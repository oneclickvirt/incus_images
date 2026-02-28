#!/bin/bash
# 从 https://github.com/oneclickvirt/incus_images 获取

run_funct="${1:-debian}"
is_build_image="${2:-false}"
build_arch="${3:-amd64}"
zip_name_list=()
opath=$(pwd)
rm -rf *.tar.xz *.qcow2
ls

if command -v apt-get >/dev/null 2>&1; then
    if ! command -v sudo >/dev/null 2>&1; then
        apt-get install sudo -y
    fi
    if ! command -v zip >/dev/null 2>&1; then
        sudo apt-get install zip -y
    fi
    if ! command -v jq >/dev/null 2>&1; then
        sudo apt-get install jq -y
    fi
    if ! command -v snap >/dev/null 2>&1; then
        sudo apt-get install snapd -y
    fi
    if ! command -v umoci >/dev/null 2>&1; then
        sudo apt-get install umoci -y
    fi
    sudo systemctl start snapd
    sleep 10
    if ! command -v distrobuilder >/dev/null 2>&1; then
        sudo snap install distrobuilder --classic
    fi
    if ! command -v debootstrap >/dev/null 2>&1; then
        sudo apt-get install debootstrap -y
    fi
    sudo apt-get install -y btrfs-progs dosfstools qemu-kvm
fi

if [ "${build_arch}" == "x86_64" ] || [ "${build_arch}" == "amd64" ]; then
    build_arch="x86_64"
elif [ "${build_arch}" == "aarch64" ] || [ "${build_arch}" == "arm64" ]; then
    build_arch="arm64"
else
    echo "不支持的架构: ${build_arch}"
    exit 1
fi

