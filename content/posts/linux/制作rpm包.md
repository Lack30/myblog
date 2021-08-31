---
title: "制作rpm包"
date: 2019-05-29T17:34:45+08:00
lastmod: 2019-05-29T17:34:45+08:00
draft: false
keywords: []
description: ""
tags: ["linux"]
categories: ["笔记"]
author: "Lack"
---


# 制作rpm包的流程

rpm包是redhat和CentOS等linux发行版的包管理工具，能有效的管理系统的软件包，包括添加、删除、升级等操作。所以为了我们自己开发的软件也可以这样容易的管理，我们需要知道怎么制作rpm软件包


## 安装需要的软件
```bash
[root@CentOS1  ~]# yum install -y rpm-build
```
执行了以上的命令后我们就这里使用rpmbuild这个命令了。


## 创建rpmbuild

然后就需要创建rpmbuild
```bash
rpmbuild/
├── BUILD         // 在编译的过程中，有些缓存的数据都会放置在这个目录当中；
├── BUILDROOT     // 编译后生成的软件临时安装目录
├── RPMS          // 经过编译之后，并且顺利的编译成功之后，将打包完成的文件放置在这个目录当中。里头有包含了 i386, i586, i686, noarch.... 等等的次目录。
├── SOURCES       // 这个目录当中放置的是该软件的原始档 (*.tar.gz 的文件) 以及 config 这个配置档；
├── SPECS         // 这个目录当中放置的是该软件的配置档，例如这个软件的资讯参数、配置项目等等都放置在这里；
└── SRPMS         // 与 RPMS 内相似的，这里放置的就是 SRPM 封装的文件罗！有时候你想要将你的软件用 SRPM 的方式释出时， 你的 SRPM 文件就会放置在这个目录中了。
```
```bash
[root@CentOS1  ~]# mkdir -p rpmbuild/{BUILD,BUILDROOT,RPMS,SOURCES,SPECS,SRPMS}
```
这个目录就是我们要制作rpm包的相关目录，它里面保存我们需要的各种文件。


## 创建helloworld.spec文件
接下来来一个简单的demo，先在rpmbuild/SPECS下新建文件helloworld.spec
```bash
[root@CentOS1  ~]# vim rpmbuild/SPCES/helloworld.spec 
Name:           helloworld
Version:        1.0.0
Release:        1%{?dist}
Summary:        helloworld
Group:          Development/Tools
License:        GPL
#URL:
Source0:        %{name}-%{version}.tar.gz
#BuildRequires:
#Requires:
%description
%prep
%setup -q
%build
%install
mkdir -p $RPM_BUILD_ROOT/usr/bin
cp $RPM_BUILD_DIR/%{name}-%{version}/helloworld $RPM_BUILD_ROOT/usr/bin/
%clean
rm -rf $RPM_BUILD_ROOT
%files
%defattr(-,root,root,-)
%doc
/usr/bin/helloworld
%changelog
```
`*.spec` 文件的内容等下再讲，保存好 helloworld.spec 文件后，还需要再 rpmbuild/SOURCES 目录下添加对应的软件包，软件包的名字和SOURCE0字段对应
```bash
[root@CentOS1  ~]# echo "#! /bin/bash" > rpmbuild/SOURCES/helloworld-1.0.0/helloworld 
[root@CentOS1  ~]# echo "echo 'Hello World'" >> rpmbuild/SOURCES/helloworld-1.0.0/helloworld 
[root@CentOS1  ~]# tar -cvf rpmbuild/SOURCES/helloworld-1.0.0.tar.gz rpmbuild/SOURCES/helloworld-1.0.0 
rpmbuild/SOURCES/helloworld-1.0.0/
rpmbuild/SOURCES/helloworld-1.0.0/helloworld
```

## 制作rpm包
需要的文件都准备好了，就可以制作文件包了。
```bash
[root@CentOS1  ~]# rpmbuild -bb rpmbuild/SPECS/helloworld.spec 
[root@CentOS1  ~]# ls rpmbuild/RPMS/x86_64/helloworld-1.0.0-1.el7.x86_64.rpm 
rpmbuild/RPMS/x86_64/helloworld-1.0.0-1.el7.x86_64.rpm
```
生成的rpm包就可以使用 rpm -ivh 命令安装了


# spec文件说明
接下来说明spec文件的语法规则。一般的spec文件头包含以下几个域：

## Name
```bash
描述：
软件包的名称，后面可使用%{name}的方式引用
格式：
Name:
```

## Version
```bash
描述：
软件包的名称，后面可使用%{name}的方式引用软件包版本号，后面可使用%{version}引用
格式：
Version:
```

## Release
```bash
描述：
软件包的发行号，后面可使用%{release}引用
格式：
Release:
```

