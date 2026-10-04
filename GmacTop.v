// +FHDR----------------------------------------------------------------------------
// Device        : Xilinx
// Author        : fxdqe
// Email         : 1706260166@qq.com
// Created On    : 2026/09/16 21:05
// File Name     : GmacTop.v
// Description   : 1G GMAC 顶层：UsrRsWidthCdc / RsFramer / PcsCodec / PcsSdsGearbox / GmacReg
//                 外部 rstN 只进 GmacReg 与 GmacRst；GmacRst 输出 rstNCore 给数据通路。
//
// ---------------------------------------------------------------------------------
// Modification History:
// Date         By              Version                 Change Description
// ---------------------------------------------------------------------------------
// 2026/09/16   fxdqe           1.0                     Interface template
// 2026/09/18   fxdqe           1.1                     复位只从寄存器软复位模块分发
// 2026/10/01   fxdqe           1.2                     Cnt/F1 命名与 W32
// 2026/10/01   fxdqe           1.3                     口计数接到寄存器
// 2026/10/02   fxdqe           1.4                     帧长配置接到寄存器
// 2026/10/03   fxdqe           1.5                     去掉 rsTxState / ifgCnt，Tx 计数改 16 位
// 2026/10/03   fxdqe           1.6                     rxDelCrc 接到寄存器
// 2026/10/04   fxdqe           1.7                     环回 FIFO 水位阈值接到寄存器
// 2026/10/04   fxdqe           1.8                     Gearbox 读侧水位接到寄存器
// -FHDR----------------------------------------------------------------------------

`include "GmacIf.vh"

module GmacTop(/*autoarg*/
        //Inputs
        clkUsr, clkTx, clkRx, clkSdsTx, clkSdsRx, clkMgmt, rstN,
        usr2CdcPktBusData, usr2CdcPktBusVb, usr2CdcPktBusValid, usr2CdcPktBusSfp,
        usr2CdcPktBusEfp, usr2CdcPktBusErr, usr2CdcPktBusPreemptable,
        sds2GbxRxBusData, wr, wrAddr, wrData, rd, rdAddr,
        //Outputs
        usr2CdcPktBusStall, cdc2UsrPktBusData, cdc2UsrPktBusVb, cdc2UsrPktBusValid,
        cdc2UsrPktBusSfp, cdc2UsrPktBusEfp, cdc2UsrPktBusErr,
        cdc2UsrPktBusPreemptable, gbx2SdsTxBusData, wrAck, wrErr,
        rdAck, rdErr, rdData, irq
);

//######################################################
//Interface
//######################################################

parameter USR_DATA_W        = `GMAC_USR_W;
parameter FIFO_DEPTH        = 16;
parameter FIFO_AL_FULL_THRD = FIFO_DEPTH - 3;
parameter DATE              = 32'h20260916;
parameter USER              = 16'h0001;
parameter VERSION           = 16'h0001;

input                   clkUsr;
input                   clkTx;
input                   clkRx;
input                   clkSdsTx;
input                   clkSdsRx;
input                   clkMgmt;
input                   rstN;

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

output [`GMAC_SDS_W-1:0]  gbx2SdsTxBusData;
input  [`GMAC_SDS_W-1:0]  sds2GbxRxBusData;

input                   wr;
input  [`GMAC_ADDR_W-1:0] wrAddr;
input  [`GMAC_REG_W-1:0]  wrData;
output                  wrAck;
output                  wrErr;
input                   rd;
input  [`GMAC_ADDR_W-1:0] rdAddr;
output                  rdAck;
output                  rdErr;
output [`GMAC_REG_W-1:0]  rdData;
output                  irq;

//######################################################
//Value
//######################################################

wire                       softRstN;
wire                       rstNCore;
wire                       txEn;
wire                       rxEn;
wire                       loopback;
wire [7:0]                 fifoTxFifoThrd;
wire [7:0]                 loopbackAlFullThrd;
wire [7:0]                 loopbackAlEmptyThrd;
wire [7:0]                 gbxTxFifoThrd;
wire [7:0]                 gbxRxFifoThrd;
wire [3:0]                 ifgCntMax;
wire [10:0]                lenCntMin;
wire [10:0]                lenCntMax;
wire                       rxDelCrc;
wire [`GMAC_REG_W-1:0]     irqMask;
wire [`GMAC_REG_W-1:0]     irqRaw;

