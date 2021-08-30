---
title: "Dblink"
date: 2021-08-30T17:49:19+08:00
lastmod: 2021-08-30T17:49:19+08:00
draft: false
description: ""
featuredImage: "https://raw.githubusercontent.com/xingyys/myblog/main/posts/images/20210830185536.png"
tags: 
 - oracle
categories: 
 - 笔记
author: "Lack"
---

查询所有触发器
```sql
select * from user_triggers;
```
根据名称禁用触发器
```sql
alter trigger LOGMNRGGC_TRIGGER disable;
```
查询所有 job
```sql
select * from user_jobs;
```
根据 id 禁用 job
```sql
BEGIN dbms_job.broken(4001,true); END;
```

禁用 oracle dblink
```sql
alter system set open_links=0 sid='$sid' scope=spfile;
alter system set open_links_per_instance=0 sid='$sid' scope=spfile;
```

启用 oracle dblink
```sql
alter system set open_links=4 sid='$sid' scope=spfile;
alter system set open_links_per_instance=4 sid='$sid' scope=spfile;
```