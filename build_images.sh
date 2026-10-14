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
    if ! command -v distrobuilder >/dev/null 2>&1; then
        bash .github/scripts/install_distrobuilder.sh
    fi
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
    local -a EXTRA_ARGS=() BUILDER_CMD=()
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
                EXTRA_ARGS=()
                if [[ "$run_funct" == "centos" ]]; then
                    [ "${arch}" = "amd64" ] && arch="x86_64"
                    [ "${arch}" = "arm64" ] && arch="aarch64"
                    if [ "$version" = "7" ] && [ "${arch}" != "amd64" ] && [ "${arch}" != "x86_64" ]; then
                        EXTRA_ARGS=(-o source.url=http://mirror.math.princeton.edu/pub/centos-altarch/ -o source.skip_verification=true)
                    fi
                    if [ "$version" = "8-Stream" ] || [ "$version" = "9-Stream" ] || [ "$version" = "10-Stream" ]; then
                        EXTRA_ARGS+=(-o source.variant=boot)
                    fi
                    if [ "$version" = "9-Stream" ] || [ "$version" = "10-Stream" ]; then
                        # The CentOS downloader appends the stream path itself.
                        EXTRA_ARGS+=(-o source.url=https://mirror.stream.centos.org/)
                    fi
                elif [[ "$run_funct" == "rockylinux" ]]; then
                    [ "${arch}" = "amd64" ] && arch="x86_64"
                    [ "${arch}" = "arm64" ] && arch="aarch64"
                    EXTRA_ARGS=(-o source.variant=boot)
                elif [[ "$run_funct" == "almalinux" ]]; then
                    [ "${arch}" = "amd64" ] && arch="x86_64"
                    [ "${arch}" = "arm64" ] && arch="aarch64"
                    EXTRA_ARGS=(-o source.variant=boot)
                elif [[ "$run_funct" == "oracle" ]]; then
                    [ "${arch}" = "amd64" ] && arch="x86_64"
                    [ "${arch}" = "arm64" ] && arch="aarch64"
                    if [[ "$version" == "8" || "$version" == "9" || "$version" == "10" ]]; then
                        EXTRA_ARGS=(-o source.url=https://yum.oracle.com/ISOS/OracleLinux)
                    fi
                elif [[ "$run_funct" == "archlinux" ]]; then
                    [ "${arch}" = "amd64" ] && arch="x86_64"
                    [ "${arch}" = "arm64" ] && arch="aarch64"
                    if [ "${arch}" != "amd64" ] && [ "${arch}" != "i386" ] && [ "${arch}" != "x86_64" ]; then
                        EXTRA_ARGS=(-o source.url=https://ca.us.mirror.archlinuxarm.org)
                    fi
                elif [[ "$run_funct" == "alpine" ]]; then
                    [ "${arch}" = "amd64" ] && arch="x86_64"
                    [ "${arch}" = "arm64" ] && arch="aarch64"
                    if [ "${version}" = "edge" ]; then
                        EXTRA_ARGS=(-o source.same_as=3.21)
                    fi
                elif [[ "$run_funct" == "fedora" || "$run_funct" == "openeuler" || "$run_funct" == "opensuse" ]]; then
                    [ "${arch}" = "amd64" ] && arch="x86_64"
                    [ "${arch}" = "arm64" ] && arch="aarch64"
                elif [[ "$run_funct" == "gentoo" ]]; then
                    [ "${arch}" = "x86_64" ] && arch="amd64"
                    [ "${arch}" = "aarch64" ] && arch="arm64"
                    if [ "${variant}" = "cloud" ]; then
                        EXTRA_ARGS=(-o source.variant=openrc)
                    else
                        EXTRA_ARGS=(-o "source.variant=${variant}")
                    fi
                elif [[ "$run_funct" == "debian" ]]; then
                    [ "${arch}" = "x86_64" ] && arch="amd64"
                    [ "${arch}" = "aarch64" ] && arch="arm64"
                elif [[ "$run_funct" == "ubuntu" ]]; then
                    [ "${arch}" = "x86_64" ] && arch="amd64"
                    [ "${arch}" = "aarch64" ] && arch="arm64"
                    if [ "${arch}" != "amd64" ] && [ "${arch}" != "i386" ] && [ "${arch}" != "x86_64" ]; then
                        EXTRA_ARGS=(-o source.url=http://ports.ubuntu.com/ubuntu-ports)
                    fi
                fi
                if [ "$is_build_image" == true ]; then
                    rm -f -- incus.tar.xz lxd.tar.xz rootfs.squashfs rootfs.tar.xz disk.qcow2 disk_compressed.qcow2
                    builder_bin=$(command -v distrobuilder) || { echo "distrobuilder is not installed on this runner" >&2; return 1; }
                    BUILDER_CMD=(sudo "$builder_bin" build-incus "${opath}/images_yaml/${run_funct}.yaml")
                    if [[ "$run_funct" != "gentoo" && "$run_funct" != "archlinux" ]]; then
                        BUILDER_CMD+=(-o "image.release=${version}")
                    fi
                    BUILDER_CMD+=(-o "image.architecture=${arch}" -o "image.variant=${variant}")
                    if [[ "$run_funct" != "gentoo" ]]; then
                        BUILDER_CMD+=(-o "packages.manager=${manager}")
                    fi
                    BUILDER_CMD+=("${EXTRA_ARGS[@]}")
                    printf 'Running:'
                    printf ' %q' "${BUILDER_CMD[@]}"
                    printf '\n'
                    if python3 "${opath}/.github/scripts/build_image_retry.py" -- "${BUILDER_CMD[@]}"; then
                        echo "Command succeeded"
                    else
                        echo "Image builder failed; preserving the previous release" >&2
                        return 1
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
