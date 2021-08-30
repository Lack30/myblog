---
title: "使用kubeadm安装kubernetes1.16"
date: 2019-10-19T15:10:16+08:00
lastmod: 2019-10-19T15:10:16+08:00
draft: false
keywords: []
description: ""
tags: ["k8s"]
categories: ["云计算"]
author: ""

# You can also close(false) or open(true) something for this content.
# P.S. comment can only be closed
comment: true
toc: true
autoCollapseToc: false
postMetaInFooter: false
hiddenFromHomePage: false
# You can also define another contentCopyright. e.g. contentCopyright: "This is another copyright."
contentCopyright: false
reward: false
mathjax: false
mathjaxEnableSingleDollar: false
mathjaxEnableAutoNumber: false

# You unlisted posts you might want not want the header or footer to show
hideHeaderAndFooter: false

# You can enable or disable out-of-date content warning for individual post.
# Comment this out to use the global config.
#enableOutdatedInfoWarning: false

flowchartDiagrams:
  enable: false
  options: ""

sequenceDiagrams: 
  enable: false
  options: ""

---

环境版本说明：
- 三台vmware虚拟机，系统版本CentOS7.6。
- Kubernetes 1.16.0，当前最新版。
- flannel v0.11
- docker 18.09

使用kubeadm可以简单的搭建一套k8s集群环境，而不用关注安装部署的细节，而且现在k8s的版本更新频率很快，所以这种方法十分推荐。

# 相关准备

> 注：本节相关操作要在所有节点上执行。

## 硬件环境
使用三台vmware虚拟机，配置网络，并保证可以联网。
- k8s-master 4G 4核 CentOS7 192.168.10.20
- k8s-node1 2G 2核 CentOS7 192.168.10.21
- k8s-node2 2G 2核 CentOS7 192.168.10.22

## 主机划分
- k8s-master作为集群管理节点：etcd kubeadm kube-apiserver kube-scheduler kube-controller-manager kubelet flanneld docker
- k8s-node1作为工作节点：kubeadm kubelet flanneld docker
- k8s-node2作为工作节点：kubeadm kubelet flanneld docker

## 准备工作
安装必要的rpm软件：
```bash
 yum install -y wget vim net-tools epel-release
```
关闭防火墙
```bash
systemctl disable firewalld
systemctl stop firewalld
```
关闭selinux
```bash
# 临时禁用selinux
setenforce 0
# 永久关闭 修改/etc/sysconfig/selinux文件设置
sed -i 's/SELINUX=permissive/SELINUX=disabled/' /etc/sysconfig/selinux
sed -i "s/SELINUX=enforcing/SELINUX=disabled/g" /etc/selinux/config
```
禁用交换分区
```bash
swapoff -a

# 永久禁用，打开/etc/fstab注释掉swap那一行。
sed -i 's/.*swap.*/#&/' /etc/fstab
```
修改 /etc/hosts
```bash
cat <<EOF >> /etc/host

192.168.10.20 k8s-master
192.168.10.21 k8s-node1
192.168.10.22 k8s-node2
EOF
```

修改内核参数
```bash
cat <<EOF >  /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
sysctl --system
```

# 安装docker18.09
## 配置yum源
```bash
## 配置默认源
## 备份
mv /etc/yum.repos.d/CentOS-Base.repo /etc/yum.repos.d/CentOS-Base.repo.backup

## 下载阿里源
wget -O /etc/yum.repos.d/CentOS-Base.repo http://mirrors.aliyun.com/repo/Centos-7.repo

## 刷新
yum makecache fast

## 配置k8s源
cat <<EOF > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://mirrors.aliyun.com/kubernetes/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=0
EOF

## 重建yum缓存
yum clean all
yum makecache fast
yum -y update
```

## 安装docker
下载docker的yum源文件
```bash
yum -y install yum-utils device-mapper-persistent-data lvm2
yum-config-manager --add-repo http://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo
```
这里指定docker版本，可以先查看支持的版本
```bash
[root@localhost ~]# yum list docker-ce --showduplicates |sort -r               
 * updates: mirrors.aliyun.com
Loading mirror speeds from cached hostfile
Loaded plugins: fastestmirror
 * extras: mirrors.aliyun.com
 * epel: hkg.mirror.rackspace.com
docker-ce.x86_64            3:19.03.2-3.el7                     docker-ce-stable
docker-ce.x86_64            3:19.03.1-3.el7                     docker-ce-stable
docker-ce.x86_64            3:19.03.0-3.el7                     docker-ce-stable
docker-ce.x86_64            3:18.09.9-3.el7                     docker-ce-stable
...
 * base: mirrors.aliyun.com
```
目前最新版本为19.03，指定下载18.09
```bash
yum install -y docker-ce-18.09.9-3.el7
systemctl enable docker
systemctl start docker
```
## 修改docker的启动参数
```bash
cat > /etc/docker/daemon.json <<EOF
{
  "registry-mirrors": ["https://xxxx.mirror.aliyuncs.com"],
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2",
  "storage-opts": [
    "overlay2.override_kernel_check=true"
  ]
}
EOF

systemctl restart docker
```

