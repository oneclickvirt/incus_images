#!/bin/bash

wget https://raw.githubusercontent.com/lxc/lxc-ci/main/images/debian.yaml
chmod 777 debian.yaml
insert_content_1="    - curl\n    - wget\n    - bash\n    - lsof\n    - sshpass\n    - openssh-server\n    - iptables\n    - dos2unix"
sed -i "/- vim/ a\\$insert_content_1" debian.yaml
insert_content_2=$(cat bash_insert_content.text)
line_number=$(($(wc -l < debian.yaml) - 2))
head -n $line_number debian.yaml > temp.yaml
echo "$insert_content_2" >> temp.yaml
tail -n 2 debian.yaml >> temp.yaml
mv temp.yaml debian.yaml
