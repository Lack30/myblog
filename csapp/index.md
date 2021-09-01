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
2. I/O设备: 系统与外部世界的联系通道。每个 I/O 设备都通过一个控制器或者适配器与 I/O 总线相连。控制器和适配器之间的区别主要在于它们的封装方式。控制器是 I/O 设备本身或者系统的主印制电路板上的芯片组。而适配器则是一块插在主板插槽上的卡。
3. 主存: 主存是一个临时存储设备，在处理执行程序时，用来存放程序和程序处理的数据。从物理上来说，主存是由一组动态随机存储存储器 (DRAM) 芯片组成的。从逻辑上来说，存储器是一个线性的字节数组，每个字节都有其唯一的地址(数组索引)，这些地址是从零开始的。
4. 处理器：中央处理单元 (CPU)，简称处理器，是解释(或)执行存储在主存中指令的引擎、处理器的核心是一个大小与一个字的存储设备(或寄存器)，称为程序计数器(PC)。在任何时刻，PC 都指向主存中的某条机器语言指令。

系统执行一个 `Hello World` 程序时，硬件运行流程。
1. 键盘输入命令时，shell 程序将字符逐一读入寄存器，再存放到内存中。
2. 键入回车键后，shell 执行一系列指令来加载可执行的 hello 文件，将 hello 目标文件中的代码和数据从磁盘复制到内存。
3. 处理器开始执行 hello 程序 main 程序中的机器语言指令。
4. 这些指令将输出的字符串中的字节从主存复制到寄存器文件，再从寄存器文件中复制到显示设备，最终显示在屏幕上。

### 1.5 高速缓存至关重要
系统运行时会频繁的挪动信息，而不同存储设备之间的读写性能有严重偏差 (从寄存器中读取数据比从主存中读取快100被，从主存中读取又比磁盘中快 1000 万倍)。所以不同存储设备间需要高速缓存来提供系统运行速度。

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