// +FHDR----------------------------------------------------------------------------
// Device        : Xilinx
// Author        : fxdqe
// Email         : 1706260166@qq.com
// Created On    : 2026/09/16 21:05
// File Name     : RsRxParser.v
// Description   : Rx 猎 SFD、直通 DA 起内容、延迟线剥 FCS；无 stall。
//                 rxDelCrc=1 时用延迟线丢掉 FCS。=0 时字节随到随出，FCS 也交出去，efp 在收到的最后一字节。
//                 rstN 已是 clkRx 域同步释放复位。
//                 出口比输入晚一拍，状态机用三段式。状态是独热码。
//
// ---------------------------------------------------------------------------------
// Modification History:
// Date         By              Version                 Change Description
// ---------------------------------------------------------------------------------
// 2026/09/16   fxdqe           1.0                     Original
// 2026/10/01   fxdqe           1.1                     Cnt 命名与 output reg
// 2026/10/03   fxdqe           1.2                     三段式、独热、CRC 例化 GmacCrc32
// 2026/10/03   fxdqe           1.3                     rxDelCrc 控制是否剥 FCS
// 2026/10/03   fxdqe           1.4                     保留 FCS 时不再占 4 拍，入口可接着收下一帧
// 2026/10/03   fxdqe           1.5                     按状态机、标志、数据、CRC、出口分段
// -FHDR----------------------------------------------------------------------------

`include "GmacIf.vh"

module RsRxParser(/*autoarg*/
        //Inputs
        clkRx, rstN, pcs2RsSyncStatus, rxDelCrc, pcs2RsPktBusData,
        pcs2RsPktBusValid, pcs2RsPktBusSfp, pcs2RsPktBusEfp,
        pcs2RsPktBusErr, pcs2RsPktBusPreemptable,
        //Outputs
        rs2CdcPktBusData, rs2CdcPktBusValid, rs2CdcPktBusSfp,
        rs2CdcPktBusEfp, rs2CdcPktBusErr, rs2CdcPktBusPreemptable,
        rsRxState, rxCrcErrCnt, rxSfdCnt
);

//######################################################
//Interface
//######################################################

localparam [31:0] CRC_INIT = 32'hffff_ffff;

input                           clkRx;
input                           rstN;
input                           pcs2RsSyncStatus;
input                           rxDelCrc;

input  [`GMAC_BYTE_W-1:0]       pcs2RsPktBusData;
input                           pcs2RsPktBusValid;
input                           pcs2RsPktBusSfp;
input                           pcs2RsPktBusEfp;
input                           pcs2RsPktBusErr;
input                           pcs2RsPktBusPreemptable;

