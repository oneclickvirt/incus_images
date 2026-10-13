#!/bin/bash
set -eo pipefail
source "$CI_IMAGE_SCRIPT_ROOT/ci_network.sh"
# from https://github.com/oneclickvirt/incus_images
# Thanks https://github.com/lxc/lxc-ci/tree/main/images
# 2025.01.30

REPO_DIR="${GITHUB_WORKSPACE:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
cd "$REPO_DIR/images_yaml"

patch_alpine_vm_boot() {
    local file_name="${1:-alpine.yaml}"

    sed -i 's#same_as: .*#same_as: 3.21#' "$file_name"
    sed -i 's#url: .*alpine/.*#url: https://dl-cdn.alpinelinux.org/alpine/#' "$file_name"
    sed -i 's#GRUB_CMDLINE_LINUX_DEFAULT="console=tty1 console=ttyS0 modules={{ targets.incus.vm.filesystem }} rootfstype={{ targets.incus.vm.filesystem }}"#GRUB_CMDLINE_LINUX_DEFAULT="console=tty1 console=ttyS0 modules=sd-mod,usb-storage,{{ targets.incus.vm.filesystem }} rootfstype={{ targets.incus.vm.filesystem }}"#' "$file_name"

    if ! grep -q '^    - udev$' "$file_name"; then
        sed -i '/    - linux-virt/a\    - udev' "$file_name"
    fi

    sed -i 's#for svc_name in devfs dmesg hwdrivers mdev; do#for svc_name in devfs dmesg hwdrivers mdev udev udev-settle udev-trigger; do#' "$file_name"
    sed -i 's#grub-install --target=${TARGET}-efi --no-nvram --removable#grub-install --target=${TARGET}-efi --efi-directory=/boot/efi --no-nvram --removable#' "$file_name"
    sed -i 's#grub-install --target=${TARGET}-efi --no-nvram$#grub-install --target=${TARGET}-efi --efi-directory=/boot/efi --no-nvram#' "$file_name"

    if ! grep -q 'BOOT_EFI="/boot/efi/EFI/BOOT/BOOTX64.EFI"' "$file_name"; then
        sed -i '/grub-install --target=${TARGET}-efi --efi-directory=\/boot\/efi --no-nvram$/a\
    BOOT_EFI="/boot/efi/EFI/BOOT/BOOTX64.EFI"\
    [ "${TARGET}" = "arm64" ] && BOOT_EFI="/boot/efi/EFI/BOOT/BOOTAA64.EFI"\
    test -s "${BOOT_EFI}"' "$file_name"
    fi

    sed -i 's#rm /etc/update-grub.conf#rm -f /etc/update-grub.conf#' "$file_name"
}

# debian
rm -rf debian.yaml
wget https://raw.githubusercontent.com/lxc/lxc-ci/main/images/debian.yaml
insert_content_1="    - curl\n    - wget\n    - bash\n    - lsof\n    - sshpass\n    - openssh-server\n    - iptables\n    - dos2unix\n    - cron"
sed -i "/- vim/ a\\$insert_content_1" debian.yaml
"$CI_IMAGE_PYTHON" "$CI_IMAGE_SCRIPT_ROOT/append_image_actions.py" "debian.yaml" "$CI_IMAGE_SCRIPT_ROOT/../../bash_insert_content.text"
sed -i -e '/mappings:/i \ ' debian.yaml

# ubuntu
rm -rf ubuntu.yaml
wget https://raw.githubusercontent.com/lxc/lxc-ci/main/images/ubuntu.yaml
insert_content_1="    - curl\n    - wget\n    - bash\n    - lsof\n    - sshpass\n    - openssh-server\n    - iptables\n    - dos2unix\n    - cron"
sed -i "/- vim/ a\\$insert_content_1" ubuntu.yaml
"$CI_IMAGE_PYTHON" "$CI_IMAGE_SCRIPT_ROOT/append_image_actions.py" "ubuntu.yaml" "$CI_IMAGE_SCRIPT_ROOT/../../bash_insert_content.text"
sed -i -e '/mappings:/i \ ' ubuntu.yaml

