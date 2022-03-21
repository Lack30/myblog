# 安装kubernetes1.23


本文介绍如何通过 Kubeadm 工具安装 Kubernetes 1.23。

## 一、准备

### 1.1 系统环境
准备三台vmware虚拟机，配置为 CentOS7.6 / 2Core / 2G，系统环境如下:
```bash
172.16.219.100 k8s-master
172.16.219.101 k8s-slave1
172.16.219.102 k8s-slave2
```

### 1.2 配置防火墙
关闭Linux的防火墙
```bash
systemctl stop firewalld
systemctl disable firewalld
```
关闭 selinux
```bash
setenforce 0
```

```bash
vim /etc/selinux/config
SELINUX=disabled
```
### 1.3 关闭 swap 分区
Kubernetes 1.8开始要求关闭系统的Swap，如果不关闭，默认配置下kubelet将无法启动。 关闭系统的Swap方法如下:
```bash
swapoff -a
```
同时修改 `/etc/fstab`:
```bash
#UUID=7f0f3bd8-3605-4ad7-81b0-1a91c735969f swap                    swap    defaults        0 0
```
### 1.4 部署 containerd
kubernetes 1.22 版本之后，默认的容器运行时变成 containerd。所以在安装 k8s 之前先安装 containerd。

配置 overlay
```bash
cat << EOF > /etc/modules-load.d/containerd.conf
overlay
br_netfilter
EOF
```
加载内核配置
```bash
modprobe overlay
modprobe br_netfilter
```

修改网络相关的内核参数
```bash
cat << EOF > /etc/sysctl.d/99-kubernetes-cri.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
user.max_user_namespaces=28633
vm.swappiness=0
EOF
```
加载配置
```bash
sysctl -p /etc/sysctl.d/99-kubernetes-cri.conf
```
现在 kube-proxy 可以使用 ipvs 来代替原来的 iptables。配置 ipvs:
```bash
cat > /etc/sysconfig/modules/ipvs.modules <<EOF
#!/bin/bash
modprobe -- ip_vs
modprobe -- ip_vs_rr
modprobe -- ip_vs_wrr
modprobe -- ip_vs_sh
modprobe -- nf_conntrack_ipv4
EOF

chmod 755 /etc/sysconfig/modules/ipvs.modules 
bash /etc/sysconfig/modules/ipvs.modules 
```
安装 ipvs 工具，方便管理 ipvs 规则
```bash
yum install -y ipset ipvsadm
```

安装部署 containerd，在各个节点上安装 containerd
```bash
wget https://github.com/containerd/containerd/releases/download/v1.5.8/cri-containerd-cni-1.5.8-linux-amd64.tar.gz
```
直接解压到 `/` 目录下，
```bash
tar -zxvf cri-containerd-cni-1.5.8-linux-amd64.tar.gz -C /
```
由于 `cri-containerd-cni-1.5.8-linux-amd64.tar.gz` 包内部的 runc 包在 CentOS7 下的动态链接有问题，所以需要下载二进制文件替换它。
```bash
wget https://github.com/opencontainers/runc/releases/download/v1.1.0-rc.1/runc.amd64
mv runc.amd64 /usr/local/sbin/runc
``` 
生成 containerd 的配置文件并修改
```bash
mkdir -p /etc/containerd
containerd config default > /etc/containerd/config.toml
```
根据文档Container runtimes 中的内容，对于使用systemd作为init system的Linux的发行版，使用systemd作为容器的cgroup driver可以确保服务器节点在资源紧张的情况更加稳定，因此这里配置各个节点上containerd的cgroup driver为systemd。

修改前面生成的配置文件 `/etc/containerd/config.toml`：
```bash
[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc]
  ...
  [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
    SystemdCgroup = true
```
由于 k8s.grc.io 被墙，替换成国内源。再修改 `/etc/containerd/config.toml`
```bash
[plugins."io.containerd.grpc.v1.cri"]
  ...
  # sandbox_image = "k8s.gcr.io/pause:3.5"
  sandbox_image = "registry.aliyuncs.com/google_containers/pause:3.6"
```
配置 containerd 开机自启
```bash
systemctl enable containerd
systemctl start containerd
```
执行 crictl 命令测试
```bash
 crictl version
Version:  0.1.0
RuntimeName:  containerd
RuntimeVersion:  v1.5.8
RuntimeApiVersion:  v1alpha2
```

