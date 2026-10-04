// +FHDR----------------------------------------------------------------------------
// Device        : Xilinx
// Author        : fxdqe
// Email         : 1706260166@qq.com
// Created On    : 2026/09/16 21:05
// File Name     : UsrRsWidthCdc.v
// Description   : 用户 128b@50M 与 RS 8b@125M 的位宽+时钟桥；管理域 CDC 在本模块内。
//                 rstN 为 GmacRst 的 rstNCore，内部同步到 usr/tx/rx/mgmt。
//
// ---------------------------------------------------------------------------------
// Modification History:
// Date         By              Version                 Change Description
// ---------------------------------------------------------------------------------
// 2026/09/16   fxdqe           1.0                     Interface template
// 2026/09/18   fxdqe           1.1                     单路复位，分域同步
// 2026/10/01   fxdqe           1.2                     Cnt 命名 / W32 / txVbErrCnt
// 2026/10/01   fxdqe           1.3                     分域复位改用 IP_ResetSync
// 2026/10/01   fxdqe           1.4                     去掉 GmacFifoRst，双钟握手进 FIFO
// 2026/10/01   fxdqe           1.5                     口计数灰码同步到 clkMgmt
// -FHDR----------------------------------------------------------------------------

`include "GmacIf.vh"

module UsrRsWidthCdc(/*autoarg*/
        //Inputs
        clkUsr, clkTx, clkRx, clkMgmt, rstN, fifoTxFifoThrd,
        usr2CdcPktBusData, usr2CdcPktBusVb, usr2CdcPktBusValid, usr2CdcPktBusSfp,
        usr2CdcPktBusEfp, usr2CdcPktBusErr, usr2CdcPktBusPreemptable,
        cdc2RsPktBusStall, rs2CdcPktBusData, rs2CdcPktBusValid,
        rs2CdcPktBusSfp, rs2CdcPktBusEfp, rs2CdcPktBusErr,
        rs2CdcPktBusPreemptable,
        //Outputs
        usr2CdcPktBusStall, cdc2UsrPktBusData, cdc2UsrPktBusVb, cdc2UsrPktBusValid,
        cdc2UsrPktBusSfp, cdc2UsrPktBusEfp, cdc2UsrPktBusErr,
        cdc2UsrPktBusPreemptable, cdc2RsPktBusData, cdc2RsPktBusValid,
        cdc2RsPktBusSfp, cdc2RsPktBusEfp, cdc2RsPktBusErr,
        cdc2RsPktBusPreemptable, txFifoLevel, fifoAlFull, txFifoPeakCnt,
        txOverRunCnt, txUnderRunCnt, txVbErrCnt, rxFifoLevel, rxFifoPeakCnt,
        rxOverflowCnt, txInSfpCnt, txInEfpCnt, txInVbCnt, txInValidCnt, txInErrCnt,
        txOutSfpCnt, txOutEfpCnt, txOutVbCnt, txOutValidCnt, txOutErrCnt,
        rxInSfpCnt, rxInEfpCnt, rxInVbCnt, rxInValidCnt, rxInErrCnt,
        rxOutSfpCnt, rxOutEfpCnt, rxOutVbCnt, rxOutValidCnt, rxOutErrCnt
);

//######################################################
//Interface
//######################################################

parameter USR_DATA_W        = `GMAC_USR_W;
parameter FIFO_DEPTH        = 16;
parameter FIFO_AL_FULL_THRD = FIFO_DEPTH - 3;

input                   clkUsr;
input                   clkTx;
input                   clkRx;
input                   clkMgmt;
input                   rstN;
input  [7:0]            fifoTxFifoThrd;

