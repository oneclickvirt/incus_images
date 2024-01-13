#!/bin/bash
# from https://github.com/oneclickvirt/incus_images


opath=$(pwd)
if ! command -v zip >/dev/null 2>&1; then
    sudo apt-get install zip -y
fi
if ! command -v distrobuilder >/dev/null 2>&1; then
    sudo snap install distrobuilder --classic
fi
if ! command -v debootstrap >/dev/null 2>&1; then
    sudo apt-get install debootstrap -y
fi

debian(){
    # debian
    debian_versions=("buster" "bullseye" "bookworm" "trixie")
    debian_ver_nums=("10" "11" "12" "13")
    architectures=("amd64" "arm64") # "armel" "armhf" "i386" "ppc64el" "s390x"
    variants=("default" "cloud")
    len=${#debian_versions[@]}
    for ((i=0; i<len; i++)); do
        version=${debian_versions[i]}
        ver_num=${debian_ver_nums[i]}
        for arch in "${architectures[@]}"; do
            for variant in "${variants[@]}"; do
                sudo distrobuilder build-incus ${opath}/images_yaml/debian.yaml -o image.release=${version} -o image.architecture=${arch} -o image.variant=${variant}
                if [ -f incus.tar.xz ] && [ -f rootfs.squashfs ]; then
                    zip debian_${ver_num}_${version}_${arch}_${variant}.zip incus.tar.xz rootfs.squashfs
                    rm -rf incus.tar.xz rootfs.squashfs
                fi
            done
        done
    done
}
