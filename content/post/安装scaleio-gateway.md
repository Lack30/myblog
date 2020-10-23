---
title: "安装scaleio Gateway"
date: 2018-08-31T15:27:24+08:00
lastmod: 2018-08-31T15:27:24+08:00
draft: false
keywords: []
description: ""
tags: ["linux", "scaleio"]
categories: ["存储"]
author: ""

# You can also close(false) or open(true) something for this content.
# P.S. comment can only be closed
comment: false
toc: true
autoCollapseToc: false
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

scaleio-gateway是EMC ScaleIO存储的网关接口，通过调用其api能实现EMC存储软件的管理。下面来介绍怎么安装和配置：<br />
<a name="6NhLo"></a>
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
<a name="4rT73"></a>
# 二、配置
安装完gateway还需要配置，gateway的配置有两种方式。

- 使用浏览器配置。
- 直接修改配置文件。



使用浏览器配置<br />使用浏览器输入地址 https://<主机ip>，输入用户名密码(admin/Scale10)后登陆 <br />
![image.png](https://cdn.nlark.com/yuque/0/2020/png/551536/1597714980277-9e0ccd1d-1d8b-4d84-87d5-b593b360c22d.png?x-oss-process=image%2Fresize%2Cw_1016)
<br />输入后<br />
![image.png](https://cdn.nlark.com/yuque/0/2020/png/551536/1597714988515-81f670e6-0c49-4c21-8224-974ef94d8add.png#align=left&display=inline&height=347&margin=%5Bobject%20Object%5D&name=image.png&originHeight=693&originWidth=1010&size=58653&status=done&style=none&width=505)<br />![image.png](https://cdn.nlark.com/yuque/0/2020/png/551536/1597714996738-0534e257-a7a3-404a-9ce8-f42c02feb5a7.png#align=left&display=inline&height=277&margin=%5Bobject%20Object%5D&name=image.png&originHeight=554&originWidth=1202&size=36588&status=done&style=none&width=601)<br />直接修改配置文件
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
<a name="I1tps"></a>
# 三、验证
使用浏览器登陆 https://<主机ip>/api/login 验证<br />curl命令验证验证：
```bash
[root@localhost  ~]# curl -k --user admin:Scale10 https://192.168.3.107/api/login
"YWRtaW46MTU1ODA5ODgyNjQyODozMDVjYWQ3NjljNWFlNWU4ZWI2MDcxZGNiNmI4MmMzMA"
```