## Packager
```bash
描述：
打包的人（一般喜欢写个人邮箱）
格式：
Packager:          youner_liucn@126.com
```

## License
```bash
描述：
软件授权方式，通常是GPL（自由软件）或GPLv2,BSD
格式：
License:          GPL
```

## Summary
```bash
描述：
软件摘要信息
格式：
Summary:          
```

## Group
```bash
描述：
软件包所属类别
格式：
Group:       Applications/Multimedia
具体类别：
Amusements/Games（娱乐/游戏）
Amusements/Graphics（娱乐/图形）
Applications/Archiving（应用/文档）
Applications/Communications（应用/通讯）
Applications/Databases（应用/数据库）
Applications/Editors（应用/编辑器）
Applications/Emulators（应用/仿真器）
Applications/Engineering（应用/工程）
Applications/File（应用/文件）
Applications/Internet（应用/因特网）
Applications/Multimedia（应用/多媒体）
Applications/Productivity（应用/产品）
Applications/Publishing（应用/印刷）
Applications/System（应用/系统）
Applications/Text（应用/文本）
Development/Debuggers（开发/调试器）
Development/Languages（开发/语言）
Development/Libraries（开发/函数库）
Development/System（开发/系统）
Development/Tools（开发/工具）
Documentation （文档）
SystemEnvironment/Base（系统环境/基础）
SystemEnvironment/Daemons （系统环境/守护）
SystemEnvironment/Kernel （系统环境/内核）
SystemEnvironment/Libraries （系统环境/函数库）
SystemEnvironment/Shells （系统环境/接口）
UserInterface/Desktops（用户界面/桌面）
User Interface/X（用户界面/X窗口）
User Interface/XHardware Support （用户界面/X硬件支持）
```

## Source0
```bash
描述：
源代码包的名字
格式：
Source0:       %{name}-%{version}.tar.gz
```

## BuildRoot
```bash
描述：
编译的路径。是安装或编译时使用的“虚拟目录”，考虑到多用户的环境，一般定义为：
该参数非常重要，因为在生成rpm的过程中，执行make install时就会把软件安装到上述的路径中，在打包的时候，同样依赖“虚拟目录”为“根目录”进行操作(即%files段)。
后面可使用$RPM_BUILD_ROOT 方式引用。
格式：
BuildRoot：%{_tmppath}/%{name}-%{version}-%{release}-buildroot
```

## URL
```bash
描述：
软件的主页
格式：
URL:
```

##  Vendor
```bash
描述：
发行商或打包组织的信息，例如RedFlagCo,Ltd
格式：
Vendor: <RedFlag Co,Ltd>
```

## Provides
```bash
描述：
指明本软件一些特定的功能，以便其他rpm识别
格式：
Provides:
```
描述：指明本软件一些特定的功能，以便其他rpm识别格式：Provides: 

## 依赖关系
依赖关系定义了一个包正常工作需要依赖的其他包，RPM在升级、安装和删除的时候会确保依赖关系得到满足。rpm支持4种依赖：

- Requirements, 包依赖其他包所提供的功能
- Provides, 这个包能提供的功能
- Conflicts, 一个包和其他包冲突的功能
- Obsoletes, 其他包提供的功能已经不推荐使用了，这通常是其他包的功能修改了，老版本不推荐使用了，可以在以后的版本中会被废弃。


定义依赖关系的语法是：

- Requires: capability
- Provides: capability
- Obsoletes: capability
- Conflicts: capability

大部分时候，capability应该是所依赖的包的名称。一行中也可以定义多个依赖，比如： `Requires: tbsys tbnet` 
在指定依赖关系的时候还可以指定版本号，比如:`Requires: tbsys >= 2.0` 


## Requires
```bash
描述：
所依赖的软件包名称, 可以用>=或<=表示大于或小于某一特定版本。 “>=”号两边需用空格隔开，而不同软件名称也用空格分开。
格式：
Requires:       libpng-devel >= 1.0.20 zlib
其它写法例如：
Requires: bzip2 = %{version}, bzip2-libs =%{version}
或
Requires: perl(Carp)>=3.2         # 需要perl模块Carp
还有例如PreReq、Requires(pre)、Requires(post)、Requires(preun)、Requires(postun)、BuildRequires等都是针对不同阶段的依赖指定。
例如：
PreReq: capability>=version      # capability包必须先安装
Conflicts:bash>=2.0              # 该包和所有不小于2.0的bash包有冲突
```

## BuildRequires
```bash
描述：
编译时的包依赖
格式：
BuildRequires: zlib-devel
依赖包格式：
```

## 说明%description
```bash
软件包详细说明，可写在多个行上。
%description
Consul feature - Service Discovery, HealthChecking, KV, Multi Datacenter
```

