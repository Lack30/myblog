---
title: "Qemu Img命令使用"
date: 2021-01-17T22:35:06+08:00
lastmod: 2021-01-17T22:35:06+08:00
draft: false
keywords: 
 - kvm
description: ""
tags: 
 - kvm
categories: 
 - 虚拟化
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

`qemu-img` 是 QEMU 的磁盘管理工具，它允许用户创建、转化、修改 QEMU 磁盘。
> 注：qemu-img 操作磁盘时需要关闭 kvm 虚拟机，直接在虚拟机运行时修改磁盘可能会导致数据不一致甚至导致磁盘损坏。

# qemu-img 基本命令
## check 
语法: `check [-f fmt] filename`

对磁盘镜像文件进行一致性检查，查找镜像文件中的错误，目前仅支持对“qcow2”、“qed”、“vdi”格式文件的检查。其中，qcow2 是 QEMU 0.8.3版本引入的镜像文件格式，也是目前使用最广泛的格式。qed（QEMU enhanced disk）是从 QEMU 0.14 版开始加入的增强磁盘文件格式，为了避免 qcow2 格式的一些缺点，也为了提高性能，不过目前还不够成熟。而 vdi（Virtual Disk Image）是 Oracle 的 VirtualBox 虚拟机中的存储格式。参数-f fmt 是指定文件的格式，如果不指定格式 qemu-img 会自动检测，filename 是磁盘镜像文件的名称（包括路径）。
```bash
# qemu-img check -f qcow2 sdb.qcow2
No errors were found on the image.
Image end offset: 524288
```

## create 
语法: `create [-f fmt] [-o options] filename [size]`

创建一个格式为 fmt，大小为 size，文件名为filename 的镜像文件。根据文件格式 fmt 的不同，还可以添加一个或多个选项（options）来附加对该文件的各种功能设置，可以使用“-o ?”来查询某种格式文件支持那些选项，在“-o”选项中各个选项用逗号来分隔。

如果 "-o" 选项中使用了 backing_file 这个选项来指定其后端镜像文件，那么这个创建的镜像文件仅记录与后端镜像文件的差异部分。后端镜像文件不会被修改，除非在 QEMU monitor 中使用"commit" 命令或者使用 "qemu-img commit" 命令去手动提交这些改动。这种情况下，size 参数不是必须需的，其值默认为后端镜像文件的大小。另外，直接使用 "-b backfile" 参数也与 "-o backing_file=backfile" 效果相同。

size 选项用于指定镜像文件的大小，其默认单位是字节（bytes），也可以支持k（或K）、M、G、T来分别表示KB、MB、GB、TB大小。另外，镜像文件的大小（size）也并非必须写在命令的最后，它也可以被写在 "-o" 选项中作为其中一个选项。

```bash
# qemu-img create -f qcow2 -o backing_file=sdb.qcow2 sdc.qcow2 10G
qemu-img: warning: Deprecated use of backing file without explicit backing format (detected format of qcow2)
Formatting 'sdc.qcow2', fmt=qcow2 cluster_size=65536 extended_l2=off compression_type=zlib size=10737418240 backing_file=sdb.qcow2 backing_fmt=qcow2 lazy_refcounts=off refcount_bits=16

# qemu-img create -f raw sdd.raw 10G
Formatting 'sdd.raw', fmt=raw size=10737418240
```

## commit 
语法: `[-f fmt] [-t cache] filename`

提交 filename 文件中的更改到后端支持镜像文件（创建时通过 backing_file 指定的）中去。
```bash
# qemu-img commit sdc.qcow2
Image committed.
```
## convert 
语法: `convert [-c] [-p] [-f fmt] [-t cache] [-O output_fmt] [-o options] [-s snapshot_name] [-S sparse_size] filename [filename2 [...]] output_filename`
将fmt格式的 filename 镜像文件根据 options 选项转换为格式为 output_fmt 的名为 output_filename 的镜像文件。它支持不同格式的镜像文件之间的转换，比如可以用 VMware 用的vmdk 格式文件转换为 qcow2 文件，这对从其他虚拟化方案转移到 KVM上 的用户非常有用。一般来说，输入文件格式 fmt 由 qemu-img 工具自动检测到，而输出文件格式 output_fmt 根据自己需要来指定，默认会被转换为与 raw 文件格式（且默认使用稀疏文件的方式存储以节省存储空间）。

