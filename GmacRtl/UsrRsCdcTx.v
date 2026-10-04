// +FHDR----------------------------------------------------------------------------
// Device        : Xilinx
// Author        : fxdqe
// Email         : 1706260166@qq.com
// Created On    : 2026/09/16 21:05
// File Name     : UsrRsCdcTx.v
// Description   : 用户 Tx 128b@clkUsr -> IP_AsyncFifo 严格隔离 -> 拆 8b@clkTx。
//                 以 FIFO 为界：写侧 Push，读侧 Pop。
//                 Push 前经 UsrPktFilter。Stall 上的 Valid、包外无 Sfp 或 Vb=0 不写入。
//                 反压时仍来 Valid 记 txOverRunCnt；原始 Vb 非法仍记 txVbErrCnt。
//                 FIFO 的 overRun/underRun 不会出现：Push 被 Full 挡住，Pop 只在非空时发生。
//                 读侧欠载是包已开启发而 FIFO 空，按缺口上升沿记 txUnderRunCnt。
//                 Pop 端信任 FIFO 内 Vb，不再钳位。
//                 入口/出口各计 Sfp、Efp、Vb、Valid、Err。有 Stall 的口按 fire 计。
//                 128b 口 Vb 累加本拍 Vb；8b 口每拍加 1。计满回绕到 0。
//                 Pop：计数从 fifoPopData（预取，即队头）选字节输出；Sfp 由开启发状态产生，
//                 Efp/Err 由 FIFO 词内标志与末字节计数共同产生。
//                 高字节先发；Vb 标识本拍有效字节数。
//                 rstNUsr/rstNTx 已是本时钟域同步释放复位。
//
// ---------------------------------------------------------------------------------
// Modification History:
// Date         By              Version                 Change Description
// ---------------------------------------------------------------------------------
// 2026/09/16   fxdqe           1.0                     Original
// 2026/09/18   fxdqe           1.1                     分域复位
// 2026/10/01   fxdqe           1.2                     读侧按取用状态/计数/VB 重写
// 2026/10/01   fxdqe           1.3                     接口 Vb + 高字节先发
// 2026/10/01   fxdqe           1.4                     Push/Pop 以 FIFO 分割重写
// 2026/10/01   fxdqe           1.5                     Int/F1/Cnt 命名与 VbErr
// 2026/10/01   fxdqe           1.6                     预取口改为 fifoPopData
// 2026/10/01   fxdqe           1.7                     FIFO 分域 resetIn/resetOut
// 2026/10/01   fxdqe           1.8                     字节选择改 case；inPkt 单表达式
// 2026/10/01   fxdqe           1.9                     过载/欠载不再用 FIFO 标志
// 2026/10/01   fxdqe           1.10                    Push 前接 UsrPktFilter
// 2026/10/01   fxdqe           1.11                    入口/出口 Sfp Efp Vb Valid Err 计数
// 2026/10/01   fxdqe           1.12                    端口计数计满回绕
// -FHDR----------------------------------------------------------------------------

`include "GmacIf.vh"

module UsrRsCdcTx(/*autoarg*/
        //Inputs
        clkUsr, clkTx, rstNUsr, rstNTx,
        usr2CdcPktBusData, usr2CdcPktBusVb, usr2CdcPktBusValid, usr2CdcPktBusSfp,
        usr2CdcPktBusEfp, usr2CdcPktBusErr, usr2CdcPktBusPreemptable,
        cdc2RsPktBusStall, fifoTxFifoThrd,
        //Outputs
        usr2CdcPktBusStall, cdc2RsPktBusData, cdc2RsPktBusValid,
        cdc2RsPktBusSfp, cdc2RsPktBusEfp, cdc2RsPktBusErr,
        cdc2RsPktBusPreemptable, txFifoLevel, fifoAlFull, txFifoPeakCnt,
        txOverRunCnt, txUnderRunCnt, txVbErrCnt,
        txInSfpCnt, txInEfpCnt, txInVbCnt, txInValidCnt, txInErrCnt,
        txOutSfpCnt, txOutEfpCnt, txOutVbCnt, txOutValidCnt, txOutErrCnt
);

//######################################################
//Interface
//######################################################

parameter USR_DATA_W        = `GMAC_USR_W;
parameter FIFO_DEPTH        = 16;
parameter FIFO_AL_FULL_THRD = FIFO_DEPTH - 3;

