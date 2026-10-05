# Verilog 命名与写法规范

本文汇总 GMAC RTL 编码约定。接口总线、时钟等系统级约定亦见 `Gmac结构规划.md`。

可读、好改优先于把每一条都套死。某条会使逻辑更绕、更难看时，按读得懂的写法来，并在该处留一句注释说明原因。见第 4.1 节。

参考风格：`VerilogIpLib/IP_AsyncFifo.v`。

按书写顺序分成五部分：

| 部分 | 写什么 |
|------|--------|
| 1 | 文件与模块名 |
| 2 | 接口名：总线、时钟、复位、参数、例化 |
| 3 | 信号名：后缀、计数、下一拍、打拍、中断 |
| 4 | 逻辑：always、计数、状态机、FIFO、跨时钟、复位同步 |
| 5 | 注释：模块骨架、功能块、声明行 |

与 `Gmac结构规划.md` 的关系：接口名 `Src2DstFunc`、信号/时钟小驼峰、模块缩写表、中断 `irq*` 与规划一致；冲突时以规划文档的系统约定为准，其余信号后缀与写法以本文为准。跨时钟选型、复位同步放在哪一层，以本文第 4.11、4.12 节为准。新写 GMAC RTL 按本文执行；`VerilogIpLib/IP_*` 保持既有命名。

---

## 1. 文件与模块命名

- **文件名与模块名使用大驼峰（PascalCase），且两者相同**。
  - 例：`UsrRsCdcTx.v` ↔ `module UsrRsCdcTx`；`RsTxFramer.v` ↔ `module RsTxFramer`。
- **一个文件仅含一个模块**（一对 `module` … `endmodule`），禁止同文件多模块。
- **已验证、可复用的库 IP**：以 **`IP_XXX`** 命名（文件名 / 模块名一致）。
  - 例：`IP_AsyncFifo.v`、`IP_Sync.v`、`IP_BitPluseSync.v`、`IP_DataGraySync.v`、`IP_ResetSync.v`。
  - 库 IP 既有命名保持原样，不改写。
- **模块名体现主要前后级**：有清晰上下游时用 **`Xxx2Yyy…`**（来源缩写 + `2` + 去向缩写，可再加功能）。
  - 例：接口/通路语义上的 `Usr2Cdc`、`Pcs2Gbx`；包装模块如 `UsrRsWidthCdc` 仍以功能聚合命名。
- **若无单一主要前后级**：按**模块功能**命名。
  - 例：`RsTxFramer`、`PcsRxSync`、`UsrRsWidthCdc`。

模块缩写（用于接口与前后级）：见 `Gmac结构规划.md`（`Usr` / `Cdc` / `Rs` / `Pcs` / `Gbx` / `Sds` / `Reg` / `Mgmt`）。

---

## 2. 接口命名

### 2.1 总线与时钟

- 接口名用 **`Src2DstFunc`**，与 `Gmac结构规划.md` 一致。
- 时钟名小驼峰，例如 `clkUsr`、`clkTx`、`clkMgmt`。
- 模块缩写见第 1 节。

### 2.2 复位端口

复位一律低有效，名字以 `N` 结尾。不带 `N` 表示高有效复位；本工程不使用高有效复位。

| 名字 | 极性 | 含义 |
|------|------|------|
| `rstN`、`rstNCore`、`rstNUsr` | 低有效 | 拉低进入复位，拉高释放 |
| `softRstN` | 低有效 | 寄存器电平。上电默认 1；写 0 复位数据通路，写 1 后由 `GmacRst` 拉长再释放 |
| `rstNIn` / `rstNOut` | 低有效 | 源时钟域 / 目的时钟域复位 |
| `forceAN` / `forceBN` | 低有效 | 额外把该侧 FIFO 保持在复位；平时接 1 |
| 不带 `N` 的复位名 | 高有效 | 本工程不新增 |

`VerilogIpLib/IP_*` 的端口名保持 `reset`、`resetIn`、`resetOut`、`resetA`、`resetB`，极性仍是低有效，不按本条改名。

分域同步做在向下例化的那一层，见第 4.12 节。

### 2.3 参数

要在例化时从上层改的用 `parameter`。只在本模块内部用的宽度、状态编码、深度，一律 `localparam`。

### 2.4 例化

例化时列出该模块的全部端口，顺序与模块端口定义一致。

