# K8s上搭建harbor私有库


由于公共镜像库都是部署在外网，而且有些镜像的体积也比较庞大。因此在自建的 k8s 环境上安装一套私有镜像仓库是十分有必要的。接下来就详细说明如何一步步搭建一个 harbor
环境。

## 准备

首先需要安装有一套可用的 k8s 环境，本地的环境如下：

| 主机名     | 系统    | 配置      | ip 地址      | 角色                    |
| ---------- | ------- | --------- | ------------ | ----------------------- |
| k8s-master | CentOS7 | 2 core 8G, 两块 100 硬盘 | 192.168.2.21 | master,glusterfs,heketi,helm |
| k8s-node1 | CentOS7 | 2 core 8G , 两块 100 硬盘 | 192.168.2.22 | node,gluster |
| k8s-node2 | CentOS7 | 2 core 8G , 两块 100 硬盘 | 192.168.2.23 | node,gluster |

## 安装 gluster

因为 harbor 需要 k8s pv 和 pvc，所以需要先安装 StorageClass

### gluster 配置
这个环境上是没有配置 StorageClass，这里选择 gluster 作为默认的存储。

安装 gluster 软件包，每个节点上都要执行
```bash
yum install -y glusterfs-server gluster-common glusterfs-client fuse

# 启动 gluster 服务
systemctl start glusterd
systemctl enable glusterd
```

### heketi 配置