其中，"-c" 参数是对输出的镜像文件进行压缩，不过只有 qcow2 和 qcow 格式的镜像文件才支持压缩，而且这种压缩是只读的，如果压缩的扇区被重写，则会被重写为未压缩的数据。同样可以使用 "-o options" 来指定各种选项，如：后端镜像、文件大小、是否加密等等。使用 backing_file 选项来指定后端镜像，让生成的文件是 copy-on-write的增量文件，这时必须让转换命令中指定的后端镜像与输入文件的后端镜像的内容是相同的，尽管它们各自后端镜像的目录、格式可能不同。

如果使用 qcow2、qcow、cow 等作为输出文件格式来转换raw格式的镜像文件（非稀疏文件格式），镜像转换还可以起到将镜像文件转化为更小的镜像，因为它可以将空的扇区删除使之在生成的输出文件中并不存在。

```bash
# qemu-img convert -p -f qcow2 -O raw sdc.qcow2 sdc.raw
    (100.00/100%)

# qemu-img convert -c -p -f raw -O qcow2 sdc.raw sdcc.qcow2
    (100.00/100%)
```

## info 
语法: `[-f fmt] filename`

展示 filename 镜像文件的信息。如果文件是使用稀疏文件的存储方式，也会显示出它的本来分配的大小以及实际已占用的磁盘空间大小。如果文件中存放有客户机快照，快照的信息也会被显示出来。
```bash
# qemu-img info sdc.qcow2
image: sdc.qcow2
file format: qcow2
virtual size: 10 GiB (10737418240 bytes)
disk size: 256 KiB
cluster_size: 65536
backing file: sdb.qcow2
backing file format: qcow2
Format specific information:
    compat: 1.1
    compression type: zlib
    lazy refcounts: false
    refcount bits: 16
    corrupt: false
    extended l2: false
```

## snapshot 
语法: `snapshot [-l | -a snapshot | -c snapshot | -d snapshot] filename`

- "-l" 选项是查询并列出镜像文件中的所有快照
- "-a snapshot" 是让镜像文件使用某个快照
- "-c snapshot" 是创建一个快照
- "-d" 是删除一个快照。

```bash
# qemu-img snapshot -l sdb.qcow2
Snapshot list:
ID        TAG               VM SIZE                DATE     VM CLOCK     ICOUNT
1         sdb-ss1               0 B 2021-01-17 09:14:46 00:00:00.000          0
# qemu-img snapshot -c sdb-ss2 sdb.qcow2
# qemu-img snapshot -l sdb.qcow2
Snapshot list:
ID        TAG               VM SIZE                DATE     VM CLOCK     ICOUNT
1         sdb-ss1               0 B 2021-01-17 09:14:46 00:00:00.000          0
2         sdb-ss2               0 B 2021-01-17 09:15:11 00:00:00.000          0
# qemu-img snapshot -c sdb-ss3 sdb.qcow2
# qemu-img snapshot -l sdb.qcow2
Snapshot list:
ID        TAG               VM SIZE                DATE     VM CLOCK     ICOUNT
1         sdb-ss1               0 B 2021-01-17 09:14:46 00:00:00.000          0
2         sdb-ss2               0 B 2021-01-17 09:15:11 00:00:00.000          0
3         sdb-ss3               0 B 2021-01-17 09:15:21 00:00:00.000          0
# qemu-img snapshot -d sdb-ss2 sdb.qcow2
# qemu-img snapshot -l sdb.qcow2
Snapshot list:
ID        TAG               VM SIZE                DATE     VM CLOCK     ICOUNT
1         sdb-ss1               0 B 2021-01-17 09:14:46 00:00:00.000          0
3         sdb-ss3               0 B 2021-01-17 09:15:21 00:00:00.000          0
```

