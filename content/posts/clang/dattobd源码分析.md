---
title: "Dattobd源码分析"
date: 2022-02-26T17:16:06+08:00
lastmod: 2022-02-26T17:16:06+08:00
draft: true
keywords: 
 - datto
description: ""
tags: 
 - C
 - 源码
categories: 
 - 开发
author: "Lack"
---

# 简介
[datto](https://github.com/datto/dattobd) 是 linux 下的一款备份工具。它能提供磁盘快照功能，并追踪 linux 内核中的块变化。datto 编译完成后生成三个工具，分别为:
- dattobd.ko : linux 内核模块，负责实际处理用户操作和追踪块变化。
- dbdctl : 用户态工具，通过 /etc/datto-ctl 字符文件和 dattobd.ko 通讯。
- update-img : 用户态工具，根据块变化信息间增量部分的数据写入到指定的块文件中。

# 源码分析

## 内部工作原理

dbdctl -> /etc/datto-ctl -> dattobd.ko

## 内核驱动
dattobd.ko 模块入口处位于 src/dattodb.c 中，内核模块统一入口为 `module_init`: 

### init
```C

static int __init agent_init(void){
    ...

	// 注册 /proc/datto-info，显示 datto 状态
	LOG_DEBUG("registering proc file");
	info_proc = proc_create(INFO_PROC_FILE, 0, NULL, &dattobd_proc_fops);

    ...

	// 注册 /dev/datto-ctl，负责和内核 dattobd.ko 通讯
	LOG_DEBUG("registering control device");
	ret = misc_register(&snap_control_device);

    // 替换 mount, umount hook
	if(dattobd_may_hook_syscalls) (void)hook_system_call_table();

	return 0;
    ...
}
module_init(agent_init);
```

## ioctl 
[ioctl](https://zh.wikipedia.org/wiki/Ioctl) 可以自定义系统调用，它是 dbdctl 和 dattobd.ko 通讯的桥梁，
```C
static const struct file_operations snap_control_fops = {
	.owner = THIS_MODULE,
	.unlocked_ioctl = ctrl_ioctl,
	.compat_ioctl = ctrl_ioctl,
	.open = nonseekable_open,
	.llseek = noop_llseek,
};

static struct miscdevice snap_control_device = {
	.minor = MISC_DYNAMIC_MINOR,
	.name = CONTROL_DEVICE_NAME,
	.fops = &snap_control_fops,
};
```
`/dev/datto-ctl` 操作函数为 ctrl_ioctl
```C
static long ctrl_ioctl(struct file *filp, unsigned int cmd, unsigned long arg){
	int ret, idx;
	char *bdev_path = NULL;
	char *cow_path = NULL;
	struct dattobd_info *info = NULL;
	unsigned int minor = 0;
	unsigned long fallocated_space = 0, cache_size = 0;

	LOG_DEBUG("ioctl command received: %d", cmd);
	mutex_lock(&ioctl_mutex);

	switch(cmd){
	case IOCTL_SETUP_SNAP:
		//get params from user space
		ret = get_setup_params((struct setup_params __user *)arg, &minor, &bdev_path, &cow_path, &fallocated_space, &cache_size);
		if(ret) break;

		ret = ioctl_setup_snap(minor, bdev_path, cow_path, fallocated_space, cache_size);
		if(ret) break;

		break;
	case IOCTL_RELOAD_SNAP:
		//get params from user space
		ret = get_reload_params((struct reload_params __user *)arg, &minor, &bdev_path, &cow_path, &cache_size);
		if(ret) break;

		ret = ioctl_reload_snap(minor, bdev_path, cow_path, cache_size);
		if(ret) break;

		break;
	case IOCTL_RELOAD_INC:
		//get params from user space
		ret = get_reload_params((struct reload_params __user *)arg, &minor, &bdev_path, &cow_path, &cache_size);
		if(ret) break;

		ret = ioctl_reload_inc(minor, bdev_path, cow_path, cache_size);
		if(ret) break;

		break;
	case IOCTL_DESTROY:
		//get minor from user space
		ret = get_user(minor, (unsigned int __user *)arg);
		if(ret){
			LOG_ERROR(ret, "error copying minor number from user space");
			break;
		}

		ret = ioctl_destroy(minor);
		if(ret) break;

		break;
	case IOCTL_TRANSITION_INC:
		//get minor from user space
		ret = get_user(minor, (unsigned int __user *)arg);
		if(ret){
			LOG_ERROR(ret, "error copying minor number from user space");
			break;
		}

		ret = ioctl_transition_inc(minor);
		if(ret) break;

		break;
	case IOCTL_TRANSITION_SNAP:
		//get params from user space
		ret = get_transition_snap_params((struct transition_snap_params __user *)arg, &minor, &cow_path, &fallocated_space);
		if(ret) break;

		ret = ioctl_transition_snap(minor, cow_path, fallocated_space);
		if(ret) break;

		break;
	case IOCTL_RECONFIGURE:
		//get params from user space
		ret = get_reconfigure_params((struct reconfigure_params __user *)arg, &minor, &cache_size);
		if(ret) break;

		ret = ioctl_reconfigure(minor, cache_size);
		if(ret) break;

		break;
	case IOCTL_DATTOBD_INFO:
		//get params from user space
		info = kmalloc(sizeof(struct dattobd_info), GFP_KERNEL);
		if(!info){
			ret = -ENOMEM;
			LOG_ERROR(ret, "error allocating memory for dattobd info");
			break;
		}

		ret = copy_from_user(info, (struct dattobd_info __user *)arg, sizeof(struct dattobd_info));
		if(ret){
			ret = -EFAULT;
			LOG_ERROR(ret, "error copying dattobd info struct from user space");
			break;
		}

		ret = ioctl_dattobd_info(info);
		if(ret) break;

		ret = copy_to_user((struct dattobd_info __user *)arg, info, sizeof(struct dattobd_info));
		if(ret){
			ret = -EFAULT;
			LOG_ERROR(ret, "error copying dattobd info struct to user space");
			break;
		}

		break;
	case IOCTL_GET_FREE:
		idx = get_free_minor();
		if(idx < 0){
			ret = idx;
			LOG_ERROR(ret, "no free devices");
			break;
		}

		ret = copy_to_user((int __user *)arg, &idx, sizeof(idx));
		if(ret){
			ret = -EFAULT;
			LOG_ERROR(ret, "error copying minor to user space");
			break;
		}

		break;
	default:
		ret = -EINVAL;
		LOG_ERROR(ret, "invalid ioctl called");
		break;
	}

	LOG_DEBUG("minor range = %u - %u", lowest_minor, highest_minor);
	mutex_unlock(&ioctl_mutex);

	if(bdev_path) kfree(bdev_path);
	if(cow_path) kfree(cow_path);
	if(info) kfree(info);

	return ret;
}
```
`datto` 中自定义如下的系统调用
```C
// dattobd.h

#define IOCTL_SETUP_SNAP _IOW(DATTO_IOCTL_MAGIC, 1, struct setup_params) //in: see above
#define IOCTL_RELOAD_SNAP _IOW(DATTO_IOCTL_MAGIC, 2, struct reload_params) //in: see above
#define IOCTL_RELOAD_INC _IOW(DATTO_IOCTL_MAGIC, 3, struct reload_params) //in: see above
#define IOCTL_DESTROY _IOW(DATTO_IOCTL_MAGIC, 4, unsigned int) //in: minor
#define IOCTL_TRANSITION_INC _IOW(DATTO_IOCTL_MAGIC, 5, unsigned int) //in: minor
#define IOCTL_TRANSITION_SNAP _IOW(DATTO_IOCTL_MAGIC, 6, struct transition_snap_params) //in: see above
#define IOCTL_RECONFIGURE _IOW(DATTO_IOCTL_MAGIC, 7, struct reconfigure_params) //in: see above
#define IOCTL_DATTOBD_INFO _IOR(DATTO_IOCTL_MAGIC, 8, struct dattobd_info) //in: see above
#define IOCTL_GET_FREE _IOR(DATTO_IOCTL_MAGIC, 9, int)
```
分别对应 `dbdctl` 工具的各个子命令。接下来我们来解析 `dbctl` 子命令执行中，dattobd.ko 内部运行机制。

## 命令解析

### setup-snapshot
`dbdctl setup-snapshot` 命令的作用是为一个块文件创建一个镜像。这个块文件必须是已挂载的，同时 cow_file 存储增量信息的文件必须保存在块文件内部。 
```bash
dbdctl setup-snapshot /dev/sda1 /boot/.datto 0
```
查看 `/proc/datto-info` 文件:
```bash
# cat /proc/datto-info
{
	"version": "0.10.16",
	"devices": [
		{
			"minor": 0,
			"cow_file": "/.datto",
			"block_device": "/dev/sda1",
			"max_cache": 314572800,
			"fallocate": 106954752,
			"seq_id": 1,
			"uuid": "cdca8aa58f6e42bf9ec94ad26a3d27ca",
			"version": 1,
			"nr_changed_blocks": 0,
			"state": 3
		}
	]
}
```
内部源码为:
```C
#define ioctl_setup_snap(minor, bdev_path, cow_path, fallocated_space, cache_size) __ioctl_setup(minor, bdev_path, cow_path, fallocated_space, cache_size, 1, 0)

...
static int __ioctl_setup(unsigned int minor, const char *bdev_path, const char *cow_path, unsigned long fallocated_space, unsigned long cache_size, int is_snap, int is_reload){
	int ret, is_mounted;
	struct snap_device *dev = NULL;

	LOG_DEBUG("received %s %s ioctl - %u : %s : %s", (is_reload)? "reload" : "setup", (is_snap)? "snap" : "inc", minor, bdev_path, cow_path);

	//verify that the minor number is valid
	ret = verify_minor_available(minor);
	if(ret) goto error;

	// 检测块文件是否挂载
	ret = __verify_bdev_writable(bdev_path, &is_mounted);
	if(ret) goto error;

	...

	//allocate the tracing struct
	ret = tracer_alloc(&dev);
	if(ret) goto error;

	//route to the appropriate setup function
	if(is_snap){
		// dbdctl setup-snapshot 命令内部实现
		if(is_mounted) ret = tracer_setup_active_snap(dev, minor, bdev_path, cow_path, fallocated_space, cache_size);
		else ...
	}else{
		...
	}

	if(ret) goto error;

	return 0;

error:
	LOG_ERROR(ret, "error during setup ioctl handler");
	if(dev) kfree(dev);
	return ret;
}


static int tracer_setup_active_snap(struct snap_device *dev, unsigned int minor, const char *bdev_path, const char *cow_path, unsigned long fallocated_space, unsigned long cache_size){
	int ret;

	set_bit(SNAPSHOT, &dev->sd_state);
	set_bit(ACTIVE, &dev->sd_state);
	clear_bit(UNVERIFIED, &dev->sd_state);

	//setup base device
	ret = __tracer_setup_base_dev(dev, bdev_path);
	if(ret) goto error;

	//setup the cow manager
	ret = __tracer_setup_cow_new(dev, dev->sd_base_dev, cow_path, dev->sd_size, fallocated_space, cache_size, NULL, 1);
	if(ret) goto error;

	//setup the cow path
	ret = __tracer_setup_cow_path(dev, dev->sd_cow->filp);
	if(ret) goto error;

	//setup the snapshot values
	ret = __tracer_setup_snap(dev, minor, dev->sd_base_dev, dev->sd_size);
	if(ret) goto error;

	//setup the cow thread and run it
	ret = __tracer_setup_snap_cow_thread(dev, minor);
	if(ret) goto error;

	wake_up_process(dev->sd_cow_thread);

	//inject the tracing function
	ret = __tracer_setup_tracing(dev, minor);
	if(ret) goto error;

	return 0;

error:
	LOG_ERROR(ret, "error setting up tracer as active snapshot");
	tracer_destroy(dev);
	return ret;
}
```
由此可知，`setup-snapshot` 分成以下步骤:
1. setup base device : 设置设备基本信息
2. setup the cow manager : 设置 cow 文件管理器
3. setup the cow path : 设置 cow 文件路径
4. setup the snapshot values : 设置快照盘信息
5. setup the cow thread and run it : 设置 cow 内核相关，并运行
6. inject the tracing function : 注入块追踪内核线程

接下来我们来依次说明每个步骤内部详情:

*1. 设置设备信息* 
```C
static int __tracer_setup_base_dev(struct snap_device *dev, const char *bdev_path){
	int ret;

	// 通过 bdev_path 路径获取 block_device 结构体
	LOG_DEBUG("finding block device");
	dev->sd_base_dev = blkdev_get_by_path(bdev_path, FMODE_READ, NULL);
	if(IS_ERR(dev->sd_base_dev)){
		ret = PTR_ERR(dev->sd_base_dev);
		dev->sd_base_dev = NULL;
		LOG_ERROR(ret, "error finding block device '%s'", bdev_path);
		goto error;
	}else if(!dev->sd_base_dev->bd_disk){
		ret = -EFAULT;
		LOG_ERROR(ret, "error finding block device gendisk");
		goto error;
	}

	//check block device is not already being traced
	LOG_DEBUG("checking block device '%s' is not already being traced", bdev_path);
	if(bdev_is_already_traced(dev->sd_base_dev)){
		ret = -EINVAL;
		LOG_ERROR(ret, "block device is already being traced");
		goto error;
	}

	//fetch the absolute pathname for the base device
	LOG_DEBUG("fetching the absolute pathname for the base device");
	ret = pathname_to_absolute(bdev_path, &dev->sd_bdev_path, NULL);
	if(ret) goto error;

	//check if device represents a partition, calculate size and offset
	LOG_DEBUG("calculating block device size and offset");
	if(dev->sd_base_dev->bd_contains != dev->sd_base_dev){
		dev->sd_sect_off = dev->sd_base_dev->bd_part->start_sect;
		dev->sd_size = dattobd_bdev_size(dev->sd_base_dev);
	}else{
		dev->sd_sect_off = 0;
		dev->sd_size = get_capacity(dev->sd_base_dev->bd_disk);
	}

	LOG_DEBUG("bdev size = %llu, offset = %llu", (unsigned long long)dev->sd_size, (unsigned long long)dev->sd_sect_off);

	return 0;

error:
	LOG_ERROR(ret, "error setting up base block device");
	__tracer_destroy_base_dev(dev);
	return ret;
}
```
主要的功能是获取 `dev->sd_base_dev`、`dev->sd_sect_off` 和 `dev->sd_size`。

*2. 设置 cow 文件管理器* 

```C
#define __tracer_setup_cow_new(dev, bdev, cow_path, size, fallocated_space, cache_size, uuid, seqid) __tracer_setup_cow(dev, bdev, cow_path, size, fallocated_space, cache_size, uuid, seqid, 0)

static int __tracer_setup_cow(struct snap_device *dev, struct block_device *bdev, const char *cow_path, sector_t size, unsigned long fallocated_space, unsigned long cache_size, const uint8_t *uuid, uint64_t seqid, int open_method){
	int ret;
	uint64_t max_file_size;
	char bdev_name[BDEVNAME_SIZE];

	bdevname(bdev, bdev_name);

	if(open_method == 3){
		... 
	}else{
		if(!cache_size) dev->sd_cache_size = dattobd_cow_max_memory_default;
		else dev->sd_cache_size = cache_size;

		if(open_method == 0){
			//calculate how much space should be allocated to the cow file
			if(!fallocated_space){
				max_file_size = size * SECTOR_SIZE * dattobd_cow_fallocate_percentage_default;
				do_div(max_file_size, 100);
				dev->sd_falloc_size = max_file_size;
				do_div(dev->sd_falloc_size, (1024 * 1024));
			}else{
				max_file_size = fallocated_space * (1024 * 1024);
				dev->sd_falloc_size = fallocated_space;
			}

			//create and open the cow manager
			LOG_DEBUG("creating cow manager");
			ret = cow_init(cow_path, SECTOR_TO_BLOCK(size), COW_SECTION_SIZE, dev->sd_cache_size, max_file_size, uuid, seqid, &dev->sd_cow);
			if(ret) goto error;
		}else{
			... 
		}
	}

	//verify that file is on block device
	if(!file_is_on_bdev(dev->sd_cow->filp, bdev)){
		ret = -EINVAL;
		LOG_ERROR(ret, "'%s' is not on '%s'", cow_path, bdev_name);
		goto error;
	}

	//find the cow file's inode number
	LOG_DEBUG("finding cow file inode");
	dev->sd_cow_inode = dattobd_get_dentry(dev->sd_cow->filp)->d_inode;

	return 0;

error:
	LOG_ERROR(ret, "error setting up cow manager");
	if(open_method != 3) __tracer_destroy_cow_free(dev);
	return ret;
}
```
主要作用为设置 `snap_device` 的 `cache_size`(缓存容量)、`sd_falloc_size`(分配空间) 和 `sd_cow_inode`(cow 文件 inode 信息)。

*3. setup the cow path* 设置 `snap_device` 的 `sd_cow_path`(cow 文件的绝对路径)
```C
static int __tracer_setup_cow_path(struct snap_device *dev, const struct file *cow_file){
	int ret;

	//get the pathname of the cow file (relative to the mountpoint)
	LOG_DEBUG("getting relative pathname of cow file");
	ret = dentry_get_relative_pathname(dattobd_get_dentry(cow_file), &dev->sd_cow_path, NULL);
	if(ret) goto error;

	return 0;

error:
	LOG_ERROR(ret, "error setting up cow file path");
	__tracer_destroy_cow_path(dev);
	return ret;
}
```

*4. setup the snapshot values*
```C
static int __tracer_setup_snap(struct snap_device *dev, unsigned int minor, struct block_device *bdev, sector_t size){
	int ret;

	// 初始化 dev bio set 
	ret = __tracer_bioset_init(dev);
	if(ret){
		LOG_ERROR(ret, "error initializing bio set");
		goto error;
	}

	//allocate request queue
	LOG_DEBUG("allocating queue");
	// 分配 dev->sd_queue 内存，GFP_KERNEL 表示无内存可用时可引起休眠
	dev->sd_queue = blk_alloc_queue(GFP_KERNEL);
	if(!dev->sd_queue){
		ret = -ENOMEM;
		LOG_ERROR(ret, "error allocating request queue");
		goto error;
	}

	//register request handler
	LOG_DEBUG("setting up make request function");
	// 设置 dev->sd_queue 的 make_request_fn 为 snap_mrf
	blk_queue_make_request(dev->sd_queue, snap_mrf);

	//give our request queue the same properties as the base device's
	LOG_DEBUG("setting queue limits");
	blk_set_stacking_limits(&dev->sd_queue->limits);
	dattobd_bdev_stack_limits(dev->sd_queue, bdev, 0);

#ifdef HAVE_MERGE_BVEC_FN
	//use a thin wrapper around the base device's merge_bvec_fn
	if(bdev_get_queue(bdev)->merge_bvec_fn) blk_queue_merge_bvec(dev->sd_queue, snap_merge_bvec);
#endif

	//allocate a gendisk struct
	LOG_DEBUG("allocating gendisk");
	// 分配一个 gendisk 结构，1 表示该设备不能被分区
	dev->sd_gd = alloc_disk(1);
	if(!dev->sd_gd){
		ret = -ENOMEM;
		LOG_ERROR(ret, "error allocating gendisk");
		goto error;
	}

	//initialize gendisk and request queue values
	LOG_DEBUG("initializing gendisk");
	// dev->sd_queue 的属主为 dev
	dev->sd_queue->queuedata = dev;
	dev->sd_gd->private_data = dev;
	dev->sd_gd->major = major;
	dev->sd_gd->first_minor = minor;
	dev->sd_gd->fops = &snap_ops;
	dev->sd_gd->queue = dev->sd_queue;

	//name our gendisk
	LOG_DEBUG("naming gendisk");
	// 设置 dev gendisk 设备名称
	snprintf(dev->sd_gd->disk_name, 32, SNAP_DEVICE_NAME, minor);

	//set the capacity of our gendisk
	LOG_DEBUG("block device size: %llu", (unsigned long long)size);
	// 设置设备容量
	set_capacity(dev->sd_gd, size);

#ifdef HAVE_GENHD_FL_NO_PART_SCAN
//#if LINUX_VERSION_CODE >= KERNEL_VERSION(3,2,0)
	//disable partition scanning (the device should not have any sub-partitions)
	dev->sd_gd->flags |= GENHD_FL_NO_PART_SCAN;
#endif

	//set the device as read-only
	// gendisk 只读
	set_disk_ro(dev->sd_gd, 1);

	//register gendisk with the kernel
	LOG_DEBUG("adding disk");
	// 注册到 /dev 目录下
	add_disk(dev->sd_gd);

	LOG_DEBUG("starting mrf kernel thread");

	// 启动 make_request_fn 线程
	dev->sd_mrf_thread = kthread_run(snap_mrf_thread, dev, SNAP_MRF_THREAD_NAME_FMT, minor);
	if(IS_ERR(dev->sd_mrf_thread)){ 
		ret = PTR_ERR(dev->sd_mrf_thread);
		dev->sd_mrf_thread = NULL;
		LOG_ERROR(ret, "error starting mrf kernel thread");
		goto error;
	}

	atomic64_set(&dev->sd_submitted_cnt, 0);
	atomic64_set(&dev->sd_received_cnt, 0);

	return 0;

error:
	LOG_ERROR(ret, "error setting up snapshot");
	__tracer_destroy_snap(dev);
	return ret;
}
```
主要功能是设置 `dev->sd_queue` 请求队列和队列的 `make_request_fn`，新增 `gendisk` 结构体指向块文件并注册到 /dev 下，启动 `make_request_fn` 为内核线程。

*5. setup the cow thread and run it* 
```C
static int __tracer_setup_cow_thread(struct snap_device *dev, unsigned int minor, int is_snap){
	int ret;

	LOG_DEBUG("creating kernel cow thread");
	if(is_snap) dev->sd_cow_thread = kthread_create(snap_cow_thread, dev, SNAP_COW_THREAD_NAME_FMT, minor);
	...

	if(IS_ERR(dev->sd_cow_thread)){
		ret = PTR_ERR(dev->sd_cow_thread);
		dev->sd_cow_thread = NULL;
		LOG_ERROR(ret, "error creating kernel thread");
		goto error;
	}

	return 0;

error:
	LOG_ERROR(ret, "error setting up cow thread");
	__tracer_destroy_cow_thread(dev);
	return ret;
}

...
// 后台执行 sd_cow_thread
wake_up_process(dev->sd_cow_thread);
```
后台执行 `snap_cow_thread` 函数，主要是处理 `bio`。

*6. inject the tracing function* 
```C
static int __tracer_setup_tracing(struct snap_device *dev, unsigned int minor){
	int ret;

	dev->sd_minor = minor;
	minor_range_include(minor);

	//get the base block device's make_request_fn
	LOG_DEBUG("getting the base block device's make_request_fn");
	ret = find_orig_mrf(dev->sd_base_dev, &dev->sd_orig_mrf);
	if(ret) goto error;

	ret = __tracer_transition_tracing(dev, dev->sd_base_dev, tracing_mrf, &snap_devices[minor]);
	if(ret) goto error;

	return 0;

error:
	LOG_ERROR(ret, "error setting up tracing");
	dev->sd_minor = 0;
	dev->sd_orig_mrf = NULL;
	minor_range_recalculate();
	return ret;
}
```
将原来块文件的 `make_request_fn` 替换成 tracing_mrf。

```C
static MRF_RETURN_TYPE tracing_mrf(struct request_queue *q, struct bio *bio){
	int i, ret = 0;
	struct snap_device *dev;
	make_request_fn *orig_mrf = NULL;

	MAYBE_UNUSED(ret);

	smp_rmb();
	tracer_for_each(dev, i){
		if(!dev || test_bit(UNVERIFIED, &dev->sd_state) || !tracer_queue_matches_bio(dev, bio)) continue;

		orig_mrf = dev->sd_orig_mrf;
		if(dattobd_bio_op_flagged(bio, DATTOBD_PASSTHROUGH)){
			dattobd_bio_op_clear_flag(bio, DATTOBD_PASSTHROUGH);
			goto call_orig;
		}

		if(tracer_should_trace_bio(dev, bio)){
			if(test_bit(SNAPSHOT, &dev->sd_state)) {
                ret = snap_trace_bio(dev, bio);
            } else {
                ret = inc_trace_bio(dev, bio);
            }
			goto out;
		}
	}

call_orig:
	if(orig_mrf) ret = dattobd_call_mrf(orig_mrf, q, bio);
	else LOG_ERROR(-EFAULT, "error finding original_mrf");

out:
	MRF_RETURN(ret);
}
```

执行完这个命令后，系统后台会新增两个 datto 相关的进程:
```bash
ps aux|grep datto
root       6821  0.0  0.0      0     0 ?        S<   09:16   0:00 [datto_snap_mrf0]
root       6823  0.0  0.0      0     0 ?        S<   09:16   0:00 [datto_snap_cow0]
```