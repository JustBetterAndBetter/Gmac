// +FHDR----------------------------------------------------------------------------
// Device        : Xilinx
// Author        : fxdqe
// Email         : 1706260166@qq.com
// Created On    : 2026/09/16 21:05
// File Name     : UsrRsCdcRx.v
// Description   : RS Rx 8b@clkRx 拼 128b -> IP_AsyncFifo -> 用户口@clkUsr。
//                 以 FIFO 为界：写侧 Push，读侧 Pop。无 stall，反压不回 RS。
//                 Push：高字节先装；拼满 16 或遇 efp 时，本片字节数作为 Vb 写入。
//                 将满或已满则丢掉本包剩余，并记 rxOverflowCnt。
//                 Pop：信任 FIFO 内 Vb。非空即 Pop，下一拍输出；有词则连续出。
//                 输出前经 UsrPktFilter，规则与 Tx 输入端相同。Rx 无 Stall。
//                 入口/出口各计 Sfp、Efp、Vb、Valid、Err。无 Stall，按 Valid 计。
//                 8b 入口 Vb 每拍加 1；128b 出口累加本拍 Vb。计满回绕到 0。
//                 rstNRx/rstNUsr 已是本时钟域同步释放复位。
//
// ---------------------------------------------------------------------------------
// Modification History:
// Date         By              Version                 Change Description
// ---------------------------------------------------------------------------------
// 2026/09/16   fxdqe           1.0                     Original
// 2026/09/18   fxdqe           1.1                     分域复位
// 2026/10/01   fxdqe           1.2                     接口 Vb + 高字节先发
// 2026/10/01   fxdqe           1.3                     Cnt/分区与 Tx 对齐
// 2026/10/01   fxdqe           1.4                     预取口改为 fifoPopData
// 2026/10/01   fxdqe           1.5                     FIFO 分域 resetIn/resetOut
// 2026/10/01   fxdqe           1.6                     按片计 Vb 后 Push；Pop 预取空一拍
// 2026/10/01   fxdqe           1.7                     Pop 不再空拍，有词则连续输出
// 2026/10/01   fxdqe           1.8                     用户口前接 UsrPktFilter
// 2026/10/01   fxdqe           1.9                     入口/出口 Sfp Efp Vb Valid Err 计数
// 2026/10/01   fxdqe           1.10                    端口计数计满回绕
// -FHDR----------------------------------------------------------------------------

`include "GmacIf.vh"

module UsrRsCdcRx(/*autoarg*/
        //Inputs
        clkRx, clkUsr, rstNRx, rstNUsr, rs2CdcPktBusData,
        rs2CdcPktBusValid, rs2CdcPktBusSfp, rs2CdcPktBusEfp,
        rs2CdcPktBusErr, rs2CdcPktBusPreemptable,
        //Outputs
        cdc2UsrPktBusData, cdc2UsrPktBusVb, cdc2UsrPktBusValid, cdc2UsrPktBusSfp,
        cdc2UsrPktBusEfp, cdc2UsrPktBusErr, cdc2UsrPktBusPreemptable,
        rxFifoLevel, rxFifoPeakCnt, rxOverflowCnt,
        rxInSfpCnt, rxInEfpCnt, rxInVbCnt, rxInValidCnt, rxInErrCnt,
        rxOutSfpCnt, rxOutEfpCnt, rxOutVbCnt, rxOutValidCnt, rxOutErrCnt
);

//######################################################
//Interface
//######################################################

parameter USR_DATA_W = `GMAC_USR_W;
parameter FIFO_DEPTH = 16;

localparam ADDR_WIDTH = FIFO_DEPTH<=4  ? 2:
                        FIFO_DEPTH<=8  ? 3:
                        FIFO_DEPTH<=16 ? 4:
                        FIFO_DEPTH<=32 ? 5: 6;
