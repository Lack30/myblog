# 

## 三、安装客户端

### 3.1 Linux 下部署

```bash
上传安装包到服务器后，在指定路径解压
mkdir /opt/howlink/cdm
mv lblet-linux_amd64.zip /opt/howlink
cd /opt/howlink
unzip lblet-linux_amd64.zip -d /opt/howlink/cdm 
```

#### 3.1.1 安装 iscsiadm

当前版本的lblet，依赖于iSCSI客户端（即将⽀持FC），在启动lblet之前，需要安装iSCSI客户端。安装可以通过直接上传rpm包安装，也可以挂载系统镜像使⽤yum本地源安装。
公司NAS上提供了 Linux 6 和 Linux 7 版本的rpm包，两个版本安装过程有所区别：

```bash
# 上传rpm到指定位置后进⾏安装
# Linux 6
rpm -ivh iscsi-initiator-utils-6.2.0.873-27.el6_9.x86_64.rpm

# Linux 7
rpm -ivh iscsi-initiator-utils-iscsiuio-6.2.0.874-11.el7.x86_64.rpm
rpm -ivh iscsi-initiator-utils-6.2.0.874-11.el7.x86_64.rpm
```

#### 3.1.2 修改lblet的配置⽂件

以下是 /opt/howlink/cdm/config/config.ini 内容：

```bash
cat /opt/howlink/cdm/config/config.ini
# 需改lblet名称，该值唯⼀
name = orac1
# cdm
service.group = com.howlink.cdm

# 这⼉是connector对外的地址，必须是lblet可以访问的地址
connector.address=$SERVER_IP:8089

[lblet]
scripts=/opt/howlink/cdm/static
point=/opt/howlink/cdm/touch
cdm-oracle=/opt/howlink/cdm/bin/cdm-oracle
cdm-disk=/opt/howlink/cdm/bin/cdm-disk
```

修改完后将文件复制到 /root/.howlink/cdm/config.ini，防止lblet更新时被修改。

> 注：配置文件请直接在 linux 上修改，因为 windows 上修改的文件会改变文件的字符集格式，使得 linux 程序识别出错。

#### 3.1.3 设置启动脚本

Linux 6使⽤service进⾏服务管理，到了Linux 7，则使⽤systemctl来进⾏服务管理，systemctl向下兼容service命令。所以，根据lblet所在的操作系统版本，启动脚本的部署⽅式也有所区别：

```bash
# linux6
# 复制启动脚本
cp /opt/howlink/cdm/systemed/lblet.sh /etcd/init.d/lblet
chmod +x /etc/init.d/lblet

# 开机启动 lblet
chkconfig --add lblet | chkconfig on lblet

# linux7
# 复制启动脚本
cp systemed/lblet.service /usr/lib/systemed/system/lblet.service

# 开机启动 lblet
systemctl enable lblet
```

#### 3.1.4 启动 lblet

由于服务管理⽅式不同，启动⽅式也有所区别：

```bash
# Linux 6
service lblet start

# Linux 7
systemctl lblet start
```

### 3.2 windows 下部署

将压缩包上传⾄服务器，创建⽬录 C:\howlink，将压缩包解压⾄该⽬录下

#### 3.2.1 启动iSCSI服务

与Linux的相同，当前版本的lblet，依赖于iSCSI客户端（即将⽀持FC），在启动lblet之前，需要先启动iSCSI服务。打开“iSCSI发起程序”，如果提示服务尚未运⾏，请单击“是"以启动该服务。

#### 3.2.2 同意协议

由于SQLServer和MySQL会调⽤sync.exe，该程序⾸次运⾏需要同意协议，故这两种备份需要同意程序的使⽤协议：双击运⾏C:\howlink\cdm\scripts\sync.exe，点击“同意”按钮即可。

#### 3.2.3 测试VSS

由于SQLServer和MySQL的备份需要调⽤VSS（卷影复制），故使⽤lblet之前需要测试VSS能否正常运⾏。
在CMD窗⼝或PowerShell下运⾏此命令：
如果返回值报错，缺少依赖等，请按照提示安装依赖，依赖包已放置于公司NAS指定位置。
依赖中包括.NET4.5和VC++运⾏库。如果返回值最后⼀⾏为“True”，则继续执⾏，成功执⾏将会返回“True”

#### 3.2.4 修改配置⽂件

修改lblet的配置⽂件，以下是 config/config.ini 内容：

```bash
cat /opt/howlink/cdm/config/config.init
# 需改lblet名称，该值唯⼀

name = orac1
# cdm
service.group = com.howlink.cdm

# 这⼉是connector对外的地址，必须是lblet可以访问的地址
connector.address=$SERVER_IP:8089

[lblet]
scripts=C:\howlink\cdm\static
point=C:\howlink\cdm\touch
cdm-oracle=C:\howlink\cdm\bin\cdm-oracle
cdm-disk=C:\howlink\cdm\bin\cdm-disk
```

