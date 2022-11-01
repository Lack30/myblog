---
title: "K8s结合kubevirt管理虚拟机"
date: 2022-06-06T12:19:12+08:00
lastmod: 2022-06-06T12:19:12+08:00
draft: false
keywords: []
description: ""
tags: ["k8s"]
categories: ["云原生"]
author: "Lack"
---

## 什么是 KubeVirt
KubeVirt 作为 Red Hat 公司的开源项目，它可以让用户以容器的方式来管理虚拟机。


Kubevirt 主要实现了下面几种资源，以实现对虚拟机的管理：
- VirtualMachineInstance（VMI） : 类似于 kubernetes Pod，是管理虚拟机的最小资源。一个 VirtualMachineInstance 对象即表示一台正在运行的虚拟机实例，包含一个虚拟机所需要的各种配置。
- VirtualMachine（VM）: 为群集内的 VirtualMachineInstance 提供管理功能，例如开机/关机/重启虚拟机，确保虚拟机实例的启动状态，与虚拟机实例是 1:1 的关系，类似与 spec.replica 为 1 的 StatefulSet。
- VirtualMachineInstanceReplicaSet : 类似 ReplicaSet，可以启动指定数量的 VirtualMachineInstance，并且保证指定数量的 VirtualMachineInstance 运行，可以配置 HPA。


KubeVirt 架构图

