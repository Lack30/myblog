---
title: "Scst在线扩容"
date: 2020-04-09T14:59:25+08:00
lastmod: 2020-04-09T14:59:25+08:00
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

SCST 共享的磁盘支持在线扩容。操作如下：
<a name="eNUjo"></a>
# scst 服务端
首先有一块 zfs 存储卷，现在将其容量从 15G 扩展到 20G。
```bash
zfs set volsize=20G tank/vol
```
修改 scst 中 device 的 size 属性
```bash
scstadmin -set_dev_attr device1 -attributes size=21474836480 -noprompt
```
<a name="BPvoN"></a>
# iscsi 客户端
重新扫描 target
```bash
iscsiadm -m node --target <target_name> -R
```
扩展磁盘容量，如果磁盘存储 mount 状态则先 umount。
```bash
resize2fs /dev/sdX
e2fsck -f /dev/sdX
resize2fs /dev/sdX
```
重新挂载，使用 `df` 即可发现磁盘的容量被修改。
<a name="NhF54"></a>
# FC 客户端
重新扫描 FC host
```bash
echo "- - -" > /sys/class/scst_host/hostX/scan
```
扩展磁盘容量如上。

