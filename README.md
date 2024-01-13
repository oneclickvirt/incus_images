# lxd_images

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
