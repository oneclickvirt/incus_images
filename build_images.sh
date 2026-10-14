#!/bin/bash
set -eo pipefail
# 从 https://github.com/oneclickvirt/incus_images 获取

run_funct="${1:-debian}"
is_build_image="${2:-false}"
build_arch="${3:-amd64}"
zip_name_list=()
opath=$(pwd)
selected_images=0
[[ "$is_build_image" == true || "$is_build_image" == false ]] || { echo "Invalid build mode" >&2; exit 1; }
[[ "$build_arch" =~ ^(amd64|x86_64|arm64|aarch64)$ ]] || { echo "Invalid image architecture" >&2; exit 1; }
[[ "${CI_IMAGE_RELEASES:-}" =~ ^[A-Za-z0-9._\ -]*$ ]] || { echo "Invalid release selector" >&2; exit 1; }
if [[ "$is_build_image" == true ]]; then rm -f -- incus.tar.xz lxd.tar.xz rootfs.squashfs rootfs.tar.xz; fi
if [[ "$is_build_image" == true ]]; then ls; fi
# 检查并安装依赖工具
if [ "$is_build_image" == true ] && command -v apt-get >/dev/null 2>&1; then
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
    if ! command -v umoci >/dev/null 2>&1; then
        sudo apt-get install umoci -y
    fi
    uname_output=$(uname -a)
    # if [[ $uname_output != *ARM* && $uname_output != *arm* && $uname_output != *aarch* ]]; then
    if ! command -v snap >/dev/null 2>&1; then
        sudo apt-get install snapd -y
    fi
    sudo systemctl start snapd
    sleep 10
    if ! command -v distrobuilder >/dev/null 2>&1; then
        sudo snap install distrobuilder --classic
    fi
    # else
    #     # if ! command -v snap >/dev/null 2>&1; then
    #     #     sudo apt-get install snapd -y
    #     # fi
    #     # sudo systemctl start snapd
    #     # if ! command -v distrobuilder >/dev/null 2>&1; then
    #     #     sudo snap install distrobuilder --classic
    #     # fi
    #     if ! command -v distrobuilder >/dev/null 2>&1; then
    #         $HOME/goprojects/bin/distrobuilder --version
    #     fi
    #     if [ $? -ne 0 ]; then
    #         sudo apt-get install build-essential -y
    #         export CGO_ENABLED=1
    #         export CC=gcc
    #         if [ "${build_arch}" == "x86_64" ] || [ "${build_arch}" == "amd64" ]; then
    #             GO_ARCH="amd64"
    #         elif [ "${build_arch}" == "aarch64" ] || [ "${build_arch}" == "arm64" ]; then
    #             GO_ARCH="arm64"
    #         else
    #             echo "不支持的架构: ${build_arch}"
    #             exit 1
    #         fi
    #         GO_VERSION="1.22.7"
    #         GO_URL="https://go.dev/dl/go${GO_VERSION}.linux-${GO_ARCH}.tar.gz"
    #         sudo wget $GO_URL
    #         sudo chmod 777 go${GO_VERSION}.linux-${GO_ARCH}.tar.gz
    #         sudo rm -rf /usr/local/go && sudo tar -C /usr/local -xzf go${GO_VERSION}.linux-${GO_ARCH}.tar.gz
    #         sudo go version
    #         export GOROOT=/usr/local/go
    #         export PATH=$GOROOT/bin:$PATH
    #         export GOPATH=$HOME/goprojects/
    #         sudo go version
    #         sudo apt-get install -q -y debootstrap rsync gpg squashfs-tools git make
    #         sudo git config --global user.name "daily-update"
    #         sudo git config --global user.email "tg@spiritlhl.top"
    #         sudo mkdir -p $HOME/go/src/github.com/lxc/
    #         cd $HOME/go/src/github.com/lxc/
    #         sudo git clone https://github.com/lxc/distrobuilder
    #         cd ./distrobuilder
    #         sudo make
    #         export PATH=$HOME/goprojects/bin/distrobuilder:$PATH
    #         echo $PATH
    #         find $HOME -name distrobuilder -type f 2>/dev/null
    #         $HOME/goprojects/bin/distrobuilder --version
    #     fi
    #     # wget https://api.ilolicon.com/distrobuilder.deb
    #     # dpkg -i distrobuilder.deb
    # fi
    if ! command -v debootstrap >/dev/null 2>&1; then
        sudo apt-get install debootstrap -y
    fi
fi
if [ "${build_arch}" == "x86_64" ] || [ "${build_arch}" == "amd64" ]; then
    build_arch="x86_64"
