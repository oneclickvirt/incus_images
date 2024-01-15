#!/bin/bash
# 从 https://github.com/oneclickvirt/incus_images 获取

opath=$(pwd)

# 检查并安装依赖工具
if command -v apt-get >/dev/null 2>&1; then
    # ubuntu debian kali
    if ! command -v zip >/dev/null 2>&1; then
        sudo apt-get install zip -y
    fi
    uname_output=$(uname -a)
    if [[ $uname_output != *ARM* && $uname_output != *arm* && $uname_output != *aarch* ]]; then
        if ! command -v snap >/dev/null 2>&1; then
            sudo apt-get install snapd -y
        fi
        if ! command -v distrobuilder >/dev/null 2>&1; then
            sudo snap install distrobuilder --classic
        fi
    else
        sudo apt-get install build-essential -y
        export CGO_ENABLED=1
        export CC=gcc
        wget https://go.dev/dl/go1.21.6.linux-arm64.tar.gz
        chmod 777 go1.21.6.linux-arm64.tar.gz
        rm -rf /usr/local/go && tar -C /usr/local -xzf go1.21.6.linux-arm64.tar.gz
        export GOROOT=/usr/local/go
        export PATH=$GOROOT/bin:$PATH
        export GOPATH=$HOME/goprojects/
        go version
        apt-get install -q -y debootstrap rsync gpg squashfs-tools git make
        git config --global user.name "daily-update"
        git config --global user.email "tg@spiritlhl.top"
        mkdir -p $HOME/go/src/github.com/lxc/
        cd $HOME/go/src/github.com/lxc/
        git clone https://github.com/lxc/distrobuilder
        cd ./distrobuilder
        make
        export PATH=$HOME/go/bin:$PATH
        echo $PATH
        distrobuilder --version
        $HOME/go/bin/distrobuilder --version
    fi
    if ! command -v debootstrap >/dev/null 2>&1; then
        sudo apt-get install debootstrap -y
    fi
elif command -v yum >/dev/null 2>&1; then
    # centos oracle
    if ! command -v zip >/dev/null 2>&1; then
        sudo yum install zip -y
    fi
    if ! command -v distrobuilder >/dev/null 2>&1; then
        # sudo yum install wget -y
        # sudo yum install python2 -y
        # wget https://raw.githubusercontent.com/gdraheim/docker-systemctl-replacement/master/files/docker/systemctl.py -O /bin/systemctl
        # chmod a+x /bin/systemctl
        # sudo yum install snapd -y
        # sudo ln -s /var/lib/snapd/snap /snap
        # sudo /bin/systemctl start snapd.socket
        # sudo /bin/systemctl enable --now snapd.socket
        # sudo snap install distrobuilder --classic
        rpm --import https://mirror.go-repo.io/centos/RPM-GPG-KEY-GO-REPO
        curl -s https://mirror.go-repo.io/centos/go-repo.repo | tee /etc/yum.repos.d/go-repo.repo
        sudo yum install -y golang
        sudo yum install -y tar rsync gnupg squashfs-tools git make
        mkdir -p $HOME/go/src/github.com/lxc/
        cd $HOME/go/src/github.com/lxc/
        git clone https://github.com/lxc/distrobuilder
        cd ./distrobuilder
        make
        export PATH=$PATH:$HOME/go/bin
        echo $PATH
        distrobuilder --version
        $HOME/go/bin/distrobuilder --version
    fi
elif command -v dnf >/dev/null 2>&1; then
    # almalinux rockylinux oracle
    if ! command -v zip >/dev/null 2>&1; then
        sudo dnf install zip -y
    fi
    if ! command -v distrobuilder >/dev/null 2>&1; then
        sudo dnf install epel-release -y
        sudo dnf install snapd -y
        sudo dnf install wget -y
        wget https://raw.githubusercontent.com/gdraheim/docker-systemctl-replacement/master/files/docker/systemctl.py -O /bin/systemctl
        chmod a+x /bin/systemctl
        sudo systemctl start snapd.socket
        sudo systemctl enable --now snapd.socket
        sudo ln -s /var/lib/snapd/snap /snap
        sudo snap install distrobuilder --classic
    fi
