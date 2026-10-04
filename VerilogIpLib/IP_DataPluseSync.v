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
// 2026/10/01   fxdqe           1.1                     Change the name to IP_DataPluseSync
// -FHDR----------------------------------------------------------------------------
module IP_DataPluseSync(/*autoarg*/
        //Inputs
        clockA, resetA, validA, dataA, clockB, resetB, validB, dataB,
        //Outputs
        validB, dataB
);

parameter DATAWIDTH = 16;

//###################################################### 
//Interface
//###################################################### 
input  clockA;
input  resetA;

input  validA;
input  [(DATAWIDTH-1):0] dataA;

input  clockB;
input  resetB;

input  validB;
input  [(DATAWIDTH-1):0] dataB;








//###################################################### 
//Value
//###################################################### 

wire   inPluseAInt;     
reg    inPluseA;     
reg    inPluseAF1;     
reg    inPluseAF2;     
wire   getPluseInB;     




//###################################################### 
//Logic
//###################################################### 


    assign inPluseAInt = validA ? !inPluseA : inPluseA; 

    always@(posedge clockA or negedge resetA)begin
        if(!resetA)begin
            inPluseA <= 1'd0;
        end
        else begin
            inPluseA <= inPluseAInt;
        end
    end
    always@(posedge clockB or negedge resetB)begin
        if(!resetA)begin
            inPluseAF1 <= 1'd0;
            inPluseAF2 <= 1'd0;
        end
        else begin
            inPluseAF1 <= inPluseA;
            inPluseAF2 <= inPluseAF1;
        end
    end

    assign getPluseInB = inPluseAF2 & !inPluseAF1
    assign validB = getPluseInB; 



endmodule