## rebase 
语法: `rebase [-f fmt] [-t cache] [-p] [-u] -b backing_file [-F backing_fmt] filename`

改变镜像文件的后端镜像文件，只有 qcow2 和 qed 格式支持rebase命令。使用 "-b backing_file" 中指定的文件作为后端镜像，后端镜像也被转化为 "-F backing_fmt" 中指定的后端镜像格式。

它可以工作于两种模式之下，一种是安全模式（Safe Mode）也是默认的模式，qemu-img会去比较原来的后端镜像与现在的后端镜像的不同进行合理的处理；另一种是非安全模式（Unsafe Mode），是通过 "-u" 参数来指定的，这种模式主要用于将后端镜像进行了重命名或者移动了位置之后对前端镜像文件的修复处理，由用户去保证后端镜像的一致性。

```bash
# qemu-img rebase -f qcow2 -p -b sdc.qcow2 sdd.qcow2
qemu-img: warning: Deprecated use of backing file without explicit backing format, use of this image requires potentially unsafe format probing
    (100.00/100%)
```
## resize 
语法: `resize filename [+ | -]size`

改变镜像文件的大小，使其不同于创建之时的大小。"+" 和 "-" 分别表示增加和减少镜像文件的大小，而 size 也是支持 K、M、G、T 等单位的使用。缩小镜像的大小之前，需要在客户机中保证里面的文件系统有空余空间，否则会数据丢失，另外，qcow2 格式文件不支持缩小镜像的操作。在增加了镜像文件大小后，也需启动客户机到里面去应用 "fdisk"、"parted" 等分区工具进行相应的操作才能真正让客户机使用到增加后的镜像空间。不过使用 resize 命令时需要小心（最好做好备份），如果失败的话，可能会导致镜像文件无法正常使用而造成数据丢失。
```bash
# qemu-img resize sdd.qcow2 +2G
Image resized.
```

# qemu-img 支​持​格​式​
## raw
Raw 磁​盘​映​像​格​式​（默​认​）。​这​个​格​式​的​优​点​是​可​以​简​单​、​容​易​地​导​出​到​其​它​模​拟​器​中​。​如​果​您​的​文​件​系​统​支​持​中​断​（例​如​在​ Linux 中​的​ ext2 或​者​ ext3 以​及​ Windows 中​的​ NTFS），那​么​只​有​写​入​的​字​段​会​占​用​空​间​。​使​用​ qemu-img info 了​解​ Unix/Linux 中​映​像​或​者​ ls -ls 使​用​的​实​际​大​小​。​
## qcow2
QEMU 映​像​格​式​，最​万​能​的​格​式​。​使​用​它​可​获​得​较​小​映​像​（如​果​您​的​系​统​不​支​持​中​断​，例​如​在​ Windows 中​，它​会​很​有​用​）、​额​外​的​ AES 加​密​法​、​zlib 压​缩​以​及​对​多​ VM 快​照​的​支​持​。​
## qcow
旧​的​ QEMU 映​像​格​式​。​只​用​于​与​旧​版​本​兼​容​。​
## cow
写​入​映​像​格​式​的​用​户​模​式​ Linux 副​本​。​包​含​ cow 格​式​的​目​的​只​是​为​了​与​前​面​的​版​本​兼​容​。​它​无​法​在​ Windows 中​使​用​。​
## vmdk
VMware 3 和​ 4 兼​容​映​像​格​式​。​
## cloop
Linux 压​缩​回​送​映​像​，只​有​在​重​复​使​用​直​接​压​缩​的​ CD-ROM 映​像​时​有​用​，比​如​在​ Knoppix CD-ROM 中​。​