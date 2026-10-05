// +FHDR----------------------------------------------------------------------------
// Device        : Xilinx
// Author        : fxdqe
// Email         : 1706260166@qq.com
// Created On    : 2026/09/16 21:05
// File Name     : PcsCodec.v
// Description   : 8B/10B 与有序集；近端环回与管理域 CDC 在本模块内。
//                 rstN 为 rstNCore，内部同步到 tx/rx/mgmt。
//
// ---------------------------------------------------------------------------------
// Modification History:
// Date         By              Version                 Change Description
// ---------------------------------------------------------------------------------
// 2026/09/16   fxdqe           1.0                     Interface template
// 2026/09/18   fxdqe           1.1                     单路复位，分域同步
// 2026/10/01   fxdqe           1.2                     Enc 命名 / W32 / 分区注释
// 2026/10/01   fxdqe           1.3                     环回预取口改为 fifoPopData
// 2026/10/01   fxdqe           1.4                     IP_ResetSync；FIFO 分域复位
// 2026/10/01   fxdqe           1.5                     去掉环回 GmacFifoRst
// 2026/10/03   fxdqe           1.6                     环回 Pop 积 4 个码组后启动
// 2026/10/04   fxdqe           1.7                     环回 AlFull/AlEmpty 阈值改寄存器
// 2026/10/05   fxdqe           1.8                     同步器去掉源时钟端口
// -FHDR----------------------------------------------------------------------------

`include "GmacIf.vh"

module PcsCodec(/*autoarg*/
        //Inputs
        clkTx, clkRx, clkMgmt, rstN, txEn, rxEn, loopback,
        loopbackAlFullThrd, loopbackAlEmptyThrd,
        rs2PcsPktBusData, rs2PcsPktBusValid, rs2PcsPktBusSfp,
        rs2PcsPktBusEfp, rs2PcsPktBusErr, rs2PcsPktBusPreemptable,
        gbx2PcsCodeBusCodeGroup,
        //Outputs
        rs2PcsPktBusStall, pcs2RsPktBusData, pcs2RsPktBusValid,
        pcs2RsPktBusSfp, pcs2RsPktBusEfp, pcs2RsPktBusErr,
        pcs2RsPktBusPreemptable, pcs2GbxCodeBusCodeGroup,
        pcs2RsSyncStatus, pcsRxSync, pcsTxState, pcsTxEven, pcsTxRd,
        pcsRxSyncState, pcsRxEven, pcsRxRd, lossOfSyncCnt, codeVCnt
);

//######################################################
//Interface
//######################################################

parameter LOOPBACK_FIFO_DEPTH = 16;

input                   clkTx;
input                   clkRx;
input                   clkMgmt;
input                   rstN;
input                   txEn;
input                   rxEn;
input                   loopback;
input  [7:0]            loopbackAlFullThrd;
input  [7:0]            loopbackAlEmptyThrd;

input  [`GMAC_BYTE_W-1:0] rs2PcsPktBusData;
input                   rs2PcsPktBusValid;
input                   rs2PcsPktBusSfp;
input                   rs2PcsPktBusEfp;
input                   rs2PcsPktBusErr;
input                   rs2PcsPktBusPreemptable;
output                  rs2PcsPktBusStall;