![](https://raw.githubusercontent.com/xingyys/myblog/main/posts/images/20220607102220.png)

- virt-api : 负责提供一些 KubeVirt 特有的 api，像是 console, vnc, startvm, stopvm 等，工具 virtctl 会直接和该组件通讯
- virt-controller : 管理和监控 VMI 对象及其关联的 Pod，对其状态进行更新。
- virt-handler : 以 DaemonSet 运行在每一个节点上，监听 VMI 的状态向上汇报，管理 VMI 的生命周期。
- virt-launcher : 以 Pod 方式运行，每个 VMI Object 都会对应一个 virt-launcher Pod，容器内有单独的 libvirtd，用于启动和管理虚拟机。


## 准备

### 系统环境
首先需要安装有一套可用的 k8s 环境，本地的环境如下：

| 主机名     | 系统    | 配置                      | ip 地址      | 角色                         |
| ---------- | ------- | ------------------------- | ------------ | ---------------------------- |
| k8s-master | CentOS7 | 2 core 8G, 两块 100 硬盘  | 192.168.2.21 | master,glusterfs,heketi,helm |
| k8s-node1  | CentOS7 | 2 core 8G , 两块 100 硬盘 | 192.168.2.22 | node,gluster                 |
| k8s-node2  | CentOS7 | 2 core 8G , 两块 100 硬盘 | 192.168.2.23 | node,gluster                 |
| k8s-virt   | CentOS7 | 4 core 8G , 两块 100 硬盘 | 192.168.2.24 | node,gluster,kvm             |

### 修改主机
升级 k8s-virt 节点内核，可以参考[CentOS7 升级内核](https://www.cnblogs.com/ding2016/p/10429640.html)

升级完成后:
```bash
$ uname -r
5.18.2-1.el7.elrepo.x86_64
```
将 k8s-virt 加入 gluster 集群，可以参考[gluster 配置](http://xingyys.tech/k8s%E4%B8%8A%E6%90%AD%E5%BB%BAharbor%E7%A7%81%E6%9C%89%E5%BA%93/#gluster-%E9%85%8D%E7%BD%AE)

安装 containerd 和 kubelet，可以参考[部署 containerd](http://xingyys.tech/%E5%AE%89%E8%A3%85kubernetes1.23/#14-%E9%83%A8%E7%BD%B2-containerd)

k8s-virt 加入 k8s 集群，先获取 token，在 k8s-master 直接命令
```bash
$ kubeadm token create --print-join-command
kubeadm join 192.168.2.21:6443 --token ysrnjl.j78kztr0k1dwpwt6 --discovery-token-ca-cert-hash sha256:3496a635ca78755b032c077ff7bcf27b070868b78ff8058c412575f4127bccaa
```
在 k8s-virt 上执行命令
```bash
kubeadm join 192.168.2.21:6443 --token ysrnjl.j78kztr0k1dwpwt6 --discovery-token-ca-cert-hash sha256:3496a635ca78755b032c077ff7bcf27b070868b78ff8058c412575f4127bccaa
```

### 安装 KubeVirt

### 安装 libvirt 和 qemu
```bash
yum install -y qemu-kvm libvirt virt-install bridge-utils
```
查看节点是否支持 kvm 虚拟机化
```bash
$ virt-host-validate qemu
  QEMU: 正在检查 for hardware virtualization                                 : PASS
  QEMU: 正在检查 if device /dev/kvm exists                                   : PASS
  QEMU: 正在检查 if device /dev/kvm is accessible                            : PASS
  QEMU: 正在检查 if device /dev/vhost-net exists                             : PASS
  QEMU: 正在检查 if device /dev/net/tun exists                               : PASS
  QEMU: 正在检查 for cgroup 'memory' controller support                      : PASS
  QEMU: 正在检查 for cgroup 'memory' controller mount-point                  : PASS
  QEMU: 正在检查 for cgroup 'cpu' controller support                         : PASS
  QEMU: 正在检查 for cgroup 'cpu' controller mount-point                     : PASS
  QEMU: 正在检查 for cgroup 'cpuacct' controller support                     : PASS
  QEMU: 正在检查 for cgroup 'cpuacct' controller mount-point                 : PASS
  QEMU: 正在检查 for cgroup 'cpuset' controller support                      : PASS
  QEMU: 正在检查 for cgroup 'cpuset' controller mount-point                  : PASS
  QEMU: 正在检查 for cgroup 'devices' controller support                     : PASS
  QEMU: 正在检查 for cgroup 'devices' controller mount-point                 : PASS
  QEMU: 正在检查 for cgroup 'blkio' controller support                       : PASS
  QEMU: 正在检查 for cgroup 'blkio' controller mount-point                   : PASS
  QEMU: 正在检查 for device assignment IOMMU support                         : WARN (No ACPI DMAR table found, IOMMU either disabled in BIOS or not supported by this hardware platform)
```
如果不支持，则让 Kubevirt 使用软件虚拟化：
```bash
kubectl create namespace kubevirt
kubectl create configmap -n kubevirt kubevirt-config --from-literal debug.useEmulation=true
```

### 部署 KubeVirt

部署最新版本的 KubeVirt
```bash
export VERSION=$(curl -s https://api.github.com/repos/kubevirt/kubevirt/releases | grep tag_name | grep -v -- '-rc' | head -1 | awk -F': ' '{print $2}' | sed 's/,//' | xargs)
kubectl apply -f https://github.com/kubevirt/kubevirt/releases/download/${VERSION}/kubevirt-operator.yaml
kubectl apply -f https://github.com/kubevirt/kubevirt/releases/download/${VERSION}/kubevirt-cr.yaml
```

查看命令执行结果
```bash
$ kubectl get pods -n kubevirt
NAME                               READY   STATUS    RESTARTS      AGE
virt-api-59d4c5cb49-6b2r2          1/1     Running   1 (82m ago)   82m
virt-api-59d4c5cb49-d9w4z          1/1     Running   1 (82m ago)   82m
virt-controller-8684f9db98-d6w6p   1/1     Running   0             82m
virt-controller-8684f9db98-hrkjg   1/1     Running   0             82m
virt-handler-2hfxz                 1/1     Running   0             82m
virt-handler-4vk84                 1/1     Running   0             82m
virt-handler-qg4qt                 1/1     Running   0             82m
virt-handler-qnzsh                 1/1     Running   0             82m
virt-operator-5fcd4ff76f-47n27     1/1     Running   0             84m
virt-operator-5fcd4ff76f-kq4h8     1/1     Running   0             84m
```

### 部署 CDI
CDI (Containerized Data Importer) 可以使用 PVC 作为 KubeVirt VM 磁盘，建议同时安装：
```bash
export VERSION=$(curl -s https://github.com/kubevirt/containerized-data-importer/releases | grep -o "v[0-9]\.[0-9]*\.[0-9]*" | head -1)
kubectl create -f https://github.com/kubevirt/containerized-data-importer/releases/download/$VERSION/cdi-operator.yaml
kubectl create -f https://github.com/kubevirt/containerized-data-importer/releases/download/$VERSION/cdi-cr.yaml
```

### 安装 virtctl 工具
virtctl 工具可以直接用来操作虚拟机，执行以下命令下载
```bash
export VERSION=$(curl -s https://api.github.com/repos/kubevirt/kubevirt/releases | grep tag_name | grep -v -- '-rc' | head -1 | awk -F': ' '{print $2}' | sed 's/,//' | xargs)
curl -L -o /usr/local/bin/virtctl https://github.com/kubevirt/kubevirt/releases/download/$VERSION/virtctl-$VERSION-linux-amd64
chmod +x /usr/local/bin/virtctl
```

## 创建虚拟机

### 准备系统镜像
这里推荐一个 windows 系统镜像站 [https://msdn.itellyou.cn/](https://msdn.itellyou.cn/)，下载 windows 2012 R2

![](https://raw.githubusercontent.com/xingyys/myblog/main/posts/images/20220607111630.png)

下载 CentOS7 镜像，选择阿里云镜像站 [https://mirrors.aliyun.com/centos/7/isos/x86_64/](https://mirrors.aliyun.com/centos/7/isos/x86_64/)

![](https://raw.githubusercontent.com/xingyys/myblog/main/posts/images/20220607111807.png)

### 安装 CentOS7 虚拟机

KubeVirt 可以使用 PVC 作为后端磁盘，使用 filesystem 类型的 PVC 时，默认使用的时 /disk.img 这个镜像，用户可以将镜像上传到 PVC，
在创建 VMI 时使用此 PVC。使用这种方式需要注意下面几点：
- 一个 PVC 只允许存在一个镜像，只允许一个 VMI 使用，要创建多个 VMI，需要上传多次
- /disk.img 的格式必须是 RAW 格式

CDI 提供了使用使用 PVC 作为虚拟机磁盘的方案，在虚拟机启动前通过下面方式填充 PVC：
- 通过 URL 导入虚拟机镜像到 PVC，URL 可以是 http 链接，s3 链接
- Clone 一个已经存在的 PVC
- 通过 container registry 导入虚拟机磁盘到 PVC，需要结合 ContainerDisk 使用
- 通过客户端上传本地镜像到 PVC

通过命令行 `virtctl`，结合 CDI 项目，可以上传本地镜像到 PVC 上，支持的镜像格式有：
- .img
- .qcow2
- .iso
- 压缩为 .tar，.gz，.xz 格式的上述镜像

上传镜像文件 

```bash
$  export CDI_PROXY=`kubectl -n cdi get svc -l cdi.kubevirt.io=cdi-uploadproxy -o go-template --template='{{ (index .items 0).spec.clusterIP }}'`
$ virtctl image-upload --image-path='/root/iso/CentOS-7-x86_64-DVD-2009.iso' --pvc-name=iso-centos7  --pvc-size=5G --uploadproxy-url=https://$CDI_PROXY  --insecure  --wait-secs=240
PVC default/iso-centos7 not found
PersistentVolumeClaim default/iso-centos7 created
Waiting for PVC iso-centos7 upload pod to be ready...
Pod now ready
Uploading data to https://10.98.254.51

 4.39 GiB / 4.39 GiB [=============================================================================================================================================================] 100.00% 3m43s

Uploading data completed successfully, waiting for processing to complete, you can hit ctrl-c without interrupting the progress
Processing completed successfully
Uploading /root/iso/CentOS-7-x86_64-DVD-2009.iso completed successfully
```

参数说明：
- --image-path : 操作系统镜像路径。
- --pvc-name : 指定存储操作系统镜像的 PVC，这个 PVC 不需要提前准备好，镜像上传过程中会自动创建。
- --pvc-size : PVC 大小，根据操作系统镜像大小来设定，一般略大一个 G 就行。
- --uploadproxy-url : cdi-uploadproxy 的 Service IP，可以通过命令 `kubectl -n cdi get svc -l cdi.kubevirt.io=cdi-uploadproxy` 来查看。

KubeVirt 支持 HostDisk
```bash
$ kubectl edit kubevirt kubevirt -n kubevirt
    ...
    spec:
      configuration:
        developerConfiguration:
          featureGates:
            - DataVolumes
            - LiveMigration
            - HostDisk
    ...
```

CentOS7 虚拟机的模板文件

```bash
cat > kubevirt-centos7.yaml << EOF
apiVersion: kubevirt.io/v1alpha3
kind: VirtualMachine
metadata:
  name: centos7
spec:
  running: false
  template:
    metadata:
      labels:
        kubevirt.io/domain: centos7
    spec:
      domain:
        cpu:
          cores: 1
        devices:
          disks:
          - bootOrder: 1
            cdrom:
              bus: sata
            name: cdromiso
          - disk:
              bus: virtio
            name: harddrive
          - cdrom:
              bus: sata
            name: virtiocontainerdisk
          interfaces:
          - masquerade: {}
            model: e1000
            name: default
        machine:
          type: q35
        resources:
          requests:
            memory: 2G
      networks:
      - name: default
        pod: {}
      volumes:
      - name: cdromiso
        persistentVolumeClaim:
          claimName: iso-centos7
      - name: harddrive
        hostDisk:
          capacity: 30Gi
          path: /data/disk.img
          type: DiskOrCreate
      - containerDisk:
          image: kubevirt/virtio-container-disk
        name: virtiocontainerdisk
EOF
```

这里用到了 3 个 Volume：
- cdromiso : 提供操作系统安装镜像，即上文上传镜像后生成的 PVC iso-centos7。
- harddrive : 虚拟机使用的磁盘，即操作系统就会安装在该磁盘上。这里选择 hostDisk 直接挂载到宿主机以提升性能，如果使用分布式存储则体验非常不好。
- containerDisk : 由于 Windows 默认无法识别 raw 格式的磁盘，所以需要安装 virtio 驱动。 containerDisk 可以将打包好 virtio 驱动的容器镜像挂载到虚拟机中。

关于网络部分，spec.template.spec.networks 定义了一个网络叫 default，这里表示使用 Kubernetes 默认的 CNI。spec.template.spec.domain.devices.interfaces 选择定义的
网络 default，并开启 `masquerade`，以使用网络地址转换 (NAT) 来通过 Linux 网桥将虚拟机连接至 Pod 网络后端。

使用模板文件

```bash
kubectl apply -f kubevirt-centos7.yaml
```

启动虚拟机

```bash
virtctl start centos7
```

启动 vnc 代理

```bash
$ virtctl vnc centos7 --proxy-only --address=0.0.0.0
{"port":42743}
{"component":"","level":"info","msg":"connection timeout: 1m0s","pos":"vnc.go:153","timestamp":"2022-06-07T10:06:11.066704Z"}
{"component":"","level":"info","msg":"VNC Client connected in 7.866330333s","pos":"vnc.go:166","timestamp":"2022-06-07T10:06:18.933070Z"}
```

执行完上面的命令后，就会打开本地的 VNC 客户端连接到虚拟机

![](https://raw.githubusercontent.com/xingyys/myblog/main/posts/images/20220607100912.png)

直接下一步直到完成即可

安装完成重启后虚拟机依旧会从 cdrom 启动，修改 vm
```bash
virtctl stop centos7
kubectl edit virtualmachine.kubevirt.io/centos7
```
设硬盘为第一启动项
```bash
...
        devices:
          disks:
          - bootOrder: 2
            cdrom:
              bus: sata
            name: cdromiso
          - bootOrder: 1
            disk:
              bus: virtio
            name: harddrive
...
```
修改完成，重启虚拟机
```bash
virtctl start centos7
```
centos7 虚拟机启动正常

![](https://raw.githubusercontent.com/xingyys/myblog/main/posts/images/20220607104750.png)


### 安装 Windows2012 虚拟机

上传 windows2012 镜像
```bash
$ virtctl image-upload --image-path='/root/iso/cn_windows_server_2012_r2_x64_dvd_2707961.iso' --pvc-name=iso-win12  --pvc-size=5G --uploadproxy-url=https://$CDI_PROXY  --insecure  --wait-secs=240
PVC default/iso-win12 not found
PersistentVolumeClaim default/iso-win12 created
Waiting for PVC iso-win12 upload pod to be ready...
Pod now ready
Uploading data to https://10.98.254.51

 4.11 GiB / 4.11 GiB [=============================================================================================================================================================] 100.00% 3m54s

Uploading data completed successfully, waiting for processing to complete, you can hit ctrl-c without interrupting the progress
Processing completed successfully
Uploading /root/iso/cn_windows_server_2012_r2_x64_dvd_2707961.iso completed successfully
```

虚拟机配置文件 kubevirt-win12.yaml
```bash
cat > kubevirt-win12.yaml << EOF
apiVersion: kubevirt.io/v1
kind: VirtualMachine
metadata:
  name: win12
spec:
  running: false
  template:
    metadata:
      labels:
        kubevirt.io/domain: win12
        kubevirt.io/os: win2k12r2
    spec:
      domain:
        clock:
          timer:
            hpet:
              present: false
            hyperv: {}
            pit:
              tickPolicy: delay
            rtc:
              tickPolicy: catchup
          utc: {}
        cpu:
          cores: 2
        devices:
          disks:
          - bootOrder: 1
            cdrom:
              bus: sata
            name: cdromiso
          - disk:
              bus: virtio
            name: harddrive
          - cdrom:
              bus: sata
            name: virtiocontainerdisk
          interfaces:
          - masquerade: {}
            model: e1000
            name: default
        features:
          acpi: {}
          apic: {}
          hyperv:
            relaxed: {}
            spinlocks:
              spinlocks: 8191
            vapic: {}
          smm: {}
        firmware:
          bootloader:
            efi:
              secureBoot: true
        machine:
          type: q35
        resources:
          requests:
            memory: 2G
      networks:
      - name: default
        pod: {}
      volumes:
      - name: cdromiso
        persistentVolumeClaim:
          claimName: iso-win12
      - name: harddrive
        hostDisk:
          capacity: 30Gi
          path: /data/win12.img
          type: DiskOrCreate
      - containerDisk:
          image: kubevirt/virtio-container-disk
        name: virtiocontainerdisk
EOF
```
应用配置文件
```bash
kubectl apply -f kubevirt-win12.yaml
virtctl start win12
```

启动 vnc 代理

```bash
virtctl vnc win12 --address=0.0.0.0 --proxy-only
```

执行命令之后，使用 vnc 连接到虚拟机: 192.168.1.21:40710，打开就可以看到

![](https://raw.githubusercontent.com/xingyys/myblog/main/posts/images/20220607161015.png)

直接下一步，开始安装

![](https://raw.githubusercontent.com/xingyys/myblog/main/posts/images/20220607161326.png)

直接百度一个序列码，下一步

![](https://raw.githubusercontent.com/xingyys/myblog/main/posts/images/20220607161459.png)

![](https://raw.githubusercontent.com/xingyys/myblog/main/posts/images/20220607161610.png)

如果选择硬盘时没有一个可供使用，就需要安装 virtio 驱动

virtio 驱动挂载进来后，直接点击*浏览*:

![](https://raw.githubusercontent.com/xingyys/myblog/main/posts/images/20220607200905.png)

选择 viostor/2k12R2/amd64

![](https://raw.githubusercontent.com/xingyys/myblog/main/posts/images/20220607200950.png)

接着下一步

![](https://raw.githubusercontent.com/xingyys/myblog/main/posts/images/20220607161952.png)

继续安装

![](https://raw.githubusercontent.com/xingyys/myblog/main/posts/images/20220607201140.png)

安装成功后会自动重启进行初始化设置

如果你的 Kubernetes 集群 CNI 插件用的是 Calico，这里会遇到虚拟机无法联网的问题。因为 Calico 默认禁用了容器的 ip forward 功能，而 masquerade 需要开启这个功能才能生效。

我们只需要修改 Calico 的 ConfigMap 就可以启用容器的 ip forward 功能了，执行以下命令打开 configmap calico-config：

```bash
kubectl -n calico-system edit cm cni-config
```
修改配置文件
```bash
...
          "container_settings": {
              "allow_ip_forwarding": true
          },
...
```
安装完成

## 参考
- [https://www.cnblogs.com/ryanyangcs/p/14079144.html](https://www.cnblogs.com/ryanyangcs/p/14079144.html)
- [https://www.cnblogs.com/ding2016/p/10429640.html](https://www.cnblogs.com/ding2016/p/10429640.html)
- [https://kubevirt.io/user-guide/operations/activating_feature_gates/](https://kubevirt.io/user-guide/operations/activating_feature_gates/)