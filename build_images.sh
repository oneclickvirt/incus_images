#!/bin/bash
# 从 https://github.com/oneclickvirt/incus_images 获取

opath=$(pwd)

# 检查并安装依赖工具
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
is_build_image="${2:-false}"
zip_name_list=()

# 构建或列出不同发行版的镜像
build_or_list_images() {
    local versions=("$1")
    local ver_nums=("$2")
    local architectures=("amd64")
    local variants=("default" "cloud")
    local len=${#versions[@]}
    for ((i = 0; i < len; i++)); do
        version=${versions[i]}
        ver_num=${ver_nums[i]}
        for arch in "${architectures[@]}"; do
            for variant in "${variants[@]}"; do
                if [ "$is_build_image" == true ]; then
                    sudo distrobuilder build-incus "${opath}/images_yaml/${run_funct}.yaml" -o image.release=${version} -o image.architecture=${arch} -o image.variant=${variant}
                    if [ -f incus.tar.xz ] && [ -f rootfs.squashfs ]; then
                        zip "${run_funct}_${ver_num}_${version}_${arch}_${variant}.zip" incus.tar.xz rootfs.squashfs
                        rm -rf incus.tar.xz rootfs.squashfs
                    fi
                else
                    zip_name_list+=("${run_funct}_${ver_num}_${version}_${arch}_${variant}.zip")
                fi
            done
        done
    done
    if [ "$is_build_image" == false ]; then
        echo "${zip_name_list[@]}"
    fi
}

# 不同发行版的配置
case "$run_funct" in
debian)
    build_or_list_images "buster bullseye bookworm trixie" "10 11 12 13"
    ;;
ubuntu)
    build_or_list_images "bionic focal jammy lunar mantic noble" "18.04 20.04 22.04 23.04 23.10 24.04"
    ;;
kali)
    build_or_list_images "kali-rolling" "latest"
    ;;
centos)
    build_or_list_images "7 8-Stream 9-Stream" "7 8 9"
    ;;
almalinux)
    build_or_list_images "8 9" "8 9"
    ;;
rockylinux)
    build_or_list_images "8 9" "8 9"
    ;;
alpine)
    build_or_list_images "3.17 3.18 3.19 edge" "3.17 3.18 3.19 edge"
    ;;
openwrt)
    build_or_list_images "snapshot 22.03 23.05" "snapshot 22.03 23.05"
    ;;
oracle)
    build_or_list_images "7 8 9" "7 8 9"
    ;;
archlinux)
    build_or_list_images "latest" "latest"
    ;;
*)
    echo "Invalid distribution specified."
    ;;
esac