localparam ADDR_WIDTH = FIFO_DEPTH<=4  ? 2:
                        FIFO_DEPTH<=8  ? 3:
                        FIFO_DEPTH<=16 ? 4:
                        FIFO_DEPTH<=32 ? 5: 6;
localparam PTR_W      = ADDR_WIDTH + 1;
// {pre, err, efp, sfp, vb[4:0], data[127:0]}  vb=1..16
localparam VB_W       = `GMAC_VB_W;
localparam FIFO_W     = USR_DATA_W + VB_W + 4;
localparam BIT_VB0    = USR_DATA_W;
localparam BIT_VB_MSB = USR_DATA_W + VB_W - 1;
localparam BIT_SFP    = USR_DATA_W + VB_W;
localparam BIT_EFP    = USR_DATA_W + VB_W + 1;
localparam BIT_ERR    = USR_DATA_W + VB_W + 2;
localparam BIT_PRE    = USR_DATA_W + VB_W + 3;

input                   clkUsr;
input                   clkTx;
input                   rstNUsr;
input                   rstNTx;

input  [USR_DATA_W-1:0] usr2CdcPktBusData;
input  [VB_W-1:0]       usr2CdcPktBusVb;
input                   usr2CdcPktBusValid;
input                   usr2CdcPktBusSfp;
input                   usr2CdcPktBusEfp;
input                   usr2CdcPktBusErr;
input                   usr2CdcPktBusPreemptable;
output                  usr2CdcPktBusStall;

output [`GMAC_BYTE_W-1:0] cdc2RsPktBusData;
output                  cdc2RsPktBusValid;
output                  cdc2RsPktBusSfp;
output                  cdc2RsPktBusEfp;
output                  cdc2RsPktBusErr;
output                  cdc2RsPktBusPreemptable;
input                   cdc2RsPktBusStall;
input  [7:0]            fifoTxFifoThrd;

output [`GMAC_CNT_W8-1:0]     txFifoLevel;
output                        fifoAlFull;
output reg [`GMAC_CNT_W8-1:0]  txFifoPeakCnt;
output reg [`GMAC_CNT_W32-1:0] txOverRunCnt;
output reg [`GMAC_CNT_W32-1:0] txUnderRunCnt;
output reg [`GMAC_CNT_W32-1:0] txVbErrCnt;
output reg [`GMAC_CNT_W16-1:0] txInSfpCnt;
output reg [`GMAC_CNT_W16-1:0] txInEfpCnt;
output reg [`GMAC_CNT_W32-1:0] txInVbCnt;
output reg [`GMAC_CNT_W32-1:0] txInValidCnt;
output reg [`GMAC_CNT_W8-1:0]  txInErrCnt;
output reg [`GMAC_CNT_W16-1:0] txOutSfpCnt;
output reg [`GMAC_CNT_W16-1:0] txOutEfpCnt;
output reg [`GMAC_CNT_W32-1:0] txOutVbCnt;
output reg [`GMAC_CNT_W32-1:0] txOutValidCnt;
output reg [`GMAC_CNT_W8-1:0]  txOutErrCnt;

//######################################################
//Value
//######################################################

wire [PTR_W-1:0]           alFullThrd;
wire [PTR_W-1:0]           txThrd;
wire [PTR_W-1:0]           alEmptyThrd;
wire [FIFO_W-1:0]          fifoPushData;
wire                       fifoPush;
wire                       fifoPop;
wire [FIFO_W-1:0]          fifoPopData;
wire [PTR_W-1:0]           fifoDepth;
wire                       fifoEmpty;
wire                       fifoFull;
wire                       fifoValid;

wire                       pushViolate;
wire                       vbIllegal;
wire [USR_DATA_W-1:0]      fltData;
wire [VB_W-1:0]            fltVb;
wire                       fltValid;
wire                       fltSfp;
wire                       fltEfp;
wire                       fltErr;
wire                       fltPre;
wire [`GMAC_CNT_W32-1:0]   txOverRunCntInt;
wire [`GMAC_CNT_W32-1:0]   txVbErrCntInt;

wire [VB_W-1:0]            headVb;
wire                       headEfp;
wire                       headErr;
wire                       headPre;
wire [3:0]                 lastByteIdx;
wire                       isLastByte;
wire                       canBeat;
wire                       rsFire;
reg  [`GMAC_BYTE_W-1:0]    byteData;
wire                       inPktInt;
wire [3:0]                 byteCntInt;
wire                       underRunGap;
wire                       underRunEvt;
wire [`GMAC_CNT_W32-1:0]   txUnderRunCntInt;
wire [`GMAC_CNT_W8-1:0]    txFifoPeakCntInt;
wire                       inFire;

