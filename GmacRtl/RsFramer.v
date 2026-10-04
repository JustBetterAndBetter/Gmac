// +FHDR----------------------------------------------------------------------------
// Device        : Xilinx
// Author        : fxdqe
// Email         : 1706260166@qq.com
// Created On    : 2026/09/16 21:05
// File Name     : RsFramer.v
// Description   : 以太网成帧/解析；rstN 为 rstNCore，内部同步到 tx/rx/mgmt。
//
// ---------------------------------------------------------------------------------
// Modification History:
// Date         By              Version                 Change Description
// ---------------------------------------------------------------------------------
// 2026/09/16   fxdqe           1.0                     Interface template
// 2026/09/18   fxdqe           1.1                     单路复位，分域同步
// 2026/10/01   fxdqe           1.2                     Cnt 命名 / W32
// 2026/10/01   fxdqe           1.3                     分域复位改用 IP_ResetSync
// 2026/10/02   fxdqe           1.4                     帧长配置同步到 clkTx
// 2026/10/03   fxdqe           1.5                     去掉 rsTxState / ifgCnt，Tx 计数改 16 位
// 2026/10/03   fxdqe           1.6                     rxDelCrc 同步到 clkRx
// -FHDR----------------------------------------------------------------------------

`include "GmacIf.vh"

module RsFramer(/*autoarg*/
        //Inputs
        clkTx, clkRx, clkMgmt, rstN, ifgCntMax, lenCntMin, lenCntMax, rxDelCrc, pcs2RsSyncStatus,
        cdc2RsPktBusData, cdc2RsPktBusValid, cdc2RsPktBusSfp,
        cdc2RsPktBusEfp, cdc2RsPktBusErr, cdc2RsPktBusPreemptable,
        rs2PcsPktBusStall, pcs2RsPktBusData, pcs2RsPktBusValid,
        pcs2RsPktBusSfp, pcs2RsPktBusEfp, pcs2RsPktBusErr,
        pcs2RsPktBusPreemptable,
        //Outputs
        cdc2RsPktBusStall, rs2CdcPktBusData, rs2CdcPktBusValid,
        rs2CdcPktBusSfp, rs2CdcPktBusEfp, rs2CdcPktBusErr,
        rs2CdcPktBusPreemptable, rs2PcsPktBusData, rs2PcsPktBusValid,
        rs2PcsPktBusSfp, rs2PcsPktBusEfp, rs2PcsPktBusErr,
        rs2PcsPktBusPreemptable, txBusy, padCnt, txOversizeCnt,
        txUnderrunCnt, txSfdCnt, rsRxState, rxCrcErrCnt,
        rxSfdCnt
);

//######################################################
//Interface
//######################################################

input                   clkTx;
input                   clkRx;
input                   clkMgmt;
input                   rstN;
input  [3:0]            ifgCntMax;
input  [10:0]           lenCntMin;
input  [10:0]           lenCntMax;
input                   rxDelCrc;
input                   pcs2RsSyncStatus;

input  [`GMAC_BYTE_W-1:0] cdc2RsPktBusData;
input                   cdc2RsPktBusValid;
input                   cdc2RsPktBusSfp;
input                   cdc2RsPktBusEfp;
input                   cdc2RsPktBusErr;
input                   cdc2RsPktBusPreemptable;
output                  cdc2RsPktBusStall;

output [`GMAC_BYTE_W-1:0] rs2CdcPktBusData;
output                  rs2CdcPktBusValid;
output                  rs2CdcPktBusSfp;
output                  rs2CdcPktBusEfp;
output                  rs2CdcPktBusErr;
output                  rs2CdcPktBusPreemptable;

output [`GMAC_BYTE_W-1:0] rs2PcsPktBusData;
output                  rs2PcsPktBusValid;
output                  rs2PcsPktBusSfp;
output                  rs2PcsPktBusEfp;
output                  rs2PcsPktBusErr;
output                  rs2PcsPktBusPreemptable;
input                   rs2PcsPktBusStall;