# 安装k8s

## 管理节点配置
先在k8s-master上安装管理节点

### 下载kubeadm，kubelet
```bash
yum install -y kubeadm kubelet
```

### 初始化kubeadm
这里不直接初始化，因为国内用户不能直接拉取相关的镜像，所以这里想查看需要的镜像版本
```bash
[root@k8s-master ~]# kubeadm config images list
k8s.gcr.io/kube-apiserver:v1.16.0
k8s.gcr.io/kube-controller-manager:v1.16.0
k8s.gcr.io/kube-scheduler:v1.16.0
k8s.gcr.io/kube-proxy:v1.16.0
k8s.gcr.io/pause:3.1
k8s.gcr.io/etcd:3.3.15-0
k8s.gcr.io/coredns:1.6.2
```
根据需要的版本，直接拉取国内镜像，并修改tag
```bash
# vim kubeadm.sh

#!/bin/bash

## 使用如下脚本下载国内镜像，并修改tag为google的tag
set -e

KUBE_VERSION=v1.16.0
KUBE_PAUSE_VERSION=3.1
ETCD_VERSION=3.3.15-0
CORE_DNS_VERSION=1.6.2

GCR_URL=k8s.gcr.io
ALIYUN_URL=registry.cn-hangzhou.aliyuncs.com/google_containers

images=(kube-proxy:${KUBE_VERSION}
kube-scheduler:${KUBE_VERSION}
kube-controller-manager:${KUBE_VERSION}
kube-apiserver:${KUBE_VERSION}
pause:${KUBE_PAUSE_VERSION}
etcd:${ETCD_VERSION}
coredns:${CORE_DNS_VERSION})

for imageName in ${images[@]} ; do
  docker pull $ALIYUN_URL/$imageName
  docker tag  $ALIYUN_URL/$imageName $GCR_URL/$imageName
  docker rmi $ALIYUN_URL/$imageName
done
```
运行脚本，拉取镜像
```bash
sh ./kubeadm.sh
```
master节点执行
```bash
sudo kubeadm init \
 --apiserver-advertise-address 192.168.10.20 \
 --kubernetes-version=v1.16.0 \
 --pod-network-cidr=10.244.0.0/16
```
> 注：这里的pod-network-cidr，最好不要改动，和以下的步骤是关联的。

结果返回
```bash
...
...

mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
...

## 添加节点需要执行以下命令，可以使用命令 kubeadm token create --print-join-command 来获取 
 
kubeadm join 192.168.10.20:6443 --token lixsl8.v1auqmf91ty0xl0k \
    --discovery-token-ca-cert-hash sha256:c3f92a6ed9149ead327342f48a545e7e127a455d5b338129feac85893d918a55 
```

如果是要安装多个master节点，则初始化命令使用
```bash
kubeadm init  --apiserver-advertise-address 192.168.10.20 --control-plane-endpoint 192.168.10.20  --kubernetes-version=v1.16.0  --pod-network-cidr=10.244.0.0/16  --upload-certs
```
添加master节点使用命令:
```bash
kubeadm join 192.168.10.20:6443 --token z34zii.ur84appk8h9r3yik --discovery-token-ca-cert-hash sha256:dae426820f2c6073763a3697abeb14d8418c9268288e37b8fc25674153702801     --control-plane --certificate-key 1b9b0f1fdc0959a9decef7d812a2f606faf69ca44ca24d2e557b3ea81f415afe
```
> 注：这里的token会不同，不要直接复制。kubeadm init成功后会输出添加master节点的命令

## 工作节点配置
### 下载kubeadm kubelet
三台节点都要运行
```bash
yum install -y kubeadm kubelet
```
### 添加节点
三台节点都要运行，这里先忽略错误
```bash
kubeadm join 192.168.10.20:6443 --token lixsl8.v1auqmf91ty0xl0k \
    --discovery-token-ca-cert-hash sha256:c3f92a6ed9149ead327342f48a545e7e127a455d5b338129feac85893d918a55 \
   --ignore-preflight-errors=all 
```
如果添加节点失败，或是想重新添加，可以使用命令
```bash
kubeadm reset
```
> 注：不要在轻易master上使用，它会删除所有kubeadm配置
这时在节点上就可以使用命令查看添加的节点信息了
```bash
[root@k8s-master ~]# kubectl get nodes
NAME         STATUS     ROLES    AGE   VERSION
k8s-master   NotReady   master   45m   v1.16.0
k8s-node1    NotReady   <none>   26s   v1.16.0
k8s-node2    NotReady   <none>   12s   v1.16.0
```
但节点的状态就是 `NotReady`，还需要一些操作

