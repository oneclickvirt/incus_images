# lxd_images

```
distrobuilder build-incus debian.yaml -o image.release=bullseye -o image.architecture=amd64 -o image.variant=default
```

```
lxc image import incus.tar.xz rootfs.squashfs --alias mydebian
lxc init mydebian test
lxc start test
lxc exec test -- /bin/bash
```

```
lxc delete -f test
lxc image delete mydebian
```