reg                        inPkt;
reg  [3:0]                 byteCnt;
reg                        underRunGapF1;

//######################################################
//Logic
//######################################################

//======================================================
// FIFO
//======================================================

    assign alFullThrd  = FIFO_AL_FULL_THRD[PTR_W-1:0];
    assign txThrd      = fifoTxFifoThrd[PTR_W-1:0];
    assign alEmptyThrd = {{ADDR_WIDTH{1'd0}},1'd1};

    IP_AsyncFifo #(
        .DATA_WIDTH (FIFO_W),
        .FIFO_DEPTH (FIFO_DEPTH)
    ) uTxFifo (
        .clockIn         (clkUsr),
        .clockOut        (clkTx),
        .resetIn         (rstNUsr),
        .resetOut        (rstNTx),
        .fifoPush        (fifoPush),
        .fifoPushData    (fifoPushData),
        .fifoPop         (fifoPop),
        .fifoPopData     (fifoPopData),
        .fifoDepth       (fifoDepth),
        .fifoAlFullThrd  (alFullThrd),
        .fifoAlEmptyThrd (alEmptyThrd),
        .fifoTxFifoThrd  (txThrd),
        .fifoAlFull      (fifoAlFull),
        .fifoAlEmpty     (),
        .fifoValid       (fifoValid),
        .overRun         (),
        .underRun        (),
        .fifoEmpty       (fifoEmpty),
        .fifoFull        (fifoFull)
    );

    assign txFifoLevel = {{(8-PTR_W){1'd0}},fifoDepth};

//======================================================
// Push @ clkUsr：反压看 AlFull，写入看 Full
// 流水上可能还有未写入的拍，AlFull 到 Full 留出裕量
//======================================================

    assign usr2CdcPktBusStall = fifoAlFull | (~rstNUsr);
    assign pushViolate        = usr2CdcPktBusValid & usr2CdcPktBusStall;

    // 原始 Vb 非法仍记错。写入 FIFO 的是过滤后的拍，Vb 已是 1..16 或本拍不写
    assign vbIllegal = usr2CdcPktBusValid &
                       ((usr2CdcPktBusVb == {VB_W{1'd0}}) | (usr2CdcPktBusVb > 5'd16));

    UsrPktFilter #(
        .USR_DATA_W (USR_DATA_W)
    ) uUsrPktFilter (
        .clk            (clkUsr),
        .rstN           (rstNUsr),
        .stall          (usr2CdcPktBusStall),
        .inData         (usr2CdcPktBusData),
        .inVb           (usr2CdcPktBusVb),
        .inValid        (usr2CdcPktBusValid),
        .inSfp          (usr2CdcPktBusSfp),
        .inEfp          (usr2CdcPktBusEfp),
        .inErr          (usr2CdcPktBusErr),
        .inPreemptable  (usr2CdcPktBusPreemptable),
        .outData        (fltData),
        .outVb          (fltVb),
        .outValid       (fltValid),
        .outSfp         (fltSfp),
        .outEfp         (fltEfp),
        .outErr         (fltErr),
        .outPreemptable (fltPre)
    );

    assign fifoPush     = fltValid & ~fifoFull;
    assign fifoPushData = {fltPre, fltErr, fltEfp, fltSfp, fltVb, fltData};

    // 反压期间仍来 Valid：本拍不该再写。Full 已挡住 Push，FIFO overRun 不会置位
    assign txOverRunCntInt = (pushViolate &&
                              (txOverRunCnt != {`GMAC_CNT_W32{1'd1}})) ?
                             (txOverRunCnt + {{(`GMAC_CNT_W32-1){1'd0}},1'd1}) :
                              txOverRunCnt;
    always@(posedge clkUsr or negedge rstNUsr)begin
        if(!rstNUsr)begin
            txOverRunCnt <= {`GMAC_CNT_W32{1'd0}};
        end
        else begin
            txOverRunCnt <= txOverRunCntInt;
        end
    end

    assign txVbErrCntInt = (vbIllegal && (txVbErrCnt != {`GMAC_CNT_W32{1'd1}})) ?
                           (txVbErrCnt + {{(`GMAC_CNT_W32-1){1'd0}},1'd1}) :
                            txVbErrCnt;
    always@(posedge clkUsr or negedge rstNUsr)begin
        if(!rstNUsr)begin
            txVbErrCnt <= {`GMAC_CNT_W32{1'd0}};
        end
        else begin
            txVbErrCnt <= txVbErrCntInt;
        end
    end

//======================================================
// Pop @ clkTx：计数从 fifoPopData 选字节，产生 sfp/efp（Vb 不再钳位）
//======================================================

    assign headVb  = fifoPopData[BIT_VB_MSB:BIT_VB0];
    assign headEfp = fifoPopData[BIT_EFP];
    assign headErr = fifoPopData[BIT_ERR];
    assign headPre = fifoPopData[BIT_PRE];

    // Vb=1..16（Push 已保证）-> 末字节下标；Vb=16 时低 4bit=0，减 1 回绕为 15
    assign lastByteIdx = headVb[3:0] - 4'd1;
    assign isLastByte  = (byteCnt == lastByteIdx);

    // 未开启发：fifoValid 水线开门；已在包内：只要 head 非空即可继续
    assign canBeat  = ~fifoEmpty & (inPkt | fifoValid);
    assign rsFire   = canBeat & ~cdc2RsPktBusStall;
    assign fifoPop  = rsFire & isLastByte;

    // 高字节先发：byteCnt=0 取 [127:120]；case 综合为并行选择
    always@(*)begin
        case(byteCnt)
            4'h0:    byteData = fifoPopData[8*15 +: 8];
            4'h1:    byteData = fifoPopData[8*14 +: 8];
            4'h2:    byteData = fifoPopData[8*13 +: 8];
            4'h3:    byteData = fifoPopData[8*12 +: 8];
            4'h4:    byteData = fifoPopData[8*11 +: 8];
            4'h5:    byteData = fifoPopData[8*10 +: 8];
            4'h6:    byteData = fifoPopData[8*9  +: 8];
            4'h7:    byteData = fifoPopData[8*8  +: 8];
            4'h8:    byteData = fifoPopData[8*7  +: 8];
            4'h9:    byteData = fifoPopData[8*6  +: 8];
            4'hA:    byteData = fifoPopData[8*5  +: 8];
            4'hB:    byteData = fifoPopData[8*4  +: 8];
            4'hC:    byteData = fifoPopData[8*3  +: 8];
            4'hD:    byteData = fifoPopData[8*2  +: 8];
            4'hE:    byteData = fifoPopData[8*1  +: 8];
            default: byteData = fifoPopData[8*0  +: 8];
        endcase
    end

    assign cdc2RsPktBusValid       = canBeat;
    assign cdc2RsPktBusData        = byteData;
    assign cdc2RsPktBusSfp         = canBeat & ~inPkt;
    assign cdc2RsPktBusEfp         = canBeat & headEfp & isLastByte;
    assign cdc2RsPktBusErr         = canBeat & headErr & headEfp & isLastByte;
    assign cdc2RsPktBusPreemptable = canBeat & headPre;

    assign byteCntInt = rsFire ? (isLastByte ? 4'd0 : (byteCnt + 4'd1)) : byteCnt;
    always@(posedge clkTx or negedge rstNTx)begin
        if(!rstNTx)begin
            byteCnt <= 4'd0;
        end
        else begin
            byteCnt <= byteCntInt;
        end
    end

    // 发出一拍后置 1，保持到发出带 Efp 的末字节；反压未发出则保持
    assign inPktInt = (inPkt | rsFire) & ~(rsFire & isLastByte & headEfp);
    always@(posedge clkTx or negedge rstNTx)begin
        if(!rstNTx)begin
            inPkt <= 1'd0;
        end
        else begin
            inPkt <= inPktInt;
        end
    end

    // 包中词间空：用户带宽违约；缺口上升沿记一次
    assign underRunGap = inPkt & fifoEmpty;
    always@(posedge clkTx or negedge rstNTx)begin
        if(!rstNTx)begin
            underRunGapF1 <= 1'd0;
        end
        else begin
            underRunGapF1 <= underRunGap;
        end
    end

    // Pop 已要求非空，FIFO underRun 不会置位；只记包内读空的上升沿
    assign underRunEvt = underRunGap & ~underRunGapF1;
    assign txUnderRunCntInt = (underRunEvt && (txUnderRunCnt != {`GMAC_CNT_W32{1'd1}})) ?
                              (txUnderRunCnt + {{(`GMAC_CNT_W32-1){1'd0}},1'd1}) :
                               txUnderRunCnt;
    always@(posedge clkTx or negedge rstNTx)begin
        if(!rstNTx)begin
            txUnderRunCnt <= {`GMAC_CNT_W32{1'd0}};
        end
        else begin
            txUnderRunCnt <= txUnderRunCntInt;
        end
    end

    assign txFifoPeakCntInt = (txFifoLevel > txFifoPeakCnt) ? txFifoLevel : txFifoPeakCnt;
    always@(posedge clkTx or negedge rstNTx)begin
        if(!rstNTx)begin
            txFifoPeakCnt <= {`GMAC_CNT_W8{1'd0}};
        end
        else begin
            txFifoPeakCnt <= txFifoPeakCntInt;
        end
    end

//======================================================
// 端口计数 @ clkUsr / clkTx。fire 才计，反压保持的拍不计多次。计满回绕
//======================================================

    assign inFire = usr2CdcPktBusValid & ~usr2CdcPktBusStall;

    always@(posedge clkUsr or negedge rstNUsr)begin
        if(!rstNUsr)begin
            txInSfpCnt   <= {`GMAC_CNT_W16{1'd0}};
            txInEfpCnt   <= {`GMAC_CNT_W16{1'd0}};
            txInVbCnt    <= {`GMAC_CNT_W32{1'd0}};
            txInValidCnt <= {`GMAC_CNT_W32{1'd0}};
            txInErrCnt   <= {`GMAC_CNT_W8{1'd0}};
        end
        else if(inFire)begin
            if(usr2CdcPktBusSfp)
                txInSfpCnt <= txInSfpCnt + {{(`GMAC_CNT_W16-1){1'd0}},1'd1};
            if(usr2CdcPktBusEfp)
                txInEfpCnt <= txInEfpCnt + {{(`GMAC_CNT_W16-1){1'd0}},1'd1};
            txInValidCnt <= txInValidCnt + {{(`GMAC_CNT_W32-1){1'd0}},1'd1};
            if(usr2CdcPktBusErr)
                txInErrCnt <= txInErrCnt + {{(`GMAC_CNT_W8-1){1'd0}},1'd1};
            txInVbCnt <= txInVbCnt + {{(`GMAC_CNT_W32-`GMAC_VB_W){1'd0}}, usr2CdcPktBusVb};
        end
    end

    always@(posedge clkTx or negedge rstNTx)begin
        if(!rstNTx)begin
            txOutSfpCnt   <= {`GMAC_CNT_W16{1'd0}};
            txOutEfpCnt   <= {`GMAC_CNT_W16{1'd0}};
            txOutVbCnt    <= {`GMAC_CNT_W32{1'd0}};
            txOutValidCnt <= {`GMAC_CNT_W32{1'd0}};
            txOutErrCnt   <= {`GMAC_CNT_W8{1'd0}};
        end
        else if(rsFire)begin
            if(cdc2RsPktBusSfp)
                txOutSfpCnt <= txOutSfpCnt + {{(`GMAC_CNT_W16-1){1'd0}},1'd1};
            if(cdc2RsPktBusEfp)
                txOutEfpCnt <= txOutEfpCnt + {{(`GMAC_CNT_W16-1){1'd0}},1'd1};
            txOutValidCnt <= txOutValidCnt + {{(`GMAC_CNT_W32-1){1'd0}},1'd1};
            if(cdc2RsPktBusErr)
                txOutErrCnt <= txOutErrCnt + {{(`GMAC_CNT_W8-1){1'd0}},1'd1};
            txOutVbCnt <= txOutVbCnt + {{(`GMAC_CNT_W32-1){1'd0}},1'd1};
        end
    end

endmodule
