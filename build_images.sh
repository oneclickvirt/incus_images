#!/bin/bash
# 从 https://github.com/oneclickvirt/incus_images 获取

opath=$(pwd)

# 检查并安装依赖工具
if command -v apt-get >/dev/null 2>&1; then
    # ubuntu debian kali
    if ! command -v sudo >/dev/null 2>&1; then
        apt-get install sudo -y
    fi
    if ! command -v zip >/dev/null 2>&1; then
        sudo apt-get install zip -y
    fi
    if ! command -v jq >/dev/null 2>&1; then
        sudo apt-get install jq -y
    fi
    uname_output=$(uname -a)
    if [[ $uname_output != *ARM* && $uname_output != *arm* && $uname_output != *aarch* ]]; then
        if ! command -v snap >/dev/null 2>&1; then
            sudo apt-get install snapd -y
        fi
        if ! command -v distrobuilder >/dev/null 2>&1; then
            sudo snap install distrobuilder --classic
        fi
    fi
    # else
    #     sudo apt-get install build-essential -y
    #     export CGO_ENABLED=1
    #     export CC=gcc
    #     wget https://go.dev/dl/go1.21.6.linux-arm64.tar.gz
    #     chmod 777 go1.21.6.linux-arm64.tar.gz
    #     rm -rf /usr/local/go && tar -C /usr/local -xzf go1.21.6.linux-arm64.tar.gz
    #     export GOROOT=/usr/local/go
    #     export PATH=$GOROOT/bin:$PATH
    #     export GOPATH=$HOME/goprojects/
    #     go version
    #     apt-get install -q -y debootstrap rsync gpg squashfs-tools git make
    #     git config --global user.name "daily-update"
    #     git config --global user.email "tg@spiritlhl.top"
    #     mkdir -p $HOME/go/src/github.com/lxc/
    #     cd $HOME/go/src/github.com/lxc/
    #     git clone https://github.com/lxc/distrobuilder
    #     cd ./distrobuilder
    #     make
    #     export PATH=$HOME/goprojects/bin/distrobuilder:$PATH
    #     echo $PATH
    #     find $HOME -name distrobuilder -type f 2>/dev/null
    #     distrobuilder --version
    #     $HOME/goprojects/bin/distrobuilder --version
    # fi
    if ! command -v debootstrap >/dev/null 2>&1; then
        sudo apt-get install debootstrap -y
    fi
fi
run_funct="${1:-debian}"
is_build_image="${2:-false}"
build_arch="${3:-amd64}"
zip_name_list=()

