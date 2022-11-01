# 编译调试 ceph v16.2.10


对于学习分布式存储而言，ceph 是一个很好的例子。它具有分布式存储所需的各种常用功能。本篇通过一个开发者的角度来尝试对 ceph 源码进行编译，并且调试。

# 准备阶段
先说明实验的环境：
- 操作系统：Ubuntu desktop 20.04
- 编译工具： gcc/g++ 9.4.0 、 python 3.8 、 cmake 3.16.3
- 源码版本：ceph v16.2.10
- IDE：vscode 、clangd

# 编译 ceph
直接从 github 上下载 ceph 源码
```bash
git clone https://github.com/ceph/ceph
cd ceph
git submodule update --init --recursive
```
安装依赖项
```bash
cd ceph
./install-deps.sh
```
这里出现一个问题，在安装 pytest 包时提示版本错误，解决方式时修改 requirement.txt 文件
```bash
vim src/pybind/mgr/dashboard/requirements-lint.txt
# pytest==6.2.4
pytest
```

编译 ceph，因为需要设置开发环境，所以需要先修改 ceph 编译参数，直接修改 do_cmake.sh
```bash
...
if [[ ! "$ARGS $@" =~ "-DBOOST_J" ]] ; then
    ncpu=$(getconf _NPROCESSORS_ONLN 2>&1)
    [ -n "$ncpu" -a "$ncpu" -gt 1 ] && ARGS+=" -DBOOST_J=$(expr $ncpu / 2)"
fi
ARGS+=" -DCMAKE_EXPORT_COMPILE_COMMANDS=1"
...
```
`-DCMAKE_EXPORT_COMPILE_COMMANDS=1` 参数是告诉 cmake 预编译时生成 `compile_commmands.json`，配合 clangd 可以进行代码补全。

生成 makefile 文件
```bash
./do_cmake.sh
```
执行完成后会生成 build 目录，在 build 目录内编译二进制文件
```bash
cd build
make -j4 vstart
```
通过这个命令就可以生成 ceph 本地开发环境需要的各种文件了。这个命令需要一段时间，先直接配置 vscode 环境。

# 配置 vscode
vscode 配合 clangd 可以很好的实现 C++ 代码补全功能。先设置 vscode 远程连接，在远程机器上安装插件 
- C/C++
- clangd
- CMake
- GDB Debug
- CodeLLDB

ubuntu 安装 clangd，添加 clangd 源码
```bash
deb http://apt.llvm.org/focal/ llvm-toolchain-focal-14 main
deb-src http://apt.llvm.org/focal/ llvm-toolchain-focal-14 main

apt update
```
安装 clangd-14
```bash
apt install -y clang-14 clangd-14

sudo update-alternatives --install /usr/bin/clang clang /usr/bin/clang-14 1 --slave /usr/bin/clang++ clang++ /usr/bin/clang++-14
sudo update-alternatives --install /usr/bin/clangd clangd /usr/bin/clangd-14 1
```

