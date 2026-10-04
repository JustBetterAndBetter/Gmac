// +FHDR----------------------------------------------------------------------------
// Device        : Xilinx
// Author        : fxdqe
// Email         : 1706260166@qq.com
// Created On    : 2025/08/31 20:37
// Last Modified : 2025/08/31 20:57
// File Name     : IP_Sync.v
// Description   : double Sync One Bit need the clock Out Fre > clock In
//         
// 
// ---------------------------------------------------------------------------------
// Modification History:
// Date         By              Version                 Change Description
// ---------------------------------------------------------------------------------
// 2025/08/31   fxdqe           1.0                     Original
// -FHDR----------------------------------------------------------------------------
module IP_Sync(/*autoarg*/
        //Inputs
        clockIn, clockOut, reset, dataIn, 
        //Outputs
        dataOut
);


parameter  DATA_WIDTH=1;
//###################################################### 
//Interface
//###################################################### 

input    clockIn;
input    clockOut;

input    reset;

input   [DATA_WIDTH-1:0] dataIn;

output  [DATA_WIDTH-1:0] dataOut;





//###################################################### 
//Value
//###################################################### 


reg      [DATA_WIDTH-1:0]      dataInF1;
reg      [DATA_WIDTH-1:0]      dataInF2;





//###################################################### 
//Logic
//###################################################### 

    always@(posedge clockOut or negedge reset)begin
        if(!reset)begin
            dataInF1 <= {(DATA_WIDTH+1){1'd0}};
            dataInF2 <= {(DATA_WIDTH+1){1'd0}};
        end
        else begin
            dataInF1 <= dataIn;
            dataInF2 <= dataInF1;
        end
    end

    assign dataOut = dataInF2;


endmodule

