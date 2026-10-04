// +FHDR----------------------------------------------------------------------------
// Device        : Xilinx
// Author        : fxdqe
// Email         : 1706260166@qq.com
// Created On    : 2026/10/03 16:20
// File Name     : GmacCrc32.v
// Description   : 以太网 CRC-32 的 8 比特并行组合逻辑。
//                 反射多项式 0xEDB88320，低位先入。初值与结果取反由调用方处理。
// ---------------------------------------------------------------------------------
// Modification History:
// Date         By              Version                 Change Description
// ---------------------------------------------------------------------------------
// 2026/10/03   fxdqe           1.0                     Original
// -FHDR----------------------------------------------------------------------------

module GmacCrc32(/*autoarg*/
        //Inputs
        crcIn, dataIn,
        //Outputs
        crcOut
);

//######################################################
//Interface
//######################################################

input  [31:0] crcIn;
input  [7:0]  dataIn;
output [31:0] crcOut;

//######################################################
//Value
//######################################################

// 无寄存器。crcOut 与 crcIn、dataIn 同一拍有效。

//######################################################
//Logic
//######################################################

//======================================================
// 一拍吃进 8 比特
// 串行定义是反射直接形式：反馈取余数最低位与数据当前位的异或，
// 余数右移，反馈为 1 时异或 0xEDB88320。数据从 bit0 开始，先低位。
// 下面每一行是把这 8 步按线性展开后的异或树，中间拍不再出现。
//======================================================
    assign crcOut[ 0] = crcIn[2] ^ crcIn[8] ^ dataIn[2];
    assign crcOut[ 1] = crcIn[0] ^ crcIn[3] ^ crcIn[9] ^ dataIn[0] ^ dataIn[3];
    assign crcOut[ 2] = crcIn[0] ^ crcIn[1] ^ crcIn[4] ^ crcIn[10] ^ dataIn[0] ^ dataIn[1] ^ dataIn[4];
    assign crcOut[ 3] = crcIn[1] ^ crcIn[2] ^ crcIn[5] ^ crcIn[11] ^ dataIn[1] ^ dataIn[2] ^ dataIn[5];
    assign crcOut[ 4] = crcIn[0] ^ crcIn[2] ^ crcIn[3] ^ crcIn[6] ^ crcIn[12] ^ dataIn[0] ^ dataIn[2] ^ dataIn[3] ^ dataIn[6];
    assign crcOut[ 5] = crcIn[1] ^ crcIn[3] ^ crcIn[4] ^ crcIn[7] ^ crcIn[13] ^ dataIn[1] ^ dataIn[3] ^ dataIn[4] ^ dataIn[7];
    assign crcOut[ 6] = crcIn[4] ^ crcIn[5] ^ crcIn[14] ^ dataIn[4] ^ dataIn[5];
    assign crcOut[ 7] = crcIn[0] ^ crcIn[5] ^ crcIn[6] ^ crcIn[15] ^ dataIn[0] ^ dataIn[5] ^ dataIn[6];
    assign crcOut[ 8] = crcIn[1] ^ crcIn[6] ^ crcIn[7] ^ crcIn[16] ^ dataIn[1] ^ dataIn[6] ^ dataIn[7];
    assign crcOut[ 9] = crcIn[7] ^ crcIn[17] ^ dataIn[7];
    assign crcOut[10] = crcIn[2] ^ crcIn[18] ^ dataIn[2];
    assign crcOut[11] = crcIn[3] ^ crcIn[19] ^ dataIn[3];
    assign crcOut[12] = crcIn[0] ^ crcIn[4] ^ crcIn[20] ^ dataIn[0] ^ dataIn[4];
    assign crcOut[13] = crcIn[0] ^ crcIn[1] ^ crcIn[5] ^ crcIn[21] ^ dataIn[0] ^ dataIn[1] ^ dataIn[5];
    assign crcOut[14] = crcIn[1] ^ crcIn[2] ^ crcIn[6] ^ crcIn[22] ^ dataIn[1] ^ dataIn[2] ^ dataIn[6];
    assign crcOut[15] = crcIn[2] ^ crcIn[3] ^ crcIn[7] ^ crcIn[23] ^ dataIn[2] ^ dataIn[3] ^ dataIn[7];
    assign crcOut[16] = crcIn[0] ^ crcIn[2] ^ crcIn[3] ^ crcIn[4] ^ crcIn[24] ^ dataIn[0] ^ dataIn[2] ^ dataIn[3] ^ dataIn[4];
    assign crcOut[17] = crcIn[0] ^ crcIn[1] ^ crcIn[3] ^ crcIn[4] ^ crcIn[5] ^ crcIn[25] ^ dataIn[0] ^ dataIn[1] ^ dataIn[3] ^ dataIn[4] ^ dataIn[5];
    assign crcOut[18] = crcIn[0] ^ crcIn[1] ^ crcIn[2] ^ crcIn[4] ^ crcIn[5] ^ crcIn[6] ^ crcIn[26] ^ dataIn[0] ^ dataIn[1] ^ dataIn[2] ^ dataIn[4] ^ dataIn[5] ^ dataIn[6];
    assign crcOut[19] = crcIn[1] ^ crcIn[2] ^ crcIn[3] ^ crcIn[5] ^ crcIn[6] ^ crcIn[7] ^ crcIn[27] ^ dataIn[1] ^ dataIn[2] ^ dataIn[3] ^ dataIn[5] ^ dataIn[6] ^ dataIn[7];
    assign crcOut[20] = crcIn[3] ^ crcIn[4] ^ crcIn[6] ^ crcIn[7] ^ crcIn[28] ^ dataIn[3] ^ dataIn[4] ^ dataIn[6] ^ dataIn[7];
    assign crcOut[21] = crcIn[2] ^ crcIn[4] ^ crcIn[5] ^ crcIn[7] ^ crcIn[29] ^ dataIn[2] ^ dataIn[4] ^ dataIn[5] ^ dataIn[7];
    assign crcOut[22] = crcIn[2] ^ crcIn[3] ^ crcIn[5] ^ crcIn[6] ^ crcIn[30] ^ dataIn[2] ^ dataIn[3] ^ dataIn[5] ^ dataIn[6];
    assign crcOut[23] = crcIn[3] ^ crcIn[4] ^ crcIn[6] ^ crcIn[7] ^ crcIn[31] ^ dataIn[3] ^ dataIn[4] ^ dataIn[6] ^ dataIn[7];
    assign crcOut[24] = crcIn[0] ^ crcIn[2] ^ crcIn[4] ^ crcIn[5] ^ crcIn[7] ^ dataIn[0] ^ dataIn[2] ^ dataIn[4] ^ dataIn[5] ^ dataIn[7];
    assign crcOut[25] = crcIn[0] ^ crcIn[1] ^ crcIn[2] ^ crcIn[3] ^ crcIn[5] ^ crcIn[6] ^ dataIn[0] ^ dataIn[1] ^ dataIn[2] ^ dataIn[3] ^ dataIn[5] ^ dataIn[6];
    assign crcOut[26] = crcIn[0] ^ crcIn[1] ^ crcIn[2] ^ crcIn[3] ^ crcIn[4] ^ crcIn[6] ^ crcIn[7] ^ dataIn[0] ^ dataIn[1] ^ dataIn[2] ^ dataIn[3] ^ dataIn[4] ^ dataIn[6] ^ dataIn[7];
    assign crcOut[27] = crcIn[1] ^ crcIn[3] ^ crcIn[4] ^ crcIn[5] ^ crcIn[7] ^ dataIn[1] ^ dataIn[3] ^ dataIn[4] ^ dataIn[5] ^ dataIn[7];
    assign crcOut[28] = crcIn[0] ^ crcIn[4] ^ crcIn[5] ^ crcIn[6] ^ dataIn[0] ^ dataIn[4] ^ dataIn[5] ^ dataIn[6];
    assign crcOut[29] = crcIn[0] ^ crcIn[1] ^ crcIn[5] ^ crcIn[6] ^ crcIn[7] ^ dataIn[0] ^ dataIn[1] ^ dataIn[5] ^ dataIn[6] ^ dataIn[7];
    assign crcOut[30] = crcIn[0] ^ crcIn[1] ^ crcIn[6] ^ crcIn[7] ^ dataIn[0] ^ dataIn[1] ^ dataIn[6] ^ dataIn[7];
    assign crcOut[31] = crcIn[1] ^ crcIn[7] ^ dataIn[1] ^ dataIn[7];

endmodule
