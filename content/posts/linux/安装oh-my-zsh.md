---
title: "linux 安装 oh-my-zsh"
date: 2020-02-09T15:23:20+08:00
lastmod: 2020-02-09T15:23:20+08:00
draft: false
keywords: []
description: ""
tags: ["linux", "终端"]
categories: ["其他"]
author: "Lack"

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


# 一、介绍
oh-my-zsh 是一款命令行工具，在zsh的基础上添加了许多的新功能。接下来就来安装并使用他。<br />


# 二、安装 oh-my-zsh
oh-my-zsh 是在 zsh 的基础上使用的，所以要就安装zsh。一般linux发行版默认使用bash。以下环境为CentOS7。<br />使用 yum 安装 zsh

```bash
$ yum install zsh
```

安装完成后，替换默认的 bash 为 zsh。需要在 root 用户下使用

```bash
$ chsh -s /bin/zsh
Changing shell for root.
Shell changed.
# 在新终端中验证
$ echo $SHELL
/bin/zsh
```

执行以下命令自动安装 oh-my-zsh

```bash
$ wget https://github.com/robbyrussell/oh-my-zsh/raw/master/tools/install.sh -O - | sh
# 省略输出...
$ source .zshrc 
# .zshrc 为 zsh 的配置文件
```


# 三、配置 oh-my-zsh
接下来还要添加额外的功能。oh-my-zsh 支持很多强大的功能，这些功能都是以插件的方式实现。插件放在目录~/.oh-my-zsh/plugins 下。要让插件开始工作还需要在 .zshrc 中配置相关参数。

```bash
plugins=(git textmate ruby autojump osx mvn gradle)
```


## autojump
**作用**<br />目录间快速跳转,不用再一直 `cd` 了 😁<br />**使用 **<br />使用 `autojump` 的缩写 `j`<br />`cd` 命令进入 `~/user/github/Youthink` 文件夹，下一次再想进入 `Yourhink` 文件夹的时候,直接 `j youthink` 即可, 或者只输入 `youthink` 的一部分 `youth` 都行删除无效路径

```bash
$ j --purge 无效路径
```

需要额外下载 `autojump` 并配置<br />首先安装 `autojump`，如果你用 `Mac`，可以使用 `brew` 安装：

```bash
$ brew install autojump
```

如果是 `Linux`，可以使用 `git` 安装，比如：

```bash
$ git clone git://github.com/joelthelion/autojump.git
```

进入目录，执行

```bash
$ ./install.sh
```

最后把以下代码加入 `.zshrc`：

```bash
[[ -s ~/.autojump/etc/profile.d/autojump.sh ]] && . ~/.autojump/etc/profile.d/autojump.sh
```


## zsh-syntax-highlighting
**作用**<br/>平常用的`ls`、`cd` 等命令输入正确会绿色高亮显示，输入错误会显示其他的颜色。

![](https://raw.githubusercontent.com/xingyys/myblog/main/post/images/20201030101839.png)

**安装**
```bash
$ git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
```

在 `~/.zshrc` 中配置

```bash
plugins=(其他的插件 zsh-syntax-highlighting)
```

使配置生效

```bash
source ~/.zshrc
```


## zsh-autosuggestions
**作用**<br />如图输入命令时，会给出建议的命令（灰色部分）按键盘 → 补全<br />
<br />
![](https://raw.githubusercontent.com/xingyys/myblog/main/post/images/20201030102007.png)

如果感觉 → 补全不方便，还可以自定义补全的快捷键，比如我设置的逗号补全<br />

```bash
bindkey ',' autosuggest-accept
```

<br />在 `.zshrc` 文件添加这句话即可。<br />**<br />**安装**<br />**
```bash
$ git clone git://github.com/zsh-users/zsh-autosuggestions $ZSH_CUSTOM/plugins/zsh-autosuggestions
```

在 `~/.zshrc` 中配置

```bash
plugins=(其他的插件 zsh-autosuggestions)
```

使配置生效

```bash
source ~/.zshrc
```

