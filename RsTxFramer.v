// +FHDR----------------------------------------------------------------------------
// Device        : Xilinx
// Author        : fxdqe
// Email         : 1706260166@qq.com
// Created On    : 2026/09/16 21:05
// File Name     : RsTxFramer.v
// Description   : Tx 成帧：7×55、D5、载荷、PAD、FCS、IFG。拉断 / err / 超长走不取反的 FCS。
//                 入向 Stall=1 时 Valid=0。载荷留一拍缓存，前导期间先攒住首字节。
//                 帧长和 IFG 在帧外收下 SFP 时锁存，本帧中途改配置不影响本帧。
// ---------------------------------------------------------------------------------
// Modification History:
// Date         By              Version                 Change Description
// ---------------------------------------------------------------------------------
// 2026/09/16   fxdqe           1.0                     Original
// 2026/10/03   fxdqe           1.1                     CRC 改用例化 GmacCrc32
// -FHDR----------------------------------------------------------------------------

`include "GmacIf.vh"

module RsTxFramer(/*autoarg*/
        //Inputs
        clkTx, rstN, cdc2RsPktBusData, cdc2RsPktBusValid,
        cdc2RsPktBusSfp, cdc2RsPktBusEfp, cdc2RsPktBusErr,
        cdc2RsPktBusPreemptable, rs2PcsPktBusStall, ifgCntMax,
        lenCntMin, lenCntMax,
        //Outputs
        cdc2RsPktBusStall, rs2PcsPktBusData, rs2PcsPktBusValid,
        rs2PcsPktBusSfp, rs2PcsPktBusEfp, rs2PcsPktBusErr,
        rs2PcsPktBusPreemptable, txBusy, padCnt,
        txOversizeCnt, txUnderrunCnt, txSfdCnt
);

//######################################################
//Interface
//######################################################

localparam CRC_INIT = 32'hffff_ffff;

input                           clkTx;
input                           rstN;

input  [`GMAC_BYTE_W-1:0]       cdc2RsPktBusData;
input                           cdc2RsPktBusValid;
input                           cdc2RsPktBusSfp;
input                           cdc2RsPktBusEfp;
input                           cdc2RsPktBusErr;
input                           cdc2RsPktBusPreemptable;
output                          cdc2RsPktBusStall;

output reg [`GMAC_BYTE_W-1:0]   rs2PcsPktBusData;
output                          rs2PcsPktBusValid;
output                          rs2PcsPktBusSfp;
output                          rs2PcsPktBusEfp;
output                          rs2PcsPktBusErr;
output                          rs2PcsPktBusPreemptable;
input                           rs2PcsPktBusStall;

output                          txBusy;
output reg [10:0]               padCnt;
output reg [`GMAC_CNT_W16-1:0]  txOversizeCnt;
output reg [`GMAC_CNT_W16-1:0]  txUnderrunCnt;
output reg [`GMAC_CNT_W16-1:0]  txSfdCnt;

input  [3:0]                    ifgCntMax;
input  [10:0]                   lenCntMin;
input  [10:0]                   lenCntMax;

//######################################################
//Value
//######################################################

// 帧是否在进行。startPkt 只在 Valid 且 Sfp 的那一拍为 1，inPkt 保持到 IFG 结束
wire                            inPktInt;
reg                             inPkt;
wire                            endPkt;
wire                            startPkt;
wire                            frameOn;
wire                            takeLock;

// 前导打完后送载荷，直到 EFP 后的填充结束，或拉断且长度已够
reg                             transferData;
wire                            transferDataInt;
wire                            endTransferData;
wire                            endTransferDataNor;
wire                            endTransferDataPad;

// 前导移位。preamSeqJudge 初值 bit0，每发出一字节左环移，bit7 是 SFD 那一拍
reg  [63:0]                     preamSeqData;
reg  [7:0]                      preamSeqJudge;
reg                             addPream;
wire                            addPreamInt;