没有用到的输出用空接 `()`，不要再声明一根不读的 wire。输入必须接入。下例只摘空接的几个输出，其余端口同样按定义列全。

```verilog
    IP_AsyncFifo #(
        .DATA_WIDTH (FIFO_W),
        .FIFO_DEPTH (FIFO_DEPTH)
    ) uTxFifo (
        .fifoAlEmpty     (),
        .fifoValid       (fifoValid),
        .overRun         (),
        .underRun        (),
        .fifoEmpty       (fifoEmpty),
        .fifoFull        (fifoFull)
    );
```

### 2.5 数据口

接收数据的模块，在文件头或 Interface 注释里写清整拍谁先上线、单个字节哪一端先发。写法见第 5.4 节。

---

## 3. 信号命名

信号名小驼峰。变量、端口、参数默认无符号。需要 `signed` 时，在声明行注明原因，见第 5.3 节。

### 3.1 后缀速查

| 后缀 / 前缀 | 含义 | 类型倾向 |
|------|------|----------|
| `Cnt` | 计数器 / 累计 / 峰值锁存 | `reg` / `output reg` |
| `Int` | 对应 reg 的下一拍组合值 | `wire`，只用 `assign` |
| `Nxt` | 状态机 `always @(*)` 里的下一拍 | `reg` |
| `F1`/`F2`/`F3`… | 流水延迟。数字是晚的拍数，当前拍不加后缀 | `reg` |
| `irq*` | 中断（规划约定，非 `Intr`） | `irq` / `irqMask` / `irqRaw` 等 |
| `N`（复位名结尾） | 低有效复位。不带 `N` 为高有效复位 | `rstN`、`softRstN`、`rstNCore` |

### 3.2 计数器（Cnt）

- 计数类寄存器、计数类输出端口名后缀 **`Cnt`**。
- 示例：`txOverRunCnt`、`txUnderRunCnt`、`txVbErrCnt`、`byteCnt`、`txFifoPeakCnt`。
- 对外计数口可直接用 **`output reg …Cnt`**，由 always 写入；不要另建内部 reg 再 `assign` 到端口。
- 下一拍与锁存怎么写，见第 4.6 节。位宽宏见第 4.7 节。

### 3.3 Int（仅配合 Reg）

- **`xxxInt`** 只用于「有对应 `reg xxx`（或 `output reg xxx`）的下一拍组合逻辑」，**类型必须是 `wire`，只用 `assign`**。不要在 `always` 里给 `*Int` 赋值。
- 普通组合 wire（无对应 reg）**不加** `Int`。
- 状态机 `always @(*)` 里用 `case` 写出的下一拍是 `reg`，后缀用 **`Nxt`**，不用 `Int`。见第 4.8 节。
  - 有 Int：`byteCntInt` → `byteCnt`，`txOverRunCntInt` → `txOverRunCnt`
  - 无 Int：`canBeat`、`fifoPush`、`headVb`、`rsFire` 等

### 3.4 打拍（F1 / F2 / F3…）

只做延迟的寄存器，在信号名后加 **`F1` / `F2` / `F3`**。数字是比当前拍晚的拍数。当前这一拍不加后缀，写成 `xx`、`xxF1`、`xxF2`。

不要写成 `xx0`、`xx1`、`xx2`。也不要给每一级再套 `*Int`。流水线在时序 `always` 里直接移位：

```verilog
    oct   <= decOctet;
    octF1 <= oct;
    octF2 <= octF1;
    octF3 <= octF2;
```

同一拍一起移位、表达同一件事的侧带（数据、K、invalid）放进同一个 `always`。

单拍延迟同样加在原名后面，例如 `underRunGap` → `underRunGapF1`。被打拍的组合源本身不加 `Int`，除非它同时还是某个寄存器的下一拍输入。

### 3.5 中断（irq*）

- GMAC 中断相关命名以 **`Gmac结构规划.md` / `GmacIf.vh`** 为准，统一用 **`irq*`**（小驼峰前缀），**不用** `Intr` 后缀。
- 典型信号：`irq`、`irqMask`、`irqRaw`、`irqEvt`、`irqClr`。
- `irqRaw` 各位含义见 `GmacIf.vh`（电平状态位 + 计数变化事件位）；与计数 `Cnt`、打拍 `F1/F2/F3`、下一拍 `Int` 区分开。

---

## 4. 逻辑写法