### 3.2.5 启动 lblet

为了⽅便运⾏，建议新建批处理⽂件start.bat，内容如下：

```bash
C:\howlink\cdm\bin\lblet.exe
```

推荐将该脚本拖拽⼊PowerShell窗⼝，回⻋以运⾏。

> 注：PowerShell 必须以管理员方式启动

### 3.3 更新 lblet

CDM3.1 ⽀持lblet启动更新，解压 cdm.tar.gz 包获取 lblet 的上传到指定⻚⾯：

<img src="data:image/svg+xml,<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1558 727"></svg>" alt="image-20211231162116591" style="zoom:200%;" />

## 四、使用 cdm-dp 部署

cdm-dp 工具是 cdm 项目的部署工具、可以帮助用户快速部署 cdm 的各种组件。

cdm-dp 存放在 cdm.tar.gz 压缩包中，支持三种平台

```bash
[root@localhost cdm]# ll
总用量 227592
-rw-r--r--. 1 root root  10096787 12月 31 09:44 dp-linux_amd64.tar.gz
-rw-r--r--. 1 root root   6992170 12月 31 09:45 dp-linux_arm64.tar.gz
-rw-r--r--. 1 root root  14278990 12月 31 09:45 dp-windows_amd64-.zip
drwxr-xr-x. 2 root root       202 12月 31 09:46 lblets
drwxr-xr-x. 3 root root       143 12月 30 14:41 module
-rw-r--r--. 1 root root 103992110 12月 31 09:44 server-linux_amd64.tar.gz
-rw-r--r--. 1 root root  74248501 12月 31 09:43 server-linux_arm64.tar.gz
-rw-r--r--. 1 root root  12304591 12月 31 09:44 storage-linux_amd64.tar.gz
-rw-r--r--. 1 root root  11118095 12月 31 09:44 storage-linux_arm64.tar.gz
```

接下来以x86_64平台为例，介绍 cdm-dp 的使用方式。

解压 cdm-dp

```bash
tar -xvf dp-linux_amd64.tar.gz
```

### 4.1 安装 lb-storage 组件

> 注：lb-storage 推荐安装在 CentOS7 发行版上， 需要配置网络或本地 yum 源码，后者可以参考 0.1 节的文档。

执行以下命令安装 lb-storage 组件

```bash
./dist/cdm-dp storage --ip=$IP --port=11201 --pkg=. --name=storage
```

支持以下参数：

- --ip string     存储IP地址
- --name string   存储组件名称
- --pkg string    组件安装包路径
- --port int32    存储端口

执行完成后会依次安装 zfs、scst、nfs、lb-storage。

### 4.2 安装服务端组件

> 注：服务端组件推荐安装在 CentOS7 发行版上， 需要配置网络或本地 yum 源码，后者可以参考 0.1 节的文档。

执行以下命令安装服务端组件

```bash
/dist/cdm-dp server --ip=$IP --pkg=.
```

支持以下参数：

- --ip string     服务端节点IP地址
- --pkg string    组件安装包路径

执行完成后会依次安装 etcd、lb-admin、lb-gateway、lb-workflow、lb-connector。

安装完成后可以通过浏览器访问 http://$IP:9090 来验证。

### 4.3 安装客户端

#### 4.3.1 linux 

复制 cdm.tar.gz 到待安装 lblet 的主机，解压 cdm.tar.gz 和 dp-linux_amd64.tar.gz

```bash
tar -xvf cdm.tar.gz
cd cdm
tar -xvf dp-linux_amd64.tar.gz
```

安装 lblet

```
./dist/cdm-dp lblet --name=$NAME --server-ip=$SERVER_IP --pkg=.
```

支持以下参数：

- --server-ip string     服务端节点IP地址
- --name string  lblet 标识名称
- --pkg string    组件安装包路径

> 注：安装前确认服务端和lblet节点的网络连接情况。

#### 4.3.2 windows

解压 cdm 下的 dp-windows_amd64.zip 文件，将 dist/cdm-dp.exe 和 lblets 复制到待安装节点的 C:\howlink 下。

通过管理员方式打开 cmd.exe，执行以下命令

```bash
C:\Users\Administrator> C:\howlink\cdm-dp.exe lblet --pkg=C:\howlink\lblets --server-ip=$IP --name=$NAME --password=$PASSWORD
```

支持以下参数：

- --server-ip string     服务端节点IP地址
- --name string  lblet 标识名称
- --pkg string    组件安装包路径
- --password  Administrator 用户的登录密码

> 注：安装前确认服务端和lblet节点的网络连接情况。iscsi 客户端已安装且可用
