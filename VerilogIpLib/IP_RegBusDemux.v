// +FHDR----------------------------------------------------------------------------
// Device        : Xilinx
// Author        : fxdqe
// Email         : 1706260166@qq.com
// Created On    : 2025/12/26 12:13
// Last Modified : 2025/12/26 13:00
// File Name     : RegDemux.v
// Description   : this is used to change the RegBus to eight RegBus
//         
// 
// ---------------------------------------------------------------------------------
// Modification History:
// Date         By              Version                 Change Description
// ---------------------------------------------------------------------------------
// 2025/12/26   fxdqe           1.0                     Original
// -FHDR----------------------------------------------------------------------------
module RegBusDemux(/*autoarg*/
        //Inputs
        wr, wrAddr, wrData, rd, 
        rdAddr, decOffset, wrAck0, 
        wrErr0, rdAck0, rdErr0, 
        rdData0, wrAck1, wrErr1, 
        rdAck1, rdErr1, rdData1, 
        wrAck2, wrErr2, rdAck2, 
        rdErr2, rdData2, wrAck3, 
        wrErr3, rdAck3, rdErr3, 
        rdData3, wrAck4, wrErr4, 
        rdAck4, rdErr4, rdData4, 
        wrAck5, wrErr5, rdAck5, 
        rdErr5, rdData5, wrAck6, 
        wrErr6, rdAck6, rdErr6, 
        rdData6, wrAck7, wrErr7, 
        rdAck7, rdErr7, rdData7, 
        //Outputs
        wrAck, wrErr, rdAck, rdErr, 
        rdData, wr0, wrAddr0, 
        wrData0, rd0, rdAddr0, 
        wr1, wrAddr1, wrData1, 
        rd1, rdAddr1, wr2, 
        wrAddr2, wrData2, rd2, 
        rdAddr2, wr3, wrAddr3, 
        wrData3, rd3, rdAddr3, 
        wr4, wrAddr4, wrData4, 
        rd4, rdAddr4, wr5, 
        wrAddr5, wrData5, rd5, 
        rdAddr5, wr6, wrAddr6, 
        wrData6, rd6, rdAddr6, 
        wr7, wrAddr7, wrData7, 
        rd7, rdAddr7
);



//###################################################### 
//Interface
//###################################################### 

    

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

    input        [4:0]     decOffset;


    output                  wr0;
    output [31:0]           wrAddr0;
    output [31:0]           wrData0;
    input                   wrAck0;
    input                   wrErr0;
    output                  rd0;
    output [31:0]           rdAddr0;
    input                   rdAck0;
    input                   rdErr0;
    input  [31:0]           rdData0;

    output                  wr1;
    output [31:0]           wrAddr1;
    output [31:0]           wrData1;
    input                   wrAck1;
    input                   wrErr1;
    output                  rd1;
    output [31:0]           rdAddr1;
    input                   rdAck1;
    input                   rdErr1;
    input  [31:0]           rdData1;

    output                  wr2;
    output [31:0]           wrAddr2;
    output [31:0]           wrData2;
    input                   wrAck2;
    input                   wrErr2;
    output                  rd2;
    output [31:0]           rdAddr2;
    input                   rdAck2;
    input                   rdErr2;
    input  [31:0]           rdData2;

    output                  wr3;
    output [31:0]           wrAddr3;
    output [31:0]           wrData3;
    input                   wrAck3;
    input                   wrErr3;
    output                  rd3;
    output [31:0]           rdAddr3;
    input                   rdAck3;
    input                   rdErr3;
    input  [31:0]           rdData3;

    output                  wr4;
    output [31:0]           wrAddr4;
    output [31:0]           wrData4;
    input                   wrAck4;
    input                   wrErr4;
    output                  rd4;
    output [31:0]           rdAddr4;
    input                   rdAck4;
    input                   rdErr4;
    input  [31:0]           rdData4;

    output                  wr5;
    output [31:0]           wrAddr5;
    output [31:0]           wrData5;
    input                   wrAck5;
    input                   wrErr5;
    output                  rd5;
    output [31:0]           rdAddr5;
    input                   rdAck5;
    input                   rdErr5;
    input  [31:0]           rdData5;

    output                  wr6;
    output [31:0]           wrAddr6;
    output [31:0]           wrData6;
    input                   wrAck6;
    input                   wrErr6;
    output                  rd6;
    output [31:0]           rdAddr6;
    input                   rdAck6;
    input                   rdErr6;
    input  [31:0]           rdData6;

    output                  wr7;
    output [31:0]           wrAddr7;
    output [31:0]           wrData7;
    input                   wrAck7;
    input                   wrErr7;
    output                  rd7;
    output [31:0]           rdAddr7;
    input                   rdAck7;
    input                   rdErr7;
    input  [31:0]           rdData7;






