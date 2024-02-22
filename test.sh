#!/bin/bash
# by https://github.com/oneclickvirt/incus_images
# 2024.02.22
# curl -L https://raw.githubusercontent.com/oneclickvirt/incus_images/main/test.sh -o test.sh && chmod +x test.sh && ./test.sh

rm -rf log
date=$(date)
echo "$date" >>log
echo "------------------------------------------" >>log
release_names=("ubuntu" "debian" "kali" "centos" "almalinux" "rockylinux" "fedora" "opensuse" "alpine" "archlinux" "gentoo" "openwrt" "oracle" "openeuler")
response=$(curl -slk -m 6 "https://raw.githubusercontent.com/oneclickvirt/incus_images/main/fixed_images.txt")
system_names=()
if [ $? -eq 0 ] && [ -n "$response" ]; then
    system_names+=($(echo "$response"))
fi
for ((i = 0; i < ${#release_names[@]}; i++)); do
    release_name="${release_names[i]}"
    temp_images=()
    for sy in "${system_names[@]}"; do
        if [[ $sy == "${release_name}"* ]]; then
            curl -LO "https://github.com/oneclickvirt/incus_images/releases/download/${release_name}/${sy}"
            temp_images+=("${sy}")
        fi
    done
    for image_name in "${temp_images[@]}"; do
        echo "$image_name"
        echo "$image_name" >>log
        chmod 777 "$image_name"
        unzip "$image_name"
        rm -rf "$image_name"
        incus image import incus.tar.xz rootfs.squashfs --alias "$image_name"
        rm -rf incus.tar.xz rootfs.squashfs
        incus init "$image_name" test -c limits.cpu=1 -c limits.memory=1024MiB
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
        res4=$(incus exec test -- curl -lk https://raw.githubusercontent.com/spiritLHLS/ecs/main/back/test)
        if [[ $res4 == *"success"* ]]; then
            echo "network is public"
        else
            echo "no public network" >>log
        fi
        incus stop test
        incus start test
        sleep 10
        echo "nameserver 8.8.8.8" | incus exec test -- tee -a /etc/resolv.conf
        res5=$(incus exec test -- curl -lk https://raw.githubusercontent.com/spiritLHLS/ecs/main/back/test)
        if [[ $res5 == *"success"* ]]; then
            echo "reboot success"
        else
            echo "reboot failed" >>log
        fi
        incus stop test
        incus delete -f test
        incus image delete $image_name
        echo "------------------------------------------" >>log
    done
done