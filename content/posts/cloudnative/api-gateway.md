---
title: "API 网关"
date: 2021-10-26T20:09:24+08:00
lastmod: 2021-10-26T20:09:24+08:00
draft: true
keywords: 
 - 架构
 - 理论
featuredImage: "https://raw.githubusercontent.com/xingyys/myblog/main/posts/images/20210926200427.png"
tags: 
 - 笔记
categories: 
 - 云原生
author: "Lack"
---

## API Gateway 技术实现

### 网关分类
- 通用 Gateway
- API Gateway
- WAF

## 如何选择 API Gateway

考虑点:
- 数据同步
- 插件机制
- 代码复杂

开源Gateway方案 - 技术选型 
- 存储 
- 路由 
- Schema 
- 插件

数据同步要求: 中心化型 > 数据库型 > 配置文件型

开源Gateway方案 - 技术选型 
- 路由匹配 
- 插件列表 
- 插件链运行 
- 计算目标地址 
- 流量转发

## API Gateway 实践

网关不要耦合业务逻辑