## 二、部署 Kubernetes

### 2.1 安装 kubeadm
环境都准备完成后，开始证实安装 k8s。在每个节点上安装 kubeadm 和 kubelet，先配置 yum 源
```bash
cat <<EOF > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=http://mirrors.aliyun.com/kubernetes/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=0
repo_gpgcheck=0
gpgkey=http://mirrors.aliyun.com/kubernetes/yum/doc/yum-key.gpg
        http://mirrors.aliyun.com/kubernetes/yum/doc/rpm-package-key.gpg
EOF
```
更新缓存
```bash
yum makecache fast
yum install -y kubelet kubeadm kubectl
```
开机启动 kubelet 服务
```bash
systemctl enable kubelet
```
### 2.2 初始化集群
使用 `kubeadm config print init-defaults --component-configs KubeletConfiguration` 可以打印集群初始化默认的使用的配置：
```bash
apiVersion: kubeadm.k8s.io/v1beta3
bootstrapTokens:
- groups:
  - system:bootstrappers:kubeadm:default-node-token
  token: abcdef.0123456789abcdef
  ttl: 24h0m0s
  usages:
  - signing
  - authentication
kind: InitConfiguration
localAPIEndpoint:
  advertiseAddress: 1.2.3.4
  bindPort: 6443
nodeRegistration:
  criSocket: /var/run/dockershim.sock
  imagePullPolicy: IfNotPresent
  name: node
  taints: null
---
apiServer:
  timeoutForControlPlane: 4m0s
apiVersion: kubeadm.k8s.io/v1beta3
certificatesDir: /etc/kubernetes/pki
clusterName: kubernetes
controllerManager: {}
dns: {}
etcd:
  local:
    dataDir: /var/lib/etcd
imageRepository: k8s.gcr.io
kind: ClusterConfiguration
kubernetesVersion: 1.23.0
networking:
  dnsDomain: cluster.local
  serviceSubnet: 10.96.0.0/12
scheduler: {}
---
apiVersion: kubelet.config.k8s.io/v1beta1
authentication:
  anonymous:
    enabled: false
  webhook:
    cacheTTL: 0s
    enabled: true
  x509:
    clientCAFile: /etc/kubernetes/pki/ca.crt
authorization:
  mode: Webhook
  webhook:
    cacheAuthorizedTTL: 0s
    cacheUnauthorizedTTL: 0s
cgroupDriver: systemd
clusterDNS:
- 10.96.0.10
clusterDomain: cluster.local
cpuManagerReconcilePeriod: 0s
evictionPressureTransitionPeriod: 0s
fileCheckFrequency: 0s
healthzBindAddress: 127.0.0.1
healthzPort: 10248
httpCheckFrequency: 0s
imageMinimumGCAge: 0s
kind: KubeletConfiguration
logging:
  flushFrequency: 0
  options:
    json:
      infoBufferSize: "0"
  verbosity: 0
memorySwap: {}
nodeStatusReportFrequency: 0s
nodeStatusUpdateFrequency: 0s
rotateCertificates: true
runtimeRequestTimeout: 0s
shutdownGracePeriod: 0s
shutdownGracePeriodCriticalPods: 0s
staticPodPath: /etc/kubernetes/manifests
streamingConnectionIdleTimeout: 0s
syncFrequency: 0s
volumeStatsAggPeriod: 0s
```
从默认的配置中可以看到，可以使用`imageRepository`定制在集群初始化时拉取k8s所需镜像的地址。基于默认配置定制出本次使用kubeadm初始化集群所需的配置文件`kubeadm.yaml`：
```bash
apiVersion: kubeadm.k8s.io/v1beta3
kind: InitConfiguration
localAPIEndpoint:
  advertiseAddress: 172.16.219.100
  bindPort: 6443
nodeRegistration:
  criSocket: /run/containerd/containerd.sock
  taints:
  - effect: PreferNoSchedule
    key: node-role.kubernetes.io/master
---
apiVersion: kubeadm.k8s.io/v1beta2
kind: ClusterConfiguration
kubernetesVersion: v1.23.1
imageRepository: registry.aliyuncs.com/google_containers
networking:
  podSubnet: 10.244.0.0/16
---
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration
cgroupDriver: systemd
failSwapOn: false
---
apiVersion: kubeproxy.config.k8s.io/v1alpha1
kind: KubeProxyConfiguration
mode: ipvs
```
这里定制了`imageRepository`为阿里云的registry，避免因gcr被墙，无法直接拉取镜像。`criSocket` 设置了容器运行时为containerd。 同时设置kubelet的`cgroupDriver`为systemd，设置kube-proxy代理模式为ipvs。

