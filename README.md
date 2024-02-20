# incus_images

[![almalinux images x86_64](https://github.com/oneclickvirt/incus_images/actions/workflows/build_almalinux_x86_64.yml/badge.svg)](https://github.com/oneclickvirt/incus_images/actions/workflows/build_almalinux_x86_64.yml) [![alpine images x86_64](https://github.com/oneclickvirt/incus_images/actions/workflows/build_alpine_x86_64.yml/badge.svg)](https://github.com/oneclickvirt/incus_images/actions/workflows/build_alpine_x86_64.yml) [![archlinux images x86_64](https://github.com/oneclickvirt/incus_images/actions/workflows/build_archlinux_x86_64.yml/badge.svg)](https://github.com/oneclickvirt/incus_images/actions/workflows/build_archlinux_x86_64.yml) [![centos images x86_64](https://github.com/oneclickvirt/incus_images/actions/workflows/build_centos_x86_64.yml/badge.svg)](https://github.com/oneclickvirt/incus_images/actions/workflows/build_centos_x86_64.yml) [![debian images x86_64](https://github.com/oneclickvirt/incus_images/actions/workflows/build_debian_x86_64.yml/badge.svg)](https://github.com/oneclickvirt/incus_images/actions/workflows/build_debian_x86_64.yml) [![kali images x86_64](https://github.com/oneclickvirt/incus_images/actions/workflows/build_kali_x86_64.yml/badge.svg)](https://github.com/oneclickvirt/incus_images/actions/workflows/build_kali_x86_64.yml) [![openwrt images x86_64](https://github.com/oneclickvirt/incus_images/actions/workflows/build_openwrt_x86_64.yml/badge.svg)](https://github.com/oneclickvirt/incus_images/actions/workflows/build_openwrt_x86_64.yml) [![oralce images x86_64](https://github.com/oneclickvirt/incus_images/actions/workflows/build_oralce_x86_64.yml/badge.svg)](https://github.com/oneclickvirt/incus_images/actions/workflows/build_oralce_x86_64.yml) [![rockylinux images x86_64](https://github.com/oneclickvirt/incus_images/actions/workflows/build_rockylinux_x86_64.yml/badge.svg)](https://github.com/oneclickvirt/incus_images/actions/workflows/build_rockylinux_x86_64.yml) [![ubuntu images x86_64](https://github.com/oneclickvirt/incus_images/actions/workflows/build_ubuntu_x86_64.yml/badge.svg)](https://github.com/oneclickvirt/incus_images/actions/workflows/build_ubuntu_x86_64.yml) [![Clone yaml](https://github.com/oneclickvirt/incus_images/actions/workflows/clone_yaml.yml/badge.svg)](https://github.com/oneclickvirt/incus_images/actions/workflows/clone_yaml.yml)

This repository container images serves https://github.com/oneclickvirt/incus and https://github.com/oneclickvirt/lxd

Support:

[incus full version](https://github.com/lxc/incus)

LXD version <= [5.18](https://github.com/canonical/lxd/releases/tag/lxd-5.18)

## test

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
