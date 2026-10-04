// +FHDR----------------------------------------------------------------------------
// Device        : Xilinx
// Author        : fxdqe
// Email         : 1706260166@qq.com
// Created On    : 2026/09/16 21:05
// File Name     : PcsSdsGearbox.v
// Description   : PCS 10b@125M 与 SERDES 20b 互转；rstN 为 rstNCore，内部同步到各钟。
//
// ---------------------------------------------------------------------------------
// Modification History:
// Date         By              Version                 Change Description
// ---------------------------------------------------------------------------------
// 2026/09/16   fxdqe           1.0                     Interface template
// 2026/09/18   fxdqe           1.1                     单路复位，分域同步
// 2026/10/04   fxdqe           1.2                     Tx/Rx 功能块注释
// 2026/10/04   fxdqe           1.3                     读侧水位改配置寄存器
// -FHDR----------------------------------------------------------------------------

`include "GmacIf.vh"

module PcsSdsGearbox(/*autoarg*/
        //Inputs
        clkTx, clkSdsTx, clkRx, clkSdsRx, clkMgmt, rstN,
        gbxTxFifoThrd, gbxRxFifoThrd,
        pcs2GbxCodeBusCodeGroup, sds2GbxRxBusData,
        //Outputs
        gbx2PcsCodeBusCodeGroup, gbx2SdsTxBusData
);

//######################################################
//Interface
//######################################################

input                   clkTx;
input                   clkSdsTx;
input                   clkRx;
input                   clkSdsRx;
input                   clkMgmt;
input                   rstN;

input  [7:0]            gbxTxFifoThrd;
input  [7:0]            gbxRxFifoThrd;

input  [`GMAC_CODE_W-1:0] pcs2GbxCodeBusCodeGroup;
output [`GMAC_CODE_W-1:0] gbx2PcsCodeBusCodeGroup;

output [`GMAC_SDS_W-1:0]  gbx2SdsTxBusData;
input  [`GMAC_SDS_W-1:0]  sds2GbxRxBusData;

//######################################################
//Logic
//######################################################

//======================================================
// Tx：两拍 10b@clkTx 拼 20b，交到 clkSdsTx
//======================================================

    PcsSdsGbxTx uPcsSdsGbxTx (
        .clkTx                     (clkTx),
        .clkSdsTx                  (clkSdsTx),
        .clkMgmt                   (clkMgmt),
        .rstN                      (rstN),
        .gbxTxFifoThrd             (gbxTxFifoThrd),
        .pcs2GbxCodeBusCodeGroup   (pcs2GbxCodeBusCodeGroup),
        .gbx2SdsTxBusData          (gbx2SdsTxBusData)
    );

//======================================================
// Rx：20b@clkSdsRx 拆成两拍 10b，交到 clkRx
//======================================================

    PcsSdsGbxRx uPcsSdsGbxRx (
        .clkSdsRx                  (clkSdsRx),
        .clkRx                     (clkRx),
        .clkMgmt                   (clkMgmt),
        .rstN                      (rstN),
        .gbxRxFifoThrd             (gbxRxFifoThrd),
        .sds2GbxRxBusData          (sds2GbxRxBusData),
        .gbx2PcsCodeBusCodeGroup   (gbx2PcsCodeBusCodeGroup)
    );

endmodule