elif command -v pacman >/dev/null 2>&1; then
    # archlinux
    if ! command -v zip >/dev/null 2>&1; then
        sudo pacman -Sy --noconfirm --needed zip
    fi
    if ! command -v distrobuilder >/dev/null 2>&1; then
        sudo pacman -Sy --noconfirm --needed snapd
        sudo ln -s /var/lib/snapd/snap /snap
        sudo pacman -Sy --noconfirm --needed wget
        wget https://raw.githubusercontent.com/gdraheim/docker-systemctl-replacement/master/files/docker/systemctl.py -O /bin/systemctl
        chmod a+x /bin/systemctl
        sudo systemctl start snapd.socket
        sudo systemctl enable --now snapd.socket
        sudo snap install distrobuilder --classic
    fi
elif command -v apk >/dev/null 2>&1; then
    # alpine
    if ! command -v zip >/dev/null 2>&1; then
        sudo apk add zip
    fi
    if ! command -v distrobuilder >/dev/null 2>&1; then
        sudo apk add snapd
        sudo ln -s /var/lib/snapd/snap /snap
        snap –version
        sudo snap install distrobuilder --classic
    fi
fi

run_funct="${1:-debian}"
is_build_image="${2:-false}"
build_arch="${3:-amd64}"
zip_name_list=()

# 构建或列出不同发行版的镜像
build_or_list_images() {
    local versions=()
    local ver_nums=()
    read -ra versions <<< "$1"
    read -ra ver_nums <<< "$2"
    local architectures=("$build_arch")
    local variants=("default" "cloud")
    local len=${#versions[@]}
    for ((i = 0; i < len; i++)); do
        version=${versions[i]}
        ver_num=${ver_nums[i]}
        for arch in "${architectures[@]}"; do
            for variant in "${variants[@]}"; do
                if [ "$is_build_image" == true ]; then    
                    if sudo distrobuilder build-incus "${opath}/images_yaml/${run_funct}.yaml" -o image.release=${version} -o image.architecture=${arch} -o image.variant=${variant}; then
                        echo "Command succeeded"
                    else
                        sudo $HOME/go/bin/distrobuilder "${opath}/images_yaml/${run_funct}.yaml" -o image.release=${version} -o image.architecture=${arch} -o image.variant=${variant}
                    fi
                    if [ -f incus.tar.xz ] && [ -f rootfs.squashfs ]; then
                        zip "${run_funct}_${ver_num}_${version}_${arch}_${variant}.zip" incus.tar.xz rootfs.squashfs
                        rm -rf incus.tar.xz rootfs.squashfs
                    fi
                else
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
case "$run_funct" in
debian)
    build_or_list_images "buster bullseye bookworm trixie" "10 11 12 13"
    ;;
ubuntu)
    build_or_list_images "bionic focal jammy lunar mantic noble" "18.04 20.04 22.04 23.04 23.10 24.04"
    ;;
kali)
    build_or_list_images "kali-rolling" "latest"
    ;;
centos)
    build_or_list_images "7 8-Stream 9-Stream" "7 8 9"
    ;;
almalinux)
    build_or_list_images "8 9" "8 9"
    ;;
rockylinux)
    build_or_list_images "8 9" "8 9"
    ;;
alpine)
    build_or_list_images "3.17 3.18 3.19 edge" "3.17 3.18 3.19 edge"
    ;;
openwrt)
    build_or_list_images "snapshot 22.03 23.05" "snapshot 22.03 23.05"
    ;;
oracle)
    build_or_list_images "7 8 9" "7 8 9"
    ;;
archlinux)
    build_or_list_images "latest" "latest"
    ;;
*)
    echo "Invalid distribution specified."
    ;;
esac
