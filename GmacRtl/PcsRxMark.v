// +FHDR----------------------------------------------------------------------------
// Device        : Xilinx
// Author        : fxdqe
// Email         : 1706260166@qq.com
// Created On    : 2026/09/16 21:05
// File Name     : PcsRxMark.v
// Description   : /S/ 起包、/T/R/R|K28.5/ 收包、/V/ 打 err；失锁先 err 再抑制 sfp。
//                 4 拍窗口认结束序列。出口比窗口条件晚一拍，状态机用三段式。状态是独热码。
//                 rstN 已是 clkRx 域同步释放复位。
// ---------------------------------------------------------------------------------
// Modification History:
// Date         By              Version                 Change Description
// ---------------------------------------------------------------------------------
// 2026/09/16   fxdqe           1.1                     4-deep checkEnd
// 2026/10/01   fxdqe           1.2                     Cnt 命名与 output reg
// 2026/10/04   fxdqe           1.3                     窗口、状态、标志、计数、出口拆开
// 2026/10/04   fxdqe           1.4                     窗口流水改为 oct/octF1/octF2/octF3
// -FHDR----------------------------------------------------------------------------

`include "GmacIf.vh"

module PcsRxMark(/*autoarg*/
        //Inputs
        clkRx, rstN, rxEn, pcs2RsSyncStatus, dec2MarkOctet,
        dec2MarkIsK, dec2MarkInvalid, dec2MarkRxRd, dec2MarkRxEven,
        dec2MarkSyncStatus, dec2MarkCgBad,
        //Outputs
        pcs2RsPktBusData, pcs2RsPktBusValid, pcs2RsPktBusSfp,
        pcs2RsPktBusEfp, pcs2RsPktBusErr, pcs2RsPktBusPreemptable,
        codeVCnt
);

//######################################################
//Interface
//######################################################

input                           clkRx;
input                           rstN;
input                           rxEn;
input                           pcs2RsSyncStatus;

input  [`GMAC_BYTE_W-1:0]       dec2MarkOctet;
input                           dec2MarkIsK;
input                           dec2MarkInvalid;
input                           dec2MarkRxRd;
input                           dec2MarkRxEven;
input                           dec2MarkSyncStatus;
input                           dec2MarkCgBad;

output [`GMAC_BYTE_W-1:0]       pcs2RsPktBusData;
output                          pcs2RsPktBusValid;
output                          pcs2RsPktBusSfp;
output                          pcs2RsPktBusEfp;
output                          pcs2RsPktBusErr;
output                          pcs2RsPktBusPreemptable;
output reg [`GMAC_CNT_W32-1:0]  codeVCnt;

//######################################################
//Value
//######################################################

localparam [7:0] K28_5 = 8'hBC;
localparam [7:0] K27_7 = 8'hFB;
localparam [7:0] K29_7 = 8'hFD;
localparam [7:0] K23_7 = 8'hF7;
localparam [7:0] K30_7 = 8'hFE;

// 独热。bit0 是复位态 Idle，bit1 是 InPkt
localparam [1:0] ST_IDLE = 2'b01;
localparam [1:0] ST_PKT  = 2'b10;

// 4 拍窗口。oct 是刚收下的码，octF3 是正在交给 RS 的那一拍
reg  [`GMAC_BYTE_W-1:0]         oct;
reg  [`GMAC_BYTE_W-1:0]         octF1;
reg  [`GMAC_BYTE_W-1:0]         octF2;
reg  [`GMAC_BYTE_W-1:0]         octF3;
reg                             isK;
reg                             isKF1;
reg                             isKF2;
reg                             isKF3;
reg                             inv;
reg                             invF1;
reg                             invF2;
reg                             invF3;
reg                             sync;
reg                             syncF1;
reg                             syncF2;
reg                             syncF3;

wire                            syncOk;
wire                            liveFail;
wire                            isS;
wire                            isV;
wire                            isT;
wire                            isR;
wire                            isEnd;
wire                            isK28;
wire                            checkEnd;

// 窗口未满时不切包。数到 4 停住
reg  [2:0]                      fillCnt;
wire [2:0]                      fillCntInt;
wire                            filled;

// 状态。Idle 等 /S/，InPkt 交包
reg  [1:0]                      state;
reg  [1:0]                      stateNxt;
wire                            inPkt;
wire                            startPkt;
wire                            cutPkt;
wire                            goodEnd;
wire                            k28Cut;
wire                            symErr;

