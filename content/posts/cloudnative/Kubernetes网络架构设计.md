---
title: "Kubernetes网络架构设计"
date: 2021-10-12T22:21:25+08:00
lastmod: 2021-10-12T22:21:25+08:00
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

## k8s 网络模型
- 容器间通信
- Pod 间通信
- Pod 和服务间通信
- 外部和服务间通信

## Kubernetes 网络模型 - 总结
- 节点上的 Pod 可以不通过 NAT 和其他任何节点上的 Pod 通信
- 节点上的代理（比如： 系统守护进程、 kubelet） 可以和节点上的所有Pod通信
- 那些运行在节点的主机网络里的 Pod 可以不通过 NAT 和所有节点上的 Pod 通信

## CNI 概念
- Veth Pair
- Overlay Network
- VTEP
- Cni网桥
- Main 插件
- IPAM（IP Address Management）

## CNI 特点
- 所有容器都可以直接使用 IP 地址与其他容器通信，而无需使用 NAT。
- 所有宿主机都可以直接使用 IP 地址与所有容器通信， 而无需使用 NAT。 反之亦然。
- 容器自己“看到”的自己的 IP 地址， 和别人（宿主机或者容器） 看到的地址是完全一样的。