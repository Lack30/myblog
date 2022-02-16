---
title: "配置CentOS8的yum源"
date: 2022-02-16T17:29:27+08:00
lastmod: 2022-02-16T17:29:27+08:00
draft: false
tags: 
 - linux
categories: 
 - 运维
author: "Lack"
---

# 简介
如果更换 CentOS8 的 yum 源成国内源。

# 内容
备份老的 *.repo 文件

```bash
cd /etc/yum.repo.d/
mkdir bak
mv *.repo ./bak
```

添加新的 CentOS-Base.repo 文件
```bash
vi CentOS-Base.repo

# CentOS-Base.repo
#
# The mirror system uses the connecting IP address of the client and the
# update status of each mirror to pick mirrors that are updated to and
# geographically close to the client.  You should use this for CentOS updates
# unless you are manually picking other mirrors.
#
# If the mirrorlist= does not work for you, as a fall back you can try the
# remarked out baseurl= line instead.
#
#

[base]
name=CentOS-8.5.2111 - Base - mirrors.aliyun.com
#failovermethod=priority
baseurl=https://mirrors.aliyun.com/centos-vault/8.5.2111/BaseOS/$basearch/os/
        http://mirrors.aliyuncs.com/centos-vault/8.5.2111/BaseOS/$basearch/os/
        http://mirrors.cloud.aliyuncs.com/centos-vault/8.5.2111/BaseOS/$basearch/os/
gpgcheck=1
gpgkey=https://mirrors.aliyun.com/centos/RPM-GPG-KEY-CentOS-Official

#additional packages that may be useful
[extras]
name=CentOS-8.5.2111 - Extras - mirrors.aliyun.com
#failovermethod=priority
baseurl=https://mirrors.aliyun.com/centos-vault/8.5.2111/extras/$basearch/os/
        http://mirrors.aliyuncs.com/centos-vault/8.5.2111/extras/$basearch/os/
        http://mirrors.cloud.aliyuncs.com/centos-vault/8.5.2111/extras/$basearch/os/
gpgcheck=1
gpgkey=https://mirrors.aliyun.com/centos/RPM-GPG-KEY-CentOS-Official

#additional packages that extend functionality of existing packages
[centos-vaultplus]
name=CentOS-8.5.2111 - Plus - mirrors.aliyun.com
#failovermethod=priority
baseurl=https://mirrors.aliyun.com/centos-vault/8.5.2111/centos-vaultplus/$basearch/os/
        http://mirrors.aliyuncs.com/centos-vault/8.5.2111/centos-vaultplus/$basearch/os/
        http://mirrors.cloud.aliyuncs.com/centos-vault/8.5.2111/centos-vaultplus/$basearch/os/
gpgcheck=1
enabled=0
gpgkey=https://mirrors.aliyun.com/centos/RPM-GPG-KEY-CentOS-Official

[PowerTools]
name=CentOS-8.5.2111 - PowerTools - mirrors.aliyun.com
#failovermethod=priority
baseurl=https://mirrors.aliyun.com/centos-vault/8.5.2111/PowerTools/$basearch/os/
        http://mirrors.aliyuncs.com/centos-vault/8.5.2111/PowerTools/$basearch/os/
        http://mirrors.cloud.aliyuncs.com/centos-vault/8.5.2111/PowerTools/$basearch/os/
gpgcheck=1
enabled=0
gpgkey=https://mirrors.aliyun.com/centos/RPM-GPG-KEY-CentOS-Official


[AppStream]
name=CentOS-8.5.2111 - AppStream - mirrors.aliyun.com
#failovermethod=priority
baseurl=https://mirrors.aliyun.com/centos-vault/8.5.2111/AppStream/$basearch/os/
        http://mirrors.aliyuncs.com/centos-vault/8.5.2111/AppStream/$basearch/os/
        http://mirrors.cloud.aliyuncs.com/centos-vault/8.5.2111/AppStream/$basearch/os/
gpgcheck=1
gpgkey=https://mirrors.aliyun.com/centos/RPM-GPG-KEY-CentOS-Official
```

直接使用国内镜像站上下载的源文件会报错，原因是 CentOS 社区的新规导致原来的路径都 404 错误。

更新缓存
```bash
dnf makecache
```

> 注: CentOS8 中使用 dnf 来替换原来的 yum 工具。它们的用法一致