input  [USR_DATA_W-1:0] usr2CdcPktBusData;
input  [`GMAC_VB_W-1:0] usr2CdcPktBusVb;
input                   usr2CdcPktBusValid;
input                   usr2CdcPktBusSfp;
input                   usr2CdcPktBusEfp;
input                   usr2CdcPktBusErr;
input                   usr2CdcPktBusPreemptable;
output                  usr2CdcPktBusStall;

output [USR_DATA_W-1:0] cdc2UsrPktBusData;
output [`GMAC_VB_W-1:0] cdc2UsrPktBusVb;
output                  cdc2UsrPktBusValid;
output                  cdc2UsrPktBusSfp;
output                  cdc2UsrPktBusEfp;
output                  cdc2UsrPktBusErr;
output                  cdc2UsrPktBusPreemptable;

output [`GMAC_BYTE_W-1:0] cdc2RsPktBusData;
output                  cdc2RsPktBusValid;
output                  cdc2RsPktBusSfp;
output                  cdc2RsPktBusEfp;
output                  cdc2RsPktBusErr;
output                  cdc2RsPktBusPreemptable;
input                   cdc2RsPktBusStall;

input  [`GMAC_BYTE_W-1:0] rs2CdcPktBusData;
input                   rs2CdcPktBusValid;
input                   rs2CdcPktBusSfp;
input                   rs2CdcPktBusEfp;
input                   rs2CdcPktBusErr;
input                   rs2CdcPktBusPreemptable;

output [`GMAC_CNT_W8-1:0]  txFifoLevel;
output                     fifoAlFull;
output [`GMAC_CNT_W8-1:0]  txFifoPeakCnt;
output [`GMAC_CNT_W32-1:0] txOverRunCnt;
output [`GMAC_CNT_W32-1:0] txUnderRunCnt;
output [`GMAC_CNT_W32-1:0] txVbErrCnt;
output [`GMAC_CNT_W8-1:0]  rxFifoLevel;
output [`GMAC_CNT_W8-1:0]  rxFifoPeakCnt;
output [`GMAC_CNT_W32-1:0] rxOverflowCnt;
output [`GMAC_CNT_W16-1:0] txInSfpCnt;
output [`GMAC_CNT_W16-1:0] txInEfpCnt;
output [`GMAC_CNT_W32-1:0] txInVbCnt;
output [`GMAC_CNT_W32-1:0] txInValidCnt;
output [`GMAC_CNT_W8-1:0]  txInErrCnt;
output [`GMAC_CNT_W16-1:0] txOutSfpCnt;
output [`GMAC_CNT_W16-1:0] txOutEfpCnt;
output [`GMAC_CNT_W32-1:0] txOutVbCnt;
output [`GMAC_CNT_W32-1:0] txOutValidCnt;
output [`GMAC_CNT_W8-1:0]  txOutErrCnt;
output [`GMAC_CNT_W16-1:0] rxInSfpCnt;
output [`GMAC_CNT_W16-1:0] rxInEfpCnt;
output [`GMAC_CNT_W32-1:0] rxInVbCnt;
output [`GMAC_CNT_W32-1:0] rxInValidCnt;
output [`GMAC_CNT_W8-1:0]  rxInErrCnt;
output [`GMAC_CNT_W16-1:0] rxOutSfpCnt;
output [`GMAC_CNT_W16-1:0] rxOutEfpCnt;
output [`GMAC_CNT_W32-1:0] rxOutVbCnt;
output [`GMAC_CNT_W32-1:0] rxOutValidCnt;
output [`GMAC_CNT_W8-1:0]  rxOutErrCnt;

//######################################################
//Value
//######################################################

wire                       rstNUsr;
wire                       rstNTx;
wire                       rstNRx;
wire                       rstNMgmt;
wire [7:0]                 fifoTxFifoThrdTx;

