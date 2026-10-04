// +FHDR----------------------------------------------------------------------------
// Device        : Xilinx
// Author        : fxdqe
// Email         : 1706260166@qq.com
// Created On    : 2026/09/16 21:05
// File Name     : PcsTxEncode.v
// Description   : Tx Idle/InPkt/AfterPkt + 8B/10B + RD；10b 口无 stall。
//                 rstN 已是 clkTx 域同步释放复位，不再另接 softRstN。
//
// ---------------------------------------------------------------------------------
// Modification History:
// Date         By              Version                 Change Description
// ---------------------------------------------------------------------------------
// 2026/09/16   fxdqe           1.0                     Original
// 2026/10/04   fxdqe           1.1                     去掉 xmit，发包只看 txEn
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

input                   clkTx;
input                   rstN;
input                   txEn;

input  [`GMAC_BYTE_W-1:0] rs2PcsPktBusData;
input                   rs2PcsPktBusValid;
input                   rs2PcsPktBusSfp;
input                   rs2PcsPktBusEfp;
input                   rs2PcsPktBusErr;
input                   rs2PcsPktBusPreemptable;
output                  rs2PcsPktBusStall;

output [`GMAC_CODE_W-1:0] pcs2GbxCodeBusCodeGroup;

output [1:0]            pcsTxState;
output                  pcsTxEven;
output                  pcsTxRd;

//######################################################
//Value
//######################################################

localparam [1:0] ST_IDLE  = 2'd0;
localparam [1:0] ST_INPKT = 2'd1;
localparam [1:0] ST_AFTER = 2'd2;

localparam [7:0] K28_5 = 8'hBC;
localparam [7:0] K27_7 = 8'hFB;
localparam [7:0] K29_7 = 8'hFD;
localparam [7:0] K23_7 = 8'hF7;
localparam [7:0] K30_7 = 8'hFE;
localparam [7:0] D5_6  = 8'hC5;
localparam [7:0] D16_2 = 8'h50;

reg  [1:0]              state;
reg                     txEven;
reg                     txRd;
reg                     iUseI1;
reg  [1:0]              afterCnt;
reg  [`GMAC_CODE_W-1:0] codeReg;

wire                    even;
wire                    allowData;
wire                    wantStart;
wire                    takeS;
wire                    stallRs;
wire [7:0]              encOctet;
wire                    encIsK;
wire [9:0]              encCode;
wire                    encRdNext;
wire                    consume;
wire                    inPktGap;

//######################################################
//Logic
//######################################################

//======================================================
// 编码选择 / stall
//======================================================

    assign even      = txEven;
    assign allowData = txEn;
    assign wantStart = allowData & (state == ST_IDLE) & rs2PcsPktBusValid & rs2PcsPktBusSfp;
    assign takeS     = wantStart & even;
    assign inPktGap  = (state == ST_INPKT) & ~rs2PcsPktBusValid;
    // txEn 只门控新包；已发 /S/ 的当前包必须排完
    // Stall 不看 Valid。Idle 奇数列不能发 /S/；前级在 Stall 时把 Valid 拉低
    assign stallRs   = (state == ST_AFTER) |
                       ((state == ST_IDLE) & ~even);
    assign consume   = ((state == ST_INPKT) & rs2PcsPktBusValid) | takeS;

    assign encIsK = (state == ST_IDLE)  ? (even ? 1'b1 : 1'b0) :
                    (state == ST_AFTER) ? 1'b1 :
                    takeS               ? 1'b1 :
                    inPktGap            ? 1'b1 :
                    (rs2PcsPktBusErr & consume & ~rs2PcsPktBusEfp) ? 1'b1 :
                    1'b0;

    assign encOctet = (state == ST_IDLE) ? (even ? K28_5 : (iUseI1 ? D5_6 : D16_2)) :
                      (state == ST_AFTER)? ((afterCnt==2'd0) ? K29_7 : K23_7) :
                      takeS              ? K27_7 :
                      inPktGap           ? K30_7 :
                      (rs2PcsPktBusErr & consume & ~rs2PcsPktBusEfp) ? K30_7 :
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

    assign rs2PcsPktBusStall       = stallRs;
    assign pcs2GbxCodeBusCodeGroup = codeReg;
    assign pcsTxState              = state;
    assign pcsTxEven               = ~txEven;
    assign pcsTxRd                 = txRd;

//======================================================
// FSM / RD / 码组寄存 @ clkTx
//======================================================

    always@(posedge clkTx or negedge rstN) begin
        if (!rstN) begin
            state    <= ST_IDLE;
            txEven   <= 1'b1;
            txRd     <= 1'b0;
            afterCnt <= 2'd0;
            iUseI1   <= 1'b0;
            codeReg  <= 10'b0101111100;
        end
        else begin
            codeReg <= encCode;
            txRd    <= encRdNext;
            txEven  <= ~txEven;
            if ((state == ST_IDLE) && even)
                iUseI1 <= txRd;
            case (state)
                ST_IDLE: begin
                    if (takeS)
                        state <= ST_INPKT;
                end
                ST_INPKT: begin
                    if (rs2PcsPktBusValid & rs2PcsPktBusEfp) begin
                        state    <= ST_AFTER;
                        afterCnt <= 2'd0;
                    end
                end
                ST_AFTER: begin
                    if (afterCnt == 2'd0)
                        afterCnt <= 2'd1;
                    else if (afterCnt == 2'd1) begin
                        if (even)
                            afterCnt <= 2'd2;
                        else
                            state <= ST_IDLE;
                    end
                    else
                        state <= ST_IDLE;
                end
                default: state <= ST_IDLE;
            endcase
        end
    end

endmodule
