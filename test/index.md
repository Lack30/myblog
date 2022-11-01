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