output [`GMAC_BYTE_W-1:0]       rs2CdcPktBusData;
output                          rs2CdcPktBusValid;
output                          rs2CdcPktBusSfp;
output                          rs2CdcPktBusEfp;
output                          rs2CdcPktBusErr;
output                          rs2CdcPktBusPreemptable;

output [1:0]                    rsRxState;
output reg [`GMAC_CNT_W32-1:0]  rxCrcErrCnt;
output reg [`GMAC_CNT_W32-1:0]  rxSfdCnt;

//######################################################
//Value
//######################################################

// 独热。bit0 是复位态 Hunt，bit1 是 Data
localparam [1:0] ST_HUNT = 2'b01;
localparam [1:0] ST_DATA = 2'b10;

localparam [7:0]  SFD_E   = 8'hD5;
localparam [10:0] MIN_LEN = 11'd60;

// 状态。Hunt 等 D5，Data 收本帧
reg  [1:0]                      state;
reg  [1:0]                      stateNxt;
wire                            inHunt;
wire                            inData;
wire                            canHunt;
wire                            sfdHit;
wire                            dataBeat;
wire                            syncDrop;

// 跟状态走的标志。SFD 装入，本帧结束清掉
reg                             rxDelCrcLock;
wire                            rxDelCrcLockInt;
reg                             sfpPend;
wire                            sfpPendInt;
reg                             sawErr;
wire                            sawErrInt;
reg  [2:0]                      dlyCnt;
wire [2:0]                      dlyCntInt;
wire                            dlyFull;

// 4 字节延迟线。dly0 是刚收进的字节，dly3 是最早的那个
reg  [7:0]                      dly0;
reg  [7:0]                      dly1;
reg  [7:0]                      dly2;
reg  [7:0]                      dly3;
wire [7:0]                      dly0Int;
wire [7:0]                      dly1Int;
wire [7:0]                      dly2Int;
wire [7:0]                      dly3Int;

// CRC 余数，以及已算进 CRC 的载荷字节数。FCS 四个字节留在延迟线里，不计入
reg  [31:0]                     crc;
wire [31:0]                     crcInt;
wire [31:0]                     crcStep;
reg  [10:0]                     byteCnt;
wire [10:0]                     byteCntInt;
wire [31:0]                     fcsRecv;
wire                            fcsBad;
wire                            lenBad;
wire                            efpErr;
wire                            crcErrHit;
wire [`GMAC_CNT_W32-1:0]        rxCrcErrCntInt;
wire [`GMAC_CNT_W32-1:0]        rxSfdCntInt;

// 出口寄存器。决定在本拍，寄存器下一拍才出现在口上
reg  [`GMAC_BYTE_W-1:0]         dataOut;
reg                             validOut;
reg                             sfpOut;
reg                             efpOut;
reg                             errOut;
reg  [`GMAC_BYTE_W-1:0]         dataNxt;
reg                             validNxt;
reg                             sfpNxt;
reg                             efpNxt;
reg                             errNxt;

//######################################################
//Logic
//######################################################

//======================================================
// 状态 @ clkRx
// inHunt / inData：独热译码，两位同时为 1 时都不是。
// canHunt：PCS 仍同步才收新字节。
// sfdHit：Hunt 里看到 D5。这一拍还不是载荷。
// dataBeat：Data 里收下的一拍。syncDrop：同步掉了，本帧作废。
// SFD 进入 Data。EFP 或同步丢失回 Hunt。
//======================================================

    assign inHunt   = state[0] & ~state[1];
    assign inData   = state[1] & ~state[0];
    assign canHunt  = pcs2RsSyncStatus;
    assign sfdHit   = inHunt & pcs2RsPktBusValid & canHunt & (pcs2RsPktBusData == SFD_E);
    assign dataBeat = inData & canHunt & pcs2RsPktBusValid;
    assign syncDrop = inData & ~canHunt;

    always@(posedge clkRx or negedge rstN) begin
        if (!rstN)
            state <= ST_HUNT;
        else
            state <= stateNxt;
    end

    always@(*) begin
        stateNxt = state;
        case (state)
            ST_HUNT: if (sfdHit & ~pcs2RsPktBusEfp) stateNxt = ST_DATA;
            ST_DATA: if (syncDrop | (dataBeat & pcs2RsPktBusEfp)) stateNxt = ST_HUNT;
            default: stateNxt = ST_HUNT;
        endcase
    end

    assign rsRxState = state;

//======================================================
// 状态相关信号
// rxDelCrcLock 只在 SFD 抄入口，本帧中途改配置不影响本帧。
// sfpPend 在 SFD 置 1。保留 FCS 时首字节送出即清；剥 FCS 时要等延迟线满。
// EFP 或同步丢失也清。同拍又置又清时清优先。
// sawErr 在 SFD 装入当拍 err，之后见过就保持。
// dlyCnt 计已装入延迟线的字节，到 4 停住。SFD 时清零。
//======================================================

    assign dlyFull         = dlyCnt >= 3'd4;
    assign rxDelCrcLockInt = sfdHit ? rxDelCrc : rxDelCrcLock;
    assign sfpPendInt      = (sfpPend | sfdHit) & ~(syncDrop | (sfdHit & pcs2RsPktBusEfp) | (dataBeat & (~rxDelCrcLock | dlyFull | pcs2RsPktBusEfp)));
    assign sawErrInt       = sfdHit ? pcs2RsPktBusErr : (dataBeat ? (sawErr | pcs2RsPktBusErr) : sawErr);
    assign dlyCntInt       = sfdHit ? 3'd0 : ((dataBeat & ~dlyFull) ? (dlyCnt + 3'd1) : dlyCnt);

    always@(posedge clkRx or negedge rstN) begin
        if (!rstN) begin
            rxDelCrcLock <= 1'b1;
            sfpPend      <= 1'b0;
            sawErr       <= 1'b0;
            dlyCnt       <= 3'd0;
        end
        else begin
            rxDelCrcLock <= rxDelCrcLockInt;
            sfpPend      <= sfpPendInt;
            sawErr       <= sawErrInt;
            dlyCnt       <= dlyCntInt;
        end
    end

//======================================================
// 数据通路
// 延迟线只在 Data 的有效拍移位。SFD 当拍不装入。
// 剥 FCS 时，满了之后送出的是 dly3，不是本拍新字节。
//======================================================

    assign dly0Int = dataBeat ? pcs2RsPktBusData : dly0;
    assign dly1Int = dataBeat ? dly0 : dly1;
    assign dly2Int = dataBeat ? dly1 : dly2;
    assign dly3Int = dataBeat ? dly2 : dly3;

    always@(posedge clkRx or negedge rstN) begin
        if (!rstN) begin
            dly0 <= 8'h00;
            dly1 <= 8'h00;
            dly2 <= 8'h00;
            dly3 <= 8'h00;
        end
        else begin
            dly0 <= dly0Int;
            dly1 <= dly1Int;
            dly2 <= dly2Int;
            dly3 <= dly3Int;
        end
    end

//======================================================
// CRC
// 挤出 dly3 的那拍才把它算进余数和帧长。FCS 四个字节留在线里。
// 好帧比对的是线上剩下的 4 字节和取反余数。高位是最后收到的那个。
// 线未满就 EFP，FCS 不完整，直接当错。
// SFD 命中加 rxSfdCnt。SFD 当拍 EFP、同步丢失、EFP 时校验失败，加 rxCrcErrCnt。
// 加到全 1 停住。
//======================================================

    GmacCrc32 uCrc32 (
        .crcIn  (crc),
        .dataIn (dly3),
        .crcOut (crcStep)
    );

    assign crcInt     = sfdHit ? CRC_INIT : ((dataBeat & dlyFull) ? crcStep : crc);
    assign byteCntInt = sfdHit ? 11'd0 : ((dataBeat & dlyFull) ? (byteCnt + 11'd1) : byteCnt);
    assign fcsRecv    = {pcs2RsPktBusData, dly0, dly1, dly2};
    assign fcsBad     = fcsRecv != ~crcStep;
    assign lenBad     = (byteCnt + 11'd1) < MIN_LEN;
    assign efpErr     = sawErr | pcs2RsPktBusErr | fcsBad | lenBad;

    assign crcErrHit = (sfdHit & pcs2RsPktBusEfp)
                     | syncDrop
                     | (dataBeat & pcs2RsPktBusEfp & (~dlyFull | efpErr));
    assign rxSfdCntInt    = (~sfdHit | (rxSfdCnt >= {`GMAC_CNT_W32{1'b1}}))
                          ? rxSfdCnt
                          : (rxSfdCnt + {{(`GMAC_CNT_W32-1){1'b0}}, 1'b1});
    assign rxCrcErrCntInt = (~crcErrHit | (rxCrcErrCnt >= {`GMAC_CNT_W32{1'b1}}))
                          ? rxCrcErrCnt
                          : (rxCrcErrCnt + {{(`GMAC_CNT_W32-1){1'b0}}, 1'b1});

    always@(posedge clkRx or negedge rstN) begin
        if (!rstN) begin
            crc     <= CRC_INIT;
            byteCnt <= 11'd0;
        end
        else begin
            crc     <= crcInt;
            byteCnt <= byteCntInt;
        end
    end

    always@(posedge clkRx or negedge rstN) begin
        if (!rstN) begin
            rxCrcErrCnt <= {`GMAC_CNT_W32{1'b0}};
            rxSfdCnt    <= {`GMAC_CNT_W32{1'b0}};
        end
        else begin
            rxCrcErrCnt <= rxCrcErrCntInt;
            rxSfdCnt    <= rxSfdCntInt;
        end
    end

//======================================================
// 出口
// 默认 valid / sfp / efp / err 为 0，data 保持。
// 剥 FCS：线满之后送出 dly3。EFP 且线已满时，这一拍是最后一个载荷字节。
// 线还没满就 EFP：不打拍，只记错。
// 保留 FCS：每个有效字节当拍送出，含 FCS。EFP 打在收到的最后一字节。
// 同步丢失：已经送出过则补一个带 efp+err 的尾；还没送出过则不打拍。
//======================================================

    always@(*) begin
        dataNxt  = dataOut;
        validNxt = 1'b0;
        sfpNxt   = 1'b0;
        efpNxt   = 1'b0;
        errNxt   = 1'b0;
        if (syncDrop & ~rxDelCrcLock & ~sfpPend) begin
            dataNxt  = dataOut;
            validNxt = 1'b1;
            efpNxt   = 1'b1;
            errNxt   = 1'b1;
        end
        else if (syncDrop & rxDelCrcLock & (dlyFull | ~sfpPend)) begin
            dataNxt  = dly3;
            validNxt = 1'b1;
            sfpNxt   = sfpPend & dlyFull;
            efpNxt   = 1'b1;
            errNxt   = 1'b1;
        end
        else if (dataBeat & ~rxDelCrcLock) begin
            dataNxt  = pcs2RsPktBusData;
            validNxt = 1'b1;
            sfpNxt   = sfpPend;
            efpNxt   = pcs2RsPktBusEfp;
            errNxt   = pcs2RsPktBusEfp & (~dlyFull | efpErr);
        end
        else if (dataBeat & dlyFull) begin
            dataNxt  = dly3;
            validNxt = 1'b1;
            sfpNxt   = sfpPend;
            efpNxt   = pcs2RsPktBusEfp;
            errNxt   = pcs2RsPktBusEfp & efpErr;
        end
    end

    always@(posedge clkRx or negedge rstN) begin
        if (!rstN) begin
            dataOut  <= 8'h00;
            validOut <= 1'b0;
            sfpOut   <= 1'b0;
            efpOut   <= 1'b0;
            errOut   <= 1'b0;
        end
        else begin
            dataOut  <= dataNxt;
            validOut <= validNxt;
            sfpOut   <= sfpNxt;
            efpOut   <= efpNxt;
            errOut   <= errNxt;
        end
    end

    assign rs2CdcPktBusData        = dataOut;
    assign rs2CdcPktBusValid       = validOut;
    assign rs2CdcPktBusSfp         = sfpOut;
    assign rs2CdcPktBusEfp         = efpOut;
    assign rs2CdcPktBusErr         = errOut;
    assign rs2CdcPktBusPreemptable = 1'b0;

endmodule
