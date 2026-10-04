// +FHDR----------------------------------------------------------------------------
// Device        : Xilinx
// Author        : fxdqe
// Email         : 1706260166@qq.com
// Created On    : 2026/10/01 18:50
// File Name     : IP_DulResetSync.v
// Description   : 双钟复位。resetInSync/resetOutSync 为两侧已同步释放的低有效复位；
//                 resetInDouleSync/ressetOutDouleSync 要等对端也释放后才抬高，
//                 避免单边跑指针。
// ---------------------------------------------------------------------------------
// Modification History:
// Date         By              Version                 Change Description
// ---------------------------------------------------------------------------------
// 2026/10/01   fxdqe           1.0                     Original
// 2026/10/01   fxdqe           1.1                     去掉 force 保持
// 2026/10/01   fxdqe           1.2                     同步复位改为端口，输出改名
// -FHDR----------------------------------------------------------------------------
module IP_DulResetSync(/*autoarg*/
        //Inputs
        clockIn, clockOut, resetInSync, resetOutSync,
        //Outputs
        resetInDouleSync, ressetOutDouleSync
);

//######################################################
//Interface
//######################################################

input                   clockIn;
input                   clockOut;
input                   resetInSync;
input                   resetOutSync;
output                  resetInDouleSync;
output                  ressetOutDouleSync;

//######################################################
//Value
//######################################################

wire                    wantRstIn;
wire                    wantRstOut;
wire                    wantRstOutInIn;
wire                    wantRstInInOut;

//######################################################
//Logic
//######################################################

    assign wantRstIn  = ~resetInSync;
    assign wantRstOut = ~resetOutSync;

    // 对端复位请求同步到本侧时钟；同步器复位用本侧（输出）时钟域复位。
    IP_Sync #(.DATA_WIDTH(1)) uWantOutInIn (
        .clockIn  (clockOut),
        .clockOut (clockIn),
        .reset    (resetInSync),
        .dataIn   (wantRstOut),
        .dataOut  (wantRstOutInIn)
    );

    IP_Sync #(.DATA_WIDTH(1)) uWantInInOut (
        .clockIn  (clockIn),
        .clockOut (clockOut),
        .reset    (resetOutSync),
        .dataIn   (wantRstIn),
        .dataOut  (wantRstInInOut)
    );

    assign resetInDouleSync   = ~(wantRstIn  | wantRstOutInIn);
    assign ressetOutDouleSync = ~(wantRstOut | wantRstInInOut);

endmodule