# kali
rm -rf kali.yaml
wget https://raw.githubusercontent.com/lxc/lxc-ci/main/images/kali.yaml
insert_content_1="    - curl\n    - wget\n    - bash\n    - lsof\n    - sshpass\n    - openssh-server\n    - iptables\n    - dos2unix\n    - cron"
sed -i "/- systemd/ a\\$insert_content_1" kali.yaml
"$CI_IMAGE_PYTHON" "$CI_IMAGE_SCRIPT_ROOT/append_image_actions.py" "kali.yaml" "$CI_IMAGE_SCRIPT_ROOT/../../bash_insert_content.text"
sed -i -e '/mappings:/i \ ' kali.yaml

# centos
rm -rf centos.yaml
wget https://raw.githubusercontent.com/lxc/lxc-ci/main/images/centos.yaml
# epel-relase 不可用 cron 不可用
insert_content_1="    - curl\n    - wget\n    - bash\n    - lsof\n    - sshpass\n    - openssh-server\n    - iptables\n    - dos2unix\n    - cronie"
sed -i "/- vim-minimal/ a\\$insert_content_1" centos.yaml
"$CI_IMAGE_PYTHON" "$CI_IMAGE_SCRIPT_ROOT/append_image_actions.py" "centos.yaml" "$CI_IMAGE_SCRIPT_ROOT/../../bash_insert_content.text"

# almalinux
rm -rf almalinux.yaml
wget https://raw.githubusercontent.com/lxc/lxc-ci/main/images/almalinux.yaml
# cron 不可用
insert_content_1="    - curl\n    - wget\n    - bash\n    - lsof\n    - sshpass\n    - openssh-server\n    - iptables\n    - dos2unix\n    - cronie"
sed -i "/- vim-minimal/ a\\$insert_content_1" almalinux.yaml
"$CI_IMAGE_PYTHON" "$CI_IMAGE_SCRIPT_ROOT/append_image_actions.py" "almalinux.yaml" "$CI_IMAGE_SCRIPT_ROOT/../../bash_insert_content.text"

# rockylinux
rm -rf rockylinux.yaml
wget https://raw.githubusercontent.com/lxc/lxc-ci/main/images/rockylinux.yaml
# cron 不可用
insert_content_1="    - curl\n    - wget\n    - bash\n    - lsof\n    - sshpass\n    - openssh-server\n    - iptables\n    - dos2unix\n    - cronie"
sed -i "/- vim-minimal/ a\\$insert_content_1" rockylinux.yaml
"$CI_IMAGE_PYTHON" "$CI_IMAGE_SCRIPT_ROOT/append_image_actions.py" "rockylinux.yaml" "$CI_IMAGE_SCRIPT_ROOT/../../bash_insert_content.text"

# oracle
rm -rf oracle.yaml
wget https://raw.githubusercontent.com/lxc/lxc-ci/main/images/oracle.yaml
# cron 不可用
insert_content_1="    - curl\n    - wget\n    - bash\n    - lsof\n    - sshpass\n    - openssh-server\n    - iptables\n    - dos2unix\n    - cronie"
sed -i "/- vim-minimal/ a\\$insert_content_1" oracle.yaml
"$CI_IMAGE_PYTHON" "$CI_IMAGE_SCRIPT_ROOT/append_image_actions.py" "oracle.yaml" "$CI_IMAGE_SCRIPT_ROOT/../../bash_insert_content.text"

# archlinux
rm -rf archlinux.yaml
wget https://raw.githubusercontent.com/lxc/lxc-ci/main/images/archlinux.yaml
# cronie 不可用 cron 不可用
insert_content_1="    - curl\n    - wget\n    - bash\n    - lsof\n    - sshpass\n    - iptables\n    - dos2unix"
sed -i "/- which/ a\\$insert_content_1" archlinux.yaml
"$CI_IMAGE_PYTHON" "$CI_IMAGE_SCRIPT_ROOT/append_image_actions.py" "archlinux.yaml" "$CI_IMAGE_SCRIPT_ROOT/../../bash_insert_content.text"
sed -i -e '/mappings:/i \ ' archlinux.yaml