elif [ "${build_arch}" == "aarch64" ] || [ "${build_arch}" == "arm64" ]; then
    build_arch="arm64"
else
    echo "不支持的架构: ${build_arch}"
    exit 1
fi
# 构建或列出不同发行版的镜像
build_or_list_images() {
    local versions=()
    local ver_nums=()
    local variants=()
    read -ra versions <<< "$1"
    read -ra ver_nums <<< "$2"
    read -ra variants <<< "$3"
    if [[ -n "${CI_IMAGE_VARIANTS:-}" ]]; then
        local requested=() available=" ${variants[*]} "
        read -ra requested <<< "$CI_IMAGE_VARIANTS"
        for selected in "${requested[@]}"; do
            [[ "$available" == *" $selected "* ]] || { echo "Unknown requested image variant" >&2; return 1; }
        done
        variants=("${requested[@]}")
    fi
    local architectures=("$build_arch")
    local len=${#versions[@]}
    if (( len == 0 )); then echo "No image releases were obtained from the configured source" >&2; return 1; fi
    for ((i = 0; i < len; i++)); do
        version=${versions[i]}
        ver_num=${ver_nums[i]}
        if [[ -n "${CI_IMAGE_RELEASES:-}" && " ${CI_IMAGE_RELEASES} " != *" ${version} "* && " ${CI_IMAGE_RELEASES} " != *" ${ver_num} "* ]]; then
            continue
        fi
        for arch in "${architectures[@]}"; do
            for variant in "${variants[@]}"; do
                selected_images=$((selected_images + 1))
# apk apt dnf egoportage opkg pacman portage yum equo xbps zypper luet slackpkg
                if [[ "$run_funct" == "centos" || "$run_funct" == "fedora" || "$run_funct" == "openeuler" ]]; then
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
                    if [[ "$version" == "snapshot" || "$version" =~ ^([0-9]+)\. ]]; then
                        if [[ "$version" == "snapshot" ]] || (( 10#${BASH_REMATCH[1]} >= 25 )); then
                            manager="apk"
                        fi
                    fi
                elif [[ "$run_funct" == "gentoo" ]]; then
                    manager="portage"
                elif [[ "$run_funct" == "opensuse" ]]; then
                    manager="zypper"
                else
                    echo "Unsupported distribution: $run_funct"
                    exit 1
                fi
                EXTRA_ARGS=""
                if [[ "$run_funct" == "centos" ]]; then
                    [ "${arch}" = "amd64" ] && arch="x86_64"
                    [ "${arch}" = "arm64" ] && arch="aarch64"
                    if [ "$version" = "7" ] && [ "${arch}" != "amd64" ] && [ "${arch}" != "x86_64" ]; then
                        EXTRA_ARGS="-o source.url=http://mirror.math.princeton.edu/pub/centos-altarch/ -o source.skip_verification=true"
                    fi
                    if [ "$version" = "8-Stream" ] || [ "$version" = "9-Stream" ]; then
                        EXTRA_ARGS="${EXTRA_ARGS} -o source.variant=boot"
                    fi
                    if [ "$version" = "9-Stream" ]; then
                        EXTRA_ARGS="${EXTRA_ARGS} -o source.url=https://mirror1.hs-esslingen.de/pub/Mirrors/centos-stream"
                    fi
                elif [[ "$run_funct" == "rockylinux" ]]; then
                    [ "${arch}" = "amd64" ] && arch="x86_64"
                    [ "${arch}" = "arm64" ] && arch="aarch64"
                    EXTRA_ARGS="-o source.variant=boot"
                elif [[ "$run_funct" == "almalinux" ]]; then
                    [ "${arch}" = "amd64" ] && arch="x86_64"
                    [ "${arch}" = "arm64" ] && arch="aarch64"
                    EXTRA_ARGS="-o source.variant=boot"
                elif [[ "$run_funct" == "oracle" ]]; then
                    [ "${arch}" = "amd64" ] && arch="x86_64"
                    [ "${arch}" = "arm64" ] && arch="aarch64"
                    if [[ "$version" == "8" || "$version" == "9" || "$version" == "10" ]]; then
                        EXTRA_ARGS="-o source.url=https://yum.oracle.com/ISOS/OracleLinux"
                    fi
                elif [[ "$run_funct" == "archlinux" ]]; then
                    [ "${arch}" = "amd64" ] && arch="x86_64"
                    [ "${arch}" = "arm64" ] && arch="aarch64"
                    if [ "${arch}" != "amd64" ] && [ "${arch}" != "i386" ] && [ "${arch}" != "x86_64" ]; then
                        EXTRA_ARGS="-o source.url=http://os.archlinuxarm.org"
                    fi
                elif [[ "$run_funct" == "alpine" ]]; then
                    [ "${arch}" = "amd64" ] && arch="x86_64"
                    [ "${arch}" = "arm64" ] && arch="aarch64"
                    if [ "${version}" = "edge" ]; then
                        EXTRA_ARGS="-o source.same_as=3.21"
                    fi
                elif [[ "$run_funct" == "fedora" || "$run_funct" == "openeuler" || "$run_funct" == "opensuse" ]]; then
                    [ "${arch}" = "amd64" ] && arch="x86_64"
                    [ "${arch}" = "arm64" ] && arch="aarch64"
                elif [[ "$run_funct" == "gentoo" ]]; then
                    [ "${arch}" = "x86_64" ] && arch="amd64"
                    [ "${arch}" = "aarch64" ] && arch="arm64"
                    if [ "${variant}" = "cloud" ]; then
                        EXTRA_ARGS="-o source.variant=openrc"
                    else
                        EXTRA_ARGS="-o source.variant=${variant}"
                    fi
                elif [[ "$run_funct" == "debian" ]]; then
                    [ "${arch}" = "x86_64" ] && arch="amd64"
                    [ "${arch}" = "aarch64" ] && arch="arm64"
                elif [[ "$run_funct" == "ubuntu" ]]; then
                    [ "${arch}" = "x86_64" ] && arch="amd64"
                    [ "${arch}" = "aarch64" ] && arch="arm64"
                    if [ "${arch}" != "amd64" ] && [ "${arch}" != "i386" ] && [ "${arch}" != "x86_64" ]; then
                        EXTRA_ARGS="-o source.url=http://ports.ubuntu.com/ubuntu-ports"
                    fi
                fi
                if [ "$is_build_image" == true ]; then
                    rm -f -- incus.tar.xz lxd.tar.xz rootfs.squashfs rootfs.tar.xz disk.qcow2 disk_compressed.qcow2
                    if command -v distrobuilder >/dev/null 2>&1; then
                        if [[ "$run_funct" == "gentoo" ]]; then
                            echo "sudo distrobuilder build-incus "${opath}/images_yaml/${run_funct}.yaml" -o image.architecture=${arch} -o image.variant=${variant} ${EXTRA_ARGS}"
                            if sudo distrobuilder build-incus "${opath}/images_yaml/${run_funct}.yaml" -o image.architecture=${arch} -o image.variant=${variant} ${EXTRA_ARGS}; then
                                echo "Command succeeded"
                            else
                                echo "Image builder failed; preserving the previous release" >&2
                                return 1
                            fi
                        elif [[ "$run_funct" != "archlinux" ]]; then
                            echo "sudo distrobuilder build-incus "${opath}/images_yaml/${run_funct}.yaml" -o image.release=${version} -o image.architecture=${arch} -o image.variant=${variant} -o packages.manager=${manager} ${EXTRA_ARGS}"
                            if sudo distrobuilder build-incus "${opath}/images_yaml/${run_funct}.yaml" -o image.release=${version} -o image.architecture=${arch} -o image.variant=${variant} -o packages.manager=${manager} ${EXTRA_ARGS}; then
                                echo "Command succeeded"
                            else
                                echo "Image builder failed; preserving the previous release" >&2
                                return 1
                            fi
                        else
                            echo "sudo distrobuilder build-incus "${opath}/images_yaml/${run_funct}.yaml" -o image.architecture=${arch} -o image.variant=${variant} -o packages.manager=${manager} ${EXTRA_ARGS}"
                            if sudo distrobuilder build-incus "${opath}/images_yaml/${run_funct}.yaml" -o image.architecture=${arch} -o image.variant=${variant} -o packages.manager=${manager} ${EXTRA_ARGS}; then
                                echo "Command succeeded"
                            else
                                echo "Image builder failed; preserving the previous release" >&2
                                return 1
                            fi
                        fi
                    else
                        if [[ "$run_funct" == "gentoo" ]]; then
                            echo "sudo $HOME/goprojects/bin/distrobuilder build-incus "${opath}/images_yaml/${run_funct}.yaml" -o image.architecture=${arch} -o image.variant=${variant} ${EXTRA_ARGS}"
                            if sudo $HOME/goprojects/bin/distrobuilder build-incus "${opath}/images_yaml/${run_funct}.yaml" -o image.architecture=${arch} -o image.variant=${variant} ${EXTRA_ARGS}; then
                                echo "Command succeeded"
                            else
                                echo "Image builder failed; preserving the previous release" >&2
                                return 1
                            fi
                        elif [[ "$run_funct" != "archlinux" ]]; then
                            echo "sudo $HOME/goprojects/bin/distrobuilder build-incus "${opath}/images_yaml/${run_funct}.yaml" -o image.release=${version} -o image.architecture=${arch} -o image.variant=${variant} -o packages.manager=${manager} ${EXTRA_ARGS}"
                            if sudo $HOME/goprojects/bin/distrobuilder build-incus "${opath}/images_yaml/${run_funct}.yaml" -o image.release=${version} -o image.architecture=${arch} -o image.variant=${variant} -o packages.manager=${manager} ${EXTRA_ARGS}; then
                                echo "Command succeeded"
                            else
                                echo "Image builder failed; preserving the previous release" >&2
                                return 1
                            fi
                        else
                            echo "sudo $HOME/goprojects/bin/distrobuilder build-incus "${opath}/images_yaml/${run_funct}.yaml" -o image.architecture=${arch} -o image.variant=${variant} -o packages.manager=${manager} ${EXTRA_ARGS}"
                            if sudo $HOME/goprojects/bin/distrobuilder build-incus "${opath}/images_yaml/${run_funct}.yaml" -o image.architecture=${arch} -o image.variant=${variant} -o packages.manager=${manager} ${EXTRA_ARGS}; then
                                echo "Command succeeded"
                            else
                                echo "Image builder failed; preserving the previous release" >&2
                                return 1
                            fi
                        fi
                    fi
                    # 强制设置架构名字
                    if [[ "$run_funct" == "gentoo" || "$run_funct" == "debian" || "$run_funct" == "ubuntu" ]]; then
                        [ "${arch}" = "amd64" ] && arch="x86_64"
                    elif [[ "$run_funct" == "fedora" || "$run_funct" == "openeuler" || "$run_funct" == "opensuse" || "$run_funct" == "alpine" || "$run_funct" == "oracle" || "$run_funct" == "archlinux" ]]; then
                        [ "${arch}" = "aarch64" ] && arch="arm64"
                    elif [[ "$run_funct" == "almalinux" || "$run_funct" == "centos" || "$run_funct" == "rockylinux" ]]; then
                        [ "${arch}" = "aarch64" ] && arch="arm64"
                    fi
                    if [ -f incus.tar.xz ] && [ -f rootfs.squashfs ]; then
                        rm -f -- "${run_funct}_${ver_num}_${version}_${arch}_${variant}.zip"
                        zip "${run_funct}_${ver_num}_${version}_${arch}_${variant}.zip" incus.tar.xz rootfs.squashfs
                        rm -f incus.tar.xz rootfs.squashfs
                    else
                        echo "Missing Incus image artifacts" >&2
                        return 1
                    fi
                else
                    # 强制设置架构名字
                    if [[ "$run_funct" == "gentoo" || "$run_funct" == "debian" || "$run_funct" == "ubuntu" ]]; then
                        [ "${arch}" = "amd64" ] && arch="x86_64"
                    elif [[ "$run_funct" == "fedora" || "$run_funct" == "openeuler" || "$run_funct" == "opensuse" || "$run_funct" == "alpine" || "$run_funct" == "oracle" || "$run_funct" == "archlinux" ]]; then
                        [ "${arch}" = "aarch64" ] && arch="arm64"
                    elif [[ "$run_funct" == "almalinux" || "$run_funct" == "centos" || "$run_funct" == "rockylinux" ]]; then
                        [ "${arch}" = "aarch64" ] && arch="arm64"
                    fi
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
# build_or_list_images 镜像名字 镜像版本号 variants的值
if [[ -f "${CI_IMAGE_CATALOG:-.github/image-catalog.json}" ]]; then
    catalog_selection=$(python3 .github/scripts/image_catalog.py selection --catalog "${CI_IMAGE_CATALOG:-.github/image-catalog.json}" --distro "$run_funct" --arch "$build_arch") || exit 1
    mapfile -t catalog_axes <<< "$catalog_selection"
    [[ ${#catalog_axes[@]} == 3 ]] || { echo "Invalid validated catalog" >&2; exit 1; }
    build_or_list_images "${catalog_axes[0]}" "${catalog_axes[1]}" "${catalog_axes[2]}"
else
case "$run_funct" in
debian)
    build_or_list_images "buster bullseye bookworm trixie" "10 11 12 13" "default cloud"
    ;;
ubuntu)
    build_or_list_images "bionic focal jammy lunar mantic noble" "18.04 20.04 22.04 23.04 23.10 24.04" "default cloud"
    ;;
kali)
    build_or_list_images "kali-rolling" "latest" "default cloud"
    ;;
archlinux)
    build_or_list_images "current" "current" "default cloud"
    ;;
gentoo)
    build_or_list_images "current" "current" "cloud systemd openrc"
    ;;
centos)
    build_or_list_images "7 8-Stream 9-Stream" "7 8 9" "default cloud"
    ;;
almalinux)
    URL="https://raw.githubusercontent.com/lxc/lxc-ci/main/jenkins/jobs/image-almalinux.yaml"
    curl_output=$(curl -s "$URL" | awk '/name: release/{flag=1; next} /^$/{flag=0} flag && /^ *-/{if (!first) {printf "%s", $2; first=1} else {printf " %s", $2}}' | sed 's/"//g')
    build_or_list_images "$curl_output" "$curl_output" "default cloud"
    ;;