input  [`GMAC_BYTE_W-1:0] pcs2RsPktBusData;
input                   pcs2RsPktBusValid;
input                   pcs2RsPktBusSfp;
input                   pcs2RsPktBusEfp;
input                   pcs2RsPktBusErr;
input                   pcs2RsPktBusPreemptable;

output                  txBusy;
output [10:0]           padCnt;
output [`GMAC_CNT_W16-1:0] txOversizeCnt;
output [`GMAC_CNT_W16-1:0] txUnderrunCnt;
output [`GMAC_CNT_W16-1:0] txSfdCnt;
output [1:0]            rsRxState;
output [`GMAC_CNT_W32-1:0] rxCrcErrCnt;
output [`GMAC_CNT_W32-1:0] rxSfdCnt;

//######################################################
//Value
//######################################################

wire                       rstNTx;
wire                       rstNRx;
wire                       rstNMgmt;

wire [3:0]                 ifgCntMaxTx;
wire [10:0]                lenCntMinTx;
wire [10:0]                lenCntMaxTx;
wire                       rxDelCrcRx;
wire                       txBusyTx;
wire [10:0]                padCntTx;
wire [`GMAC_CNT_W16-1:0]   txOversizeCntTx;
wire [`GMAC_CNT_W16-1:0]   txUnderrunCntTx;
wire [`GMAC_CNT_W16-1:0]   txSfdCntTx;
wire [1:0]                 rsRxStateRx;
wire [`GMAC_CNT_W32-1:0]   rxCrcErrCntRx;
wire [`GMAC_CNT_W32-1:0]   rxSfdCntRx;

//######################################################
//Logic
//######################################################

//======================================================
// Reset：分域同步
//======================================================

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
// CDC：状态与计数同步到 clkMgmt
//======================================================

    IP_Sync #(.DATA_WIDTH(4)) uIfgCntMax (
        .clockIn  (clkMgmt),
        .clockOut (clkTx),
        .reset    (rstNTx),
        .dataIn   (ifgCntMax),
        .dataOut  (ifgCntMaxTx)
    );

    IP_Sync #(.DATA_WIDTH(11)) uLenCntMin (
        .clockIn  (clkMgmt),
        .clockOut (clkTx),
        .reset    (rstNTx),
        .dataIn   (lenCntMin),
        .dataOut  (lenCntMinTx)
    );

    IP_Sync #(.DATA_WIDTH(11)) uLenCntMax (
        .clockIn  (clkMgmt),
        .clockOut (clkTx),
        .reset    (rstNTx),
        .dataIn   (lenCntMax),
        .dataOut  (lenCntMaxTx)
    );

    IP_Sync #(.DATA_WIDTH(1)) uRxDelCrc (
        .clockIn  (clkMgmt),
        .clockOut (clkRx),
        .reset    (rstNRx),
        .dataIn   (rxDelCrc),
        .dataOut  (rxDelCrcRx)
    );

    IP_Sync #(.DATA_WIDTH(1)) uTxBusy (
        .clockIn  (clkTx),
        .clockOut (clkMgmt),
        .reset    (rstNMgmt),
        .dataIn   (txBusyTx),
        .dataOut  (txBusy)
    );

    IP_DataGraySync #(.DATAWIDTH(11)) uPadCnt (
        .clockA (clkTx),
        .dataA  (padCntTx),
        .clockB (clkMgmt),
        .dataB  (padCnt)
    );

    IP_DataGraySync #(.DATAWIDTH(`GMAC_CNT_W16)) uTxOversizeCnt (
        .clockA (clkTx),
        .dataA  (txOversizeCntTx),
        .clockB (clkMgmt),
        .dataB  (txOversizeCnt)
    );

    IP_DataGraySync #(.DATAWIDTH(`GMAC_CNT_W16)) uTxUnderrunCnt (
        .clockA (clkTx),
        .dataA  (txUnderrunCntTx),
        .clockB (clkMgmt),
        .dataB  (txUnderrunCnt)
    );

    IP_DataGraySync #(.DATAWIDTH(`GMAC_CNT_W16)) uTxSfdCnt (
        .clockA (clkTx),
        .dataA  (txSfdCntTx),
        .clockB (clkMgmt),
        .dataB  (txSfdCnt)
    );

    IP_Sync #(.DATA_WIDTH(2)) uRsRxState (
        .clockIn  (clkRx),
        .clockOut (clkMgmt),
        .reset    (rstNMgmt),
        .dataIn   (rsRxStateRx),
        .dataOut  (rsRxState)
    );

    IP_DataGraySync #(.DATAWIDTH(`GMAC_CNT_W32)) uRxCrcErrCnt (
        .clockA (clkRx),
        .dataA  (rxCrcErrCntRx),
        .clockB (clkMgmt),
        .dataB  (rxCrcErrCnt)
    );

    IP_DataGraySync #(.DATAWIDTH(`GMAC_CNT_W32)) uRxSfdCnt (
        .clockA (clkRx),
        .dataA  (rxSfdCntRx),
        .clockB (clkMgmt),
        .dataB  (rxSfdCnt)
    );