// 一拍缓存。前导期间不弹出，弹出的同一拍可以再收一字节
reg  [`GMAC_BYTE_W-1:0]         cdc2RsPktBusDataLock;
reg                             cdc2RsPktBusSfpLock;
reg                             cdc2RsPktBusEfpLock;
reg                             cdc2RsPktBusErrLock;
reg                             storeDataValid;
wire                            storeDataValidInt;
wire                            storeFree;
wire                            storeBusy;

// 帧长。pktLenCnt 在最后一个 FCS 字节被收下时清零
reg  [15:0]                     pktLenCnt;
wire [15:0]                     pktLenCntInt;
wire [15:0]                     lenNext;
wire                            startPad;
reg                             inPad;
wire                            inPadInt;
wire                            endPad;

// CRC 残留，以及正在送出的 FCS 字节号。4'h1/2/4/8 各对应一个字节，低字节先发
wire [31:0]                     newCrc;
reg  [31:0]                     oldCrc;
wire [31:0]                     crcSel;
wire [7:0]                      crcDataIn;
reg  [7:0]                      crcDataSel;
reg  [3:0]                      crcSelect;

// IFG。inTail 从最后一个 FCS 字节被收下的下一拍开始
reg                             inTail;
wire                            inTailInt;
wire [4:0]                      tailStallCntInt;
reg  [4:0]                      tailStallCnt;
wire                            endTailStall;

// 本帧要打错误 FCS：入向 err、超长，或缓存已空仍在送载荷（拉断）
wire                            lengTooLong;
wire                            pktErrInt;
reg                             pktErr;

// 反复出现的条件。单 bit 用 & | ~
wire                            pcsReady;
wire                            preamFire;
wire                            preamLast;
wire                            payloadLast;
wire                            inPream;
wire                            inErr;
wire                            lenFire;
wire [15:0]                     lenMinExt;
wire [15:0]                     lenMaxExt;
wire                            inFcs;
wire                            fcsLast;
wire                            padBeat;
wire                            underrun;
wire                            underrunShort;
wire                            underrunLong;
wire                            efpBeat;
wire                            crcUpdate;
wire                            ifgCntHit;
wire                            ifgSkip;
wire                            selFcs;
wire                            selPad;
wire                            sfpFromBus;
wire                            sfpFromLock;

// 帧外收下 SFP 时锁存。本帧发送途中改配置不影响本帧
reg  [3:0]                      ifgCntLock;
wire [3:0]                      ifgCntLockInt;
reg  [10:0]                     lenCntMinLock;
wire [10:0]                     lenCntMinLockInt;
reg  [10:0]                     lenCntMaxLock;
wire [10:0]                     lenCntMaxLockInt;

// 出口字节选择，一位一个来源：{FCS, PAD, 前导}。都不是则送缓存里的载荷
wire [2:0]                      finalDataSelect;

// 发生过填充的报文个数，以及超长 / 拉断 / SFD 次数
wire [10:0]                     padCntInt;
wire [`GMAC_CNT_W32-1:0]        txOversizeCntInt;
wire [`GMAC_CNT_W32-1:0]        txUnderrunCntInt;
wire [`GMAC_CNT_W32-1:0]        txSfdCntInt;

//######################################################
//Logic
//######################################################