[Heketi](https://github.com/heketi/heketi)提供了一个RESTful管理界面，可以用来管理GlusterFS卷的生命周期。 通过Heketi，就可以像使用OpenStack Manila，
Kubernetes和OpenShift一样申请可以动态配置GlusterFS卷。Heketi会动态在集群内选择bricks构建所需的volumes，这样以确保数据的副本会分散到集群不同的故障域内。
同时Heketi还支持任意数量的ClusterFS集群，以保证接入的云服务器不局限于单个GlusterFS集群。

下载 heketi
```bash
yum install -y heketi
```
修改配置文件
```bash
# vim /etc/heketi.json
{
    "port": "18080",
    "user_auth": false,
    "jwt": {
        "admin": {
            "key": "adminkey"
        },
        "user": {
            "key": "userkey"
        }
    },
    "glusterfs": {
        "executor": "ssh",
        "sshexec": {
            "keyfile": "/etc/heketi/heketi_key",
            "user": "root",
            "port": "22",
            "fstab": "/etc/fstab"
        },
        "db": "/var/lib/heketi/heketi.db",
        "loglevel": "info"
    }
}
```
生成 ssh 密钥
```bash
ssh-keygen -t rsa -q -f /etc/heketi/heketi_key -N ''
chmod 600 /etc/heketi/heketi_key.pub

# ssh公钥传递，这里只以一个节点为例
ssh-copy-id -i /etc/heketi/heketi_key.pub root@192.168.2.21
ssh-copy-id -i /etc/heketi/heketi_key.pub root@192.168.2.22
ssh-copy-id -i /etc/heketi/heketi_key.pub root@192.168.2.23

# 验证是否能通过ssh密钥正常连接到glusterfs节点

ssh -i /etc/heketi/heketi_key root@192.168.2.22
```
启动 heketi
```bash
systemctl start heketi
systemctl enable heketi
```

添加 heketi 环境变量
```bash
cat >>  /etc/profile << EOF
export HEKETI_CLI_SERVER=http://192.168.2.21:18080
export HEKETI_CLI_USER=admin
export HEKETI_CLI_SECRET=adminkey
EOF

source /etc/profile
```

添加 gluster 节点
```bash
heketi-cli cluster create

heketi-cli node add --cluster 2292936a36f1798e588ac0a687b58a6d --management-host-name 192.168.2.21 --storage-host-name 192.168.2.21 --zone 1
heketi-cli node add --cluster 2292936a36f1798e588ac0a687b58a6d --management-host-name 192.168.2.22 --storage-host-name 192.168.2.22 --zone 1
heketi-cli node add --cluster 2292936a36f1798e588ac0a687b58a6d --management-host-name 192.168.2.23 --storage-host-name 192.168.2.23 --zone 1
```

添加每个节点上的磁盘
```bash
heketi-cli --server http://192.168.2.21:18080 --user admin --secret adminkey device add --name="/dev/sdb" --node 314d3fb4d3e7eb4d7c9a6a3f5c800d74
heketi-cli --server http://192.168.2.21:18080 --user admin --secret adminkey device add --name="/dev/sdc" --node 314d3fb4d3e7eb4d7c9a6a3f5c800d74
heketi-cli --server http://192.168.2.21:18080 --user admin --secret adminkey device add --name="/dev/sdb" --node 500c293b77696808673a4c25d7d4961a
heketi-cli --server http://192.168.2.21:18080 --user admin --secret adminkey device add --name="/dev/sdc" --node 500c293b77696808673a4c25d7d4961a
heketi-cli --server http://192.168.2.21:18080 --user admin --secret adminkey device add --name="/dev/sdb" --node e4827cda4d3da2b33d30b95ec085cc8a
heketi-cli --server http://192.168.2.21:18080 --user admin --secret adminkey device add --name="/dev/sdc" --node e4827cda4d3da2b33d30b95ec085cc8a
```

### 添加默认的 StorageClass
新增 StorageClass 配置文件
```bash
# vim gluster-sa.yaml

apiVersion: v1
kind: Secret
metadata:
  name: heketi-secret
  namespace: default
data:
  key: YWRtaW5rZXk=   # echo -n "adminkey" | base64 
type: kubernetes.io/glusterfs

---
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: glusterfs
provisioner: kubernetes.io/glusterfs
allowVolumeExpansion: true
parameters:
  resturl: "http://192.168.2.21:18080"
  clusterid: "2292936a36f1798e588ac0a687b58a6d"
  restauthenabled: "true"
  restuser: "admin"
  restuserkey: "adminkey"
  secretNamespace: "default"
  secretName: "heketi-secret"
  gidMin: "40000"
  gidMax: "50000"
  volumetype: "replicate:3"
```
创建 StorageClass 
```bash
kubectl apply -f gluster-sa.yaml
```
设置为默认 StorageClass
```bash
kubectl patch storageclass glusterfs -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'

# kubectl get storageclass
NAME                  PROVISIONER               RECLAIMPOLICY   VOLUMEBINDINGMODE   ALLOWVOLUMEEXPANSION   AGE
glusterfs (default)   kubernetes.io/glusterfs   Delete          Immediate           true                   8h
```

## 安装 harbor
安装完 gluster 就可以开始安装 harbor，先使用 helm 下载 harbor chart

```bash
helm repo add harbor https://helm.goharbor.io
helm pull harbor/harbor --untar
```

修改 values 配置文件
```bash
# vim harbor/values.yaml
expose:
  type: ingress    # 第4行，使用 ingress 对外提供服务
  tls:
    enabled: true  
    certSource: secret # 第19行，选择 k8s secret 作为 tls 来源
    secret:
      secretName: "tls-harbor"       # 第28行，k8s secret 名称，提供 https 证书
      notarySecretName: "tls-harbor" # 第33行，k8s secret 名称，提供 https 证书
  ingress:
    hosts:
      core: harbor.howlinkdev.com    # 第36行，harbor 域名
      notary: notary.howlinkdev.com  # 第37行，notary 域名，用于镜像的签名，保证镜像安全，不能与core设置的域名一样
externalURL: https://harbor.howlinkdev.com  # 第126行，harbor 访问 URL，与第36行域名保持一致
persistence:
   enabled: true
   resourcePolicy: "keep"
   persistentVolumeClaim:
     registry:   # 镜像存储
       storageClass: "glusterfs"  # 第219行， 存储类型，选择 gluster
       subPath: "harbor-registry"
       accessMode: ReadWriteOnce
       size: 50Gi  # pv 容量
     chartmuseum:  # helm chart 存储
       storageClass: "glusterfs"
       subPath: "harbor-chartmuseum"
       accessMode: ReadWriteOnce
       size: 5Gi
     jobservice:
       storageClass: "glusterfs"
       subPath: "harbor-jobservice"
       accessMode: ReadWriteOnce
       size: 5Gi
     database:
       storageClass: "glusterfs"
       subPath: "harbor-database"
       accessMode: ReadWriteOnce
       size: 10Gi
     redis:
       storageClass: "glusterfs"
       subPath: "harbor-redis"
       accessMode: ReadWriteOnce
       size: 5Gi
     trivy:
       storageClass: "glusterfs"
       subPath: "harbor-trivy"
       accessMode: ReadWriteOnce
       size: 5Gi
```

生成自签证书
```bash
# vim ssl/openssl.conf
# ca根证书配置
[ ca ]
subjectKeyIdentifier=hash
authorityKeyIdentifier=keyid:always,issuer
basicConstraints = critical,CA:true

# HTTPS应用证书配置
[ crt ]
subjectKeyIdentifier = hash
authorityKeyIdentifier=keyid:always,issuer
basicConstraints = critical, CA:false
keyUsage = critical, digitalSignature, cRLSign, keyEncipherment
extendedKeyUsage = critical, serverAuth, clientAuth
subjectAltName=@alt_names

# SANs可以将一个证书给多个域名或IP使用
# 访问的域名或IP必须包含在此，否则无效
# 修改为你要保护的域名或者IP地址，支持通配符
[alt_names]
DNS.1 = howlinkdev.com
DNS.2 = harbor.howlinkdev.com
IP.1 = 192.168.2.21
```
创建证书
```bash
cd ssl
# 生成根证书
openssl genrsa -out root.key 2048
openssl req -new -key root.key  -out root.csr -subj "/C=CN/ST=Zhejiang/L=Wenzhou/O=howlink/OU=howlink/CN=howlinkdev.com"
openssl x509 -req -extfile openssl.cnf -extensions ca -in root.csr -out root.crt -signkey root.key -CAcreateserial -days 3650

# 生成 harbor 应用证书
openssl genrsa -out harbor.key 2048
openssl req -new -key harbor.key -out harbor.csr -subj "/C=CN/ST=Zhejiang/L=Wenzhou/O=howlink/OU=howlink/CN=harbor.howlinkdev.com"
openssl x509 -req -extfile openssl.cnf -extensions crt -CA root.crt -CAkey root.key -CAserial harbor.srl -CAcreateserial -in harbor.csr -out harbor.crt -days 3650
```
添加证书
```bash
kubectl create namespace harbor
kubectl create secret tls tls-harbor --cert=ssl/harbor.crt --key=ssl/harbor.key -n harbor
```
安装 harbor
```bash
cd harbor/harbor

helm install harbor . -n harbor
```
查看 pod
```bash
# kubectl get pods -n harbor
NAME                                    READY   STATUS    RESTARTS     AGE
harbor-chartmuseum-76cbb9445b-hq9vm     1/1     Running   0            4h1m
harbor-core-6846c8d495-h26nw            1/1     Running   0            4h1m
harbor-database-0                       1/1     Running   0            4h1m
harbor-jobservice-c6f985dcf-nlg4h       1/1     Running   0            4h1m
harbor-notary-server-7d89946d7c-g9lj2   1/1     Running   1 (4h ago)   4h1m
harbor-notary-signer-58ff89f555-92pmr   1/1     Running   1 (4h ago)   4h1m
harbor-portal-f6f488566-5zc6k           1/1     Running   0            4h1m
harbor-redis-0                          1/1     Running   0            4h1m
harbor-registry-65f599f844-gxf5r        2/2     Running   0            4h1m
harbor-trivy-0                          1/1     Running   0            4h1m
```
由于 `harbor.howlinkdev.com` 由于自建的域名，k8s core dns 默认无法解析，所以需要修改客户端的 `/etc/hosts`

> 注: 如果安装失败需要重新安装时，需要先删除残留的 pv 和 pvc。不然可能出现 harbor-registry /storage 目录权限错误的情况。

```bash
# /etc/hosts

192.168.2.21 harbor.howlinkdev.com
```

还需要修改 coredns 的配置文件
```bash
# kubectl edit cm coredns -n kube-system
apiVersion: v1
data:
  Corefile: |
    .:53 {
        log
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
        # 添加自定义解析规则
        hosts {
           192.168.2.21 harbor.howlinkdev.com
           fallthrough
        }
        prometheus :9153
        forward . /etc/resolv.conf {
           max_concurrent 1000
        }
        cache 30
        reload
        loop
        loadbalance
    }
kind: ConfigMap
metadata:
  creationTimestamp: "2022-05-30T02:29:32Z"
  name: coredns
  namespace: kube-system
  resourceVersion: "57400"
  uid: 702890ed-fb08-443e-9ce2-f28dac4ec9b4
```
客户端使用浏览器访问 `https://harbor.howlinkdev.com`，默认的用户名密码为 admin/Harbor12345

![](https://raw.githubusercontent.com/xingyys/myblog/main/posts/images/20220530200012.png)


## 设置私有库
最后我们就可以修改 containerd 的配置文件，新增 `harbor.howlinkdev.com`

```bash
# vim /etc/containerd/config.toml

    [plugins."io.containerd.grpc.v1.cri".registry]
      config_path = ""

      [plugins."io.containerd.grpc.v1.cri".registry.headers]

      [plugins."io.containerd.grpc.v1.cri".registry.mirrors]
        [plugins."io.containerd.grpc.v1.cri".registry.mirrors."harbor.howlinkdev.com"]
          endpoint = ["https://harbor.howlinkdev.com"]

      [plugins."io.containerd.grpc.v1.cri".registry.auths]

      [plugins."io.containerd.grpc.v1.cri".registry.configs]
        [plugins."io.containerd.grpc.v1.cri".registry.configs."harbor.howlinkdev.com".tls]
          insecure_skip_verify = true
        [plugins."io.containerd.grpc.v1.cri".registry.configs."harbor.howlinkdev.com".auth]
          username="admin"
          password="Harbor12345"
```

重启 containerd
```bash
systemctl restart containerd
```

安装 nerdctl
```bash
wget https://github.com/containerd/nerdctl/releases/download/v0.20.0/nerdctl-0.20.0-linux-amd64.tar.gz

tar nerdctl-0.20.0-linux-amd64.tar.gz
mv nerdctl /usr/local/sbin/nerdctl
chmod +x /usr/local/sbin/nerdctl
```

修改 `/etc/hosts`，添加记录
```bash
192.168.2.21 harbor.howlinkdev.com
```

使用 nerdctl 登录 harbor
```bash
nerdctl login https://harbor.howlinkdev.com --insecure-registry -u admin -p Harbor12345
```

上传镜像
```bash
nerdctl push harbor.howlinkdev.com/library/nginx --insecure-registry 
```

nerdctl push报错：Request Entity Too Large，这里报错是因为ingress-nginx的配置文件中client_max_body_size参数过小。
修改 ingress-nginx 的 /etc/nginx/nginx.conf
```bash
# vim /etc/nginx/nginx.conf

client_body_timeout             120s;
client_header_timeout           120s;
client_max_body_size                    500m;

location /configuration 中的client_max_body_size 21m不用改
```