wire [`GMAC_BYTE_W-1:0]    cdc2RsPktBusData;
wire                       cdc2RsPktBusValid;
wire                       cdc2RsPktBusSfp;
wire                       cdc2RsPktBusEfp;
wire                       cdc2RsPktBusErr;
wire                       cdc2RsPktBusPreemptable;
wire                       cdc2RsPktBusStall;

wire [`GMAC_BYTE_W-1:0]    rs2CdcPktBusData;
wire                       rs2CdcPktBusValid;
wire                       rs2CdcPktBusSfp;
wire                       rs2CdcPktBusEfp;
wire                       rs2CdcPktBusErr;
wire                       rs2CdcPktBusPreemptable;

wire [`GMAC_BYTE_W-1:0]    rs2PcsPktBusData;
wire                       rs2PcsPktBusValid;
wire                       rs2PcsPktBusSfp;
wire                       rs2PcsPktBusEfp;
wire                       rs2PcsPktBusErr;
wire                       rs2PcsPktBusPreemptable;
wire                       rs2PcsPktBusStall;

wire [`GMAC_BYTE_W-1:0]    pcs2RsPktBusData;
wire                       pcs2RsPktBusValid;
wire                       pcs2RsPktBusSfp;
wire                       pcs2RsPktBusEfp;
wire                       pcs2RsPktBusErr;
wire                       pcs2RsPktBusPreemptable;

wire [`GMAC_CODE_W-1:0]    pcs2GbxCodeBusCodeGroup;
wire [`GMAC_CODE_W-1:0]    gbx2PcsCodeBusCodeGroup;

wire                       pcs2RsSyncStatus;
wire                       pcsRxSync;
wire [`GMAC_CNT_W8-1:0]    txFifoLevel;
wire                       fifoAlFull;
wire [`GMAC_CNT_W8-1:0]    txFifoPeakCnt;
wire [`GMAC_CNT_W32-1:0]   txOverRunCnt;
wire [`GMAC_CNT_W32-1:0]   txUnderRunCnt;
wire [`GMAC_CNT_W32-1:0]   txVbErrCnt;
wire [`GMAC_CNT_W8-1:0]    rxFifoLevel;
wire [`GMAC_CNT_W8-1:0]    rxFifoPeakCnt;
wire [`GMAC_CNT_W32-1:0]   rxOverflowCnt;
wire [`GMAC_CNT_W16-1:0]   txInSfpCnt;
wire [`GMAC_CNT_W16-1:0]   txInEfpCnt;
wire [`GMAC_CNT_W32-1:0]   txInVbCnt;
wire [`GMAC_CNT_W32-1:0]   txInValidCnt;
wire [`GMAC_CNT_W8-1:0]    txInErrCnt;
wire [`GMAC_CNT_W16-1:0]   txOutSfpCnt;
wire [`GMAC_CNT_W16-1:0]   txOutEfpCnt;
wire [`GMAC_CNT_W32-1:0]   txOutVbCnt;
wire [`GMAC_CNT_W32-1:0]   txOutValidCnt;
wire [`GMAC_CNT_W8-1:0]    txOutErrCnt;
wire [`GMAC_CNT_W16-1:0]   rxInSfpCnt;
wire [`GMAC_CNT_W16-1:0]   rxInEfpCnt;
wire [`GMAC_CNT_W32-1:0]   rxInVbCnt;
wire [`GMAC_CNT_W32-1:0]   rxInValidCnt;
wire [`GMAC_CNT_W8-1:0]    rxInErrCnt;
wire [`GMAC_CNT_W16-1:0]   rxOutSfpCnt;
wire [`GMAC_CNT_W16-1:0]   rxOutEfpCnt;
wire [`GMAC_CNT_W32-1:0]   rxOutVbCnt;
wire [`GMAC_CNT_W32-1:0]   rxOutValidCnt;
wire [`GMAC_CNT_W8-1:0]    rxOutErrCnt;
wire                       txBusy;
wire [10:0]                padCnt;
wire [`GMAC_CNT_W16-1:0]   txOversizeCnt;
wire [`GMAC_CNT_W16-1:0]   txUnderrunCnt;
wire [`GMAC_CNT_W16-1:0]   txSfdCnt;
wire [1:0]                 rsRxState;
wire [`GMAC_CNT_W32-1:0]   rxCrcErrCnt;
wire [`GMAC_CNT_W32-1:0]   rxSfdCnt;
wire [1:0]                 pcsTxState;
wire                       pcsTxEven;
wire                       pcsTxRd;
wire [2:0]                 pcsRxSyncState;
wire                       pcsRxEven;
wire                       pcsRxRd;
wire [`GMAC_CNT_W32-1:0]   lossOfSyncCnt;
wire [`GMAC_CNT_W32-1:0]   codeVCnt;
reg  [7:0]                 irqEvt;
reg  [`GMAC_CNT_W32-1:0]   txOverRunCntF1;
reg  [`GMAC_CNT_W32-1:0]   txUnderRunCntF1;
reg  [`GMAC_CNT_W32-1:0]   rxOverflowCntF1;
reg  [`GMAC_CNT_W16-1:0]   txOversizeCntF1;
reg  [`GMAC_CNT_W16-1:0]   txUnderrunCntF1;
reg  [`GMAC_CNT_W32-1:0]   rxCrcErrCntF1;
reg  [`GMAC_CNT_W32-1:0]   lossOfSyncCntF1;
reg  [`GMAC_CNT_W32-1:0]   codeVCntF1;
wire                       irqClr;
wire [`GMAC_ADDR_W-1:0]    irqClrAddr;

