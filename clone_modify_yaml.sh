#!/bin/bash
# from https://github.com/oneclickvirt/incus_images

wget https://raw.githubusercontent.com/lxc/lxc-ci/main/images/debian.yaml
chmod 777 debian.yaml
sed -i 's/- vim\n    action: install/- vim\n    - curl\n    - wget\n    - bash\n    - lsof\n    - sshpass\n    - openssh-server\n    - iptables\n    - dos2unix\n    action: install/g' debian.yaml
insert_content="
- trigger: post-files
  action: |-
    #!/bin/sh
    set -eux

    systemctl disable iptables || true
    systemctl enable sshd || true
    systemctl enable ssh || true
    # sshd_config
    sed -i \"s/^#\\?Port.*/Port 22/g\" /etc/ssh/sshd_config || true
    sed -i \"s/^#\\?PermitRootLogin.*/PermitRootLogin yes/g\" /etc/ssh/sshd_config || true
    sed -i \"s/^#\\?PasswordAuthentication.*/PasswordAuthentication yes/g\" /etc/ssh/sshd_config || true
    sed -i 's/#ListenAddress 0.0.0.0/ListenAddress 0.0.0.0/' /etc/ssh/sshd_config || true
    sed -i 's/#ListenAddress ::/ListenAddress ::/' /etc/ssh/sshd_config || true
    sed -i 's/#AddressFamily any/AddressFamily any/' /etc/ssh/sshd_config || true
    sed -i \"s/^#\\?PubkeyAuthentication.*/PubkeyAuthentication no/g\" /etc/ssh/sshd_config || true
    sed -i '/^#UsePAM\\|UsePAM/c #UsePAM no' /etc/ssh/sshd_config || true
    sed -i '/^AuthorizedKeysFile/s/^/#/' /etc/ssh/sshd_config || true
    # cloud-init
    sed -i \"s/^#\\?Port.*/Port 22/g\" /etc/ssh/sshd_config.d/50-cloud-init.conf || true
    sed -i \"s/^#\\?PermitRootLogin.*/PermitRootLogin yes/g\" /etc/ssh/sshd_config.d/50-cloud-init.conf || true
    sed -i \"s/^#\\?PasswordAuthentication.*/PasswordAuthentication yes/g\" /etc/ssh/sshd_config.d/50-cloud-init.conf || true
    sed -i 's/#ListenAddress 0.0.0.0/ListenAddress 0.0.0.0/' /etc/ssh/sshd_config.d/50-cloud-init.conf || true
    sed -i 's/#ListenAddress ::/ListenAddress ::/' /etc/ssh/sshd_config.d/50-cloud-init.conf || true
    sed -i 's/#AddressFamily any/AddressFamily any/' /etc/ssh/sshd_config.d/50-cloud-init.conf || true
    sed -i \"s/^#\\?PubkeyAuthentication.*/PubkeyAuthentication no/g\" /etc/ssh/sshd_config.d/50-cloud-init.conf || true
    sed -i '/^#UsePAM\\|UsePAM/c #UsePAM no' /etc/ssh/sshd_config.d/50-cloud-init.conf || true
    sed -i '/^AuthorizedKeysFile/s/^/#/' /etc/ssh/sshd_config.d/50-cloud-init.conf || true
    # other config
    sed -i.bak '/^SELINUX=/cSELINUX=disabled' /etc/sysconfig/selinux || true
    sed -i.bak '/^SELINUX=/cSELINUX=disabled' /etc/selinux/config || true
"
sed -i "/mappings:/i $insert_content" debian.yaml
