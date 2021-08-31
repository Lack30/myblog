# 开启oracle的闪回功能


查看是否开启闪回
```sql
SQL> select flashback_on from v$database;

FLASHBACK_ON
------------------
NO
```

查看是否配置了db_recover_file_dest   
```sql
SQL> show parameter db_recovery

NAME				     TYPE	 VALUE
------------------------------------ ----------- ------------------------------
db_recovery_file_dest		     string
db_recovery_file_dest_size	     big integer 0
```

没有配置的话，先创建对应的目录，注意目录的权限和oracle数据库的一致
```bash
mkdir /u01/flashback
chown oracle:oinstall /u01/flashback
```
```sql
SQL> alter system set db_recovery_file_dest_size=30G scope=both;
SQL> alter system set db_recovery_file_dest='/u01/flashback'  scope=both;

System altered.
```

关闭 oracle
```sql
SQL> shutdown immediate;
Database closed.
Database dismounted.
ORACLE instance shut down.
```
启动到 mount 状态
```sql
SQL> startup mount;
ORACLE instance started.

Total System Global Area 1603411968 bytes
Fixed Size		    2253664 bytes
Variable Size		  905972896 bytes
Database Buffers	  687865856 bytes
Redo Buffers		    7319552 bytes
Database mounted.
```          
开启 archeve log
```sql
SQL> alter database archivelog;

Database altered.
```
开启闪回功能
```sql
SQL> alter database flashback on;

Database altered.
```
启动数据库到 open 状态
```sql
SQL> alter database open;

Database altered.
```

```sql
SQL> select flashback_on from v$database;

FLASHBACK_ON
------------------
YES
```

