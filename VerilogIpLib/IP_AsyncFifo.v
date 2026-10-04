// +FHDR----------------------------------------------------------------------------
// Device        : Xilinx
// Author        : fxdqe
// Email         : 1706260166@qq.com
// Created On    : 2025/08/30 23:23
// File Name     : IP_AsyncFifo.v
// Description   :for the gray data transfer ,the empty maybe not realy empty
// the full is not full.
// resetIn/resetOut 须已同步到各自时钟：分域复位在 FIFO 外，同一时钟复位多处共用。
// 内部 IP_DulResetSync 等到两侧都释放后才释放本侧指针，避免单边跑指针。
// 
// ---------------------------------------------------------------------------------
// Modification History:
// Date         By              Version                 Change Description
// ---------------------------------------------------------------------------------
// 2025/08/30   fxdqe           1.0                     Original
// 2026/10/01   fxdqe           1.1                     内部例化 IP_DulResetSync
// -FHDR----------------------------------------------------------------------------
module IP_AsyncFifo(/*autoarg*/
        //Inputs
        clockIn, clockOut, fifoPush, fifoPushData, fifoPop, 
        fifoAlFullThrd, fifoAlEmptyThrd, fifoTxFifoThrd, resetIn, resetOut,
        //Outputs
        fifoPopData, fifoDepth, fifoAlFull, fifoAlEmpty, fifoValid, 
        overRun, underRun, fifoEmpty, fifoFull
);




//###################################################### 
//Interface
//###################################################### 

parameter DATA_WIDTH=32;
parameter FIFO_DEPTH=16;
parameter ADDR_WIDTH= FIFO_DEPTH<=4   ? 2:
                      FIFO_DEPTH<=8   ? 3:
                      FIFO_DEPTH<=16  ? 4:
                      FIFO_DEPTH<=32  ? 5:
                      FIFO_DEPTH<=64  ? 6:
                      FIFO_DEPTH<=128 ? 7:
                      FIFO_DEPTH<=256 ? 8: 9;

input                   clockIn;
input                   clockOut;
input                   resetIn;
input                   resetOut;

input                   fifoPush;
input [DATA_WIDTH-1:0]  fifoPushData;


input                   fifoPop;
output[DATA_WIDTH-1:0]  fifoPopData;

output  [ADDR_WIDTH:0]  fifoDepth;


input   [ADDR_WIDTH:0]  fifoAlFullThrd;
input   [ADDR_WIDTH:0]  fifoAlEmptyThrd;
input   [ADDR_WIDTH:0]  fifoTxFifoThrd;

output                  fifoAlFull;
output                  fifoAlEmpty;
output                  fifoValid;


output                  overRun;
output                  underRun;

output                  fifoEmpty;
output                  fifoFull;

//###################################################### 
//Value
//###################################################### 


reg      [DATA_WIDTH-1:0] storeData [(FIFO_DEPTH-1):0];
wire     [ADDR_WIDTH:0]   writeAddrInt;
reg      [ADDR_WIDTH:0]   writeAddr;
wire     [ADDR_WIDTH:0]   readAddrInt;
reg      [ADDR_WIDTH:0]   readAddr;

reg      [DATA_WIDTH-1:0] fifoPopDataGet;

wire     [ADDR_WIDTH:0]   writeAddrGray;
reg      [ADDR_WIDTH:0]   writeAddrGrayF1;
reg      [ADDR_WIDTH:0]   writeAddrGrayF2;
wire     [ADDR_WIDTH:0]   writeAddrGrayLift;

wire     [ADDR_WIDTH:0]   readAddrGray;
reg      [ADDR_WIDTH:0]   readAddrGrayF1;
reg      [ADDR_WIDTH:0]   readAddrGrayF2;
wire     [ADDR_WIDTH:0]   readAddrGrayLift;

wire                      pushSync;

wire     [ADDR_WIDTH:0]   storeCntInt;
reg      [ADDR_WIDTH:0]   storeCnt;

wire     [ADDR_WIDTH:0]   storeCntReadInt;
reg      [ADDR_WIDTH:0]   storeCntRead;

wire                      resetInDouleSync;
wire                      ressetOutDouleSync;


