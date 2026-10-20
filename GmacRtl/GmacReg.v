// +FHDR----------------------------------------------------------------------------
// Device        : Xilinx
// Author        : Auto Generated
// Email         : 
// Created On    : 2026/10/16 20:53
// File Name     : GmacReg.v
// Description   : 寄存器总线译码。读和写各自建树，第一拍按地址空间最高位比较组命中，组内用 [5:2] 选择。Ack 表示访问完成，Err 表示完成但有错误，二者同一拍有效。
// 
// ---------------------------------------------------------------------------------
// Modification History:
// Date         By              Version                 Change Description
// ---------------------------------------------------------------------------------
// 2026/10/16 20:53   Auto Generated   1.0                     Original
// -FHDR----------------------------------------------------------------------------
module GmacReg(/*autoarg*/
        //Inputs
        clkMgmt, rstN, regBusWr, regBusWrAddr, regBusWrData, regBusRd, regBusRdAddr, date, user, version, codeVCnt, irqRaw, 
        lossOfSyncCnt, rxCrcErrCnt, rxOverflowCnt, rxSfdCnt, txOverRunCnt, txUnderRunCnt, txVbErrCnt, txOversizeCnt, txSfdCnt, 
        txUnderrunCnt, padCnt, rxFifoLevel, rxFifoPeakCnt, txFifoLevel, txFifoPeakCnt, pcsRxSyncState, pcsTxState, rsRxState, 
        fifoAlFull, pcsRxEven, pcsRxRd, pcsRxSync, pcsTxEven, pcsTxRd, txBusy, txInSfpCnt, txInEfpCnt, txInVbCnt, txInValidCnt, 
        txOutSfpCnt, txOutEfpCnt, txOutVbCnt, txOutValidCnt, rxInSfpCnt, rxInEfpCnt, rxInVbCnt, rxInValidCnt, rxOutSfpCnt, 
        rxOutEfpCnt, rxOutVbCnt, rxOutValidCnt, txInErrCnt, txOutErrCnt, rxInErrCnt, rxOutErrCnt,
        //Outputs
        regBusWrAck, regBusWrErr, regBusRdAck, regBusRdErr, regBusRdData, irqMask, fifoTxFifoThrd, xmit, loopback, rxEn, 
        softRst, txEn
);

//######################################################
// Interface
// 寄存器总线为字节地址。32bit 访问时 [7:0] 是该地址上的字节，[31:24] 是更高地址上的字节。多比特字段的低位对应 bit_range 的低位。
//######################################################

input                  clkMgmt;
input                  rstN;

input                  regBusWr;
input  [31:0]          regBusWrAddr;
input  [31:0]          regBusWrData;
output reg             regBusWrAck;
output reg             regBusWrErr;

input                  regBusRd;
input  [31:0]          regBusRdAddr;
output reg             regBusRdAck;
output reg             regBusRdErr;
output reg [31:0]      regBusRdData;

input  [31:0]         date;
input  [15:0]         user;
input  [15:0]         version;
output reg [31:0]     irqMask;
output reg [7:0]      fifoTxFifoThrd;
output reg [1:0]      xmit;
output reg            loopback;
output reg            rxEn;
output reg            softRst;
output reg            txEn;
input  [31:0]         codeVCnt;
input  [31:0]         irqRaw;
input  [31:0]         lossOfSyncCnt;
input  [31:0]         rxCrcErrCnt;
input  [31:0]         rxOverflowCnt;
input  [31:0]         rxSfdCnt;
input  [31:0]         txOverRunCnt;
input  [31:0]         txUnderRunCnt;
input  [31:0]         txVbErrCnt;
input  [15:0]         txOversizeCnt;
input  [15:0]         txSfdCnt;
input  [15:0]         txUnderrunCnt;
input  [10:0]         padCnt;
input  [7:0]          rxFifoLevel;
input  [7:0]          rxFifoPeakCnt;
input  [7:0]          txFifoLevel;
input  [7:0]          txFifoPeakCnt;
input  [2:0]          pcsRxSyncState;
input  [1:0]          pcsTxState;
input  [1:0]          rsRxState;
input                 fifoAlFull;
input                 pcsRxEven;
input                 pcsRxRd;
input                 pcsRxSync;
input                 pcsTxEven;
input                 pcsTxRd;
input                 txBusy;
input  [15:0]         txInSfpCnt;
input  [15:0]         txInEfpCnt;
input  [31:0]         txInVbCnt;
input  [31:0]         txInValidCnt;
input  [15:0]         txOutSfpCnt;
input  [15:0]         txOutEfpCnt;
input  [31:0]         txOutVbCnt;
input  [31:0]         txOutValidCnt;
input  [15:0]         rxInSfpCnt;
input  [15:0]         rxInEfpCnt;
input  [31:0]         rxInVbCnt;
input  [31:0]         rxInValidCnt;
input  [15:0]         rxOutSfpCnt;
input  [15:0]         rxOutEfpCnt;
input  [31:0]         rxOutVbCnt;
input  [31:0]         rxOutValidCnt;
input  [7:0]          txInErrCnt;
input  [7:0]          txOutErrCnt;
input  [7:0]          rxInErrCnt;
input  [7:0]          rxOutErrCnt;

