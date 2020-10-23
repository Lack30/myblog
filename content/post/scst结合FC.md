---
title: "Scst结合FC"
date: 2020-08-06T15:21:50+08:00
lastmod: 2020-08-06T15:21:50+08:00
draft: false
keywords: []
description: ""
tags: ["iscsi"]
categories: ["运维"]
author: ""

# You can also close(false) or open(true) something for this content.
# P.S. comment can only be closed
comment: true
toc: true
autoCollapseToc: true
postMetaInFooter: false
hiddenFromHomePage: false
# You can also define another contentCopyright. e.g. contentCopyright: "This is another copyright."
contentCopyright: false
reward: false
mathjax: false
mathjaxEnableSingleDollar: false
mathjaxEnableAutoNumber: false

# You unlisted posts you might want not want the header or footer to show
hideHeaderAndFooter: false

# You can enable or disable out-of-date content warning for individual post.
# Comment this out to use the global config.
#enableOutdatedInfoWarning: false

flowchartDiagrams:
  enable: false
  options: ""

sequenceDiagrams: 
  enable: false
  options: ""

---

SCST 是 iscsi 的一种实现方式，它既可以使用 iscsi 协议共享本地磁盘，同时也支持 [FC](https://en.wikipedia.org/wiki/Fibre_Channel) 协议。<br />FC 协议需要硬件 FC HBA 卡的支持。  SCST 和 FC 的环境搭建如下看[这里](http://scst.sourceforge.net/qla2x00t-howto.html) 。<br />

<a name="a69f6882"></a>
# 环境配置

<br />接下来 SCST 和 FC 的使用。<br />首先需要有 scst 的环境：<br />![image.png](https://cdn.nlark.com/yuque/0/2020/png/551536/1596161682842-be237776-e1ae-4e4b-be0b-c7676740a2f0.png#align=left&display=inline&height=54&margin=%5Bobject%20Object%5D&name=image.png&originHeight=107&originWidth=860&size=13088&status=done&style=none&width=430)<br />保证 linux 内核中加载了 qla。使用 scstadm 查看所支持的驱动：<br />![image.png](https://cdn.nlark.com/yuque/0/2020/png/551536/1596161697676-a7148b6a-2fa1-4e79-945c-d5f31641dc47.png#align=left&display=inline&height=30&margin=%5Bobject%20Object%5D&name=image.png&originHeight=59&originWidth=797&size=5866&status=done&style=none&width=398.5)<br />如果使用 FC 去共享磁盘，scst 需要创建和 FC 设备对应的 target。FC 设备和 target 属于一对一关系，而且创建 target 的名称要和 FC 设备的 ID 相同。<br />查看 FC 设备的 ID 可以用以下的方式：<br />1.查看内核中 qla2x00t (`/sys/kernel/scst_tgt/targets/qla2x00t`) 目录下的内容<br />![image.png](https://cdn.nlark.com/yuque/0/2020/png/551536/1596161723584-376d456c-f9ca-4a9e-8414-8b4195965ee7.png#align=left&display=inline&height=53&margin=%5Bobject%20Object%5D&name=image.png&originHeight=105&originWidth=895&size=13311&status=done&style=none&width=447.5)<br />2.直接查看 FC 设备的 port_id (`/sys/class/fc_host/hostx/port_name`)，<br />![image.png](https://cdn.nlark.com/yuque/0/2020/png/551536/1596161736093-b87c3fef-99eb-471c-abfb-65e9631244a1.png#align=left&display=inline&height=31&margin=%5Bobject%20Object%5D&name=image.png&originHeight=63&originWidth=831&size=6591&status=done&style=none&width=415.5)
<a name="618af87a"></a>
# 配置 FC


<a name="2034ea04"></a>
## SCST 服务端配置

<br />创建 target, FC 设备和 target 一对一。<br />

```bash
scstadmin -add_target 50:01:10:a0:00:16:bf:30 -driver qla2x00t
```

<br />创建 device 对应本地的块文件<br />

```bash
scstadmin -open_dev fc1 -handler vdisk_fileio -attributes filename=/dev/sdc
```

<br />创建 group，scst 中的 group 用于限定共享的对象。<br />

```bash
scstadmin -add_group group1 -target 50:01:10:a0:00:16:bf:30 -driver qla2x00t
```

<br />创建 lun，因为 scst target 和 FC 设置是一对一关系，所以当需要在同一个 FC 下共享多个磁盘给不同的客户端时就需要在同一个 target 下创建多个 lun。<br />

```bash
scstadmin -add_lun 0 -target 50:01:10:a0:00:16:bf:30 -driver qla2x00t -group group1 -device fc1
```

<br />指定共享的客户端，这里需要知道客户端 FC 设备对应的 ID。<br />查看 `/sys/class/fc_host/hostx/port_name`<br />![image.png](https://cdn.nlark.com/yuque/0/2020/png/551536/1596161756993-045d1cd9-073e-443b-a5c0-c83ccd843812.png#align=left&display=inline&height=28&margin=%5Bobject%20Object%5D&name=image.png&originHeight=56&originWidth=799&size=6549&status=done&style=none&width=399.5)
```bash
scstadmin -add_init 50:01:10:a0:00:16:bf:34 --target 50:01:10:a0:00:16:bf:30 -driver qla2x00t -group group1 -device fc1
```

<br />启动 target<br />

```bash
scstadmin -enable_target 50:01:10:a0:00:16:bf:30 --driver qla2x00t
```

<br />最后将改动写入配置文件<br />

```bash
scstadmin -write_config /etc/scst.conf
```

<br />（如果对应的客户端已经属于某个已存在的 group，则复用这个 group，并选择不存在的 lun id）
<a name="f4f5ae5e"></a>
## 客户端配置
扫描 scst 主机<br />

```bash
echo "- - -" > /sys/class/scst_host/host3/scan
```

<br />其中 `"- - -"` 这三个值代表通道，SCSI目标ID和LUN。破折号充当通配符，表示“重新扫描所有内容”。`host3` 和 `/sys/class/fc_host/host3` 相对应。执行命令后客户端增加了一块磁盘。<br />
<br />