localparam PTR_W      = ADDR_WIDTH + 1;
localparam VB_W       = `GMAC_VB_W;
localparam FIFO_W     = USR_DATA_W + VB_W + 4;
localparam BIT_VB0    = USR_DATA_W;
localparam BIT_VB_MSB = USR_DATA_W + VB_W - 1;
localparam BIT_SFP    = USR_DATA_W + VB_W;
localparam BIT_EFP    = USR_DATA_W + VB_W + 1;
localparam BIT_ERR    = USR_DATA_W + VB_W + 2;
localparam BIT_PRE    = USR_DATA_W + VB_W + 3;
localparam [PTR_W-1:0] PTR_ONE      = {{ADDR_WIDTH{1'd0}}, 1'd1};
localparam [PTR_W-1:0] PTR_TWO      = {{(ADDR_WIDTH-1){1'd0}}, 2'd2};
localparam [PTR_W-1:0] AL_FULL_THRD = FIFO_DEPTH[PTR_W-1:0] - PTR_TWO;

input                   clkRx;
input                   clkUsr;
input                   rstNRx;
input                   rstNUsr;

input  [`GMAC_BYTE_W-1:0] rs2CdcPktBusData;
input                   rs2CdcPktBusValid;
input                   rs2CdcPktBusSfp;
input                   rs2CdcPktBusEfp;
input                   rs2CdcPktBusErr;
input                   rs2CdcPktBusPreemptable;

output [USR_DATA_W-1:0] cdc2UsrPktBusData;
output [VB_W-1:0]       cdc2UsrPktBusVb;
output                  cdc2UsrPktBusValid;
output                  cdc2UsrPktBusSfp;
output                  cdc2UsrPktBusEfp;
output                  cdc2UsrPktBusErr;
output                  cdc2UsrPktBusPreemptable;

output [`GMAC_CNT_W8-1:0]      rxFifoLevel;
output reg [`GMAC_CNT_W8-1:0]  rxFifoPeakCnt;
output reg [`GMAC_CNT_W32-1:0] rxOverflowCnt;
output reg [`GMAC_CNT_W16-1:0] rxInSfpCnt;
output reg [`GMAC_CNT_W16-1:0] rxInEfpCnt;
output reg [`GMAC_CNT_W32-1:0] rxInVbCnt;
output reg [`GMAC_CNT_W32-1:0] rxInValidCnt;
output reg [`GMAC_CNT_W8-1:0]  rxInErrCnt;
output reg [`GMAC_CNT_W16-1:0] rxOutSfpCnt;
output reg [`GMAC_CNT_W16-1:0] rxOutEfpCnt;
output reg [`GMAC_CNT_W32-1:0] rxOutVbCnt;
output reg [`GMAC_CNT_W32-1:0] rxOutValidCnt;
output reg [`GMAC_CNT_W8-1:0]  rxOutErrCnt;

//######################################################
//Value
//######################################################

// FIFO：{pre, err, efp, sfp, vb, data}
wire [FIFO_W-1:0]          fifoPushData;
wire                       fifoPush;
wire                       fifoPop;
wire [FIFO_W-1:0]          fifoPopData;
wire [PTR_W-1:0]           fifoDepth;
wire                       fifoEmpty;
wire                       fifoFull;
wire                       fifoAlFull;

// Push 侧：把字节拼成一片，片长即 Vb
wire                       rsBeat;
wire                       newWord;
wire [3:0]                 slotIdx;
wire                       sliceEnd;
wire                       canPush;
wire                       flushBeat;
wire                       packSet;
wire                       packClr;
wire                       dropSet;
wire                       dropClr;
wire [USR_DATA_W-1:0]      wordBase;
reg  [USR_DATA_W-1:0]      wordNow;
wire [VB_W-1:0]            sliceVb;
wire                       sliceSfp;
wire                       sliceErr;
wire                       slicePre;
wire [USR_DATA_W-1:0]      packDataInt;
wire [3:0]                 byteCntInt;
wire                       packSfpInt;
wire                       packErrInt;
wire                       packPreInt;
wire                       packingInt;
wire                       droppingInt;
wire                       overflowEvt;
wire [`GMAC_CNT_W32-1:0]   rxOverflowCntInt;
reg  [USR_DATA_W-1:0]      packData;
reg  [3:0]                 byteCnt;
reg                        packSfp;
reg                        packErr;
reg                        packPre;
reg                        packing;
reg                        dropping;

