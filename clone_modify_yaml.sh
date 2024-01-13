#!/bin/bash

wget https://raw.githubusercontent.com/lxc/lxc-ci/main/images/debian.yaml
chmod 777 debian.yaml
sed -i 's/- vim\n    action: install/- vim\n    - curl\n    - wget\n    - bash\n    - lsof\n    - sshpass\n    - openssh-server\n    - iptables\n    - dos2unix\n    action: install/g' debian.yaml
insert_content=$(cat bash_insert_content.text)
sed -i -e "$(($(wc -l < debian.yaml) - 2))i\\$insert_content" debian.yaml
