---
title: "Linux内存"
date: 2021-10-10T23:54:28+08:00
lastmod: 2021-10-10T23:54:28+08:00
draft: false
tags: 
 - linux
categories: 
 - 笔记
author: "Lack"
---

## 内存地址
x86微处理器的三种不同地址:
- 逻辑地址(logical address): 每一个逻辑地址都由一个段(segment)和偏移量(offset或displacement)组成，偏移量指明了从段开始的地方到实际地址之间的距离。
- 线性地址(linear address)(也称虚拟地址 virtual address): 线性地址通常用十六进制数字表示，值得范围从 0x00000000 到 0xffffffff。可以表示高达 4GB 的地址。
- 物理地址(physical address): 用于芯片级内存单元寻址。他们从微处理器的地址引脚发送到内存总线上的电信号相对应。

内存控制单元(MMU)通过分段单元(segmentation unit)的硬件电路把一个逻辑地址转换成线性地址。通过分页单元(paging unit)的硬件电路把线性地址转化成物理地址。