---
title: "oracle11g 单机创建 data guard"
date: 2023-03-29T15:51:40+08:00
lastmod: 2023-03-29T15:51:40+08:00
draft: false
keywords:
  - oracle
  - linux
tags:
  - oracle
categories:
  - 运维
  - 数据库
---

# 准备环境

|             | 主库                                    | 备库                                    |
| ----------- | --------------------------------------- | --------------------------------------- |
| 操作系统    | CentOS7                                 | CentOS7                                 |
| 数据库版本  | oracle 11.2.0.4.0                       | oracle 11.2.0.4.0                       |
| ip 地址     | 192.168.2.141                           | 192.168.2.142                           |
| ORACLE_BASE | /u01/app/oracle                         | /u01/app/oracle                         |
| ORACLE_HOME | /u01/app/oracle/product/11.2.0/dbhome_1 | /u01/app/oracle/product/11.2.0/dbname_1 |
| SID         | orcl                                    | orclst                                  |

# 1.主库修改参数

开始归档模式 (只有这步需要重启数据库)

```sql
SQL> shutdown immediate;
SQL> startup mount;
SQL> alter database archivelog;
SQL> alter database open;
-- 数据库设置为 force logging
SQL> alter database force logging;
SQL> select name,log_mode,force_logging from v$database;

NAME	  LOG_MODE     FOR
--------- ------------ ---
ORCL	  ARCHIVELOG   YES
```

修改监听文件 `$ORACLE_HOME/network/admin/listener.ora`，添加以下内容

```bash
SID_LIST_LISTENER =
  (SID_LIST =
    (SID_DESC =
      (GLOBAL_DBNAME = ORCL )
      (ORACLE_HOME = /u01/app/oracle/product/11.2.0/dbhome_1 )
      (SID_NAME = orcl )
    )
  )
```

添加 standby 日志

```sql
SQL> select thread#,group#,members,bytes/1024/1024 from v$log;

   THREAD#     GROUP#	 MEMBERS BYTES/1024/1024
---------- ---------- ---------- ---------------
	 1	    1	       1	      50
	 1	    2	       1	      50
	 1	    3	       1	      50

-- 添加和 log 相同数量的 standby 日志
SQL> alter database add standby logfile group 11 ('/u01/app/oracle/oradata/orcl/redo/redo11_std01.log') size 50M;
SQL> alter database add standby logfile group 12 ('/u01/app/oracle/oradata/orcl/redo/redo12_std01.log') size 50M;
SQL> alter database add standby logfile group 13 ('/u01/app/oracle/oradata/orcl/redo/redo13_std01.log') size 50M;

SQL> select group#,thread#,sequence#,archived,status from v$standby_log;

    GROUP#    THREAD#  SEQUENCE# ARC STATUS
---------- ---------- ---------- --- ----------
	11	    0	       0 YES UNASSIGNED
	12	    0	       0 YES UNASSIGNED
	13	    0	       0 YES UNASSIGNED
```

设置数据库口令文件的使用模式

```sql
SQL> show parameter remote_login_passwordfile;

NAME				     TYPE	 VALUE
------------------------------------ ----------- ------------------------------
remote_login_passwordfile	     string	 EXCLUSIVE

-- 设置为 EXCLUSIVE，注意修改完需要重启数据库
SQL> alter system set remote_login_passwordfile=EXCLUSIVE scope=spfile;
SQL> shutdown immediate;
SQL> startup;
```

参数设置

```sql
-- 启动 broker
SQL> alter system set dg_broker_start=true scope=both;
-- 修改日志转化模式
SQL> alter system set log_archive_config='DG_CONFIG=(orcl,orclst)' scope=spfile;
-- 添加归档日志路径
SQL> alter system set log_archive_dest_1='location=/u01/app/oracle/oradata/orcl/archive valid_for=(all_logfiles,all_roles) db_unique_name=orcl' scope=spfile;
SQL> alter system set log_archive_dest_2='service=(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=192.168.2.142)(PORT=1521))(CONNECT_DATA=(SERVICE_NAME=ORCLST)(INSTANCE_NAME=orclst)(SERVER=DEDICATED))) LGWR ASYNC VALID_FOR=(ONLINE_LOGFILES,PRIMARY_ROLE) db_unique_name=orclst' scope=spfile;
SQL> alter system set log_archive_dest_state_1='ENABLE' scope=spfile;
SQL> alter system set log_archive_dest_state_2='ENABLE' scope=spfile;
-- 配置 fal
SQL> alter system set fal_client='(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=192.168.2.141)(PORT=1521))(CONNECT_DATA=(SERVICE_NAME=ORCL)(INSTANCE_NAME=orcl)(SERVER=DEDICATED)))';
SQL> alter system set fal_server='(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=192.168.2.142)(PORT=1521))(CONNECT_DATA=(SERVICE_NAME=ORCLST)(INSTANCE_NAME=orclst)(SERVER=DEDICATED)))';
-- 设置归档日志进程的最大数量
SQL> alter system set log_archive_max_processes=10 scope=both;
-- 设置备库文件管理模式
SQL> alter system set standby_file_management='AUTO';
-- 启动 OMF 功能
SQL> alter system set db_create_file_dest='/u01/app/oracle/oradata/orcl/datafile' scope=spfile;
-- 如果主备库文件的存放路径不一致，还需要修改以下参数
SQL> alter system set db_file_name_convert='/u01/app/oracle/oradata/orcl','/u01/app/oracle/oradata/orclst' scope=spfile;
SQL> alter system set log_file_name_convert='/u01/app/oracle/oradata/orcl/onlinelog','/u01/app/oracle/oradata/orclst/onlinelog' scope=spfile;
-- 生成 pfile
SQL> create pfile='/tmp/initorcl.ora' from spfile;
```

