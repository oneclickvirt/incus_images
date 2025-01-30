#!/bin/bash
# by https://github.com/oneclickvirt/incus_images
# 2025.01.30
# curl -L https://raw.githubusercontent.com/oneclickvirt/incus_images/main/test.sh -o test.sh && chmod +x test.sh && ./test.sh

# 获取命令行参数
arch="$1"
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

rm -rf log
rm -rf "$fixed_images_file"
date=$(date)
echo "$date" >>log
echo "------------------------------------------" >>log
release_names=("ubuntu" "debian" "kali" "centos" "almalinux" "rockylinux" "fedora" "opensuse" "alpine" "archlinux" "gentoo" "openwrt" "oracle" "openeuler")
system_names=()
response=$(curl -slk -m 6 "$file_url")
if [ $? -ne 0 ]; then
    response=$(curl -slk -m 6 "$alt_file_url")
fi
if [ $? -eq 0 ] && [ -n "$response" ]; then
    system_names+=($(echo "$response"))
fi
for ((i = 0; i < ${#release_names[@]}; i++)); do
    release_name="${release_names[i]}"
    temp_images=()
    for sy in "${system_names[@]}"; do
        if [[ $sy == "${release_name}"* ]]; then
            curl -m 60 -LO "https://github.com/oneclickvirt/incus_images/releases/download/${release_name}/${sy}"
            if [ $? -ne 0 ]; then
                curl -m 60 -LO "https://cdn.spiritlhl.net/https://github.com/oneclickvirt/incus_images/releases/download/${release_name}/${sy}"
            fi
            temp_images+=("${sy}")
        fi
    done
    for image_name in "${temp_images[@]}"; do
        echo "$image_name"
        echo "$image_name" >>log
        echo "$image_name" >>"$fixed_images_file"
        delete_status=false
        chmod 777 "$image_name"
        unzip "$image_name"
        rm -rf "$image_name"
        incus image import incus.tar.xz rootfs.squashfs --alias myc
        rm -rf incus.tar.xz rootfs.squashfs
        incus init myc test
        incus start test
        sleep 5
        res1=$(incus exec test -- lsof -i:22)
        if [[ $res1 == *"command not found"* ]]; then
            echo "no lsof" >>log
        fi
        sleep 1
        res1=$(incus exec test -- lsof -i:22)
        if [[ $res1 == *"ssh"* ]]; then
            echo "ssh config correct"
        else
            if [ "$delete_status" = false ];then
                delete_status=true
                head -n -1 "$fixed_images_file" > temp.txt && mv temp.txt "$fixed_images_file"
            fi
        fi
        res2=$(incus exec test -- curl --version)
        if [[ $res2 == *"command not found"* ]]; then
            echo "no curl" >>log
        fi
        res3=$(incus exec test -- wget --version)
        if [[ $res3 == *"command not found"* ]]; then
            echo "no wget" >>log
        fi
        echo "nameserver 8.8.8.8" | incus exec test -- tee -a /etc/resolv.conf
        res4=$(incus exec test -- curl -lk https://cdn.spiritlhl.net/https://raw.githubusercontent.com/spiritLHLS/ecs/main/back/test)
        if [[ $res4 == *"success"* ]]; then
            echo "network is public"
        else
            echo "no public network" >>log
            if [ "$delete_status" = false ];then
                delete_status=true
                head -n -1 "$fixed_images_file" > temp.txt && mv temp.txt "$fixed_images_file"
            fi
        fi
        sleep 5
        incus stop test
        if [ $? -eq 0 ]; then
            incus start test
            sleep 10
            echo "nameserver 8.8.8.8" | incus exec test -- tee -a /etc/resolv.conf
            res5=$(incus exec test -- curl -lk https://cdn.spiritlhl.net/https://raw.githubusercontent.com/spiritLHLS/ecs/main/back/test)
            if [[ $res5 == *"success"* ]]; then
                echo "reboot success"
            else
                echo "reboot failed" >>log
                if [ "$delete_status" = false ];then
                    delete_status=true
                    head -n -1 "$fixed_images_file" > temp.txt && mv temp.txt "$fixed_images_file"
                fi
            fi
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
    done
done
