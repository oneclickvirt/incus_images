#!/bin/bash
# from https://github.com/oneclickvirt/incus_images
# Thanks https://github.com/lxc/lxc-ci/tree/main/images

cd /home/runner/work/incus_images/incus_images/images_yaml/
# debian
rm -rf debian.yaml
wget https://raw.githubusercontent.com/lxc/lxc-ci/main/images/debian.yaml
chmod 777 debian.yaml
insert_content_1="    - curl\n    - wget\n    - bash\n    - lsof\n    - sshpass\n    - openssh-server\n    - iptables\n    - dos2unix\n    - cron"
sed -i "/- vim/ a\\$insert_content_1" debian.yaml
insert_content_2=$(cat /home/runner/work/incus_images/incus_images/bash_insert_content.text)
line_number=$(($(wc -l < debian.yaml) - 2))
head -n $line_number debian.yaml > temp.yaml
echo "$insert_content_2" >> temp.yaml
tail -n 2 debian.yaml >> temp.yaml
mv temp.yaml debian.yaml
sed -i -e '/mappings:/i \ ' debian.yaml

# ubuntu
rm -rf ubuntu.yaml
wget https://raw.githubusercontent.com/lxc/lxc-ci/main/images/ubuntu.yaml
chmod 777 ubuntu.yaml
insert_content_1="    - curl\n    - wget\n    - bash\n    - lsof\n    - sshpass\n    - openssh-server\n    - iptables\n    - dos2unix\n    - cron"
sed -i "/- vim/ a\\$insert_content_1" ubuntu.yaml
insert_content_2=$(cat /home/runner/work/incus_images/incus_images/bash_insert_content.text)
line_number=$(($(wc -l < ubuntu.yaml) - 2))
head -n $line_number ubuntu.yaml > temp.yaml
echo "$insert_content_2" >> temp.yaml
tail -n 2 ubuntu.yaml >> temp.yaml
mv temp.yaml ubuntu.yaml
sed -i -e '/mappings:/i \ ' ubuntu.yaml

# kali
rm -rf kali.yaml
wget https://raw.githubusercontent.com/lxc/lxc-ci/main/images/kali.yaml
chmod 777 kali.yaml
insert_content_1="    - curl\n    - wget\n    - bash\n    - lsof\n    - sshpass\n    - openssh-server\n    - iptables\n    - dos2unix\n    - cron"
sed -i "/- systemd/ a\\$insert_content_1" kali.yaml
insert_content_2=$(cat /home/runner/work/incus_images/incus_images/bash_insert_content.text)
line_number=$(($(wc -l < kali.yaml) - 2))
head -n $line_number kali.yaml > temp.yaml
echo "$insert_content_2" >> temp.yaml
tail -n 2 kali.yaml >> temp.yaml
mv temp.yaml kali.yaml
sed -i -e '/mappings:/i \ ' kali.yaml

# centos
rm -rf centos.yaml
wget https://raw.githubusercontent.com/lxc/lxc-ci/main/images/centos.yaml
chmod 777 centos.yaml
insert_content_1="    - curl\n    - wget\n    - bash\n    - lsof\n    - sshpass\n    - openssh-server\n    - iptables\n    - dos2unix\n    - cronie"
sed -i "/- vim-minimal/ a\\$insert_content_1" centos.yaml
insert_content_2=$(cat /home/runner/work/incus_images/incus_images/bash_insert_content.text)
cat centos.yaml > temp.yaml
echo "" >> temp.yaml
echo "$insert_content_2" >> temp.yaml
mv temp.yaml centos.yaml

# almalinux
rm -rf almalinux.yaml
wget https://raw.githubusercontent.com/lxc/lxc-ci/main/images/almalinux.yaml
chmod 777 almalinux.yaml
insert_content_1="    - curl\n    - wget\n    - bash\n    - lsof\n    - sshpass\n    - openssh-server\n    - iptables\n    - dos2unix\n    - cronie"
sed -i "/- vim-minimal/ a\\$insert_content_1" almalinux.yaml
insert_content_2=$(cat /home/runner/work/incus_images/incus_images/bash_insert_content.text)
cat almalinux.yaml > temp.yaml
echo "" >> temp.yaml
echo "$insert_content_2" >> temp.yaml
mv temp.yaml almalinux.yaml

