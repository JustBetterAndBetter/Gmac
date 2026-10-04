// +FHDR----------------------------------------------------------------------------
// Device        : Xilinx
// Author        : fxdqe
// Email         : 1706260166@qq.com
// Created On    : 2025/06/24 00:40
// Last Modified : 2025/11/17 22:03
// File Name     : IP_Fifo.v
// Description   : TODO change the inter value to parameter
//         
// 
// ---------------------------------------------------------------------------------
// Modification History:
// Date         By              Version                 Change Description
// ---------------------------------------------------------------------------------
// 2025/06/24   fxdqe           1.0                     Original
// -FHDR----------------------------------------------------------------------------
module IP_Fifo
(/*autoarg*/
        //Inputs
        clock, reset, fifoPush, fifoPushData, fifoPop, fifoAlFullThrd, 
        fifoAlEmptyThrd, fifoTxFifoThrd, 
        //Outputs
        fifoPopData, fifoDepth, fifoAlFull, fifoAlEmpty, fifoValid, 
        overRun, underRun, fifoEmpty, fifoFull
);

/*************************************************/
//inteface
/*************************************************/

parameter DATA_WIDTH=32;
parameter FIFO_DEPTH=16;
parameter ADDR_WIDTH= FIFO_DEPTH<=4   ? 2:
                      FIFO_DEPTH<=8   ? 3:
                      FIFO_DEPTH<=16  ? 4:
                      FIFO_DEPTH<=32  ? 5:
                      FIFO_DEPTH<=64  ? 6:
                      FIFO_DEPTH<=128 ? 7:
                      FIFO_DEPTH<=256 ? 8: 9;


input   clock;
input   reset;

input                   fifoPush;
input [DATA_WIDTH-1:0]  fifoPushData;


input                   fifoPop;
output[DATA_WIDTH-1:0]  fifoPopData;

output  [ADDR_WIDTH:0]  fifoDepth;


input   [ADDR_WIDTH:0]  fifoAlFullThrd;
input   [ADDR_WIDTH:0]  fifoAlEmptyThrd;
input   [ADDR_WIDTH:0]  fifoTxFifoThrd;

output         fifoAlFull;
output         fifoAlEmpty;
output         fifoValid;


output         overRun;
output         underRun;

output         fifoEmpty;
output         fifoFull;


/*************************************************/
//repulation
/*************************************************/
reg    [DATA_WIDTH-1:0]  fifoMem [(FIFO_DEPTH-1):0];

reg    [ADDR_WIDTH-1:0]   wrAddr;
wire   [ADDR_WIDTH-1:0]   wrAddrInt;
reg    [ADDR_WIDTH-1:0]   rdAddr;
wire   [ADDR_WIDTH-1:0]   rdAddrInt;



reg    [ADDR_WIDTH:0] fifoDepth;

wire         fifoEmpty;
wire         fifoFull;


//######################################################
//Logic
//######################################################

    genvar i;
    integer k;


    generate 
        for(i=0;i<FIFO_DEPTH;i=i+1)begin:MEMWR  
            always@(posedge clock or negedge reset)begin
                if(!reset)begin
                    fifoMem[i] <= {DATA_WIDTH{1'd0}};
                end
                else if(fifoPush && wrAddr==i)begin
                    fifoMem[i]<= fifoPushData;
                end
            end
        end
    endgenerate
    assign fifoPopData = fifoMem[rdAddr];

    assign wrAddrInt = fifoPush ? wrAddr + 4'd1 : wrAddr;
    always@(posedge clock or negedge reset)begin
        if(!reset)begin
            wrAddr<=4'd0;
        end
        else begin
            wrAddr<=wrAddrInt;
        end
    end


    assign rdAddrInt = fifoPop ? rdAddr + 4'd1 : rdAddr;
    always@(posedge clock or negedge reset)begin
        if(!reset)begin
            rdAddr<=4'd0;
        end
        else begin
            rdAddr<=rdAddrInt;
        end
    end

    always@(posedge clock or negedge reset)begin
        if(!reset)begin
            fifoDepth <=5'd0;
        end
        else if(fifoPush && fifoPop)begin
            fifoDepth <= fifoDepth;
        end
        else if(fifoPush)begin
            fifoDepth <= fifoDepth + 5'd1;
        end
        else if(fifoPop)begin
            fifoDepth <= fifoDepth - 5'd1;
        end
    end

    assign overRun = fifoPush && (fifoDepth==5'd16);
    assign underRun= fifoPop && (fifoDepth==5'd0);
    assign fifoEmpty = (fifoDepth==5'd0);
    assign fifoFull = (fifoDepth==5'd16);

    assign fifoAlFull  = fifoDepth>=fifoAlFullThrd ;
    assign fifoAlEmpty = fifoDepth<=fifoAlEmptyThrd ;
    assign fifoValid   = fifoDepth>=fifoTxFifoThrd && fifoDepth>5'd0;


//======================================================
//DebugCnt and some assert
//======================================================




endmodule

//
//
//本处介绍一些常用命令
//autoinst //自动例化  <S-F3>
//autoinstparam //自动例化参数 
//autoinstparam_value //自动例化参数,后为默认值<S-F4>
//当文件夹下的.f
// RtlTree 可以打开Rtl 路径
//autoarg  自动端口 <S-F2>
//nmap   <C-a-j>  i$display("%m ");
//nmap   <C-a-u>  i`uvm_info("TMP",$sformatf("",),UVM_HIGH);<Esc>
//nmap   <C-a-i>  i`uvm_info("INFO",$sformatf("",),UVM_HIGH);<Esc>
//nmap   <C-a-o>  i`uvm_fatal("",$sformatf("",));<Esc>
//nmap   <C-a-y>  i`uvm_warning("",$sformatf("",));<Esc>
//A& A*
//A* Apn
//A( Ap

