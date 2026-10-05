// +FHDR----------------------------------------------------------------------------
// Device        : Xilinx
// Author        : fxdqe
// Email         : 1706260166@qq.com
// Created On    : 2026/09/16 21:05
// File Name     : PcsSdsGbxRx.v
// Description   : 一词 20b@clkSdsRx 经 AsyncFifo 到 clkRx，先出 [9:0] 再出 [19:10]。
//                 rstN 为 rstNCore，内部同步到 clkSdsRx / clkRx。
// ---------------------------------------------------------------------------------
// Modification History:
// Date         By              Version                 Change Description
// ---------------------------------------------------------------------------------
// 2026/09/16   fxdqe           1.1                     AsyncFifo + word-aligned split
// 2026/09/18   fxdqe           1.2                     单路复位，分域同步
// 2026/10/01   fxdqe           1.3                     Value/Push/Pop 分区注释
// 2026/10/01   fxdqe           1.4                     预取口改为 fifoPopData
// 2026/10/01   fxdqe           1.5                     FIFO 分域 resetIn/resetOut
// 2026/10/01   fxdqe           1.6                     分域复位改 IP_ResetSync
// 2026/10/04   fxdqe           1.7                     Pop 改独热两段式，时序只采样
// 2026/10/04   fxdqe           1.8                     读侧水位改 gbxRxFifoThrd
// 2026/10/05   fxdqe           1.9                     同步器去掉源时钟端口
// -FHDR----------------------------------------------------------------------------

`include "GmacIf.vh"

module PcsSdsGbxRx(/*autoarg*/
        //Inputs
        clkSdsRx, clkRx, rstN, gbxRxFifoThrd, sds2GbxRxBusData, 
        //Outputs
        gbx2PcsCodeBusCodeGroup
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

input                   clkSdsRx;
input                   clkRx;
input                   rstN;

input  [7:0]              gbxRxFifoThrd;
input  [`GMAC_SDS_W-1:0]  sds2GbxRxBusData;
output reg [`GMAC_CODE_W-1:0] gbx2PcsCodeBusCodeGroup;

//######################################################
//Value
//######################################################

// 复位：rstN 同步到写钟 / 读钟
wire                    rstNSdsRx;
wire                    rstNRx;

// Push @ clkSdsRx：SDS 词写入 FIFO
reg                     pushCmd;
wire                    pushCmdInt;
reg  [`GMAC_SDS_W-1:0]  pushData;
wire [`GMAC_SDS_W-1:0]  pushDataInt;

// FIFO。gbxRxFifoThrd 在 clkMgmt，同步到读钟后作为 fifoValid 门槛
wire [7:0]              gbxRxFifoThrdRx;
wire [PTR_W-1:0]        txThrd;
wire                    fifoPush;
wire                    fifoPop;
wire [`GMAC_SDS_W-1:0]  fifoPopData;
wire                    fifoEmpty;
wire                    fifoFull;
wire                    fifoValid;

// Pop @ clkRx：等水位，再把一词拆成低 10b、高 10b
localparam [2:0] ST_WAIT = 3'b001;
localparam [2:0] ST_LO   = 3'b010;
localparam [2:0] ST_HI   = 3'b100;

reg  [2:0]              state;
reg  [2:0]              stateNxt;
wire                    takeWord;
reg  [`GMAC_SDS_W-1:0]  word;
wire [`GMAC_SDS_W-1:0]  wordInt;
reg                     popCmd;
wire                    popCmdInt;
wire [`GMAC_CODE_W-1:0] gbx2PcsCodeBusCodeGroupInt;

//######################################################
//Logic
//######################################################

//======================================================
// 复位同步到 clkSdsRx / clkRx
//======================================================

    IP_ResetSync uRstSds (
        .resetIn  (rstN),
        .clockOut (clkSdsRx),
        .resetOut (rstNSdsRx)
    );

    IP_ResetSync uRstRx (
        .resetIn  (rstN),
        .clockOut (clkRx),
        .resetOut (rstNRx)
    );

//======================================================
// 读侧水位：clkMgmt 配置同步到 clkRx
//======================================================

    IP_Sync #(.DATA_WIDTH(8)) uGbxRxFifoThrd (
        .clockOut (clkRx),
        .reset    (rstNRx),
        .dataIn   (gbxRxFifoThrd),
        .dataOut  (gbxRxFifoThrdRx)
    );

    assign txThrd = gbxRxFifoThrdRx[PTR_W-1:0];

//======================================================
// FIFO：clkSdsRx 写入，clkRx 读出
//======================================================

    IP_AsyncFifo #(
        .DATA_WIDTH ( `GMAC_SDS_W ),
        .FIFO_DEPTH ( FIFO_DEPTH )
    ) uGbxRxFifo (
        .clockIn         (clkSdsRx),
        .clockOut        (clkRx),
        .resetIn         (rstNSdsRx),
        .resetOut        (rstNRx),
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
// Push @ clkSdsRx：未满则把本拍 SDS 词写入 FIFO
//======================================================

    assign pushDataInt = sds2GbxRxBusData;
    assign pushCmdInt  = ~fifoFull;
    assign fifoPush    = pushCmd;

    always@(posedge clkSdsRx or negedge rstNSdsRx) begin
        if (!rstNSdsRx) begin
            pushCmd  <= 1'b0;
            pushData <= {`GMAC_SDS_W{1'b0}};
        end
        else begin
            pushCmd  <= pushCmdInt;
            pushData <= pushDataInt;
        end
    end

//======================================================
// Pop @ clkRx：水位开门后，先出 [9:0] 再出 [19:10]
//======================================================

    always@(posedge clkRx or negedge rstNRx) begin
        if (!rstNRx)
            state <= ST_WAIT;
        else
            state <= stateNxt;
    end

    always @(*) begin
        stateNxt = state;
        case (state)
            ST_WAIT: if (fifoValid) stateNxt = ST_LO;
            ST_LO:   stateNxt = ST_HI;
            ST_HI:   stateNxt = fifoEmpty ? ST_WAIT : ST_LO;
            default: stateNxt = ST_WAIT;
        endcase
    end

    // 取词与 Pop 晚一拍生效，和原 loaded/sel 对齐
    assign takeWord  = (state[0] & fifoValid) | (state[2] & ~fifoEmpty);
    assign wordInt   = takeWord ? fifoPopData : word;
    assign popCmdInt = takeWord;
    assign fifoPop   = popCmd;

    always@(posedge clkRx or negedge rstNRx) begin
        if (!rstNRx) begin
            word   <= {`GMAC_SDS_W{1'b0}};
            popCmd <= 1'b0;
        end
        else begin
            word   <= wordInt;
            popCmd <= popCmdInt;
        end
    end

    assign gbx2PcsCodeBusCodeGroupInt = state[1] ? word[`GMAC_CODE_W-1:0] :
                                        state[2] ? word[`GMAC_SDS_W-1:`GMAC_CODE_W] :
                                                   gbx2PcsCodeBusCodeGroup;

    always@(posedge clkRx or negedge rstNRx) begin
        if (!rstNRx)
            gbx2PcsCodeBusCodeGroup <= {`GMAC_CODE_W{1'b0}};
        else
            gbx2PcsCodeBusCodeGroup <= gbx2PcsCodeBusCodeGroupInt;
    end

endmodule