rockylinux)
    URL="https://raw.githubusercontent.com/lxc/lxc-ci/main/jenkins/jobs/image-rockylinux.yaml"
    curl_output=$(curl -s "$URL" | awk '/name: release/{flag=1; next} /^$/{flag=0} flag && /^ *-/{if (!first) {printf "%s", $2; first=1} else {printf " %s", $2}}' | sed 's/"//g')
    build_or_list_images "$curl_output" "$curl_output" "default cloud"
    ;;
alpine)
    URL="https://raw.githubusercontent.com/lxc/lxc-ci/main/jenkins/jobs/image-alpine.yaml"
    curl_output=$(curl -s "$URL" | awk '/name: release/{flag=1; next} /^$/{flag=0} flag && /^ *-/{if (!first) {printf "%s", $2; first=1} else {printf " %s", $2}}' | sed 's/"//g')
    build_or_list_images "$curl_output" "$curl_output" "default cloud"
    ;;
openwrt)
    URL="https://raw.githubusercontent.com/lxc/lxc-ci/main/jenkins/jobs/image-openwrt.yaml"
    curl_output=$(curl -s "$URL" | awk '/name: release/{flag=1; next} /^$/{flag=0} flag && /^ *-/{if (!first) {printf "%s", $2; first=1} else {printf " %s", $2}}' | sed 's/"//g')
    build_or_list_images "$curl_output" "$curl_output" "default cloud"
    ;;