// Pop 侧：非空即 Pop，下一拍输出，再过滤到用户口
wire [USR_DATA_W-1:0]      popData;
wire [VB_W-1:0]            popVb;
wire                       popSfp;
wire                       popEfp;
wire                       popErr;
wire                       popPre;
wire [FIFO_W-1:0]          outRegInt;
wire                       outValidInt;
wire [`GMAC_CNT_W8-1:0]    rxFifoPeakCntInt;
reg  [FIFO_W-1:0]          outReg;
reg                        outValid;

//######################################################
//Logic
//######################################################

//======================================================
// Push @ clkRx：拼满 16 或遇 efp，带本片字节数 Push
//======================================================

    assign rsBeat    = rs2CdcPktBusValid;
    assign newWord   = ~packing | rs2CdcPktBusSfp;
    assign slotIdx   = newWord ? 4'd0 : byteCnt;
    assign sliceEnd  = rs2CdcPktBusEfp | (slotIdx == 4'hF);
    assign canPush   = ~fifoFull & ~fifoAlFull;
    assign flushBeat = rsBeat & ~dropping & sliceEnd;
    assign fifoPush  = flushBeat & canPush;

    assign wordBase = newWord ? {USR_DATA_W{1'd0}} : packData;

    always@(*)begin
        wordNow = wordBase;
        case(slotIdx)
            4'h0:    wordNow[8*15 +: 8] = rs2CdcPktBusData;
            4'h1:    wordNow[8*14 +: 8] = rs2CdcPktBusData;
            4'h2:    wordNow[8*13 +: 8] = rs2CdcPktBusData;
            4'h3:    wordNow[8*12 +: 8] = rs2CdcPktBusData;
            4'h4:    wordNow[8*11 +: 8] = rs2CdcPktBusData;
            4'h5:    wordNow[8*10 +: 8] = rs2CdcPktBusData;
            4'h6:    wordNow[8*9  +: 8] = rs2CdcPktBusData;
            4'h7:    wordNow[8*8  +: 8] = rs2CdcPktBusData;
            4'h8:    wordNow[8*7  +: 8] = rs2CdcPktBusData;
            4'h9:    wordNow[8*6  +: 8] = rs2CdcPktBusData;
            4'hA:    wordNow[8*5  +: 8] = rs2CdcPktBusData;
            4'hB:    wordNow[8*4  +: 8] = rs2CdcPktBusData;
            4'hC:    wordNow[8*3  +: 8] = rs2CdcPktBusData;
            4'hD:    wordNow[8*2  +: 8] = rs2CdcPktBusData;
            4'hE:    wordNow[8*1  +: 8] = rs2CdcPktBusData;
            default: wordNow[8*0  +: 8] = rs2CdcPktBusData;
        endcase
    end

    assign sliceVb  = {1'd0, slotIdx} + {{(VB_W-1){1'd0}}, 1'd1};
    assign sliceSfp = newWord ? rs2CdcPktBusSfp : packSfp;
    assign sliceErr = newWord ? rs2CdcPktBusErr : (packErr | rs2CdcPktBusErr);
    assign slicePre = newWord ? rs2CdcPktBusPreemptable : packPre;
    assign fifoPushData = {slicePre, sliceErr, rs2CdcPktBusEfp,
                           sliceSfp, sliceVb, wordNow};

    assign packSet     = rsBeat & ~dropping & ~sliceEnd;
    assign packClr     = rsBeat & (dropping | sliceEnd);
    assign dropSet     = flushBeat & ~canPush & ~rs2CdcPktBusEfp;
    assign dropClr     = rsBeat & rs2CdcPktBusEfp;
    assign packingInt  = (packing | packSet) & ~packClr;
    assign droppingInt = (dropping | dropSet) & ~dropClr;

    assign packDataInt = rsBeat ? wordNow  : packData;
    assign byteCntInt  = rsBeat ? (slotIdx + 4'd1) : byteCnt;
    assign packSfpInt  = rsBeat ? sliceSfp : packSfp;
    assign packErrInt  = rsBeat ? sliceErr : packErr;
    assign packPreInt  = rsBeat ? slicePre : packPre;

    always@(posedge clkRx or negedge rstNRx)begin
        if(!rstNRx)begin
            packData <= {USR_DATA_W{1'd0}};
            byteCnt  <= 4'd0;
            packSfp  <= 1'd0;
            packErr  <= 1'd0;
            packPre  <= 1'd0;
            packing  <= 1'd0;
            dropping <= 1'd0;
        end
        else begin
            packData <= packDataInt;
            byteCnt  <= byteCntInt;
            packSfp  <= packSfpInt;
            packErr  <= packErrInt;
            packPre  <= packPreInt;
            packing  <= packingInt;
            dropping <= droppingInt;
        end
    end

    assign overflowEvt = flushBeat & ~canPush;
    assign rxOverflowCntInt = (overflowEvt && (rxOverflowCnt != {`GMAC_CNT_W32{1'd1}})) ?
                              (rxOverflowCnt + {{(`GMAC_CNT_W32-1){1'd0}}, 1'd1}) :
                               rxOverflowCnt;
    always@(posedge clkRx or negedge rstNRx)begin
        if(!rstNRx)begin
            rxOverflowCnt <= {`GMAC_CNT_W32{1'd0}};
        end
        else begin
            rxOverflowCnt <= rxOverflowCntInt;
        end
    end

//======================================================
// FIFO
//======================================================

    IP_AsyncFifo #(
        .DATA_WIDTH (FIFO_W),
        .FIFO_DEPTH (FIFO_DEPTH)
    ) uRxFifo (
        .clockIn         (clkRx),
        .clockOut        (clkUsr),
        .resetIn         (rstNRx),
        .resetOut        (rstNUsr),
        .fifoPush        (fifoPush),
        .fifoPushData    (fifoPushData),
        .fifoPop         (fifoPop),
        .fifoPopData     (fifoPopData),
        .fifoDepth       (fifoDepth),
        .fifoAlFullThrd  (AL_FULL_THRD),
        .fifoAlEmptyThrd (PTR_ONE),
        .fifoTxFifoThrd  ({PTR_W{1'd0}}),
        .fifoAlFull      (fifoAlFull),
        .fifoAlEmpty     (),
        .fifoValid       (),
        .overRun         (),
        .underRun        (),
        .fifoEmpty       (fifoEmpty),
        .fifoFull        (fifoFull)
    );

    assign rxFifoLevel = {{(8-PTR_W){1'd0}}, fifoDepth};

//======================================================
// Pop @ clkUsr：非空即 Pop，下一拍输出；有词则连续
//======================================================

    assign fifoPop     = ~fifoEmpty;
    assign outValidInt = fifoPop;
    assign outRegInt   = fifoPop ? fifoPopData : outReg;

    always@(posedge clkUsr or negedge rstNUsr)begin
        if(!rstNUsr)begin
            outReg   <= {FIFO_W{1'd0}};
            outValid <= 1'd0;
        end
        else begin
            outReg   <= outRegInt;
            outValid <= outValidInt;
        end
    end

    assign popData = outReg[USR_DATA_W-1:0];
    assign popVb   = outValid ? outReg[BIT_VB_MSB:BIT_VB0] : {VB_W{1'd0}};
    assign popSfp  = outValid & outReg[BIT_SFP];
    assign popEfp  = outValid & outReg[BIT_EFP];
    assign popErr  = outValid & outReg[BIT_ERR];
    assign popPre  = outValid & outReg[BIT_PRE];

    UsrPktFilter #(
        .USR_DATA_W (USR_DATA_W)
    ) uUsrPktFilter (
        .clk            (clkUsr),
        .rstN           (rstNUsr),
        .stall          (1'd0),
        .inData         (popData),
        .inVb           (popVb),
        .inValid        (outValid),
        .inSfp          (popSfp),
        .inEfp          (popEfp),
        .inErr          (popErr),
        .inPreemptable  (popPre),
        .outData        (cdc2UsrPktBusData),
        .outVb          (cdc2UsrPktBusVb),
        .outValid       (cdc2UsrPktBusValid),
        .outSfp         (cdc2UsrPktBusSfp),
        .outEfp         (cdc2UsrPktBusEfp),
        .outErr         (cdc2UsrPktBusErr),
        .outPreemptable (cdc2UsrPktBusPreemptable)
    );

    assign rxFifoPeakCntInt = (rxFifoLevel > rxFifoPeakCnt) ? rxFifoLevel : rxFifoPeakCnt;
    always@(posedge clkUsr or negedge rstNUsr)begin
        if(!rstNUsr)begin
            rxFifoPeakCnt <= {`GMAC_CNT_W8{1'd0}};
        end
        else begin
            rxFifoPeakCnt <= rxFifoPeakCntInt;
        end
    end

//======================================================
// 端口计数 @ clkRx / clkUsr。无 Stall，Valid 即一拍。计满回绕
//======================================================

    always@(posedge clkRx or negedge rstNRx)begin
        if(!rstNRx)begin
            rxInSfpCnt   <= {`GMAC_CNT_W16{1'd0}};
            rxInEfpCnt   <= {`GMAC_CNT_W16{1'd0}};
            rxInVbCnt    <= {`GMAC_CNT_W32{1'd0}};
            rxInValidCnt <= {`GMAC_CNT_W32{1'd0}};
            rxInErrCnt   <= {`GMAC_CNT_W8{1'd0}};
        end
        else if(rs2CdcPktBusValid)begin
            if(rs2CdcPktBusSfp)
                rxInSfpCnt <= rxInSfpCnt + {{(`GMAC_CNT_W16-1){1'd0}},1'd1};
            if(rs2CdcPktBusEfp)
                rxInEfpCnt <= rxInEfpCnt + {{(`GMAC_CNT_W16-1){1'd0}},1'd1};
            rxInValidCnt <= rxInValidCnt + {{(`GMAC_CNT_W32-1){1'd0}},1'd1};
            if(rs2CdcPktBusErr)
                rxInErrCnt <= rxInErrCnt + {{(`GMAC_CNT_W8-1){1'd0}},1'd1};
            rxInVbCnt <= rxInVbCnt + {{(`GMAC_CNT_W32-1){1'd0}},1'd1};
        end
    end

    always@(posedge clkUsr or negedge rstNUsr)begin
        if(!rstNUsr)begin
            rxOutSfpCnt   <= {`GMAC_CNT_W16{1'd0}};
            rxOutEfpCnt   <= {`GMAC_CNT_W16{1'd0}};
            rxOutVbCnt    <= {`GMAC_CNT_W32{1'd0}};
            rxOutValidCnt <= {`GMAC_CNT_W32{1'd0}};
            rxOutErrCnt   <= {`GMAC_CNT_W8{1'd0}};
        end
        else if(cdc2UsrPktBusValid)begin
            if(cdc2UsrPktBusSfp)
                rxOutSfpCnt <= rxOutSfpCnt + {{(`GMAC_CNT_W16-1){1'd0}},1'd1};
            if(cdc2UsrPktBusEfp)
                rxOutEfpCnt <= rxOutEfpCnt + {{(`GMAC_CNT_W16-1){1'd0}},1'd1};
            rxOutValidCnt <= rxOutValidCnt + {{(`GMAC_CNT_W32-1){1'd0}},1'd1};
            if(cdc2UsrPktBusErr)
                rxOutErrCnt <= rxOutErrCnt + {{(`GMAC_CNT_W8-1){1'd0}},1'd1};
            rxOutVbCnt <= rxOutVbCnt + {{(`GMAC_CNT_W32-`GMAC_VB_W){1'd0}}, cdc2UsrPktBusVb};
        end
    end

endmodule
