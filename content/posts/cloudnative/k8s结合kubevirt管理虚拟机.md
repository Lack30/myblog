---
title: "K8s结合kubevirt管理虚拟机"
date: 2022-06-06T12:19:12+08:00
lastmod: 2022-06-06T12:19:12+08:00
draft: true
keywords: []
description: ""
tags: ["k8s"]
categories: ["云原生"]
author: "Lack"
---

启动 vnc 代理
```bash
virtctl vnc win10 --address=0.0.0.0 --proxy-only
```

执行命令之后，使用 vnc 连接到虚拟机: 192.168.1.21:36369

如果选择硬盘时没有一个可供使用，就需要安装 virtio 驱动

virtio 驱动挂载进来后，直接点击*加载驱动程序*就可以安装驱动了:

![](https://raw.githubusercontent.com/xingyys/myblog/main/posts/images/20220606122142.png)

继续安装



