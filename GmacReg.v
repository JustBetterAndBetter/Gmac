// +FHDR----------------------------------------------------------------------------
// Device        : Xilinx
// Author        : Auto Generated
// Email         : 
// Created On    : 2026/10/04 22:09
// File Name     : GmacReg.v
// Description   : Auto generated register module
//         
// 
// ---------------------------------------------------------------------------------
// Modification History:
// Date         By              Version                 Change Description
// ---------------------------------------------------------------------------------
// 2026/10/04 22:09   Auto Generated   1.0                     Original
// -FHDR----------------------------------------------------------------------------
module GmacReg(/*autoarg*/
        //Inputs
        clock, rstN, wr, wrAddr, wrData, rd, rdAddr, date, user, version, txFifoLevel, rxFifoLevel, fifoAlFull, txFifoPeakCnt, 
        rxFifoPeakCnt, txBusy, rsRxState, padCnt, pcsRxSync, pcsTxState, pcsTxEven, pcsTxRd, pcsRxSyncState, pcsRxEven, 
        pcsRxRd, irqRaw, txOverRunCnt, txUnderRunCnt, rxOverflowCnt, txVbErrCnt, txOversizeCnt, txUnderrunCnt, rxCrcErrCnt, 
        txSfdCnt, rxSfdCnt, lossOfSyncCnt, codeVCnt, txInSfpCnt, txInEfpCnt, txInVbCnt, txInValidCnt, txInErrCnt, txOutSfpCnt, 
        txOutEfpCnt, txOutVbCnt, txOutValidCnt, txOutErrCnt, rxInSfpCnt, rxInEfpCnt, rxInVbCnt, rxInValidCnt, rxInErrCnt, 
        rxOutSfpCnt, rxOutEfpCnt, rxOutVbCnt, rxOutValidCnt, rxOutErrCnt,
        //Outputs
        wrAck, wrErr, rdAck, rdErr, rdData, softRstN, txEn, rxEn, loopback, fifoTxFifoThrd, irqMask, ifgCntMax, lenCntMin, 
        lenCntMax, rxDelCrc, loopbackAlFullThrd, loopbackAlEmptyThrd, gbxTxFifoThrd, gbxRxFifoThrd
);



//###################################################### 
//Interface
//###################################################### 

    input                   clock;
    input                   rstN;

    input                  wr;
    input [31:0]           wrAddr;
    input [31:0]           wrData;
    output                 wrAck;
    output                 wrErr;
    
    input                  rd;
    input [31:0]           rdAddr;
    output                 rdAck;
    output                 rdErr;
    output  [31:0]         rdData;

    //RO WO ,RW ,RI ,WI ,RWI,RIWI

    input     [31:0]         date;
    input     [15:0]         user;
    input     [15:0]         version;
    input     [7:0]          txFifoLevel;
    input     [7:0]          rxFifoLevel;
    input                    fifoAlFull;
    input     [7:0]          txFifoPeakCnt;
    input     [7:0]          rxFifoPeakCnt;
    input                    txBusy;
    input     [1:0]          rsRxState;
    input     [10:0]         padCnt;
    input                    pcsRxSync;
    input     [1:0]          pcsTxState;
    input                    pcsTxEven;
    input                    pcsTxRd;
    input     [2:0]          pcsRxSyncState;
    input                    pcsRxEven;
    input                    pcsRxRd;
    input     [31:0]         irqRaw;
    input     [31:0]         txOverRunCnt;
    input     [31:0]         txUnderRunCnt;
    input     [31:0]         rxOverflowCnt;
    input     [31:0]         txVbErrCnt;
    input     [15:0]         txOversizeCnt;
    input     [15:0]         txUnderrunCnt;
    input     [31:0]         rxCrcErrCnt;
    input     [15:0]         txSfdCnt;
    input     [31:0]         rxSfdCnt;
    input     [31:0]         lossOfSyncCnt;
    input     [31:0]         codeVCnt;
    input     [15:0]         txInSfpCnt;
    input     [15:0]         txInEfpCnt;
    input     [31:0]         txInVbCnt;
    input     [31:0]         txInValidCnt;
    input     [7:0]          txInErrCnt;
    input     [15:0]         txOutSfpCnt;
    input     [15:0]         txOutEfpCnt;
    input     [31:0]         txOutVbCnt;
    input     [31:0]         txOutValidCnt;
    input     [7:0]          txOutErrCnt;
    input     [15:0]         rxInSfpCnt;
    input     [15:0]         rxInEfpCnt;
    input     [31:0]         rxInVbCnt;
    input     [31:0]         rxInValidCnt;
    input     [7:0]          rxInErrCnt;
    input     [15:0]         rxOutSfpCnt;
    input     [15:0]         rxOutEfpCnt;
    input     [31:0]         rxOutVbCnt;
    input     [31:0]         rxOutValidCnt;
    input     [7:0]          rxOutErrCnt;

    output                   softRstN;
    output                   txEn;
    output                   rxEn;
    output                   loopback;
    output    [7:0]          fifoTxFifoThrd;
    output    [31:0]         irqMask;
    output    [3:0]          ifgCntMax;
    output    [10:0]         lenCntMin;
    output    [10:0]         lenCntMax;
    output                   rxDelCrc;
    output    [7:0]          loopbackAlFullThrd;
    output    [7:0]          loopbackAlEmptyThrd;
    output    [7:0]          gbxTxFifoThrd;
    output    [7:0]          gbxRxFifoThrd;