创建 oracle 密码文件

```sql
su - oracle
orapwd file=/tmp/orapworcl password=oracle
```

将密码文件和 pfile 复制到备库机器上，并修改为备库的 sid

# 2.启动备库

复制 initorcl.ora 和 orapworcl

```bash
root# mv initorcl.ora $ORACLE_HOME/dbs/initorclst.ora
root# mv orapworcl $ORACLE_HOME/dbs/orapworclst
root# chown oracle:oinstall $ORACLE_HOME/dbs/initorclst.ora
root# chown oracle:oinstall $ORACLE_HOME/dbs/orapworclst
```

修改 initorclst.ora

```bash
orcl.__db_cache_size=654311424
orcl.__java_pool_size=16777216
orcl.__large_pool_size=33554432
orcl.__oracle_base='/u01/app/oracle'#ORACLE_BASE set from environment
orcl.__pga_aggregate_target=637534208
orcl.__sga_target=956301312
orcl.__shared_io_pool_size=0
orcl.__shared_pool_size=234881024
orcl.__streams_pool_size=0
*.audit_file_dest='/u01/app/oracle/admin/orclst/adump'
*.audit_trail='db'
*.compatible='11.2.0.4.0'
*.control_files='/u01/app/oracle/oradata/orclst/control01.ctl','/u01/app/oracle/fast_recovery_area/orclst/control02.ctl'
*.db_block_size=8192
*.db_create_file_dest='/u01/app/oracle/oradata/orclst/datafile'
*.db_domain=''
*.db_file_name_convert='/u01/app/oracle/oradata/orcl','/u01/app/oracle/oradata/orclst'
# 这个需要和主库 SID 一直
*.db_name='orcl'
# 这里修改备库 SID
*.db_unique_name='orclst'
*.db_recovery_file_dest='/u01/app/oracle/fast_recovery_area'
*.db_recovery_file_dest_size=4385144832
*.dg_broker_start=TRUE
*.diagnostic_dest='/u01/app/oracle'
*.dispatchers='(PROTOCOL=TCP) (SERVICE=orclstXDB)'
*.fal_server='(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=192.168.2.141)(PORT=1521))(CONNECT_DATA=(SERVICE_NAME=ORCL)(INSTANCE_NAME=orcl)(SERVER=DEDICATED)))'
*.fal_client='(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=192.168.2.142)(PORT=1521))(CONNECT_DATA=(SERVICE_NAME=ORCLST)(INSTANCE_NAME=orclst)(SERVER=DEDICATED)))'
*.log_archive_config='DG_CONFIG=(orcl,orclst)'
*.log_archive_dest_1='location=/u01/app/oracle/oradata/orclst/archive valid_for=(all_logfiles,all_roles) db_unique_name=orclst'
*.log_archive_dest_2='service=(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=192.168.2.141)(PORT=1521))(CONNECT_DATA=(SERVICE_NAME=ORCL)(INSTANCE_NAME=orcl)(SERVER=DEDICATED))) LGWR ASYNC VALID_FOR=(ONLINE_LOGFILES,PRIMARY_ROLE) db_unique_name=orcl'
*.log_archive_dest_state_1='ENABLE'
*.log_archive_dest_state_2='ENABLE'
*.log_archive_max_processes=10
*.log_file_name_convert='/u01/app/oracle/oradata/orcl/onlinelog','/u01/app/oracle/oradata/orclst/onlinelog'
*.memory_target=1588592640
*.open_cursors=300
*.processes=150
*.remote_login_passwordfile='EXCLUSIVE'
*.standby_file_management='AUTO'
*.undo_tablespace='UNDOTBS1'
```

