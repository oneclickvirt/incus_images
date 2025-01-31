#!/bin/bash
# by https://github.com/oneclickvirt/incus_images
# 2025.01.31

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
echo "$date" >> log
echo "------------------------------------------" >> log
echo "测试镜像: $image_name" >> log

# 下载和解压镜像
delete_status=false
echo "$image_name" >> "$fixed_images_file"
echo "开始下载镜像..."
curl -m 1800 -LO "https://github.com/oneclickvirt/incus_images/releases/download/${image_name%%_*}/$image_name"
if [ $? -ne 0 ]; then
    echo "主下载失败，尝试备用下载源..."
    curl -m 1800 -LO "https://cdn.spiritlhl.net/https://github.com/oneclickvirt/incus_images/releases/download/${image_name%%_*}/$image_name"
fi

if [ ! -f "$image_name" ]; then
    echo "错误：镜像下载失败"
    head -n -1 "$fixed_images_file" > temp.txt && mv temp.txt "$fixed_images_file"
    exit 1
fi

chmod 777 "$image_name"
unzip "$image_name"
if [ $? -ne 0 ]; then
    echo "错误：解压失败"
    head -n -1 "$fixed_images_file" > temp.txt && mv temp.txt "$fixed_images_file"
    exit 1
fi
rm -rf "$image_name"

# 导入镜像
incus image import incus.tar.xz rootfs.squashfs --alias myc
rm -rf incus.tar.xz rootfs.squashfs

# 创建测试容器
incus init myc test || { echo "容器初始化失败"; exit 1; }
incus start test
sleep 10

# 测试SSH服务
ssh_test() {
    retries=0
    max_retries=5
    while [ $retries -lt $max_retries ]; do
        res=$(incus exec test -- lsof -i:22 2>/dev/null | grep ssh)
        if [[ -n "$res" ]]; then
            echo "SSH服务正常"
            return 0
        fi
        sleep $((2**retries))
        ((retries++))
    done
    echo "SSH服务异常"
    return 1
}

# 测试网络连通性
network_test() {
    incus exec test -- cp /etc/resolv.conf /etc/resolv.conf.bak
    echo "nameserver 8.8.8.8" | incus exec test -- tee -a /etc/resolv.conf >/dev/null
    res=$(incus exec test -- curl -m 10 -skL https://cdn.spiritlhl.net/https://raw.githubusercontent.com/spiritLHLS/ecs/main/back/test)
    incus exec test -- mv /etc/resolv.conf.bak /etc/resolv.conf
    
    if [[ "$res" == *"success"* ]]; then
        echo "网络连通正常"
        return 0
    else
        echo "网络连接失败"
        return 1
    fi
}

# 执行测试用例
if ! ssh_test; then
    echo "SSH测试失败" >> log
    delete_status=true
fi

if ! network_test; then
    echo "网络测试失败" >> log
    delete_status=true
fi

# 重启测试
incus stop test
if incus start test; then
    sleep 15
    if ! network_test; then
        echo "重启后网络测试失败" >> log
        delete_status=true
    fi
else
    echo "容器重启失败" >> log
    delete_status=true
fi

# 清理资源
incus stop test
incus delete -f test
incus image delete myc

# 处理测试结果
if [ "$delete_status" = true ]; then
    echo "镜像未通过测试，从列表移除"
    sed -i "/$image_name/d" "$fixed_images_file"
fi

echo "------------------------------------------" >> log
exit 0