//###################################################### 
//Value
//###################################################### 
wire  [31:0]  rdAddrErrData;
reg   [31:0]  rdData;
reg           rdAck;
reg           rdErr;
reg            softRstN;
reg            txEn;
reg            rxEn;
reg            loopback;
reg  [7:0]     fifoTxFifoThrd;
reg  [31:0]    irqMask;
reg  [3:0]     ifgCntMax;
reg  [10:0]    lenCntMin;
reg  [10:0]    lenCntMax;
reg            rxDelCrc;
reg  [7:0]     loopbackAlFullThrd;
reg  [7:0]     loopbackAlEmptyThrd;
reg  [7:0]     gbxTxFifoThrd;
reg  [7:0]     gbxRxFifoThrd;
wire  [3:0]   rdDecodeLevel0_0;
reg   [31:0]  rdDataLevel0_0;
reg           rdLevel0_0Err;
reg           rdHitLevel0_0;
reg           wrHitLevel0_0;
wire          wrLevel0_0Err;
wire  [3:0]   rdDecodeLevel0_4;
reg   [31:0]  rdDataLevel0_4;
reg           rdLevel0_4Err;
reg           rdHitLevel0_4;
reg           wrHitLevel0_4;
reg           wrLevel0_4Err;
wire  [3:0]   rdDecodeLevel0_5;
reg   [31:0]  rdDataLevel0_5;
reg           rdLevel0_5Err;
reg           rdHitLevel0_5;
reg           wrHitLevel0_5;
wire          wrLevel0_5Err;
wire  [3:0]   rdDecodeLevel0_6;
reg   [31:0]  rdDataLevel0_6;
reg           rdLevel0_6Err;
reg           rdHitLevel0_6;
reg           wrHitLevel0_6;
wire          wrLevel0_6Err;
wire  [3:0]   rdDecodeLevel0_7;
reg   [31:0]  rdDataLevel0_7;
reg           rdLevel0_7Err;
reg           rdHitLevel0_7;
reg           wrHitLevel0_7;
reg           wrLevel0_7Err;
wire  [3:0]   wrDecodeLevel0_4;
wire  [3:0]   wrDecodeLevel0_7;
wire          rdHitDecode;
reg   [31:0]  rdAddrF1;
reg   [31:0]  wrAddrF1;
reg   [31:0]  wrDataF1;

reg  [3:0]   rdSelLevel1_0;
wire         rdHitLevel1_0_wire;
wire [15:0] rdSelLevel1_0_onehot;
reg  [31:0]  rdDataLevel1_0_comb;
reg  [31:0]  rdDataLevel1_0;
reg         rdHitLevel1_0;
reg         rdLevel1_0Err_comb;
reg         rdLevel1_0Err;
//###################################################### 
//Logic
//###################################################### 


//Rd Part

assign rdAddrErrData = 32'heef55fee;

