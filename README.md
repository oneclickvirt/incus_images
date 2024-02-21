# incus_images

[![almalinux x86_64](https://github.com/oneclickvirt/incus_images/actions/workflows/almalinux_x86_64.yml/badge.svg)](https://github.com/oneclickvirt/incus_images/actions/workflows/almalinux_x86_64.yml) [![alpine x86_64](https://github.com/oneclickvirt/incus_images/actions/workflows/alpine_x86_64.yml/badge.svg)](https://github.com/oneclickvirt/incus_images/actions/workflows/alpine_x86_64.yml) [![archlinux x86_64](https://github.com/oneclickvirt/incus_images/actions/workflows/archlinux_x86_64.yml/badge.svg)](https://github.com/oneclickvirt/incus_images/actions/workflows/archlinux_x86_64.yml) [![centos x86_64](https://github.com/oneclickvirt/incus_images/actions/workflows/centos_x86_64.yml/badge.svg)](https://github.com/oneclickvirt/incus_images/actions/workflows/centos_x86_64.yml) [![debian x86_64](https://github.com/oneclickvirt/incus_images/actions/workflows/debian_x86_64.yml/badge.svg)](https://github.com/oneclickvirt/incus_images/actions/workflows/debian_x86_64.yml) [![kali x86_64](https://github.com/oneclickvirt/incus_images/actions/workflows/kali_x86_64.yml/badge.svg)](https://github.com/oneclickvirt/incus_images/actions/workflows/kali_x86_64.yml) [![openwrt x86_64](https://github.com/oneclickvirt/incus_images/actions/workflows/openwrt_x86_64.yml/badge.svg)](https://github.com/oneclickvirt/incus_images/actions/workflows/openwrt_x86_64.yml) [![oralce x86_64](https://github.com/oneclickvirt/incus_images/actions/workflows/oralce_x86_64.yml/badge.svg)](https://github.com/oneclickvirt/incus_images/actions/workflows/oralce_x86_64.yml) [![rockylinux x86_64](https://github.com/oneclickvirt/incus_images/actions/workflows/rockylinux_x86_64.yml/badge.svg)](https://github.com/oneclickvirt/incus_images/actions/workflows/rockylinux_x86_64.yml) [![ubuntu x86_64](https://github.com/oneclickvirt/incus_images/actions/workflows/ubuntu_x86_64.yml/badge.svg)](https://github.com/oneclickvirt/incus_images/actions/workflows/ubuntu_x86_64.yml) [![gentoo x86_64](https://github.com/oneclickvirt/incus_images/actions/workflows/gentoo_x86_64.yml/badge.svg)](https://github.com/oneclickvirt/incus_images/actions/workflows/gentoo_x86_64.yml) [![fedora x86_64](https://github.com/oneclickvirt/incus_images/actions/workflows/fedora_x86_64.yml/badge.svg)](https://github.com/oneclickvirt/incus_images/actions/workflows/fedora_x86_64.yml) [![openeuler x86_64](https://github.com/oneclickvirt/incus_images/actions/workflows/openeuler_x86_64.yml/badge.svg)](https://github.com/oneclickvirt/incus_images/actions/workflows/openeuler_x86_64.yml) [![opensuse x86_64](https://github.com/oneclickvirt/incus_images/actions/workflows/opensuse_x86_64.yml/badge.svg)](https://github.com/oneclickvirt/incus_images/actions/workflows/opensuse_x86_64.yml) [![clone yaml](https://github.com/oneclickvirt/incus_images/actions/workflows/clone_yaml.yml/badge.svg)](https://github.com/oneclickvirt/incus_images/actions/workflows/clone_yaml.yml)

## 说明

Releases中的镜像(每日拉取镜像进行自动修补和更新)：

已预安装：wget curl openssh-server sshpass sudo cron(cronie) lsof iptables dos2unix

已预开启SSH登陆，预设SSH监听IPV4和IPV6的22端口，开启允许密码验证登陆

所有镜像均开启允许root用户进行SSH登录

默认用户名：```root```

未修改默认密码，与官方仓库一致

本仓库的容器镜像服务于： https://github.com/oneclickvirt/incus and https://github.com/oneclickvirt/lxd

支持:

[incus的所有版本](https://github.com/lxc/incus)

LXD 版本 <= [5.18](https://github.com/canonical/lxd/releases/tag/lxd-5.18) 

incus在LXD的5.18版本分叉，不保证LXD更高版本下的容器镜像可用性

## Introduce

Mirrors in Releases (pulls mirrors daily for automatic patching and updating):

Pre-installed: wget curl openssh-server sshpass sudo cron(cronie) lsof iptables dos2unix

Pre-enabled SSH login, preset SSH listening on port 22 of IPV4 and IPV6, enabled to allow password authentication login

All mirrors are enabled to allow SSH login for root users.

Default username: ```root```.

Unchanged default password, consistent with official repository.

This repository container images serves https://github.com/oneclickvirt/incus and https://github.com/oneclickvirt/lxd

Support:

[incus full version](https://github.com/lxc/incus)

LXD version <= [5.18](https://github.com/canonical/lxd/releases/tag/lxd-5.18)

incus forked at version 5.18 of LXD and does not guarantee container image availability under higher versions of LXD

## 测试-test

```
incus image import incus.tar.xz rootfs.squashfs --alias myc
incus init myc test
incus start test
incus exec test -- /bin/bash
```

```
incus delete -f test
incus image delete myc
```

## Thanks

https://discuss.linuxcontainers.org/t/distrobuilder-how-to-compile-a-centos-container-image-in-an-ubuntu-environment-github-action/18709

https://linuxcontainers.org/incus/docs/main/

https://github.com/lxc/lxc-ci/tree/main/images

https://github.com/lxc/distrobuilder

https://go.dev/dl/
