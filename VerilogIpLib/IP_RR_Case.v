// +FHDR----------------------------------------------------------------------------
// Device        : Xilinx
// Author        : fxdqe
// Email         : 1706260166@qq.com
// Created On    : 2025/08/29 22:07
// File Name     : IP_RR_Case.v
// Description   :
//         
// 
// ---------------------------------------------------------------------------------
// Modification History:
// Date         By              Version                 Change Description
// ---------------------------------------------------------------------------------
// 2025/08/29   fxdqe           1.0                     Original
// -FHDR----------------------------------------------------------------------------
module IP_RR_Case(/*autoarg*/
        //Inputs
        clock, reset, hold, req, 
        //Outputs
        grant
);



parameter REQ_WIDTH = 32;
//###################################################### 
//Interface
//###################################################### 

input    clock;
input    reset;


input                     hold;

input    [REQ_WIDTH-1:0]  req;
output   [REQ_WIDTH-1:0]  grant;




//###################################################### 
//Value
//###################################################### 

reg      [REQ_WIDTH-1:0]  grant0;
reg      [REQ_WIDTH-1:0]  grant1;

reg      [REQ_WIDTH-1:0]  lastGrant;
reg      [REQ_WIDTH-1:0]  lastGrantLock;

wire     [REQ_WIDTH-1:0]  req0;
wire     [REQ_WIDTH-1:0]  req1;