always@(posedge clock or negedge rstN)begin
    if(!rstN)begin
        rdAddrF1 <= 32'h0;
        wrAddrF1 <= 32'h0;
        wrDataF1 <= 32'h0;
        rdHitLevel0_0 <= 1'd0;
        rdHitLevel0_4 <= 1'd0;
        rdHitLevel0_5 <= 1'd0;
        rdHitLevel0_6 <= 1'd0;
        rdHitLevel0_7 <= 1'd0;
    end
    else begin
        rdAddrF1 <= rdAddr;
        wrAddrF1 <= wrAddr;
        wrDataF1 <= wrData;
        rdHitLevel0_0 <= rd && ((rdAddr[31:6] == 26'h0));
        rdHitLevel0_4 <= rd && ((rdAddr[31:6] == 26'h4));
        rdHitLevel0_5 <= rd && ((rdAddr[31:6] == 26'h5));
        rdHitLevel0_6 <= rd && ((rdAddr[31:6] == 26'h6));
        rdHitLevel0_7 <= rd && ((rdAddr[31:6] == 26'h7));
    end
end

assign rdDecodeLevel0_0 = rdAddrF1[5:2];
always@(*) begin
    rdLevel0_0Err = 1'd0;
    case(rdDecodeLevel0_0)
        4'd0:rdDataLevel0_0 = date;
        4'd1:rdDataLevel0_0 = user;
        4'd2:rdDataLevel0_0 = version;
        default:begin 
            rdDataLevel0_0 = rdAddrErrData;
            rdLevel0_0Err = rdHitLevel0_0;
        end
    endcase
end
assign rdDecodeLevel0_4 = rdAddrF1[5:2];
always@(*) begin
    rdLevel0_4Err = 1'd0;
    case(rdDecodeLevel0_4)
        4'd0:rdDataLevel0_4 = softRstN;
        4'd1:rdDataLevel0_4 = txEn;
        4'd2:rdDataLevel0_4 = rxEn;
        4'd3:rdDataLevel0_4 = loopback;
        4'd5:rdDataLevel0_4 = fifoTxFifoThrd;
        4'd6:rdDataLevel0_4 = irqMask;
        4'd7:rdDataLevel0_4 = ifgCntMax;
        4'd8:rdDataLevel0_4 = txFifoLevel;
        4'd9:rdDataLevel0_4 = rxFifoLevel;
        4'd10:rdDataLevel0_4 = fifoAlFull;
        4'd11:rdDataLevel0_4 = txFifoPeakCnt;
        4'd12:rdDataLevel0_4 = rxFifoPeakCnt;
        4'd13:rdDataLevel0_4 = txBusy;
        4'd15:rdDataLevel0_4 = rsRxState;
        default:begin 
            rdDataLevel0_4 = rdAddrErrData;
            rdLevel0_4Err = rdHitLevel0_4;
        end
    endcase
end
assign rdDecodeLevel0_5 = rdAddrF1[5:2];
always@(*) begin
    rdLevel0_5Err = 1'd0;
    case(rdDecodeLevel0_5)
        4'd0:rdDataLevel0_5 = padCnt;
        4'd2:rdDataLevel0_5 = pcsRxSync;
        4'd3:rdDataLevel0_5 = pcsTxState;
        4'd4:rdDataLevel0_5 = pcsTxEven;
        4'd5:rdDataLevel0_5 = pcsTxRd;
        4'd6:rdDataLevel0_5 = pcsRxSyncState;
        4'd7:rdDataLevel0_5 = pcsRxEven;
        4'd8:rdDataLevel0_5 = pcsRxRd;
        4'd9:rdDataLevel0_5 = irqRaw;
        4'd10:rdDataLevel0_5 = txOverRunCnt;
        4'd11:rdDataLevel0_5 = txUnderRunCnt;
        4'd12:rdDataLevel0_5 = rxOverflowCnt;
        4'd13:rdDataLevel0_5 = txVbErrCnt;
        4'd14:rdDataLevel0_5 = txOversizeCnt;
        4'd15:rdDataLevel0_5 = txUnderrunCnt;
        default:begin 
            rdDataLevel0_5 = rdAddrErrData;
            rdLevel0_5Err = rdHitLevel0_5;
        end
    endcase
end
assign rdDecodeLevel0_6 = rdAddrF1[5:2];
always@(*) begin
    rdLevel0_6Err = 1'd0;
    case(rdDecodeLevel0_6)
        4'd0:rdDataLevel0_6 = rxCrcErrCnt;
        4'd1:rdDataLevel0_6 = txSfdCnt;
        4'd2:rdDataLevel0_6 = rxSfdCnt;
        4'd3:rdDataLevel0_6 = lossOfSyncCnt;
        4'd4:rdDataLevel0_6 = codeVCnt;
        4'd5:rdDataLevel0_6 = txInSfpCnt;
        4'd6:rdDataLevel0_6 = txInEfpCnt;
        4'd7:rdDataLevel0_6 = txInVbCnt;
        4'd8:rdDataLevel0_6 = txInValidCnt;
        4'd9:rdDataLevel0_6 = txInErrCnt;
        4'd10:rdDataLevel0_6 = txOutSfpCnt;
        4'd11:rdDataLevel0_6 = txOutEfpCnt;
        4'd12:rdDataLevel0_6 = txOutVbCnt;
        4'd13:rdDataLevel0_6 = txOutValidCnt;
        4'd14:rdDataLevel0_6 = txOutErrCnt;
        4'd15:rdDataLevel0_6 = rxInSfpCnt;
        default:begin 
            rdDataLevel0_6 = rdAddrErrData;
            rdLevel0_6Err = rdHitLevel0_6;
        end
    endcase
end
assign rdDecodeLevel0_7 = rdAddrF1[5:2];
always@(*) begin
    rdLevel0_7Err = 1'd0;
    case(rdDecodeLevel0_7)
        4'd0:rdDataLevel0_7 = rxInEfpCnt;
        4'd1:rdDataLevel0_7 = rxInVbCnt;
        4'd2:rdDataLevel0_7 = rxInValidCnt;
        4'd3:rdDataLevel0_7 = rxInErrCnt;
        4'd4:rdDataLevel0_7 = rxOutSfpCnt;
        4'd5:rdDataLevel0_7 = rxOutEfpCnt;
        4'd6:rdDataLevel0_7 = rxOutVbCnt;
        4'd7:rdDataLevel0_7 = rxOutValidCnt;
        4'd8:rdDataLevel0_7 = rxOutErrCnt;
        4'd9:rdDataLevel0_7 = lenCntMin;
        4'd10:rdDataLevel0_7 = lenCntMax;
        4'd11:rdDataLevel0_7 = rxDelCrc;
        4'd12:rdDataLevel0_7 = loopbackAlFullThrd;
        4'd13:rdDataLevel0_7 = loopbackAlEmptyThrd;
        4'd14:rdDataLevel0_7 = gbxTxFifoThrd;
        4'd15:rdDataLevel0_7 = gbxRxFifoThrd;
        default:begin 
            rdDataLevel0_7 = rdAddrErrData;
            rdLevel0_7Err = rdHitLevel0_7;
        end
    endcase
end
assign rdSelLevel1_0_onehot = {1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, rdHitLevel0_7, rdHitLevel0_6, 
                                   rdHitLevel0_5, rdHitLevel0_4, rdHitLevel0_0};
assign rdHitLevel1_0_wire = |rdSelLevel1_0_onehot;
always@(*) begin
    case(rdSelLevel1_0_onehot)
        16'h1:rdSelLevel1_0 = 4'h0;
        16'h2:rdSelLevel1_0 = 4'h1;
        16'h4:rdSelLevel1_0 = 4'h2;
        16'h8:rdSelLevel1_0 = 4'h3;
        16'h10:rdSelLevel1_0 = 4'h4;
        default:rdSelLevel1_0 = 4'h0;
    endcase
end
always@(*) begin
    case(rdSelLevel1_0)
        4'h0:rdDataLevel1_0_comb = rdDataLevel0_0;
        4'h1:rdDataLevel1_0_comb = rdDataLevel0_4;
        4'h2:rdDataLevel1_0_comb = rdDataLevel0_5;
        4'h3:rdDataLevel1_0_comb = rdDataLevel0_6;
        4'h4:rdDataLevel1_0_comb = rdDataLevel0_7;
        default:rdDataLevel1_0_comb = rdAddrErrData;
    endcase
end
always@(*) begin
    case(rdSelLevel1_0)
        4'h0:rdLevel1_0Err_comb = rdLevel0_0Err;
        4'h1:rdLevel1_0Err_comb = rdLevel0_4Err;
        4'h2:rdLevel1_0Err_comb = rdLevel0_5Err;
        4'h3:rdLevel1_0Err_comb = rdLevel0_6Err;
        4'h4:rdLevel1_0Err_comb = rdLevel0_7Err;
        default:rdLevel1_0Err_comb = 1'd0;
    endcase
end
always@(posedge clock or negedge rstN)begin
    if(!rstN)begin
        rdDataLevel1_0 <= 32'h0;
        rdHitLevel1_0 <= 1'd0;
        rdLevel1_0Err <= 1'd0;
    end
    else begin
        rdDataLevel1_0 <= rdDataLevel1_0_comb;
        rdHitLevel1_0 <= rdHitLevel1_0_wire;
        rdLevel1_0Err <= rdLevel1_0Err_comb;
    end
end

assign rdData = rdHitLevel1_0 ? rdDataLevel1_0 : rdAddrErrData;

assign rdAck = rdHitLevel1_0;
assign rdErr = rdLevel1_0Err;

//Write Part

always@(posedge clock or negedge rstN)begin
    if(!rstN)begin
        wrHitLevel0_0 <= 1'd0;
        wrHitLevel0_4 <= 1'd0;
        wrHitLevel0_5 <= 1'd0;
        wrHitLevel0_6 <= 1'd0;
        wrHitLevel0_7 <= 1'd0;
    end
    else begin
        wrHitLevel0_0 <= wr && ((wrAddr[31:6] == 26'h0));
        wrHitLevel0_4 <= wr && ((wrAddr[31:6] == 26'h4));
        wrHitLevel0_5 <= wr && ((wrAddr[31:6] == 26'h5));
        wrHitLevel0_6 <= wr && ((wrAddr[31:6] == 26'h6));
        wrHitLevel0_7 <= wr && ((wrAddr[31:6] == 26'h7));
    end
end

assign wrAck = wrHitLevel0_0 || wrHitLevel0_4 || wrHitLevel0_5 || wrHitLevel0_6 || wrHitLevel0_7;
assign wrLevel0_0Err = wrHitLevel0_0;
assign wrDecodeLevel0_4 = wrAddrF1[5:2];
always@(*) begin
    case(wrDecodeLevel0_4)
        4'd0:wrLevel0_4Err = 1'd0;
        4'd1:wrLevel0_4Err = 1'd0;
        4'd2:wrLevel0_4Err = 1'd0;
        4'd3:wrLevel0_4Err = 1'd0;
        4'd5:wrLevel0_4Err = 1'd0;
        4'd6:wrLevel0_4Err = 1'd0;
        4'd7:wrLevel0_4Err = 1'd0;
        default:wrLevel0_4Err = wrHitLevel0_4;
    endcase
end
always@(posedge clock or negedge rstN) begin
    if(!rstN)begin
        softRstN <= 1'h1;
        txEn <= 1'h1;
        rxEn <= 1'h1;
        loopback <= 1'h0;
        fifoTxFifoThrd <= 8'd1;
        irqMask <= 32'h0;
        ifgCntMax <= 4'd12;
    end
    else begin
        if(wrHitLevel0_4)begin
            case(wrDecodeLevel0_4)
                4'd0:softRstN             <= wrDataF1;
                4'd1:txEn             <= wrDataF1;
                4'd2:rxEn             <= wrDataF1;
                4'd3:loopback             <= wrDataF1;
                4'd5:fifoTxFifoThrd             <= wrDataF1;
                4'd6:irqMask             <= wrDataF1;
                4'd7:ifgCntMax             <= wrDataF1;
                default:;
            endcase
        end
    end
end
assign wrLevel0_5Err = wrHitLevel0_5;
assign wrLevel0_6Err = wrHitLevel0_6;
assign wrDecodeLevel0_7 = wrAddrF1[5:2];
always@(*) begin
    case(wrDecodeLevel0_7)
        4'd9:wrLevel0_7Err = 1'd0;
        4'd10:wrLevel0_7Err = 1'd0;
        4'd11:wrLevel0_7Err = 1'd0;
        4'd12:wrLevel0_7Err = 1'd0;
        4'd13:wrLevel0_7Err = 1'd0;
        4'd14:wrLevel0_7Err = 1'd0;
        4'd15:wrLevel0_7Err = 1'd0;
        default:wrLevel0_7Err = wrHitLevel0_7;
    endcase
end
always@(posedge clock or negedge rstN) begin
    if(!rstN)begin
        lenCntMin <= 11'd60;
        lenCntMax <= 11'd1514;
        rxDelCrc <= 1'h1;
        loopbackAlFullThrd <= 8'd13;
        loopbackAlEmptyThrd <= 8'd4;
        gbxTxFifoThrd <= 8'd1;
        gbxRxFifoThrd <= 8'd1;
    end
    else begin
        if(wrHitLevel0_7)begin
            case(wrDecodeLevel0_7)
                4'd9:lenCntMin             <= wrDataF1;
                4'd10:lenCntMax             <= wrDataF1;
                4'd11:rxDelCrc             <= wrDataF1;
                4'd12:loopbackAlFullThrd             <= wrDataF1;
                4'd13:loopbackAlEmptyThrd             <= wrDataF1;
                4'd14:gbxTxFifoThrd             <= wrDataF1;
                4'd15:gbxRxFifoThrd             <= wrDataF1;
                default:;
            endcase
        end
    end
end
assign wrErr = wrLevel0_0Err || wrLevel0_4Err || wrLevel0_5Err || wrLevel0_6Err || wrLevel0_7Err;

endmodule