在开始初始化集群之前可以使用`kubeadm config images pull --config kubeadm.yaml`预先在各个服务器节点上拉取所k8s需要的容器镜像。
```bash
kubeadm config images pull --config kubeadm.yaml
```
接下来使用kubeadm初始化集群，选择node1作为Master Node，在node1上执行下面的命令：
```bash
kubeadm init --config kubeadm.yaml
```
执行过程中会输出相关日志。其中有以下关键内容：
- `[certs]`生成相关的各种证书
- `[kubeconfig]`生成相关的kubeconfig文件
- `[kubelet-start]` 生成kubelet的配置文件"`/var/lib/kubelet/config.yaml`"
- `[control-plane]`使用/etc/kubernetes/manifests目录中的yaml文件创建apiserver、controller-manager、scheduler的静态pod
- `[bootstraptoken]`生成token记录下来，后边使用`kubeadm join`往集群中添加节点时会用到
- 下面的命令是配置常规用户如何使用kubectl访问集群：
```bash
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```
- 最后给出添加新的工作节点命令`kubeadm join 172.16.219.100:6443 --token rdm2to.z9n608f4ix4lnik8 --discovery-token-ca-cert-hash sha256:047a21a7d519b87e594d36a6fdbfadc86557cd602ee58bda8f7fc97f38cba4d9`

查看集群状态
```bash
kubectl get cs
Warning: v1 ComponentStatus is deprecated in v1.19+
NAME                 STATUS    MESSAGE                         ERROR
controller-manager   Healthy   ok
scheduler            Healthy   ok
etcd-0               Healthy   {"health":"true","reason":""}
```
> 注意：如果集群初始化中出现问题，可以使用 `kubeadm reset` 命令清除安装的内容，再重新安装。

### 2.3 安装 helm 包管理器
helm 是开源的 k8s 包管理工具，可以简化 k8s 服务的安装步骤。安装命令如下:
```bash
wget https://get.helm.sh/helm-v3.7.2-linux-amd64.tar.gz
tar -zxvf helm-v3.7.2-linux-amd64.tar.gz
mv linux-amd64/helm  /usr/local/bin/
```
使用命令 `helm list` 检查。