output [`GMAC_BYTE_W-1:0] pcs2RsPktBusData;
output                  pcs2RsPktBusValid;
output                  pcs2RsPktBusSfp;
output                  pcs2RsPktBusEfp;
output                  pcs2RsPktBusErr;
output                  pcs2RsPktBusPreemptable;

output [`GMAC_CODE_W-1:0] pcs2GbxCodeBusCodeGroup;
input  [`GMAC_CODE_W-1:0] gbx2PcsCodeBusCodeGroup;

output                  pcs2RsSyncStatus;
output                  pcsRxSync;
output [1:0]            pcsTxState;
output                  pcsTxEven;
output                  pcsTxRd;
output [2:0]            pcsRxSyncState;
output                  pcsRxEven;
output                  pcsRxRd;
output [`GMAC_CNT_W32-1:0] lossOfSyncCnt;
output [`GMAC_CNT_W32-1:0] codeVCnt;

//######################################################
//Value
//######################################################

localparam LOOPBACK_ADDR_W = LOOPBACK_FIFO_DEPTH<=4   ? 2:
                             LOOPBACK_FIFO_DEPTH<=8   ? 3:
                             LOOPBACK_FIFO_DEPTH<=16  ? 4:
                             LOOPBACK_FIFO_DEPTH<=32  ? 5: 6;
localparam LOOPBACK_PTR_W  = LOOPBACK_ADDR_W + 1;
localparam [LOOPBACK_PTR_W-1:0] LOOPBACK_ZERO = {LOOPBACK_PTR_W{1'b0}};
localparam [LOOPBACK_PTR_W-1:0] LOOPBACK_POP_START =
    {{(LOOPBACK_PTR_W-3){1'b0}}, 3'd4};

wire                       rstNTx;
wire                       rstNRx;
wire                       rstNMgmt;
wire                       txEnTx;
wire                       rxEnRx;
wire                       loopbackTx;
wire                       loopbackRx;
wire [7:0]                 loopbackAlFullThrdTx;
wire [7:0]                 loopbackAlEmptyThrdTx;
wire [7:0]                 loopbackAlEmptyThrdRx;

wire [`GMAC_CODE_W-1:0]    pcs2GbxCodeBusCodeGroupEnc;
wire [`GMAC_CODE_W-1:0]    gbx2PcsCodeBusToSync;
wire [`GMAC_CODE_W-1:0]    loopbackPopData;
wire                       loopbackEmpty;
wire                       loopbackAlEmpty;
wire                       loopbackFull;
wire                       loopbackPush;
wire                       loopbackPop;
wire                       loopbackAlFull;
wire [LOOPBACK_PTR_W-1:0]  loopbackDepth;
wire                       loopbackRunNxt;
wire                       rstNFifoLbTx;
wire                       rstNFifoLbRx;
reg                        skipI;
wire                       isCommaTx;
reg                        insHalf;
reg                        idleRd;
reg                        loopbackRun;
wire [`GMAC_CODE_W-1:0]    idleCg;
wire                       idleRdN;
wire                       inserting;

wire [`GMAC_BYTE_W-1:0]    sync2DecOctet;
wire                       sync2DecIsK;
wire                       sync2DecRxRd;
wire                       sync2DecRxEven;
wire                       sync2DecSyncStatus;
wire                       sync2DecCgBad;

