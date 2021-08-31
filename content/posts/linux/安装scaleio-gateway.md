---
title: "安装scaleio Gateway"
date: 2018-08-31T15:27:24+08:00
lastmod: 2018-08-31T15:27:24+08:00
draft: false
keywords: []
description: ""
tags: ["linux", "scaleio"]
categories: ["存储"]
author: "Lack"
---

scaleio-gateway是EMC ScaleIO存储的网关接口，通过调用其api能实现EMC存储软件的管理。下面来介绍怎么安装和配置：

# 一、安装
1.直接是使用rpm软件安装：gateway运行环境需要 java1.8，内存大于3G
```bash
# 先配置gateway admin用户的密码
[root@localhost  ~]# export GATEWAY_ADMIN_PASSWORD=Scale10 
[root@localhost  ~]# rpm -ivh /tmp/EMC-ScaleIO-gateway-2.6-11000.113.x86_64.rpm 
# 安装成功后服务默认启动，绑定在端口80
[root@localhost  ~]# netstat -tnlp | grep 80 
tcp6       0      0 :::80                   :::*                    LISTEN      4225/java
```

# 二、配置
安装完gateway还需要配置，gateway的配置有两种方式。

- 使用浏览器配置。
- 直接修改配置文件。



使用浏览器配置使用浏览器输入地址 https://<主机ip>，输入用户名密码(admin/Scale10)后登陆 
![](https://raw.githubusercontent.com/xingyys/myblog/main/post/images/20201030102048.png)
输入后
![](https://raw.githubusercontent.com/xingyys/myblog/main/post/images/20201030102116.png)

![](https://raw.githubusercontent.com/xingyys/myblog/main/post/images/20201030102139.png)
直接修改配置文件
```bash
[root@localhost  ~]# vim /opt/emc/scaleio/gateway/webapps/ROOT/WEB-INF/classes/gatewayUser.properties 
// 修改以下字段
// scaleio管理的ip地址，使用,或;隔开
mdm.ip.addresses=192.168.3.200;192.168.3.201
// 允许非加密的通讯
gateway-security.allow_non_secure_communication=true
// 防止主从切换中gateway错误
security.bypass_certificate_check=true
// 记得重启gateway服务
[root@localhost  ~]# /etc/init.d/scaleio-gateway restart
```

# 三、验证
使用浏览器登陆 https://<主机ip>/api/login 验证curl命令验证验证：
```bash
[root@localhost  ~]# curl -k --user admin:Scale10 https://192.168.3.107/api/login
"YWRtaW46MTU1ODA5ODgyNjQyODozMDVjYWQ3NjljNWFlNWU4ZWI2MDcxZGNiNmI4MmMzMA"
```