### 4.1 可读性优先

代码读得懂、改得动，优先于机械套用本文。某一条会让逻辑变绕、信号变多、或和相邻模块对不上时，按更清楚的写法来，并在该处留一句注释说明偏离了哪一条、为什么。命名、单 always 写源、跨时钟必须用同步器这些会直接写错功能的约定，仍然要守住。

### 4.2 单 always 写源

- **一个变量只在一个 always 块内被写**。
- 禁止同一 reg 在多个 always 中赋值。
- 能否放进同一个 `always`，先看功能，再看时钟。时钟和复位相同只是必要条件。块里的寄存器必须功能类似，或者彼此极强相关：离开对方，这条逻辑就不成立。不能因为都在同一个时钟上做 `Reg <= RegInt` 或打拍，就合成一块。
- 可以写在一起：同一级流水的数据和它的 `valid`、侧带；一个计数和只为这个计数服务的门槛标志；同一拍一起打拍、表达同一件事的一组信号。
- 必须分开：状态、运行不一致、译码结果。它们可以共用时钟，但各干一件事。计数器的下一拍各自 `assign`，锁存按第 4.6 节集中到后面一个 `always`，不要拆进上面三类。
- 功能已经相同，并且每条都只是 `Reg <= RegInt`，或只是打拍 `xxxF1 <= src`（再拍 `xxxF2 <= xxxF1`）时，放进同一个 `always`。不要一个寄存器一个 `always`。
- 时序 `always` 里不要再写下一拍的 `case` / `if` 决策。下一拍在组合段算成 `*Int`（`assign`）或状态机的 `*Nxt`，时序段只采样。
- 时钟或复位不同的寄存器分开写。

相同功能的逻辑写在一起，形成一块（Push / Pop / 计数 / CDC 等）。相关变量声明也按功能分组，见第 5.2 节。

```verilog
    assign byteCntInt = rsFire ? (byteCnt + 4'd1) : byteCnt;
    assign inPktInt   = (inPkt | rsFire) & ~clr;

    always@(posedge clkTx or negedge rstNTx) begin
        if (!rstNTx) begin
            byteCnt <= 4'd0;
            inPkt   <= 1'b0;
        end
        else begin
            byteCnt <= byteCntInt;
            inPkt   <= inPktInt;
        end
    end
```

### 4.3 阻塞与非阻塞

时序 `always` 里用非阻塞 `<=`。`<=` 可以用于寄存器采样、打拍、计数锁存，不另加限制。

阻塞 `=` 只留在组合 `always @(*)` 的 case 写法里：入口先赋保持值，再用 `case` 改写，见第 4.8 节的 `stateNxt`。其它地方少用 `=`。下一拍能写成 `assign *Int` 或 `assign *Nxt` 时，不要再开一个只有 `if` 的组合 `always` 去用 `=`。

### 4.4 `always @(*)` 赋全，避免锁存

`always @(*)` 里被赋值的每个变量，在所有分支上都要有赋值，包括 `default`。入口先写成保持或确定的默认值，再在 `case` / `if` 里改写需要变的项。缺一条就会综合出锁存。

```verilog
always @(*) begin
    stateNxt = state;
    case (state)
        ST_IDLE: if (startIdle) stateNxt = ST_PRE;
        ST_PRE:  if (fire)      stateNxt = ST_DATA;
        default: stateNxt = ST_IDLE;
    endcase
end
```

### 4.5 `case` 都写 `default`

`case`、`casex`、`casez` 都写 `default`，分支已经列全也写。组合 `always` 里 `default` 给出确定值；状态转移里 `default` 回到复位态。

### 4.6 计数器写法

- 计数用来离开某个状态，或停在上限时，边界用 **`>=` / `<=`**，不用 **`==` / `!=`** 卡一个点。计数被干扰跳过那个点时，`==` 会一直等，状态机停住。上限为 0 时先排除再做减 1，避免绕回后条件永远成立。
- 内部计数器的下一拍用 **`assign`** 写成 `*CntInt`，加数的位宽与计数器一致。时序 `always` 只做锁存，不在里面写加 1 或清零。

```verilog
assign byteCntInt = fire ? byteCnt + 16'd1 : byteCnt;
```

- 要清零时，按有效级往条件上加：优先级高的写在前面。清零优先于加 1，都不成立则保持。

