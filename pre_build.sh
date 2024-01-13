#!/bin/bash


snap install distrobuilder --classic
apt-get install debootstrap -y


debian_versions=("stretch" "buster" "bullseye" "bookworm" "trixie")
architectures=("amd64" "arm64" "armel" "armhf" "i386" "ppc64el" "s390x")
variants=("default", "cloud")
for version in "${debian_versions[@]}"; do
    for arch in "${architectures[@]}"; do
        for variant in "${variants[@]}"; do
            distrobuilder build-lxc debian.yaml -o image.release=${version} -o image.architecture=${arch} -o image.variant=${variant}
            mv meta.tar.xz
            mv rootfs.tar.xz
        done
    done
done