//###################################################### 
//Value
//###################################################### 

reg    [2:0]     addressRdSel;
reg    [2:0]     addressWrSel;


reg   [7:0]     hitRdDecoder;
reg   [7:0]     hitWrDecoder;
wire  [7:0]     hitRdAckDecoder;

reg   [31:0]    rdData;



//###################################################### 
//Logic
//###################################################### 


    always@(*)begin
        case(decOffset)
            5'h00:addressRdSel = rdAddr[0 +: 3];
            5'h01:addressRdSel = rdAddr[1 +: 3];
            5'h02:addressRdSel = rdAddr[2 +: 3];
            5'h03:addressRdSel = rdAddr[3 +: 3];
            5'h04:addressRdSel = rdAddr[4 +: 3];
            5'h05:addressRdSel = rdAddr[5 +: 3];
            5'h06:addressRdSel = rdAddr[6 +: 3];
            5'h07:addressRdSel = rdAddr[7 +: 3];
            5'h08:addressRdSel = rdAddr[8 +: 3];
            5'h09:addressRdSel = rdAddr[9 +: 3];
            5'h0a:addressRdSel = rdAddr[10+: 3];
            5'h0b:addressRdSel = rdAddr[11+: 3];
            5'h0c:addressRdSel = rdAddr[12+: 3];
            5'h0d:addressRdSel = rdAddr[13+: 3];
            5'h0e:addressRdSel = rdAddr[14+: 3];
            5'h0f:addressRdSel = rdAddr[15+: 3];
            5'h10:addressRdSel = rdAddr[16+: 3];
            5'h11:addressRdSel = rdAddr[17+: 3];
            5'h12:addressRdSel = rdAddr[18+: 3];
            5'h13:addressRdSel = rdAddr[19+: 3];
            5'h14:addressRdSel = rdAddr[20+: 3];
            5'h15:addressRdSel = rdAddr[21+: 3];
            5'h16:addressRdSel = rdAddr[22+: 3];
            5'h17:addressRdSel = rdAddr[23+: 3];
            5'h18:addressRdSel = rdAddr[24+: 3];
            5'h19:addressRdSel = rdAddr[25+: 3];
            5'h1a:addressRdSel = rdAddr[26+: 3];
            5'h1b:addressRdSel = rdAddr[27+: 3];
            5'h1c:addressRdSel = rdAddr[28+: 3];
            5'h1d:addressRdSel = rdAddr[29+: 3];
            default:addressRdSel = 3'd0;
        endcase
    end

    always@(*)begin
        case(addressRdSel)
            3'h0:hitRdDecoder =8'h1;
            3'h1:hitRdDecoder =8'h2;
            3'h2:hitRdDecoder =8'h4;
            3'h3:hitRdDecoder =8'h8;
            3'h4:hitRdDecoder =8'h10;
            3'h5:hitRdDecoder =8'h20;
            3'h6:hitRdDecoder =8'h40;
            3'h7:hitRdDecoder =8'h80;
            default:hitRdDecoder = 8'h0;
        endcase
    end
    assign            rd0 = rd && hitRdDecoder[0];
    assign            rd1 = rd && hitRdDecoder[1];
    assign            rd2 = rd && hitRdDecoder[2];
    assign            rd3 = rd && hitRdDecoder[3];
    assign            rd4 = rd && hitRdDecoder[4];
    assign            rd5 = rd && hitRdDecoder[5];
    assign            rd6 = rd && hitRdDecoder[6];
    assign            rd7 = rd && hitRdDecoder[7];
    assign            rdAddr0 = rdAddr;
    assign            rdAddr1 = rdAddr;
    assign            rdAddr2 = rdAddr;
    assign            rdAddr3 = rdAddr;
    assign            rdAddr4 = rdAddr;
    assign            rdAddr5 = rdAddr;
    assign            rdAddr6 = rdAddr;
    assign            rdAddr7 = rdAddr;

    assign            rdAck = rdAck0 || rdAck1 || rdAck2 || rdAck3 ||  
                                     rdAck4 || rdAck5 || rdAck6 || rdAck7 ; 
    assign            rdErr = rdErr0 || rdErr1 || rdErr2 || rdErr3 ||  
                                     rdErr4 || rdErr5 || rdErr6 || rdErr7 ; 
    assign            hitRdAckDecoder = {rdAck7,rdAck6,rdAck5,rdAck4,
                                         rdAck3,rdAck2,rdAck1,rdAck0};

    always@(*)begin
        case(hitRdAckDecoder)
            8'd0:rdData=rdData0;
            8'd1:rdData=rdData1;
            8'd2:rdData=rdData2;
            8'd3:rdData=rdData3;
            8'd4:rdData=rdData4;
            8'd5:rdData=rdData5;
            8'd6:rdData=rdData6;
            8'd7:rdData=rdData7;
            default:rdData=32'h0;
        endcase
    end

    always@(*)begin
        case(decOffset)
            5'h00:addressWrSel = wrAddr[0 +: 3];
            5'h01:addressWrSel = wrAddr[1 +: 3];
            5'h02:addressWrSel = wrAddr[2 +: 3];
            5'h03:addressWrSel = wrAddr[3 +: 3];
            5'h04:addressWrSel = wrAddr[4 +: 3];
            5'h05:addressWrSel = wrAddr[5 +: 3];
            5'h06:addressWrSel = wrAddr[6 +: 3];
            5'h07:addressWrSel = wrAddr[7 +: 3];
            5'h08:addressWrSel = wrAddr[8 +: 3];
            5'h09:addressWrSel = wrAddr[9 +: 3];
            5'h0a:addressWrSel = wrAddr[10+: 3];
            5'h0b:addressWrSel = wrAddr[11+: 3];
            5'h0c:addressWrSel = wrAddr[12+: 3];
            5'h0d:addressWrSel = wrAddr[13+: 3];
            5'h0e:addressWrSel = wrAddr[14+: 3];
            5'h0f:addressWrSel = wrAddr[15+: 3];
            5'h10:addressWrSel = wrAddr[16+: 3];
            5'h11:addressWrSel = wrAddr[17+: 3];
            5'h12:addressWrSel = wrAddr[18+: 3];
            5'h13:addressWrSel = wrAddr[19+: 3];
            5'h14:addressWrSel = wrAddr[20+: 3];
            5'h15:addressWrSel = wrAddr[21+: 3];
            5'h16:addressWrSel = wrAddr[22+: 3];
            5'h17:addressWrSel = wrAddr[23+: 3];
            5'h18:addressWrSel = wrAddr[24+: 3];
            5'h19:addressWrSel = wrAddr[25+: 3];
            5'h1a:addressWrSel = wrAddr[26+: 3];
            5'h1b:addressWrSel = wrAddr[27+: 3];
            5'h1c:addressWrSel = wrAddr[28+: 3];
            5'h1d:addressWrSel = wrAddr[29+: 3];
            default:addressWrSel = 3'd0;
        endcase
    end

    always@(*)begin
        case(addressWrSel)
            3'h0:hitWrDecoder =8'h1;
            3'h1:hitWrDecoder =8'h2;
            3'h2:hitWrDecoder =8'h4;
            3'h3:hitWrDecoder =8'h8;
            3'h4:hitWrDecoder =8'h10;
            3'h5:hitWrDecoder =8'h20;
            3'h6:hitWrDecoder =8'h40;
            3'h7:hitWrDecoder =8'h80;
            default:hitWrDecoder = 8'h0;
        endcase
    end
    assign            wr0 = wr && hitWrDecoder[0];
    assign            wr1 = wr && hitWrDecoder[1];
    assign            wr2 = wr && hitWrDecoder[2];
    assign            wr3 = wr && hitWrDecoder[3];
    assign            wr4 = wr && hitWrDecoder[4];
    assign            wr5 = wr && hitWrDecoder[5];
    assign            wr6 = wr && hitWrDecoder[6];
    assign            wr7 = wr && hitWrDecoder[7];
    assign            wrAddr0 = wrAddr;
    assign            wrAddr1 = wrAddr;
    assign            wrAddr2 = wrAddr;
    assign            wrAddr3 = wrAddr;
    assign            wrAddr4 = wrAddr;
    assign            wrAddr5 = wrAddr;
    assign            wrAddr6 = wrAddr;
    assign            wrAddr7 = wrAddr;
    assign            wrData0 = wrData;
    assign            wrData1 = wrData;
    assign            wrData2 = wrData;
    assign            wrData3 = wrData;
    assign            wrData4 = wrData;
    assign            wrData5 = wrData;
    assign            wrData6 = wrData;
    assign            wrData7 = wrData;

    assign            wrAck = wrAck0 || wrAck1 || wrAck2 || wrAck3 ||  
                                      wrAck4 || wrAck5 || wrAck6 || wrAck7 ; 
    assign            wrErr = wrErr0 || wrErr1 || wrErr2 || wrErr3 ||  
                                      wrErr4 || wrErr5 || wrErr6 || wrErr7 ; 


endmodule