# 构建或列出不同发行版的镜像
build_or_list_images() {
    local versions=()
    local ver_nums=()
    read -ra versions <<< "$1"
    read -ra ver_nums <<< "$2"
    local architectures=("$build_arch")
    local variants=("default" "cloud")
    local len=${#versions[@]}
    for ((i = 0; i < len; i++)); do
        version=${versions[i]}
        ver_num=${ver_nums[i]}
        for arch in "${architectures[@]}"; do
            for variant in "${variants[@]}"; do
                if [ "$is_build_image" == true ]; then
                    EXTRA_ARGS=""
                    if [[ "$run_funct" == "oracle" && "$version" == "9" ]]; then
                        EXTRA_ARGS="-o source.url=https://yum.oracle.com/ISOS/OracleLinux"
                    elif [[ "$run_funct" == "centos" ]]; then
                        if [ "$version" = "7" ] && [ "${arch}" != "amd64" ] && [ "${arch}" != "x86_64" ]; then
                            EXTRA_ARGS="-o source.url=http://mirror.math.princeton.edu/pub/centos-altarch/ -o source.skip_verification=true"
                        fi
                        if [ "$version" = "8-Stream" ] || [ "$version" = "9-Stream" ]; then
                            EXTRA_ARGS="${EXTRA_ARGS} -o source.variant=boot"
                        fi
                        if [ "$version" = "9-Stream" ]; then
                            EXTRA_ARGS="${EXTRA_ARGS} -o source.url=https://mirror1.hs-esslingen.de/pub/Mirrors/centos-stream"
                        fi
                    elif [[ "$run_funct" == "archlinux" ]]; then
                        if [ "${arch}" != "amd64" ] && [ "${arch}" != "i386" && [ "${arch}" != "x86_64" ]; then
                            EXTRA_ARGS="-o source.url=http://os.archlinuxarm.org"
                        fi
                    elif [[ "$run_funct" == "alpine" ]]; then
                        EXTRA_ARGS="-o source.same_as=3.19"
                    elif [[ "$run_funct" == "rockylinux" ]]; then
                        EXTRA_ARGS="-o source.variant=boot"
                    elif [[ "$run_funct" == "almalinux" ]]; then
                        EXTRA_ARGS="-o source.variant=boot"
                    elif [[ "$run_funct" == "ubuntu" ]]; then
                        if [ "${arch}" != "amd64" ] && [ "${arch}" != "i386" && [ "${arch}" != "x86_64" ]; then
                            EXTRA_ARGS="-o source.url=http://ports.ubuntu.com/ubuntu-ports"
                        fi
                    elif [[ "$run_funct" == "gentoo" ]]; then
                        if [ "${variant}" = "cloud" ]; then
                            EXTRA_ARGS="-o source.variant=openrc"
                        else
                            EXTRA_ARGS="-o source.variant=${variant}"
                        fi
                        [ "${arch}" = "x86_64" ] && arch="amd64"
                    elif [[ "$run_funct" == "fedora" ]]; then
                        [ "${arch}" = "amd64" ] && arch="x86_64"
                        [ "${arch}" = "arm64" ] && arch="aarch64"
                    fi
                    # apk apt dnf egoportage opkg pacman portage yum equo xbps zypper luet slackpkg
                    if [[ "$run_funct" == "centos" || "$run_funct" == "fedora" ]]; then
                        manager="yum"
                    elif [[ "$run_funct" == "kali" || "$run_funct" == "ubuntu" || "$run_funct" == "debian" ]]; then
                        manager="apt"
                    elif [[ "$run_funct" == "almalinux" || "$run_funct" == "rockylinux" || "$run_funct" == "oracle" ]]; then
                        manager="dnf"
                    elif [[ "$run_funct" == "archlinux" ]]; then
                        manager="pacman"
                    elif [[ "$run_funct" == "alpine" ]]; then
                        manager="apk"
                    elif [[ "$run_funct" == "openwrt" ]]; then
                        manager="opkg"
                    elif [[ "$run_funct" == "gentoo" ]]; then
                        manager="portage"
                    else
                        echo "Unsupported distribution: $run_funct"
                        exit 1
                    fi
                    if [[ "$run_funct" == "gentoo" ]]; then
                        echo "sudo distrobuilder build-incus "${opath}/images_yaml/${run_funct}.yaml" -o image.architecture=${arch} -o image.variant=${variant} ${EXTRA_ARGS}"
                        if sudo distrobuilder build-incus "${opath}/images_yaml/${run_funct}.yaml" -o image.architecture=${arch} -o image.variant=${variant} ${EXTRA_ARGS}; then
                            echo "Command succeeded"
                        fi
                    elif [[ "$run_funct" != "archlinux" ]]; then
                        echo "sudo distrobuilder build-incus "${opath}/images_yaml/${run_funct}.yaml" -o image.release=${version} -o image.architecture=${arch} -o image.variant=${variant} -o packages.manager=${manager} ${EXTRA_ARGS}"
                        if sudo distrobuilder build-incus "${opath}/images_yaml/${run_funct}.yaml" -o image.release=${version} -o image.architecture=${arch} -o image.variant=${variant} -o packages.manager=${manager} ${EXTRA_ARGS}; then
                            echo "Command succeeded"
                        fi
                    else
                        echo "sudo distrobuilder build-incus "${opath}/images_yaml/${run_funct}.yaml" -o image.architecture=${arch} -o image.variant=${variant} -o packages.manager=${manager} ${EXTRA_ARGS}"
                        if sudo distrobuilder build-incus "${opath}/images_yaml/${run_funct}.yaml" -o image.architecture=${arch} -o image.variant=${variant} -o packages.manager=${manager} ${EXTRA_ARGS}; then
                            echo "Command succeeded"
                        fi
                    fi
                    if [[ "$run_funct" == "gentoo" ]]; then
                        if [ "${variant}" = "openrc" ]; then
                            variant="cloud"
                        fi
                        [ "${arch}" = "amd64" ] && arch="x86_64"
                    elif [[ "$run_funct" == "fedora" ]]; then
                        [ "${arch}" = "x86_64" ] && arch="amd64"
                        [ "${arch}" = "aarch64" ] && arch="arm64"
                    fi
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
# build_or_list_images 镜像名字 镜像版本号
case "$run_funct" in
debian)
    build_or_list_images "buster bullseye bookworm trixie" "10 11 12 13"
    # "jessie stretch " "8 9"
    # "buster bullseye bookworm trixie" "10 11 12 13"
    ;;
ubuntu)
    build_or_list_images "mantic noble" "23.10 24.04"
    # "bionic focal jammy lunar" "18.04 20.04 22.04 23.04"
    # "mantic noble" "23.10 24.04"
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
    build_or_list_images "snapshot 21.02 22.03 23.05" "snapshot 21.02 22.03 23.05"
    ;;
oracle)
    build_or_list_images "7 8 9" "7 8 9"
    ;;
archlinux)
    build_or_list_images "current" "current"
    ;;
gentoo)
    build_or_list_images "current" "current"
    ;;
fedora)
    build_or_list_images "37 38 39" "37 38 39"
    ;;
*)
    echo "Invalid distribution specified."
    ;;
esac