### 2.4 安装 Calico 
使用 Calico 作为 k8s 的 CNI。这里使用 helm 安装。
下载 `tigera-openrator` 的 helm chart：
```bash
wget https://github.com/projectcalico/calico/releases/download/v3.21.2/tigera-operator-v3.21.2-1.tgz
```
查看这个 chart 中可定制的配置:
```bash
helm show values tigera-operator-v3.21.2-1.tgz > calico.yaml
 
imagePullSecrets: {}

installation:
  enabled: true
  kubernetesProvider: ""

apiServer:
  enabled: true

certs:
  node:
    key:
    cert:
    commonName:
  typha:
    key:
    cert:
    commonName:
    caBundle:

# Configuration for the tigera operator
tigeraOperator:
  image: tigera/operator
  version: v1.23.3
  registry: quay.io
calicoctl:
  image: quay.io/docker.io/calico/ctl
  tag: v3.21.2
```
使用 helm 安装 calico
```bash
helm install calico tigera-operator-v3.21.2-1.tgz -f calico.yaml
```
等待所有 Pod 安装完成
```bash
kubectl get pods -n calico-system
NAME                                       READY   STATUS    RESTARTS   AGE
calico-kube-controllers-59c45ff85c-cvzg6   1/1     Running   0          9h
calico-node-lb7q8                          0/1     Running   0          9h
calico-typha-68c8b9b5ff-bdh6h              1/1     Running   0          9h
```
查看 calico 新增的相关资源
```bash
kubectl api-resources | grep calico
bgpconfigurations                              crd.projectcalico.org/v1               false        BGPConfiguration
bgppeers                                       crd.projectcalico.org/v1               false        BGPPeer
blockaffinities                                crd.projectcalico.org/v1               false        BlockAffinity
caliconodestatuses                             crd.projectcalico.org/v1               false        CalicoNodeStatus
clusterinformations                            crd.projectcalico.org/v1               false        ClusterInformation
felixconfigurations                            crd.projectcalico.org/v1               false        FelixConfiguration
globalnetworkpolicies                          crd.projectcalico.org/v1               false        GlobalNetworkPolicy
globalnetworksets                              crd.projectcalico.org/v1               false        GlobalNetworkSet
hostendpoints                                  crd.projectcalico.org/v1               false        HostEndpoint
ipamblocks                                     crd.projectcalico.org/v1               false        IPAMBlock
ipamconfigs                                    crd.projectcalico.org/v1               false        IPAMConfig
ipamhandles                                    crd.projectcalico.org/v1               false        IPAMHandle
ippools                                        crd.projectcalico.org/v1               false        IPPool
ipreservations                                 crd.projectcalico.org/v1               false        IPReservation
kubecontrollersconfigurations                  crd.projectcalico.org/v1               false        KubeControllersConfiguration
networkpolicies                                crd.projectcalico.org/v1               true         NetworkPolicy
networksets                                    crd.projectcalico.org/v1               true         NetworkSet
```
这些api资源是属于calico的，因此不建议使用kubectl来管理，推荐按照calicoctl来管理这些api资源。 将calicoctl安装为kubectl的插件:
```bash
cd /usr/local/bin
curl -o kubectl-calico -O -L  "https://github.com/projectcalico/calicoctl/releases/download/v3.21.2/calicoctl" 
chmod +x kubectl-calico
```
验证插件正常工作:
```bash
kubectl calico -h
```
检测 k8s CoreDns 服务
```bash
kubectl run curl --image=radial/busyboxplus:curl -it
If you don't see a command prompt, try pressing enter.
[ root@curl:/ ]$
```
通过命令 nslookup kubernetes.default 检测
```bash
nslookup kubernetes.default
Server:    10.96.0.10
Address 1: 10.96.0.10 kube-dns.kube-system.svc.cluster.local

Name:      kubernetes.default
Address 1: 10.96.0.1 kubernetes.default.svc.cluster.local
```

### 2.5 添加工作节点
将 k8s-slave1 和 k8s-slave2 节点添加到集群中。
```bash
kubeadm join 172.16.219.100:6443 --token rdm2to.z9n608f4ix4lnik8 --discovery-token-ca-cert-hash sha256:047a21a7d519b87e594d36a6fdbfadc86557cd602ee58bda8f7fc97f38cba4d9`
```
在 k8s-master 上测试结果：
```bash
kubectl get nodes
NAME         STATUS   ROLES                       AGE   VERSION
k8s-master   Ready    control-plane,edge,master   9h    v1.23.1
k8s-slave1   Ready    <none>                      9h    v1.23.1
k8s-slave2   Ready    <none>                      9h    v1.23.1
```

## 三、Kubernetes 常用组件

### 3.1 部署 ingress-nginx
k8s 提供 ingress，可以间集群的服务提供给外部进行访问。Nginx Ingress Controller被部署在Kubernetes的边缘节点上。

这里将node1(172.168.219.101)作为边缘节点，打上Label：
```bash
kubectl label node k8s-slave1 node-role.kubernetes.io/edge=
```
下载 ingress-nginx
```bash
wget https://github.com/kubernetes/ingress-nginx/releases/download/helm-chart-4.0.13/ingress-nginx-4.0.13.tgz
```
修改 chart 的配置：
```bash
controller:
  ingressClassResource:
    name: nginx
    enabled: true
    default: true
    controllerValue: "k8s.io/ingress-nginx"
  admissionWebhooks:
    enabled: false
  replicaCount: 1
  image:
    # registry: k8s.gcr.io
    # image: ingress-nginx/controller
    # tag: "v1.1.0"
    registry: docker.io
    image: unreachableg/k8s.gcr.io_ingress-nginx_controller
    tag: "v1.1.0"
    digest: sha256:4f5df867e9367f76acfc39a0f85487dc63526e27735fa82fc57d6a652bafbbf6
  hostNetwork: true
  nodeSelector:
    node-role.kubernetes.io/edge: ''
  affinity:
    podAntiAffinity:
        requiredDuringSchedulingIgnoredDuringExecution:
        - labelSelector:
            matchExpressions:
            - key: app
              operator: In
              values:
              - nginx-ingress
            - key: component
              operator: In
              values:
              - controller
          topologyKey: kubernetes.io/hostname
  tolerations:
      - key: node-role.kubernetes.io/master
        operator: Exists
        effect: NoSchedule
      - key: node-role.kubernetes.io/master
        operator: Exists
        effect: PreferNoSchedule
