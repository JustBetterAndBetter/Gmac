// +FHDR----------------------------------------------------------------------------
// Device        : Xilinx
// Author        : fxdqe
// Email         : 1706260166@qq.com
// Created On    : 2025/10/24 23:48
// Last Modified : 2025/12/28 20:40
// File Name     : AxiLite2RegBus.v
// Description   : this module is used to transfer the axilite to Regbus
//         
// 
// ---------------------------------------------------------------------------------
// Modification History:
// Date         By              Version                 Change Description
// ---------------------------------------------------------------------------------
// 2025/10/24   fxdqe           1.0                     Original
// 2026/10/01   fxdqe           1.1                     FIFO 分域 resetIn/resetOut
// 2026/10/01   fxdqe           1.2                     分域复位 resetAxi/resetRegBus
// -FHDR----------------------------------------------------------------------------
module IP_AxiLite2RegBus(/*autoarg*/
        //Inputs
        s_axi_aclk, clockRegBus, resetAxi, resetRegBus, s_axi_awaddr, s_axi_awvalid, 
        s_axi_wdata, s_axi_wvalid, s_axi_bready, s_axi_araddr, 
        s_axi_arvalid, s_axi_rready, wrAck, 
        wrErr, rdAck, rdErr, 
        rdData, 
        //Outputs
        s_axi_awready, s_axi_wready, s_axi_bresp, s_axi_bvalid, 
        s_axi_arready, s_axi_rdata, s_axi_rresp, s_axi_rvalid, 
        wr, wrAddr, wrData, rd, 
        rdAddr
);





//###################################################### 
//Interface
//###################################################### 

    // Clock and Reset
    input                   s_axi_aclk;
    input                   clockRegBus;
    input                   resetAxi;
    input                   resetRegBus;
    
    // AXI Lite Write Address Channel
    input  [31:0]           s_axi_awaddr;
    //input  [2:0]            s_axi_awprot;
    input                   s_axi_awvalid;
    output                  s_axi_awready;
    
    // AXI Lite Write Data Channel
    input  [31:0]           s_axi_wdata;
    //input  [3:0]            s_axi_wstrb;
    input                   s_axi_wvalid;
    output                  s_axi_wready;
    
    // AXI Lite Write Response Channel
    output [1:0]            s_axi_bresp;
    output                  s_axi_bvalid;
    input                   s_axi_bready;
    
    // AXI Lite Read Address Channel
    input  [31:0]           s_axi_araddr;
    //input  [2:0]            s_axi_arprot;
    input                   s_axi_arvalid;
    output                  s_axi_arready;
    
    // AXI Lite Read Data Channel
    output [31:0]           s_axi_rdata;
    output [1:0]            s_axi_rresp;
    output                  s_axi_rvalid;
    input                   s_axi_rready;
    
    // Register Bus Interface
    output                  wr;
    output [31:0]           wrAddr;
    output [31:0]           wrData;
    input                   wrAck;
    input                   wrErr;
    
    output                  rd;
    output [31:0]           rdAddr;
    input                   rdAck;
    input                   rdErr;
    input  [31:0]           rdData;


//###################################################### 
//Value
//###################################################### 

    //Axi Tunle Fifo
    wire             writeAddrTunleFifoPush;      
    wire  [31:0]     writeAddrTunleFifoPushData;      
    wire             writeAddrTunleFifoPop;      
    wire  [31:0]     writeAddrTunleFifoPopData;      
    wire             writeAddrTunleFifoEmpty;      
    wire             writeAddrTunleFifoFull;      
    wire             writeAddrTunleFifoValid;      

    wire             writeDataTunleFifoPush;      
    wire  [31:0]     writeDataTunleFifoPushData;      
    wire             writeDataTunleFifoPop;      
    wire  [31:0]     writeDataTunleFifoPopData;      
    wire             writeDataTunleFifoEmpty;      
    wire             writeDataTunleFifoFull;      
    wire             writeDataTunleFifoValid;      

    wire             writeAckTunleFifoPush;      
    wire             writeAckTunleFifoPushData;      
    wire             writeAckTunleFifoPop;      
    wire             writeAckTunleFifoPopData;      
    wire             writeAckTunleFifoEmpty;      
    wire             writeAckTunleFifoFull;      
    wire             writeAckTunleFifoValid;      

    wire             readTunleFifoPush;      
    wire  [31:0]     readTunleFifoPushData;      
    wire             readTunleFifoPop;      
    wire  [31:0]     readTunleFifoPopData;      
    wire             readTunleFifoEmpty;      
    wire             readTunleFifoFull;      
    wire             readTunleFifoValid;      

    wire             readDataTunleFifoPush;      
    wire  [32:0]     readDataTunleFifoPushData;      
    wire             readDataTunleFifoPop;      
    wire  [32:0]     readDataTunleFifoPopData;      
    wire             readDataTunleFifoEmpty;      
    wire             readDataTunleFifoFull;      
    wire             readDataTunleFifoValid;      

    //write Ctrl
    wire             matchWrWatchTime;
    reg    [7:0]     writeTimeCnt;
    wire   [7:0]     writeTimeCntInt;
    wire             endWrite;
    wire             startWrite;
    wire             inWriteInt;
    reg              inWrite;

    //read Ctrl
    wire             matchRdWatchTime;
    reg    [7:0]     readTimeCnt;
    wire   [7:0]     readTimeCntInt;
    wire             endRead;
    wire             startRead;
    wire             inReadInt;
    reg              inRead;

