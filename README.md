# incus_images

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

## Sponsor

Thanks to [dartnode](https://dartnode.com/?via=server) for compilation support.

## Thanks

https://discuss.linuxcontainers.org/t/distrobuilder-how-to-compile-a-centos-container-image-in-an-ubuntu-environment-github-action/18709

https://linuxcontainers.org/incus/docs/main/

https://github.com/lxc/lxc-ci/tree/main/images

https://github.com/lxc/distrobuilder

https://go.dev/dl/