## 预处理%prep
预处理通常用来执行一些解开源程序包的命令，为下一步的编译安装作准备。%prep和下面的%build，%install段一样，除了可以执行RPM所定义的宏命令（以%开头）以外，还可以执行SHELL命令。功能上类似于./configure。作用：用来准备要编译的软件。通常，这一段落将归档中的源代码解压，并应用补丁。这些可以用标准的 shell 命令完成，但是更多地使用预定义的宏。检查标签语法是否正确，删除旧的软件源程序，对包含源程序的tar文件进行解码。如果包含补丁（patch）文件，将补丁文件应用到解开的源码中。它一般包含%setup与%patch两个命令。%setup用于将软件包打开，执行%patch可将补丁文件加入解开的源程序中。


### 宏%setup

这个宏解压源代码，将当前目录改为源代码解压之后产生的目录。这个宏还有一些选项可以用。例如，在解压后，%setup 宏假设产生的目录是%{name}-%{version}如果 tar 打包中的目录不是这样命名的，可以用 -n 选项来指定要切换到的目录。例如：
- %setup -n %{name}-April2003Rel
- %setup-q             ：将 tar 命令的繁复输出关闭。
- %setup -n newdir     ：将压缩的软件源程序在newdir目录下解开。
- %setup -c            ：在解开源程序之前先创建目录。
- %setup -b num        ：在包含多个源程序时，将第num个源程序解压缩。
- %setup -T            ：不使用缺省的解压缩操作。

例如：
- %setup -T -b 0        //解开第一个源程序文件。
-%setup -c -nnewdir    //创建目录newdir，并在此目录之下解开源程序。


### 宏%patch
这个宏将头部定义的补丁应用于源代码。如果定义了多个补丁，它可以用一个数字的参数来指示应用哪个补丁文件。它也接受 -b extension 参数，指示 RPM 在打补丁之前，将文件备份为扩展名是 extension 的文件。
- %patch N  ：这里N是数字，表示使用第N个补丁文件，等价于%patch-P N
- -p0       ：指定使用第一个补丁文件，-p1指定使用第二个补丁文件。
- -s        ：在使用补丁时，不显示任何信息。
- -bname    ：在加入补丁文件之前，将源文件名上加入name。若为指定此参数，则缺省源文件加入.orig。
- -T        ：将所有打补丁时产生的输出文件删除


## 编译%build

定义编译软件包所要执行的命令， 这一节一般由多个make命令组成。作用：在这个段落中，包含用来配置和编译已配置的软件的命令。与 Prep 段落一样，这些命令可以是 shell 命令，也可以是宏。如果要编译的宏使用了 autoconf，那么应当用 %configure 宏来配置软件。这个宏自动为 autoconf 指定了安装软件的正确选项，编译优化的软件。如果软件不是用 autoconf 配置的，那么使用合适的 shell 命令来配置它。软件配置之后，必须编译它。由于各个应用程序的编译方法都各自不同，没有用来编译的宏。只要写出要用来编译的 shell 命令就可以了。环境变量 $RPM_OPT_FLAGS 在编译软件时很常用。这个 shell 变量包含针对 gcc 编译器套件的正确的优化选项，使用这样的语法：
```bash 
makeCC="gcc $RPM_OPT_FLAGS"
``` 
或者
```bash 
makeCFLAGS="$RPM_OPT_FLAGS"
```
就可以保证总是使用合适的优化选项。也可以使用其他编译器标志和选项。默认的 $RPM_OPT_FLAGS 是: 
```bash
-O2 -g-march=i386 -mcpu=i686
```


## 安装%install

定义在安装软件包时将执行命令，类似于make install命令。有些spec文件还有%post-install段，用于定义在软件安装完成后的所需执行的配置工作。作用：这个段落用于将已编译的软件安装到虚拟的目录结构中，从而可以打包成一个 RPM。在 Header 段落，可以定义 Buildroot，它定义了虚拟目录树的位置，软件将安装到那里。通常，它是这样的：`Buildroot:%{_tmppath}/%{name}-buildroot`

