#!/bin/bash
# from https://github.com/oneclickvirt/incus_images

wget https://raw.githubusercontent.com/lxc/lxc-ci/main/images/debian.yaml
chmod 777 debian.yaml
sed -i 's/- vim\n    action: install/- vim\n    - curl\n    - wget\n    - bash\n    - lsof\n    - sshpass\n    - openssh-server\n    - iptables\n    - dos2unix\n    action: install/g' debian.yaml
insert_content=$(cat bash_insert_content.text)
sed -i -e "/mappings:/i $(echo "$insert_content" | sed 's/\//\\\//g')" debian.yaml