wire [`GMAC_BYTE_W-1:0]    dec2MarkOctet;
wire                       dec2MarkIsK;
wire                       dec2MarkInvalid;
wire                       dec2MarkRxRd;
wire                       dec2MarkRxEven;
wire                       dec2MarkSyncStatus;
wire                       dec2MarkCgBad;

wire [1:0]                 pcsTxStateTx;
wire                       pcsTxEvenTx;
wire                       pcsTxRdTx;
wire [2:0]                 pcsRxSyncStateRx;
wire                       pcsRxEvenRx;
wire                       pcsRxRdRx;
wire [`GMAC_CNT_W32-1:0]   lossOfSyncCntRx;
wire [`GMAC_CNT_W32-1:0]   codeVCntRx;

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
// Mgmt CDC：配置下发与状态/计数上报
//======================================================

    IP_Sync #(.DATA_WIDTH(1)) uTxEn (
        .clockOut (clkTx),
        .reset    (rstNTx),
        .dataIn   (txEn),
        .dataOut  (txEnTx)
    );

    IP_Sync #(.DATA_WIDTH(1)) uRxEn (
        .clockOut (clkRx),
        .reset    (rstNRx),
        .dataIn   (rxEn),
        .dataOut  (rxEnRx)
    );

    IP_Sync #(.DATA_WIDTH(1)) uLoopbackTx (
        .clockOut (clkTx),
        .reset    (rstNTx),
        .dataIn   (loopback),
        .dataOut  (loopbackTx)
    );

    IP_Sync #(.DATA_WIDTH(1)) uLoopbackRx (
        .clockOut (clkRx),
        .reset    (rstNRx),
        .dataIn   (loopback),
        .dataOut  (loopbackRx)
    );

    IP_Sync #(.DATA_WIDTH(8)) uLbAlFullThrd (
        .clockOut (clkTx),
        .reset    (rstNTx),
        .dataIn   (loopbackAlFullThrd),
        .dataOut  (loopbackAlFullThrdTx)
    );

    IP_Sync #(.DATA_WIDTH(8)) uLbAlEmptyThrdTx (
        .clockOut (clkTx),
        .reset    (rstNTx),
        .dataIn   (loopbackAlEmptyThrd),
        .dataOut  (loopbackAlEmptyThrdTx)
    );

    IP_Sync #(.DATA_WIDTH(8)) uLbAlEmptyThrdRx (
        .clockOut (clkRx),
        .reset    (rstNRx),
        .dataIn   (loopbackAlEmptyThrd),
        .dataOut  (loopbackAlEmptyThrdRx)
    );

    IP_Sync #(.DATA_WIDTH(1)) uPcsRxSyncMgmt (
        .clockOut (clkMgmt),
        .reset    (rstNMgmt),
        .dataIn   (sync2DecSyncStatus),
        .dataOut  (pcsRxSync)
    );

    IP_Sync #(.DATA_WIDTH(2)) uPcsTxState (
        .clockOut (clkMgmt),
        .reset    (rstNMgmt),
        .dataIn   (pcsTxStateTx),
        .dataOut  (pcsTxState)
    );

    IP_Sync #(.DATA_WIDTH(1)) uPcsTxEven (
        .clockOut (clkMgmt),
        .reset    (rstNMgmt),
        .dataIn   (pcsTxEvenTx),
        .dataOut  (pcsTxEven)
    );

    IP_Sync #(.DATA_WIDTH(1)) uPcsTxRd (
        .clockOut (clkMgmt),
        .reset    (rstNMgmt),
        .dataIn   (pcsTxRdTx),
        .dataOut  (pcsTxRd)
    );

    IP_Sync #(.DATA_WIDTH(3)) uPcsRxSyncState (
        .clockOut (clkMgmt),
        .reset    (rstNMgmt),
        .dataIn   (pcsRxSyncStateRx),
        .dataOut  (pcsRxSyncState)
    );

    IP_Sync #(.DATA_WIDTH(1)) uPcsRxEven (
        .clockOut (clkMgmt),
        .reset    (rstNMgmt),
        .dataIn   (pcsRxEvenRx),
        .dataOut  (pcsRxEven)
    );

    IP_Sync #(.DATA_WIDTH(1)) uPcsRxRd (
        .clockOut (clkMgmt),
        .reset    (rstNMgmt),
        .dataIn   (pcsRxRdRx),
        .dataOut  (pcsRxRd)
    );

    IP_DataGraySync #(.DATAWIDTH(`GMAC_CNT_W32)) uLossOfSyncCnt (
        .dataA  (lossOfSyncCntRx),
        .clockB (clkMgmt),
        .dataB  (lossOfSyncCnt)
    );

    IP_DataGraySync #(.DATAWIDTH(`GMAC_CNT_W32)) uCodeVCnt (
        .dataA  (codeVCntRx),
        .clockB (clkMgmt),
        .dataB  (codeVCnt)
    );