# gentoo
rm -rf gentoo.yaml
wget https://raw.githubusercontent.com/lxc/lxc-ci/main/images/gentoo.yaml
# cronie 不可用 cron 不可用
insert_content_1="    - curl\n    - wget\n    - bash\n    - lsof\n    - sshpass\n    - iptables\n    - dos2unix"
sed -i "/- sudo/ a\\$insert_content_1" gentoo.yaml
"$CI_IMAGE_PYTHON" "$CI_IMAGE_SCRIPT_ROOT/append_image_actions.py" "gentoo.yaml" "$CI_IMAGE_SCRIPT_ROOT/../../bash_insert_content.text"
sed -i -e '/environment:/i \ ' gentoo.yaml
sed -i 's/- default/- openrc/g' gentoo.yaml

# fedora
rm -rf fedora.yaml
wget https://raw.githubusercontent.com/lxc/lxc-ci/main/images/fedora.yaml
# cron 不可用
insert_content_1="    - curl\n    - wget\n    - bash\n    - lsof\n    - sshpass\n    - openssh-server\n    - iptables\n    - dos2unix\n    - cronie"
sed -i "/- xz/ a\\$insert_content_1" fedora.yaml
"$CI_IMAGE_PYTHON" "$CI_IMAGE_SCRIPT_ROOT/append_image_actions.py" "fedora.yaml" "$CI_IMAGE_SCRIPT_ROOT/../../bash_insert_content.text"

# alpine
rm -rf alpine.yaml
wget https://raw.githubusercontent.com/lxc/lxc-ci/main/images/alpine.yaml
# cronie 不可用 cron 不可用
insert_content_1="    - curl\n    - wget\n    - bash\n    - lsof\n    - sshpass\n    - openssh-server\n    - openssh-keygen\n    - cronie\n    - iptables\n    - dos2unix"
sed -i "/- doas/ a\\$insert_content_1" alpine.yaml
"$CI_IMAGE_PYTHON" "$CI_IMAGE_SCRIPT_ROOT/append_image_actions.py" "alpine.yaml" "$CI_IMAGE_SCRIPT_ROOT/../../sh_insert_content.text"
patch_alpine_vm_boot alpine.yaml
sed -i -e '/mappings:/i \ ' alpine.yaml

# openwrt
rm -rf openwrt.yaml
wget https://raw.githubusercontent.com/lxc/lxc-ci/main/images/openwrt.yaml
# cronie 不可用 cron 不可用
insert_content_1="    - curl\n    - wget\n    - bash\n    - lsof\n    - sshpass\n    - openssh-server\n    - openssh-keygen\n    - iptables"
sed -i "/- sudo/ a\\$insert_content_1" openwrt.yaml

# opensuse
rm -rf opensuse.yaml
wget https://raw.githubusercontent.com/lxc/lxc-ci/main/images/opensuse.yaml
# cron 不可用
insert_content_1="    - curl\n    - wget\n    - bash\n    - lsof\n    - sshpass\n    - openssh-server\n    - iptables\n    - dos2unix\n    - cronie"
sed -i "/- vim-minimal/ a\\$insert_content_1" opensuse.yaml
"$CI_IMAGE_PYTHON" "$CI_IMAGE_SCRIPT_ROOT/append_image_actions.py" "opensuse.yaml" "$CI_IMAGE_SCRIPT_ROOT/../../bash_insert_content.text"

# openeuler
rm -rf openeuler.yaml
wget https://raw.githubusercontent.com/lxc/lxc-ci/main/images/openeuler.yaml
# cron 不可用
insert_content_1="    - curl\n    - wget\n    - bash\n    - lsof\n    - sshpass\n    - openssh-server\n    - iptables\n    - dos2unix\n    - cronie"
sed -i "/- vim-minimal/ a\\$insert_content_1" openeuler.yaml
"$CI_IMAGE_PYTHON" "$CI_IMAGE_SCRIPT_ROOT/append_image_actions.py" "openeuler.yaml" "$CI_IMAGE_SCRIPT_ROOT/../../bash_insert_content.text"

cd "$REPO_DIR"
