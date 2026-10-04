// +FHDR----------------------------------------------------------------------------
// Device        : Xilinx
// Author        : Auto Generated
// Email         : 
// Created On    : 2026/04/04 02:49
// File Name     : templateReg.v
// Description   : Auto generated register module
//         
// 
// ---------------------------------------------------------------------------------
// Modification History:
// Date         By              Version                 Change Description
// ---------------------------------------------------------------------------------
// 2026/04/04 02:49   Auto Generated   1.0                     Original
// -FHDR----------------------------------------------------------------------------
module templateReg(/*autoarg*/
        //Inputs
        clock, rstN, wr, wrAddr, wrData, rd, rdAddr, date, user, version, inPktCnt, 
        inSopPktCnt, inChan0PktCnt, readDone, readStart, status0Intr, status1Intr, status2Intr, interrupt0Set, mem1cnt0RdData, 
        mem1cnt1RdData, mem1RdAck, mem2disCnt0RdData, mem2checkCnt1RdData, mem2checkCnt2RdData, mem2RdAck,
        //Outputs
        wrAck, wrErr, rdAck, rdErr, rdData, Key, dna1, dna2, dna3, softReset, rdReadDone, 
        rdReadStart, startInitWrData, wrStartInit, status0IntrWrData, wrStatus0Intr, rdStatus0Intr, status1IntrWrData, 
        wrStatus1Intr, rdStatus1Intr, status2IntrWrData, wrStatus2Intr, rdStatus2Intr, interrupt0SetWrData, wrInterrupt0Set, 
        mem1cnt0WrData, mem1cnt1WrData, mem1Wr, mem1WrAddr, mem1Rd, mem1RdAddr, mem2disCnt0WrData, mem2checkCnt1WrData, 
        mem2checkCnt2WrData, mem2Wr, mem2WrAddr, mem2Rd, mem2RdAddr
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
    input     [15:0]         inPktCnt;
    input     [31:0]         inSopPktCnt;
    input     [31:0]         inChan0PktCnt;
    input                    readDone;
    input                    readStart;
    input     [31:0]         status0Intr;
    input     [31:0]         status1Intr;
    input     [31:0]         status2Intr;
    input     [31:0]         interrupt0Set;

    output    [31:0]         Key;
    output    [31:0]         dna1;
    output    [14:0]         dna2;
    output    [31:0]         dna3;
    output                   softReset;
    output                  rdReadDone;
    output                  rdReadStart;
    output                   startInitWrData;
    output                  wrStartInit;
    output    [31:0]         status0IntrWrData;
    output                  wrStatus0Intr;
    output                  rdStatus0Intr;
    output    [31:0]         status1IntrWrData;
    output                  wrStatus1Intr;
    output                  rdStatus1Intr;
    output    [31:0]         status2IntrWrData;
    output                  wrStatus2Intr;
    output                  rdStatus2Intr;
    output    [31:0]         interrupt0SetWrData;
    output                  wrInterrupt0Set;

    //Memory interfaces

    output    [31:0]        mem1cnt0WrData;
    input     [31:0]        mem1cnt0RdData;
    output    [15:0]        mem1cnt1WrData;
    input     [15:0]        mem1cnt1RdData;
    output                  mem1Wr;
    output    [3:0]          mem1WrAddr;
    output                  mem1Rd;
    output    [3:0]          mem1RdAddr;
    input                    mem1RdAck;

    output    [31:0]        mem2disCnt0WrData;
    input     [31:0]        mem2disCnt0RdData;
    output    [31:0]        mem2checkCnt1WrData;
    input     [31:0]        mem2checkCnt1RdData;
    output    [31:0]        mem2checkCnt2WrData;
    input     [31:0]        mem2checkCnt2RdData;
    output                  mem2Wr;
    output    [7:0]          mem2WrAddr;
    output                  mem2Rd;
    output    [7:0]          mem2RdAddr;
    input                    mem2RdAck;

//###################################################### 
//Value
//###################################################### 
wire  [31:0]  rdAddrErrData;
reg   [31:0]  rdData;
reg           rdAck;
reg           rdErr;
reg   [2:0]   rdDataSel;
reg           rdReadDone;
reg           rdReadStart;
reg           wrStartInit;
reg           rdStatus0Intr;
reg           wrStatus0Intr;
reg           rdStatus1Intr;
reg           wrStatus1Intr;
reg           rdStatus2Intr;
reg           wrStatus2Intr;
reg           wrInterrupt0Set;
reg  [31:0]    Key;
reg  [31:0]    dna1;
reg  [14:0]    dna2;
reg  [31:0]    dna3;
reg            softReset;
reg            startInitWrData;
reg  [31:0]    status0IntrWrData;
reg  [31:0]    status1IntrWrData;
reg  [31:0]    status2IntrWrData;
reg  [31:0]    interrupt0SetWrData;
reg  [31:0]   mem1cnt0WrData;
reg  [15:0]   mem1cnt1WrData;
reg           mem1RdHit;
reg           mem1WrHit;
wire  [0:0]   mem1RdOffsetDecode;
wire  [0:0]   mem1WrOffsetDecode;
reg   [31:0]   mem1RdDataTemp;
wire          mem1RdErr;
wire          mem1RdHitReal;
wire          mem1WrErr;
wire          mem1RdInt;
wire          mem1WrInt;
wire  [3:0]   mem1RdAddrInt;
wire  [3:0]   mem1WrAddrInt;
reg           mem1Wr;
reg  [3:0]   mem1WrAddr;
reg  [31:0]   mem2disCnt0WrData;
reg  [31:0]   mem2checkCnt1WrData;
reg  [31:0]   mem2checkCnt2WrData;
reg           mem2RdHit;
reg           mem2WrHit;
wire  [1:0]   mem2RdOffsetDecode;
wire  [1:0]   mem2WrOffsetDecode;
reg   [31:0]   mem2RdDataTemp;
wire          mem2RdErr;
wire          mem2RdHitReal;
wire          mem2WrErr;
wire          mem2RdInt;
wire          mem2WrInt;
wire  [7:0]   mem2RdAddrInt;
wire  [7:0]   mem2WrAddrInt;
reg           mem2Wr;
reg  [7:0]   mem2WrAddr;
wire  [3:0]   rdDecodeLevel0_0;
reg   [31:0]  rdDataLevel0_0;
reg           rdLevel0_0Err;
reg           rdHitLevel0_0;
reg           wrHitLevel0_0;
reg           wrLevel0_0Err;
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
reg           wrLevel0_5Err;
wire  [3:0]   wrDecodeLevel0_0;
wire  [3:0]   wrDecodeLevel0_4;
wire  [3:0]   wrDecodeLevel0_5;
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
            mem1RdHit <= 1'd0;
            mem2RdHit <= 1'd0;
        end
        else begin
            rdAddrF1 <= rdAddr;
            wrAddrF1 <= wrAddr;
            wrDataF1 <= wrData;
            rdHitLevel0_0 <= rd && ((rdAddr[31:6] == 26'h0));
            rdHitLevel0_4 <= rd && ((rdAddr[31:6] == 26'h4));
            rdHitLevel0_5 <= rd && ((rdAddr[31:6] == 26'h5));
            mem1RdHit <= rd && (rdAddr[31:7] == 25'h3);
            mem2RdHit <= rd && (rdAddr[31:12] == 20'h1);
        end
    end

    assign rdDecodeLevel0_0 = rdAddrF1[5:2];
    always@(*) begin
        rdLevel0_0Err = 1'd0;
        case(rdDecodeLevel0_0)
            4'd0:rdDataLevel0_0 = date;
            4'd1:rdDataLevel0_0 = user;
            4'd2:rdDataLevel0_0 = version;
            4'd3:rdDataLevel0_0 = Key;
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
            4'd0:rdDataLevel0_4 = inPktCnt;
            4'd1:rdDataLevel0_4 = inSopPktCnt;
            4'd2:rdDataLevel0_4 = inChan0PktCnt;
            4'd8:rdDataLevel0_4 = softReset;
            4'd12:rdDataLevel0_4 = readDone;
            4'd13:rdDataLevel0_4 = readStart;
            default:begin 
                rdDataLevel0_4 = rdAddrErrData;
                rdLevel0_4Err = rdHitLevel0_4;
            end
        endcase
    end
    always@(*) begin
        rdReadDone         = 1'd0;
        rdReadStart         = 1'd0;
        case(rdDecodeLevel0_4)
            4'd12:rdReadDone         = rdHitLevel0_4;
            4'd13:rdReadStart         = rdHitLevel0_4;
            default:;
        endcase
    end

    assign rdDecodeLevel0_5 = rdAddrF1[5:2];
    always@(*) begin
        rdLevel0_5Err = 1'd0;
        case(rdDecodeLevel0_5)
            4'd4:rdDataLevel0_5 = status0Intr;
            4'd5:rdDataLevel0_5 = status1Intr;
            4'd6:rdDataLevel0_5 = status2Intr;
            4'd8:rdDataLevel0_5 = interrupt0Set;
            default:begin 
                rdDataLevel0_5 = rdAddrErrData;
                rdLevel0_5Err = rdHitLevel0_5;
            end
        endcase
    end
    always@(*) begin
        rdStatus0Intr         = 1'd0;
        rdStatus1Intr         = 1'd0;
        rdStatus2Intr         = 1'd0;
        case(rdDecodeLevel0_5)
            4'd4:rdStatus0Intr         = rdHitLevel0_5;
            4'd5:rdStatus1Intr         = rdHitLevel0_5;
            4'd6:rdStatus2Intr         = rdHitLevel0_5;
            default:;
        endcase
    end

    assign mem1RdOffsetDecode = rdAddrF1[2:2];
    always@(*) begin
        if(mem1RdAck)begin
            mem1RdDataTemp = {mem1cnt0RdData};
        end
        else begin
            case(mem1RdOffsetDecode)
                1'd0:mem1RdDataTemp = {mem1cnt0RdData};
                1'd1:mem1RdDataTemp = {16'd0, mem1cnt1RdData};
                default:mem1RdDataTemp = rdAddrErrData;
            endcase
        end
    end

    assign mem1RdErr = mem1RdHit && !(mem1RdOffsetDecode == 1'd0 || mem1RdOffsetDecode == 1'd1);
    assign mem1RdHitReal = mem1RdHit && !mem1RdErr;

    assign mem1RdInt = mem1RdHit && (mem1RdOffsetDecode == 1'd0);
    assign mem1RdAddrInt = rdAddrF1[6:3];
    assign mem1Rd = mem1RdInt;
    assign mem1RdAddr = mem1RdAddrInt;

    assign mem2RdOffsetDecode = rdAddrF1[3:2];
    always@(*) begin
        if(mem2RdAck)begin
            mem2RdDataTemp = {mem2disCnt0RdData};
        end
        else begin
            case(mem2RdOffsetDecode)
                2'd0:mem2RdDataTemp = {mem2disCnt0RdData};
                2'd1:mem2RdDataTemp = {mem2checkCnt1RdData};
                2'd2:mem2RdDataTemp = {mem2checkCnt2RdData};
                default:mem2RdDataTemp = rdAddrErrData;
            endcase
        end
    end

    assign mem2RdErr = mem2RdHit && !(mem2RdOffsetDecode == 2'd0 || mem2RdOffsetDecode == 2'd1 || mem2RdOffsetDecode == 2'd2);
    assign mem2RdHitReal = mem2RdHit && !mem2RdErr;

    assign mem2RdInt = mem2RdHit && (mem2RdOffsetDecode == 2'd0);
    assign mem2RdAddrInt = rdAddrF1[11:4];
    assign mem2Rd = mem2RdInt;
    assign mem2RdAddr = mem2RdAddrInt;

    assign rdSelLevel1_0_onehot = {1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, rdHitLevel0_5, 
                                       rdHitLevel0_4, rdHitLevel0_0};
    assign rdHitLevel1_0_wire = |rdSelLevel1_0_onehot;
    always@(*) begin
        case(rdSelLevel1_0_onehot)
            16'h1:rdSelLevel1_0 = 4'h0;
            16'h2:rdSelLevel1_0 = 4'h1;
            16'h4:rdSelLevel1_0 = 4'h2;
            default:rdSelLevel1_0 = 4'h0;
        endcase
    end
    always@(*) begin
        case(rdSelLevel1_0)
            4'h0:rdDataLevel1_0_comb = rdDataLevel0_0;
            4'h1:rdDataLevel1_0_comb = rdDataLevel0_4;
            4'h2:rdDataLevel1_0_comb = rdDataLevel0_5;
            default:rdDataLevel1_0_comb = rdAddrErrData;
        endcase
    end
    always@(*) begin
        case(rdSelLevel1_0)
            4'h0:rdLevel1_0Err_comb = rdLevel0_0Err;
            4'h1:rdLevel1_0Err_comb = rdLevel0_4Err;
            4'h2:rdLevel1_0Err_comb = rdLevel0_5Err;
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

    always@(*) begin
        if(rdHitLevel1_0) begin
            rdDataSel = 3'd0;
        end
        else if(mem1RdAck || mem1RdHitReal) begin
            rdDataSel = 3'd1;
        end
        else if(mem2RdAck || mem2RdHitReal) begin
            rdDataSel = 3'd2;
        end
        else begin
            rdDataSel = 3'd3;
        end
    end

    always@(*) begin
        case(rdDataSel)
            3'd0:rdData = rdDataLevel1_0;
            3'd1:rdData = mem1RdDataTemp;
            3'd2:rdData = mem2RdDataTemp;
            default:rdData = rdAddrErrData;
        endcase
    end

    assign rdAck = rdHitLevel1_0 || mem1RdAck || (mem1RdHit && !mem1Rd) || mem2RdAck || (mem2RdHit && !mem2Rd);
    assign rdErr = rdLevel1_0Err || mem1RdErr || mem2RdErr;

    //Write Part

    always@(posedge clock or negedge rstN)begin
        if(!rstN)begin
            wrHitLevel0_0 <= 1'd0;
            wrHitLevel0_4 <= 1'd0;
            wrHitLevel0_5 <= 1'd0;
            mem1WrHit <= 1'd0;
            mem2WrHit <= 1'd0;
        end
        else begin
            wrHitLevel0_0 <= wr && ((wrAddr[31:6] == 26'h0));
            wrHitLevel0_4 <= wr && ((wrAddr[31:6] == 26'h4));
            wrHitLevel0_5 <= wr && ((wrAddr[31:6] == 26'h5));
            mem1WrHit <= wr && (wrAddr[31:7] == 25'h3);
            mem2WrHit <= wr && (wrAddr[31:12] == 20'h1);
        end
    end

    assign wrAck = wrHitLevel0_0 || wrHitLevel0_4 || wrHitLevel0_5 || mem1WrHit || mem2WrHit;
    assign wrDecodeLevel0_0 = wrAddrF1[5:2];
    always@(*) begin
        case(wrDecodeLevel0_0)
            4'd3:wrLevel0_0Err = 1'd0;
            default:wrLevel0_0Err = wrHitLevel0_0;
        endcase
    end
    always@(posedge clock or negedge rstN) begin
        if(!rstN)begin
            Key <= 32'h0;
        end
        else begin
            if(wrHitLevel0_0)begin
                case(wrDecodeLevel0_0)
                    4'd3:Key             <= wrDataF1;
                    default:;
                endcase
            end
        end
    end
    assign wrDecodeLevel0_4 = wrAddrF1[5:2];
    always@(*) begin
        case(wrDecodeLevel0_4)
            4'd4:wrLevel0_4Err = 1'd0;
            4'd5:wrLevel0_4Err = 1'd0;
            4'd6:wrLevel0_4Err = 1'd0;
            4'd8:wrLevel0_4Err = 1'd0;
            default:wrLevel0_4Err = wrHitLevel0_4;
        endcase
    end
    always@(posedge clock or negedge rstN) begin
        if(!rstN)begin
            dna1 <= 32'h789;
            dna2 <= 15'h123;
            dna3 <= 32'habc;
            softReset <= 1'h1;
        end
        else begin
            if(wrHitLevel0_4)begin
                case(wrDecodeLevel0_4)
                    4'd4:dna1             <= wrDataF1;
                    4'd5:dna2             <= wrDataF1;
                    4'd6:dna3             <= wrDataF1;
                    4'd8:softReset             <= wrDataF1;
                    default:;
                endcase
            end
        end
    end
    assign wrDecodeLevel0_5 = wrAddrF1[5:2];
    always@(*) begin
        case(wrDecodeLevel0_5)
            4'd0:wrLevel0_5Err = 1'd0;
            4'd4:wrLevel0_5Err = 1'd0;
            4'd5:wrLevel0_5Err = 1'd0;
            4'd6:wrLevel0_5Err = 1'd0;
            4'd8:wrLevel0_5Err = 1'd0;
            default:wrLevel0_5Err = wrHitLevel0_5;
        endcase
    end
    always@(posedge clock ) begin
        if(wrHitLevel0_5)begin
            case(wrDecodeLevel0_5)
                4'd0:startInitWrData        <= wrDataF1;
                4'd4:status0IntrWrData        <= wrDataF1;
                4'd5:status1IntrWrData        <= wrDataF1;
                4'd6:status2IntrWrData        <= wrDataF1;
                4'd8:interrupt0SetWrData        <= wrDataF1;
                default:;
            endcase
        end
    end
    always@(posedge clock ) begin
        wrStartInit        <= 1'd0;
        wrStatus0Intr        <= 1'd0;
        wrStatus1Intr        <= 1'd0;
        wrStatus2Intr        <= 1'd0;
        wrInterrupt0Set        <= 1'd0;
        if(wrHitLevel0_5) begin
            case(wrDecodeLevel0_5)
                4'd0:wrStartInit        <= 1'd1;
                4'd4:wrStatus0Intr        <= 1'd1;
                4'd5:wrStatus1Intr        <= 1'd1;
                4'd6:wrStatus2Intr        <= 1'd1;
                4'd8:wrInterrupt0Set        <= 1'd1;
                default:;
            endcase
        end
    end

    assign mem1WrOffsetDecode = wrAddrF1[2:2];
    always@(posedge clock ) begin
        if(mem1WrHit && mem1WrOffsetDecode == 1'd0) begin
            mem1cnt0WrData <= wrDataF1[31:0];
        end
        if(mem1WrHit && mem1WrOffsetDecode == 1'd1) begin
            mem1cnt1WrData <= wrDataF1[15:0];
        end
    end

    assign mem1WrErr = mem1WrHit && !(mem1WrOffsetDecode == 1'd0 || mem1WrOffsetDecode == 1'd1);

    assign mem1WrInt = mem1WrHit && (mem1WrOffsetDecode == 1'd1);
    assign mem1WrAddrInt = wrAddrF1[6:3];
    always@(posedge clock or negedge rstN)begin
        if(!rstN)begin
            mem1Wr <= 1'd0;
            mem1WrAddr <= 4'd0;
        end
        else begin
            mem1Wr <= mem1WrInt;
            mem1WrAddr <= mem1WrAddrInt;
        end
    end

    assign mem2WrOffsetDecode = wrAddrF1[3:2];
    always@(posedge clock ) begin
        if(mem2WrHit && mem2WrOffsetDecode == 2'd0) begin
            mem2disCnt0WrData <= wrDataF1[31:0];
        end
        if(mem2WrHit && mem2WrOffsetDecode == 2'd1) begin
            mem2checkCnt1WrData <= wrDataF1[31:0];
        end
        if(mem2WrHit && mem2WrOffsetDecode == 2'd2) begin
            mem2checkCnt2WrData <= wrDataF1[31:0];
        end
    end

    assign mem2WrErr = mem2WrHit && !(mem2WrOffsetDecode == 2'd0 || mem2WrOffsetDecode == 2'd1 || mem2WrOffsetDecode == 2'd2);

    assign mem2WrInt = mem2WrHit && (mem2WrOffsetDecode == 2'd2);
    assign mem2WrAddrInt = wrAddrF1[11:4];
    always@(posedge clock or negedge rstN)begin
        if(!rstN)begin
            mem2Wr <= 1'd0;
            mem2WrAddr <= 8'd0;
        end
        else begin
            mem2Wr <= mem2WrInt;
            mem2WrAddr <= mem2WrAddrInt;
        end
    end

    assign wrErr = wrLevel0_0Err || wrLevel0_4Err || wrLevel0_5Err || mem1WrErr || mem2WrErr;

endmodule
