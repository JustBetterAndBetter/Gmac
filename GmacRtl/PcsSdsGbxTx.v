// +FHDR----------------------------------------------------------------------------
// Device        : Xilinx
// Author        : fxdqe
// Email         : 1706260166@qq.com
// Created On    : 2026/09/16 21:05
// File Name     : PcsSdsGbxTx.v
// Description   : 两拍 10b@clkTx 拼一词 20b，AsyncFifo 交到 clkSdsTx；低 10 bit 先出。
//                 rstN 为 rstNCore，内部同步到 clkTx / clkSdsTx。
// ---------------------------------------------------------------------------------
// Modification History:
// Date         By              Version                 Change Description
// ---------------------------------------------------------------------------------
// 2026/09/16   fxdqe           1.1                     AsyncFifo CDC
// 2026/09/18   fxdqe           1.2                     单路复位，分域同步
// 2026/10/01   fxdqe           1.3                     Value/Push/Pop 分区注释
// 2026/10/01   fxdqe           1.4                     预取口改为 fifoPopData
// 2026/10/01   fxdqe           1.5                     FIFO 分域 resetIn/resetOut
// 2026/10/01   fxdqe           1.6                     分域复位改 IP_ResetSync
// 2026/10/04   fxdqe           1.7                     下一拍改 Int，时序只采样
// 2026/10/04   fxdqe           1.8                     读侧水位改 gbxTxFifoThrd
// 2026/10/05   fxdqe           1.9                     同步器去掉源时钟端口
// -FHDR----------------------------------------------------------------------------

`include "GmacIf.vh"

module PcsSdsGbxTx(/*autoarg*/
        //Inputs
        clkTx, clkSdsTx, rstN, gbxTxFifoThrd, pcs2GbxCodeBusCodeGroup, 
        //Outputs
        gbx2SdsTxBusData
);

//######################################################
//Interface
//######################################################

parameter FIFO_DEPTH = 8;

localparam ADDR_WIDTH = FIFO_DEPTH<=4  ? 2:
                        FIFO_DEPTH<=8  ? 3:
                        FIFO_DEPTH<=16 ? 4: 5;
localparam PTR_W      = ADDR_WIDTH + 1;
localparam [PTR_W-1:0] PTR_ONE   = {{ADDR_WIDTH{1'b0}}, 1'b1};
localparam [PTR_W-1:0] PTR_THREE = {{(ADDR_WIDTH-1){1'b0}}, 2'd3};
localparam [PTR_W-1:0] AL_FULL_THRD = FIFO_DEPTH[PTR_W-1:0] - PTR_THREE;

input                   clkTx;
input                   clkSdsTx;
input                   rstN;

input  [7:0]            gbxTxFifoThrd;
input  [`GMAC_CODE_W-1:0] pcs2GbxCodeBusCodeGroup;
output reg [`GMAC_SDS_W-1:0] gbx2SdsTxBusData;

//######################################################
//Value
//######################################################

// 复位：rstN 同步到写钟 / 读钟
wire                    rstNTx;
wire                    rstNSdsTx;

// Push @ clkTx：偶拍锁低 10b，奇拍拼 20b
reg                     even;
wire                    evenInt;
reg  [`GMAC_CODE_W-1:0] codeLo;
wire [`GMAC_CODE_W-1:0] codeLoInt;
reg                     pushCmd;
wire                    pushCmdInt;
reg  [`GMAC_SDS_W-1:0]  pushData;
wire [`GMAC_SDS_W-1:0]  pushDataInt;

// FIFO。gbxTxFifoThrd 在 clkMgmt，同步到读钟后作为 fifoValid 门槛
wire [7:0]              gbxTxFifoThrdSds;
wire [PTR_W-1:0]        txThrd;
wire                    fifoPush;
wire                    fifoPop;
wire [`GMAC_SDS_W-1:0]  fifoPopData;
wire                    fifoEmpty;
wire                    fifoFull;
wire                    fifoValid;