//######################################################
//Logic
//######################################################

//======================================================
// Reset
//======================================================

    assign irqClrAddr = {{(`GMAC_ADDR_W-9){1'b0}}, 9'h118};
    assign irqClr     = wr & (wrAddr == irqClrAddr);

    GmacRst uGmacRst (
        .clkMgmt  (clkMgmt),
        .rstN     (rstN),
        .softRstN (softRstN),
        .rstNCore (rstNCore)
    );

//======================================================
// Irq：计数边沿采事件（irq* 名保持规划文档约定）
//======================================================

    always@(posedge clkMgmt or negedge rstN) begin
        if (!rstN) begin
            irqEvt           <= 8'h0;
            txOverRunCntF1   <= {`GMAC_CNT_W32{1'b0}};
            txUnderRunCntF1  <= {`GMAC_CNT_W32{1'b0}};
            rxOverflowCntF1  <= {`GMAC_CNT_W32{1'b0}};
            txOversizeCntF1  <= {`GMAC_CNT_W16{1'b0}};
            txUnderrunCntF1  <= {`GMAC_CNT_W16{1'b0}};
            rxCrcErrCntF1    <= {`GMAC_CNT_W32{1'b0}};
            lossOfSyncCntF1  <= {`GMAC_CNT_W32{1'b0}};
            codeVCntF1       <= {`GMAC_CNT_W32{1'b0}};
        end
        else if (!rstNCore) begin
            irqEvt           <= 8'h0;
            txOverRunCntF1   <= {`GMAC_CNT_W32{1'b0}};
            txUnderRunCntF1  <= {`GMAC_CNT_W32{1'b0}};
            rxOverflowCntF1  <= {`GMAC_CNT_W32{1'b0}};
            txOversizeCntF1  <= {`GMAC_CNT_W16{1'b0}};
            txUnderrunCntF1  <= {`GMAC_CNT_W16{1'b0}};
            rxCrcErrCntF1    <= {`GMAC_CNT_W32{1'b0}};
            lossOfSyncCntF1  <= {`GMAC_CNT_W32{1'b0}};
            codeVCntF1       <= {`GMAC_CNT_W32{1'b0}};
        end
        else begin
            txOverRunCntF1   <= txOverRunCnt;
            txUnderRunCntF1  <= txUnderRunCnt;
            rxOverflowCntF1  <= rxOverflowCnt;
            txOversizeCntF1  <= txOversizeCnt;
            txUnderrunCntF1  <= txUnderrunCnt;
            rxCrcErrCntF1    <= rxCrcErrCnt;
            lossOfSyncCntF1  <= lossOfSyncCnt;
            codeVCntF1       <= codeVCnt;

            if (irqClr) begin
                irqEvt <= 8'h0;
            end
            else begin
                if (txOverRunCnt   != txOverRunCntF1)   irqEvt[0] <= 1'b1;
                if (txUnderRunCnt  != txUnderRunCntF1)  irqEvt[1] <= 1'b1;
                if (rxOverflowCnt  != rxOverflowCntF1)  irqEvt[2] <= 1'b1;
                if (txUnderrunCnt  != txUnderrunCntF1)  irqEvt[3] <= 1'b1;
                if (txOversizeCnt  != txOversizeCntF1)  irqEvt[4] <= 1'b1;
                if (rxCrcErrCnt    != rxCrcErrCntF1)    irqEvt[5] <= 1'b1;
                if (lossOfSyncCnt  != lossOfSyncCntF1)  irqEvt[6] <= 1'b1;
                if (codeVCnt       != codeVCntF1)       irqEvt[7] <= 1'b1;
            end
        end
    end

    assign irqRaw = {{(`GMAC_REG_W-11){1'b0}},
                     irqEvt[7],
                     irqEvt[6],
                     irqEvt[5],
                     irqEvt[4],
                     irqEvt[3],
                     irqEvt[2],
                     irqEvt[1],
                     irqEvt[0],
                     txBusy,
                     ~pcsRxSync,
                     fifoAlFull};
    assign irq = |(irqRaw & irqMask);

//======================================================
// Datapath wrappers
//======================================================

    UsrRsWidthCdc #(
        .USR_DATA_W        (USR_DATA_W),
        .FIFO_DEPTH        (FIFO_DEPTH),
        .FIFO_AL_FULL_THRD (FIFO_AL_FULL_THRD)
    ) uUsrRsWidthCdc (
        .clkUsr                    (clkUsr),
        .clkTx                     (clkTx),
        .clkRx                     (clkRx),
        .clkMgmt                   (clkMgmt),
        .rstN                      (rstNCore),
        .fifoTxFifoThrd            (fifoTxFifoThrd),
        .usr2CdcPktBusData         (usr2CdcPktBusData),
        .usr2CdcPktBusVb           (usr2CdcPktBusVb),
        .usr2CdcPktBusValid        (usr2CdcPktBusValid),
        .usr2CdcPktBusSfp          (usr2CdcPktBusSfp),
        .usr2CdcPktBusEfp          (usr2CdcPktBusEfp),
        .usr2CdcPktBusErr          (usr2CdcPktBusErr),
        .usr2CdcPktBusPreemptable  (usr2CdcPktBusPreemptable),
        .usr2CdcPktBusStall        (usr2CdcPktBusStall),
        .cdc2UsrPktBusData         (cdc2UsrPktBusData),
        .cdc2UsrPktBusVb           (cdc2UsrPktBusVb),
        .cdc2UsrPktBusValid        (cdc2UsrPktBusValid),
        .cdc2UsrPktBusSfp          (cdc2UsrPktBusSfp),
        .cdc2UsrPktBusEfp          (cdc2UsrPktBusEfp),
        .cdc2UsrPktBusErr          (cdc2UsrPktBusErr),
        .cdc2UsrPktBusPreemptable  (cdc2UsrPktBusPreemptable),
        .cdc2RsPktBusData          (cdc2RsPktBusData),
        .cdc2RsPktBusValid         (cdc2RsPktBusValid),
        .cdc2RsPktBusSfp           (cdc2RsPktBusSfp),
        .cdc2RsPktBusEfp           (cdc2RsPktBusEfp),
        .cdc2RsPktBusErr           (cdc2RsPktBusErr),
        .cdc2RsPktBusPreemptable   (cdc2RsPktBusPreemptable),
        .cdc2RsPktBusStall         (cdc2RsPktBusStall),
        .rs2CdcPktBusData          (rs2CdcPktBusData),
        .rs2CdcPktBusValid         (rs2CdcPktBusValid),
        .rs2CdcPktBusSfp           (rs2CdcPktBusSfp),
        .rs2CdcPktBusEfp           (rs2CdcPktBusEfp),
        .rs2CdcPktBusErr           (rs2CdcPktBusErr),
        .rs2CdcPktBusPreemptable   (rs2CdcPktBusPreemptable),
        .txFifoLevel               (txFifoLevel),
        .fifoAlFull                (fifoAlFull),
        .txFifoPeakCnt             (txFifoPeakCnt),
        .txOverRunCnt              (txOverRunCnt),
        .txUnderRunCnt             (txUnderRunCnt),
        .txVbErrCnt                (txVbErrCnt),
        .rxFifoLevel               (rxFifoLevel),
        .rxFifoPeakCnt             (rxFifoPeakCnt),
        .rxOverflowCnt             (rxOverflowCnt),
        .txInSfpCnt                (txInSfpCnt),
        .txInEfpCnt                (txInEfpCnt),
        .txInVbCnt                 (txInVbCnt),
        .txInValidCnt              (txInValidCnt),
        .txInErrCnt                (txInErrCnt),
        .txOutSfpCnt               (txOutSfpCnt),
        .txOutEfpCnt               (txOutEfpCnt),
        .txOutVbCnt                (txOutVbCnt),
        .txOutValidCnt             (txOutValidCnt),
        .txOutErrCnt               (txOutErrCnt),
        .rxInSfpCnt                (rxInSfpCnt),
        .rxInEfpCnt                (rxInEfpCnt),
        .rxInVbCnt                 (rxInVbCnt),
        .rxInValidCnt              (rxInValidCnt),
        .rxInErrCnt                (rxInErrCnt),
        .rxOutSfpCnt               (rxOutSfpCnt),
        .rxOutEfpCnt               (rxOutEfpCnt),
        .rxOutVbCnt                (rxOutVbCnt),
        .rxOutValidCnt             (rxOutValidCnt),
        .rxOutErrCnt               (rxOutErrCnt)
    );

    RsFramer uRsFramer (
        .clkTx                     (clkTx),
        .clkRx                     (clkRx),
        .clkMgmt                   (clkMgmt),
        .rstN                      (rstNCore),
        .ifgCntMax                 (ifgCntMax),
        .lenCntMin                 (lenCntMin),
        .lenCntMax                 (lenCntMax),
        .rxDelCrc                  (rxDelCrc),
        .pcs2RsSyncStatus          (pcs2RsSyncStatus),
        .cdc2RsPktBusData          (cdc2RsPktBusData),
        .cdc2RsPktBusValid         (cdc2RsPktBusValid),
        .cdc2RsPktBusSfp           (cdc2RsPktBusSfp),
        .cdc2RsPktBusEfp           (cdc2RsPktBusEfp),
        .cdc2RsPktBusErr           (cdc2RsPktBusErr),
        .cdc2RsPktBusPreemptable   (cdc2RsPktBusPreemptable),
        .cdc2RsPktBusStall         (cdc2RsPktBusStall),
        .rs2CdcPktBusData          (rs2CdcPktBusData),
        .rs2CdcPktBusValid         (rs2CdcPktBusValid),
        .rs2CdcPktBusSfp           (rs2CdcPktBusSfp),
        .rs2CdcPktBusEfp           (rs2CdcPktBusEfp),
        .rs2CdcPktBusErr           (rs2CdcPktBusErr),
        .rs2CdcPktBusPreemptable   (rs2CdcPktBusPreemptable),
        .rs2PcsPktBusData          (rs2PcsPktBusData),
        .rs2PcsPktBusValid         (rs2PcsPktBusValid),
        .rs2PcsPktBusSfp           (rs2PcsPktBusSfp),
        .rs2PcsPktBusEfp           (rs2PcsPktBusEfp),
        .rs2PcsPktBusErr           (rs2PcsPktBusErr),
        .rs2PcsPktBusPreemptable   (rs2PcsPktBusPreemptable),
        .rs2PcsPktBusStall         (rs2PcsPktBusStall),
        .pcs2RsPktBusData          (pcs2RsPktBusData),
        .pcs2RsPktBusValid         (pcs2RsPktBusValid),
        .pcs2RsPktBusSfp           (pcs2RsPktBusSfp),
        .pcs2RsPktBusEfp           (pcs2RsPktBusEfp),
        .pcs2RsPktBusErr           (pcs2RsPktBusErr),
        .pcs2RsPktBusPreemptable   (pcs2RsPktBusPreemptable),
        .txBusy                    (txBusy),
        .padCnt                    (padCnt),
        .txOversizeCnt             (txOversizeCnt),
        .txUnderrunCnt             (txUnderrunCnt),
        .txSfdCnt                  (txSfdCnt),
        .rsRxState                 (rsRxState),
        .rxCrcErrCnt               (rxCrcErrCnt),
        .rxSfdCnt                  (rxSfdCnt)
    );

    PcsCodec uPcsCodec (
        .clkTx                     (clkTx),
        .clkRx                     (clkRx),
        .clkMgmt                   (clkMgmt),
        .rstN                      (rstNCore),
        .txEn                      (txEn),
        .rxEn                      (rxEn),
        .loopback                  (loopback),
        .loopbackAlFullThrd        (loopbackAlFullThrd),
        .loopbackAlEmptyThrd       (loopbackAlEmptyThrd),
        .rs2PcsPktBusData          (rs2PcsPktBusData),
        .rs2PcsPktBusValid         (rs2PcsPktBusValid),
        .rs2PcsPktBusSfp           (rs2PcsPktBusSfp),
        .rs2PcsPktBusEfp           (rs2PcsPktBusEfp),
        .rs2PcsPktBusErr           (rs2PcsPktBusErr),
        .rs2PcsPktBusPreemptable   (rs2PcsPktBusPreemptable),
        .rs2PcsPktBusStall         (rs2PcsPktBusStall),
        .pcs2RsPktBusData          (pcs2RsPktBusData),
        .pcs2RsPktBusValid         (pcs2RsPktBusValid),
        .pcs2RsPktBusSfp           (pcs2RsPktBusSfp),
        .pcs2RsPktBusEfp           (pcs2RsPktBusEfp),
        .pcs2RsPktBusErr           (pcs2RsPktBusErr),
        .pcs2RsPktBusPreemptable   (pcs2RsPktBusPreemptable),
        .pcs2GbxCodeBusCodeGroup   (pcs2GbxCodeBusCodeGroup),
        .gbx2PcsCodeBusCodeGroup   (gbx2PcsCodeBusCodeGroup),
        .pcs2RsSyncStatus          (pcs2RsSyncStatus),
        .pcsRxSync                 (pcsRxSync),
        .pcsTxState                (pcsTxState),
        .pcsTxEven                 (pcsTxEven),
        .pcsTxRd                   (pcsTxRd),
        .pcsRxSyncState            (pcsRxSyncState),
        .pcsRxEven                 (pcsRxEven),
        .pcsRxRd                   (pcsRxRd),
        .lossOfSyncCnt             (lossOfSyncCnt),
        .codeVCnt                  (codeVCnt)
    );

    PcsSdsGearbox uPcsSdsGearbox (
        .clkTx                     (clkTx),
        .clkSdsTx                  (clkSdsTx),
        .clkRx                     (clkRx),
        .clkSdsRx                  (clkSdsRx),
        .clkMgmt                   (clkMgmt),
        .rstN                      (rstNCore),
        .gbxTxFifoThrd             (gbxTxFifoThrd),
        .gbxRxFifoThrd             (gbxRxFifoThrd),
        .pcs2GbxCodeBusCodeGroup   (pcs2GbxCodeBusCodeGroup),
        .gbx2PcsCodeBusCodeGroup   (gbx2PcsCodeBusCodeGroup),
        .gbx2SdsTxBusData          (gbx2SdsTxBusData),
        .sds2GbxRxBusData          (sds2GbxRxBusData)
    );

//======================================================
// Register
//======================================================

    GmacReg uGmacReg (
        .clock                     (clkMgmt),
        .rstN                      (rstN),
        .wr                        (wr),
        .wrAddr                    (wrAddr),
        .wrData                    (wrData),
        .wrAck                     (wrAck),
        .wrErr                     (wrErr),
        .rd                        (rd),
        .rdAddr                    (rdAddr),
        .rdAck                     (rdAck),
        .rdErr                     (rdErr),
        .rdData                    (rdData),
        .date                      (DATE),
        .user                      (USER),
        .version                   (VERSION),
        .softRstN                  (softRstN),
        .txEn                      (txEn),
        .rxEn                      (rxEn),
        .loopback                  (loopback),
        .fifoTxFifoThrd            (fifoTxFifoThrd),
        .ifgCntMax                 (ifgCntMax),
        .lenCntMin                 (lenCntMin),
        .lenCntMax                 (lenCntMax),
        .rxDelCrc                  (rxDelCrc),
        .loopbackAlFullThrd        (loopbackAlFullThrd),
        .loopbackAlEmptyThrd       (loopbackAlEmptyThrd),
        .gbxTxFifoThrd             (gbxTxFifoThrd),
        .gbxRxFifoThrd             (gbxRxFifoThrd),
        .irqMask                   (irqMask),
        .txFifoLevel               (txFifoLevel),
        .rxFifoLevel               (rxFifoLevel),
        .fifoAlFull                (fifoAlFull),
        .txFifoPeakCnt             (txFifoPeakCnt),
        .rxFifoPeakCnt             (rxFifoPeakCnt),
        .txBusy                    (txBusy),
        .rsRxState                 (rsRxState),
        .padCnt                    (padCnt),
        .pcsRxSync                 (pcsRxSync),
        .pcsTxState                (pcsTxState),
        .pcsTxEven                 (pcsTxEven),
        .pcsTxRd                   (pcsTxRd),
        .pcsRxSyncState            (pcsRxSyncState),
        .pcsRxEven                 (pcsRxEven),
        .pcsRxRd                   (pcsRxRd),
        .irqRaw                    (irqRaw),
        .txOverRunCnt              (txOverRunCnt),
        .txUnderRunCnt             (txUnderRunCnt),
        .rxOverflowCnt             (rxOverflowCnt),
        .txVbErrCnt                (txVbErrCnt),
        .txOversizeCnt             (txOversizeCnt),
        .txUnderrunCnt             (txUnderrunCnt),
        .rxCrcErrCnt               (rxCrcErrCnt),
        .txSfdCnt                  (txSfdCnt),
        .rxSfdCnt                  (rxSfdCnt),
        .lossOfSyncCnt             (lossOfSyncCnt),
        .codeVCnt                  (codeVCnt),
        .txInSfpCnt                (txInSfpCnt),
        .txInEfpCnt                (txInEfpCnt),
        .txInVbCnt                 (txInVbCnt),
        .txInValidCnt              (txInValidCnt),
        .txInErrCnt                (txInErrCnt),
        .txOutSfpCnt               (txOutSfpCnt),
        .txOutEfpCnt               (txOutEfpCnt),
        .txOutVbCnt                (txOutVbCnt),
        .txOutValidCnt             (txOutValidCnt),
        .txOutErrCnt               (txOutErrCnt),
        .rxInSfpCnt                (rxInSfpCnt),
        .rxInEfpCnt                (rxInEfpCnt),
        .rxInVbCnt                 (rxInVbCnt),
        .rxInValidCnt              (rxInValidCnt),
        .rxInErrCnt                (rxInErrCnt),
        .rxOutSfpCnt               (rxOutSfpCnt),
        .rxOutEfpCnt               (rxOutEfpCnt),
        .rxOutVbCnt                (rxOutVbCnt),
        .rxOutValidCnt             (rxOutValidCnt),
        .rxOutErrCnt               (rxOutErrCnt)
    );

endmodule
