`ifndef GMAC_IF_VH
`define GMAC_IF_VH

// +FHDR----------------------------------------------------------------------------
// File Name     : GmacIf.vh
// Description   : 1G GMAC 接口约定（位宽 / 总线信号 / 时钟）。模块端口按此展开。
//                 本文件只定义宏与注释，不含逻辑。
// ---------------------------------------------------------------------------------

//######################################################
// 位宽
//######################################################

`define GMAC_USR_W      128
`define GMAC_BYTE_W     8
`define GMAC_VB_W       5
`define GMAC_CODE_W     10
`define GMAC_SDS_W      20
`define GMAC_ADDR_W     32
`define GMAC_REG_W      32
// 计数器位宽：按用途选 8/16/32，勿再混用单一宏
`define GMAC_CNT_W8     8
`define GMAC_CNT_W16    16
`define GMAC_CNT_W32    32
`define GMAC_CNT_W      `GMAC_CNT_W32

//######################################################
// 包总线 PktBus / 用户 DataBus
//   高字节先发：128b 时 data[127:120] 最先上线，依次到 data[7:0]。
//   Vb[4:0]：本拍有效字节数，值为 1..16（有几个有效字节就为几）。
//            有效字节自高字节起连续占 Vb 个；未用低字节可任意。
//   8b 内部总线每拍 1 字节，无需 Vb。
//   fire = valid & ~stall（仅 Tx 有 stall；Rx 无 stall 信号）。
//   preemptable：802.3br 预留，第一版绑 0。
//   err：至少在 efp 拍有效。
//######################################################
//
// 信号（相对源）：
//   Data[W-1:0]  Vb[4:0]  Valid  Sfp  Efp  Err  Preemptable  [Stall]
//   （仅用户侧 128b DataBus 带 Vb；内部 8b 无 Vb）
//
// | 接口              | 源 -> 宿              | 时钟     | W   | stall | Vb |
// | usr2CdcPktBus     | User -> UsrRsWidthCdc | clkUsr   | 128 | 有    | 有 |
// | cdc2UsrPktBus     | UsrRsWidthCdc -> User | clkUsr   | 128 | 无    | 有 |
// | cdc2RsPktBus      | UsrRsWidthCdc -> Rs   | clkTx    | 8   | 有    | 无 |
// | rs2CdcPktBus      | Rs -> UsrRsWidthCdc   | clkRx    | 8   | 无    | 无 |
// | rs2PcsPktBus      | Rs -> PcsCodec        | clkTx    | 8   | 有    | 无 |
// | pcs2RsPktBus      | PcsCodec -> Rs        | clkRx    | 8   | 无    | 无 |
//
// Verilog 端口展开：{实例}{信号}，信号首字母大写。
//   例：usr2CdcPktBusData / usr2CdcPktBusVb / usr2CdcPktBusValid

//######################################################
// 码组总线 CodeBus
//   每拍 1 个 10-bit 码组；空闲是 /I/ 不是气泡；无 valid / stall。
//   codeGroup[0] 先出。
//######################################################
//
// | 接口                 | 源 -> 宿                 | 时钟  |
// | pcs2GbxCodeBus       | PcsCodec -> Gearbox      | clkTx |
// | gbx2PcsCodeBus       | Gearbox -> PcsCodec      | clkRx |
//
// 信号：CodeGroup[9:0]

//######################################################
// SERDES 总线 SdsBus
//   每拍 20 bit，无 valid / stall。低 10 bit 先出（[9:0] 再 [19:10]）。
//######################################################
//
// | 接口            | 源 -> 宿        | 时钟     |
// | gbx2SdsTxBus    | Gearbox -> SDS  | clkSdsTx |
// | sds2GbxRxBus    | SDS -> Gearbox  | clkSdsRx |
//
// 信号：Data[19:0]