```verilog
assign byteCntInt = clr  ? 16'd0 :
                    fire ? byteCnt + 16'd1 :
                           byteCnt;
```

- `assign` 紧挨着对应计数器的功能块。这样的计数器有多个时，锁存集中到这些 `assign` 后面的**一个**时序 `always`，里面只写 `Cnt <= CntInt`。不要每个计数器各占一个 `always`，也不要把状态、运行不一致、译码结果写进这个锁存块。

```verilog
assign commaCntInt = cgBad ? 2'd0 :
                     lock  ? commaCnt + 2'd1 :
                             commaCnt;
assign goodCntInt  = cgBad ? 2'd0 :
                     hold  ? goodCnt + 2'd1 :
                             goodCnt;

always@(posedge clkRx or negedge rstN) begin
    if (!rstN) begin
        commaCnt <= 2'd0;
        goodCnt  <= 2'd0;
    end
    else begin
        commaCnt <= commaCntInt;
        goodCnt  <= goodCntInt;
    end
end
```

推荐写法（对齐 `IP_AsyncFifo`）：

```verilog
    assign readAddrInt = fifoPop ? readAddr + {{(ADDR_WIDTH){1'd0}},1'd1}: readAddr;
    always@(posedge clockOut or negedge reset)begin
        if(!reset)begin
            readAddr <= {(ADDR_WIDTH+1){1'd0}};
        end
        else begin
            readAddr <= readAddrInt;
        end
    end
```

### 4.7 计数位宽宏

- 计数位宽由多个宏控制，按用途选用，勿混用单一宏：

| 宏 | 宽度 | 典型用途 |
|----|------|----------|
| `` `GMAC_CNT_W8` `` | 8 | 水位、峰值等 |
| `` `GMAC_CNT_W16` `` | 16 | 中等计数 |
| `` `GMAC_CNT_W32` `` | 32 | 错误/事件累计等 |

- 定义位置：`GmacRtl/GmacIf.vh`。
- `` `GMAC_CNT_W` `` 保留为 `` `GMAC_CNT_W32` `` 别名，仅作兼容；新代码请显式写 8/16/32。

### 4.8 单 bit：置 1 后保持到某事件

单 bit 状态若语义是「某条件成立则变为 1，之后保持，直到某事件真正发生才回到 0」，下一拍用一条 `assign` 写完，不要嵌套三目。

```verilog
assign flagInt = (flag | set) & ~clr;
```

| 情况 | 结果 |
|------|------|
| `set` 成立且 `clr` 不成立 | 1 |
| `flag` 已为 1 且 `clr` 不成立 | 保持 1 |
| `clr` 成立 | 0（同拍 `set` 也成立时，清零优先） |
| `set`、`clr` 都不成立 | 保持原值 |

- `set`：置 1 的条件。
- `clr`：必须是事件已经发生（握手或发送成立）。只写「看起来到了结束条件」不够；反压、本拍并未发出时 `clr` 应为 0，状态继续保持。
- 运算符用 `&`、`|`、`~`。

例：`inPkt` 在发出一拍后置 1，保持到**发出**带 Efp 的末字节：

```verilog
assign inPktInt = (inPkt | rsFire) & ~(rsFire & isLastByte & headEfp);
```

清零项是 `rsFire & isLastByte & headEfp`。若写成 `(inPkt | rsFire) & ~(isLastByte & headEfp)`，停在末字节等待发送时会提前掉到 0，下一拍可能再次冒出 Sfp。

### 4.9 状态机：默认两段式，Moore 或 Mealy

状态机默认**两段式**，不在时序 `always` 里写状态转移。本拍必须锁存输入、输出要晚一拍才出现、两段式对不上时，用第 4.9.1 节的三段式。能用两段式就不用三段式。

书写顺序固定为三步，让状态转移先被看到：

1. **`state <= stateNxt`**：单独一个时序 `always`，只采样状态。
2. **`stateNxt` 赋值**：单独一个 `always @(*)`。入口先 `stateNxt = state`，再 `case (state)` 改写。不要把计数、CRC、标志写进这个 `case`。
3. **按状态产生的其他块**：输出译码、输出计数、内部计数、CRC、标志。计数器按第 4.6 节写 `assign *CntInt`，锁存集中到一个时序 `always`。其余寄存器按第 4.2 节拆开：功能类似或极强相关的才共用一块，不要把计数器、CRC、标志仅因时钟相同写在一起。