//======================================================
// 常用条件
// pcsReady：下游这拍收得下。
// underrun：正在送载荷，缓存已经空。短于最短长度要补 00，否则直接收尾。
// efpBeat：缓存里的 EFP 字节这拍送出。它或偏短拉断都表示载荷到头。
// fcsLast：4 个 FCS 字节的最后一拍，且下游收下了。EFP / ERR 打在这里。
// lenFire / lenNext：这拍有一个字节要算进帧长，lenNext 是算上之后的长度。
//======================================================

    assign pcsReady      = ~rs2PcsPktBusStall;
    assign lenMinExt     = {5'd0, lenCntMinLock};
    assign lenMaxExt     = {5'd0, lenCntMaxLock};
    assign inFcs         = |crcSelect;
    assign fcsLast       = crcSelect[3] & pcsReady;
    assign padBeat       = inPad & pcsReady;
    assign underrun      = transferData & pcsReady & ~inPad & ~storeDataValid;
    assign underrunShort = underrun & (pktLenCnt < lenMinExt);
    assign underrunLong  = underrun & (pktLenCnt >= lenMinExt);
    assign efpBeat       = storeDataValid & cdc2RsPktBusEfpLock & storeFree;
    assign payloadLast   = efpBeat | underrunShort;
    assign inPream       = addPream | startPkt;
    assign preamFire     = inPream & pcsReady;
    assign preamLast     = preamSeqJudge[7] & pcsReady;
    assign inErr         = cdc2RsPktBusValid & cdc2RsPktBusErr;
    assign lenFire       = cdc2RsPktBusValid | padBeat | underrunShort;
    assign lenNext       = pktLenCnt + {15'd0, lenFire};
    assign crcUpdate     = (cdc2RsPktBusValid & (transferData | startPkt)) | padBeat | underrunShort;
    assign frameOn       = startPkt | inPkt;
    assign takeLock      = startPkt & ~inPkt;
    assign storeBusy     = storeDataValid & ~storeFree & transferData;
    assign ifgCntHit     = (tailStallCnt + 5'd1) >= {1'd0, ifgCntLock};
    assign ifgSkip       = fcsLast & (tailStallCnt >= ifgCntLock);
    assign selFcs        = inFcs | underrunLong;
    assign selPad        = inPad | underrunShort;
    assign sfpFromBus    = cdc2RsPktBusSfp & pcsReady;
    assign sfpFromLock   = cdc2RsPktBusSfpLock & addPream;

//======================================================
// 帧起止，以及本帧用的长度 / IFG
// 入向 Valid 且 Sfp 打开一帧。inPkt 保持到 IFG 结束。
// 只在 inPkt 仍为 0 时把配置抄进来，抄的是这一拍输入口上的值。
//======================================================

    assign inPktInt         = (inPkt | startPkt) & ~endPkt;
    assign startPkt         = cdc2RsPktBusValid & cdc2RsPktBusSfp;
    assign endPkt           = endTailStall;
    assign ifgCntLockInt    = takeLock ? ifgCntMax : ifgCntLock;
    assign lenCntMinLockInt = takeLock ? lenCntMin : lenCntMinLock;
    assign lenCntMaxLockInt = takeLock ? lenCntMax : lenCntMaxLock;

    always@(posedge clkTx or negedge rstN) begin
        if (!rstN) begin
            ifgCntLock    <= 4'd0;
            lenCntMinLock <= 11'd0;
            lenCntMaxLock <= 11'd0;
            inPkt         <= 1'd0;
        end
        else begin
            ifgCntLock    <= ifgCntLockInt;
            lenCntMinLock <= lenCntMinLockInt;
            lenCntMaxLock <= lenCntMaxLockInt;
            inPkt         <= inPktInt;
        end
    end

//======================================================
// 一拍缓存
// storeFree 表示这拍把缓存里的字节送出去。前导期间 addPream 挡住，首字节留到前导结束。
// 送出的同一拍若上游还有 Valid，缓存换成新字节；没有则变空。
//======================================================

    assign storeFree         = storeDataValid & pcsReady & ~addPream;
    assign storeDataValidInt = (storeDataValid | cdc2RsPktBusValid) & ~(storeFree & ~cdc2RsPktBusValid);

    always@(posedge clkTx or negedge rstN) begin
        if (!rstN)
            storeDataValid <= 1'd0;
        else
            storeDataValid <= storeDataValidInt;
    end

    always@(posedge clkTx) begin
        if (cdc2RsPktBusValid) begin
            cdc2RsPktBusDataLock <= cdc2RsPktBusData;
            cdc2RsPktBusSfpLock  <= cdc2RsPktBusSfp;
            cdc2RsPktBusEfpLock  <= cdc2RsPktBusEfp;
            cdc2RsPktBusErrLock  <= cdc2RsPktBusErr;
        end
    end

//======================================================
// 前导与 SFD
// 复位值是 7 个 55 接一个 D5，每拍发出当前最高字节再左环移。
// preamSeqJudge 走到 bit7 且下游收下，这一拍就是 D5，下一拍进入载荷。
// 下游 Stall 时 preamFire 为 0，字节停在原位。
//======================================================

    assign addPreamInt = (addPream | startPkt) & ~preamLast;

    always@(posedge clkTx or negedge rstN) begin
        if (!rstN)
            addPream <= 1'd0;
        else
            addPream <= addPreamInt;
    end

    always@(posedge clkTx or negedge rstN) begin
        if (!rstN) begin
            preamSeqData  <= {7{8'h55}, 8'hd5};
            preamSeqJudge <= 8'h1;
        end
        else if (preamFire) begin
            preamSeqData  <= {preamSeqData[55:0], preamSeqData[63:56]};
            preamSeqJudge <= {preamSeqJudge[6:0], preamSeqJudge[7]};
        end
    end

//======================================================
// 载荷阶段
// SFD 送出后进入。正常 EFP 且还短于最短长度时先去填充，不在这里结束。
// 拉断且长度已够则立刻结束，这一拍出口改送 FCS。
//======================================================

    assign transferDataInt    = (transferData | preamLast) & ~endTransferData;
    assign endTransferDataNor = payloadLast & ~startPad;
    assign endTransferDataPad = endPad;
    assign endTransferData    = endTransferDataPad | endTransferDataNor | underrunLong;

    always@(posedge clkTx or negedge rstN) begin
        if (!rstN)
            transferData <= 1'd0;
        else
            transferData <= transferDataInt;
    end

//======================================================
// 帧长与填充
// 收下的载荷、填充字节、偏短拉断补上的 00，都让 pktLenCnt 加 1。
// 载荷到头时 lenNext 仍短于最短长度则进入填充，补到等于最短长度。
// 最后一个 FCS 字节被收下时帧长清零，供下一帧重新计。
//======================================================

    assign pktLenCntInt = fcsLast ? 16'd0 : lenNext;
    assign startPad     = payloadLast & (lenNext < lenMinExt);
    assign endPad       = (pktLenCnt + 16'd1 >= lenMinExt) & pcsReady & inPad;
    assign inPadInt     = (inPad | startPad) & ~endPad;

    always@(posedge clkTx or negedge rstN) begin
        if (!rstN) begin
            pktLenCnt <= 16'd0;
            inPad     <= 1'd0;
        end
        else begin
            pktLenCnt <= pktLenCntInt;
            inPad     <= inPadInt;
        end
    end

//======================================================
// CRC 与 FCS
// 以太网 CRC：反射多项式，初值全 1，好帧发送时取反，低字节先发。
// 载荷在收下那拍算入，填充和偏短拉断的 00 在送出那拍算入。前导不参与。
// 8 比特更新在 GmacCrc32 里一次算完，这里只保留余数寄存器。
// crcSelect 正常从 4'h1 左移，依次送出 4 个字节。
// 拉断且长度已够时，当拍已经把第 1 字节从旁路送出，移位器改从 4'h2 接上。
// 错误帧不取反。帧结束后把 CRC 恢复成初值。
//======================================================

    assign crcDataIn = cdc2RsPktBusValid ? cdc2RsPktBusData : 8'h0;

    GmacCrc32 uCrc32 (
        .crcIn  (oldCrc),
        .dataIn (crcDataIn),
        .crcOut (newCrc)
    );

    assign crcSel    = (pktErr | underrunLong) ? oldCrc : ~oldCrc;

    always@(*) begin
        case (crcSelect)
            4'h1:    crcDataSel = crcSel[7:0];
            4'h2:    crcDataSel = crcSel[15:8];
            4'h4:    crcDataSel = crcSel[23:16];
            4'h8:    crcDataSel = crcSel[31:24];
            default: crcDataSel = crcSel[7:0];
        endcase
    end

    always@(posedge clkTx or negedge rstN) begin
        if (!rstN) begin
            oldCrc    <= CRC_INIT;
            crcSelect <= 4'd0;
        end
        else begin
            if (endTailStall)
                oldCrc <= CRC_INIT;
            else if (crcUpdate)
                oldCrc <= newCrc;

            if (underrunLong)
                crcSelect <= 4'h2;
            else if (endTransferData)
                crcSelect <= 4'h1;
            else if (pcsReady & inFcs)
                crcSelect <= {crcSelect[2:0], 1'd0};
        end
    end

//======================================================
// IFG
// 最后一个 FCS 字节收下后进入 inTail，空拍数等于本帧锁存的 ifgCntLock。
// 锁存值是 0 时，fcsLast 当拍 ifgSkip 成立，inTail 不进入，后面没有空拍。
//======================================================

    assign inTailInt       = (fcsLast | inTail) & ~endTailStall;
    assign tailStallCntInt = inTail ? (tailStallCnt + 5'd1) : 5'd0;
    assign endTailStall    = (ifgCntHit & inTail) | ifgSkip;

    always@(posedge clkTx or negedge rstN) begin
        if (!rstN) begin
            inTail       <= 1'b0;
            tailStallCnt <= 5'd0;
        end
        else begin
            inTail       <= inTailInt;
            tailStallCnt <= tailStallCntInt;
        end
    end

//======================================================
// 错误 FCS
// 拉断在缓存变空的那拍置位，超长在载荷或填充结束且帧长超过上限时置位。
// 置位后保持到本帧结束。FCS 四个字节都看这个标志。
//======================================================

    assign lengTooLong = (pktLenCnt > lenMaxExt) & endTransferData;
    assign pktErrInt   = (pktErr | inErr | lengTooLong | underrun) & ~endTailStall;

    always@(posedge clkTx or negedge rstN) begin
        if (!rstN)
            pktErr <= 1'd0;
        else
            pktErr <= pktErrInt;
    end

//======================================================
// 出口
// 前导、填充、FCS 期间反压入向。缓存里还有字节且这拍送不出去时也反压。
// 字节来源按 selFcs / selPad / inPream 独热选择；叠在一起时落到缓存数据。
// SFP 只在 preamSeqJudge[0] 为 1 的那一拍，也就是第一个 55。
// 这一拍已经处于前导时用锁存的 Sfp，否则用当前总线上的 Sfp。
// EFP 和 ERR 只在最后一个 FCS 字节，且这一拍下游确实收下。
//======================================================

    assign cdc2RsPktBusStall       = storeBusy | inTail | inFcs | inPad | addPream | startPad | endTransferData;
    assign finalDataSelect         = {selFcs, selPad, inPream};
    assign rs2PcsPktBusValid       = frameOn & pcsReady & (~inTail | inFcs);
    assign rs2PcsPktBusSfp         = preamSeqJudge[0] & (sfpFromBus | sfpFromLock);
    assign rs2PcsPktBusEfp         = fcsLast;
    assign rs2PcsPktBusErr         = pktErr & fcsLast;
    assign rs2PcsPktBusPreemptable = 1'd0;
    assign txBusy                  = frameOn;

    always@(*) begin
        case (finalDataSelect)
            3'h1:    rs2PcsPktBusData = preamSeqData[63:56];
            3'h2:    rs2PcsPktBusData = 8'h0;
            3'h4:    rs2PcsPktBusData = crcDataSel;
            default: rs2PcsPktBusData = cdc2RsPktBusDataLock;
        endcase
    end

//======================================================
// 计数
// padCnt 计发生过填充的报文个数，一帧最多加 1。
// 超长、拉断各在收尾条件成立的那拍加 1。SFD 在第一个 55 被收下时加 1。
//======================================================

    assign padCntInt        = (startPad | underrunShort) ? (padCnt + 11'd1) : padCnt;
    assign txOversizeCntInt = lengTooLong ? (txOversizeCnt + 16'd1) : txOversizeCnt;
    assign txSfdCntInt      = (rs2PcsPktBusValid & rs2PcsPktBusSfp) ? (txSfdCnt + 16'd1) : txSfdCnt;
    assign txUnderrunCntInt = underrun ? (txUnderrunCnt + 16'd1) : txUnderrunCnt;

    always@(posedge clkTx or negedge rstN) begin
        if (!rstN) begin
            padCnt        <= 11'd0;
            txOversizeCnt <= 16'd0;
            txSfdCnt      <= 16'd0;
            txUnderrunCnt <= 16'd0;
        end
        else begin
            padCnt        <= padCntInt;
            txOversizeCnt <= txOversizeCntInt;
            txSfdCnt      <= txSfdCntInt;
            txUnderrunCnt <= txUnderrunCntInt;
        end
    end

endmodule