//######################################################
// 管理总线 mgmt2RegRegBus @ clkMgmt
//   与 RegGen 口同名，不含下划线。未实现地址 Err=1。
//######################################################
//
//   wr  wrAddr[31:0]  wrData[31:0]  wrAck  wrErr
//   rd  rdAddr[31:0]  rdData[31:0]  rdAck  rdErr
//
// GmacReg（RegGen：clock/reset，GmacTop 接 clkMgmt/rstN；仅寄存器吃外部复位）
//   控制输出：softRstN txEn rxEn loopback fifoTxFifoThrd irqMask ifgCntMax lenCntMin lenCntMax rxDelCrc
//             loopbackAlFullThrd loopbackAlEmptyThrd gbxTxFifoThrd gbxRxFifoThrd
//   软复位：softRstN 低有效。GmacRst 把 POR 与 softRstN 拉长为 rstNCore，再分给数据通路
//   状态输入：已在各模块同步到 clkMgmt 的水位/FSM/锁/计数
//   口计数从 0x194 起，只读：txIn/txOut/rxIn/rxOut 的 Sfp、Efp、Vb、Valid、Err
//   近端环回在 PcsCodec 内：clkTx 10b 经 IP_AsyncFifo 折到 clkRx
//   irq 输出：|(irqRaw & irqMask)。事件位[10:3]在计数变化时置位，写 irqClr 地址清。
//   irqRaw[10:0] =（中断口名 irq* 依规划文档；事件对应 *Cnt 边沿）
//     [0] fifoAlFull  [1] ~pcsRxSync  [2] txBusy
//     [3] txOverRunCntEvt  [4] txUnderRunCntEvt [5] rxOverflowCntEvt
//     [6] txUnderrunCntEvt [7] txOversizeCntEvt [8] rxCrcErrCntEvt
//     [9] lossOfSyncCntEvt [10] codeVCntEvt

//######################################################
// PCS 内部（不引出核）
//######################################################
//
// Sync2Dec @ clkRx（PcsRxSync -> PcsRxDecode）
//   CodeGroup[9:0]  RxEven  SyncStatus  CgBad
//
// Dec2Mark @ clkRx（PcsRxDecode -> PcsRxMark）
//   Octet[7:0]  IsK  Invalid  RxRd  RxEven  SyncStatus
//
// PcsRxMark.pcs2RsSyncStatus 必须直接接 PcsRxSync（线），
// 不要用 Decode 流水里滞后的 SyncStatus 做失锁关门。
//
// 数据通路名统一为 pcs2RsSyncStatus（clkRx）：PcsCodec → RsFramer。
// 给 GmacReg 的 pcsRxSync 由 PcsCodec 在内部同步到 clkMgmt。

//######################################################
// 时钟 / 复位
//######################################################
//
//   clkUsr     50 MHz   用户 128 bit
//   clkTx     125 MHz   RS/PCS/Gbx 10b 发送域
//   clkRx     125 MHz   RS/PCS/Gbx 10b 接收域（clkSdsRx 倍频，勿与 clkTx 同相假设）
//   clkSdsTx   ~62.5 M  SERDES Tx 20b（典型与 clkTx 同源 2 分频）
//   clkSdsRx   ~62.5 M  SERDES Rx 恢复钟
//   clkMgmt             寄存器
//   rstN                外部异步复位，只进 GmacReg / GmacRst
//   rstNCore            GmacRst 输出，POR 与 softRstN 合并后的核复位
//
// 复位路径：
//   外部 rstN → GmacReg + GmacRst
//   GmacRst 拉长 softRstN → rstNCore → 各数据模块
//   各模块内部用 IP_ResetSync 把 rstNCore 同步到本时钟（异步置位、同步释放）
//   模块不再同时接端口 rstN 和 softRstN
//
// 跨域（做在各数据模块内部，不在 GmacTop）：
//   控制：GmacReg(clkMgmt) → IP_Sync → 本域时钟；同步器复位用目的时钟域复位
//   计数/水位：本域 → IP_DataGraySync → clkMgmt
//   1 bit 状态：本域 → IP_Sync(reset=目的域复位) → clkMgmt
//   包装模块对外：控制输入、状态输出均视为 clkMgmt；叶子仍用本域信号

`endif