// 包内见过 /V/、非法码或 K。合法结束那拍还要把它算进 err
reg                             pktErr;
wire                            pktErrInt;

// /V/ 与非法码累计。纯 K 不加
wire                            codeVHit;
wire [`GMAC_CNT_W32-1:0]        codeVCntInt;

// 出口寄存器。决定在本拍，寄存器下一拍才出现在口上
reg  [`GMAC_BYTE_W-1:0]         dataOut;
reg                             validOut;
reg                             sfpOut;
reg                             efpOut;
reg                             errOut;
reg  [`GMAC_BYTE_W-1:0]         dataNxt;
reg                             validNxt;
reg                             sfpNxt;
reg                             efpNxt;
reg                             errNxt;

//######################################################
//Logic
//######################################################

//======================================================
// 窗口 @ clkRx
// octF3 是末字节，octF2 / octF1 / oct 是后面的 /T/、/R/、/R/ 或 K28.5。
// 失锁看当前 syncStatus 和 rxEn，不等窗口里的旧状态。
// /S/ 还要窗口那一拍自己也是同步的。
//======================================================

    assign syncOk   = pcs2RsSyncStatus & rxEn;
    assign liveFail = ~syncOk;
    assign isS      = isKF3 & ~invF3 & (octF3 == K27_7);
    assign isV      = isKF3 & ~invF3 & (octF3 == K30_7);
    assign isT      = isKF2 & ~invF2 & (octF2 == K29_7);
    assign isR      = isKF1 & ~invF1 & (octF1 == K23_7);
    assign isEnd    = isK & ~inv & ((oct == K23_7) | (oct == K28_5));
    assign isK28    = isKF3 & ~invF3 & (octF3 == K28_5);
    assign checkEnd = isT & isR & isEnd;
    assign filled   = fillCnt >= 3'd4;

    always@(posedge clkRx or negedge rstN) begin
        if (!rstN) begin
            oct    <= {`GMAC_BYTE_W{1'b0}};
            octF1  <= {`GMAC_BYTE_W{1'b0}};
            octF2  <= {`GMAC_BYTE_W{1'b0}};
            octF3  <= {`GMAC_BYTE_W{1'b0}};
            isK    <= 1'b0;
            isKF1  <= 1'b0;
            isKF2  <= 1'b0;
            isKF3  <= 1'b0;
            inv    <= 1'b1;
            invF1  <= 1'b1;
            invF2  <= 1'b1;
            invF3  <= 1'b1;
            sync   <= 1'b0;
            syncF1 <= 1'b0;
            syncF2 <= 1'b0;
            syncF3 <= 1'b0;
        end
        else begin
            oct    <= dec2MarkOctet;
            octF1  <= oct;
            octF2  <= octF1;
            octF3  <= octF2;
            isK    <= dec2MarkIsK;
            isKF1  <= isK;
            isKF2  <= isKF1;
            isKF3  <= isKF2;
            inv    <= dec2MarkInvalid;
            invF1  <= inv;
            invF2  <= invF1;
            invF3  <= invF2;
            sync   <= dec2MarkSyncStatus;
            syncF1 <= sync;
            syncF2 <= syncF1;
            syncF3 <= syncF2;
        end
    end

//======================================================
// 状态 @ clkRx
// startPkt：空闲时看到已同步的 /S/。
// cutPkt：正在交包时失锁或 rxEn 关掉，本拍截断。
// goodEnd：末字节后面已经是 /T/R/R/ 或 /T/R/K28.5/。
// k28Cut：包内冒出 K28.5，且这一拍不是合法结束。
// symErr：包内的 /V/、非法码或其它 K。K28.5 截断也算在里面。
//======================================================

    assign inPkt    = state[1] & ~state[0];
    assign startPkt = filled & ~inPkt & syncOk & syncF3 & isS;
    assign cutPkt   = filled & inPkt & liveFail;
    assign goodEnd  = filled & inPkt & ~liveFail & checkEnd;
    assign k28Cut   = filled & inPkt & ~liveFail & ~checkEnd & isK28;
    assign symErr   = filled & inPkt & ~liveFail & ~checkEnd & (invF3 | isV | isKF3);

    always@(posedge clkRx or negedge rstN) begin
        if (!rstN)
            state <= ST_IDLE;
        else
            state <= stateNxt;
    end

    always@(*) begin
        stateNxt = state;
        case (state)
            ST_IDLE: if (startPkt) stateNxt = ST_PKT;
            ST_PKT:  if (cutPkt | goodEnd | k28Cut) stateNxt = ST_IDLE;
            default: stateNxt = ST_IDLE;
        endcase
    end

//======================================================
// 包内错误标志
// 置位后保持。失锁截断、合法结束、下一包 /S/ 清掉。同拍又置又清时清优先。
// K28.5 截断只置位，留到下一包 /S/ 再清。
//======================================================

    assign pktErrInt = (pktErr | symErr) & ~(startPkt | cutPkt | goodEnd);

    always@(posedge clkRx or negedge rstN) begin
        if (!rstN)
            pktErr <= 1'b0;
        else
            pktErr <= pktErrInt;
    end

//======================================================
// 计数 @ clkRx
// fillCnt 数进窗口的拍数，到 4 停住。
// codeVCnt 只计仍在包内、还没结束、仍然同步时的 /V/ 和非法码。加到全 1 停住。
//======================================================

    assign fillCntInt  = filled ? fillCnt : (fillCnt + 3'd1);
    assign codeVHit    = filled & inPkt & ~liveFail & ~checkEnd & (isV | invF3);
    assign codeVCntInt = (~codeVHit | (codeVCnt >= {`GMAC_CNT_W32{1'b1}}))
                       ? codeVCnt
                       : (codeVCnt + {{(`GMAC_CNT_W32-1){1'b0}}, 1'b1});

    always@(posedge clkRx or negedge rstN) begin
        if (!rstN) begin
            fillCnt  <= 3'd0;
            codeVCnt <= {`GMAC_CNT_W32{1'b0}};
        end
        else begin
            fillCnt  <= fillCntInt;
            codeVCnt <= codeVCntInt;
        end
    end

//======================================================
// 出口
// 默认 valid / sfp / efp / err 为 0，data 保持。
// /S/ 还原成 0x55。包内每一拍都交出 octF3，结束符本身不交。
// 合法结束的 err 还看已经记下的 pktErr。失锁截断本拍 efp 且 err。
//======================================================

    always@(*) begin
        dataNxt  = dataOut;
        validNxt = 1'b0;
        sfpNxt   = 1'b0;
        efpNxt   = 1'b0;
        errNxt   = 1'b0;
        if (cutPkt) begin
            dataNxt  = isS ? 8'h55 : octF3;
            validNxt = 1'b1;
            efpNxt   = 1'b1;
            errNxt   = 1'b1;
        end
        else if (startPkt) begin
            dataNxt  = 8'h55;
            validNxt = 1'b1;
            sfpNxt   = 1'b1;
        end
        else if (goodEnd) begin
            dataNxt  = isS ? 8'h55 : octF3;
            validNxt = 1'b1;
            efpNxt   = 1'b1;
            errNxt   = pktErr | invF3 | isV | isKF3;
        end
        else if (filled & inPkt) begin
            dataNxt  = isS ? 8'h55 : octF3;
            validNxt = 1'b1;
            errNxt   = invF3 | isV | isKF3;
            if (k28Cut) begin
                efpNxt = 1'b1;
                errNxt = 1'b1;
            end
        end
    end

    always@(posedge clkRx or negedge rstN) begin
        if (!rstN) begin
            dataOut  <= {`GMAC_BYTE_W{1'b0}};
            validOut <= 1'b0;
            sfpOut   <= 1'b0;
            efpOut   <= 1'b0;
            errOut   <= 1'b0;
        end
        else begin
            dataOut  <= dataNxt;
            validOut <= validNxt;
            sfpOut   <= sfpNxt;
            efpOut   <= efpNxt;
            errOut   <= errNxt;
        end
    end

    assign pcs2RsPktBusData        = dataOut;
    assign pcs2RsPktBusValid       = validOut;
    assign pcs2RsPktBusSfp         = sfpOut;
    assign pcs2RsPktBusEfp         = efpOut;
    assign pcs2RsPktBusErr         = errOut;
    assign pcs2RsPktBusPreemptable = 1'b0;

endmodule
