# Scst 安装和使用


# 安装 scst
安装 scst
```bash
wget https://ncu.dl.sourceforge.net/project/scst/scst-3.2.0.7058.tar.bz2
yum install bzip2 
bunzip2 scst-3.2.0.7058.tar.bz2 
tar xf scst-3.2.0.7058.tar 
```
编译安装scst 
```bash
make 2perf 
make scst 
make scst_install 
make iscsi 
make iscsi_install 
make scstadm 
make scstadm_install
```
查看是否被加载到内核了 
```bash
lsmod |grep scst modinfo scst 
```
启动 scst 
```bash
modprobe scst 
modprobe scst_vdisk 
modprobe scst_disk 
modprobe scst_user 
modprobe scst_modisk 
modprobe scst_processor 
modprobe scst_raid 
modprobe scst_tape 
modprobe scst_cdrom 
modprobe scst_changer 
modprobe iscsi-scst 
iscsi-scstd
```
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