| 段 | 写法 | 内容 |
|----|------|------|
| 状态寄存器 | `always @(posedge clk or negedge rstN)` | 只写 `state <= stateNxt`。放在状态机逻辑的最前面 |
| 状态转移 | 单独一个 `always @(*)` | 紧跟状态寄存器，只给 `stateNxt` 赋值 |
| 其他下一拍 | 另开 `always @(*)` | 按功能分组。入口先保持，避免锁存 |
| 其他寄存器 | 按时序功能拆开 | 计数器按第 4.6 节集中锁存。其余只合并功能类似或极强相关的寄存器，都只写 `Reg <= RegNxt` |

**编码用独热码**：每个状态一位，`localparam` 写成 `7'b0000001` 这种只有一位为 1 的常量。复位态放在 bit 0。非法编码在 `stateNxt` 的 `default` 收回复位态。`case` 一律写 `default`，见第 4.5 节。

按输出与输入的关系选型：

- **Mealy**：本拍输出由**当前状态和当前输入**共同决定。用 `assign` 或 `case (state)` 从当前 `state` 译码。直通数据、握手当拍生效时用 Mealy。本拍输出不要用 `stateNxt`。能写成一位或起来的输出用一条 `assign`，项与项之间用 `|`。
- **Moore**：输出只由**当前状态**决定。用 `assign` 或 `case (state)` 从 `state` 译码。

```verilog
    localparam [2:0] ST_IDLE = 3'b001;
    localparam [2:0] ST_PRE  = 3'b010;
    localparam [2:0] ST_DATA = 3'b100;

    always@(posedge clk or negedge rstN) begin
        if (!rstN)
            state <= ST_IDLE;
        else
            state <= stateNxt;
    end

    always @(*) begin
        stateNxt = state;
        case (state)
            ST_IDLE: if (startIdle) stateNxt = ST_PRE;
            ST_PRE:  if (fire)      stateNxt = ST_DATA;
            default: stateNxt = ST_IDLE;
        endcase
    end

    assign validOut = startIdle | state[1] | (state[2] & cdcValid);
```

#### 4.9.1 三段式

两段式的数据输出是本拍组合译码，输入和输出在同一拍。下面两种需求对不上：

- 这一拍收下的数据，后面几拍还要用（例如前导码期间先把 SFP 那一拍锁住）。
- 对外数据要晚一拍才出现，不能和输入同拍直通。

这时用三段式。书写顺序在两段式的三步上，把「输出译码」改成「输出的下一拍 + 输出寄存器」：

1. **`state <= stateNxt`**：单独一个时序 `always`，只采样状态。
2. **`stateNxt`**：单独一个 `always @(*)`，只写状态转移。
3. **输出寄存器**：组合段写 `dataNxt`、`validNxt` 等，时序段只做 `out <= outNxt`。寄存器在做出决定的下一拍更新。

时序块里仍然不写 `case` / `if` 决策。独热码、`stateNxt` 与其它 `*Nxt` 分开。计数器按第 4.6 节集中锁存。其余寄存器按第 4.2 节按功能合并，都跟两段式一样。

```verilog
    always @(*) begin
        dataNxt  = rsData;
        validNxt = rsValid;
        if (startFire) begin
            dataNxt  = 8'h55;
            validNxt = 1'b1;
        end
    end

    always@(posedge clk or negedge rstN) begin
        if (!rstN) begin
            rsData  <= 8'h00;
            rsValid <= 1'b0;
        end
        else begin
            rsData  <= dataNxt;
            rsValid <= validNxt;
        end
    end
```

输入侧带若要在 Valid 且未被反压时留下，用 `assign beatInt = inFire ? beatIn : beat`，不要在时序 `always` 里写这句选择。

### 4.10 FIFO 桥接、水位与反压

适用于跨钟 FIFO 桥接类模块（如 `UsrRsCdcTx`）：

| 项 | 约定 |
|----|------|
| 结构 | 以 FIFO 为界：前 Push、后 Pop，分区清晰 |
| Push | 对外反压看 `fifoAlFull`；内部 Push 看 `fifoFull`。反压后仍来 Valid 记错误计数 |
| Vb | Push 侧非法（0 或 >16）钳位到合法范围并记错；**Pop 侧信任 FIFO 内 Vb，不再钳位** |
| Pop | 用计数从 FIFO 预取端（`fifoPopData`，即队头）选数据输出，并产生 Sfp/Efp 等侧带 |

