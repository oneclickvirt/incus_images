#!/bin/bash
# by https://github.com/oneclickvirt/incus_images
# 2025.01.31

# 设置错误处理
set -e
trap 'echo "发生错误，行号: $LINENO, 命令: $BASH_COMMAND"' ERR

# 获取命令行参数
if [[ $# -ne 1 ]]; then
    echo "用法: $0 <完整镜像名称>"
    exit 1
fi

image_name="$1"

# 根据镜像名称识别架构
if [[ "$image_name" == *"x86_64"* ]]; then
    fixed_images_file="x86_64_fixed_images.txt"
elif [[ "$image_name" == *"arm64"* ]]; then
    fixed_images_file="arm64_fixed_images.txt"
else
    echo "错误：无法识别镜像架构"
    exit 1
fi

# 初始化日志
date=$(date)
{
    echo "$date"
    echo "------------------------------------------"
    echo "测试镜像: $image_name"
} >> log

# 创建临时文件来跟踪测试状态
test_status_file=$(mktemp)
echo "success" > "$test_status_file"

cleanup() {
    local exit_code=$?
    echo "清理资源..."
    
    # 停止并删除容器（如果存在）
    incus stop test 2>/dev/null || true
    incus delete -f test 2>/dev/null || true
    
    # 删除镜像（如果存在）
    incus image delete myc 2>/dev/null || true
    
    # 清理临时文件
    rm -f "$test_status_file"
    rm -f incus.tar.xz rootfs.squashfs "$image_name"
    
    # 添加分隔线到日志
    echo "------------------------------------------" >> log
    
    # 如果测试失败，从固定镜像列表中删除
    if [[ "$(cat "$test_status_file")" != "success" ]]; then
        echo "测试失败，从列表中移除镜像"
        sed -i "/$image_name/d" "$fixed_images_file"
    fi
    
    exit $exit_code
}

trap cleanup EXIT

# 下载和解压镜像
echo "开始下载镜像..."
if ! curl -m 1800 -LO "https://github.com/oneclickvirt/incus_images/releases/download/${image_name%%_*}/$image_name"; then
    echo "主下载失败，尝试备用下载源..."
    if ! curl -m 1800 -LO "https://cdn.spiritlhl.net/https://github.com/oneclickvirt/incus_images/releases/download/${image_name%%_*}/$image_name"; then
        echo "错误：所有下载源均失败" | tee -a log
        echo "fail" > "$test_status_file"
        exit 1
    fi
fi

# 验证文件存在和大小
if [ ! -f "$image_name" ] || [ ! -s "$image_name" ]; then
    echo "错误：镜像文件不存在或为空" | tee -a log
    echo "fail" > "$test_status_file"
    exit 1
fi

chmod 777 "$image_name"

# 解压镜像
if ! unzip -q "$image_name"; then
    echo "错误：解压失败" | tee -a log
    echo "fail" > "$test_status_file"
    exit 1
fi

# 添加镜像到固定列表
echo "$image_name" >> "$fixed_images_file"

# 导入镜像
if ! incus image import incus.tar.xz rootfs.squashfs --alias myc; then
    echo "错误：镜像导入失败" | tee -a log
    echo "fail" > "$test_status_file"
    exit 1
fi

# 创建和启动容器
if ! incus init myc test; then
    echo "错误：容器初始化失败" | tee -a log
    echo "fail" > "$test_status_file"
    exit 1
fi

if ! incus start test; then
    echo "错误：容器启动失败" | tee -a log
    echo "fail" > "$test_status_file"
    exit 1
fi

# 等待容器完全启动
sleep 10

# SSH服务测试函数
ssh_test() {
    local retries=0
    local max_retries=5
    
    while [ $retries -lt $max_retries ]; do
        if incus exec test -- lsof -i:22 2>/dev/null | grep -q ssh; then
            echo "SSH服务正常" | tee -a log
            return 0
        fi
        echo "等待SSH服务启动，尝试 $((retries + 1))/$max_retries..." | tee -a log
        sleep $((2**retries))
        ((retries++))
    done
    
    echo "SSH服务异常" | tee -a log
    return 1
}

# 网络连通性测试函数
network_test() {
    # 备份原始resolv.conf
    incus exec test -- cp /etc/resolv.conf /etc/resolv.conf.bak || true
    
    # 配置DNS
    echo "nameserver 8.8.8.8" | incus exec test -- tee /etc/resolv.conf >/dev/null
    
    # 执行网络测试
    if incus exec test -- curl -m 10 -skL https://cdn.spiritlhl.net/https://raw.githubusercontent.com/spiritLHLS/ecs/main/back/test | grep -q "success"; then
        echo "网络连通正常" | tee -a log
        # 恢复原始resolv.conf
        incus exec test -- mv /etc/resolv.conf.bak /etc/resolv.conf 2>/dev/null || true
        return 0
    else
        echo "网络连接失败" | tee -a log
        # 恢复原始resolv.conf
        incus exec test -- mv /etc/resolv.conf.bak /etc/resolv.conf 2>/dev/null || true
        return 1
    fi
}

# 执行测试
if ! ssh_test; then
    echo "fail" > "$test_status_file"
    exit 1
fi

if ! network_test; then
    echo "fail" > "$test_status_file"
    exit 1
fi

# 重启测试
echo "执行重启测试..." | tee -a log
if ! incus stop test; then
    echo "错误：容器停止失败" | tee -a log
    echo "fail" > "$test_status_file"
    exit 1
fi

if ! incus start test; then
    echo "错误：容器重启失败" | tee -a log
    echo "fail" > "$test_status_file"
    exit 1
fi

# 等待容器重启
sleep 15

# 重启后网络测试
if ! network_test; then
    echo "重启后网络测试失败" | tee -a log
    echo "fail" > "$test_status_file"
    exit 1
fi

echo "所有测试通过" | tee -a log
exit 0