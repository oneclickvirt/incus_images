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
run_funct="${1:-debian}"

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

ubuntu(){
    # ubuntu
    ubuntu_versions=("bionic" "focal" "jammy" "lunar" "mantic" "noble")
    ubuntu_ver_nums=("18.04" "20.04" "22.04" "23.04" "23.10" "24.04")
    architectures=("amd64" "arm64") # "armel" "armhf" "i386" "ppc64el" "s390x"
    variants=("default" "cloud")
    len=${#ubuntu_versions[@]}
    for ((i=0; i<len; i++)); do
        version=${ubuntu_versions[i]}
        ver_num=${ubuntu_ver_nums[i]}
        for arch in "${architectures[@]}"; do
            for variant in "${variants[@]}"; do
                sudo distrobuilder build-incus ${opath}/images_yaml/ubuntu.yaml -o image.release=${version} -o image.architecture=${arch} -o image.variant=${variant}
                if [ -f incus.tar.xz ] && [ -f rootfs.squashfs ]; then
                    zip ubuntu_${ver_num}_${version}_${arch}_${variant}.zip incus.tar.xz rootfs.squashfs
                    rm -rf incus.tar.xz rootfs.squashfs
                fi
            done
        done
    done
}

kali(){
    # kali
    kali_versions=("kali-rolling")
    kali_ver_nums=("latest")
    architectures=("amd64" "arm64") # "armel" "armhf" "i386" "ppc64el" "s390x"
    variants=("default" "cloud")
    len=${#kali_versions[@]}
    for ((i=0; i<len; i++)); do
        version=${kali_versions[i]}
        ver_num=${kali_ver_nums[i]}
        for arch in "${architectures[@]}"; do
            for variant in "${variants[@]}"; do
                sudo distrobuilder build-incus ${opath}/images_yaml/kali.yaml -o image.release=${version} -o image.architecture=${arch} -o image.variant=${variant}
                if [ -f incus.tar.xz ] && [ -f rootfs.squashfs ]; then
                    zip kali_${ver_num}_${version}_${arch}_${variant}.zip incus.tar.xz rootfs.squashfs
                    rm -rf incus.tar.xz rootfs.squashfs
                fi
            done
        done
    done
}

centos(){
    # centos
    centos_versions=("7" "8-Stream" "9-Stream")
    centos_ver_nums=("7" "8-Stream" "9-Stream")
    architectures=("amd64" "arm64") # "armel" "armhf" "i386" "ppc64el" "s390x"
    variants=("default" "cloud")
    len=${#centos_versions[@]}
    for ((i=0; i<len; i++)); do
        version=${centos_versions[i]}
        ver_num=${centos_ver_nums[i]}
        for arch in "${architectures[@]}"; do
            for variant in "${variants[@]}"; do
                sudo distrobuilder build-incus ${opath}/images_yaml/centos.yaml -o image.release=${version} -o image.architecture=${arch} -o image.variant=${variant}
                if [ -f incus.tar.xz ] && [ -f rootfs.squashfs ]; then
                    zip centos_${ver_num}_${version}_${arch}_${variant}.zip incus.tar.xz rootfs.squashfs
                    rm -rf incus.tar.xz rootfs.squashfs
                fi
            done
        done
    done
}

almalinux(){
    # almalinux
    almalinux_versions=("8" "9")
    almalinux_ver_nums=("8" "9")
    architectures=("amd64" "arm64") # "armel" "armhf" "i386" "ppc64el" "s390x"
    variants=("default" "cloud")
    len=${#almalinux_versions[@]}
    for ((i=0; i<len; i++)); do
        version=${almalinux_versions[i]}
        ver_num=${almalinux_ver_nums[i]}
        for arch in "${architectures[@]}"; do
            for variant in "${variants[@]}"; do
                sudo distrobuilder build-incus ${opath}/images_yaml/almalinux.yaml -o image.release=${version} -o image.architecture=${arch} -o image.variant=${variant}
                if [ -f incus.tar.xz ] && [ -f rootfs.squashfs ]; then
                    zip almalinux_${ver_num}_${version}_${arch}_${variant}.zip incus.tar.xz rootfs.squashfs
                    rm -rf incus.tar.xz rootfs.squashfs
                fi
            done
        done
    done
}

rockylinux(){
    # rockylinux
    rockylinux_versions=("8" "9")
    rockylinux_ver_nums=("8" "9")
    architectures=("amd64" "arm64") # "armel" "armhf" "i386" "ppc64el" "s390x"
    variants=("default" "cloud")
    len=${#rockylinux_versions[@]}
    for ((i=0; i<len; i++)); do
        version=${rockylinux_versions[i]}
        ver_num=${rockylinux_ver_nums[i]}
        for arch in "${architectures[@]}"; do
            for variant in "${variants[@]}"; do
                sudo distrobuilder build-incus ${opath}/images_yaml/rockylinux.yaml -o image.release=${version} -o image.architecture=${arch} -o image.variant=${variant}
                if [ -f incus.tar.xz ] && [ -f rootfs.squashfs ]; then
                    zip rockylinux_${ver_num}_${version}_${arch}_${variant}.zip incus.tar.xz rootfs.squashfs
                    rm -rf incus.tar.xz rootfs.squashfs
                fi
            done
        done
    done
}

alpine(){
    # alpine
    alpine_versions=("3.17" "3.18" "3.19" "edge")
    alpine_ver_nums=("3.17" "3.18" "3.19" "edge")
    architectures=("amd64" "arm64") # "armel" "armhf" "i386" "ppc64el" "s390x"
    variants=("default" "cloud")
    len=${#alpine_versions[@]}
    for ((i=0; i<len; i++)); do
        version=${alpine_versions[i]}
        ver_num=${alpine_ver_nums[i]}
        for arch in "${architectures[@]}"; do
            for variant in "${variants[@]}"; do
                sudo distrobuilder build-incus ${opath}/images_yaml/alpine.yaml -o image.release=${version} -o image.architecture=${arch} -o image.variant=${variant}
                if [ -f incus.tar.xz ] && [ -f rootfs.squashfs ]; then
                    zip alpine_${ver_num}_${version}_${arch}_${variant}.zip incus.tar.xz rootfs.squashfs
                    rm -rf incus.tar.xz rootfs.squashfs
                fi
            done
        done
    done
}

openwrt(){
    # openwrt
    openwrt_versions=("snapshot" "22.03" "23.05")
    openwrt_ver_nums=("snapshot" "22.03" "23.05")
    architectures=("amd64" "arm64") # "armel" "armhf" "i386" "ppc64el" "s390x"
    variants=("default" "cloud")
    len=${#openwrt_versions[@]}
    for ((i=0; i<len; i++)); do
        version=${openwrt_versions[i]}
        ver_num=${openwrt_ver_nums[i]}
        for arch in "${architectures[@]}"; do
            for variant in "${variants[@]}"; do
                sudo distrobuilder build-incus ${opath}/images_yaml/openwrt.yaml -o image.release=${version} -o image.architecture=${arch} -o image.variant=${variant}
                if [ -f incus.tar.xz ] && [ -f rootfs.squashfs ]; then
                    zip openwrt_${ver_num}_${version}_${arch}_${variant}.zip incus.tar.xz rootfs.squashfs
                    rm -rf incus.tar.xz rootfs.squashfs
                fi
            done
        done
    done
}

oracle(){
    # oracle
    oracle_versions=("7" "8" "9")
    oracle_ver_nums=("7" "8" "9")
    architectures=("amd64" "arm64") # "armel" "armhf" "i386" "ppc64el" "s390x"
    variants=("default" "cloud")
    len=${#oracle_versions[@]}
    for ((i=0; i<len; i++)); do
        version=${oracle_versions[i]}
        ver_num=${oracle_ver_nums[i]}
        for arch in "${architectures[@]}"; do
            for variant in "${variants[@]}"; do
                sudo distrobuilder build-incus ${opath}/images_yaml/oracle.yaml -o image.release=${version} -o image.architecture=${arch} -o image.variant=${variant}
                if [ -f incus.tar.xz ] && [ -f rootfs.squashfs ]; then
                    zip oracle_${ver_num}_${version}_${arch}_${variant}.zip incus.tar.xz rootfs.squashfs
                    rm -rf incus.tar.xz rootfs.squashfs
                fi
            done
        done
    done
}

archlinux(){
    # archlinux
    archlinux_versions=("latest")
    archlinux_ver_nums=("latest")
    architectures=("amd64" "arm64") # "armel" "armhf" "i386" "ppc64el" "s390x"
    variants=("default" "cloud")
    len=${#archlinux_versions[@]}
    for ((i=0; i<len; i++)); do
        version=${archlinux_versions[i]}
        ver_num=${archlinux_ver_nums[i]}
        for arch in "${architectures[@]}"; do
            for variant in "${variants[@]}"; do
                sudo distrobuilder build-incus ${opath}/images_yaml/archlinux.yaml -o image.release=${version} -o image.architecture=${arch} -o image.variant=${variant}
                if [ -f incus.tar.xz ] && [ -f rootfs.squashfs ]; then
                    zip archlinux_${ver_num}_${version}_${arch}_${variant}.zip incus.tar.xz rootfs.squashfs
                    rm -rf incus.tar.xz rootfs.squashfs
                fi
            done
        done
    done
}

$run_funct
