# 1G GMAC

全双工 1000BASE-X 数据通路。用户口是 128 bit @ 50 MHz，线路侧是 SERDES 1.25 Gb/s 的 20 bit 并行口。这里的 GMAC 指千兆以太网 MAC，不是密码学 GMAC。

顶层模块是 `GmacTop`。发送从用户口到 SERDES，接收从 SERDES 回到用户口。前导码、SFD、PAD、FCS、帧间距和 8B/10B 都在核内完成。用户报文已含 DA、SA、Length/Type 和客户数据，不含前导码、SFD 和 FCS。

第一版只做数据模式。自协商、LPI、Pause、PTP 和 802.3br 抢占没有实现；`preemptable` 保留并固定为 0。不考虑 jumbo，线上最大 1518 字节（DA 到 FCS）。

## 数据通路

```text
clkUsr 50 MHz, 128 bit                         clkMgmt
用户 ── usr2CdcPktBus（有 stall）──► UsrRsWidthCdc ◄── GmacReg
     ◄── cdc2UsrPktBus（无 stall）──┘        │
                                             │ 8 bit
                                        RsFramer
                                             │ 8 bit
                                        PcsCodec
                                             │ 10 bit @ 125 MHz
                                     PcsSdsGearbox
                                             │ 20 bit
                                        SERDES 1.25 Gb/s
```

只有发送路径有反压：`fire = valid & ~stall`。接收路径没有 `stall`，用户口必须收下。

| 模块 | 作用 |
|------|------|
| `UsrRsWidthCdc` | 用户 128 bit @ 50 MHz 与 RS 8 bit @ 125 MHz 之间的位宽和时钟桥 |
| `RsFramer` | 发送加前导、SFD、PAD、FCS、IFG；接收猎 SFD、校验并剥 FCS |
| `PcsCodec` | 8B/10B 与有序集。发送按报文编码，接收同步、译码并切出帧界 |
| `PcsSdsGearbox` | PCS 10 bit @ 125 MHz 与 SERDES 20 bit 并行口互转 |
| `GmacReg` | 管理口上的控制、状态和统计 |
| `GmacRst` | 把上电复位和软复位拉长，产生数据通路复位 `rstNCore` |

## 文件

