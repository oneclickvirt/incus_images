#!/bin/bash
# by https://github.com/oneclickvirt/incus_images
# 2025.01.31

set -e
trap 'echo "发生错误，行号: $LINENO, 命令: $BASH_COMMAND"' ERR

if [[ $# -ne 1 ]]; then
    echo "用法: $0 <完整镜像名称>"
    exit 1
fi

image_name="$1"
is_kvm_image=false
if [[ "$image_name" == *_kvm.zip ]]; then
    is_kvm_image=true
fi

if [[ "$image_name" == *"x86_64"* || "$image_name" == *"amd64"* ]]; then
    fixed_images_file="x86_64_fixed_images.txt"
elif [[ "$image_name" == *"arm64"* ]]; then
    fixed_images_file="arm64_fixed_images.txt"
else
    echo "错误：无法识别镜像架构"
    exit 1
fi
if $is_kvm_image; then
    fixed_images_file="${fixed_images_file/_fixed_images/_fixed_kvm_images}"
fi
touch "$fixed_images_file"

date=$(date)
{
    echo "$date"
    echo "------------------------------------------"
    echo "测试镜像: $image_name"
} >> log

test_status_file=$(mktemp)
echo "success" > "$test_status_file"

cleanup() {
    local exit_code=$?
    echo "清理资源..."
    incus stop test 2>/dev/null || true
    incus delete -f test 2>/dev/null || true
    incus image delete myc 2>/dev/null || true

    if [[ -f "$test_status_file" ]]; then
        if [[ "$(cat "$test_status_file")" != "success" ]]; then
            echo "测试失败，从列表中移除镜像"
            grep -vxF "$image_name" "$fixed_images_file" > "${fixed_images_file}.tmp" && mv "${fixed_images_file}.tmp" "$fixed_images_file" || true
        fi
    else
        echo "警告：test_status_file 丢失，跳过失败处理" | tee -a log
    fi

    rm -f "$test_status_file"
    rm -f incus.tar.xz rootfs.squashfs disk.qcow2 "$image_name"
    echo "------------------------------------------" >> log

    # 检查 systemd-resolved 是否被影响，并尝试恢复
    if systemctl is-active --quiet systemd-resolved; then
        echo "重启 systemd-resolved 以恢复 DNS"
        systemctl restart systemd-resolved || true
    fi

    exit $exit_code
}

trap cleanup EXIT

release_tag="${image_name%%_*}"
if $is_kvm_image; then
    release_tag="kvm_images"
fi

echo "开始下载镜像..."
if ! curl -m 1800 -LO "https://github.com/oneclickvirt/incus_images/releases/download/${release_tag}/$image_name"; then
    echo "主下载失败，尝试备用下载源..."
    if ! curl -m 1800 -LO "https://cdn.spiritlhl.net/https://github.com/oneclickvirt/incus_images/releases/download/${release_tag}/$image_name"; then
        echo "错误：所有下载源均失败" | tee -a log
        echo "fail" > "$test_status_file"
        exit 1
    fi
fi

if [ ! -f "$image_name" ] || [ ! -s "$image_name" ]; then
    echo "错误：镜像文件不存在或为空" | tee -a log
    echo "fail" > "$test_status_file"
    exit 1
fi

chmod 777 "$image_name"

if ! unzip -q "$image_name"; then
    echo "错误：解压失败" | tee -a log
    echo "fail" > "$test_status_file"
    exit 1
fi

echo "$image_name" >> "$fixed_images_file"

if $is_kvm_image; then
    if [ ! -s incus.tar.xz ] || [ ! -s disk.qcow2 ]; then
        echo "错误：KVM 镜像缺少 incus.tar.xz 或 disk.qcow2" | tee -a log
        echo "fail" > "$test_status_file"
        exit 1
    fi
elif [ ! -s incus.tar.xz ] || [ ! -s rootfs.squashfs ]; then
    echo "错误：容器镜像缺少 incus.tar.xz 或 rootfs.squashfs" | tee -a log
    echo "fail" > "$test_status_file"
    exit 1
fi

if $is_kvm_image && [ ! -e /dev/kvm ]; then
    echo "错误：当前环境缺少 /dev/kvm，无法验证 VM 镜像启动" | tee -a log
    echo "fail" > "$test_status_file"
    exit 1
fi

if $is_kvm_image; then
    if ! incus image import incus.tar.xz disk.qcow2 --alias myc; then
        echo "错误：VM 镜像导入失败" | tee -a log
        echo "fail" > "$test_status_file"
        exit 1
    fi
else
    if ! incus image import incus.tar.xz rootfs.squashfs --alias myc; then
        echo "错误：镜像导入失败" | tee -a log
        echo "fail" > "$test_status_file"
        exit 1
    fi
fi

requires_secureboot_disabled() {
    case "$image_name" in
    alpine_*_kvm.zip | archlinux_*_kvm.zip | gentoo_*_kvm.zip | openwrt_*_kvm.zip)
        return 0
        ;;
    *)
        return 1
        ;;
    esac
}