wire [`GMAC_CNT_W8-1:0]    txFifoLevelTx;
wire                       fifoAlFullUsr;
wire [`GMAC_CNT_W8-1:0]    txFifoPeakCntTx;
wire [`GMAC_CNT_W32-1:0]   txOverRunCntUsr;
wire [`GMAC_CNT_W32-1:0]   txUnderRunCntTx;
wire [`GMAC_CNT_W32-1:0]   txVbErrCntUsr;
wire [`GMAC_CNT_W8-1:0]    rxFifoLevelUsr;
wire [`GMAC_CNT_W8-1:0]    rxFifoPeakCntUsr;
wire [`GMAC_CNT_W32-1:0]   rxOverflowCntRx;
wire [`GMAC_CNT_W16-1:0]   txInSfpCntUsr;
wire [`GMAC_CNT_W16-1:0]   txInEfpCntUsr;
wire [`GMAC_CNT_W32-1:0]   txInVbCntUsr;
wire [`GMAC_CNT_W32-1:0]   txInValidCntUsr;
wire [`GMAC_CNT_W8-1:0]    txInErrCntUsr;
wire [`GMAC_CNT_W16-1:0]   txOutSfpCntTx;
wire [`GMAC_CNT_W16-1:0]   txOutEfpCntTx;
wire [`GMAC_CNT_W32-1:0]   txOutVbCntTx;
wire [`GMAC_CNT_W32-1:0]   txOutValidCntTx;
wire [`GMAC_CNT_W8-1:0]    txOutErrCntTx;
wire [`GMAC_CNT_W16-1:0]   rxInSfpCntRx;
wire [`GMAC_CNT_W16-1:0]   rxInEfpCntRx;
wire [`GMAC_CNT_W32-1:0]   rxInVbCntRx;
wire [`GMAC_CNT_W32-1:0]   rxInValidCntRx;
wire [`GMAC_CNT_W8-1:0]    rxInErrCntRx;
wire [`GMAC_CNT_W16-1:0]   rxOutSfpCntUsr;
wire [`GMAC_CNT_W16-1:0]   rxOutEfpCntUsr;
wire [`GMAC_CNT_W32-1:0]   rxOutVbCntUsr;
wire [`GMAC_CNT_W32-1:0]   rxOutValidCntUsr;
wire [`GMAC_CNT_W8-1:0]    rxOutErrCntUsr;

//######################################################
//Logic
//######################################################

//======================================================
// Reset：分域同步。双钟握手在 IP_AsyncFifo 内
//======================================================

    IP_ResetSync uRstUsr (
        .resetIn  (rstN),
        .clockOut (clkUsr),
        .resetOut (rstNUsr)
    );

    IP_ResetSync uRstTx (
        .resetIn  (rstN),
        .clockOut (clkTx),
        .resetOut (rstNTx)
    );

    IP_ResetSync uRstRx (
        .resetIn  (rstN),
        .clockOut (clkRx),
        .resetOut (rstNRx)
    );

    IP_ResetSync uRstMgmt (
        .resetIn  (rstN),
        .clockOut (clkMgmt),
        .resetOut (rstNMgmt)
    );