- 注：需要 spfile 中创建字段包含的目录并设置 oracle:oinstall 文件属主

启动数据库

```bash
# export ORACLE_SID=orclst
# sqlplus / as sysdba
SQL> startup nomount pfile=/u01/app/oracle/product/11.2.0/dbname_1/dbs/initorclst.ora;
# 创建 spfile
SQL> create spfile from pfile;
```

修改监听文件 `$ORACLE_HOME/network/admin/listener.ora`，添加以下内容

```bash
SID_LIST_LISTENER =
  (SID_LIST =
    (SID_DESC =
      (GLOBAL_DBNAME = ORCLST )
      (ORACLE_HOME = /u01/app/oracle/product/11.2.0/dbname_1 )
      (SID_NAME = orclst )
    )
  )
```

# 3.同步数据

在主库上使用 rman 同步数据到备份

```sql
rman target sys/oracle@'(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=192.168.2.141)(PORT=1521))(CONNECT_DATA=(SERVICE_NAME=ORCL)(INSTANCE_NAME=orcl)(SERVER=DEDICATED)))' auxiliary sys/oracle@'(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=192.168.2.142)(PORT=1521))(CONNECT_DATA=(SERVICE_NAME=ORCLST)(INSTANCE_NAME=orclst)(SERVER=DEDICATED)))'
run {
SET NEWNAME FOR DATABASE TO '/u01/app/oracle/oradata/orclst/datafile/%U';
duplicate target database for standby from active database dorecover;
}
```

# 4.启动备库

重启数据库

```sql
SQL> shutdown immediate;

SQL> startup mount;
SQL> alter database flashback on;
SQL> alter database open;
SQL> alter database recover managed standby database using current logfile disconnect from session;
```

# 5.配置 broker

使用 broker 管理 oracle data guard 环境，在主库机器上执行相关操作

```sql
# export ORACLE_SID=orcl
# dgmgrl /
# 创建 broker
DGMGRL> CREATE CONFIGURATION orcl_broker AS PRIMARY DATABASE IS orcl CONNECT IDENTIFIER IS '(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=192.168.2.141)(PORT=1521))(CONNECT_DATA=(SERVER=DEDICATED)(SERVICE_NAME=ORCL)))';
# 添加备库
DGMGRL> ADD DATABASE orclst AS CONNECT IDENTIFIER IS '(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=192.168.2.142)(PORT=1521))(CONNECT_DATA=(SERVER=DEDICATED)(SERVICE_NAME=ORCLST)))';
# 启动 broker
DGMGRL> ENABLE CONFIGURATION;
# 设置主备库静态连接，之后就不用再备份监听文件了
DGMGRL> EDIT DATABASE orcl SET PROPERTY StaticConnectIdentifier='(DESCRIPTION=(ADDRESS=(PROTOCOL=tcp)(HOST=192.168.2.141)(PORT=1521))(CONNECT_DATA=(SERVICE_NAME=ORCL)(INSTANCE_NAME=orcl)(SERVER=DEDICATED)))';
DGMGRL> EDIT DATABASE orclst SET PROPERTY StaticConnectIdentifier='(DESCRIPTION=(ADDRESS=(PROTOCOL=tcp)(HOST=192.168.2.142)(PORT=1521))(CONNECT_DATA=(SERVICE_NAME=ORCLST)(INSTANCE_NAME=orclst)(SERVER=DEDICATED)))';
```

# broker 操作

## 查看 data guard 信息

```bash
$ export ORACLE_SID=orcl
$ dgmgrl /
DGMGRL for Linux: Version 11.2.0.4.0 - 64bit Production

Copyright (c) 2000, 2009, Oracle. All rights reserved.

Welcome to DGMGRL, type "help" for information.
Connected.
DGMGRL> show configuration verbose;

Configuration - orcl_broker

  Protection Mode: MaxPerformance
  Databases:
    orcl   - Primary database
    orclst - Physical standby database
      Warning: ORA-16857: standby disconnected from redo source for longer than specified threshold

  Properties:
    FastStartFailoverThreshold      = '30'
    OperationTimeout                = '30'
    FastStartFailoverLagLimit       = '30'
    CommunicationTimeout            = '180'
    ObserverReconnect               = '0'
    FastStartFailoverAutoReinstate  = 'TRUE'
    FastStartFailoverPmyShutdown    = 'TRUE'
    BystandersFollowRoleChange      = 'ALL'
    ObserverOverride                = 'FALSE'
    ExternalDestination1            = ''
    ExternalDestination2            = ''
    PrimaryLostWriteAction          = 'CONTINUE'

Fast-Start Failover: DISABLED

Configuration Status:
WARNING
```

