---
title: "Containerd源码分析"
date: 2021-11-16T23:17:49+08:00
lastmod: 2021-11-16T23:17:49+08:00
draft: true
featuredImage: "https://raw.githubusercontent.com/xingyys/myblog/main/posts/images/20210926200427.png"
tags: 
 - 源码分析
 - golang
categories: 
 - 云原生
author: "Lack"
---

从 Kubernetes 1.22 开始，k8s 的容器运行是默认替换成 containerd。有必要深入了解 containerd 的内部实现原理。本篇通过分析 containerd 的代码深入理解其内部原理。

使用的版本为 containerd 1.5。

## 配置环境
下载 containerd 源码:
```bash
git clone github.com/containerd/containerd
```
启动 goland 的远程调试功能

## 入口
先来从 `main` 函数来看启动流程。从以下目录结构中可以看出来，containerd 项目目录中包含一个守护进程和对应的执行工具。
```bash
cmd
├── containerd           // containerd CRI 实现，对外提供容器服务，对内和 containerd-shim-runc 通讯
├── containerd-shim
├── containerd-shim-runc-v1   // 负责和 runc 通信，管理容器实例
├── containerd-shim-runc-v2   // v2 版本 
├── containerd-stress
├── ctr                  // containerd 客户端命令行工具
├── gen-manpages
└── protoc-gen-gogoctrd
```
以下是它们之间的调用流程图: 
![](https://raw.githubusercontent.com/xingyys/myblog/main/posts/images/20211117090030.png)

## containerd
containerd 本身是一个命令行工具实现，入口文件为 `cmd/containerd/main.go`
```go
func main() {
	app := command.App()
	if err := app.Run(os.Args); err != nil {
		fmt.Fprintf(os.Stderr, "containerd: %s\n", err)
		os.Exit(1)
	}
}
```
### command app
containerd 包含三个子命令: 
configCommand: 输出 containerd 默认配置文件
publishCommand: 向 containerd 服务发布一个事件
ociHook: 启动一个 oci 钩子

`app.Action` 中定义了 containerd 的启动流程：
```go
...
    app.Action = func(context *cli.Context) error {

        ...
        // 加载配置文件
		configPath := context.GlobalString("config")

        ...
        // 通过配置文件创建 server，server 中包含 ttrpc、grpc、tcp、metrics
		server, err := server.New(ctx, config)
        ...

        ...
        // 启动 ttrpc 服务
		serve(ctx, tl, server.ServeTTRPC)
        ...

		if config.GRPC.TCPAddress != "" {
			l, err := net.Listen("tcp", config.GRPC.TCPAddress)
			if err != nil {
				return errors.Wrapf(err, "failed to get listener for TCP grpc endpoint")
			}
            // 启动 tcp 服务
			serve(ctx, l, server.ServeTCP)
		}

        ...
        // 启动 grpc 服务
        serve(ctx, l, server.ServeGRPC)

        ...
		return nil
	}
...
```