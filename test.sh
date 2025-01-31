#!/bin/bash
# by https://github.com/oneclickvirt/incus_images
# 2025.01.31
# curl -L https://raw.githubusercontent.com/oneclickvirt/incus_images/main/test.sh -o test.sh && chmod +x test.sh && ./test.sh

# 获取命令行参数
if [[ $# -lt 1 || $# -gt 2 ]]; then
    echo "用法: $0 <架构> [发行版名称]"
    exit 1
fi
arch="$1"
release_name="$2"
# 根据输入来选择文件
if [[ "$arch" == "x86_64" ]]; then
    file_url="https://raw.githubusercontent.com/oneclickvirt/incus_images/main/x86_64_all_images.txt"
    alt_file_url="https://cdn.spiritlhl.net/https://raw.githubusercontent.com/oneclickvirt/incus_images/main/x86_64_all_images.txt"
    fixed_images_file="x86_64_fixed_images.txt"
elif [[ "$arch" == "arm64" ]]; then
    file_url="https://raw.githubusercontent.com/oneclickvirt/incus_images/main/arm64_all_images.txt"
    alt_file_url="https://cdn.spiritlhl.net/https://raw.githubusercontent.com/oneclickvirt/incus_images/main/arm64_all_images.txt"
    fixed_images_file="arm64_fixed_images.txt"
else
    echo "无效的架构类型"
    exit 1
fi

release_names=("ubuntu" "debian" "kali" "centos" "almalinux" "rockylinux" "fedora" "opensuse" "alpine" "archlinux" "gentoo" "openwrt" "oracle" "openeuler")

# 检查发行版参数有效性
if [[ -n "$release_name" ]]; then
    if [[ ! " ${release_names[*]} " =~ " $release_name " ]]; then
        echo "无效的发行版名称: $release_name"
        exit 1
    fi
    release_names=("$release_name")
fi

rm -rf log
rm -rf "$fixed_images_file"
date=$(date)
echo "$date" >>log
echo "------------------------------------------" >>log
system_names=()
response=$(curl -slk -m 6 "$file_url")
if [ $? -ne 0 ]; then
    response=$(curl -slk -m 6 "$alt_file_url")
fi
if [ $? -eq 0 ] && [ -n "$response" ]; then
    system_names+=($(echo "$response"))
fi
for ((i = 0; i < ${#release_names[@]}; i++)); do
    current_release="${release_names[i]}"
    temp_images=()
    for sy in "${system_names[@]}"; do
        if [[ $sy == "${current_release}"* ]]; then
            temp_images+=("${sy}")
        fi
    done
    for image_name in "${temp_images[@]}"; do
        echo "$image_name"
        echo "$image_name" >>log
        echo "$image_name" >>"$fixed_images_file"
        delete_status=false
        curl -m 60 -LO "https://github.com/oneclickvirt/incus_images/releases/download/${current_release}/${image_name}"
        if [ $? -ne 0 ]; then
            curl -m 60 -LO "https://cdn.spiritlhl.net/https://github.com/oneclickvirt/incus_images/releases/download/${current_release}/${image_name}"
        fi
        chmod 777 "$image_name"
        unzip "$image_name"
        rm -rf "$image_name"
        incus image import incus.tar.xz rootfs.squashfs --alias myc
        rm -rf incus.tar.xz rootfs.squashfs
        incus init myc test
        incus start test
        sleep 5
        res1=$(incus exec test -- lsof -i:22 2>/dev/null)
        if [[ $res1 == *"command not found"* ]]; then
            echo "no lsof" >>log
        fi
        sleep 1
        res1=$(incus exec test -- lsof -i:22 2>/dev/null)
        if [[ $res1 == *"ssh"* ]]; then
            echo "ssh config correct"
        else
            if [ "$delete_status" = false ];then
                delete_status=true
                head -n -1 "$fixed_images_file" > temp.txt && mv temp.txt "$fixed_images_file"
            fi
        fi
        res2=$(incus exec test -- curl --version 2>/dev/null)
        if [[ $res2 == *"command not found"* ]]; then
            echo "no curl" >>log
        fi
        res3=$(incus exec test -- wget --version 2>/dev/null)
        if [[ $res3 == *"command not found"* ]]; then
            echo "no wget" >>log
        fi
        incus exec test -- cp /etc/resolv.conf /etc/resolv.conf.bak
        echo "nameserver 8.8.8.8" | incus exec test -- tee -a /etc/resolv.conf >/dev/null 2>&1
        # 运行测试
        res4=$(incus exec test -- curl -lk https://cdn.spiritlhl.net/https://raw.githubusercontent.com/spiritLHLS/ecs/main/back/test 2>/dev/null)
        if [[ $res4 == *"success"* ]]; then
            echo "network is public"
        else
            echo "no public network" >> log
            if [ "$delete_status" = false ]; then
                delete_status=true
                head -n -1 "$fixed_images_file" > temp.txt && mv temp.txt "$fixed_images_file"
            fi
        fi
        # 测试完成后恢复 DNS 配置
        incus exec test -- mv /etc/resolv.conf.bak /etc/resolv.conf
        sleep 5
        incus stop test
        if [ $? -eq 0 ]; then
            incus start test
            sleep 10
            # 备份原始 DNS 配置
            incus exec test -- cp /etc/resolv.conf /etc/resolv.conf.bak
            # 临时添加 Google DNS
            echo "nameserver 8.8.8.8" | incus exec test -- tee -a /etc/resolv.conf >/dev/null 2>&1
            # 进行测试
            res5=$(incus exec test -- curl -lk https://cdn.spiritlhl.net/https://raw.githubusercontent.com/spiritLHLS/ecs/main/back/test 2>/dev/null)
            if [[ $res5 == *"success"* ]]; then
                echo "reboot success"
            else
                echo "reboot failed" >>log
                if [ "$delete_status" = false ]; then
                    delete_status=true
                    head -n -1 "$fixed_images_file" > temp.txt && mv temp.txt "$fixed_images_file"
                fi
            fi
            # 恢复原始 DNS 配置，确保环境不受影响
            incus exec test -- mv /etc/resolv.conf.bak /etc/resolv.conf
        else
            echo "reboot failed" >>log
            if [ "$delete_status" = false ];then
                delete_status=true
                head -n -1 "$fixed_images_file" > temp.txt && mv temp.txt "$fixed_images_file"
            fi
        fi
        incus stop test
        incus delete -f test
        incus image delete myc
        echo "------------------------------------------" >>log
        curl ip.sb || echo "nameserver 8.8.8.8" >> /etc/resolv.conf >/dev/null 2>&1
    done
done
