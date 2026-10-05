// +FHDR----------------------------------------------------------------------------
// Device        : Xilinx
// Author        : fxdqe
// Email         : 1706260166@qq.com
// Created On    : 2026/09/16 21:40
// File Name     : Gmac8b10bEnc.v
// Description   : Clause 36 8B/10B。codeGroup[0]=a 先出。rd 0=负 1=正。
//                 6b/4b 只存主列。disp6：主列有 4 个 1。
//                 rd6 = rd ^ disp6。D.7 主列虽是 3 个 1，rd 为正时仍取反。
//                 4b 的 y=0/3/4/7 取反。y=0/4/7 结束极性翻转；
//                 y=3 的 0011/1100 结束极性等于 rd6。
//                 D.x.7 对 11/13/14/17/18/20 用 A7，不改变结束极性。
//                 K 码另表。kFlip 是 RD- 列的结束极性，RD+ 整组取反。
// ---------------------------------------------------------------------------------
// Modification History:
// Date         By              Version                 Change Description
// ---------------------------------------------------------------------------------
// 2026/09/16   fxdqe           1.1                     Sub-block RD, A7
// 2026/10/01   fxdqe           1.2                     单模块文件拆分
// 2026/10/04   fxdqe           1.3                     极性由码表属性得出，去掉数 1
// -FHDR----------------------------------------------------------------------------

