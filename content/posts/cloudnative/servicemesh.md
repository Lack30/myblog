---
title: "Service Mesh"
date: 2021-10-22T20:29:57+08:00
lastmod: 2021-10-22T20:29:57+08:00
draft: false
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

# 什么是 Service Mesh

## Service Mesh 产生的背景

## Service Mesh 主要功能

## Service Mesh 演进
- SDk
- Ingress (边缘代理)
- 路由网格
- Proxy
- Sidecar: 拥有所有请求的规则
- 控制面: control plane

数据面
- 处理服务请求流量
- 使用proxy拦截并转发网络流量

控制面
- 生成并下发Proxy代理规则
- 采集并遥测数据面指标

## Service Mesh 核心功能
- 应用透明
- 适配云原生
- 流控和可观测

## Service 成本和收益
收益
- 透明的应用改造成本
- 现有业务逻辑不需要变更，只需要配置Proxy规则就可以完成接入。
- 业务与SDK分离
- Proxy 完成规则判断、流量处理、超时、重试和熔断等功能。不需要第三方SDK。
- 业务与基础设施分离
- 业务不需要考虑服务发现、服务治理、监控等基础设施所完成的工作。

成本
- 多次网络链接造成的性能损耗

## Service Mesh 现状
数据平面
- Linkerd  - 出道最早，现状不好
- Envoy - 大厂出品，自带光环

Istio
- 自研控制平面
- 集成Envoy作为默认数据平面

SOFA Mesh
- 基于Istio自研
- 国内最大的Service Mech实践
- 寡不敌众，弃暗投明

## Service Mesh 结论
- 微服务的网络基础设施层
- 为云原生服务进行可靠的网络交付
- 第一代只有数据平面
- 第二代出现控制平面和数据平面
- 服务网格优势明显，但缺陷在于性能和规模
- Istio已经成为事实上的Service Mesh标准