//======================================================
// CDC：阈值与状态同步到 clkMgmt
//======================================================

    IP_Sync #(.DATA_WIDTH(8)) uFifoTxFifoThrd (
        .clockIn  (clkMgmt),
        .clockOut (clkTx),
        .reset    (rstNTx),
        .dataIn   (fifoTxFifoThrd),
        .dataOut  (fifoTxFifoThrdTx)
    );

    IP_Sync #(.DATA_WIDTH(1)) uFifoAlFull (
        .clockIn  (clkUsr),
        .clockOut (clkMgmt),
        .reset    (rstNMgmt),
        .dataIn   (fifoAlFullUsr),
        .dataOut  (fifoAlFull)
    );

    IP_DataGraySync #(.DATAWIDTH(`GMAC_CNT_W8)) uTxFifoLevel (
        .clockA (clkTx),
        .dataA  (txFifoLevelTx),
        .clockB (clkMgmt),
        .dataB  (txFifoLevel)
    );

    IP_DataGraySync #(.DATAWIDTH(`GMAC_CNT_W8)) uTxFifoPeakCnt (
        .clockA (clkTx),
        .dataA  (txFifoPeakCntTx),
        .clockB (clkMgmt),
        .dataB  (txFifoPeakCnt)
    );

    IP_DataGraySync #(.DATAWIDTH(`GMAC_CNT_W32)) uTxOverRunCnt (
        .clockA (clkUsr),
        .dataA  (txOverRunCntUsr),
        .clockB (clkMgmt),
        .dataB  (txOverRunCnt)
    );

    IP_DataGraySync #(.DATAWIDTH(`GMAC_CNT_W32)) uTxUnderRunCnt (
        .clockA (clkTx),
        .dataA  (txUnderRunCntTx),
        .clockB (clkMgmt),
        .dataB  (txUnderRunCnt)
    );

    IP_DataGraySync #(.DATAWIDTH(`GMAC_CNT_W32)) uTxVbErrCnt (
        .clockA (clkUsr),
        .dataA  (txVbErrCntUsr),
        .clockB (clkMgmt),
        .dataB  (txVbErrCnt)
    );

    IP_DataGraySync #(.DATAWIDTH(`GMAC_CNT_W8)) uRxFifoLevel (
        .clockA (clkUsr),
        .dataA  (rxFifoLevelUsr),
        .clockB (clkMgmt),
        .dataB  (rxFifoLevel)
    );

    IP_DataGraySync #(.DATAWIDTH(`GMAC_CNT_W8)) uRxFifoPeakCnt (
        .clockA (clkUsr),
        .dataA  (rxFifoPeakCntUsr),
        .clockB (clkMgmt),
        .dataB  (rxFifoPeakCnt)
    );

    IP_DataGraySync #(.DATAWIDTH(`GMAC_CNT_W32)) uRxOverflowCnt (
        .clockA (clkRx),
        .dataA  (rxOverflowCntRx),
        .clockB (clkMgmt),
        .dataB  (rxOverflowCnt)
    );

    IP_DataGraySync #(.DATAWIDTH(`GMAC_CNT_W16)) uTxInSfpCnt (
        .clockA (clkUsr), .dataA (txInSfpCntUsr), .clockB (clkMgmt), .dataB (txInSfpCnt)
    );
    IP_DataGraySync #(.DATAWIDTH(`GMAC_CNT_W16)) uTxInEfpCnt (
        .clockA (clkUsr), .dataA (txInEfpCntUsr), .clockB (clkMgmt), .dataB (txInEfpCnt)
    );
    IP_DataGraySync #(.DATAWIDTH(`GMAC_CNT_W32)) uTxInVbCnt (
        .clockA (clkUsr), .dataA (txInVbCntUsr), .clockB (clkMgmt), .dataB (txInVbCnt)
    );
    IP_DataGraySync #(.DATAWIDTH(`GMAC_CNT_W32)) uTxInValidCnt (
        .clockA (clkUsr), .dataA (txInValidCntUsr), .clockB (clkMgmt), .dataB (txInValidCnt)
    );
    IP_DataGraySync #(.DATAWIDTH(`GMAC_CNT_W8)) uTxInErrCnt (
        .clockA (clkUsr), .dataA (txInErrCntUsr), .clockB (clkMgmt), .dataB (txInErrCnt)
    );

    IP_DataGraySync #(.DATAWIDTH(`GMAC_CNT_W16)) uTxOutSfpCnt (
        .clockA (clkTx), .dataA (txOutSfpCntTx), .clockB (clkMgmt), .dataB (txOutSfpCnt)
    );
    IP_DataGraySync #(.DATAWIDTH(`GMAC_CNT_W16)) uTxOutEfpCnt (
        .clockA (clkTx), .dataA (txOutEfpCntTx), .clockB (clkMgmt), .dataB (txOutEfpCnt)
    );
    IP_DataGraySync #(.DATAWIDTH(`GMAC_CNT_W32)) uTxOutVbCnt (
        .clockA (clkTx), .dataA (txOutVbCntTx), .clockB (clkMgmt), .dataB (txOutVbCnt)
    );
    IP_DataGraySync #(.DATAWIDTH(`GMAC_CNT_W32)) uTxOutValidCnt (
        .clockA (clkTx), .dataA (txOutValidCntTx), .clockB (clkMgmt), .dataB (txOutValidCnt)
    );
    IP_DataGraySync #(.DATAWIDTH(`GMAC_CNT_W8)) uTxOutErrCnt (
        .clockA (clkTx), .dataA (txOutErrCntTx), .clockB (clkMgmt), .dataB (txOutErrCnt)
    );

    IP_DataGraySync #(.DATAWIDTH(`GMAC_CNT_W16)) uRxInSfpCnt (
        .clockA (clkRx), .dataA (rxInSfpCntRx), .clockB (clkMgmt), .dataB (rxInSfpCnt)
    );
    IP_DataGraySync #(.DATAWIDTH(`GMAC_CNT_W16)) uRxInEfpCnt (
        .clockA (clkRx), .dataA (rxInEfpCntRx), .clockB (clkMgmt), .dataB (rxInEfpCnt)
    );
    IP_DataGraySync #(.DATAWIDTH(`GMAC_CNT_W32)) uRxInVbCnt (
        .clockA (clkRx), .dataA (rxInVbCntRx), .clockB (clkMgmt), .dataB (rxInVbCnt)
    );
    IP_DataGraySync #(.DATAWIDTH(`GMAC_CNT_W32)) uRxInValidCnt (
        .clockA (clkRx), .dataA (rxInValidCntRx), .clockB (clkMgmt), .dataB (rxInValidCnt)
    );
    IP_DataGraySync #(.DATAWIDTH(`GMAC_CNT_W8)) uRxInErrCnt (
        .clockA (clkRx), .dataA (rxInErrCntRx), .clockB (clkMgmt), .dataB (rxInErrCnt)
    );

    IP_DataGraySync #(.DATAWIDTH(`GMAC_CNT_W16)) uRxOutSfpCnt (
        .clockA (clkUsr), .dataA (rxOutSfpCntUsr), .clockB (clkMgmt), .dataB (rxOutSfpCnt)
    );
    IP_DataGraySync #(.DATAWIDTH(`GMAC_CNT_W16)) uRxOutEfpCnt (
        .clockA (clkUsr), .dataA (rxOutEfpCntUsr), .clockB (clkMgmt), .dataB (rxOutEfpCnt)
    );
    IP_DataGraySync #(.DATAWIDTH(`GMAC_CNT_W32)) uRxOutVbCnt (
        .clockA (clkUsr), .dataA (rxOutVbCntUsr), .clockB (clkMgmt), .dataB (rxOutVbCnt)
    );
    IP_DataGraySync #(.DATAWIDTH(`GMAC_CNT_W32)) uRxOutValidCnt (
        .clockA (clkUsr), .dataA (rxOutValidCntUsr), .clockB (clkMgmt), .dataB (rxOutValidCnt)
    );
    IP_DataGraySync #(.DATAWIDTH(`GMAC_CNT_W8)) uRxOutErrCnt (
        .clockA (clkUsr), .dataA (rxOutErrCntUsr), .clockB (clkMgmt), .dataB (rxOutErrCnt)
    );

