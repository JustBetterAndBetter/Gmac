// +FHDR----------------------------------------------------------------------------
// Device        : Xilinx
// Author        : fxdqe
// Email         : 1706260166@qq.com
// Created On    : 2026/09/16 21:05
// File Name     : PcsRxDecode.v
// Description   : 把 PcsRxSync 已经译好的八位组打拍给 Mark。
//                 syncStatus 未锁定时不交出八位组；RD 仍逐码传递。
//                 rstN 已是 clkRx 域同步释放复位。
//
// ---------------------------------------------------------------------------------
// Modification History:
// Date         By              Version                 Change Description
// ---------------------------------------------------------------------------------
// 2026/09/16   fxdqe           1.0                     Original
// 2026/10/01   fxdqe           1.1                     Int / output reg
// 2026/10/04   fxdqe           1.2                     去掉重复译码，锁定后才输出
// -FHDR----------------------------------------------------------------------------

`include "GmacIf.vh"

module PcsRxDecode(/*autoarg*/
        //Inputs
        clkRx, rstN, sync2DecOctet, sync2DecIsK, sync2DecRxRd,
        sync2DecRxEven, sync2DecSyncStatus, sync2DecCgBad,
        //Outputs
        dec2MarkOctet, dec2MarkIsK, dec2MarkInvalid, dec2MarkRxRd,
        dec2MarkRxEven, dec2MarkSyncStatus, dec2MarkCgBad
);

//######################################################
//Interface
//######################################################

input                   clkRx;
input                   rstN;

input  [`GMAC_BYTE_W-1:0] sync2DecOctet;
input                   sync2DecIsK;
input                   sync2DecRxRd;
input                   sync2DecRxEven;
input                   sync2DecSyncStatus;
input                   sync2DecCgBad;

output reg [`GMAC_BYTE_W-1:0] dec2MarkOctet;
output reg                    dec2MarkIsK;
output reg                    dec2MarkInvalid;
output reg                    dec2MarkRxRd;
output reg                    dec2MarkRxEven;
output reg                    dec2MarkSyncStatus;
output reg                    dec2MarkCgBad;

//######################################################
//Value
//######################################################

wire [`GMAC_BYTE_W-1:0] dec2MarkOctetInt;
wire                    dec2MarkIsKInt;
wire                    dec2MarkInvalidInt;
wire                    dec2MarkRxRdInt;
wire                    dec2MarkRxEvenInt;
wire                    dec2MarkSyncStatusInt;
wire                    dec2MarkCgBadInt;

//######################################################
//Logic
//######################################################

//======================================================
// 锁定后才把译码结果交给 Mark；RD 失锁期间继续走
//======================================================

    assign dec2MarkOctetInt      = sync2DecSyncStatus ? sync2DecOctet :
                                   {`GMAC_BYTE_W{1'b0}};
    assign dec2MarkIsKInt        = sync2DecSyncStatus & sync2DecIsK;
    assign dec2MarkInvalidInt    = ~sync2DecSyncStatus | sync2DecCgBad;
    assign dec2MarkRxRdInt       = sync2DecRxRd;
    assign dec2MarkRxEvenInt     = sync2DecRxEven;
    assign dec2MarkSyncStatusInt = sync2DecSyncStatus;
    assign dec2MarkCgBadInt      = sync2DecCgBad;

//======================================================
// 译码结果打拍 @ clkRx
//======================================================

    always@(posedge clkRx or negedge rstN) begin
        if (!rstN) begin
            dec2MarkOctet      <= {`GMAC_BYTE_W{1'b0}};
            dec2MarkIsK        <= 1'b0;
            dec2MarkInvalid    <= 1'b1;
            dec2MarkRxRd       <= 1'b0;
            dec2MarkRxEven     <= 1'b0;
            dec2MarkSyncStatus <= 1'b0;
            dec2MarkCgBad      <= 1'b1;
        end
        else begin
            dec2MarkOctet      <= dec2MarkOctetInt;
            dec2MarkIsK        <= dec2MarkIsKInt;
            dec2MarkInvalid    <= dec2MarkInvalidInt;
            dec2MarkRxRd       <= dec2MarkRxRdInt;
            dec2MarkRxEven     <= dec2MarkRxEvenInt;
            dec2MarkSyncStatus <= dec2MarkSyncStatusInt;
            dec2MarkCgBad      <= dec2MarkCgBadInt;
        end
    end

endmodule