//###################################################### 
//Logic
//###################################################### 

    assign writeAddrTunleFifoPush     = s_axi_awvalid&&s_axi_awready;
    assign writeAddrTunleFifoPushData = s_axi_awaddr;
    assign s_axi_awready              = !writeAddrTunleFifoFull;
    IP_AsyncFifo #(32,8)uwriteAddrTunle (
        .clockIn          (s_axi_aclk),
        .clockOut         (clockRegBus),
        .resetIn          (resetAxi),
        .resetOut         (resetRegBus),
        .fifoPush         (writeAddrTunleFifoPush    ),
        .fifoPushData     (writeAddrTunleFifoPushData),
        .fifoPop          (writeAddrTunleFifoPop     ),
        .fifoPopData      (writeAddrTunleFifoPopData ),
        .fifoAlFullThrd   (4'd6),
        .fifoAlEmptyThrd  (4'd0),
        .fifoTxFifoThrd   (4'd0),
        .fifoEmpty        (writeAddrTunleFifoEmpty),
        .overRun          (),
        .underRun         (),
        .fifoAlFull       (),
        .fifoAlEmpty      (),
        .fifoValid        (writeAddrTunleFifoValid),
        .fifoDepth        (),
        .fifoFull         (writeAddrTunleFifoFull)
    );
    assign writeAddrTunleFifoPop = !inWrite&&writeAddrTunleFifoValid&&writeDataTunleFifoValid&&!writeAckTunleFifoFull;
    assign wrAddr        = writeAddrTunleFifoPopData;
    assign wr             = writeAddrTunleFifoPop;

    assign writeDataTunleFifoPush     = s_axi_wvalid&&s_axi_wready;
    assign writeDataTunleFifoPushData = s_axi_wdata;
    assign s_axi_wready              = !writeDataTunleFifoFull;
    IP_AsyncFifo #(32,8)uwriteDataTunle (
        .clockIn          (s_axi_aclk),
        .clockOut         (clockRegBus),
        .resetIn          (resetAxi),
        .resetOut         (resetRegBus),
        .fifoPush         (writeDataTunleFifoPush    ),
        .fifoPushData     (writeDataTunleFifoPushData),
        .fifoPop          (writeDataTunleFifoPop     ),
        .fifoPopData      (writeDataTunleFifoPopData ),
        .fifoAlFullThrd   (4'd6),
        .fifoAlEmptyThrd  (4'd0),
        .fifoTxFifoThrd   (4'd0),
        .fifoEmpty        (writeDataTunleFifoEmpty),
        .overRun          (),
        .underRun         (),
        .fifoAlFull       (writeDataTunleFifoValid),
        .fifoAlEmpty      (),
        .fifoValid        (),
        .fifoDepth        (),
        .fifoFull         (writeDataTunleFifoFull)
    );
    assign writeDataTunleFifoPop = !inWrite&&writeAddrTunleFifoValid&&writeDataTunleFifoValid&&!writeAckTunleFifoFull;
    assign wrData        = writeDataTunleFifoPopData;


    assign writeAckTunleFifoPush     = inWrite&&(wrAck || matchWrWatchTime);
    assign writeAckTunleFifoPushData = wrErr||matchWrWatchTime;
    IP_AsyncFifo #(1,8)uwriteAckTunle (
        .clockIn          (clockRegBus),
        .clockOut         (s_axi_aclk),
        .resetIn          (resetRegBus),
        .resetOut         (resetAxi),
        .fifoPush         (writeAckTunleFifoPush    ),
        .fifoPushData     (writeAckTunleFifoPushData),
        .fifoPop          (writeAckTunleFifoPop     ),
        .fifoPopData      (writeAckTunleFifoPopData ),
        .fifoAlFullThrd   (4'd6),
        .fifoAlEmptyThrd  (4'd0),
        .fifoTxFifoThrd   (4'd0),
        .fifoEmpty        (writeAckTunleFifoEmpty),
        .overRun          (),
        .underRun         (),
        .fifoAlFull       (writeAckTunleFifoValid),
        .fifoAlEmpty      (),
        .fifoValid        (),
        .fifoDepth        (),
        .fifoFull         (writeAckTunleFifoFull)
    );
    assign s_axi_bvalid = writeAckTunleFifoValid;
    assign s_axi_bresp  =  writeAckTunleFifoPopData ? 2'd1 : 2'd0;
    assign writeAckTunleFifoPop = s_axi_bvalid&&s_axi_bready;

    assign readTunleFifoPush     = s_axi_arvalid&&s_axi_arready;
    assign readTunleFifoPushData = s_axi_araddr;
    assign s_axi_arready = !readTunleFifoFull;
    IP_AsyncFifo #(32,8)ureadTunle (
        .clockIn          (s_axi_aclk),
        .clockOut         (clockRegBus),
        .resetIn          (resetAxi),
        .resetOut         (resetRegBus),
        .fifoPush         (readTunleFifoPush    ),
        .fifoPushData     (readTunleFifoPushData),
        .fifoPop          (readTunleFifoPop     ),
        .fifoPopData      (readTunleFifoPopData ),
        .fifoAlFullThrd   (4'd6),
        .fifoAlEmptyThrd  (4'd0),
        .fifoTxFifoThrd   (4'd0),
        .fifoEmpty        (readTunleFifoEmpty),
        .overRun          (),
        .underRun         (),
        .fifoAlFull       (readTunleFifoValid),
        .fifoAlEmpty      (),
        .fifoValid        (),
        .fifoDepth        (),
        .fifoFull         (readTunleFifoFull)
    );
    assign readTunleFifoPop = !inRead && readTunleFifoValid && !readDataTunleFifoFull;

    assign rd       = readTunleFifoPop;
    assign rdAddr = readTunleFifoPopData;

    assign readDataTunleFifoPush     = inRead&&(rdAck || matchRdWatchTime);
    assign readDataTunleFifoPushData = matchRdWatchTime ? {1'd1,32'ha5a5a5a5}: {rdErr,rdData};
    IP_AsyncFifo #(33,8)ureadDataTunle (
        .clockIn          (clockRegBus),
        .clockOut         (s_axi_aclk),
        .resetIn          (resetRegBus),
        .resetOut         (resetAxi),
        .fifoPush         (readDataTunleFifoPush    ),
        .fifoPushData     (readDataTunleFifoPushData),
        .fifoPop          (readDataTunleFifoPop     ),
        .fifoPopData      (readDataTunleFifoPopData ),
        .fifoAlFullThrd   (4'd6),
        .fifoAlEmptyThrd  (4'd0),
        .fifoTxFifoThrd   (4'd0),
        .fifoEmpty        (readDataTunleFifoEmpty),
        .overRun          (),
        .underRun         (),
        .fifoAlFull       (readDataTunleFifoValid),
        .fifoAlEmpty      (),
        .fifoValid        (),
        .fifoDepth        (),
        .fifoFull         (readDataTunleFifoFull)
    );

    assign s_axi_rvalid=readDataTunleFifoValid;
    assign s_axi_rdata= readDataTunleFifoPopData[31:0];
    assign s_axi_rresp = readDataTunleFifoPopData[32] ? 2'd1 : 2'd0;
    assign readDataTunleFifoPop = s_axi_rready&&s_axi_rvalid;

    //write Ctrl
    assign startWrite = writeDataTunleFifoValid&&!writeAddrTunleFifoValid&&!inWrite&&!writeAckTunleFifoFull;
    assign endWrite   = (wrAck || matchWrWatchTime)&&inWrite;
    assign matchWrWatchTime = writeTimeCnt==8'd100 && !wrAck;
    assign writeTimeCntInt = startWrite ? 8'd0:
                             inWrite ? writeTimeCnt+8'd1 : writeTimeCnt;
    assign inWriteInt = (startWrite || inWrite)&&!endWrite;
    always@(posedge clockRegBus) begin
        writeTimeCnt <= writeTimeCntInt;
    end

    //read Ctrl
    assign startRead = readTunleFifoValid&&!inRead;
    assign endRead   = (rdAck || matchRdWatchTime)&&inRead;
    assign matchRdWatchTime = readTimeCnt==8'd100 && !rdAck;
    assign readTimeCntInt = startRead ? 8'd0:
                             inRead ? readTimeCnt+8'd1 : readTimeCnt;
    assign inReadInt = (startRead || inRead)&&!endRead ;
    always@(posedge clockRegBus) begin
        readTimeCnt <= readTimeCntInt;
    end

    always@(posedge clockRegBus or negedge resetRegBus) begin
        if(!resetRegBus)begin
            inRead <= 1'd0;
        end
        else begin
            inRead <= inReadInt;
        end
    end
    always@(posedge clockRegBus or negedge resetRegBus) begin
        if(!resetRegBus)begin
            inWrite <= 1'd0;
        end
        else begin
            inWrite <= inWriteInt;
        end
    end


endmodule