//######################################################
// Value
// 读树和写树分开。第一拍只寄存各组命中，比较位截到本文件地址空间的最高位 [8:6]。组内再用地址 [5:2] 选出寄存器，读树超过 16 组时再按 16 个一组打拍。
//######################################################

localparam [31:0] rdAddrErrData = 32'heef55fee;

reg [31:0] rdAddrF1;
reg        rdReqF1;
reg [31:0] wrAddrF1;
reg        wrReqF1;
reg [31:0] wrDataF1;

reg        rdHitL0_0;
reg [31:0] rdDataL0_0;
reg        rdErrL0_0;
reg        rdHitL0_1;
reg [31:0] rdDataL0_1;
reg        rdErrL0_1;
reg        rdHitL0_2;
reg [31:0] rdDataL0_2;
reg        rdErrL0_2;
reg        wrHitL0_0;
reg        wrAt_00000100;
reg        wrAt_00000104;
wire       wrLegalNxt;
wire       wrAckInt;
wire       wrErrInt;
reg        rdMissF;
wire       rdMissInt;
wire       rdRspHot_0;
wire       rdRspHot_1;
reg [1:0] rdRspSel;
reg [31:0] rdDataL1_0;
reg [31:0] rdDataL1_0Nxt;
reg        rdHitL1_0;
reg        rdHitL1_0Nxt;
reg        rdErrL1_0;
reg        rdErrL1_0Nxt;
reg [1:0] rdSelL1_0;

wire [31:0] irqMaskInt;
wire [7:0] fifoTxFifoThrdInt;
wire [1:0] xmitInt;
wire loopbackInt;
wire rxEnInt;
wire softRstInt;
wire txEnInt;

//######################################################
// Logic
// 读命中和写命中各自打拍，比较 [8:6]，存储器也在这一拍做基地址比较。读组内的 [5:2] 选出数据后，再按最多 16 个命中收成下一级。写不走读的数据树，只在自己的组里产生写使能。
//######################################################