//###################################################### 
//Logic
//###################################################### 

    assign req0 = req & lastGrantLock;

    always@(*)begin
        casex(req0)
            32'h8xxx_xxxx:grant0 = 32'h8000_0000;
            32'h4xxx_xxxx:grant0 = 32'h4000_0000;
            32'h2xxx_xxxx:grant0 = 32'h2000_0000;
            32'h1xxx_xxxx:grant0 = 32'h1000_0000;
            32'h08xx_xxxx:grant0 = 32'h0800_0000;
            32'h04xx_xxxx:grant0 = 32'h0400_0000;
            32'h02xx_xxxx:grant0 = 32'h0200_0000;
            32'h01xx_xxxx:grant0 = 32'h0100_0000;
            32'h008x_xxxx:grant0 = 32'h0080_0000;
            32'h004x_xxxx:grant0 = 32'h0040_0000;
            32'h002x_xxxx:grant0 = 32'h0020_0000;
            32'h001x_xxxx:grant0 = 32'h0010_0000;
            32'h0008_xxxx:grant0 = 32'h0008_0000;
            32'h0004_xxxx:grant0 = 32'h0004_0000;
            32'h0002_xxxx:grant0 = 32'h0002_0000;
            32'h0001_xxxx:grant0 = 32'h0001_0000;
            32'h0000_8xxx:grant0 = 32'h0000_8000;
            32'h0000_4xxx:grant0 = 32'h0000_4000;
            32'h0000_2xxx:grant0 = 32'h0000_2000;
            32'h0000_1xxx:grant0 = 32'h0000_1000;
            32'h0000_08xx:grant0 = 32'h0000_0800;
            32'h0000_04xx:grant0 = 32'h0000_0400;
            32'h0000_02xx:grant0 = 32'h0000_0200;
            32'h0000_01xx:grant0 = 32'h0000_0100;
            32'h0000_008x:grant0 = 32'h0000_0080;
            32'h0000_004x:grant0 = 32'h0000_0040;
            32'h0000_002x:grant0 = 32'h0000_0020;
            32'h0000_001x:grant0 = 32'h0000_0010;
            32'h0000_0008:grant0 = 32'h0000_0008;
            32'h0000_0004:grant0 = 32'h0000_0004;
            32'h0000_0002:grant0 = 32'h0000_0002;
            32'h0000_0001:grant0 = 32'h0000_0001;
            default:grant0=32'd0;
        endcase
    end

    assign req1 = req & (~lastGrantLock);
    always@(*)begin
        casex(req1)
            32'h8xxx_xxxx:grant1 = 32'h8000_0000;
            32'h4xxx_xxxx:grant1 = 32'h4000_0000;
            32'h2xxx_xxxx:grant1 = 32'h2000_0000;
            32'h1xxx_xxxx:grant1 = 32'h1000_0000;
            32'h08xx_xxxx:grant1 = 32'h0800_0000;
            32'h04xx_xxxx:grant1 = 32'h0400_0000;
            32'h02xx_xxxx:grant1 = 32'h0200_0000;
            32'h01xx_xxxx:grant1 = 32'h0100_0000;
            32'h008x_xxxx:grant1 = 32'h0080_0000;
            32'h004x_xxxx:grant1 = 32'h0040_0000;
            32'h002x_xxxx:grant1 = 32'h0020_0000;
            32'h001x_xxxx:grant1 = 32'h0010_0000;
            32'h0008_xxxx:grant1 = 32'h0008_0000;
            32'h0004_xxxx:grant1 = 32'h0004_0000;
            32'h0002_xxxx:grant1 = 32'h0002_0000;
            32'h0001_xxxx:grant1 = 32'h0001_0000;
            32'h0000_8xxx:grant1 = 32'h0000_8000;
            32'h0000_4xxx:grant1 = 32'h0000_4000;
            32'h0000_2xxx:grant1 = 32'h0000_2000;
            32'h0000_1xxx:grant1 = 32'h0000_1000;
            32'h0000_08xx:grant1 = 32'h0000_0800;
            32'h0000_04xx:grant1 = 32'h0000_0400;
            32'h0000_02xx:grant1 = 32'h0000_0200;
            32'h0000_01xx:grant1 = 32'h0000_0100;
            32'h0000_008x:grant1 = 32'h0000_0080;
            32'h0000_004x:grant1 = 32'h0000_0040;
            32'h0000_002x:grant1 = 32'h0000_0020;
            32'h0000_001x:grant1 = 32'h0000_0010;
            32'h0000_0008:grant1 = 32'h0000_0008;
            32'h0000_0004:grant1 = 32'h0000_0004;
            32'h0000_0002:grant1 = 32'h0000_0002;
            32'h0000_0001:grant1 = 32'h0000_0001;
            default:grant1=32'd0;
        endcase
    end
    assign grant = hold ? 32'h0 : (|grant1) ? grant1:grant0;
    always@(*)begin
        case(grant)
            32'h8000_0000:lastGrant = 32'h8111_1111;
            32'h4000_0000:lastGrant = 32'h4111_1111;
            32'h2000_0000:lastGrant = 32'h2111_1111;
            32'h1000_0000:lastGrant = 32'h1111_1111;
            32'h0800_0000:lastGrant = 32'h0811_1111;
            32'h0400_0000:lastGrant = 32'h0411_1111;
            32'h0200_0000:lastGrant = 32'h0211_1111;
            32'h0100_0000:lastGrant = 32'h0111_1111;
            32'h0080_0000:lastGrant = 32'h0081_1111;
            32'h0040_0000:lastGrant = 32'h0041_1111;
            32'h0020_0000:lastGrant = 32'h0021_1111;
            32'h0010_0000:lastGrant = 32'h0011_1111;
            32'h0008_0000:lastGrant = 32'h0008_1111;
            32'h0004_0000:lastGrant = 32'h0004_1111;
            32'h0002_0000:lastGrant = 32'h0002_1111;
            32'h0001_0000:lastGrant = 32'h0001_1111;
            32'h0000_8000:lastGrant = 32'h0000_8111;
            32'h0000_4000:lastGrant = 32'h0000_4111;
            32'h0000_2000:lastGrant = 32'h0000_2111;
            32'h0000_1000:lastGrant = 32'h0000_1111;
            32'h0000_0800:lastGrant = 32'h0000_0811;
            32'h0000_0400:lastGrant = 32'h0000_0411;
            32'h0000_0200:lastGrant = 32'h0000_0211;
            32'h0000_0100:lastGrant = 32'h0000_0111;
            32'h0000_0080:lastGrant = 32'h0000_0081;
            32'h0000_0040:lastGrant = 32'h0000_0041;
            32'h0000_0020:lastGrant = 32'h0000_0021;
            32'h0000_0010:lastGrant = 32'h0000_0011;
            32'h0000_0008:lastGrant = 32'h0000_0008;
            32'h0000_0004:lastGrant = 32'h0000_0004;
            32'h0000_0002:lastGrant = 32'h0000_0002;
            32'h0000_0001:lastGrant = 32'h0000_0001;
            default:lastGrant=lastGrantLock;
        endcase
    end

    always@(posedge clock or negedge reset)begin
        if(!reset)begin
            lastGrantLock <= 32'h0;
        end
        else begin
            lastGrantLock <= lastGrant;
        end
    end
endmodule
