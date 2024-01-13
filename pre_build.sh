#!/bin/bash
# from https://github.com/oneclickvirt/incus_images


snap install distrobuilder --classic
apt-get install debootstrap -y
rm -r images
mkdir images
cd ./images
debian_versions=("stretch" "buster" "bullseye" "bookworm" "trixie")
architectures=("amd64" "arm64" "armel" "armhf" "i386" "ppc64el" "s390x")
variants=("default", "cloud")
mkdir debian
cd ./debian
for version in "${debian_versions[@]}"; do
    for arch in "${architectures[@]}"; do
        for variant in "${variants[@]}"; do
            mkdir ${version}
            cd ./${version}
            mkdir ${arch}
            cd ./${arch}
            mkdir ${variant}
            cd ./${variant}
            distrobuilder build-incus /home/runner/work/incus_images/incus_images/images_yaml/debian.yaml -o image.release=${version} -o image.architecture=${arch} -o image.variant=${variant}
            cd ..
            cd ..
            cd ..
        done
    done
done
