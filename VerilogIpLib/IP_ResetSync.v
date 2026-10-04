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
module IP_ResetSync(/*autoarg*/
        //Inputs
        resetIn, clockOut, 
        //Outputs
        resetOut
);


//###################################################### 
//Interface
//###################################################### 

input  resetIn;
input  clockOut;
output reg resetOut;

//###################################################### 
//Value
//###################################################### 


//###################################################### 
//Logic
//###################################################### 

    always@(posedge clockOut or negedge resetIn)begin
        if(!resetIn)begin
            resetOut <= 1'd0;
        end
        else begin
            resetOut <= 1'd1;
        end
    end

endmodule