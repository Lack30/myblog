---
title: "下载oreilly电子书"
date: 2022-03-08T10:13:28+08:00
lastmod: 2022-03-08T10:13:28+08:00
draft: false
tags: 
 - 读书
categories: 
 - 笔记
author: "Lack"
---

# 简介
众所周知，O'Reilly 是一家世界著名的技术书出版商，提供大量高质量的技术书籍。但是不支持下载功能，所以本篇就来说明如何下载 O'Reilly 上的电子书。

# 安装
首先下载 [safaribooks](https://github.com/lorenzodifuccia/safaribooks) 工具。
```bash
$ git clone https://github.com/lorenzodifuccia/safaribooks.git
Cloning into 'safaribooks'...

$ cd safaribooks/
$ pip3 install -r requirements.txt

OR

$ pipenv install && pipenv shell
```
本机需要安装 Python3 环境。

safaribooks 的使用命令如下：
```bash
python3 safaribooks.py --cred "account_mail@mail.com:password01" XXXXXXXXXXXXX
```
其中 `XXXXXXXXXXXXX` 表示电子书的 ID。例如电子书页面 `https://learning.oreilly.com/videos/python-fundamentals/9780135917411/` 的 ID 就是 `9780135917411`。

因为作者的 O'Reilly 账号为 ACM 关联账号，无法通过直接使用账号密码方式登录下载。所以选择第二种方式：本地 cookies.json 文件。

# 下载
先在浏览器中登录 O'Reilly 页面，转到这个首页 [https://learning.oreilly.com/profile/](https://learning.oreilly.com/profile/)。打开浏览器的开发者模式，在 `Console` 下执行命令:
```javascript
javascript:(function(){var output = {};document.cookie.split(/\s*;\s*/).forEach(function(pair) {pair = pair.split(/\s*=\s*/);output[pair[0]]=pair.splice(1).join('=');});console.log(JSON.stringify(output));})();
```
将输出的信息保存到 `safaribooks` 目录下的 `cookies.json` 文件中。 

执行以下命令下载电子书：
```bash
python3 safaribooks.py  XXXXXXXXXXXXX
```
输出结果为:
```bash

 ██████╗     ██████╗ ██╗  ██╗   ██╗██████╗
██╔═══██╗    ██╔══██╗██║  ╚██╗ ██╔╝╚════██╗
██║   ██║    ██████╔╝██║   ╚████╔╝   ▄███╔╝
██║   ██║    ██╔══██╗██║    ╚██╔╝    ▀▀══╝
╚██████╔╝    ██║  ██║███████╗██║     ██╗
 ╚═════╝     ╚═╝  ╚═╝╚══════╝╚═╝     ╚═╝

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
[-] Successfully authenticated.
[*] Retrieving book info...
[-] Title: Linux Kernel Programming
[-] Authors: Kaiwan N Billimoria
[-] Identifier: 9781789953435
[-] ISBN: 9781789953435
[-] Publishers: Packt Publishing
[-] Rights:
[-] Description: Learn how to write high-quality kernel module code, solve common Linux kernel programming issues, and understand the fundamentals of Linux kernel internalsKey FeaturesDiscover how to write kernel code using the Loadable Kernel Module frameworkExplore industry-grade techniques to perform efficient memory allocation and data synchronization within the kernelUnderstand the essentials of key internals topics such as kernel architecture, memory management, CPU scheduling, and kernel synchronizationBo...
[-] Release Date: 2021-03-19
[-] URL: https://learning.oreilly.com/library/view/linux-kernel-programming/9781789953435/
[*] Retrieving book chapters...
[*] Output directory:
    /Users/xingyys/project/python3/safaribooks/Books/Linux Kernel Programming (9781789953435)
[-] Downloading book contents... (25 chapters)
    [###################################################################################################################################################################################################] 100%
[-] Downloading book CSSs... (2 files)
    [###################################################################################################################################################################################################] 100%
[-] Downloading book images... (145 files)
    [###################################################################################################################################################################################################] 100%
[-] Creating EPUB file...
[*] Done: /Users/xingyys/project/python3/safaribooks/Books/Linux Kernel Programming (9781789953435)/9781789953435.epub

    If you like it, please * this project on GitHub to make it known:
        https://github.com/lorenzodifuccia/safaribooks
    e don't forget to renew your Safari Books Online subscription:
        https://learning.oreilly.com

[!] Bye!!
```

# 格式转化
下载的电子书为 `epub` 格式，如果需要其他格式时，可以借用 [calibre](https://calibre-ebook.com/download) 工具来转化。
