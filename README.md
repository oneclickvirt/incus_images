# incus_images

Only support

https://github.com/oneclickvirt/incus_images/releases/tag/ubuntu

https://github.com/oneclickvirt/incus_images/releases/tag/debian

https://github.com/oneclickvirt/incus_images/releases/tag/kali

## test

```
distrobuilder build-incus debian.yaml -o image.release=bullseye -o image.architecture=amd64 -o image.variant=default
```

```
incus image import incus.tar.xz rootfs.squashfs --alias mydebian
incus init mydebian test
incus start test
incus exec test -- /bin/bash
```

```
incus delete -f test
incus image delete mydebian
```

## Thanks

https://linuxcontainers.org/incus/docs/main/

https://github.com/lxc/lxc-ci/tree/main/images

https://github.com/lxc/distrobuilder

https://go.dev/dl/