`IP_AsyncFifo` / `IP_Fifo` 的读侧开门门槛 `fifoTxFifoThrd`（TxThrd）和几乎满门槛 `fifoAlFullThrd`（AlFull）最好用配置寄存器控制。使用处不要写成常量或 `localparam`。

- 寄存器放在 `GmacReg`，在管理时钟上读写。
- 用到该阈值的模块从接口输入接收，模块内不自造这组寄存器。
- 输入时钟和使用时钟不同时，在接到 FIFO 之前按第 4.11 节做多 bit 同步，再按指针宽度截取。源数据保持稳定，直到使用时钟采到稳定值；跳变过程中的中间值不能拿去当门槛。

```verilog
input [7:0] gbxTxFifoThrd;

IP_DataGraySync #(.DATAWIDTH(8)) uGbxTxFifoThrd (
    .dataA  (gbxTxFifoThrd),
    .clockB (clkSdsTx),
    .dataB  (gbxTxFifoThrdSds)
);

assign txThrd = gbxTxFifoThrdSds[PTR_W-1:0];
```

对外反压由 `fifoAlFull` 产生，内部 Push 看 `fifoFull`。流水上可能还有已经收下、尚未写入的拍，AlFull 到 Full 之间的空位留给这些在途数据。Push 若也看 AlFull，这段裕量就用不上。

`UsrRsCdcTx`：`usr2CdcPktBusStall` 来自 `fifoAlFull`，`fifoPush` 为过滤后的 Valid 且 `~fifoFull`。

### 4.11 跨时钟

跨时钟只用下面几类，按信号形态选：

| 信号 | 用法 |
|------|------|
| 单 bit 电平 | `IP_Sync`。目的时钟必须采得到源电平：源电平要维持到 `clockOut` 至少采到一次。源脉冲窄、目的钟更慢时，先加宽或改走脉冲同步 |
| 单 bit 脉冲 | `IP_BitPluseSync`。脉冲之间留出同步器所需间隔 |
| 多 bit | `IP_DataGraySync`。源数据保持稳定，直到目的时钟采到稳定值后再使用 |
| Valid 驱动的数据 | `IP_AsyncFifo` |
| 用握手更直接时 | 允许用握手把数据或事件递到另一时钟 |

慢变的多 bit 控制（水位阈值等）也走 `IP_DataGraySync`，见第 4.10 节。

### 4.12 复位同步放在例化层

`GmacRst` 仍在芯片顶产生 `rstNCore`。某个模块再向下例化多个子模块时，用 `IP_ResetSync` 把复位同步到各子模块的时钟，再把同步后的低有效复位接进去。同步写在这一层的 Logic 前部。子模块端口收到的复位已经属于本时钟，内部不再例化 `IP_ResetSync`。

### 4.13 时钟不在逻辑里生成

`always` 的时钟用端口时钟或已经在时钟网络上的时钟。禁止用门、`assign`、三目或数据去拼出一根时钟再送进 `always`。

需要门控或在几路时钟里选择时，用对应的时钟 IP，或器件库里的时钟单元。

### 4.14 函数与任务只写组合

`function` 和 `task` 只描述组合逻辑：纯计算、按输入选出输出。里面不写时钟沿、延时、非阻塞赋值，也不去改时序状态。需要寄存的结果放在外面的时序 `always` 里采样。

### 4.15 `generate` 的 `begin` 带块名

`generate` 里每个 `begin` 后面写块名，便于层次和调试对上某一路。

```verilog
generate
    genvar i;
    for (i = 0; i < BYTE_N; i = i + 1) begin : byteLane
        assign byteOut[i] = data[i*8 +: 8];
    end
endgenerate
```

### 4.16 为错误路径加断言

模块里对不该发生的情况加仿真检查，方便验证直接看到运行错误。典型情况：反压之后仍来 Valid、FIFO 满仍 Push、`Vb` 越界、状态落到非法编码。

断言放在对应功能块末尾，只在仿真里生效，不参与综合，也不为它改数据通路。工具支持时用 `assert`；只吃 Verilog 时用综合会丢掉的等价检查。

### 4.17 运算和比较的位宽写齐