build_or_list_kvm_images() {
    local versions=()
    local ver_nums=()
    local variants=()
    read -ra versions <<< "$1"
    read -ra ver_nums <<< "$2"
    read -ra variants <<< "$3"
    local architectures=("$build_arch")
    local len=${#versions[@]}
    for ((i = 0; i < len; i++)); do
        version=${versions[i]}
        ver_num=${ver_nums[i]}
        for arch in "${architectures[@]}"; do
            for variant in "${variants[@]}"; do
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
                elif [[ "$run_funct" == "opensuse" ]]; then
                    manager="zypper"
                elif [[ "$run_funct" == "gentoo" ]]; then
                    manager="portage"
                elif [[ "$run_funct" == "openwrt" ]]; then
                    manager="opkg"
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
                    if [[ "$version" == "9" ]]; then
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
                        EXTRA_ARGS="-o source.same_as=3.19"
                    fi
                elif [[ "$run_funct" == "fedora" || "$run_funct" == "openeuler" || "$run_funct" == "opensuse" ]]; then
                    [ "${arch}" = "amd64" ] && arch="x86_64"
                    [ "${arch}" = "arm64" ] && arch="aarch64"
                elif [[ "$run_funct" == "debian" ]]; then
                    [ "${arch}" = "x86_64" ] && arch="amd64"
                    [ "${arch}" = "aarch64" ] && arch="arm64"
                elif [[ "$run_funct" == "ubuntu" ]]; then
                    [ "${arch}" = "x86_64" ] && arch="amd64"
                    [ "${arch}" = "aarch64" ] && arch="arm64"
                    if [ "${arch}" != "amd64" ] && [ "${arch}" != "i386" ] && [ "${arch}" != "x86_64" ]; then
                        EXTRA_ARGS="-o source.url=http://ports.ubuntu.com/ubuntu-ports"
                    fi
                elif [[ "$run_funct" == "gentoo" ]]; then
                    [ "${arch}" = "x86_64" ] && arch="amd64"
                    [ "${arch}" = "aarch64" ] && arch="arm64"
                    if [ "${variant}" = "cloud" ]; then
                        EXTRA_ARGS="-o source.variant=openrc"
                    else
                        EXTRA_ARGS="-o source.variant=${variant}"
                    fi
                elif [[ "$run_funct" == "openwrt" ]]; then
                    [ "${arch}" = "amd64" ] && arch="x86_64"
                    [ "${arch}" = "arm64" ] && arch="aarch64"
                fi
                if [ "$is_build_image" == true ]; then
                    if command -v distrobuilder >/dev/null 2>&1; then
                        if [[ "$run_funct" != "archlinux" && "$run_funct" != "gentoo" ]]; then
                            echo "sudo distrobuilder build-incus "${opath}/images_yaml/${run_funct}.yaml" --vm -o image.release=${version} -o image.architecture=${arch} -o image.variant=${variant} -o packages.manager=${manager} ${EXTRA_ARGS}"
                            if sudo distrobuilder build-incus "${opath}/images_yaml/${run_funct}.yaml" --vm -o image.release=${version} -o image.architecture=${arch} -o image.variant=${variant} -o packages.manager=${manager} ${EXTRA_ARGS}; then
                                echo "Command succeeded"
                            fi
                        else
                            echo "sudo distrobuilder build-incus "${opath}/images_yaml/${run_funct}.yaml" --vm -o image.architecture=${arch} -o image.variant=${variant} -o packages.manager=${manager} ${EXTRA_ARGS}"
                            if sudo distrobuilder build-incus "${opath}/images_yaml/${run_funct}.yaml" --vm -o image.architecture=${arch} -o image.variant=${variant} -o packages.manager=${manager} ${EXTRA_ARGS}; then
                                echo "Command succeeded"
                            fi
                        fi
                    else
                        if [[ "$run_funct" != "archlinux" && "$run_funct" != "gentoo" ]]; then
                            echo "sudo $HOME/goprojects/bin/distrobuilder build-incus "${opath}/images_yaml/${run_funct}.yaml" --vm -o image.release=${version} -o image.architecture=${arch} -o image.variant=${variant} -o packages.manager=${manager} ${EXTRA_ARGS}"
                            if sudo $HOME/goprojects/bin/distrobuilder build-incus "${opath}/images_yaml/${run_funct}.yaml" --vm -o image.release=${version} -o image.architecture=${arch} -o image.variant=${variant} -o packages.manager=${manager} ${EXTRA_ARGS}; then
                                echo "Command succeeded"
                            fi
                        else
                            echo "sudo $HOME/goprojects/bin/distrobuilder build-incus "${opath}/images_yaml/${run_funct}.yaml" --vm -o image.architecture=${arch} -o image.variant=${variant} -o packages.manager=${manager} ${EXTRA_ARGS}"
                            if sudo $HOME/goprojects/bin/distrobuilder build-incus "${opath}/images_yaml/${run_funct}.yaml" --vm -o image.architecture=${arch} -o image.variant=${variant} -o packages.manager=${manager} ${EXTRA_ARGS}; then
                                echo "Command succeeded"
                            fi
                        fi
                    fi
                    if [[ "$run_funct" == "debian" || "$run_funct" == "ubuntu" || "$run_funct" == "gentoo" ]]; then
                        [ "${arch}" = "amd64" ] && arch="x86_64"
                    elif [[ "$run_funct" == "fedora" || "$run_funct" == "opensuse" || "$run_funct" == "alpine" || "$run_funct" == "oracle" || "$run_funct" == "archlinux" || "$run_funct" == "openwrt" ]]; then
                        [ "${arch}" = "aarch64" ] && arch="arm64"
                    elif [[ "$run_funct" == "almalinux" || "$run_funct" == "centos" || "$run_funct" == "rockylinux" ]]; then
                        [ "${arch}" = "aarch64" ] && arch="arm64"
                    fi
                    if [ -f incus.tar.xz ] && [ -f disk.qcow2 ]; then
                        zip "${run_funct}_${ver_num}_${version}_${arch}_${variant}_kvm.zip" incus.tar.xz disk.qcow2
                        rm -rf incus.tar.xz disk.qcow2
                    fi
                else
                    if [[ "$run_funct" == "debian" || "$run_funct" == "ubuntu" || "$run_funct" == "gentoo" ]]; then
                        [ "${arch}" = "amd64" ] && arch="x86_64"
                    elif [[ "$run_funct" == "fedora" || "$run_funct" == "opensuse" || "$run_funct" == "alpine" || "$run_funct" == "oracle" || "$run_funct" == "archlinux" || "$run_funct" == "openwrt" ]]; then
                        [ "${arch}" = "aarch64" ] && arch="arm64"
                    elif [[ "$run_funct" == "almalinux" || "$run_funct" == "centos" || "$run_funct" == "rockylinux" ]]; then
                        [ "${arch}" = "aarch64" ] && arch="arm64"
                    fi
                    zip_name_list+=("${run_funct}_${ver_num}_${version}_${arch}_${variant}_kvm.zip")
                fi
            done
        done
    done
    if [ "$is_build_image" == false ]; then
        echo "${zip_name_list[@]}"
    fi
}

case "$run_funct" in
debian)
    build_or_list_kvm_images "buster bullseye bookworm trixie" "10 11 12 13" "default cloud"
    ;;
ubuntu)
    build_or_list_kvm_images "bionic focal jammy lunar mantic noble" "18.04 20.04 22.04 23.04 23.10 24.04" "default cloud"
    ;;
archlinux)
    build_or_list_kvm_images "current" "current" "default cloud"
    ;;
centos)
    build_or_list_kvm_images "7 8-Stream 9-Stream" "7 8 9" "default cloud"
    ;;