// Pop @ clkSdsTx：水位开门后持续读出
reg                     started;
wire                    startedInt;
wire [`GMAC_SDS_W-1:0]  gbx2SdsTxBusDataInt;

//######################################################
//Logic
//######################################################

//======================================================
// 复位同步到 clkTx / clkSdsTx
//======================================================

    IP_ResetSync uRstTx (
        .resetIn  (rstN),
        .clockOut (clkTx),
        .resetOut (rstNTx)
    );

    IP_ResetSync uRstSds (
        .resetIn  (rstN),
        .clockOut (clkSdsTx),
        .resetOut (rstNSdsTx)
    );

//======================================================
// 读侧水位：clkMgmt 配置同步到 clkSdsTx
//======================================================

    IP_Sync #(.DATA_WIDTH(8)) uGbxTxFifoThrd (
        .clockOut (clkSdsTx),
        .reset    (rstNSdsTx),
        .dataIn   (gbxTxFifoThrd),
        .dataOut  (gbxTxFifoThrdSds)
    );

    assign txThrd = gbxTxFifoThrdSds[PTR_W-1:0];

//======================================================
// FIFO：clkTx 写入，clkSdsTx 读出
//======================================================

    IP_AsyncFifo #(
        .DATA_WIDTH ( `GMAC_SDS_W ),
        .FIFO_DEPTH ( FIFO_DEPTH )
    ) uGbxTxFifo (
        .clockIn         (clkTx),
        .clockOut        (clkSdsTx),
        .resetIn         (rstNTx),
        .resetOut        (rstNSdsTx),
        .fifoPush        (fifoPush),
        .fifoPushData    (pushData),
        .fifoPop         (fifoPop),
        .fifoPopData     (fifoPopData),
        .fifoDepth       (),
        .fifoAlFullThrd  (AL_FULL_THRD),
        .fifoAlEmptyThrd (PTR_ONE),
        .fifoTxFifoThrd  (txThrd),
        .fifoAlFull      (),
        .fifoAlEmpty     (),
        .fifoValid       (fifoValid),
        .overRun         (),
        .underRun        (),
        .fifoEmpty       (fifoEmpty),
        .fifoFull        (fifoFull)
    );

//======================================================
// Push @ clkTx：偶拍锁低 10b，奇拍拼成 20b 写 FIFO
//======================================================

    assign evenInt = ~even;

    always@(posedge clkTx or negedge rstNTx) begin
        if (!rstNTx)
            even <= 1'b1;
        else
            even <= evenInt;
    end

    assign codeLoInt   = even ? pcs2GbxCodeBusCodeGroup : codeLo;
    assign pushCmdInt  = even ? 1'b0 : ~fifoFull;
    assign pushDataInt = even ? pushData : {pcs2GbxCodeBusCodeGroup, codeLo};
    assign fifoPush    = pushCmd;

    always@(posedge clkTx or negedge rstNTx) begin
        if (!rstNTx) begin
            codeLo   <= {`GMAC_CODE_W{1'b0}};
            pushCmd  <= 1'b0;
            pushData <= {`GMAC_SDS_W{1'b0}};
        end
        else begin
            codeLo   <= codeLoInt;
            pushCmd  <= pushCmdInt;
            pushData <= pushDataInt;
        end
    end

//======================================================
// Pop @ clkSdsTx：fifoValid 开门后，非空就读出 SDS 词
//======================================================

    assign fifoPop    = started & ~fifoEmpty;
    assign startedInt = started | fifoValid;

    always@(posedge clkSdsTx or negedge rstNSdsTx) begin
        if (!rstNSdsTx)
            started <= 1'b0;
        else
            started <= startedInt;
    end

    assign gbx2SdsTxBusDataInt = (started & ~fifoEmpty) ? fifoPopData : gbx2SdsTxBusData;

    always@(posedge clkSdsTx or negedge rstNSdsTx) begin
        if (!rstNSdsTx)
            gbx2SdsTxBusData <= {`GMAC_SDS_W{1'b0}};
        else
            gbx2SdsTxBusData <= gbx2SdsTxBusDataInt;
    end

endmodule