//======================================================
// Submods：Tx/Rx 位宽桥
//======================================================

    UsrRsCdcTx #(
        .USR_DATA_W        (USR_DATA_W),
        .FIFO_DEPTH        (FIFO_DEPTH),
        .FIFO_AL_FULL_THRD (FIFO_AL_FULL_THRD)
    ) uUsrRsCdcTx (
        .clkUsr                    (clkUsr),
        .clkTx                     (clkTx),
        .rstNUsr                   (rstNUsr),
        .rstNTx                    (rstNTx),
        .usr2CdcPktBusData         (usr2CdcPktBusData),
        .usr2CdcPktBusVb           (usr2CdcPktBusVb),
        .usr2CdcPktBusValid        (usr2CdcPktBusValid),
        .usr2CdcPktBusSfp          (usr2CdcPktBusSfp),
        .usr2CdcPktBusEfp          (usr2CdcPktBusEfp),
        .usr2CdcPktBusErr          (usr2CdcPktBusErr),
        .usr2CdcPktBusPreemptable  (usr2CdcPktBusPreemptable),
        .usr2CdcPktBusStall        (usr2CdcPktBusStall),
        .cdc2RsPktBusData          (cdc2RsPktBusData),
        .cdc2RsPktBusValid         (cdc2RsPktBusValid),
        .cdc2RsPktBusSfp           (cdc2RsPktBusSfp),
        .cdc2RsPktBusEfp           (cdc2RsPktBusEfp),
        .cdc2RsPktBusErr           (cdc2RsPktBusErr),
        .cdc2RsPktBusPreemptable   (cdc2RsPktBusPreemptable),
        .cdc2RsPktBusStall         (cdc2RsPktBusStall),
        .fifoTxFifoThrd            (fifoTxFifoThrdTx),
        .txFifoLevel               (txFifoLevelTx),
        .fifoAlFull                (fifoAlFullUsr),
        .txFifoPeakCnt             (txFifoPeakCntTx),
        .txOverRunCnt              (txOverRunCntUsr),
        .txUnderRunCnt             (txUnderRunCntTx),
        .txVbErrCnt                (txVbErrCntUsr),
        .txInSfpCnt                (txInSfpCntUsr),
        .txInEfpCnt                (txInEfpCntUsr),
        .txInVbCnt                 (txInVbCntUsr),
        .txInValidCnt              (txInValidCntUsr),
        .txInErrCnt                (txInErrCntUsr),
        .txOutSfpCnt               (txOutSfpCntTx),
        .txOutEfpCnt               (txOutEfpCntTx),
        .txOutVbCnt                (txOutVbCntTx),
        .txOutValidCnt             (txOutValidCntTx),
        .txOutErrCnt               (txOutErrCntTx)
    );

    UsrRsCdcRx #(
        .USR_DATA_W (USR_DATA_W),
        .FIFO_DEPTH (FIFO_DEPTH)
    ) uUsrRsCdcRx (
        .clkRx                     (clkRx),
        .clkUsr                    (clkUsr),
        .rstNRx                    (rstNRx),
        .rstNUsr                   (rstNUsr),
        .rs2CdcPktBusData          (rs2CdcPktBusData),
        .rs2CdcPktBusValid         (rs2CdcPktBusValid),
        .rs2CdcPktBusSfp           (rs2CdcPktBusSfp),
        .rs2CdcPktBusEfp           (rs2CdcPktBusEfp),
        .rs2CdcPktBusErr           (rs2CdcPktBusErr),
        .rs2CdcPktBusPreemptable   (rs2CdcPktBusPreemptable),
        .cdc2UsrPktBusData         (cdc2UsrPktBusData),
        .cdc2UsrPktBusVb           (cdc2UsrPktBusVb),
        .cdc2UsrPktBusValid        (cdc2UsrPktBusValid),
        .cdc2UsrPktBusSfp          (cdc2UsrPktBusSfp),
        .cdc2UsrPktBusEfp          (cdc2UsrPktBusEfp),
        .cdc2UsrPktBusErr          (cdc2UsrPktBusErr),
        .cdc2UsrPktBusPreemptable  (cdc2UsrPktBusPreemptable),
        .rxFifoLevel               (rxFifoLevelUsr),
        .rxFifoPeakCnt             (rxFifoPeakCntUsr),
        .rxOverflowCnt             (rxOverflowCntRx),
        .rxInSfpCnt                (rxInSfpCntRx),
        .rxInEfpCnt                (rxInEfpCntRx),
        .rxInVbCnt                 (rxInVbCntRx),
        .rxInValidCnt              (rxInValidCntRx),
        .rxInErrCnt                (rxInErrCntRx),
        .rxOutSfpCnt               (rxOutSfpCntUsr),
        .rxOutEfpCnt               (rxOutEfpCntUsr),
        .rxOutVbCnt                (rxOutVbCntUsr),
        .rxOutValidCnt             (rxOutValidCntUsr),
        .rxOutErrCnt               (rxOutErrCntUsr)
    );

endmodule
