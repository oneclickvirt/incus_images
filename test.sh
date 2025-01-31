#!/bin/bash
# https://github.com/oneclickvirt/incus_images

set -eo pipefail

# 配置参数
MAX_RETRIES=3
DOWNLOAD_TIMEOUT=1800
SSH_TEST_RETRIES=5
NETWORK_TEST_URL="https://cdn.spiritlhl.net/https://raw.githubusercontent.com/spiritLHLS/ecs/main/back/test"
TEMP_FILES=()

# 日志函数
log() {
    local level=$1
    local message=$2
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message" | tee -a validation.log
}

# 清理函数
cleanup() {
    log "INFO" "开始清理资源..."
    
    # 删除临时文件
    for file in "${TEMP_FILES[@]}"; do
        if [[ -f "$file" ]]; then
            rm -f "$file"
            log "DEBUG" "已删除临时文件: $file"
        fi
    done

    # 停止并删除测试容器
    if incus list -c n --format csv | grep -q '^test$'; then
        incus stop test --force 2>/dev/null || true
        incus delete test --force 2>/dev/null || true
        log "DEBUG" "已删除测试容器"
    fi

    # 删除测试镜像
    if incus image list -c f --format csv | grep -q '^myc$'; then
        incus image delete myc --force 2>/dev/null || true
        log "DEBUG" "已删除测试镜像"
    fi
}

# 错误处理
trap 'cleanup; log "ERROR" "脚本异常退出"; exit 1' ERR INT TERM

# 参数检查
if [[ $# -ne 1 ]]; then
    log "ERROR" "用法: $0 <完整镜像名称>"
    exit 1
fi

image_name="$1"
log "INFO" "开始验证镜像: $image_name"

# 确定架构
if [[ "$image_name" == *"x86_64"* ]]; then
    fixed_images_file="x86_64_fixed_images.txt"
elif [[ "$image_name" == *"arm64"* ]]; then
    fixed_images_file="arm64_fixed_images.txt"
else
    log "ERROR" "无法识别镜像架构"
    exit 1
fi

# 初始化结果文件
echo "$image_name" >> "$fixed_images_file"
TEMP_FILES+=("$fixed_images_file")

# 下载镜像
download_image() {
    local url="https://github.com/oneclickvirt/incus_images/releases/download/${image_name%%_*}/$image_name"
    local retries=0

    while ((retries < MAX_RETRIES)); do
        log "INFO" "尝试下载镜像 (第 $((retries+1)) 次)"
        if curl -m "$DOWNLOAD_TIMEOUT" -LO "$url"; then
            log "INFO" "镜像下载成功"
            return 0
        fi

        ((retries++))
        log "WARN" "下载失败，尝试备用源..."
        url="https://cdn.spiritlhl.net/$url"
    done

    log "ERROR" "镜像下载失败"
    return 1
}

if ! download_image; then
    sed -i "/$image_name/d" "$fixed_images_file"
    exit 1
fi

TEMP_FILES+=("$image_name")

# 解压镜像
log "INFO" "开始解压镜像..."
if ! unzip -q "$image_name"; then
    log "ERROR" "解压失败"
    sed -i "/$image_name/d" "$fixed_images_file"
    exit 1
fi
rm -f "$image_name"

TEMP_FILES+=(incus.tar.xz rootfs.squashfs)

# 导入镜像
log "INFO" "导入镜像..."
if ! incus image import incus.tar.xz rootfs.squashfs --alias myc; then
    log "ERROR" "镜像导入失败"
    sed -i "/$image_name/d" "$fixed_images_file"
    exit 1
fi

# 创建测试容器
log "INFO" "创建测试容器..."
if ! incus init myc test; then
    log "ERROR" "容器初始化失败"
    exit 1
fi

if ! incus start test; then
    log "ERROR" "容器启动失败"
    exit 1
fi

# 等待容器初始化
sleep 15

# SSH服务测试
ssh_test() {
    local retries=0
    while ((retries < SSH_TEST_RETRIES)); do
        if incus exec test -- lsof -i:22 2>/dev/null | grep -q ssh; then
            log "INFO" "SSH服务正常"
            return 0
        fi
        sleep $((2**retries))
        ((retries++))
    done
    log "ERROR" "SSH服务异常"
    return 1
}

# 网络连通性测试
network_test() {
    incus exec test -- cp /etc/resolv.conf /etc/resolv.conf.bak
    echo "nameserver 8.8.8.8" | incus exec test -- tee -a /etc/resolv.conf >/dev/null
    
    if incus exec test -- curl -m 10 -skL "$NETWORK_TEST_URL" | grep -q success; then
        log "INFO" "网络连通正常"
        incus exec test -- mv /etc/resolv.conf.bak /etc/resolv.conf
        return 0
    else
        log "ERROR" "网络连接失败"
        incus exec test -- mv /etc/resolv.conf.bak /etc/resolv.conf
        return 1
    fi
}

# 执行测试
test_passed=true
if ! ssh_test; then
    test_passed=false
fi

if ! network_test; then
    test_passed=false
fi

# 重启测试
log "INFO" "执行重启测试..."
if incus stop test && incus start test; then
    sleep 15
    if ! network_test; then
        log "ERROR" "重启后网络测试失败"
        test_passed=false
    fi
else
    log "ERROR" "容器重启失败"
    test_passed=false
fi

# 处理测试结果
if ! $test_passed; then
    log "WARN" "镜像未通过测试，从列表移除"
    sed -i "/$image_name/d" "$fixed_images_file"
fi

# 清理资源
cleanup

log "INFO" "验证流程完成"
exit 0