//======================================================
// Loopback：近端环回 FIFO 与速率适配
//======================================================

    assign isCommaTx = (pcs2GbxCodeBusCodeGroupEnc[6:0] == 7'b1111100) |
                       (pcs2GbxCodeBusCodeGroupEnc[6:0] == 7'b0000011);

    // 环回关闭时拉住本侧复位，避免残指针在打开环回时流出。
    // 双钟释放握手在 IP_AsyncFifo 内。
    assign rstNFifoLbTx = rstNTx & loopbackTx;
    assign rstNFifoLbRx = rstNRx & loopbackRx;

    always@(posedge clkTx or negedge rstNFifoLbTx) begin
        if (!rstNFifoLbTx)
            skipI <= 1'b0;
        else if (loopbackTx && loopbackAlFull && isCommaTx)
            skipI <= 1'b1;
        else
            skipI <= 1'b0;
    end

    assign loopbackPush = loopbackTx & ~loopbackFull & rstNFifoLbTx &
                          ~((loopbackAlFull & isCommaTx) | skipI);

    Gmac8b10bEnc uLbIdle (
        .octet     (insHalf ? 8'h50 : 8'hBC),
        .isK       (~insHalf),
        .rd        (idleRd),
        .codeGroup (idleCg),
        .rdNext    (idleRdN),
        .invalid   ()
    );

    // 读侧先积 4 个码组再放行 Pop。深度低于 AlEmpty 阈值时插 /I/。
    // IP 的 fifoAlEmpty 比较写侧 storeCnt；插入在读钟，改比 fifoDepth。
    assign loopbackRunNxt  = loopbackRun | (loopbackDepth >= LOOPBACK_POP_START);
    assign loopbackAlEmpty = loopbackDepth < loopbackAlEmptyThrdRx[LOOPBACK_PTR_W-1:0];
    assign inserting       = loopbackRx & (~loopbackRun | loopbackAlEmpty | insHalf);
    assign loopbackPop    = loopbackRx & loopbackRun & ~loopbackEmpty &
                            ~inserting & rstNFifoLbRx;

    always@(posedge clkRx or negedge rstNFifoLbRx) begin
        if (!rstNFifoLbRx) begin
            insHalf     <= 1'b0;
            idleRd      <= 1'b0;
            loopbackRun <= 1'b0;
        end
        else begin
            loopbackRun <= loopbackRunNxt;
            if (loopbackRx && inserting) begin
                insHalf <= ~insHalf;
                idleRd  <= idleRdN;
            end
        end
    end

    IP_AsyncFifo #(
        .DATA_WIDTH ( `GMAC_CODE_W ),
        .FIFO_DEPTH ( LOOPBACK_FIFO_DEPTH )
    ) uLoopbackFifo (
        .clockIn         (clkTx),
        .clockOut        (clkRx),
        .resetIn         (rstNFifoLbTx),
        .resetOut        (rstNFifoLbRx),
        .fifoPush        (loopbackPush),
        .fifoPushData    (pcs2GbxCodeBusCodeGroupEnc),
        .fifoPop         (loopbackPop),
        .fifoPopData     (loopbackPopData),
        .fifoDepth       (loopbackDepth),
        .fifoAlFullThrd  (loopbackAlFullThrdTx[LOOPBACK_PTR_W-1:0]),
        .fifoAlEmptyThrd (loopbackAlEmptyThrdTx[LOOPBACK_PTR_W-1:0]),
        .fifoTxFifoThrd  (LOOPBACK_ZERO),
        .fifoAlFull      (loopbackAlFull),
        .fifoAlEmpty     (),
        .fifoValid       (),
        .overRun         (),
        .underRun        (),
        .fifoEmpty       (loopbackEmpty),
        .fifoFull        (loopbackFull)
    );

    assign gbx2PcsCodeBusToSync = ~loopbackRx ? gbx2PcsCodeBusCodeGroup :
                                  (inserting ? idleCg : loopbackPopData);
    assign pcs2GbxCodeBusCodeGroup = pcs2GbxCodeBusCodeGroupEnc;
    assign pcs2RsSyncStatus = sync2DecSyncStatus;
    assign pcsRxEvenRx = dec2MarkRxEven;
    assign pcsRxRdRx   = dec2MarkRxRd;

//======================================================
// Tx：编码
//======================================================

    PcsTxEncode uPcsTxEncode (
        .clkTx                     (clkTx),
        .rstN                      (rstNTx),
        .txEn                      (txEnTx),
        .rs2PcsPktBusData          (rs2PcsPktBusData),
        .rs2PcsPktBusValid         (rs2PcsPktBusValid),
        .rs2PcsPktBusSfp           (rs2PcsPktBusSfp),
        .rs2PcsPktBusEfp           (rs2PcsPktBusEfp),
        .rs2PcsPktBusErr           (rs2PcsPktBusErr),
        .rs2PcsPktBusPreemptable   (rs2PcsPktBusPreemptable),
        .rs2PcsPktBusStall         (rs2PcsPktBusStall),
        .pcs2GbxCodeBusCodeGroup   (pcs2GbxCodeBusCodeGroupEnc),
        .pcsTxState                (pcsTxStateTx),
        .pcsTxEven                 (pcsTxEvenTx),
        .pcsTxRd                   (pcsTxRdTx)
    );

//======================================================
// Rx：同步 / 解码 / 有序集标注
//======================================================

    PcsRxSync uPcsRxSync (
        .clkRx                     (clkRx),
        .rstN                      (rstNRx),
        .gbx2PcsCodeBusCodeGroup   (gbx2PcsCodeBusToSync),
        .sync2DecOctet             (sync2DecOctet),
        .sync2DecIsK               (sync2DecIsK),
        .sync2DecRxRd              (sync2DecRxRd),
        .sync2DecRxEven            (sync2DecRxEven),
        .sync2DecSyncStatus        (sync2DecSyncStatus),
        .sync2DecCgBad             (sync2DecCgBad),
        .pcsRxSyncState            (pcsRxSyncStateRx),
        .lossOfSyncCnt             (lossOfSyncCntRx)
    );

    PcsRxDecode uPcsRxDecode (
        .clkRx                     (clkRx),
        .rstN                      (rstNRx),
        .sync2DecOctet             (sync2DecOctet),
        .sync2DecIsK               (sync2DecIsK),
        .sync2DecRxRd              (sync2DecRxRd),
        .sync2DecRxEven            (sync2DecRxEven),
        .sync2DecSyncStatus        (sync2DecSyncStatus),
        .sync2DecCgBad             (sync2DecCgBad),
        .dec2MarkOctet             (dec2MarkOctet),
        .dec2MarkIsK               (dec2MarkIsK),
        .dec2MarkInvalid           (dec2MarkInvalid),
        .dec2MarkRxRd              (dec2MarkRxRd),
        .dec2MarkRxEven            (dec2MarkRxEven),
        .dec2MarkSyncStatus        (dec2MarkSyncStatus),
        .dec2MarkCgBad             (dec2MarkCgBad)
    );

    PcsRxMark uPcsRxMark (
        .clkRx                     (clkRx),
        .rstN                      (rstNRx),
        .rxEn                      (rxEnRx),
        .pcs2RsSyncStatus          (sync2DecSyncStatus),
        .dec2MarkOctet             (dec2MarkOctet),
        .dec2MarkIsK               (dec2MarkIsK),
        .dec2MarkInvalid           (dec2MarkInvalid),
        .dec2MarkRxRd              (dec2MarkRxRd),
        .dec2MarkRxEven            (dec2MarkRxEven),
        .dec2MarkSyncStatus        (dec2MarkSyncStatus),
        .dec2MarkCgBad             (dec2MarkCgBad),
        .pcs2RsPktBusData          (pcs2RsPktBusData),
        .pcs2RsPktBusValid         (pcs2RsPktBusValid),
        .pcs2RsPktBusSfp           (pcs2RsPktBusSfp),
        .pcs2RsPktBusEfp           (pcs2RsPktBusEfp),
        .pcs2RsPktBusErr           (pcs2RsPktBusErr),
        .pcs2RsPktBusPreemptable   (pcs2RsPktBusPreemptable),
        .codeVCnt                  (codeVCntRx)
    );

endmodule