`include "GmacIf.vh"

module Gmac8b10bEnc(/*autoarg*/
        //Inputs
        octet, isK, rd,
        //Outputs
        codeGroup, rdNext, invalid
);

//######################################################
//Interface
//######################################################

input  [7:0]            octet;
input                   isK;
input                   rd;
output [9:0]            codeGroup;
output                  rdNext;
output                  invalid;

//######################################################
//Value
//######################################################

localparam [7:0] K28_5 = 8'hBC;
localparam [7:0] K27_7 = 8'hFB;
localparam [7:0] K29_7 = 8'hFD;
localparam [7:0] K23_7 = 8'hF7;
localparam [7:0] K30_7 = 8'hFE;

wire [4:0]              x;
wire [2:0]              y;
reg  [5:0]              base6;
reg                     disp6;
wire                    flip6;
wire [5:0]              code6;
wire                    rd6;
wire                    useA7;
reg  [3:0]              base4;
wire                    flip4;
wire                    rdFlip4;
wire [3:0]              code4;
wire [9:0]              codeGroupD;
wire                    rdNextD;
reg  [9:0]              kBase;
reg                     kFlip;
reg                     kOk;
wire [9:0]              codeGroupK;
wire                    rdNextK;

//######################################################
//Logic
//######################################################

    assign x = octet[4:0];
    assign y = octet[7:5];

//======================================================
// 6b 主列。abcdei[0]=a。disp6 表示主列有 4 个 1。
//======================================================

    always @(*) begin
        case (x)
            5'd0  : begin base6 = 6'b111001; disp6 = 1'b1; end
            5'd1  : begin base6 = 6'b101110; disp6 = 1'b1; end
            5'd2  : begin base6 = 6'b101101; disp6 = 1'b1; end
            5'd3  : begin base6 = 6'b100011; disp6 = 1'b0; end
            5'd4  : begin base6 = 6'b101011; disp6 = 1'b1; end
            5'd5  : begin base6 = 6'b100101; disp6 = 1'b0; end
            5'd6  : begin base6 = 6'b100110; disp6 = 1'b0; end
            5'd7  : begin base6 = 6'b000111; disp6 = 1'b0; end
            5'd8  : begin base6 = 6'b100111; disp6 = 1'b1; end
            5'd9  : begin base6 = 6'b101001; disp6 = 1'b0; end
            5'd10 : begin base6 = 6'b101010; disp6 = 1'b0; end
            5'd11 : begin base6 = 6'b001011; disp6 = 1'b0; end
            5'd12 : begin base6 = 6'b101100; disp6 = 1'b0; end
            5'd13 : begin base6 = 6'b001101; disp6 = 1'b0; end
            5'd14 : begin base6 = 6'b001110; disp6 = 1'b0; end
            5'd15 : begin base6 = 6'b111010; disp6 = 1'b1; end
            5'd16 : begin base6 = 6'b110110; disp6 = 1'b1; end
            5'd17 : begin base6 = 6'b110001; disp6 = 1'b0; end
            5'd18 : begin base6 = 6'b110010; disp6 = 1'b0; end
            5'd19 : begin base6 = 6'b010011; disp6 = 1'b0; end
            5'd20 : begin base6 = 6'b110100; disp6 = 1'b0; end
            5'd21 : begin base6 = 6'b010101; disp6 = 1'b0; end
            5'd22 : begin base6 = 6'b010110; disp6 = 1'b0; end
            5'd23 : begin base6 = 6'b010111; disp6 = 1'b1; end
            5'd24 : begin base6 = 6'b110011; disp6 = 1'b1; end
            5'd25 : begin base6 = 6'b011001; disp6 = 1'b0; end
            5'd26 : begin base6 = 6'b011010; disp6 = 1'b0; end
            5'd27 : begin base6 = 6'b011011; disp6 = 1'b1; end
            5'd28 : begin base6 = 6'b011100; disp6 = 1'b0; end
            5'd29 : begin base6 = 6'b011101; disp6 = 1'b1; end
            5'd30 : begin base6 = 6'b011110; disp6 = 1'b1; end
            default: begin base6 = 6'b110101; disp6 = 1'b1; end
        endcase
    end

    assign flip6 = rd & (disp6 | (x == 5'd7));
    assign code6 = flip6 ? ~base6 : base6;
    assign rd6   = rd ^ disp6;

//======================================================
// 4b 主列。fghj 高位是 f。y=0/3/4/7 两列互反。
// 结束极性只在 y=0/4/7 翻转。y=3 两列都换，0011/1100 的结束极性仍等于 rd6。
// D.x.7：rd6 为正用 x=11/13/14 的备码，为负用 x=17/18/20 的备码。
//======================================================

    assign useA7   = ( rd6 & ((x == 5'd11) || (x == 5'd13) || (x == 5'd14))) |
                     (~rd6 & ((x == 5'd17) || (x == 5'd18) || (x == 5'd20)));
    assign flip4   = (y[0] == y[1]);
    assign rdFlip4 = (y == 3'd0) || (y == 3'd4) || (y == 3'd7);

    always @(*) begin
        case (y)
            3'd0 : base4 = 4'b1101;
            3'd1 : base4 = 4'b1001;
            3'd2 : base4 = 4'b1010;
            3'd3 : base4 = 4'b0011;
            3'd4 : base4 = 4'b1011;
            3'd5 : base4 = 4'b0101;
            3'd6 : base4 = 4'b0110;
            default: base4 = useA7 ? 4'b1110 : 4'b0111;
        endcase
    end

    assign code4     = (rd6 & flip4) ? ~base4 : base4;
    assign codeGroupD = {code4, code6};
    assign rdNextD   = rd6 ^ rdFlip4;

//======================================================
// K 码只存 RD-。kFlip 为这一列走完后的极性。非法 K 输出 0。
//======================================================

    always @(*) begin
        kOk   = 1'b1;
        kFlip = 1'b0;
        case (octet)
            K28_5 : begin kBase = 10'b0101111100; kFlip = 1'b1; end
            K27_7 : begin kBase = 10'b0001011011; kFlip = 1'b0; end
            K29_7 : begin kBase = 10'b0001011101; kFlip = 1'b0; end
            K23_7 : begin kBase = 10'b0001010111; kFlip = 1'b0; end
            K30_7 : begin kBase = 10'b0001011110; kFlip = 1'b0; end
            default: begin
                kBase = 10'b0;
                kFlip = 1'b0;
                kOk   = 1'b0;
            end
        endcase
    end

    assign codeGroupK = rd ? ~kBase : kBase;
    assign rdNextK    = rd ^ kFlip;

    assign codeGroup = isK ? codeGroupK : codeGroupD;
    assign rdNext    = isK ? rdNextK    : rdNextD;
    assign invalid   = isK & ~kOk;

endmodule
