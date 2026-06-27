#!/bin/bash
# 从 https://github.com/oneclickvirt/incus_images 获取

run_funct="${1:-debian}"
is_build_image="${2:-false}"
build_arch="${3:-amd64}"
zip_name_list=()
opath=$(pwd)
rm -rf *.tar.xz *.qcow2
if [ "$is_build_image" == true ]; then
    ls
fi

if [[ "$run_funct" == "kali" || "$run_funct" == "oracle" ]]; then
    echo "KVM images for ${run_funct} are disabled because images_yaml/${run_funct}.yaml lacks complete VM boot support." >&2
    exit 0
fi

if [ "$is_build_image" == true ] && command -v apt-get >/dev/null 2>&1; then
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

requires_secureboot_disabled() {
    case "$run_funct" in
    alpine | archlinux | gentoo | openwrt)
        return 0
        ;;
    *)
        return 1
        ;;
    esac
}

patch_incus_metadata_for_kvm() {
    local image_name="$1"
    local temp_dir=""

    if ! requires_secureboot_disabled; then
        return 0
    fi

    temp_dir=$(mktemp -d)
    if ! tar -C "$temp_dir" -xf incus.tar.xz; then
        rm -rf "$temp_dir"
        echo "Failed to unpack incus.tar.xz for ${image_name}"
        return 1
    fi

    if [ ! -f "$temp_dir/metadata.yaml" ]; then
        rm -rf "$temp_dir"
        echo "metadata.yaml not found in incus.tar.xz for ${image_name}"
        return 1
    fi

    awk '
        BEGIN { done = 0 }
        /^[[:space:]]*requirements\.secureboot:[[:space:]]*/ {
            print "  requirements.secureboot: \"false\""
            done = 1
            next
        }
        /^properties:[[:space:]]*$/ && done == 0 {
            print
            print "  requirements.secureboot: \"false\""
            done = 1
            next
        }
        { print }
        END {
            if (done == 0) {
                print "properties:"
                print "  requirements.secureboot: \"false\""
            }
        }
    ' "$temp_dir/metadata.yaml" > "$temp_dir/metadata.yaml.new"
    mv "$temp_dir/metadata.yaml.new" "$temp_dir/metadata.yaml"

    if [ -d "$temp_dir/templates" ]; then
        if ! tar -C "$temp_dir" -cJf incus.tar.xz metadata.yaml templates; then
            rm -rf "$temp_dir"
            echo "Failed to repack incus.tar.xz for ${image_name}"
            return 1
        fi
    elif ! tar -C "$temp_dir" -cJf incus.tar.xz metadata.yaml; then
        rm -rf "$temp_dir"
        echo "Failed to repack incus.tar.xz for ${image_name}"
        return 1
    fi

    rm -rf "$temp_dir"
}

