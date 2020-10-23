---
title: "Golang跨平台编译"
date: 2020-10-23T14:52:46+08:00
lastmod: 2020-10-23T14:52:46+08:00
draft: false
keywords: []
description: ""
tags: ["golang"]
categories: ["随笔"]
author: ""

# You can also close(false) or open(true) something for this content.
# P.S. comment can only be closed
comment: true
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

# golang cgo 到 Windows 的交叉编译

本篇记录在 MaxOS 下 cgo 交叉编译的解决方案。<br />因为在项目中使用 go-sqlite3 ，编译 go-sqlite3 中需要使用到 cgo。<br />在 MacOS 下编译 Go 原生 Linux 和 Windows 的程序使用以下命令：
```bash
# 交叉编译到 linux
GOOS=linux GOARCH=amd64 go build main.go
# 交叉编译到 windows
GOOS=windows GOARCH=amd64 go build -o main.exe main.go 
```
如果使用 cgo 的话，还需要添加 `CGO_ENABLED`  参数：
```bash
CGO_ENABLED=1 GOOS=windows GOARCH=amd64 go build -o main.exe main.go 
```
但是这种编译 go-sqlite3 的代码会出现以下错误：
```bash
# runtime/cgo
gcc_libinit_windows.c:7:10: fatal error: 'windows.h' file not found
```
因为 Windows 中使用 MinGW，MacOS 下如果交叉编译需要安装 C/C++ 交叉编译工具：
```bash
brew install FiloSottile/musl-cross/musl-cross
brew install mingw-w64
```
安装完工具之后就可以使用命令：
```bash
CGO_ENABLED=1 CC=x86_64-w64-mingw32-gcc CXX=x86_64-w64-mingw32-g++ GOOS=windows GOARCH=amd64 go build -a -v -o store.exe store/sqlite.exe
```
注意参数： `CXX=x86_64-w64-mingw32-g++` ，如果缺少这个参数时，可能会出现错误：
```bash
# runtime/cgo
gcc: error: unrecognized command line option ‘-mthreads’; did you mean ‘-pthread’?
```