oracle)
    URL="https://raw.githubusercontent.com/lxc/lxc-ci/main/jenkins/jobs/image-oracle.yaml"
    curl_output=$(curl -s "$URL" | awk '/name: release/{flag=1; next} /^$/{flag=0} flag && /^ *-/{if (!first) {printf "%s", $2; first=1} else {printf " %s", $2}}' | sed 's/"//g')
    build_or_list_images "$curl_output" "$curl_output" "default cloud"
    ;;
fedora)
    URL="https://raw.githubusercontent.com/lxc/lxc-ci/main/jenkins/jobs/image-fedora.yaml"
    curl_output=$(curl -s "$URL" | awk '/name: release/{flag=1; next} /^$/{flag=0} flag && /^ *-/{if (!first) {printf "%s", $2; first=1} else {printf " %s", $2}}' | sed 's/"//g')
    build_or_list_images "$curl_output" "$curl_output" "default cloud"
    ;;
opensuse)
    URL="https://raw.githubusercontent.com/lxc/lxc-ci/main/jenkins/jobs/image-opensuse.yaml"
    curl_output=$(curl -s "$URL" | awk '/name: release/{flag=1; next} /^$/{flag=0} flag && /^ *-/{if (!first) {printf "%s", $2; first=1} else {printf " %s", $2}}' | sed 's/"//g')
    build_or_list_images "$curl_output" "$curl_output" "default cloud"
    ;;
openeuler)
    URL="https://raw.githubusercontent.com/lxc/lxc-ci/main/jenkins/jobs/image-openeuler.yaml"
    curl_output=$(curl -s "$URL" | awk '/name: release/{flag=1; next} /^$/{flag=0} flag && /^ *-/{if (!first) {printf "%s", $2; first=1} else {printf " %s", $2}}' | sed 's/"//g')
    build_or_list_images "$curl_output" "$curl_output" "default cloud"
    ;;
*)
    echo "Invalid distribution specified." >&2
    exit 1
    ;;
esac
fi

(( selected_images > 0 )) || { echo "No images match the requested release" >&2; exit 1; }