使用 vscode 远程打开 ceph 目录
![](https://raw.githubusercontent.com/xingyys/myblog/main/posts/images/20221101141924.png)

添加 settings.json 和 lauch.json
```bash
mkdir .vscode
cat << EOF > .vscode/settings.json
{
    /**********
   * Clangd *
   **********/
    // 关闭 C/C++ 提供的 IntelliSenseEngine
    // Clangd 运行参数(在终端/命令行输入 clangd --help-list-hidden 可查看更多)
    "clangd.onConfigChanged": "restart",
    "clangd.path": "/usr/bin/clangd-14",
    "clangd.arguments": [
        "--compile-commands-dir=${workspaceFolder}/build",
        "--background-index",
        "--clang-tidy",
        "--log=verbose",
        "--pretty",
        "-j=4"
    ],
    // 自动检测 clangd 更新
    "clangd.checkUpdates": false,
    // clangd的snippets有很多的跳转点，不用这个就必须手动触发Intellisense了
    "C_Cpp.intelliSenseEngine": "Disabled",
    "C_Cpp.autocomplete": "Disabled",
    "C_Cpp.errorSquiggles": "Disabled",
    "editor.suggest.snippetsPreventQuickSuggestions": false,
    /*********
   * CMake *
   *********/
    // 保存 cmake.sourceDirectory 或 CMakeLists.txt 内容时，不自动配置 CMake 项目目录
    "cmake.configureOnEdit": false,
    // 在 CMake 项目目录打开时自动对其进行配置
    "cmake.configureOnOpen": false,
    // 成功配置后，将 compile_commands.json 复制到此位置
    "cmake.copyCompileCommands": "build",
    /********
   * LLDB *
   ********/
    // LLDB 指令自动补全
    "lldb.commandCompletions": true,
    // LLDB 指针显示解引用内容
    "lldb.dereferencePointers": true,
    // LLDB 鼠标悬停在变量上时预览变量值
    "lldb.evaluateForHovers": true,
    // LLDB 监视表达式的默认类型
    "lldb.launch.expressions": "simple",
    // LLDB 不显示汇编代码
    "lldb.showDisassembly": "never",
    // LLDB 生成更详细的日志
    "lldb.verboseLogging": true,
    /*********
   * Color *
   *********/
    // 控制是否对括号着色
    "editor.bracketPairColorization.enabled": true,
    // 启用括号指导线
    "editor.guides.bracketPairs": false,
    // 语义高亮
    "editor.semanticHighlighting.enabled": true,
    // 语义高亮自定义
    "editor.semanticTokenColorCustomizations": {
        "enabled": true,
        "rules": {
            // 抽象符号
            "*.abstract": {
                "fontStyle": "italic"
            },
            // 只读量等效为宏
            "readonly": "#4FC1FF",
            // 静态量（静态变量，静态函数）
            "*.static": {
                "fontStyle": "bold"
            },
            // 宏
            "macro": {
                // "foreground": "#8F5DAF"
                "foreground": "#4FC1FF"
            },
            // 成员函数
            "method": {
                "fontStyle": "underline"
            },
            // 命名空间
            "namespace": {
                "foreground": "#00D780"
            },
            // 函数参数
            "parameter": {
                "foreground": "#C8ECFF"
            },
            // 只读的函数参数
            "parameter.readonly": {
                "foreground": "#7BD1FF"
            },
            // 成员变量，似乎需要clangd12以上
            "property": {
                "fontStyle": "underline",
                "foreground": "#C8ECFF"
            },
            // 类型参数
            "typeParameter": "#31A567",
            // 未启用的宏
            "comment": "#767BA6"
        }
    },
    // 括号颜色
    "workbench.colorCustomizations": {
        "[Default Dark+]": {
            "editorBracketHighlight.foreground3": "#9CDCFE",
            "editorBracketHighlight.foreground4": "#F3FD00",
            "editorBracketHighlight.foreground5": "#F47D9F",
            "editorBracketHighlight.foreground6": "#A5ADFE"
        }
    },
    "C_Cpp.clang_format_fallbackStyle": "Google",
}
EOF
```
```bash
cat <<EOF > .vscode/lauch.json
{
    "configurations": [
        {
            "name": "(gdb) rbd",
            "type": "cppdbg",
            "request": "launch",
            "program": "${workspaceFolder}/build/bin/rbd",
            "args": [
                "info",
                "vol",
            ],
            "stopAtEntry": false,
            "cwd": "${workspaceFolder}/build",
            "environment": [],
            "externalConsole": false,
            "MIMode": "gdb",
            "setupCommands": [
                {
                    "description": "为 gdb 启用整齐打印",
                    "text": "-enable-pretty-printing",
                    "ignoreFailures": true
                },
                {
                    "description": "将反汇编风格设置为 Intel",
                    "text": "-gdb-set disassembly-flavor intel",
                    "ignoreFailures": true
                }
            ]
        },
        {
            "name": "(gdb) ceph-osd-0",
            "type": "cppdbg",
            "request": "launch",
            "program": "${workspaceFolder}/build/bin/ceph-osd",
            "args": [
                "-d",
                "-i",
                "0",
                "-c",
                "${workspaceFolder}/build/ceph.conf"
            ],
            "stopAtEntry": false,
            "cwd": "${workspaceFolder}/build",
            "environment": [],
            "externalConsole": false,
            "MIMode": "gdb",
            "setupCommands": [
                {
                    "description": "为 gdb 启用整齐打印",
                    "text": "-enable-pretty-printing",
                    "ignoreFailures": true
                },
                {
                    "description": "将反汇编风格设置为 Intel",
                    "text": "-gdb-set disassembly-flavor intel",
                    "ignoreFailures": true
                }
            ]
        },
        {
            "name": "(gdb) ceph-mon-a",
            "type": "cppdbg",
            "request": "launch",
            "program": "${workspaceFolder}/build/bin/ceph-mon",
            "args": [
                "-d",
                "-i",
                "a",
                "-c",
                "${workspaceFolder}/build/ceph.conf"
            ],
            "stopAtEntry": false,
            "cwd": "${workspaceFolder}/build",
            "environment": [],
            "externalConsole": false,
            "MIMode": "gdb",
            "setupCommands": [
                {
                    "description": "为 gdb 启用整齐打印",
                    "text": "-enable-pretty-printing",
                    "ignoreFailures": true
                },
                {
                    "description": "将反汇编风格设置为 Intel",
                    "text": "-gdb-set disassembly-flavor intel",
                    "ignoreFailures": true
                }
            ]
        }
    ]
}
EOF
```

# 调试 ceph
等待 make 命令编译完成，执行 vstart
```bash
cd build

MON=1 OSD=1 MDS=0 MGR=0 RGW=0 NFS=0 ../src/vstart.sh -n -d --without-dashboard
```
本地会启动一个 `ceph-mon` 和 一个 `ceph-osd`。直接 kill `ceph-osd` 进程，调试 `ceph-osd`

![](https://raw.githubusercontent.com/xingyys/myblog/main/posts/images/20221101142651.png)

接着就可以愉快的编译调试 ceph 源码了。
