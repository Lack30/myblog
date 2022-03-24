---
title: "Lvs 负载均衡实战"
date: 2022-03-23T17:24:13+08:00
lastmod: 2022-03-23T17:24:13+08:00
draft: false
tags:
  - linux
categories:
  - 运维
author: "Lack"
---

由于在项目中有负载均衡需求，所以就想到几年前学过的 lvs。本文记录下 lvs 在 linux 和 windows 两个平台下部署方式。

# lvs 简介

Linux Virtual Server 项目的目标 ：使用集群技术和 Linux 操作系统实现一个高性能、高可用的服务器，它具有很好的可伸缩性（Scalability）、可靠性（Reliability）和可管理性（Manageability）。

目前，LVS 项目已提供了一个实现可伸缩网络服务的 Linux Virtual Server 框架，如图 3 所示。在 LVS 框架中，提供了含有三种 IP 负载均衡技术的 IP 虚拟服务器软件 IPVS、基于内容请求分发的内核 Layer-7 交 换机 KTCPVS 和集群管理软件。可以利用 LVS 框架实现高可伸缩的、高可用的 Web、Cache、Mail 和 Media 等网络服务；在此基础上，可以开 发支持庞大用户数的、高可伸缩的、高可用的电子商务应用。

![](https://raw.githubusercontent.com/xingyys/myblog/main/posts/images/20220323172921.png)

更加具体的信息可以参考[官方文档](http://www.linuxvirtualserver.org/zh/lvs1.html)

# 环境说明

| 角色                  | IP 地址         | 环境                      |
| --------------------- | --------------- | ------------------------- |
| director              | 192.168.221.150 | CentOS7, ipvsadm          |
| linux real server 1   | 192.168.221.200 | CentOS，nginx             |
| linux real server 2   | 192.168.221.176 | CentOS, nginx             |
| windows real server 1 | 192.168.221.190 | Windows Server2012, nginx |
| windows real server 2 | 192.168.221.191 | Windows Server2012, nginx |

# 环境部署

## director 配置

director 作为负载均衡的服务端，提供入口。首先安装 `ipvsadm` 工具

```bash
yum install -y ipvsadm
```

添加子网卡 eth0:0

```bash
ifconfig eth0:0 192.168.221.150 broadcast 192.168.221.150 netmask 255.255.255.255 up
route add -host 192.168.221.150 dev eth0:0
```

开启端口转发

```bash
echo 1 > /proc/sys/net/ipv4/ip_forward
```

配置 ipvs 规则

```bash
ipvsadm -C
ipvsadm -A -t 192.168.221.150:80 -s rr
ipvsadm -a -t 192.168.221.150:80 -r 192.168.221.200:80 -g -w 1
ipvsadm -a -t 192.168.221.150:80 -r 192.168.221.176:80 -g -w 1
```

这里作一个简要的说明，首先使用 ipvsadm -A 添加 VIP 并指定负载调度算法为 rr。接着添加需要妆发的真实服务器服务入口。这里先选择两台 linux 主机。

## linux real server 配置

接着在两台 linux real server 设置 vip。执行以下命令

```bash
vip=192.168.10.140
ifconfig lo:0 $vip broadcast $vip netmask 255.255.255.255 up
route add -host $vip lo:0
echo "1" > /proc/sys/net/ipv4/conf/lo/arp_ignore
echo "2" > /proc/sys/net/ipv4/conf/lo/arp_announce
echo "1" > /proc/sys/net/ipv4/conf/all/arp_ignore
echo "2" > /proc/sys/net/ipv4/conf/all/arp_announce
```

通过命令 curl 命令验证结果

```bash
curl http://192.168.221.150/
```

## windows real server 配置

先修改 director 上的 ipvs 规则

```bash
# 删除原有规则
ipvsadm -D -t 192.168.221.150:80

ipvsadm -A -t 192.168.221.150:80 -s rr
ipvsadm -a -t 192.168.221.150:80 -r 192.168.221.190:80 -g -w 1
ipvsadm -a -t 192.168.221.150:80 -r 192.168.221.191:80 -g -w 1
```

windows real server 的操作和 linux 类似，但是有一个问题。默认安装 windows 时，本机不会配置回环地址，需要用户手动添加一个。手动添加的操作步骤可以参考[这篇文档](https://cloud.tencent.com/developer/article/1071893)。

如果想要通过命令行方式添加回环设备，windows 系统中需要安装 devcon.exe 命令。安装 devcon.exe 可以参考[这篇文档](https://www.lab-z.com/dddevcon/)

这里介绍如何通过命令方式实现和 linux 下相同的操作

```bash
C:\\devcon.exe /r install C:\\windows\\inf\\netloop.inf *msloop
```

执行成功后会创建一个新的回环设备，命令 `ipconfig /all` 效果如下
![](https://raw.githubusercontent.com/xingyys/myblog/main/posts/images/20220324144735.png)

> 注: 创建的回环设备的 mac 地址都是: 02-00-3C-4F-4F-50

修改回环设备名称和 vip 地址

```bash
# 网卡重命名
netsh interface set interface name="本地连接 4" newname="realserver"

# 添加 vip
netsh interface ip set address name="realserver" source=static 192.168.221.150 255.255.255.255
```

修改网卡接口和回环设备接口连接模式

```bash
netsh interface ipv4 set interface "realserver" weakhostreceive=enabled
netsh interface ipv4 set interface "realserver" weakhostsend=enabled
netsh interface ipv4 set interface "本地连线" weakhostreceive=enabled
netsh interface ipv4 set interface "本地连线" weakhostsend=enabled
```

> 注: `本地连线` 替换成 real server 对应的网卡名称