使用 RPM 内建的宏来指定 /var/tmp 目录中一个私用的目录。在 spec 文件的其余部分可以用 shell 变量 `$RPM_BUILD_ROOT` 获取 Buildroot 的值。
```bash
mkdir -p $RPM_BUILD_ROOT/usr/share/icons/
cp %{SOURCE3}$RPM_BUILD_ROOT/usr/share/icons/
```
Install 段落通常列出要将已编译的软件安装到 Buildroot 中的命令
宏 %makeinstall 可以用于安装支持 autoconf 的软件。这个软件自动地将软件安装到 $RPM_BUILD_ROOT 下的正确的子目录中。
有时，软件包必须被构建多次，由于打包错误或其他原因。每次构建时，Install 段落将复制文件到 Buildroot 中。要防止由于 Buildroot 中的旧文件而导致错误的打包，必须在安装新文件之前将 Buildroot 中任何现有的文件删除。为此，可以使用一个 clean 脚本。这个脚本通常以 %clean 标记表示，通常仅仅包含这样一句：
```bash
rm -rf$RPM_BUILD_ROOT
```
如果有的话，在制作了在 Install 段落中安装的文件的打包之后，将运行 %clean，保证下次构建之前 Buildroot 被清空。


## 清理%clean

```bash
%clean
rm-rf $RPM_BUILD_ROOT
```


## 文件%files

定义软件包所包含的文件，分为三类：说明文档（doc），配置文件（config）及执行程序，还可定义文件存取权限，拥有者及组别。

这里会在虚拟根目录下进行，千万不要写绝对路径，而应用宏或变量表示相对路径。 如果描述为目录，表示目录中除%exclude外的所有文件。

%defattr (-,root,root) 指定包装文件的属性，分别是(mode,owner,group)，-表示默认值，对文本文件是0644，可执行文件是0755


##  更新日志%changelog

每次软件的更新内容可以记录在此到这里，保存到发布的软件包中，以便查询之用。


# 更复杂的spec
```bash
Name:           oracle-agent
Version:        1.0.1
Release:        1%{?dist}
Summary:        oracle agent
Group:          Development/Tools
License:        GPL

#URL:
Source0:        %{name}-%{version}.tar.gz

#BuildRequires:
#Requires:
%define __debug_install_post 

%{rpmconfigdir}/find-debuginfo.sh %{?find_debuginfo_opts} "%{_builddir}/%{?buildsubdir}"

%{nil}

%description

%pre

%setup -q

%build

%install
$RPM_BUILD_ROOT # 对应文件系统的根目录，需要的路径要先创建
$RPM_BUILD_DIR # 对应tar解压后的文件目录
mkdir -p $RPM_BUILD_ROOT/etc/init.d/
mkdir -p $RPM_BUILD_ROOT/opt/howlink/oracle-agent
cp -r $RPM_BUILD_DIR/%{name}-%{version}/* $RPM_BUILD_ROOT/opt/howlink/oracle-agent/
rm -fr $RPM_BUILD_ROOT/opt/howlink/oracle-agent/debug*.list
rm -fr $RPM_BUILD_ROOT/opt/howlink/oracle-agent/elfbins.list
cp $RPM_BUILD_ROOT/opt/howlink/oracle-agent/oracle-agent-default.sh $RPM_BUILD_ROOT/etc/init.d/oracle-agent
chmod 755 $RPM_BUILD_ROOT/etc/init.d/oracle-agent
%post
systemctl daemon-reload
systemctl start oracle-agent
%clean

# 这里清理要注意
rm -rf $RPM_BUILD_ROOT/opt/howlink/oracle-agent
%files

# 生成的文件要这里添加
%defattr(-,root,root,-)
%doc
/opt/howlink/oracle-agent
/etc/init.d/oracle-agent
%preun
systemctl stop oracle-agent
%changelog
```

# 问题汇总

rpmbuild报error: Installed (but unpackaged) file(s) found的问题
```bash
找到 /usr/lib/rpm/macros 中
%__check_files
/usr/lib/rpm/check-files %{buildroot}   注释掉
#%__check_files
/usr/lib/rpm/check-files %{buildroot}
意思就是说不要在检查文件了，所以也就不会包file found的报错了
```
- check-rpaths的问题
```bash
报error
ERROR 0002: file 'xxx.so' contains an invalid rpath 'xxx' in [xxx]
经过网上查询，得知这一步只是一种检测是不是代码中使用了rpath，那我们可以简单的注释掉rpath检测就可以了，具体做法就是：
vi ~/.rpmmacros
找到这行
%__arch_install_post /usr/lib/rpm/check-rpaths /usr/lib/rpm/check-buildroot 注释掉
#%__arch_install_post /usr/lib/rpm/check-rpaths /usr/lib/rpm/check-buildroot
```
.在生成rpm包同时，还会生成debuginfo包，如果要避免生成debuginfo包：这个是默认会生成的rpm包。则可以使用下面的命令：
```bash
echo '%debug_package %{nil}' >> ~/.rpmmacros
把%debug_package %{nil} 追加到 ~/.rpmmacros 文件中便可。
```
(%prep)阶段提示包找不到
```bash
可以是软件的包解压后不会生成一个对应的目录，两个解决方式：
1.重新修改tar包
2.%setup -c
```


