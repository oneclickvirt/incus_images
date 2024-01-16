# incus_images

This repository container images serves https://github.com/oneclickvirt/incus and https://github.com/oneclickvirt/lxd

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