//###################################################### 
//Logic
//###################################################### 

    // 端口复位已在外部按时钟同步。这里只做双钟释放握手。
    IP_DulResetSync uDulRst (
        .clockIn            (clockIn),
        .clockOut           (clockOut),
        .resetInSync        (resetIn),
        .resetOutSync       (resetOut),
        .resetInDouleSync   (resetInDouleSync),
        .ressetOutDouleSync (ressetOutDouleSync)
    );

    assign writeAddrInt = fifoPush ? writeAddr + {{(ADDR_WIDTH){1'd0}},1'd1}: writeAddr; 
    always@(posedge clockIn or negedge resetInDouleSync)begin
        if(!resetInDouleSync)begin
            writeAddr <= {(ADDR_WIDTH+1){1'd0}};
        end
        else begin
            writeAddr <= writeAddrInt;
        end
    end

    assign readAddrInt = fifoPop ? readAddr + {{(ADDR_WIDTH){1'd0}},1'd1}: readAddr;
    always@(posedge clockOut or negedge ressetOutDouleSync)begin
        if(!ressetOutDouleSync)begin
            readAddr <= {(ADDR_WIDTH+1){1'd0}};
        end
        else begin
            readAddr <= readAddrInt;
        end
    end

    assign writeAddrGray = writeAddrInt ^ {1'd0,writeAddrInt[ADDR_WIDTH:1]};
    always@(posedge clockOut or negedge ressetOutDouleSync)begin
        if(!ressetOutDouleSync)begin
            writeAddrGrayF1 <= {(ADDR_WIDTH+1){1'd0}};
            writeAddrGrayF2 <= {(ADDR_WIDTH+1){1'd0}};
        end
        else begin
            writeAddrGrayF1 <= writeAddrGray;
            writeAddrGrayF2 <= writeAddrGrayF1;
        end
    end

    assign readAddrGray = readAddrInt ^ {1'd0,readAddrInt[ADDR_WIDTH:1]};
    always@(posedge clockIn or negedge resetInDouleSync)begin
        if(!resetInDouleSync)begin
            readAddrGrayF1 <= {(ADDR_WIDTH+1){1'd0}};
            readAddrGrayF2 <= {(ADDR_WIDTH+1){1'd0}};
        end
        else begin
            readAddrGrayF1 <= readAddrGray;
            readAddrGrayF2 <= readAddrGrayF1;
        end
    end

    generate  
        genvar i;
        for(i=0;i<ADDR_WIDTH;i=i+1)begin:GRAYLIFT
            assign writeAddrGrayLift[i] = writeAddrGrayLift[i+1] ^ writeAddrGrayF2[i];
            assign readAddrGrayLift[i]  = readAddrGrayLift[i+1] ^ readAddrGrayF2[i];
        end
    endgenerate
    assign writeAddrGrayLift[ADDR_WIDTH] = writeAddrGrayF2[ADDR_WIDTH];
    assign readAddrGrayLift[ADDR_WIDTH]  = readAddrGrayF2[ADDR_WIDTH];

    assign storeCntInt = (writeAddrInt>=readAddrGrayLift) ? writeAddrInt - readAddrGrayLift: 
                         {1'd1,writeAddrInt[ADDR_WIDTH-1:0]}-{1'd0,readAddrGrayLift[ADDR_WIDTH-1:0]};
    always@(posedge clockIn or negedge resetInDouleSync)begin
        if(!resetInDouleSync)begin
            storeCnt <= {(ADDR_WIDTH){1'd0}};
        end
        else begin
            storeCnt <= storeCntInt;
        end
    end

    assign storeCntReadInt = (writeAddrGrayLift>=readAddrInt) ? writeAddrGrayLift - readAddrInt: 
                         {1'd1,writeAddrGrayLift[ADDR_WIDTH-1:0]}-{1'd0,readAddrInt[ADDR_WIDTH-1:0]};
    always@(posedge clockOut or negedge ressetOutDouleSync)begin
        if(!ressetOutDouleSync)begin
            storeCntRead <= {(ADDR_WIDTH){1'd0}};
        end
        else begin
            storeCntRead <= storeCntReadInt;
        end
    end

    //Store and Rd Data

    generate
        integer k;
        always@(posedge clockIn or negedge resetInDouleSync)begin
            if(!resetInDouleSync)begin
                for(k=0;k<FIFO_DEPTH;k=k+1)begin:RESET
                    storeData[k] <= {(DATA_WIDTH){1'd0}};
                end
            end
            else if(fifoPush) begin
                storeData[writeAddr] <= fifoPushData;
            end
        end
    endgenerate

    always@(posedge clockOut or negedge ressetOutDouleSync)begin
        if(!ressetOutDouleSync)begin
            fifoPopDataGet    <= {(DATA_WIDTH){1'd0}};
        end
        else  begin
            fifoPopDataGet <= storeData[readAddrInt[(ADDR_WIDTH-1):0]];
        end
    end


    assign fifoPopData = fifoPopDataGet;

    assign fifoAlFull  = storeCnt>=fifoAlFullThrd;
    assign fifoAlEmpty = storeCnt<fifoAlEmptyThrd;
    assign fifoValid   = storeCntRead>fifoTxFifoThrd;

    assign fifoFull  = writeAddr[(ADDR_WIDTH-1):0]==readAddrGrayLift[(ADDR_WIDTH-1):0] && (writeAddr[ADDR_WIDTH]^readAddrGrayLift[ADDR_WIDTH]) ;
    assign fifoEmpty = readAddr[ADDR_WIDTH:0]==writeAddrGrayLift[ADDR_WIDTH:0];

    assign fifoDepth = storeCntRead;

    assign  overRun  = fifoFull && fifoPush;
    assign  underRun = fifoEmpty && fifoPop;

endmodule