init_args=(myc test)
if $is_kvm_image; then
    init_args+=(--vm)
fi

if ! incus init "${init_args[@]}"; then
    echo "错误：实例初始化失败" | tee -a log
    echo "fail" > "$test_status_file"
    exit 1
fi

image_type=$(incus image info myc | awk -F': ' '/^Type:/ {print $2; exit}')
if $is_kvm_image && [ "$image_type" != "virtual-machine" ]; then
    echo "错误：KVM 镜像类型异常，当前类型为 ${image_type:-unknown}" | tee -a log
    echo "fail" > "$test_status_file"
    exit 1
fi

if $is_kvm_image && requires_secureboot_disabled; then
    if ! incus image info myc | grep -q 'requirements.secureboot: "false"\|requirements.secureboot: false'; then
        echo "错误：KVM 镜像缺少 requirements.secureboot=false" | tee -a log
        echo "fail" > "$test_status_file"
        exit 1
    fi
fi

if ! incus start test; then
    echo "错误：实例启动失败" | tee -a log
    echo "fail" > "$test_status_file"
    exit 1
fi

if $is_kvm_image; then
    sleep 45
else
    sleep 10
fi

ssh_test() {
    local retries=0
    local max_retries=5
    if $is_kvm_image; then
        max_retries=12
    fi
    
    while [ $retries -lt $max_retries ]; do
        if incus exec test -- lsof -i:22 2>/dev/null | grep -q ssh; then
            echo "SSH服务正常" | tee -a log
            return 0
        fi
        echo "等待SSH服务启动，尝试 $((retries + 1))/$max_retries..." | tee -a log
        if $is_kvm_image; then
            sleep 10
        else
            sleep $((2**retries))
        fi
        ((retries++))
    done
    
    echo "SSH服务异常" | tee -a log
    return 1
}

network_test() {
    incus exec test -- cp /etc/resolv.conf /etc/resolv.conf.bak || true

    incus exec test -- sh -c 'echo "nameserver 8.8.8.8" > /etc/resolv.conf'

    if incus exec test -- curl -m 10 -skL https://cdn.spiritlhl.net/https://raw.githubusercontent.com/spiritLHLS/ecs/main/back/test | grep -q "success"; then
        echo "网络连通正常" | tee -a log
        incus exec test -- mv /etc/resolv.conf.bak /etc/resolv.conf 2>/dev/null || true
        return 0
    else
        echo "网络连接失败" | tee -a log
        incus exec test -- mv /etc/resolv.conf.bak /etc/resolv.conf 2>/dev/null || true
        return 1
    fi
}

if ! ssh_test; then
    echo "fail" > "$test_status_file"
    exit 1
fi
if ! network_test; then
    echo "fail" > "$test_status_file"
    exit 1
fi
echo "执行重启测试..." | tee -a log
if ! incus stop test; then
    echo "错误：实例停止失败" | tee -a log
    echo "fail" > "$test_status_file"
    exit 1
fi
if ! incus start test; then
    echo "错误：实例重启失败" | tee -a log
    echo "fail" > "$test_status_file"
    exit 1
fi
if $is_kvm_image; then
    sleep 45
else
    sleep 15
fi
if ! network_test; then
    echo "重启后网络测试失败" | tee -a log
    echo "fail" > "$test_status_file"
    exit 1
fi
echo "所有测试通过" | tee -a log
exit 0
