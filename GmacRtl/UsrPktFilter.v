// +FHDR----------------------------------------------------------------------------
// Device        : Xilinx
// Author        : fxdqe
// Email         : 1706260166@qq.com
// Created On    : 2026/10/01 20:40
// File Name     : UsrPktFilter.v
// Description   : 用户侧 128b 报文过滤。不缓存数据拍，只保留是否在包内、包内是否出过错。
//                 1. 当作没有输入（包状态不变）：Stall 上的 Valid；包外没有 Sfp，或包外 Vb=0。
//                 2. 照出并收包（Efp=1，Err=1，包结束）：
//                    包内 Vb=0 则 Vb 改为 16；包内无 Efp 且 Vb 为 1..15 则 Vb 保持；
//                    包内又出现 Sfp 则 Sfp 改为 0。同一拍命中多条时一起改。
//                 3. Vb>16：钳成 16 并记 Err。本拍被规则 2 收包或本来就有 Efp 则包结束，
//                    否则包继续，Err 留到结束拍。
//                 Valid=0 为空拍：包外保持空闲，包内保持打开，侧带原样送出。
//                 Preemptable 不检查、不修改。Tx 把 Stall 接上；Rx 把 Stall 接 0。
//
// ---------------------------------------------------------------------------------
// Modification History:
// Date         By              Version                 Change Description
// ---------------------------------------------------------------------------------
// 2026/10/01   fxdqe           1.0                     Original
// -FHDR----------------------------------------------------------------------------

`include "GmacIf.vh"

module UsrPktFilter(/*autoarg*/
        //Inputs
        clk, rstN, stall, inData, inVb, inValid, inSfp, inEfp, inErr,
        inPreemptable,
        //Outputs
        outData, outVb, outValid, outSfp, outEfp, outErr, outPreemptable
);

//######################################################
//Interface
//######################################################

parameter USR_DATA_W = `GMAC_USR_W;

localparam VB_W = `GMAC_VB_W;

input                   clk;
input                   rstN;
input                   stall;

input  [USR_DATA_W-1:0] inData;
input  [VB_W-1:0]       inVb;
input                   inValid;
input                   inSfp;
input                   inEfp;
input                   inErr;
input                   inPreemptable;

output [USR_DATA_W-1:0] outData;
output [VB_W-1:0]       outVb;
output                  outValid;
output                  outSfp;
output                  outEfp;
output                  outErr;
output                  outPreemptable;

//######################################################
//Value
//######################################################

wire                  beat;
wire                  vbZero;
wire                  vbOver;
wire                  vbShort;
wire                  accept;
wire                  closeVb0;
wire                  closeShort;
wire                  closeSfp;
wire                  closePkt;
wire [VB_W-1:0]       vbFix;
wire                  sfpFix;
wire                  efpFix;
wire                  errFix;
wire                  inPktInt;
wire                  sawErrInt;

reg                   inPkt;
reg                   sawErr;

//######################################################
//Logic
//######################################################

    assign beat    = inValid & ~stall;
    assign vbZero  = (inVb == {VB_W{1'd0}});
    assign vbOver  = (inVb > 5'd16);
    assign vbShort = (inVb != {VB_W{1'd0}}) & (inVb < 5'd16);

    // 包外：有 Sfp 且 Vb 非 0 才开包。包内的拍都接收，再按规则改侧带
    assign accept     = beat & (inPkt | (inSfp & ~vbZero));
    assign closeVb0   = inPkt & vbZero;
    assign closeShort = inPkt & ~inEfp & vbShort;
    assign closeSfp   = inPkt & inSfp;
    assign closePkt   = closeVb0 | closeShort | closeSfp;

    assign vbFix  = (vbOver | closeVb0) ? 5'd16 : inVb;
    assign sfpFix = closeSfp ? 1'd0 : inSfp;
    assign efpFix = closePkt ? 1'd1 : inEfp;
    assign errFix = inErr | vbOver | closePkt | (efpFix & sawErr);

    assign outValid       = accept;
    assign outData        = inData;
    assign outVb          = accept ? vbFix  : inVb;
    assign outSfp         = accept ? sfpFix : inSfp;
    assign outEfp         = accept ? efpFix : inEfp;
    assign outErr         = accept ? errFix : inErr;
    assign outPreemptable = inPreemptable;

    // 收包后回到包外，并清掉粘住的 Err。空拍和被丢掉的拍不改状态
    assign inPktInt  = accept ? ((inPkt | sfpFix) & ~efpFix) : inPkt;
    assign sawErrInt = accept ? (efpFix ? 1'd0 : (sawErr | errFix)) : sawErr;

    always@(posedge clk or negedge rstN)begin
        if(!rstN)begin
            inPkt  <= 1'd0;
            sawErr <= 1'd0;
        end
        else begin
            inPkt  <= inPktInt;
            sawErr <= sawErrInt;
        end
    end

endmodule
