# 深入理解计算机系统


## 计算机系统漫游

计算机系统是由`硬件`和`软件`组成。

### 1.1 信息就是位 + 上下文

系统中所有的信息——包括磁盘文件、内存中的程序、内存中存放的用户数据以及网络上传送的数据，都是由一串 bit 表示的。区分不同数据对象的唯一方法是我们读到这些数据对象是的上下文。

### 1.2 程序被其他程序翻译成不同的格式

![编译系统](https://raw.githubusercontent.com/xingyys/myblog/main/posts/images/20210831190321.png)

### 1.3 了解编译系统如何工作是大有益处的

为什么程序员必须要知道编译系统是如何工作的?

- 优化程序性能。
- 理解链接时出现的错误。
- 避免安全漏洞。

### 1.4 处理器读并解释储存在内存中指令

系统硬件组成

![](https://raw.githubusercontent.com/xingyys/myblog/main/posts/images/20210901205400.png)

1. 总线: 贯穿整个系统的一组电子管道，称作总线，他携带信息字节并负责在各个部件间传递。
2. I/O 设备: 系统与外部世界的联系通道。每个 I/O 设备都通过一个控制器或者适配器与 I/O 总线相连。控制器和适配器之间的区别主要在于它们的封装方式。控制器是 I/O 设备本身或者系统的主印制电路板上的芯片组。而适配器则是一块插在主板插槽上的卡。
3. 主存: 主存是一个临时存储设备，在处理执行程序时，用来存放程序和程序处理的数据。从物理上来说，主存是由一组动态随机存储存储器 (DRAM) 芯片组成的。从逻辑上来说，存储器是一个线性的字节数组，每个字节都有其唯一的地址(数组索引)，这些地址是从零开始的。
4. 处理器：中央处理单元 (CPU)，简称处理器，是解释(或)执行存储在主存中指令的引擎、处理器的核心是一个大小与一个字的存储设备(或寄存器)，称为程序计数器(PC)。在任何时刻，PC 都指向主存中的某条机器语言指令。

系统执行一个 `Hello World` 程序时，硬件运行流程。

1. 键盘输入命令时，shell 程序将字符逐一读入寄存器，再存放到内存中。
2. 键入回车键后，shell 执行一系列指令来加载可执行的 hello 文件，将 hello 目标文件中的代码和数据从磁盘复制到内存。
3. 处理器开始执行 hello 程序 main 程序中的机器语言指令。
4. 这些指令将输出的字符串中的字节从主存复制到寄存器文件，再从寄存器文件中复制到显示设备，最终显示在屏幕上。

### 1.5 高速缓存至关重要

系统运行时会频繁的挪动信息，而不同存储设备之间的读写性能有严重偏差 (从寄存器中读取数据比从主存中读取快 100 被，从主存中读取又比磁盘中快 1000 万倍)。所以不同存储设备间需要高速缓存来提供系统运行速度。

> 这里的高速缓存是相对概念。

### 1.6 存储设备形成层次结构

![](https://raw.githubusercontent.com/xingyys/myblog/main/posts/images/20210901212609.png)

### 1.7 操作系统管理硬件

我们并不直接访问硬件，而是通过操作系统。所有应用程序对硬件的操作尝试都必须通过操作系统。

操作系统有两个基本功能:

- 防止硬件被失控的应用程序滥用。
- 向应用程序提供简单一致的机制来控制复杂而又通常不大相同的低级硬件设备。

操作系统通过几个基本抽象概念来实现这两个功能。

![](https://raw.githubusercontent.com/xingyys/myblog/main/posts/images/20210901214102.png)

进程: 操作系统对一个正在运行的程序的一种抽象。

上下文: 操作系统保持跟踪进程运行所需的所有状态信息，其中包含 PC 和寄存器文件的当前值，以及主存的内存。

在任何一个时刻，单处理器系统都只能执行一个进程的代码。当操作系统决定要把控制权从当前进程转移到某个新进程时，就会进行上下文切换。这一过程有操作系统内核 (kernel) 管理。

![](https://raw.githubusercontent.com/xingyys/myblog/main/posts/images/20210901213718.png)

线程: 现代操作系统中，一个进程实际上可以由多个称为线程的执行单元组成，每个线程都裕兴在进程的上下文中，并共享同样的代码和全局数据。

虚拟机内存是一个抽象概念，它为每个进程提供一个假象，即每个进程都在独占地使用主存，每个进程看到的内存都是一致的，称为虚拟地址空间。

![](https://raw.githubusercontent.com/xingyys/myblog/main/posts/images/20210901214306.png)

虚拟地址空间从下至上依次为:

- 程序代码和数据。对所有的进程来说，代码是从同一固定地址开始，紧接着的是和 C 全局变量相对应的数据位置。代码和数据区是直接按照可执行目标文件的内容初始化的。
- 堆。堆可以在运行时动态地扩展和收缩。
- 共享库。存放 C 标准库和数学库这些共享库的代码和数据。
- 栈。位于用户虚拟地址空间顶部，编译器用它来实现函数调用，它和堆一样在程序运行期间可以动态地扩展和收缩。每次调用一个函数时，栈就会增长，从一个函数返回时，栈就会收缩。
- 内核虚拟内存。地址空间顶部的区域是为内核保留的。不允许应用程序读写这个区域的内容或者直接调用内核代码定义的函数。相反，他们必须调用内核来执行这些操作。

文件就是字节序列！每个 I/O 设备，包括磁盘、键盘、显示器，甚至网络，都可以看成文件。

### 1.8 系统之间利用网络通信

硬件和软件组合成一个系统，而通过网络间不同的主机连接成一个更广大的现代系统。

### 1.9 重要主题

并发 (concurrency): 一个同时具有多个活动的系统。

并行 (parallelism): 用并发来是一个系统运行得更快。

超线程：有时称为同时多线程 (simultaneous multi-threading)，是一项允许一个 CPU 执行多个控制流的技术。

抽象的使用是计算机科学中最为重要的概念之一。这里介绍四个抽象:

- 文件是对 I/O 设备的抽象。
- 虚拟内存是对程序存储器的抽象。
- 进程是对一个正在运行的程序的抽象。
- 虚拟机是对整个计算机的抽象。

## 程序的机器级表示

### 3.1 历史观点

Intel 处理器系列俗称 `x86`。

摩尔定律: 1965 年， Gordon Moore, Intel 公司的创始人根据当时的芯片技术做出推断，预测在未来 10 年，芯片上的晶体管数量每年都会翻一番。这个预测就成为摩尔定律。
![](https://raw.githubusercontent.com/xingyys/myblog/main/posts/images/20210906193611.png)

### 3.2 程序编码

机器级编程重要的两种抽象:

- 由指令级体系结构或指令集架构(Instruction Set Architecture, ISA) 来定义机器级程序的格式和行为，它定义了处理器状态、指令的格式，以及每条指令对状态的影响。
- 机器级程序使用的内存地址是虚拟地址，提供的内存模型看上去是一个非常大的字节数组。

汇编代码非常接近于机器代码，它的主要特点是它用可读性更好的文本格式表示。

程序内存包含：程序的可执行机器代码，操作系统需要的一些信息，用来管理过程调用和返回的运行时栈，以及用户分配的内存块。

一条机器指令只能执行一个非常基本的操作。

### 3.3 数据格式

Intel 中数据格式：

- 字 word: 表示 16 位数据类型
- 双字 double words: 32 位数
- 四字 qoad words: 64 位数

C 语言数据类型在 x86-64 中的大小。在 64 为机器中，指针长 8 字节。
![](https://raw.githubusercontent.com/xingyys/myblog/main/posts/images/20210906202049.png)

大多数`GCC`生成的汇编代码指令都有一个字符的后缀，表明操作数的大小。例如。数据传送指令有四个变种：

- movb: 传送字节
- movw: 传送字
- movl: 传送双字
- movq: 传送四字

### 3.4 访问信息

一个 `x86-64` 的中央处理单元 CPU 包含一组 16 个存储 64 位值的通用目的寄存器，这些寄存器用来存储整数数据和指针。

![](https://raw.githubusercontent.com/xingyys/myblog/main/posts/images/20210907213431.png)

关于寄存器的说明可以参考:

- [X86-64 寄存器和栈帧](https://blog.csdn.net/u013982161/article/details/51347944)
- [x86_64 寄存器介绍](https://lenzhao.com/topic/597acd202e95f0fd0a981868)

大多数指令有一个或多个操作数(operand)，指示出执行一个操作中要使用到的源数据值，以及放置结果的目的位置。

存放操作数的类型：

- 立即数(immediate)，用来表示常数值。格式是 '$' 后面跟一个标准 C 表示法表示的整数。比如 `$-577`或`$0x1F`。
- 寄存器(register)，它表示某个寄存器的内容，用符号 $R_a$ 表示。
- 内存引用，它会根据计算出来的地址(通常称为有效地址)访问某个内存位置。使用 $M_b$[Addr] 表示对存储在内存中从 _Addr_ 开始的 b 个字节值的引用。

多种不同的寻址方式，允许不同形式的内存引用。

Imm($r_b$, $r_i$, s) : 一个立即数偏移 Imm，一个基址寄存器 $r_b$，一个变址寄存器 $r_i$ 和一个比例因子 s，s 必须是 1、2、4、8。基址和变址寄存器都必须是 64 位寄存器。有效地址为 Imm+R[$r_b$]+R[$r_i$]\*s。
![](https://raw.githubusercontent.com/xingyys/myblog/main/posts/images/20210907204700.png)

计算题:
有以下内存地址和寄存器的值:

![](https://raw.githubusercontent.com/xingyys/myblog/main/posts/images/20210907210324.png)

得出以下操作数的值:
| 操作数 | 值 | 注释|
|---|---|---|
|%rax|0x100|寄存器|
|0x104|0xAB|绝对地址|
|$0x108|0x108|立即数|
|(%rax)|0xFF|地址 0x100|
|4(%rax)|0xAB|地址 0x104|
|9(%rax,%rdx)|0x11|地址 0x10C|
|260(%rax,%rdx)|0x13|地址 0x108|
|OxFC(,%rcx,4)|0xFF|地址 0x100|
|(%rax,%rdx,4)|0x11|地址 0x10C|

数据传送指令: 将数据从一个位置复制到另一个位置。

![](https://raw.githubusercontent.com/xingyys/myblog/main/posts/images/20210907211404.png)

源操作数指定的值是一个立即数，存储在寄存器或者内存中。目的操作数指定一个位置，寄存器或者内存地址。

> x86-64 中传送指令的两个操作数不能都指向内存位置，内存间的复制需要两条指令。

`MOV` 的五种可能组合:
```asm
movl $0x4050, $eax        ; Immediate -- Register, 4 bytes
movw %bp, %sp             ; Register -- Register,  2 bytes
movb (%bp, %rcx), %al     ; Memory -- Register,    1 bytes
movb $-17, (%rsp)         ; Immediate -- Memory,   1 bytes
movq %rax, -12(%rbp)      ; Register -- Memory,    8 bytes
```

`MOVZ` 类中指令把目的中剩余的字节填充为0。

![](https://raw.githubusercontent.com/xingyys/myblog/main/posts/images/20210907212410.png)

`MOVS` 类中的指令通过符号扩展来填充，把源操作的最高为进行复制。

![](https://raw.githubusercontent.com/xingyys/myblog/main/posts/images/20210907212339.png)

下面是一个数据传送示例:
```c
long exchange(long *xp, long y)
{
    long x = *xp;
    *xp = y;
    return x;
}
```
执行命令 `gcc -Og -S main.c` 生成以下汇编内容:
```asm
exchange:
        movq    (%rdi), %rax
        movq    %rsi, (%rdi)
        ret
```
可以看出: C 语言的 "指针" 其实就是地址。间接引用指针就是间该指针放在一个寄存器中，然后再内存引用中使用这个寄存器。

最后的两个数据传送操作: 将数据压入程序栈中，从程序栈中弹出数据。

![](https://raw.githubusercontent.com/xingyys/myblog/main/posts/images/20210908212726.png)

```asm
pushq %rbp        ; 栈指针减8，然后将值写到新的栈顶地址。
; 等同于
subq $8, %rsp     ; Decrement stack pointer
movq %rbp, (%rsp) ; Store %rbp on stack
```
操作示意图:
![](https://raw.githubusercontent.com/xingyys/myblog/main/posts/images/20210908213559.png)

```asm
popq %rbp         ; 弹出一个四字的操作包括从栈顶位置读出数据，然后减栈指针加8。
; 等同于
movq %rsp, (%rax) ; Read %rax from stack
addq $8, %rsp     ; Increment stack pointer
```
### 3.5 算术和逻辑操作
指令类 ADD 由四条加法指令组成: `addb` 字节加法、`addw` 字加法、`addl` 双字加法 和 `addq` 四字加法。

这些操作被分成四组: 加载有效地址、一元操作、二元操作和位移。
![](https://raw.githubusercontent.com/xingyys/myblog/main/posts/images/20210908213818.png) 

加载有效地址(load effective address)指令 `leaq` 实际上是 `movq` 指令的变形。它的指令形式是从内存读数据到寄存器，但实际上它根本就没有引用内存。
```c
long scale(long x, long y, long z) {
    long t = x + 4 * y + 12 * z;
    return t;
}
```
得到汇编命令:
```asm
_scale:                                 ## @scale
	.cfi_startproc
## %bb.0:
	pushq	%rbp
	movq	%rsp, %rbp
	leaq	(%rdi,%rsi,4), %rax
	leaq	(%rdx,%rdx,2), %rcx
	leaq	(%rax,%rcx,4), %rax
	popq	%rbp
	retq
```
