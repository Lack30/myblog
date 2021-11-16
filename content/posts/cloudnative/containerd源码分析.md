---
title: "Containerd源码分析"
date: 2021-11-16T23:17:49+08:00
lastmod: 2021-11-16T23:17:49+08:00
draft: true
featuredImage: "https://raw.githubusercontent.com/xingyys/myblog/main/posts/images/20210926200427.png"
tags: 
 - 源码分析
 - golang
categories: 
 - 云原生
author: "Lack"
---

从 Kubernetes 1.22 开始，k8s 的容器运行是默认替换成 containerd。有必要深入了解 containerd 的内部实现原理。本篇通过分析 containerd 的代码深入理解其内部原理。

使用的版本为 containerd 1.5。

