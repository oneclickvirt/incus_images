#!/bin/bash
# from https://github.com/oneclickvirt/incus_images


sudo apt-get install zip -y
sudo snap install distrobuilder --classic
sudo apt-get install debootstrap -y
debian_versions=("buster" "bullseye" "bookworm" "trixie")
debian_ver_nums=("10" "11" "12" "13")
architectures=("amd64") # "arm64" "armel" "armhf" "i386" "ppc64el" "s390x"
variants=("default" "cloud")
len=${#debian_versions[@]}
for ((i=0; i<len; i++)); do
    version=${debian_versions[i]}
    ver_num=${debian_ver_nums[i]}
    for arch in "${architectures[@]}"; do
        for variant in "${variants[@]}"; do
            sudo distrobuilder build-incus /home/runner/work/incus_images/incus_images/images_yaml/debian.yaml -o image.release=${version} -o image.architecture=${arch} -o image.variant=${variant}
            if [ -f incus.tar.xz ] && [ -f rootfs.squashfs ]; then
                zip debian_${ver_num}_${version}_${arch}_${variant}.zip incus.tar.xz rootfs.squashfs
                rm -rf incus.tar.xz rootfs.squashfs
            fi
        done
    done
done
cd /home/runner/work/incus_images/incus_images
