// +FHDR----------------------------------------------------------------------------
// Device        : Xilinx
// Author        : fxdqe
// Email         : 1706260166@qq.com
// Created On    : 2025/08/23 08:24
// File Name     : IP_RR.v
// Description   :
//         
// 
// ---------------------------------------------------------------------------------
// Modification History:
// Date         By              Version                 Change Description
// ---------------------------------------------------------------------------------
// 2025/08/23   fxdqe           1.0                     Original
// -FHDR----------------------------------------------------------------------------
module IP_RR(/*autoarg*/
        //Inputs
        clock, reset, hold, req, 
        //Outputs
        grant
);

parameter  REQ_WIDTH=32;

//###################################################### 
//Interface
//###################################################### 

input    clock;
input    reset;


input                       hold;

input    [REQ_WIDTH-1:0]  req;
output   [REQ_WIDTH-1:0]  grant;





//###################################################### 
//Value
//###################################################### 


wire [(2*REQ_WIDTH-1):0]   splicReq;


wire [(2*REQ_WIDTH-1):0]   caluateNum;
wire [(2*REQ_WIDTH-1):0]   showLowestBit;

wire [(REQ_WIDTH-1):0]     showLowestBitLo;
wire [(REQ_WIDTH-1):0]     showLowestBitHi;

wire [(REQ_WIDTH-1):0]     grantSel;


wire  [(REQ_WIDTH-1):0]    lastStateInt;
reg   [(REQ_WIDTH-1):0]    lastState;

//###################################################### 
//Logic
//###################################################### 


    assign splicReq =  {req,req};

    assign lastStateInt = |grant ? {grant[(REQ_WIDTH-2):0],grant[(REQ_WIDTH-1)]}: lastState;
    always@(posedge clock or negedge reset)begin
        if(!reset)begin
            lastState <= {{(REQ_WIDTH-1){1'd0}},1'd1};
        end
        else begin
            lastState <= lastStateInt;
        end
    end

    assign caluateNum = splicReq - {{REQ_WIDTH{1'd0}},lastState};

    assign showLowestBit = splicReq & (~caluateNum);
    assign showLowestBitLo = showLowestBit[(REQ_WIDTH-1):0];
    assign showLowestBitHi = showLowestBit[(REQ_WIDTH*2-1):REQ_WIDTH];

    //assign grantSel = |showLowestBitLo ? showLowestBitLo : 
    //                  |showLowestBitHi ? showLowestBitHi : {REQ_WIDTH{1'd0}};
    assign grantSel =  hold ? {REQ_WIDTH{1'd0}} : (showLowestBitLo | showLowestBitHi);

    assign grant = grantSel;

endmodule