### 安装flanneld
在master上操作，拷贝配置，令kubectl可用
```bash
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```
下载flannel配置文件
```bash
wget https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml
```
因为kube-flannel.yml文件中使用的镜像为quay.io的，国内无法拉取，所以同样的先从国内源上下载，再修改tag，脚本如下
```bash
# vim flanneld.sh

#!/bin/bash

set -e

FLANNEL_VERSION=v0.11.0

# 在这里修改源
QUAY_URL=quay.io/coreos
QINIU_URL=quay-mirror.qiniu.com/coreos

images=(flannel:${FLANNEL_VERSION}-amd64
flannel:${FLANNEL_VERSION}-arm64
flannel:${FLANNEL_VERSION}-arm
flannel:${FLANNEL_VERSION}-ppc64le
flannel:${FLANNEL_VERSION}-s390x)

for imageName in ${images[@]} ; do
  docker pull $QINIU_URL/$imageName
  docker tag  $QINIU_URL/$imageName $QUAY_URL/$imageName
  docker rmi $QINIU_URL/$imageName
done
```
运行脚本，这个脚本需要在每个节点上执行
```bash
sh flanneld.sh
```
安装flanneld
```bash
kubectl apply -f kube-flanneld.yaml
```
flanneld默认安装在kube-system Namespace中，使用以下命令查看:
```bash
# kubectl -n kube-system get pods
NAME                                 READY   STATUS         RESTARTS   AGE
coredns-5644d7b6d9-h9bxt             0/1     Pending        0          57m
coredns-5644d7b6d9-pkhls             0/1     Pending        0          57m
etcd-k8s-master                      1/1     Running        0          57m
kube-apiserver-k8s-master            1/1     Running        0          57m
kube-controller-manager-k8s-master   1/1     Running        0          57m
kube-flannel-ds-amd64-c4hnf          1/1     Running        1          38s
kube-flannel-ds-amd64-djzmx          1/1     Running        0          38s
kube-flannel-ds-amd64-mdg8b          1/1     Running        1          38s
kube-flannel-ds-amd64-tjxql          0/1     Terminating    0          5m34s
kube-proxy-4n5dr                     0/1     ErrImagePull   0          13m
kube-proxy-dc68d                     1/1     Running        0          57m
kube-proxy-zplgt                     0/1     ErrImagePull   0          13m
kube-scheduler-k8s-master            1/1     Running        0          57m
```
出现错误，原因是两个工作节点不能拉取pause和kube-proxy镜像，可以直接从master上打包，在node上使用
```bash
## master上执行
docker save -o pause.tar k8s.gcr.io/pause:3.1
docker save -o kube-proxy.tar k8s.gcr.io/kube-proxy

## node上执行
docker load -i pause.tar 
docker load -i kube-proxy.tar 
```
重新安装flanneld
```bash
 kubectl delete -f kube-flannel.yml 
 kubectl create -f kube-flannel.yml 
```
### 修改kubelet
使用kubeadm添加node后，节点一直处于`NotReady`状态，报错信息为：
```bash
runtime network not ready: NetworkReady=false reason:NetworkPluginNotReady message:docker: network plugin is not ready: cni config uninitialized Addresses:
```
解决方式是修改/var/lib/kubelet/kubeadm-flags.env文件，删除参数 `--network-plugin=cni`
```bash
cat << EOF > /var/lib/kubelet/kubeadm-flags.env
KUBELET_KUBEADM_ARGS="--cgroup-driver=systemd --pod-infra-container-image=k8s.gcr.io/pause:3.1"
EOF

systemctl restart kubelet
```
```bash
[root@k8s-master ~]# kubectl get nodes
NAME         STATUS   ROLES    AGE   VERSION
k8s-master   Ready    master   79m   v1.16.0
k8s-node1    Ready    <none>   34m   v1.16.0
k8s-node2    Ready    <none>   34m   v1.16.0
```
# 错误解决
关于错误`cni config uninitialized Addresses`，这里之前是直接删除参数`--network-plugin=cni`，但这样只能让节点状态修改为 ready，但是在Pod之间网络依然不可用。

*正确的解决方法*：修改kube-flannel.yaml，在111行添加参数`cniVersion`：
```bash
vim kube-flanneld.yaml

{
      "name": "cbr0",
      "cniVersion": "0.3.1",
      ....
```
安装flannel
```bash
## 如果之前安装了，先删除
## kubectl delete -f kube-flannel.yaml

kubectl apply -f kube-flannel.yaml
```