```
nginx ingress controller的副本数`replicaCount`为1，将被调度到node1这个边缘节点上。这里并没有指定nginx ingress controller service的`externalIPs`，而是通过`hostNetwork: true`设置nginx ingress controller使用宿主机网络。 因为k8s.gcr.io被墙，这里替换成`unreachableg/k8s.gcr.io_ingress-nginx_controller`提前拉取一下镜像:
```bash
crictl pull unreachableg/k8s.gcr.io_ingress-nginx_controller:v1.1.0
```
安装 ingress-nginx
```bash
helm install ingress-nginx ingress-nginx-4.0.13.tgz --create-namespace -n ingress-nginx -f values.yaml
```
通过访问 `http://172.16.219.101` 测试，返回 404 表示安装成功。

### 3.2 部署 metrics-server
下载描述文件
```bash
wget https://github.com/kubernetes-sigs/metrics-server/releases/download/v0.5.2/components.yaml
```
修改components.yaml中的image为`docker.io/unreachableg/k8s.gcr.io_metrics-server_metrics-server:v0.5.2`。 

修改components.yaml中容器的启动参数，加入`--kubelet-insecure-tls`。
```bash
kubectl apply -f components.yaml
```
metrics-server的pod正常启动后，等一段时间就可以使用kubectl top查看集群和pod的metrics信息:
```bash
kubectl top node --use-protocol-buffers=true
NAME         CPU(cores)   CPU%   MEMORY(bytes)   MEMORY%
k8s-master   287m         14%    1236Mi          71%
k8s-slave1   99m          4%     894Mi           51%
k8s-slave2   100m         5%     876Mi           50%

kubectl top pod -n kube-system --use-protocol-buffers=true
NAME                                    CPU(cores)   MEMORY(bytes)
coredns-6d8c4cb4d-klthf                 3m           17Mi
coredns-6d8c4cb4d-xmgnj                 3m           15Mi
etcd-k8s-master                         53m          60Mi
kube-apiserver-k8s-master               84m          391Mi
kube-controller-manager-k8s-master      31m          72Mi
kube-proxy-6fxdl                        14m          18Mi
kube-proxy-ggf2t                        12m          16Mi
kube-proxy-l5t9b                        13m          22Mi
kube-scheduler-k8s-master               5m           29Mi
kubernetes-dashboard-79f67c7494-pb6rq   1m           38Mi
metrics-server-74689dcfd-c9fqn          5m           33Mi
```

### 3.3 部署 dashboard
使用helm部署k8s的dashboard，添加chart repo:
```bash
helm repo add kubernetes-dashboard https://kubernetes.github.io/dashboard/
helm repo update
```
查看chart的可定制配置:
```bash
helm show values kubernetes-dashboard/kubernetes-dashboard
```
修改 chart 的定制配置
```bash
image:
  repository: kubernetesui/dashboard
  tag: v2.4.0
ingress:
  enabled: true
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/backend-protocol: "HTTPS"
  hosts:
  - k8s.example.com
  tls:
    - secretName: example-com-tls-secret
      hosts:
      - k8s.example.com
metricsScraper:
  enabled: true
```
生成个人证书：
```bash
mkdir -p /etc/k8s/ssl/
cd /etc/k8s/ssl
openssl genrsa -out dashboard.key 2048
openssl req -new -x509 -key dashboard.key -out dashboard.crt -subj "/O=dashboard/CN=k8s.example.com"
```
先创建存放k8s.example.comssl证书的secret:
```bash
kubectl create secret tls example-com-tls-secret --cert=/etc/k8s/ssl/dashboard.crt --key=/etc/k8s/ssl/dashboard.key -n kube-system
```
使用helm部署dashboard:
```bash
helm install kubernetes-dashboard kubernetes-dashboard/kubernetes-dashboard -n kube-system -f dashboard-ingress.yaml
```

