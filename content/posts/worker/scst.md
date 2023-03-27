# 创建流程
创建 target
```bash
scstadmin -add_target iqn.1994-05.com.redhat:pv -driver iscsi
```
创建 block
```bash
scstadmin -open_dev pv -handler vdisk_blockio -attributes filename=/dev/zvol/tank/pv
```
创建 group 做访问控制
```bash
scstadmin -add_group pv -driver iscsi -target iqn.1994-05.com.redhat:pv
```
添加客户端
```bash
scstadmin -add_init iqn.1994-05.com.redhat:48d51365d2b -driver iscsi -target iqn.1994-05.com.redhat:pv -group pv
```
添加 lun
```bash
scstadmin -add_lun 0 -driver iscsi -target iqn.1994-05.com.redhat:pv -group pv -device pv
```
启用 target
```bash
scstadmin -enable_target iqn.1994-05.com.redhat:pv -driver iscsi
```
使用 iscsi driver
```bash
scstadmin -set_drv_attr iscsi -attributes enabled=1 -noprompt
```
写入到配置文件
```bash
scstadmin -write_config /etc/scst.conf
```
# 删除流程
禁用 target
```bash
scstadmin -disable_target iqn.1994-05.com.redhat:pv -driver iscsi -noprompt
```
删除 target 
```bash
scstadmin -rem_target iqn.1994-05.com.redhat:pv -driver iscsi -noprompt
```
删除 block
```bash
scstadmin -close_dev pv -handler vdisk_blockio -noprompt
```



```bash
scstadmin -open_dev xxnewv0 -handler vdisk_blockio -attributes filename=/dev/zvol/SSDPOOL/xxnewv0
scstadmin -add_target iqn.2018-11.com.howlink:xxnewv -driver iscsi 
scstadmin -add_group xxnewv -driver iscsi -target iqn.2018-11.com.howlink:xxnewv
scstadmin -add_init iqn.1988-12.com.oracle:8af69646247e -driver iscsi -target iqn.2018-11.com.howlink:xxnewv -group xxnewv
scstadmin -add_lun 0 -driver iscsi -target iqn.2018-11.com.howlink:xxnewv -group xxnewv -device xxnewv0
scstadmin -enable_target iqn.2018-11.com.howlink:xxnewv -driver iscsi
scstadmin -set_drv_attr iscsi -attributes enabled=1 -noprompt
scstadmin -write_config /etc/scst.conf
```

```bash
scstadmin -open_dev uxtqzr0 -handler vdisk_blockio -attributes filename=/dev/zvol/HDDPOOL/uxtqzr0
scstadmin -add_target iqn.2018-11.com.howlink:uxtqzr -driver iscsi 
scstadmin -add_group uxtqzr -driver iscsi -target iqn.2018-11.com.howlink:uxtqzr
scstadmin -add_init iqn.1991-05.com.microsoft:vm160-20170519 -driver iscsi -target iqn.2018-11.com.howlink:uxtqzr -group uxtqzr
scstadmin -add_lun 0 -driver iscsi -target iqn.2018-11.com.howlink:uxtqzr -group uxtqzr -device uxtqzr0
scstadmin -enable_target iqn.2018-11.com.howlink:uxtqzr -driver iscsi
scstadmin -set_drv_attr iscsi -attributes enabled=1 -noprompt
scstadmin -write_config /etc/scst.conf
```

