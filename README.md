# lxd_images

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
