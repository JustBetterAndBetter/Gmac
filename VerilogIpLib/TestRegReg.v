// +FHDR----------------------------------------------------------------------------
// Device        : Xilinx
// Author        : Auto Generated
// Email         : 
// Created On    : 2025/12/26 22:13
// File Name     : TestRegReg.v
// Description   : Auto generated register module
//         
// 
// ---------------------------------------------------------------------------------
// Modification History:
// Date         By              Version                 Change Description
// ---------------------------------------------------------------------------------
// 2025/12/26 22:13   Auto Generated   1.0                     Original
// -FHDR----------------------------------------------------------------------------
module TestRegReg(/*autoarg*/
        //Inputs
        clock, reset, wr, wrAddr, wrData, rd, rdAddr, date, user, version,
        //Outputs
        wrAck, wrErr, rdAck, rdErr, rdData, key, led
);



//###################################################### 
//Interface
//###################################################### 

    input                   clock;
    input                   reset;

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

    input     [31:0]        date;
    input     [31:0]        user;
    input     [31:0]        version;

    output    [31:0]        key;
    output    [31:0]        led;

//###################################################### 
//Value
//###################################################### 
wire  [31:0]  rdAddrErrData;
reg   [31:0]  rdData;
reg           rdAck;
reg           rdErr;
reg  [31:0]   key;
reg  [31:0]   led;
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
wire  [3:0]   wrDecodeLevel0_0;
wire  [3:0]   wrDecodeLevel0_4;
wire          rdHitDecode;
reg   [31:0]  rdAddrF1;
reg   [31:0]  wrAddrF1;
reg   [31:0]  wrDataF1;

wire [1:0]   rdHitLevel1_Decode;

//###################################################### 
//Logic
//###################################################### 


    //Rd Part

    assign rdAddrErrData = 32'heef55fee;

    always@(posedge clock or negedge reset)begin
        if(!reset)begin
            rdAddrF1 <= 32'h0;
            wrAddrF1 <= 32'h0;
            wrDataF1 <= 32'h0;
            rdHitLevel0_0 <= 1'd0;
            rdHitLevel0_4 <= 1'd0;
        end
        else begin
            rdAddrF1 <= rdAddr;
            wrAddrF1 <= wrAddr;
            wrDataF1 <= wrData;
            rdHitLevel0_0 <= rd && ((rdAddr[31:6] == 26'h0));
            rdHitLevel0_4 <= rd && ((rdAddr[31:6] == 26'h4));
        end
    end

    assign rdDecodeLevel0_0 = rdAddrF1[5:2];
    always@(*) begin
        rdLevel0_0Err = 1'd0;
        case(rdDecodeLevel0_0)
            4'd0:rdDataLevel0_0 = date;
            4'd1:rdDataLevel0_0 = user;
            4'd2:rdDataLevel0_0 = version;
            4'd3:rdDataLevel0_0 = key;
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
            4'd0:rdDataLevel0_4 = led;
            default:begin 
                rdDataLevel0_4 = rdAddrErrData;
                rdLevel0_4Err = rdHitLevel0_4;
            end
        endcase
    end
    assign rdHitLevel1_Decode = {rdHitLevel0_4, rdHitLevel0_0};
    always@(*) begin
        case(rdHitLevel1_Decode)
            2'h1:rdData = rdDataLevel0_0;
            2'h2:rdData = rdDataLevel0_4;
            default:rdData = rdAddrErrData;
        endcase
    end

    always@(*) begin
        case(rdHitLevel1_Decode)
            2'h1:rdAck = 1'd1;
            2'h2:rdAck = 1'd1;
            default:rdAck = 1'd0;
        endcase
    end
    always@(*) begin
        case(rdHitLevel1_Decode)
            2'h1:rdErr = rdLevel0_0Err;
            2'h2:rdErr = rdLevel0_4Err;
            default:rdErr = 1'd0;
        endcase
    end

    //Write Part

    always@(posedge clock or negedge reset)begin
        if(!reset)begin
            wrHitLevel0_0 <= 1'd0;
            wrHitLevel0_4 <= 1'd0;
        end
        else begin
            wrHitLevel0_0 <= wr && ((wrAddr[31:6] == 26'h0));
            wrHitLevel0_4 <= wr && ((wrAddr[31:6] == 26'h4));
        end
    end

    assign wrAck = wrHitLevel0_0 || wrHitLevel0_4;
    assign wrDecodeLevel0_0 = wrAddrF1[5:2];
    always@(*) begin
        case(wrDecodeLevel0_0)
            4'd3:wrLevel0_0Err = 1'd0;
            default:wrLevel0_0Err = wrHitLevel0_0;
        endcase
    end
    always@(posedge clock ) begin
        if(wrHitLevel0_0)begin
            case(wrDecodeLevel0_0)
                4'd3:key             <= wrDataF1;
                default:;
            endcase
        end
    end
    assign wrDecodeLevel0_4 = wrAddrF1[5:2];
    always@(*) begin
        case(wrDecodeLevel0_4)
            4'd0:wrLevel0_4Err = 1'd0;
            default:wrLevel0_4Err = wrHitLevel0_4;
        endcase
    end
    always@(posedge clock ) begin
        if(wrHitLevel0_4)begin
            case(wrDecodeLevel0_4)
                4'd0:led             <= wrDataF1;
                default:;
            endcase
        end
    end
    assign wrErr = wrLevel0_0Err || wrLevel0_4Err;

endmodule