| 文件 | 功能 |
|------|------|
| `GmacTop.v` | 顶层，例化上面各段并接寄存器 |
| `GmacIf.vh` | 位宽、包总线、码组位序。各模块 `` `include `` 本文件 |
| `GmacRst.v` | 外部 `rstN` 只复位本模块和 `GmacReg`；`softRstN` 拉低后把 `rstNCore` 拉长再释放 |
| `GmacReg.v` | 寄存器文件，由寄存器脚本生成 |
| `UsrRsWidthCdc.v` | 位宽桥包装。管理域配置和统计在这里跨到业务钟 |
| `UsrPktFilter.v` | 用户 128 bit 报文过滤。不缓存数据，只记住是否在包内、包内是否出过错 |
| `UsrRsCdcTx.v` | 发送：128 bit 写入异步 FIFO，读侧按 `Vb` 拆成 8 bit。高字节先出 |
| `UsrRsCdcRx.v` | 接收：8 bit 拼成 128 bit 再交给用户。FIFO 满则丢包并计数，不反压 RS |
| `RsFramer.v` | 成帧包装。帧长、IFG、`rxDelCrc` 从管理钟同步进来 |
| `RsTxFramer.v` | 发送成帧：7×`0x55`、`0xD5`、载荷、不足 60 字节补零、FCS、12 拍 IFG。拉断、入向错误或超长走错误 FCS |
| `RsRxParser.v` | 接收：猎 SFD，DA 起直通，4 字节延迟线剥 FCS。CRC 错与 `efp` 同拍给出 |
| `GmacCrc32.v` | 以太网 CRC-32 的 8 bit 并行组合逻辑 |
| `PcsCodec.v` | PCS 包装。近端环回在 10 bit 码组上折回 |
| `PcsTxEncode.v` | 发送三态：Idle 发 `/I/`，包内发 `/S/` 和数据，包尾发 `/T/R/`。维护运行差分 |
| `PcsRxSync.v` | 接收码组同步：逗号码对齐、偶边界、`syncStatus` |
| `PcsRxDecode.v` | 把已同步的码组译成八位组，交给切帧 |
| `PcsRxMark.v` | `/S/` 起包，`/T/R/R/` 或 `/T/R/K28.5/` 收包，`/V/` 和非法码打 `err` |
| `Gmac8b10bEnc.v` | Clause 36 8B/10B 编码。`codeGroup[0]` 先出 |
| `Gmac8b10bDec.v` | Clause 36 8B/10B 译码 |
| `PcsSdsGearbox.v` | Gearbox 包装，复位同步到发送钟和接收钟 |
| `PcsSdsGbxTx.v` | 两拍 10 bit 拼成 20 bit，经异步 FIFO 交到 `clkSdsTx`。低 10 bit 先出 |
| `PcsSdsGbxRx.v` | 20 bit 经异步 FIFO 交到 `clkRx`，先出 `[9:0]`，再出 `[19:10]` |
| `tb/Gmac8b10bTb.v` | 8B/10B 编解码仿真 |
| `tb/PcsCodecPathTb.v` | PCS 通路仿真 |

## 时钟

| 时钟 | 典型频率 | 用途 |
|------|----------|------|
| `clkUsr` | 50 MHz | 用户 128 bit 口 |
| `clkTx` | 125 MHz | 发送域：位宽桥读侧、RS 发送、PCS 发送、Gearbox 的 10 bit 侧 |
| `clkRx` | 125 MHz | 接收域，由 `clkSdsRx` 倍频。不假设与 `clkTx` 同相 |
| `clkSdsTx` | 62.5 MHz | SERDES 发送并行口，20 bit |
| `clkSdsRx` | 62.5 MHz | SERDES 接收恢复钟，20 bit |
| `clkMgmt` | 管理钟 | 寄存器读写 |
| `rstN` | — | 低有效。异步置位，在 `clkMgmt` 上同步释放后再分发 |

用户口峰值 6.4 Gb/s，远高于线速 1 Gb/s。发送侧由用户保证包内喂数够快；FIFO 几乎满时用 `stall` 刹住写入。接收侧线上已是连续字节流，用户口无反压。

## 对外接口

包总线信号相对源模块命名：`data`、`vb`、`valid`、`sfp`、`efp`、`err`、`preemptable`，发送侧另有 `stall`。`sfp` 与 `valid` 同拍表示包起始，`efp` 表示包结束，`err` 至少在 `efp` 拍有效。

- 用户 128 bit：高字节先发，`data[127:120]` 最先上线。`vb` 为 1..16，有效字节从高字节起连续占 `vb` 个。
- 内部 8 bit：每拍 1 字节，不带 `vb`。
- 10 bit 码组：`codeGroup[0]` 先出。空闲是 `/I/`，每拍都有码组，没有 valid/stall。
- SERDES 20 bit：一拍两个码组，`[9:0]` 先出，再出 `[19:10]`。使用原始 20 bit，不再打开收发器自带的 8B/10B。
- 管理口：`wr` / `wrAddr` / `wrData` / `wrAck` / `wrErr`，以及 `rd` / `rdAddr` / `rdData` / `rdAck` / `rdErr`。字对齐，未实现地址 `Err=1`。`irq` 上报计数变化等事件。

`GmacReg` 给出的控制包括软复位、发送使能、接收使能、近端环回、帧间距、最短/最长帧、接收是否剥 FCS，以及各 FIFO 的读侧水位和几乎满门槛。统计在业务钟累加，管理钟读出。

## 依赖

本目录以外还需要 `VerilogIpLib` 中的：

- `IP_AsyncFifo`：跨时钟的数据
- `IP_ResetSync`：复位同步到各业务钟
- `IP_Sync`：单 bit 或稳定多 bit 电平
- `IP_DataGraySync`：跨时钟的计数和状态

综合或仿真时把 `GmacIf.vh` 所在目录加入 include 路径。SERDES、时钟倍频和 CDR 不在本目录内。
