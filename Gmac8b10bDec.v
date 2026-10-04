// +FHDR----------------------------------------------------------------------------
// Device        : Xilinx
// Author        : fxdqe
// Email         : 1706260166@qq.com
// Created On    : 2026/09/16 21:40
// File Name     : Gmac8b10bDec.v
// Description   : Clause 36 8B/10B。codeGroup[0]=a 先出。rd 0=负 1=正。
//                 6b、K 按进来的 rd 分列。4b 按 rd6 分列。
//                 y=7 再按 x 核对主码或 A7。found 表示解码成立。
// ---------------------------------------------------------------------------------
// Modification History:
// Date         By              Version                 Change Description
// ---------------------------------------------------------------------------------
// 2026/09/16   fxdqe           1.1                     Sub-block RD, A7
// 2026/10/01   fxdqe           1.2                     单模块文件拆分
// 2026/10/04   fxdqe           1.3                     6b 两列分别译码再按 rd 选择
// 2026/10/04   fxdqe           1.4                     4b/K 分列，y=7 核对 A7，去掉回编码
// 2026/10/04   fxdqe           1.5                     结束极性改由码表属性得出
// -FHDR----------------------------------------------------------------------------

`include "GmacIf.vh"

module Gmac8b10bDec(/*autoarg*/
        //Inputs
        codeGroup, rd,
        //Outputs
        octet, isK, invalid, inAlphabet, rdNext
);

//######################################################
//Interface
//######################################################

input  [9:0]            codeGroup;
input                   rd;
output [7:0]            octet;
output                  isK;
output                  invalid;
output                  inAlphabet;
output                  rdNext;

//######################################################
//Value
//######################################################

localparam [7:0] K28_5 = 8'hBC;
localparam [7:0] K27_7 = 8'hFB;
localparam [7:0] K29_7 = 8'hFD;
localparam [7:0] K23_7 = 8'hF7;
localparam [7:0] K30_7 = 8'hFE;

// 码组拆成 6b / 4b。abcdei[0]=a，fghj 高位是 f
wire [5:0]              abcdei;
wire [3:0]              fghj;

// K 码：k1 是 RD- 列，k2 是 RD+ 列
reg  [7:0]              kOctet1;
reg                     foundK1;
reg  [7:0]              kOctet2;
reg                     foundK2;
wire [7:0]              kOctet;
wire                    foundK;
wire                    kFlip;

// 6b：x1 是 RD- 列，x2 是 RD+ 列
reg  [4:0]              x1;
reg  [4:0]              x2;
reg                     found1;
reg                     found2;
wire [4:0]              x;
wire                    found6;
wire                    disp6;
wire                    rd6;

// 4b：y1 是 rd6 为负的列，y2 是 rd6 为正的列
reg  [2:0]              y1;
reg                     foundY1;
reg  [2:0]              y2;
reg                     foundY2;
wire [2:0]              y;
wire                    foundY;
wire                    useA7;
wire [3:0]              fghj7;
wire                    found4;
wire                    rdFlip4;

//######################################################
//Logic
//######################################################

    assign abcdei = {codeGroup[5], codeGroup[4], codeGroup[3],
                     codeGroup[2], codeGroup[1], codeGroup[0]};
    assign fghj   = {codeGroup[9], codeGroup[8], codeGroup[7], codeGroup[6]};

//======================================================
// K 码两列。每列只放该起始极性的码组
//======================================================

    always @(*) begin
        kOctet1 = K28_5;
        foundK1 = 1'b0;
        case (codeGroup)
            10'b0101111100: begin kOctet1 = K28_5; foundK1 = 1'b1; end
            10'b0001011011: begin kOctet1 = K27_7; foundK1 = 1'b1; end
            10'b0001011101: begin kOctet1 = K29_7; foundK1 = 1'b1; end
            10'b0001010111: begin kOctet1 = K23_7; foundK1 = 1'b1; end
            10'b0001011110: begin kOctet1 = K30_7; foundK1 = 1'b1; end
            default: foundK1 = 1'b0;
        endcase
    end

    always @(*) begin
        kOctet2 = K28_5;
        foundK2 = 1'b0;
        case (codeGroup)
            10'b1010000011: begin kOctet2 = K28_5; foundK2 = 1'b1; end
            10'b1110100100: begin kOctet2 = K27_7; foundK2 = 1'b1; end
            10'b1110100010: begin kOctet2 = K29_7; foundK2 = 1'b1; end
            10'b1110101000: begin kOctet2 = K23_7; foundK2 = 1'b1; end
            10'b1110100001: begin kOctet2 = K30_7; foundK2 = 1'b1; end
            default: foundK2 = 1'b0;
        endcase
    end

    assign kOctet = rd ? kOctet2 : kOctet1;
    assign foundK = rd ? foundK2 : foundK1;

//======================================================
// 6b 两列。x1 对应 RD-，x2 对应 RD+。中性码两列相同。按 rd 选列。
//======================================================

    always @(*) begin
        x1     = 5'd0;
        found1 = 1'b0;
        case (abcdei)
            6'b111001: begin x1 = 5'd0;  found1 = 1'b1; end
            6'b101110: begin x1 = 5'd1;  found1 = 1'b1; end
            6'b101101: begin x1 = 5'd2;  found1 = 1'b1; end
            6'b100011: begin x1 = 5'd3;  found1 = 1'b1; end
            6'b101011: begin x1 = 5'd4;  found1 = 1'b1; end
            6'b100101: begin x1 = 5'd5;  found1 = 1'b1; end
            6'b100110: begin x1 = 5'd6;  found1 = 1'b1; end
            6'b000111: begin x1 = 5'd7;  found1 = 1'b1; end
            6'b100111: begin x1 = 5'd8;  found1 = 1'b1; end
            6'b101001: begin x1 = 5'd9;  found1 = 1'b1; end
            6'b101010: begin x1 = 5'd10; found1 = 1'b1; end
            6'b001011: begin x1 = 5'd11; found1 = 1'b1; end
            6'b101100: begin x1 = 5'd12; found1 = 1'b1; end
            6'b001101: begin x1 = 5'd13; found1 = 1'b1; end
            6'b001110: begin x1 = 5'd14; found1 = 1'b1; end
            6'b111010: begin x1 = 5'd15; found1 = 1'b1; end
            6'b110110: begin x1 = 5'd16; found1 = 1'b1; end
            6'b110001: begin x1 = 5'd17; found1 = 1'b1; end
            6'b110010: begin x1 = 5'd18; found1 = 1'b1; end
            6'b010011: begin x1 = 5'd19; found1 = 1'b1; end
            6'b110100: begin x1 = 5'd20; found1 = 1'b1; end
            6'b010101: begin x1 = 5'd21; found1 = 1'b1; end
            6'b010110: begin x1 = 5'd22; found1 = 1'b1; end
            6'b010111: begin x1 = 5'd23; found1 = 1'b1; end
            6'b110011: begin x1 = 5'd24; found1 = 1'b1; end
            6'b011001: begin x1 = 5'd25; found1 = 1'b1; end
            6'b011010: begin x1 = 5'd26; found1 = 1'b1; end
            6'b011011: begin x1 = 5'd27; found1 = 1'b1; end
            6'b011100: begin x1 = 5'd28; found1 = 1'b1; end
            6'b011101: begin x1 = 5'd29; found1 = 1'b1; end
            6'b011110: begin x1 = 5'd30; found1 = 1'b1; end
            6'b110101: begin x1 = 5'd31; found1 = 1'b1; end
            default: begin
                x1     = 5'd0;
                found1 = 1'b0;
            end
        endcase
    end

    always @(*) begin
        x2     = 5'd0;
        found2 = 1'b0;
        case (abcdei)
            6'b000110: begin x2 = 5'd0;  found2 = 1'b1; end
            6'b010001: begin x2 = 5'd1;  found2 = 1'b1; end
            6'b010010: begin x2 = 5'd2;  found2 = 1'b1; end
            6'b100011: begin x2 = 5'd3;  found2 = 1'b1; end
            6'b010100: begin x2 = 5'd4;  found2 = 1'b1; end
            6'b100101: begin x2 = 5'd5;  found2 = 1'b1; end
            6'b100110: begin x2 = 5'd6;  found2 = 1'b1; end
            6'b111000: begin x2 = 5'd7;  found2 = 1'b1; end
            6'b011000: begin x2 = 5'd8;  found2 = 1'b1; end
            6'b101001: begin x2 = 5'd9;  found2 = 1'b1; end
            6'b101010: begin x2 = 5'd10; found2 = 1'b1; end
            6'b001011: begin x2 = 5'd11; found2 = 1'b1; end
            6'b101100: begin x2 = 5'd12; found2 = 1'b1; end
            6'b001101: begin x2 = 5'd13; found2 = 1'b1; end
            6'b001110: begin x2 = 5'd14; found2 = 1'b1; end
            6'b000101: begin x2 = 5'd15; found2 = 1'b1; end
            6'b001001: begin x2 = 5'd16; found2 = 1'b1; end
            6'b110001: begin x2 = 5'd17; found2 = 1'b1; end
            6'b110010: begin x2 = 5'd18; found2 = 1'b1; end
            6'b010011: begin x2 = 5'd19; found2 = 1'b1; end
            6'b110100: begin x2 = 5'd20; found2 = 1'b1; end
            6'b010101: begin x2 = 5'd21; found2 = 1'b1; end
            6'b010110: begin x2 = 5'd22; found2 = 1'b1; end
            6'b101000: begin x2 = 5'd23; found2 = 1'b1; end
            6'b001100: begin x2 = 5'd24; found2 = 1'b1; end
            6'b011001: begin x2 = 5'd25; found2 = 1'b1; end
            6'b011010: begin x2 = 5'd26; found2 = 1'b1; end
            6'b100100: begin x2 = 5'd27; found2 = 1'b1; end
            6'b011100: begin x2 = 5'd28; found2 = 1'b1; end
            6'b100010: begin x2 = 5'd29; found2 = 1'b1; end
            6'b100001: begin x2 = 5'd30; found2 = 1'b1; end
            6'b001010: begin x2 = 5'd31; found2 = 1'b1; end
            default: begin
                x2     = 5'd0;
                found2 = 1'b0;
            end
        endcase
    end

    assign x      = rd ? x2 : x1;
    assign found6 = rd ? found2 : found1;
    assign disp6  = (x == 5'd0)  | (x == 5'd1)  | (x == 5'd2)  | (x == 5'd4)  |
                    (x == 5'd8)  | (x == 5'd15) | (x == 5'd16) | (x == 5'd23) |
                    (x == 5'd24) | (x == 5'd27) | (x == 5'd29) | (x == 5'd30) |
                    (x == 5'd31);
    assign rd6    = rd ^ disp6;

//======================================================
// 4b 两列。y1 对应 rd6 为负，y2 对应 rd6 为正。y=7 含主码和 A7
//======================================================

    always @(*) begin
        y1      = 3'd0;
        foundY1 = 1'b0;
        case (fghj)
            4'b1101: begin y1 = 3'd0; foundY1 = 1'b1; end
            4'b1001: begin y1 = 3'd1; foundY1 = 1'b1; end
            4'b1010: begin y1 = 3'd2; foundY1 = 1'b1; end
            4'b0011: begin y1 = 3'd3; foundY1 = 1'b1; end
            4'b1011: begin y1 = 3'd4; foundY1 = 1'b1; end
            4'b0101: begin y1 = 3'd5; foundY1 = 1'b1; end
            4'b0110: begin y1 = 3'd6; foundY1 = 1'b1; end
            4'b0111, 4'b1110: begin y1 = 3'd7; foundY1 = 1'b1; end
            default: begin
                y1      = 3'd0;
                foundY1 = 1'b0;
            end
        endcase
    end

    always @(*) begin
        y2      = 3'd0;
        foundY2 = 1'b0;
        case (fghj)
            4'b0010: begin y2 = 3'd0; foundY2 = 1'b1; end
            4'b1001: begin y2 = 3'd1; foundY2 = 1'b1; end
            4'b1010: begin y2 = 3'd2; foundY2 = 1'b1; end
            4'b1100: begin y2 = 3'd3; foundY2 = 1'b1; end
            4'b0100: begin y2 = 3'd4; foundY2 = 1'b1; end
            4'b0101: begin y2 = 3'd5; foundY2 = 1'b1; end
            4'b0110: begin y2 = 3'd6; foundY2 = 1'b1; end
            4'b1000, 4'b0001: begin y2 = 3'd7; foundY2 = 1'b1; end
            default: begin
                y2      = 3'd0;
                foundY2 = 1'b0;
            end
        endcase
    end

    assign y      = rd6 ? y2 : y1;
    assign foundY = rd6 ? foundY2 : foundY1;

//======================================================
// y=7：rd6 为正且 x=11/13/14，或 rd6 为负且 x=17/18/20，才用 A7
//======================================================

    assign useA7 = ( rd6 & ((x == 5'd11) | (x == 5'd13) | (x == 5'd14))) |
                   (~rd6 & ((x == 5'd17) | (x == 5'd18) | (x == 5'd20)));
    assign fghj7 = useA7 ? (rd6 ? 4'b0001 : 4'b1110) :
                           (rd6 ? 4'b1000 : 4'b0111);
    assign found4 = foundY & ((y != 3'd7) | (fghj == fghj7));

//======================================================
// K 优先。数据码要 6b 与 4b 同时命中
//======================================================

    assign octet      = foundK ? kOctet : {y, x};
    assign isK        = foundK;
    assign invalid    = ~(foundK | (found6 & found4));
    assign inAlphabet = ~invalid;

//======================================================
// 结束极性。数据码：y=0/4/7 相对 rd6 翻转，y=3 仍等于 rd6。
// K28.5 相对进来的 rd 翻转，其余 K 保持 rd。
//======================================================

    assign rdFlip4 = (y == 3'd0) | (y == 3'd4) | (y == 3'd7);
    assign kFlip   = (kOctet == K28_5);
    assign rdNext  = foundK ? (rd ^ kFlip) : (rd6 ^ rdFlip4);

endmodule
