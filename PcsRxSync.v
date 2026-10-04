// +FHDR----------------------------------------------------------------------------
// Device        : Xilinx
// Author        : fxdqe
// Email         : 1706260166@qq.com
// Created On    : 2026/09/16 21:05
// File Name     : PcsRxSync.v
// Description   : Clause 36 码组同步：偶边界 / syncStatus / cgBad。
//                 尚未选定比特相位时，用上一拍并行找逗号；锁定期间不偏移，失锁后再找。
//                 状态只有失锁和锁定。逗号级数、滞回由计数器完成。
//                 全通路只在这里例化一次 8B/10B 译码，结果打拍交给 Decode。
//                 rstN 已是 clkRx 域同步释放复位。
//
// ---------------------------------------------------------------------------------
// Modification History:
// Date         By              Version                 Change Description
// ---------------------------------------------------------------------------------
// 2026/09/16   fxdqe           1.0                     Original
// 2026/10/01   fxdqe           1.1                     Int/Cnt 命名与 output reg
// 2026/10/04   fxdqe           1.2                     译码只保留一份，送给 Decode
// 2026/10/04   fxdqe           1.3                     三组 C+D 后锁定，SA1 为最稳
// 2026/10/04   fxdqe           1.4                     独热两段式，按功能拆 always
// 2026/10/04   fxdqe           1.5                     只留失锁/锁定，级数改计数
// 2026/10/04   fxdqe           1.6                     计数下一拍改 assign，集中锁存
// 2026/10/04   fxdqe           1.7                     初始逗号并行定比特相位
// 2026/10/04   fxdqe           1.8                     失锁后放开比特相位
// -FHDR----------------------------------------------------------------------------

`include "GmacIf.vh"

module PcsRxSync(/*autoarg*/
        //Inputs
        clkRx, rstN, gbx2PcsCodeBusCodeGroup,
        //Outputs
        sync2DecOctet, sync2DecIsK, sync2DecRxRd, sync2DecRxEven,
        sync2DecSyncStatus, sync2DecCgBad, pcsRxSyncState, lossOfSyncCnt
);

//######################################################
//Interface
//######################################################

input                   clkRx;
input                   rstN;

input  [`GMAC_CODE_W-1:0] gbx2PcsCodeBusCodeGroup;

output [`GMAC_BYTE_W-1:0]      sync2DecOctet;
output                         sync2DecIsK;
output                         sync2DecRxRd;
output                         sync2DecRxEven;
output                         sync2DecSyncStatus;
output                         sync2DecCgBad;
output [2:0]                   pcsRxSyncState;
output reg [`GMAC_CNT_W32-1:0] lossOfSyncCnt;

//######################################################
//Value
//######################################################

localparam [1:0] S_LOSS = 2'b01;
localparam [1:0] S_SYNC = 2'b10;

// 码组判定。phase 0 表示本拍 10 bit 已对齐，1..9 表示逗号从上一拍对应比特开始。
wire [9:0]              cgRaw;
wire [9:0]              cg;
wire [3:0]              phaseUse;
wire [9:0]              commaPh;
wire [3:0]              phaseFound;
wire                    commaHit;
wire                    hunt;
wire                    commaPlus;
wire                    commaMinus;
wire                    isComma;
wire                    commaMis;
wire                    currentEven;
wire                    alignChk;
wire                    cgBad;
wire                    commaLock;
wire [`GMAC_BYTE_W-1:0] octetDec;
wire                    isKDec;
wire                    invalidDec;
wire                    rxRdInt;

// 失锁 / 锁定
reg  [1:0]              state;
reg  [1:0]              stateNxt;

// 失锁期间已收下的偶位逗号数。3 之后的下一个好码才锁定。
reg  [1:0]              commaCnt;
wire [1:0]              commaCntInt;

// 锁定滞回：badLvl 0 最稳，3 再坏一次失锁；goodCnt 满 4 退一级。
reg  [1:0]              badLvl;
wire [1:0]              badLvlInt;
reg  [1:0]              goodCnt;
wire [1:0]              goodCntInt;

// 比特相位：找到初始逗号时写下；同步丢失后放开，便于拔插后重找
reg  [9:0]              cgPrev;
reg  [3:0]              phase;
wire [3:0]              phaseInt;
reg                     phaseLock;
wire                    phaseLockInt;
wire                    phaseDrop;

// 偶边界 / 运行不一致
reg                     rxEven;
wire                    rxEvenInt;
reg                     rxRd;
wire [`GMAC_CNT_W32-1:0] lossOfSyncCntInt;