//======================================================
// 读命中，截到地址空间最高位
// 本拍采样 regBusRd 与 regBusRdAddr。每个可读组比较 [8:6] 是否等于该组号，结果打入 rdHitL0。存储器用去掉条目号和偏移后的基地址做同样的比较。
//======================================================

    always @(posedge clkMgmt or negedge rstN) begin
        if (!rstN) begin
            rdAddrF1 <= 32'h0;
            rdReqF1 <= 1'b0;
            rdHitL0_0 <= 1'b0;
            rdHitL0_1 <= 1'b0;
            rdHitL0_2 <= 1'b0;
        end
        else begin
            rdAddrF1 <= regBusRdAddr;
            rdReqF1 <= regBusRd;
            rdHitL0_0 <= (regBusRd && (regBusRdAddr[8:6] == 3'h0));
            rdHitL0_1 <= (regBusRd && (regBusRdAddr[8:6] == 3'h4));
            rdHitL0_2 <= (regBusRd && (regBusRdAddr[8:6] == 3'h5));
        end
    end

//======================================================
// 读组 0，地址 [5:2]
// 这一组的高位已经在 rdHitL0_0 里。这里只按 [5:2] 选出组内寄存器的数据；命中但组内没有这个地址时，错误跟这次命中一起置位。
//======================================================

    always @(*) begin
        rdDataL0_0 = rdAddrErrData;
        rdErrL0_0 = 1'b0;
        case (rdAddrF1[5:2])
            4'd0: begin
                rdDataL0_0 = date;
                rdErrL0_0 = 1'b0;
            end
            4'd1: begin
                rdDataL0_0 = {16'd0, user};
                rdErrL0_0 = 1'b0;
            end
            4'd2: begin
                rdDataL0_0 = {16'd0, version};
                rdErrL0_0 = 1'b0;
            end
            default: begin
                rdErrL0_0 = rdHitL0_0;
            end
        endcase
    end

//======================================================
// 读组 1，地址 [5:2]
// 这一组的高位已经在 rdHitL0_1 里。这里只按 [5:2] 选出组内寄存器的数据；命中但组内没有这个地址时，错误跟这次命中一起置位。
//======================================================

    always @(*) begin
        rdDataL0_1 = rdAddrErrData;
        rdErrL0_1 = 1'b0;
        case (rdAddrF1[5:2])
            4'd0: begin
                rdDataL0_1 = irqMask;
                rdErrL0_1 = 1'b0;
            end
            4'd1: begin
                rdDataL0_1 = {18'd0, txEn, softRst, rxEn, loopback, xmit, fifoTxFifoThrd};
                rdErrL0_1 = 1'b0;
            end
            4'd4: begin
                rdDataL0_1 = codeVCnt;
                rdErrL0_1 = 1'b0;
            end
            4'd5: begin
                rdDataL0_1 = irqRaw;
                rdErrL0_1 = 1'b0;
            end
            4'd6: begin
                rdDataL0_1 = lossOfSyncCnt;
                rdErrL0_1 = 1'b0;
            end
            4'd7: begin
                rdDataL0_1 = rxCrcErrCnt;
                rdErrL0_1 = 1'b0;
            end
            4'd8: begin
                rdDataL0_1 = rxOverflowCnt;
                rdErrL0_1 = 1'b0;
            end
            4'd9: begin
                rdDataL0_1 = rxSfdCnt;
                rdErrL0_1 = 1'b0;
            end
            4'd10: begin
                rdDataL0_1 = txOverRunCnt;
                rdErrL0_1 = 1'b0;
            end
            4'd11: begin
                rdDataL0_1 = txUnderRunCnt;
                rdErrL0_1 = 1'b0;
            end
            4'd12: begin
                rdDataL0_1 = txVbErrCnt;
                rdErrL0_1 = 1'b0;
            end
            4'd13: begin
                rdDataL0_1 = {txSfdCnt, txOversizeCnt};
                rdErrL0_1 = 1'b0;
            end
            4'd14: begin
                rdDataL0_1 = {5'd0, padCnt, txUnderrunCnt};
                rdErrL0_1 = 1'b0;
            end
            4'd15: begin
                rdDataL0_1 = {txFifoPeakCnt, txFifoLevel, rxFifoPeakCnt, rxFifoLevel};
                rdErrL0_1 = 1'b0;
            end
            default: begin
                rdErrL0_1 = rdHitL0_1;
            end
        endcase
    end

//======================================================
// 读组 2，地址 [5:2]
// 这一组的高位已经在 rdHitL0_2 里。这里只按 [5:2] 选出组内寄存器的数据；命中但组内没有这个地址时，错误跟这次命中一起置位。
//======================================================

    always @(*) begin
        rdDataL0_2 = rdAddrErrData;
        rdErrL0_2 = 1'b0;
        case (rdAddrF1[5:2])
            4'd0: begin
                rdDataL0_2 = {7'd0, txBusy, pcsTxRd, pcsTxEven, pcsRxSync, pcsRxRd, pcsRxEven, fifoAlFull, rsRxState, 6'd0, pcsTxState, 5'd0, pcsRxSyncState};
                rdErrL0_2 = 1'b0;
            end
            4'd1: begin
                rdDataL0_2 = {txInEfpCnt, txInSfpCnt};
                rdErrL0_2 = 1'b0;
            end
            4'd2: begin
                rdDataL0_2 = txInVbCnt;
                rdErrL0_2 = 1'b0;
            end
            4'd3: begin
                rdDataL0_2 = txInValidCnt;
                rdErrL0_2 = 1'b0;
            end
            4'd4: begin
                rdDataL0_2 = {txOutEfpCnt, txOutSfpCnt};
                rdErrL0_2 = 1'b0;
            end
            4'd5: begin
                rdDataL0_2 = txOutVbCnt;
                rdErrL0_2 = 1'b0;
            end
            4'd6: begin
                rdDataL0_2 = txOutValidCnt;
                rdErrL0_2 = 1'b0;
            end
            4'd7: begin
                rdDataL0_2 = {rxInEfpCnt, rxInSfpCnt};
                rdErrL0_2 = 1'b0;
            end
            4'd8: begin
                rdDataL0_2 = rxInVbCnt;
                rdErrL0_2 = 1'b0;
            end
            4'd9: begin
                rdDataL0_2 = rxInValidCnt;
                rdErrL0_2 = 1'b0;
            end
            4'd10: begin
                rdDataL0_2 = {rxOutEfpCnt, rxOutSfpCnt};
                rdErrL0_2 = 1'b0;
            end
            4'd11: begin
                rdDataL0_2 = rxOutVbCnt;
                rdErrL0_2 = 1'b0;
            end
            4'd12: begin
                rdDataL0_2 = rxOutValidCnt;
                rdErrL0_2 = 1'b0;
            end
            4'd13: begin
                rdDataL0_2 = {rxOutErrCnt, rxInErrCnt, txOutErrCnt, txInErrCnt};
                rdErrL0_2 = 1'b0;
            end
            default: begin
                rdErrL0_2 = rdHitL0_2;
            end
        endcase
    end

//======================================================
// 读第 0 组结果汇合
// 组命中先拼成独热码，单独译成 rdSelL1_0。下一个 always 再用这个选择码取出已经准备好的 32bit 数据，然后打拍，和总线读应答对齐。
//======================================================

    always @(*) begin
        rdSelL1_0 = 2'd0;
        case ({rdHitL0_2, rdHitL0_1, rdHitL0_0})
            3'h1: rdSelL1_0 = 2'd0;
            3'h2: rdSelL1_0 = 2'd1;
            3'h4: rdSelL1_0 = 2'd2;
            default: rdSelL1_0 = 2'd0;
        endcase
    end

    always @(*) begin
        rdDataL1_0Nxt = rdAddrErrData;
        rdHitL1_0Nxt = 1'b0;
        rdErrL1_0Nxt = 1'b0;
        case (rdSelL1_0)
            2'd0: begin
                rdDataL1_0Nxt = rdDataL0_0;
                rdErrL1_0Nxt = rdErrL0_0;
            end
            2'd1: begin
                rdDataL1_0Nxt = rdDataL0_1;
                rdErrL1_0Nxt = rdErrL0_1;
            end
            2'd2: begin
                rdDataL1_0Nxt = rdDataL0_2;
                rdErrL1_0Nxt = rdErrL0_2;
            end
            default: begin
                rdDataL1_0Nxt = rdAddrErrData;
                rdErrL1_0Nxt = 1'b0;
            end
        endcase
        rdHitL1_0Nxt = (rdHitL0_0 || rdHitL0_1 || rdHitL0_2) ? 1'b1 : 1'b0;
    end

    always @(posedge clkMgmt or negedge rstN) begin
        if (!rstN) begin
            rdDataL1_0 <= 32'h0;
            rdHitL1_0 <= 1'b0;
            rdErrL1_0 <= 1'b0;
        end
        else begin
            rdDataL1_0 <= rdDataL1_0Nxt;
            rdHitL1_0 <= rdHitL1_0Nxt;
            rdErrL1_0 <= rdErrL1_0Nxt;
        end
    end

    assign rdMissInt = (rdReqF1 && !rdHitL0_0 && !rdHitL0_1 && !rdHitL0_2) ? 1'b1 : 1'b0;

    always @(posedge clkMgmt or negedge rstN) begin
        if (!rstN) begin
            rdMissF <= 1'b0;
        end
        else begin
            rdMissF <= rdMissInt;
        end
    end

//======================================================
// 写命中，与读使用不同的组
// 只为可写寄存器建组，组号可以和读树不同。比较位同样截到 [8:6]。写数据、写地址和写请求在这一拍采样，供下一拍写入。
//======================================================

    always @(posedge clkMgmt or negedge rstN) begin
        if (!rstN) begin
            wrAddrF1 <= 32'h0;
            wrReqF1 <= 1'b0;
            wrDataF1 <= 32'h0;
            wrHitL0_0 <= 1'b0;
        end
        else begin
            wrAddrF1 <= regBusWrAddr;
            wrReqF1 <= regBusWr;
            wrDataF1 <= regBusWrData;
            wrHitL0_0 <= (regBusWr && (regBusWrAddr[8:6] == 3'h4));
        end
    end

//======================================================
// 写组内选择
// 每个 wrHitL0 单独一个 always，只处理这一组地址 [5:2] 上的写使能。wrLegalNxt 是各寄存器写使能和各写表合法命中的或，表示这次写落到了某个可写范围。
//======================================================

    always @(*) begin
        wrAt_00000100 = 1'b0;
        wrAt_00000104 = 1'b0;
        case (wrAddrF1[5:2])
            4'd0: wrAt_00000100 = wrHitL0_0;
            4'd1: wrAt_00000104 = wrHitL0_0;
            default: begin
                wrAt_00000100 = 1'b0;
                wrAt_00000104 = 1'b0;
            end
        endcase
    end

    assign wrLegalNxt = wrAt_00000100
        || wrAt_00000104;

    assign wrAckInt = (wrReqF1) ? 1'b1 : 1'b0;
    assign wrErrInt = (wrReqF1 && !wrLegalNxt) ? 1'b1 : 1'b0;

    always @(posedge clkMgmt or negedge rstN) begin
        if (!rstN) begin
            regBusWrAck <= 1'b0;
            regBusWrErr <= 1'b0;
        end
        else begin
            regBusWrAck <= wrAckInt;
            regBusWrErr <= wrErrInt;
        end
    end

//======================================================
// 寄存器存储与触发，与写应答同一拍更新
// Int 是对应寄存器的下一拍，只用 assign 产生。写数据和写触发共用一个时序块，复位时分别回到默认值和 0。读触发与读应答同一拍置位。
//======================================================

    assign irqMaskInt = wrAt_00000100 ? wrDataF1 : irqMask;
    always @(posedge clkMgmt or negedge rstN) begin
        if (!rstN) begin
            irqMask <= 32'h0;
        end
        else begin
            irqMask <= irqMaskInt;
        end
    end

    assign fifoTxFifoThrdInt = wrAt_00000104 ? wrDataF1[7:0] : fifoTxFifoThrd;
    always @(posedge clkMgmt or negedge rstN) begin
        if (!rstN) begin
            fifoTxFifoThrd <= 8'd1;
        end
        else begin
            fifoTxFifoThrd <= fifoTxFifoThrdInt;
        end
    end

    assign xmitInt = wrAt_00000104 ? wrDataF1[9:8] : xmit;
    always @(posedge clkMgmt or negedge rstN) begin
        if (!rstN) begin
            xmit <= 2'd2;
        end
        else begin
            xmit <= xmitInt;
        end
    end

    assign loopbackInt = wrAt_00000104 ? wrDataF1[10] : loopback;
    always @(posedge clkMgmt or negedge rstN) begin
        if (!rstN) begin
            loopback <= 1'h0;
        end
        else begin
            loopback <= loopbackInt;
        end
    end

    assign rxEnInt = wrAt_00000104 ? wrDataF1[11] : rxEn;
    always @(posedge clkMgmt or negedge rstN) begin
        if (!rstN) begin
            rxEn <= 1'h1;
        end
        else begin
            rxEn <= rxEnInt;
        end
    end

    assign softRstInt = wrAt_00000104 ? wrDataF1[12] : softRst;
    always @(posedge clkMgmt or negedge rstN) begin
        if (!rstN) begin
            softRst <= 1'h0;
        end
        else begin
            softRst <= softRstInt;
        end
    end

    assign txEnInt = wrAt_00000104 ? wrDataF1[13] : txEn;
    always @(posedge clkMgmt or negedge rstN) begin
        if (!rstN) begin
            txEn <= 1'h1;
        end
        else begin
            txEn <= txEnInt;
        end
    end

//======================================================
// 存储器端口，命中后去掉地址前缀得到表内地址
// Rd 只在该条目的最低偏移置位。RdAck 为 1 时返回第一个字段，其后各拍按偏移选择后面的字段。写使能在该条目的最后一个合法偏移置位，并与写应答同一拍输出。
//======================================================

//======================================================
// 读应答，Ack 表示完成，Err 表示完成但有错误
// 寄存器汇合结果、各表命中和未命中先收成独热码 rdRspHot，译成 rdRspSel。下一个 always 再用 rdRspSel 给出数据和应答。Ack 与 Err 同一拍变化，未命中时二者同时为 1。
//======================================================

    assign rdRspHot_0 = rdHitL1_0;
    assign rdRspHot_1 = (rdMissF && !rdRspHot_0);

    always @(*) begin
        rdRspSel = 2'd0;
        case ({rdRspHot_1, rdRspHot_0})
            2'h1: rdRspSel = 2'd1;
            2'h2: rdRspSel = 2'd2;
            default: rdRspSel = 2'd0;
        endcase
    end

    always @(*) begin
        regBusRdData = rdAddrErrData;
        regBusRdAck = 1'b0;
        regBusRdErr = 1'b0;
        case (rdRspSel)
            2'd1: begin
                regBusRdData = (rdErrL1_0) ? rdAddrErrData : rdDataL1_0;
                regBusRdAck = 1'b1;
                regBusRdErr = rdErrL1_0;
            end
            2'd2: begin
                regBusRdData = rdAddrErrData;
                regBusRdAck = 1'b1;
                regBusRdErr = 1'b1;
            end
            default: begin
                regBusRdData = rdAddrErrData;
                regBusRdAck = 1'b0;
                regBusRdErr = 1'b0;
            end
        endcase
    end

endmodule
