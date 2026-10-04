// +FHDR----------------------------------------------------------------------------
// Device        : Xilinx
// Author        : fxdqe
// Email         : 1706260166@qq.com
// Created On    : 2025/10/31 00:19
// Last Modified : 2025/10/31 00:21
// File Name     : IP_DataSync.v
// Description   :
//         
// 
// ---------------------------------------------------------------------------------
// Modification History:
// Date         By              Version                 Change Description
// ---------------------------------------------------------------------------------
// 2025/10/31   fxdqe           1.0                     Original
// -FHDR----------------------------------------------------------------------------
module IP_DataGraySync(/*autoarg*/
        //Inputs
        clockA, dataA, clockB,
        //Outputs
        dataB
);

parameter DATAWIDTH = 16;
//###################################################### 
//Interface
//###################################################### 

input  clockA;
input  [DATAWIDTH-1:0] dataA;
input  clockB;
output [DATAWIDTH-1:0] dataB;

//###################################################### 
//Value
//###################################################### 

wire [DATAWIDTH-1:0] dataGrayA;
reg [DATAWIDTH-1:0] dataGrayAF1;
reg [DATAWIDTH-1:0] dataGrayAF2;
wire [DATAWIDTH-1:0] dataDeGrayB;

//###################################################### 
//Logic
//###################################################### 

    assign dataGrayA = dataA ^ {1'd0,dataA[DATAWIDTH-1:1]};
    always@(posedge clockA )begin
        dataGrayAF1 <= dataGrayA;
        dataGrayAF2 <= dataGrayAF1;
    end

    generate  
        genvar i;
        for(i=0;i<ADDR_WIDTH;i=i+1)begin:GRAYLIFT
            assign dataDeGrayB[i] = dataGrayAF2[i] ^ dataGrayAF1[i+1];
        end
    endgenerate

    assign dataB = dataDeGrayB;

endmodule