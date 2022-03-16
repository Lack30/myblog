# Clion远程调试c代码


本篇主要介绍如何使用 Clion 来远程调整 C 语言代码。所需环境如下:
- Mac 主机
- Clion 2021.3.3
- CentOS8 远程开发机

在 mac 上新建一个 mac 项目

![](https://raw.githubusercontent.com/xingyys/myblog/main/posts/images/20220216163516.png)

添加远程工具链 toolchains: settings --> Build --> toolchains

![](https://raw.githubusercontent.com/xingyys/myblog/main/posts/images/20220216164638.png)

Clion 默认项目默认的 cmake 最小版本为 3.21。本地升级 cmake
```bash
sudo brew upgrade cmake
```

远程 CentOS8 安装工具库
```bash
dnf install -y gcc gcc-c++ cmake wget net-tools openssl-devel
```
下载 cmake
```bash
wget https://github.com/Kitware/CMake/releases/download/v3.21.5/cmake-3.21.5-linux-x86_64.tar.gz
tar -xvf cmake-3.21.5-linux-x86_64.tar.gz
cd cmake-3.21.5
```
安装 cmake
```bash
./bootstrap
make 
make install
```
删除旧版本的 cmake
```bash
dnf remove -y cmake
```
安装 gdb 等工具
```bash
dnf install -y make clang gdb gdb-gdbsever
```
调整 Clion 的 cmake 配置： settings --> Build --> Cmake

![](https://raw.githubusercontent.com/xingyys/myblog/main/posts/images/20220216165622.png)

添加 Debug Configuration:

![](https://raw.githubusercontent.com/xingyys/myblog/main/posts/images/20220216170245.png)

配置远程 linux 连接: settings --> Deployment

![](https://raw.githubusercontent.com/xingyys/myblog/main/posts/images/20220216171652.png)

调整远程目录的映射关系

![](https://raw.githubusercontent.com/xingyys/myblog/main/posts/images/20220216171706.png)

以下为最终样式

![](https://raw.githubusercontent.com/xingyys/myblog/main/posts/images/20220216171750.png)

以上就是本篇的全部内容了，有了以上配置的环境，就可以大大提高C的开发效率了，愉快的开发吧！