validate_vm_artifacts() {
    local image_name="$1"
    local total_size=0

    if [ ! -s incus.tar.xz ] || [ ! -s disk.qcow2 ]; then
        echo "Missing VM artifacts for ${image_name}"
        return 1
    fi

    total_size=$(($(stat -c%s incus.tar.xz) + $(stat -c%s disk.qcow2)))
    if [ "$total_size" -le $((10 * 1024 * 1024)) ]; then
        echo "Artifacts for ${image_name} are too small to be a valid VM image"
        return 1
    fi

    if ! tar -tf incus.tar.xz metadata.yaml >/dev/null 2>&1; then
        echo "incus.tar.xz for ${image_name} does not contain metadata.yaml"
        return 1
    fi

    if ! tar -xOf incus.tar.xz metadata.yaml 2>/dev/null | grep -q '^architecture:'; then
        echo "metadata.yaml for ${image_name} is missing architecture"
        return 1
    fi

    local template_files=""
    template_files=$(tar -xOf incus.tar.xz metadata.yaml 2>/dev/null | sed -n 's/^[[:space:]]*template:[[:space:]]*//p' | tr -d "\"'" | awk '{print $1}' | sort -u)
    if [ -n "$template_files" ]; then
        local tpl=""
        while IFS= read -r tpl; do
            [ -n "$tpl" ] || continue
            if ! tar -tf incus.tar.xz "templates/${tpl}" >/dev/null 2>&1; then
                echo "metadata.yaml for ${image_name} references missing template: templates/${tpl}"
                return 1
            fi
        done <<< "$template_files"
    fi

    if requires_secureboot_disabled; then
        if ! tar -xOf incus.tar.xz metadata.yaml 2>/dev/null | grep -q '^[[:space:]]*requirements\.secureboot:[[:space:]]*["'\'']*false["'\'']*[[:space:]]*$'; then
            echo "metadata.yaml for ${image_name} must declare requirements.secureboot=false"
            return 1
        fi
    fi

    if command -v qemu-img >/dev/null 2>&1; then
        if ! qemu-img info disk.qcow2 >/dev/null 2>&1; then
            echo "qemu-img cannot read disk.qcow2 for ${image_name}"
            return 1
        fi

        if command -v jq >/dev/null 2>&1; then
            local disk_info=""
            local disk_format=""
            local virtual_size=""

            disk_info=$(qemu-img info --output=json disk.qcow2 2>/dev/null || true)
            disk_format=$(printf '%s' "$disk_info" | jq -r '.format // empty')
            virtual_size=$(printf '%s' "$disk_info" | jq -r '."virtual-size" // 0')

            if [ "$disk_format" != "qcow2" ]; then
                echo "disk.qcow2 for ${image_name} has unexpected format: ${disk_format}"
                return 1
            fi

            if [ "$virtual_size" -le 0 ]; then
                echo "disk.qcow2 for ${image_name} has invalid virtual size"
                return 1
            fi
        fi
    fi

    return 0
}

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
                        EXTRA_ARGS="-o source.same_as=3.21"
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
                    builder_path=""
                    if command -v distrobuilder >/dev/null 2>&1; then
                        builder_path="distrobuilder"
                    elif [ -x "$HOME/goprojects/bin/distrobuilder" ]; then
                        builder_path="$HOME/goprojects/bin/distrobuilder"
                    else
                        echo "distrobuilder not found"
                        continue
                    fi

                    success=false
                    if [[ "$run_funct" != "archlinux" && "$run_funct" != "gentoo" ]]; then
                        echo "sudo ${builder_path} build-incus ${opath}/images_yaml/${run_funct}.yaml --vm -o image.release=${version} -o image.architecture=${arch} -o image.variant=${variant} -o packages.manager=${manager} ${EXTRA_ARGS}"
                        if sudo "$builder_path" build-incus "${opath}/images_yaml/${run_funct}.yaml" --vm -o image.release="${version}" -o image.architecture="${arch}" -o image.variant="${variant}" -o packages.manager="${manager}" ${EXTRA_ARGS}; then
                            echo "Command succeeded"
                            success=true
                        fi
                    else
                        echo "sudo ${builder_path} build-incus ${opath}/images_yaml/${run_funct}.yaml --vm -o image.architecture=${arch} -o image.variant=${variant} -o packages.manager=${manager} ${EXTRA_ARGS}"
                        if sudo "$builder_path" build-incus "${opath}/images_yaml/${run_funct}.yaml" --vm -o image.architecture="${arch}" -o image.variant="${variant}" -o packages.manager="${manager}" ${EXTRA_ARGS}; then
                            echo "Command succeeded"
                            success=true
                        fi
                    fi

                    if ! $success; then
                        echo "Build failed for ${run_funct} ${version} ${arch} ${variant}; removing partial VM artifacts"
                        rm -f incus.tar.xz disk.qcow2 disk_compressed.qcow2
                        continue
                    fi

                    if [[ "$run_funct" == "debian" || "$run_funct" == "ubuntu" || "$run_funct" == "gentoo" ]]; then
                        [ "${arch}" = "amd64" ] && arch="x86_64"
                    elif [[ "$run_funct" == "fedora" || "$run_funct" == "opensuse" || "$run_funct" == "alpine" || "$run_funct" == "oracle" || "$run_funct" == "archlinux" || "$run_funct" == "openwrt" ]]; then
                        [ "${arch}" = "aarch64" ] && arch="arm64"
                    elif [[ "$run_funct" == "almalinux" || "$run_funct" == "centos" || "$run_funct" == "rockylinux" ]]; then
                        [ "${arch}" = "aarch64" ] && arch="arm64"
                    fi

                    zip_file="${run_funct}_${ver_num}_${version}_${arch}_${variant}_kvm.zip"
                    if ! patch_incus_metadata_for_kvm "$zip_file"; then
                        echo "Failed to patch metadata for ${zip_file}; skipping package"
                        rm -f incus.tar.xz disk.qcow2 disk_compressed.qcow2
                        continue
                    fi

                    if command -v qemu-img >/dev/null 2>&1; then
                        qemu-img convert -O qcow2 -c disk.qcow2 disk_compressed.qcow2 && mv disk_compressed.qcow2 disk.qcow2 || true
                    fi

                    if validate_vm_artifacts "$zip_file"; then
                        zip -9 "$zip_file" incus.tar.xz disk.qcow2
                    else
                        echo "VM artifacts failed validation for ${zip_file}; skipping package"
                    fi

                    rm -f incus.tar.xz disk.qcow2 disk_compressed.qcow2
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
