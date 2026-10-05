// +FHDR----------------------------------------------------------------------------
// Device        : Xilinx
// Author        : fxdqe
// Email         : 1706260166@qq.com
// Created On    : 2026/09/16 21:05
// File Name     : PcsTxEncode.v
// Description   : Tx Idle/InPkt/AfterPkt + 8B/10B + RD。10b 口每拍一个码组，无 stall。
//                 入向每拍 1 字节，rs2PcsPktBusData[0] 先发。
//                 出向 pcs2GbxCodeBusCodeGroup[0] 先出。
//                 rstN 已是 clkTx 域同步释放复位，不再另接 softRstN。
//                 状态口 pcsTxState 仍是寄存器表里的 2 bit，内部用独热码。
//
// ---------------------------------------------------------------------------------
// Modification History:
// Date         By              Version                 Change Description
// ---------------------------------------------------------------------------------
// 2026/09/16   fxdqe           1.0                     Original
// 2026/10/04   fxdqe           1.1                     去掉 xmit，发包只看 txEn
// 2026/10/05   fxdqe           1.2                     独热两段式，按功能拆 always
// -FHDR----------------------------------------------------------------------------

`include "GmacIf.vh"

module PcsTxEncode(/*autoarg*/
        //Inputs
        clkTx, rstN, txEn, rs2PcsPktBusData,
        rs2PcsPktBusValid, rs2PcsPktBusSfp, rs2PcsPktBusEfp,
        rs2PcsPktBusErr, rs2PcsPktBusPreemptable,
        //Outputs
        rs2PcsPktBusStall, pcs2GbxCodeBusCodeGroup, pcsTxState,
        pcsTxEven, pcsTxRd
);

//######################################################
//Interface
//######################################################

input                           clkTx;
input                           rstN;
input                           txEn;

input  [`GMAC_BYTE_W-1:0]       rs2PcsPktBusData;
input                           rs2PcsPktBusValid;
input                           rs2PcsPktBusSfp;
input                           rs2PcsPktBusEfp;
input                           rs2PcsPktBusErr;
input                           rs2PcsPktBusPreemptable; // 第一版不使用，固定为 0
output                          rs2PcsPktBusStall;

output [`GMAC_CODE_W-1:0]       pcs2GbxCodeBusCodeGroup;

output [1:0]                    pcsTxState; // 0 Idle，1 InPkt，2 After
output                          pcsTxEven;  // 已送出码组的偶边界，1 为偶
output                          pcsTxRd;    // 已送出码组之后的运行差分，1 为正

//######################################################
//Value
//######################################################

localparam [2:0] ST_IDLE  = 3'b001;
localparam [2:0] ST_INPKT = 3'b010;
localparam [2:0] ST_AFTER = 3'b100;

localparam [7:0] K28_5 = 8'hBC;
localparam [7:0] K27_7 = 8'hFB;
localparam [7:0] K29_7 = 8'hFD;
localparam [7:0] K23_7 = 8'hF7;
localparam [7:0] K30_7 = 8'hFE;
localparam [7:0] D5_6  = 8'hC5;
localparam [7:0] D16_2 = 8'h50;

// 拍条件。takeS 在偶边界用 /S/ 换掉这一拍前导码
wire                            inIdle;
wire                            inPkt;
wire                            inAfter;
wire                            wantStart;
wire                            takeS;
wire                            pktEnd;
wire                            inPktGap;
wire                            errV;
wire                            leaveAfter;

// 状态
reg  [2:0]                      state;
reg  [2:0]                      stateNxt;

// After 计数。0 是 /T/，1 和 2 是 /R/，用来把下一 /I/ 推到偶位置
reg  [1:0]                      afterCnt;
wire [1:0]                      afterCntInt;

// 偶边界。1 表示正在组的这一拍是偶位置
reg                             txEven;
wire                            txEvenInt;

// 运行差分。0 负，1 正。上电为负
reg                             txRd;
wire                            txRdInt;

// 偶拍记下的 RD。下一拍奇位置用它选 /I1/ 或 /I2/
reg                             iUseI1;
wire                            iUseI1Int;

// 本拍要编的八位组，以及打一拍后的码组
wire [`GMAC_BYTE_W-1:0]         encOctet;
wire                            encIsK;
wire [`GMAC_CODE_W-1:0]         encCode;
wire                            encRdNext;
reg  [`GMAC_CODE_W-1:0]         codeF1;

//######################################################
//Logic
//######################################################

