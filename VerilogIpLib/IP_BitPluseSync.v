// +FHDR----------------------------------------------------------------------------
// Device        : Xilinx
// Author        : fxdqe
// Email         : 1706260166@qq.com
// Created On    : 2025/10/30 23:56
// Last Modified : 2025/10/31 00:19
// File Name     : IP_BitSync.v
// Description   : this is used to transfer a Pluse from clockA to Clock B
// remeber in this the pluse must be inter some time
//         
// 
// ---------------------------------------------------------------------------------
// Modification History:
// Date         By              Version                 Change Description
// ---------------------------------------------------------------------------------
// 2025/10/30   fxdqe           1.0                     Original
// 2026/10/01   fxdqe           1.1                     Change the name to IP_BitPluseSync
// -FHDR----------------------------------------------------------------------------
module IP_BitPluseSync(/*autoarg*/
        //Inputs
        clockA, bitInA, clockB, 
        //Outputs
        bitOutB
);



//###################################################### 
//Interface
//###################################################### 

input  clockA;
input  resetA;
input  bitInA;
input  clockB;
input  resetB;
output bitOutB;







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

    assign inPluseAInt = bitInA ? !inPluseA : inPluseA; 

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
    assign bitOutB = getPluseInB; 



endmodule