//======================================================
// Submods：Tx 成帧 / Rx 解析
//======================================================

    RsTxFramer uRsTxFramer (
        .clkTx                     (clkTx),
        .rstN                      (rstNTx),
        .ifgCntMax                 (ifgCntMaxTx),
        .lenCntMin                 (lenCntMinTx),
        .lenCntMax                 (lenCntMaxTx),
        .cdc2RsPktBusData          (cdc2RsPktBusData),
        .cdc2RsPktBusValid         (cdc2RsPktBusValid),
        .cdc2RsPktBusSfp           (cdc2RsPktBusSfp),
        .cdc2RsPktBusEfp           (cdc2RsPktBusEfp),
        .cdc2RsPktBusErr           (cdc2RsPktBusErr),
        .cdc2RsPktBusPreemptable   (cdc2RsPktBusPreemptable),
        .cdc2RsPktBusStall         (cdc2RsPktBusStall),
        .rs2PcsPktBusData          (rs2PcsPktBusData),
        .rs2PcsPktBusValid         (rs2PcsPktBusValid),
        .rs2PcsPktBusSfp           (rs2PcsPktBusSfp),
        .rs2PcsPktBusEfp           (rs2PcsPktBusEfp),
        .rs2PcsPktBusErr           (rs2PcsPktBusErr),
        .rs2PcsPktBusPreemptable   (rs2PcsPktBusPreemptable),
        .rs2PcsPktBusStall         (rs2PcsPktBusStall),
        .txBusy                    (txBusyTx),
        .padCnt                    (padCntTx),
        .txOversizeCnt             (txOversizeCntTx),
        .txUnderrunCnt             (txUnderrunCntTx),
        .txSfdCnt                  (txSfdCntTx)
    );

    RsRxParser uRsRxParser (
        .clkRx                     (clkRx),
        .rstN                      (rstNRx),
        .pcs2RsSyncStatus          (pcs2RsSyncStatus),
        .rxDelCrc                  (rxDelCrcRx),
        .pcs2RsPktBusData          (pcs2RsPktBusData),
        .pcs2RsPktBusValid         (pcs2RsPktBusValid),
        .pcs2RsPktBusSfp           (pcs2RsPktBusSfp),
        .pcs2RsPktBusEfp           (pcs2RsPktBusEfp),
        .pcs2RsPktBusErr           (pcs2RsPktBusErr),
        .pcs2RsPktBusPreemptable   (pcs2RsPktBusPreemptable),
        .rs2CdcPktBusData          (rs2CdcPktBusData),
        .rs2CdcPktBusValid         (rs2CdcPktBusValid),
        .rs2CdcPktBusSfp           (rs2CdcPktBusSfp),
        .rs2CdcPktBusEfp           (rs2CdcPktBusEfp),
        .rs2CdcPktBusErr           (rs2CdcPktBusErr),
        .rs2CdcPktBusPreemptable   (rs2CdcPktBusPreemptable),
        .rsRxState                 (rsRxStateRx),
        .rxCrcErrCnt               (rxCrcErrCntRx),
        .rxSfdCnt                  (rxSfdCntRx)
    );

endmodule
