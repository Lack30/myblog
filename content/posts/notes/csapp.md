---
title: "深入理解计算机系统"
date: 2021-08-31T18:27:27+08:00
lastmod: 2021-08-31T18:27:27+08:00
draft: false
description: ""
featuredImage: "https://raw.githubusercontent.com/xingyys/myblog/main/posts/images/featured-image.png"
tags: 
 - 计算机
categories: 
 - 笔记
author: "Lack"
---

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
### 1.9 重要主题
并发 (concurrency): 一个同时具有多个活动的系统。

并行 (parallelism): 用并发来是一个系统运行得更快。

超线程：有时称为同时多线程 (simultaneous multi-threading)，是一项允许一个 CPU 执行多个控制流的技术。

抽象的使用是计算机科学中最为重要的概念之一。这里介绍四个抽象:
- 文件是对 I/O 设备的抽象。
- 虚拟内存是对程序存储器的抽象。
- 进程是对一个正在运行的程序的抽象。
- 虚拟机是对整个计算机的抽象。