比较、加减的两边位宽要在表达式里写齐。窄的一边用拼接把高位补 0，补到和宽的一边一样。无符号比较按补零后的值做。位宽不同的信号不要直接放在 `>`、`>=`、`<`、`<=`、`==`、`+`、`-` 两边，让工具自己扩展。

```verilog
assign ifgSkip = fcsLast & (tailStallCnt >= {1'd0, ifgCntLock});
```

`tailStallCnt` 为 5 bit，`ifgCntLock` 为 4 bit。计数器自加 1 时，加数位宽与计数器一致，见第 4.6 节。

### 4.18 加法留进位，减法处理小减小

加法的结果要留出进位。两个 N bit 无符号数相加，和写成 N+1 bit，最高位是进位。自加 1 的计数器若上限到不了全 1，和仍用计数器位宽，由第 4.6 节的上限判断拦住，不另加进位位。

```verilog
wire [8:0] sum;
assign sum = {1'b0, a} + {1'b0, b};
```

`a`、`b` 各 8 bit。最高位是进位，不丢。

减法要处理被减数小于减数。无符号直接相减会绕成大数。先比较：被减数大于等于减数才减，否则结果为 0。结果需要保留正负时，用 `signed`，并在声明行说明原因，见第 5.3 节。计数回绕是故意的，在该处留一句注释。

```verilog
assign diff = (a >= b) ? (a - b) : 8'd0;
```

`a`、`b`、`diff` 同为 8 bit。`a < b` 时结果是 0，不绕回。

---

## 5. 注释

### 5.1 模块骨架

模块只使用三段 `#` 横线划分 **Interface / Value / Logic** 三层，顶格书写。Logic 内部的功能块注释不得再用这套 `#` 结构（不要写成与 `//Logic` 相同的横线），以免和模块骨架混在一起。

Logic 内功能块注释保持三段横线，把 `#` 换成 `=`，仍然顶格：

```verilog
//======================================================
// Pop @ clkTx：从 fifoPopData 选字节，产生 sfp/efp
//======================================================
```

**Logic 区内的代码整体再缩进 4 格**（相对模块顶格），层次与上面的结构注释分开。包括 `assign`、`always`、`generate`、子模块例化。Interface / Value 的端口与声明保持顶格，不套这 4 格。

### 5.2 功能块

- **相同功能的逻辑写在一起**，形成一块（Push / Pop / 计数 / CDC 等）。
- **仅在该功能块前写一段注释**，说明本块做什么；块内不要碎注释刷屏。
- **相关变量声明也聚合在一起**，并在旁或块首**简要描述其功能**（Value 区按功能分组，勿散落无序）。

推荐分区示意：

```verilog
//######################################################
//Value
//######################################################
// Push 侧：写 FIFO 与违约计数
wire        fifoPush;
wire        pushViolate;
...
// Pop 侧：取字节与包状态
reg         inPkt;
reg  [3:0]  byteCnt;
...

//######################################################
//Logic
//######################################################

//======================================================
// Push @ clkUsr：有 Valid 就写；反压时不应再来 Valid
//======================================================

    assign fifoPush = ...;
    always@(posedge clkUsr or negedge rstNUsr) begin
        ...
    end

//======================================================
// Pop @ clkTx：从 fifoPopData 选字节，产生 sfp/efp
//======================================================

    assign headVb = ...;
```

### 5.3 声明行

状态、跨域之后的结果、对外语义、门槛和容易看错极性的信号，在声明行注明含义和何时有效。功能块做什么仍按第 5.2 节写在块头。普通中间线不必逐根加注释。

需要有符号数时，在声明行注明为什么用 `signed`（差值、补码比较等）。没有这句注释的信号按无符号书写和比较。

```verilog
wire signed [7:0] disp; // 失调是有符号差值，比较和累加按补码
```

偏离某一条写法时，同样在该处留一句注释，说明偏离了哪一条、为什么。见第 4.1 节。

### 5.4 数据口的字节序

接收数据的模块，在文件头或 Interface 注释里写清两件事：

- 整拍数据里哪个字节先上线，并点明总线切片。例如用户侧 128 bit 为高字节先发，`data[127:120]` 最先出现。
- 单个字节里哪一端先发。例如 GMII / 8B10B 路径为 LSB 先出，`TXD[0]` 是先发的位。

与 `Gmac结构规划.md` 已有约定相同的模块，注释里写上该约定和切片，方便读模块的人不用再翻规划。