// 译码结果打拍
reg  [`GMAC_BYTE_W-1:0] octetReg;
reg                     isKReg;
reg                     badReg;

//######################################################
//Logic
//######################################################

function [9:0] cgAlign;
    input [9:0] prevCg;
    input [9:0] currCg;
    input [3:0] phaseSel;
    begin
        case (phaseSel)
            4'd1: cgAlign = {currCg[0],   prevCg[9:1]};
            4'd2: cgAlign = {currCg[1:0], prevCg[9:2]};
            4'd3: cgAlign = {currCg[2:0], prevCg[9:3]};
            4'd4: cgAlign = {currCg[3:0], prevCg[9:4]};
            4'd5: cgAlign = {currCg[4:0], prevCg[9:5]};
            4'd6: cgAlign = {currCg[5:0], prevCg[9:6]};
            4'd7: cgAlign = {currCg[6:0], prevCg[9:7]};
            4'd8: cgAlign = {currCg[7:0], prevCg[9:8]};
            4'd9: cgAlign = {currCg[8:0], prevCg[9]};
            default: cgAlign = currCg;
        endcase
    end
endfunction

function cgAt0;
    input [9:0] code;
    begin
        cgAt0 = (code[6:0] == 7'b1111100) | (code[6:0] == 7'b0000011);
    end
endfunction

//======================================================
// 初始逗号：上一拍与本拍拼成 10 个相位，相位 0 优先
//======================================================

    assign cgRaw      = gbx2PcsCodeBusCodeGroup;
    assign hunt       = (state == S_LOSS) & (commaCnt == 2'd0) & ~phaseLock;
    assign commaPh[0] = cgAt0(cgAlign(cgPrev, cgRaw, 4'd0));
    assign commaPh[1] = cgAt0(cgAlign(cgPrev, cgRaw, 4'd1));
    assign commaPh[2] = cgAt0(cgAlign(cgPrev, cgRaw, 4'd2));
    assign commaPh[3] = cgAt0(cgAlign(cgPrev, cgRaw, 4'd3));
    assign commaPh[4] = cgAt0(cgAlign(cgPrev, cgRaw, 4'd4));
    assign commaPh[5] = cgAt0(cgAlign(cgPrev, cgRaw, 4'd5));
    assign commaPh[6] = cgAt0(cgAlign(cgPrev, cgRaw, 4'd6));
    assign commaPh[7] = cgAt0(cgAlign(cgPrev, cgRaw, 4'd7));
    assign commaPh[8] = cgAt0(cgAlign(cgPrev, cgRaw, 4'd8));
    assign commaPh[9] = cgAt0(cgAlign(cgPrev, cgRaw, 4'd9));
    assign commaHit   = |commaPh;
    assign phaseFound = commaPh[0] ? 4'd0 :
                        commaPh[1] ? 4'd1 :
                        commaPh[2] ? 4'd2 :
                        commaPh[3] ? 4'd3 :
                        commaPh[4] ? 4'd4 :
                        commaPh[5] ? 4'd5 :
                        commaPh[6] ? 4'd6 :
                        commaPh[7] ? 4'd7 :
                        commaPh[8] ? 4'd8 :
                        commaPh[9] ? 4'd9 : 4'd0;
    assign phaseDrop    = (state == S_SYNC) & (stateNxt == S_LOSS);
    assign phaseUse     = (hunt & commaHit) ? phaseFound : phase;
    assign phaseInt     = (hunt & commaHit) ? phaseFound :
                          phaseDrop ? 4'd0 : phase;
    assign phaseLockInt = (phaseLock | (hunt & commaHit)) & ~phaseDrop;
    assign cg         = cgAlign(cgPrev, cgRaw, phaseUse);

    always@(posedge clkRx or negedge rstN) begin
        if (!rstN)
            cgPrev <= 10'b0;
        else
            cgPrev <= cgRaw;
    end

    always@(posedge clkRx or negedge rstN) begin
        if (!rstN) begin
            phase     <= 4'd0;
            phaseLock <= 1'b0;
        end
        else begin
            phase     <= phaseInt;
            phaseLock <= phaseLockInt;
        end
    end

//======================================================
// 码组合法性 / 逗号边界
//======================================================

    assign commaPlus  = (cg[6:0] == 7'b1111100);
    assign commaMinus = (cg[6:0] == 7'b0000011);
    assign isComma    = commaPlus | commaMinus;
    assign commaMis   = ((cg[7:1]==7'b1111100) | (cg[7:1]==7'b0000011) |
                         (cg[8:2]==7'b1111100) | (cg[8:2]==7'b0000011) |
                         (cg[9:3]==7'b1111100) | (cg[9:3]==7'b0000011)) & ~isComma;

    Gmac8b10bDec uDec (
        .codeGroup  (cg),
        .rd         (rxRd),
        .octet      (octetDec),
        .isK        (isKDec),
        .invalid    (invalidDec),
        .inAlphabet (),
        .rdNext     (rxRdInt)
    );

    // rxEven 记下上一拍已经收下的码组落在偶位还是奇位。
    // 本拍码组在相反边界上，逗号是否对齐要看本拍，不能看上一拍。
    assign currentEven = ~rxEven;
    assign alignChk    = (state == S_SYNC) | (commaCnt != 2'd0);
    assign cgBad       = invalidDec | commaMis |
                         (isComma & ~currentEven & alignChk);
    assign commaLock   = (state == S_LOSS) & (commaCnt < 2'd3) & isComma & ~cgBad;

//======================================================
// 状态寄存器 @ clkRx
//======================================================

    always@(posedge clkRx or negedge rstN) begin
        if (!rstN)
            state <= S_LOSS;
        else
            state <= stateNxt;
    end

//======================================================
// 状态转移：只有失锁和锁定
//======================================================

    always @(*) begin
        stateNxt = state;
        if (state == S_LOSS) begin
            if ((commaCnt >= 2'd3) & ~cgBad)
                stateNxt = S_SYNC;
        end
        else if (cgBad & (badLvl >= 2'd3))
            stateNxt = S_LOSS;
        else if (state != S_SYNC)
            stateNxt = S_LOSS;
    end

//======================================================
// 逗号计数：失锁期间数满 3 个偶位逗号
//======================================================

    assign commaCntInt = ((state != S_LOSS) | cgBad | (commaCnt >= 2'd3)) ? 2'd0 :
                         commaLock ? commaCnt + 2'd1 :
                         commaCnt;

//======================================================
// 锁定滞回：坏码加级，连续 4 个好码退一级
//======================================================

    assign badLvlInt  = ((state != S_SYNC) | (cgBad & (badLvl >= 2'd3))) ? 2'd0 :
                        cgBad ? badLvl + 2'd1 :
                        ((badLvl != 2'd0) & (goodCnt >= 2'd3)) ? badLvl - 2'd1 :
                        badLvl;
    assign goodCntInt = ((state != S_SYNC) | cgBad | (badLvl == 2'd0) |
                        (goodCnt >= 2'd3)) ? 2'd0 :
                        goodCnt + 2'd1;

//======================================================
// 失锁计数
//======================================================

    assign lossOfSyncCntInt = ((stateNxt == S_LOSS) & (state != S_LOSS) &
                              (lossOfSyncCnt < {`GMAC_CNT_W32{1'b1}})) ?
                              lossOfSyncCnt + {{(`GMAC_CNT_W32-1){1'b0}}, 1'b1} :
                              lossOfSyncCnt;

//======================================================
// 计数锁存 @ clkRx
//======================================================

    always@(posedge clkRx or negedge rstN) begin
        if (!rstN) begin
            commaCnt      <= 2'd0;
            badLvl        <= 2'd0;
            goodCnt       <= 2'd0;
            lossOfSyncCnt <= {`GMAC_CNT_W32{1'b0}};
        end
        else begin
            commaCnt      <= commaCntInt;
            badLvl        <= badLvlInt;
            goodCnt       <= goodCntInt;
            lossOfSyncCnt <= lossOfSyncCntInt;
        end
    end

//======================================================
// 偶边界 @ clkRx：收下逗号时强制为偶，其余每码翻转
//======================================================

    assign rxEvenInt = commaLock | (~commaLock & ~rxEven);

    always@(posedge clkRx or negedge rstN) begin
        if (!rstN)
            rxEven <= 1'b0;
        else
            rxEven <= rxEvenInt;
    end

//======================================================
// 运行不一致 @ clkRx
//======================================================

    always@(posedge clkRx or negedge rstN) begin
        if (!rstN)
            rxRd <= 1'b0;
        else
            rxRd <= rxRdInt;
    end

//======================================================
// 译码结果打拍 @ clkRx
//======================================================

    always@(posedge clkRx or negedge rstN) begin
        if (!rstN) begin
            octetReg <= {`GMAC_BYTE_W{1'b0}};
            isKReg   <= 1'b0;
            badReg   <= 1'b1;
        end
        else begin
            octetReg <= octetDec;
            isKReg   <= isKDec;
            badReg   <= cgBad;
        end
    end

//======================================================
// 送给 Decode / 寄存器观察
//======================================================

    assign sync2DecOctet      = octetReg;
    assign sync2DecIsK        = isKReg;
    assign sync2DecRxRd       = rxRd;
    assign sync2DecRxEven     = rxEven;
    assign sync2DecSyncStatus = (state == S_SYNC);
    assign sync2DecCgBad      = badReg;
    assign pcsRxSyncState     = (state == S_SYNC) ? (3'd4 + {1'b0, badLvl}) :
                                {1'b0, commaCnt};

endmodule