//======================================================
// 拍条件：起包、收包、反压
// txEn 只门控新包。已经发出 /S/ 的当前包必须排完。
// Stall 不看 Valid。Idle 奇位置不能发 /S/，前级在 Stall 时把 Valid 拉低。
//======================================================

    assign inIdle    = (state == ST_IDLE);
    assign inPkt     = (state == ST_INPKT);
    assign inAfter   = (state == ST_AFTER);
    assign wantStart = txEn & inIdle & rs2PcsPktBusValid & rs2PcsPktBusSfp;
    assign takeS     = wantStart & txEven;
    assign pktEnd    = inPkt & rs2PcsPktBusValid & rs2PcsPktBusEfp;
    assign inPktGap  = inPkt & ~rs2PcsPktBusValid;
    assign errV      = inPkt & rs2PcsPktBusValid & rs2PcsPktBusErr & ~rs2PcsPktBusEfp;
    // /T/ 的下一拍若仍是偶位置，再留一个 /R/。计数被扰过 1 时也离开
    assign leaveAfter = inAfter & (afterCnt >= 2'd1) &
                        ((afterCnt >= 2'd2) | ~txEven);
    assign rs2PcsPktBusStall = inAfter | (inIdle & ~txEven);

// synthesis translate_off
    always@(posedge clkTx) begin
        if (rstN && rs2PcsPktBusStall && rs2PcsPktBusValid) begin
            $display("PcsTxEncode: Valid while stall");
            $stop;
        end
        if (rstN && rs2PcsPktBusPreemptable) begin
            $display("PcsTxEncode: preemptable is not used");
            $stop;
        end
    end
// synthesis translate_on

//======================================================
// 状态寄存器 @ clkTx
//======================================================

    always@(posedge clkTx or negedge rstN) begin
        if (!rstN)
            state <= ST_IDLE;
        else
            state <= stateNxt;
    end

//======================================================
// 状态转移：Idle / InPkt / AfterPkt
//======================================================

    always @(*) begin
        stateNxt = state;
        case (state)
            ST_IDLE:  if (takeS)      stateNxt = ST_INPKT;
            ST_INPKT: if (pktEnd)     stateNxt = ST_AFTER;
            ST_AFTER: if (leaveAfter) stateNxt = ST_IDLE;
            default:                  stateNxt = ST_IDLE;
        endcase
    end

// synthesis translate_off
    always@(posedge clkTx) begin
        if (rstN && (state != ST_IDLE) && (state != ST_INPKT) && (state != ST_AFTER)) begin
            $display("PcsTxEncode: illegal state %b", state);
            $stop;
        end
    end
// synthesis translate_on

//======================================================
// After 计数 @ clkTx
//======================================================

    assign afterCntInt = pktEnd              ? 2'd0 :
                         ~inAfter            ? afterCnt :
                         (afterCnt <= 2'd0)  ? 2'd1 :
                         ((afterCnt <= 2'd1) & txEven) ? 2'd2 :
                         afterCnt;

    always@(posedge clkTx or negedge rstN) begin
        if (!rstN)
            afterCnt <= 2'd0;
        else
            afterCnt <= afterCntInt;
    end

//======================================================
// 八位组选择。takeS 必须写在 Idle 前面，否则起包拍仍编成 /I/
//======================================================

    assign encIsK   = takeS    ? 1'b1 :
                      inIdle   ? txEven :
                      inAfter  ? 1'b1 :
                      inPktGap ? 1'b1 :
                      errV     ? 1'b1 :
                                 1'b0;
    assign encOctet = takeS    ? K27_7 :
                      inIdle   ? (txEven ? K28_5 : (iUseI1 ? D5_6 : D16_2)) :
                      inAfter  ? ((afterCnt <= 2'd0) ? K29_7 : K23_7) :
                      inPktGap ? K30_7 :
                      errV     ? K30_7 :
                                 rs2PcsPktBusData;

//======================================================
// 8B/10B 编码
//======================================================

    Gmac8b10bEnc uEnc (
        .octet     (encOctet),
        .isK       (encIsK),
        .rd        (txRd),
        .codeGroup (encCode),
        .rdNext    (encRdNext),
        .invalid   ()
    );

//======================================================
// 偶边界 @ clkTx
//======================================================

    assign txEvenInt = ~txEven;

    always@(posedge clkTx or negedge rstN) begin
        if (!rstN)
            txEven <= 1'b1;
        else
            txEven <= txEvenInt;
    end

//======================================================
// 运行差分 @ clkTx
//======================================================

    assign txRdInt = encRdNext;

    always@(posedge clkTx or negedge rstN) begin
        if (!rstN)
            txRd <= 1'b0;
        else
            txRd <= txRdInt;
    end

//======================================================
// /I/ 第二码 @ clkTx。偶拍锁存 RD，奇拍选 D5.6 或 D16.2
//======================================================

    assign iUseI1Int = (inIdle & txEven) ? txRd : iUseI1;

    always@(posedge clkTx or negedge rstN) begin
        if (!rstN)
            iUseI1 <= 1'b0;
        else
            iUseI1 <= iUseI1Int;
    end

//======================================================
// 码组打拍 @ clkTx。复位值是 RD- 的 K28.5
//======================================================

    always@(posedge clkTx or negedge rstN) begin
        if (!rstN)
            codeF1 <= 10'b0101111100;
        else
            codeF1 <= encCode;
    end

//======================================================
// 出口。pcsTxEven 对齐已经送出的码组，所以相对下一拍 txEven 取反
//======================================================

    assign pcs2GbxCodeBusCodeGroup = codeF1;
    assign pcsTxState              = inAfter ? 2'd2 :
                                     inPkt   ? 2'd1 :
                                               2'd0;
    assign pcsTxEven               = ~txEven;
    assign pcsTxRd                 = txRd;

endmodule
