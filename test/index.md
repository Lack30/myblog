# 

```bash
cat <<EOF > /etc/apt/sources.list
deb http://cn.archive.ubuntu.com/ubuntu/ jammy main restricted universe multiverse
deb-src http://cn.archive.ubuntu.com/ubuntu/ jammy main restricted universe multiverse

deb http://cn.archive.ubuntu.com/ubuntu/ jammy-security main restricted universe multiverse
deb-src http://cn.archive.ubuntu.com/ubuntu/ jammy-security main restricted universe multiverse

deb http://cn.archive.ubuntu.com/ubuntu/ jammy-updates main restricted universe multiverse
deb-src http://cn.archive.ubuntu.com/ubuntu/ jammy-updates main restricted universe multiverse
EOF
```

````
apt-get install -y ubiquity ubiquity-casper ubiquity-frontend-gtk ubiquity-slideshow-ubuntu ubiquity-ubuntu-artwork
````

```bash
apt-get install -y \
    sudo \
    ubuntu-server \
    casper \
    ubiquity-casper \
    discover \
    laptop-detect \
    os-prober \
    network-manager \
    resolvconf \
    net-tools \
    wireless-tools \
    locales \
    grub-common \
    grub-gfxpayload-lists \
    grub-pc \
    grub-pc-bin \
    grub2-common
```

| **参数**                                                     | **说明** | **默认值** |
| :----------------------------------------------------------: | :------- | ---------- |
| --broker.default string |              Broker for pub/sub| |
| --cache.default string |               Cache used for key-value storage | |
|--client.content-type string |         Sets the content type for client ||
|--client.default string          |     Client for vine||
|--client.dial-timeout duration     |Sets the client dial timeout||
|--client.grpc.max-idle int  |          Sets maximum idle conns of a pool|  50 |
|--client.grpc.max-recv-msg-size int |   Sets maximum message that client can receive |  104857600|
|--client.grpc.max-send-msg-size int |  Sets maximum message that client can send |  104857600|
|--client.grpc.max-streams int     |    Sets maximum streams on a grpc connections (default 20) ||
|--client.pool-size int     |           Sets the client connection pool size |      |
|--client.pool-ttl duration   |         Sets the client connection pool ttl |      |
|--client.request-timeout duration   |  Sets the client request timeout | |
|--client.retries int   |               Sets the retries ||
|--dao.dialect string    |              Database option for the underlying dao | |
| --dao.dsn string                      |DSN database driver name for underlying dao ||
|--logger.fields strings          |     Sets other fields for logger ||
|--logger.level string     |            Sets the level for logger ||
| --registry.address string      |       Sets the registry addresses ||
|--registry.default string      |       Registry for discovery ||
|--registry.mdns.domain string     |    Sets the domain of mdns| ".vine" |
|--registry.timeout duration    |       Sets the registry request timeout |  3s |
|--selector.default string   |          Selector used to pick nodes for querying ||
|--server.address string   |            Bind address for the server ||
|--server.advertise string   |          Use instead of the server-address when registering with discovery ||
|--server.default string     |          Server for vine |    |
|--server.grpc.content-type string   |  Sets the content type for grpc protocol | "application/grpc"|
|--server.grpc.max-msg-size int   |     Sets maximum message size that server can send receive | 104857600 |
|--server.id string       |             Id of the server||
|--server.metadata strings    |         A list of key-value pairs defining metadata ||
|--server.name string        |          Name of the server||
|--server.register-interval duration  | Register interval ||
|--server.register-ttl duration      |  Registry TTL||
|--tracer.address string      |         Comma-separated list of tracer addresses||
|--tracer.default string        |       Trace for vine |          |


