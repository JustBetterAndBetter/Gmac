// +FHDR----------------------------------------------------------------------------
// Device        : Xilinx
// Author        : fxdqe
// Email         : 1706260166@qq.com
// Created On    : 2026/09/18 21:00
// File Name     : GmacRst.v
// Description   : 寄存器侧软复位模块。外部 rstN 只复位本模块与 GmacReg；
//                 本模块把 POR 与 softRstN（低有效）拉长后生成 rstNCore，再分给数据通路。
//                 rstNCore 相对 clkMgmt 为异步置位、同步释放。
// -FHDR----------------------------------------------------------------------------

module GmacRst(/*autoarg*/
        //Inputs
        clkMgmt, rstN, softRstN,
        //Outputs
        rstNCore
);

//######################################################
//Interface
//######################################################

localparam [4:0] STRETCH_MAX  = 5'd16;
localparam [4:0] STRETCH_ZERO = 5'd0;
localparam [4:0] STRETCH_ONE  = 5'd1;

input                   clkMgmt;
input                   rstN;
input                   softRstN;
output                  rstNCore;

//######################################################
//Value
//######################################################

reg  [4:0]              stretchCnt;

//######################################################
//Logic
//######################################################

    always@(posedge clkMgmt or negedge rstN) begin
        if (!rstN)
            stretchCnt <= STRETCH_MAX;
        else if (!softRstN)
            stretchCnt <= STRETCH_MAX;
        else if (stretchCnt != STRETCH_ZERO)
            stretchCnt <= stretchCnt - STRETCH_ONE;
    end

    // rstN 拉低时组合拉低 rstNCore；softRstN 为低时重新拉长。释放后等 stretchCnt 计完再抬高。
    assign rstNCore = rstN & (stretchCnt == STRETCH_ZERO);

endmodule
