---
title: "CentOS7 静默安装单机 oracle11g"
date: 2023-03-27T21:00:17+08:00
lastmod: 2023-03-27T21:00:17+08:00
draft: false
keywords:
  - oracle
  - linux
description: ""
tags:
  - oracle
categories:
  - 运维
  - 数据库
author: "Lack"
---

# 确认资源

| 用户            | oracle                               |
| --------------- | ------------------------------------ |
| 安装包解压目录  | /u01/database                        |
| ORACLE_BASE     | /u01/app/oracle                      |
| ORACLE_HOME     | $ORACLE_BASE/product/11.2.0/dbname_1 |
| ORACLE_SID      | orcl                                 |
| GDBNAME         | orcl                                 |
| sysdba 用户密码 | oracle                               |
| sys 用户密码    | oracle                               |
| system 用户密码 | oracle                               |
| 数据库版本      | 11.2.0.4                             |
| 操作系统版本    | CentOS 7.5                           |

# 环境配置

修改主机名

```bash
hostnamectl set-hostname oracle
echo "127.0.0.1 oracle" >>/etc/hosts
```

关闭 selinux 和防火墙

```bash
setenforce 0
sed -i "s/SELINUX=enforcing/SELINUX=disabled/g "/etc/selinux/config
systemctl stop firewalld
systemctl disable firewalld
```

创建 oracle 用户和组

```bash
groupadd oinstall
groupadd dba
useradd -g oinstall -G dba oracle
```

修改 orace 用户密码

```bash
echo oracle | passwd --stdin oracle
```

安装依赖包

```bash
yum install -y gcc gcc-c++ make binutils compat-libstdc++-33 elfutils-libelf elfutils-libelf-devel glibc glibc-common glibc-devel libaio libaio-devel libgcc libstdc++ libstdc++-devel unixODBC unixODBC-devel ksh
```

修改内核参数

```bash
cat >> /etc/sysctl.conf << EOF
fs.aio-max-nr = 1048576
fs.file-max = 6815744
kernel.shmall = 2097152
kernel.shmmax = 4100861952
kernel.shmmni = 4096
kernel.sem = 250 32000 100 128
net.ipv4.ip_local_port_range = 9000 65500
net.core.rmem_default = 262144
net.core.rmem_max = 4194304
net.core.wmem_default = 262144
net.core.wmem_max = 1048576
EOF
sysctl -p
```

修改 oracle 用户限制参数

```bash
cat >>  /etc/security/limits.conf  << EOF
oracle        soft        nproc        16384
oracle        hard        nproc        16384
oracle        soft        nofile       16384
oracle        hard        nofile       65536
oracle        soft        stack        10240
oracle        hard        stack        32768
oracle        soft        memlock      2000000
oracle        hard        memlock      2000000
EOF
```

# 安装 oracle

创建 oracle 目录

```bash
mkdir -p /u01/app/oracle/{product/11.2.0/dbhome_1,oradata,oraInventory,recovery_area}
chown -R oracle:oinstall /u01/app/oracle
chmod 775 /u01/app/oracle
```

解压 oracle 压缩包

```bash
mkdir -pv /u01/
unzip p13390677_112040_Linux-x86-64_1of7.zip -d /u01/
unzip p13390677_112040_Linux-x86-64_2of7.zip -d /u01/
chown -R oracle:oinstall /u01/database
```

- 安装单机版本的 oracle 只需要前两个包

修改 oracle 安装应答文件，使用静默安装

```bash
sed -i 's/oracle.install.option=.*/oracle.install.option=INSTALL_DB_SWONLY/g' /u01/database/response/db_install.rsp
sed -i 's/ORACLE_HOSTNAME=.*/ORACLE_HOSTNAME=oracle/g' /u01/database/response/db_install.rsp
sed -i 's/UNIX_GROUP_NAME=.*/UNIX_GROUP_NAME=oinstall/g' /u01/database/response/db_install.rsp
sed -i 's#INVENTORY_LOCATION=.*#INVENTORY_LOCATION=/u01/app/oracle/oraInventory#g' /u01/database/response/db_install.rsp
sed -i 's#ORACLE_HOME=.*#ORACLE_HOME=/u01/app/oracle/product/11.2.0/dbname_1#g' /u01/database/response/db_install.rsp
sed -i 's#ORACLE_BASE=.*#ORACLE_BASE=/u01/app/oracle#g' /u01/database/response/db_install.rsp
sed -i 's/oracle.install.db.InstallEdition=.*/oracle.install.db.InstallEdition=EE/g' /u01/database/response/db_install.rsp
sed -i 's/oracle.install.db.DBA_GROUP=.*/oracle.install.db.DBA_GROUP=oinstall/g' /u01/database/response/db_install.rsp
sed -i 's/oracle.install.db.OPER_GROUP=.*/oracle.install.db.OPER_GROUP=oinstall/g' /u01/database/response/db_install.rsp
sed -i 's/oracle.install.db.config.starterdb.characterSet=.*/oracle.install.db.config.starterdb.characterSet=ZHS16GBK/g' /u01/database/response/db_install.rsp
sed -i 's/oracle.install.db.config.starterdb.storageType=.*/oracle.install.db.config.starterdb.storageType=FILE_SYSTEM_STORAGE/g' /u01/database/response/db_install.rsp
sed -i 's/DECLINE_SECURITY_UPDATES=.*/DECLINE_SECURITY_UPDATES=true/g' /u01/database/response/db_install.rsp
sed -i 's/oracle.installer.autoupdates.option=.*/oracle.installer.autoupdates.option=SKIP_UPDATES/g' /u01/database/response/db_install.rsp
```

