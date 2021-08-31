---
title: "Windows 上使用 Go 语言"
date: 2020-10-29T16:44:06+08:00
lastmod: 2020-10-29T16:44:06+08:00
draft: false
keywords: []
description: ""
tags: ["windows", "golang"]
categories: ["开发"]
author: "Lack"

# You can also close(false) or open(true) something for this content.
# P.S. comment can only be closed
comment: true
toc: true
autoCollapseToc: true
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

在 Windows 使用 Go 开发项目是，为了实现统一的配置和格式管理，需要进行一下的配置。
# 开发环境选择
Go 语言的开发环境统一使用 Jetbrain 公司的 Goland。之后需要进行一些配置。
修改统一的文件换行符为 `\n` 。
<br/>
settings > Editor > Code Style
<br/>
![](https://raw.githubusercontent.com/xingyys/myblog/main/post/images/20201030110653.png)
添加格式化工具 `goimports`。`goimports` 同时内置了 `gofmt` 的功能。可以格式化 Go 代理、自动导入依赖包等。
<br/>
settings > Editor > Code Style > Go
<br/>
![](https://raw.githubusercontent.com/xingyys/myblog/main/post/images/20201030110801.png)
设置文件自动格式化
<br/>
settings > Tools > File Watch
<br/>
![](https://raw.githubusercontent.com/xingyys/myblog/main/post/images/20201030110855.png)
配置远程主机代码同步（可选）

Tools > Deployment > Configuration
<br/>
![](https://raw.githubusercontent.com/xingyys/myblog/main/post/images/20201030110938.png)
# Git 配置
文本文件所使用的换行符，在不同的系统平台上是不一样的。 `UNIX/Linux` 使用的是 `0x0A（LF）` ，早期的 `Mac OS` 使用的是 `0x0D（CR）` ，后来的 `OS X`  在更换内核后与 `UNIX`  保持一致了。但 `DOS/Windows`  一直使用 `0x0D0A（CRLF）`  作为换行符。


跨平台协作开发是常有的，不统一的换行符确实对跨平台的文件交换带来了麻烦。最大的问题是，在不同平台上，换行符发生改变时，Git 会认为整个文件被修改，这就造成我们没法 diff，不能正确反映本次的修改。还好 Git 在设计时就考虑了这一点，其提供了一个 autocrlf 的配置项，用于在提交和检出时自动转换换行符，该配置有三个可选项：

- true: 提交时转换为 LF，检出时转换为 CRLF
- false: 提交检出均不转换
- input: 提交时转换为LF，检出时不转换



用如下命令即可完成配置：
```bash
# 提交时转换为LF，检出时转换为CRLF
git config --global core.autocrlf true
# 提交时转换为LF，检出时不转换
git config --global core.autocrlf input
# 提交检出均不转换
git config --global core.autocrlf false
```
如果把 autocrlf 设置为 false 时，那另一个配置项 safecrlf 最好设置为 ture。该选项用于检查文件是否包含混合换行符，其有三个可选项：

- true: 拒绝提交包含混合换行符的文件
- false: 允许提交包含混合换行符的文件
- warn: 提交包含混合换行符的文件时给出警告



配置方法：
```bash
# 拒绝提交包含混合换行符的文件
git config --global core.safecrlf true
# 允许提交包含混合换行符的文件
git config --global core.safecrlf false
# 提交包含混合换行符的文件时给出警告
git config --global core.safecrlf warn
```
为了防止混乱，直接使用以下配置。
```bash
$ git config --global core.autocrlf false
$ git config --global core.safecrlf false
```
`以上配置需要注意: *.bat、*.ps 的换行修改为 CRLF；*.sh 文件修改为 LF，其他的所有文件统一为 LF。` 