确认上面的命令部署成功。

创建管理员sa:
```bash
kubectl create serviceaccount kube-dashboard-admin-sa -n kube-system

kubectl create clusterrolebinding kube-dashboard-admin-sa \
--clusterrole=cluster-admin --serviceaccount=kube-system:kube-dashboard-admin-sa
```

获取集群管理员登录dashboard所需token:
```bash
kubectl describe -n kube-system secret $(kubectl -n kube-system get secret | grep kube-dashboard-admin-sa-token|awk -F ' ' '{print $1}')
Name:         kube-dashboard-admin-sa-token-7r5dh
Namespace:    kube-system
Labels:       <none>
Annotations:  kubernetes.io/service-account.name: kube-dashboard-admin-sa
              kubernetes.io/service-account.uid: 594e7c8a-4a81-43ec-9819-0df5d7813cfd

Type:  kubernetes.io/service-account-token

Data
====
ca.crt:     1099 bytes
namespace:  11 bytes
token:      eyJhbGciOiJSUzI1NiIsImtpZCI6IjJWLUlNOFBfd2lFUWZzVTZ6UHNMRFludHpkaU5TbFdwME80MmNMbGpVQTgifQ.eyJpc3MiOiJrdWJlcm5ldGVzL3NlcnZpY2VhY2NvdW50Iiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9uYW1lc3BhY2UiOiJrdWJlLXN5c3RlbSIsImt1YmVybmV0ZXMuaW8vc2VydmljZWFjY291bnQvc2VjcmV0Lm5hbWUiOiJrdWJlLWRhc2hib2FyZC1hZG1pbi1zYS10b2tlbi03cjVkaCIsImt1YmVybmV0ZXMuaW8vc2VydmljZWFjY291bnQvc2VydmljZS1hY2NvdW50Lm5hbWUiOiJrdWJlLWRhc2hib2FyZC1hZG1pbi1zYSIsImt1YmVybmV0ZXMuaW8vc2VydmljZWFjY291bnQvc2VydmljZS1hY2NvdW50LnVpZCI6IjU5NGU3YzhhLTRhODEtNDNlYy05ODE5LTBkZjVkNzgxM2NmZCIsInN1YiI6InN5c3RlbTpzZXJ2aWNlYWNjb3VudDprdWJlLXN5c3RlbTprdWJlLWRhc2hib2FyZC1hZG1pbi1zYSJ9.P_zB-q-gp38XEkGMbtrdZawRwpL740Z2amVg1mQ5SeHY701cU2wNziIMfi_UyKRP0BZ1O_F8l2g-kEqzot5i9Pjbrw9mkJfx4x3AVXDCWHv6a-TJJSyXCj1Of8dFzksMWrkdXL3UHGAOZZ9DGMcPIeuaN1CQIOJVo9shInBcQt8dHglr8rBtAhnuMnhOJZZc9Pp1gXCktw2iWr1oeEdpZtgLYCH3c4hpMi9oQnkyP70T0m69BJBkbHP0_toMJISZk-NkR3KmhB4Ze959lyCFA09urP6sZKETlcxy1q_nJ1ILmMJWJaTGinY1hlHEGRYwz7Qur5N7oKEeAiJWugam5w
```

由于这里的证书和域名都是自生成的，所以集群外无法解析。在本机的 /etc/hosts 上添加记录
```bash
172.16.219.101 k8s.example.com
```
同时在集群的 coredns 中添加记录
```bash
kubectl describe configmap coredns -n kube-system
Name:         coredns
Namespace:    kube-system
Labels:       <none>
Annotations:  <none>

Data
====
Corefile:
----
.:53 {
    errors
    health {
       lameduck 5s
    }
    ready
    kubernetes cluster.local in-addr.arpa ip6.arpa {
       pods insecure
       fallthrough in-addr.arpa ip6.arpa
       ttl 30
    }
    hosts {
       172.16.219.101 k8s.example.com
       fallthrough
    }
    prometheus :9153
    forward . /etc/resolv.conf {
       max_concurrent 1000
    }
    cache 30
    loop
    reload
    loadbalance
}


BinaryData
====
```
使用上面的token登录k8s dashboard。
![](https://raw.githubusercontent.com/xingyys/myblog/main/posts/images/20220113203555.png)