# rockylinux
rm -rf rockylinux.yaml
wget https://raw.githubusercontent.com/lxc/lxc-ci/main/images/rockylinux.yaml
chmod 777 rockylinux.yaml
insert_content_1="    - curl\n    - wget\n    - bash\n    - lsof\n    - sshpass\n    - openssh-server\n    - iptables\n    - dos2unix\n    - cronie"
sed -i "/- vim-minimal/ a\\$insert_content_1" rockylinux.yaml
insert_content_2=$(cat /home/runner/work/incus_images/incus_images/bash_insert_content.text)
cat rockylinux.yaml > temp.yaml
echo "" >> temp.yaml
echo "$insert_content_2" >> temp.yaml
mv temp.yaml rockylinux.yaml

# archlinux
rm -rf archlinux.yaml
wget https://raw.githubusercontent.com/lxc/lxc-ci/main/images/archlinux.yaml
chmod 777 archlinux.yaml
insert_content_1="    - curl\n    - wget\n    - bash\n    - lsof\n    - sshpass\n    - openssh-server\n    - openssh-keygen\n    - cronie\n    - cron\n    - iptables\n    - dos2unix"
sed -i "/- which/ a\\$insert_content_1" archlinux.yaml
insert_content_2=$(cat /home/runner/work/incus_images/incus_images/bash_insert_content.text)
line_number=$(($(wc -l < archlinux.yaml) - 2))
head -n $line_number archlinux.yaml > temp.yaml
echo "$insert_content_2" >> temp.yaml
tail -n 2 archlinux.yaml >> temp.yaml
mv temp.yaml archlinux.yaml
sed -i -e '/mappings:/i \ ' archlinux.yaml

# oracle
rm -rf oracle.yaml
wget https://raw.githubusercontent.com/lxc/lxc-ci/main/images/oracle.yaml
chmod 777 oracle.yaml
insert_content_1="    - curl\n    - wget\n    - bash\n    - lsof\n    - sshpass\n    - openssh-server\n    - iptables\n    - dos2unix\n    - cronie"
sed -i "/- vim-minimal/ a\\$insert_content_1" oracle.yaml
insert_content_2=$(cat /home/runner/work/incus_images/incus_images/bash_insert_content.text)
cat oracle.yaml > temp.yaml
echo "" >> temp.yaml
echo "$insert_content_2" >> temp.yaml
mv temp.yaml oracle.yaml

# alpine
rm -rf alpine.yaml
wget https://raw.githubusercontent.com/lxc/lxc-ci/main/images/alpine.yaml
chmod 777 alpine.yaml
insert_content_1="    - curl\n    - wget\n    - bash\n    - lsof\n    - sshpass\n    - openssh-server\n    - openssh-keygen\n    - cronie\n    - iptables\n    - dos2unix"
sed -i "/- doas/ a\\$insert_content_1" alpine.yaml
insert_content_2=$(cat /home/runner/work/incus_images/incus_images/sh_insert_content.text)
line_number=$(($(wc -l < alpine.yaml) - 2))
head -n $line_number alpine.yaml > temp.yaml
echo "$insert_content_2" >> temp.yaml
tail -n 2 alpine.yaml >> temp.yaml
mv temp.yaml alpine.yaml
sed -i -e '/mappings:/i \ ' alpine.yaml

# openwrt
rm -rf openwrt.yaml
wget https://raw.githubusercontent.com/lxc/lxc-ci/main/images/openwrt.yaml
chmod 777 openwrt.yaml
insert_content_1="    - curl\n    - wget\n    - bash\n    - lsof\n    - sshpass\n    - openssh-server\n    - openssh-keygen\n    - cronie\n    - iptables\n    - dos2unix"
sed -i "/- sudo/ a\\$insert_content_1" openwrt.yaml
insert_content_2=$(cat /home/runner/work/incus_images/incus_images/sh_insert_content.text)
cat openwrt.yaml > temp.yaml
echo "$insert_content_2" >> temp.yaml
mv temp.yaml openwrt.yaml