kali)
    URL="https://raw.githubusercontent.com/lxc/lxc-ci/main/jenkins/jobs/image-kali.yaml"
    curl_output=$(curl -s "$URL" | awk '/name: release/{flag=1; next} /^$/{flag=0} flag && /^ *-/{if (!first) {printf "%s", $2; first=1} else {printf " %s", $2}}' | sed 's/"//g')
    build_or_list_kvm_images "$curl_output" "$curl_output" "default cloud"
    ;;
almalinux)
    URL="https://raw.githubusercontent.com/lxc/lxc-ci/main/jenkins/jobs/image-almalinux.yaml"
    curl_output=$(curl -s "$URL" | awk '/name: release/{flag=1; next} /^$/{flag=0} flag && /^ *-/{if (!first) {printf "%s", $2; first=1} else {printf " %s", $2}}' | sed 's/"//g')
    build_or_list_kvm_images "$curl_output" "$curl_output" "default cloud"
    ;;
rockylinux)
    URL="https://raw.githubusercontent.com/lxc/lxc-ci/main/jenkins/jobs/image-rockylinux.yaml"
    curl_output=$(curl -s "$URL" | awk '/name: release/{flag=1; next} /^$/{flag=0} flag && /^ *-/{if (!first) {printf "%s", $2; first=1} else {printf " %s", $2}}' | sed 's/"//g')
    build_or_list_kvm_images "$curl_output" "$curl_output" "default cloud"
    ;;
alpine)
    URL="https://raw.githubusercontent.com/lxc/lxc-ci/main/jenkins/jobs/image-alpine.yaml"
    curl_output=$(curl -s "$URL" | awk '/name: release/{flag=1; next} /^$/{flag=0} flag && /^ *-/{if (!first) {printf "%s", $2; first=1} else {printf " %s", $2}}' | sed 's/"//g')
    build_or_list_kvm_images "$curl_output" "$curl_output" "default cloud"
    ;;
oracle)
    URL="https://raw.githubusercontent.com/lxc/lxc-ci/main/jenkins/jobs/image-oracle.yaml"
    curl_output=$(curl -s "$URL" | awk '/name: release/{flag=1; next} /^$/{flag=0} flag && /^ *-/{if (!first) {printf "%s", $2; first=1} else {printf " %s", $2}}' | sed 's/"//g')
    build_or_list_kvm_images "$curl_output" "$curl_output" "default cloud"
    ;;
fedora)
    URL="https://raw.githubusercontent.com/lxc/lxc-ci/main/jenkins/jobs/image-fedora.yaml"
    curl_output=$(curl -s "$URL" | awk '/name: release/{flag=1; next} /^$/{flag=0} flag && /^ *-/{if (!first) {printf "%s", $2; first=1} else {printf " %s", $2}}' | sed 's/"//g')
    build_or_list_kvm_images "$curl_output" "$curl_output" "default cloud"
    ;;
opensuse)
    URL="https://raw.githubusercontent.com/lxc/lxc-ci/main/jenkins/jobs/image-opensuse.yaml"
    curl_output=$(curl -s "$URL" | awk '/name: release/{flag=1; next} /^$/{flag=0} flag && /^ *-/{if (!first) {printf "%s", $2; first=1} else {printf " %s", $2}}' | sed 's/"//g')
    build_or_list_kvm_images "$curl_output" "$curl_output" "default cloud"
    ;;
openeuler)
    URL="https://raw.githubusercontent.com/lxc/lxc-ci/main/jenkins/jobs/image-openeuler.yaml"
    curl_output=$(curl -s "$URL" | awk '/name: release/{flag=1; next} /^$/{flag=0} flag && /^ *-/{if (!first) {printf "%s", $2; first=1} else {printf " %s", $2}}' | sed 's/"//g')
    build_or_list_kvm_images "$curl_output" "$curl_output" "default cloud"
    ;;
gentoo)
    URL="https://raw.githubusercontent.com/lxc/lxc-ci/main/jenkins/jobs/image-gentoo.yaml"
    curl_output=$(curl -s "$URL" | awk '/name: release/{flag=1; next} /^$/{flag=0} flag && /^ *-/{if (!first) {printf "%s", $2; first=1} else {printf " %s", $2}}' | sed 's/"//g')
    build_or_list_kvm_images "$curl_output" "$curl_output" "default cloud"
    ;;
openwrt)
    URL="https://raw.githubusercontent.com/lxc/lxc-ci/main/jenkins/jobs/image-openwrt.yaml"
    curl_output=$(curl -s "$URL" | awk '/name: release/{flag=1; next} /^$/{flag=0} flag && /^ *-/{if (!first) {printf "%s", $2; first=1} else {printf " %s", $2}}' | sed 's/"//g')
    build_or_list_kvm_images "$curl_output" "$curl_output" "default cloud"
    ;;
*)
    echo "Invalid distribution specified."
    ;;
esac