设置 oracle 环境变量

```bash
su - oracle
echo 'export ORACLE_BASE=/u01/app/oracle
export ORACLE_HOME=$ORACLE_BASE/product/11.2.0/dbname_1
export PATH=$PATH:$ORACLE_HOME/bin
export CLASSPATH=$ORACLE_HOME/JRE:$ORACLE_HOME/jlib:$ORACLE_HOME/rdbms/jlib
export LD_LIBRARY_PATH=$ORACLE_HOME/lib:/lib64:/usr/lib64:/usr/local/lib64
export ORACLE_SID=orcl
export NLS_LANG=AMERICAN_AMERICA.ZHS16GBK' >> .bash_profile
source .bash_profile
```

安装 oraInventory 文件

```bash
# vi /etc/oraInventory.loc
inventory_loc=/u01/app/oracle/oraInventory
inst_group=oinstall
```

安装 oracle 数据库

```bash
su - oracle
/u01/database/runInstaller -silent -ignorePrereq -waitforcompletion -responseFile /u01/database/response/db_install.rsp
```

切换到 root 用户执行 root.sh 脚本

```bash
su - root
/u01/app/oracle/oraInventory/orainstRoot.sh
/u01/app/oracle/product/11.2.0/dbname_1/root.sh
```

# 配置监听

```bash
netca -silent -responseFile /u01/database/response/netca.rsp
```

监听会启动在 1521 上

```bash
$ netstat -tnlp | grep 1521
(Not all processes could be identified, non-owned process info
 will not be shown, you would have to be root to see it all.)
tcp6       0      0 :::1521                 :::*                    LISTEN      15233/tnslsnr
```

# 创建数据库实例

修改应答文件

```bash
sed -i 's/RESPONSEFILE_VERSION =.*/RESPONSEFILE_VERSION = "11.2.0"/g' /u01/database/response/dbca.rsp
sed -i 's/OPERATION_TYPE =.*/OPERATION_TYPE = "createDatabase"/g' /u01/database/response/dbca.rsp
sed -i 's/GDBNAME =.*/GDBNAME = "orcl"/g' /u01/database/response/dbca.rsp
sed -i 's/SID =.*/SID = "orcl"/g' /u01/database/response/dbca.rsp
sed -i 's/TEMPLATENAME =.*/TEMPLATENAME = "General_Purpose.dbc"/g' /u01/database/response/dbca.rsp
sed -i 's#.*DATAFILEDESTINATION =.*#DATAFILEDESTINATION = /u01/app/oracle/oradata#g' /u01/database/response/dbca.rsp
sed -i 's#.*RECOVERYAREADESTINATION =.*#RECOVERYAREADESTINATION=/u01/app/oracle/recovery_area#g' /u01/database/response/dbca.rsp
sed -i 's/CHARACTERSET =.*/CHARACTERSET = "ZHS16GBK"/g' /u01/database/response/dbca.rsp
sed -i 's/TOTALMEMORY =.*/TOTALMEMORY = "5120"/g' /u01/database/response/dbca.rsp
sed -i 's/#SYSDBAPASSWORD =.*/SYSDBAPASSWORD = "oracle"/g' /u01/database/response/dbca.rsp
sed -i 's/#SYSPASSWORD =.*/SYSPASSWORD = "oracle"/g' /u01/database/response/dbca.rsp
sed -i 's/#SYSTEMPASSWORD =.*/SYSTEMPASSWORD = "oracle"/g' /u01/database/response/dbca.rsp
```

使用 dbca 创建实例

```bash
su - oracle
dbca -silent -responseFile /u01/database/response/dbca.rsp
```

- 使用 dbca 也可以删除实例，使用命令为
  ```bash
  dbca -silent -deleteDatabase -sourcedb orcl
  ```

创建完成后就可以使用 sqlplus 登录

```bash
$ sqlplus / as sysdba

SQL*Plus: Release 11.2.0.4.0 Production on Mon Mar 27 20:52:42 2023

Copyright (c) 1982, 2013, Oracle.  All rights reserved.

Connected to:
Oracle Database 11g Enterprise Edition Release 11.2.0.4.0 - 64bit Production
With the Partitioning, OLAP, Data Mining and Real Application Testing options

SQL> select status from v$instance;

STATUS
------------------------
OPEN
```

以上就是在 CentOS7 上静默按 oracle 11g 的全部内容了
