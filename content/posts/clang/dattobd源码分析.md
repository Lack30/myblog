---
title: "Dattobd源码分析"
date: 2022-02-26T17:16:06+08:00
lastmod: 2022-02-26T17:16:06+08:00
draft: true
keywords: 
 - datto
description: ""
tags: 
 - C
 - 源码
categories: 
 - 开发
author: "Lack"
---

# 简介
[datto](https://github.com/datto/dattobd) 是 linux 下的一款备份工具。它能提供磁盘快照功能，并追踪 linux 内核中的块变化。datto 编译完成后生成三个工具，分别为:
- dattobd.ko : linux 内核模块，负责实际处理用户操作和追踪块变化。
- dbdctl : 用户态工具，通过 /etc/datto-ctl 字符文件和 dattobd.ko 通讯。
- update-img : 用户态工具，根据块变化信息间增量部分的数据写入到指定的块文件中。

# 源码分析

## 内部工作原理

dbdctl -> /etc/datto-ctl -> dattobd.ko

## 内核驱动
dattobd.ko 模块入口处位于 src/dattodb.c 中，内核模块统一入口为 `module_init`: 

### init
```C

static int __init agent_init(void){
    ...

	// 注册 /proc/datto-info，显示 datto 状态
	LOG_DEBUG("registering proc file");
	info_proc = proc_create(INFO_PROC_FILE, 0, NULL, &dattobd_proc_fops);

    ...

	// 注册 /dev/datto-ctl，负责和内核 dattobd.ko 通讯
	LOG_DEBUG("registering control device");
	ret = misc_register(&snap_control_device);

    // 替换 mount, umount hook
	if(dattobd_may_hook_syscalls) (void)hook_system_call_table();

	return 0;
    ...
}
module_init(agent_init);
```

## ioctl 