## 查看数据库信息

```bash
DGMGRL> show database verbose orcl

Database - orcl

  Role:            PRIMARY
  Intended State:  TRANSPORT-ON
  Instance(s):
    orcl

  Properties:
    DGConnectIdentifier             = '(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=192.168.2.141)(PORT=1521))(CONNECT_DATA=(SERVER=DEDICATED)(SERVICE_NAME=ORCL)))'
    ObserverConnectIdentifier       = ''
    LogXptMode                      = 'ASYNC'
    DelayMins                       = '0'
    Binding                         = 'optional'
    MaxFailure                      = '0'
    MaxConnections                  = '1'
    ReopenSecs                      = '300'
    NetTimeout                      = '30'
    RedoCompression                 = 'DISABLE'
    LogShipping                     = 'ON'
    PreferredApplyInstance          = ''
    ApplyInstanceTimeout            = '0'
    ApplyParallel                   = 'AUTO'
    StandbyFileManagement           = 'MANUAL'
    ArchiveLagTarget                = '0'
    LogArchiveMaxProcesses          = '10'
    LogArchiveMinSucceedDest        = '1'
    DbFileNameConvert               = '/u01/app/oracle/oradata/orcl, /u01/app/oracle/oradata/orclst'
    LogFileNameConvert              = '/u01/app/oracle/oradata/orcl/onlinelog, /u01/app/oracle/oradata/orclst/onlinelog'
    FastStartFailoverTarget         = ''
    InconsistentProperties          = '(monitor)'
    InconsistentLogXptProps         = '(monitor)'
    SendQEntries                    = '(monitor)'
    LogXptStatus                    = '(monitor)'
    RecvQEntries                    = '(monitor)'
    ApplyLagThreshold               = '0'
    TransportLagThreshold           = '0'
    TransportDisconnectedThreshold  = '30'
    SidName                         = 'orcl'
    StaticConnectIdentifier         = '(DESCRIPTION=(ADDRESS=(PROTOCOL=tcp)(HOST=192.168.2.141)(PORT=1521))(CONNECT_DATA=(SERVICE_NAME=ORCL)(INSTANCE_NAME=orcl)(SERVER=DEDICATED)))'
    StandbyArchiveLocation          = '/u01/app/oracle/oradata/orcl/archive'
    AlternateLocation               = ''
    LogArchiveTrace                 = '0'
    LogArchiveFormat                = '%t_%s_%r.dbf'
    TopWaitEvents                   = '(monitor)'

Database Status:
SUCCESS
```

## switchover

执行 switchover 切换，先连接到备库

```bash
$ dgmgrl /
# 使用 identifier 连接
DGMGRL> connect sys/oracle@'(DESCRIPTION=(ADDRESS=(PROTOCOL=tcp)(HOST=192.168.2.142)(PORT=1521))(CONNECT_DATA=(SERVICE_NAME=ORCLST)(INSTANCE_NAME=orclst)(SERVER=DEDICATED)))';
Connected.
# 使用 switchover 命令执行主备切换
DGMGRL> switchover to orclst;
```

切换过程中如果出现 `ORA-12514: TNS:listener does not currently know of service requested in connect descriptor` 错误，直接启动源主库即可

```bash
$ dgmgrl /
DGMGRL> startup;
DGMGRL> show configuration verbose;
```

## failover

模拟主库意外关闭

```sql
SQL> shutdown abort
```

在备库上执行 failover 切换

```bash
$ dgmgrl /
DGMGRL> failover to orclst
```

重新启动原主库，想要原主库启动可用，需要保证开启闪回

```sql
-- 启动原主库
SQL> startup mount;
-- 这个 scn 从现主库查看，sql 语句为 select to_char(standby_became_primary_scn) from v$database
SQL> flashback database to scn 1129493;
-- 切换数据库角色
SQL> alter database convert to physical standby;
-- 重启数据库并恢复
SQL> shutdown immediate;
SQL> startup;
SQL> alter database recover managed standby database using current logfile disconnect from session;
```

最后调整 broker，在现主库上操作

```bash
$ dgmgrl /
DGMGRL> reinstate database orcl;
DGMGRL> show configuration;

Configuration - orcl_broker

  Protection Mode: MaxPerformance
  Databases:
    orclst - Primary database
    orcl   - Physical standby database

Fast-Start Failover: DISABLED

Configuration Status:
SUCCESS
```

查看状态，可以看出 dg 已经恢复正常
