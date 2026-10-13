#!/usr/bin/env bash
set -euo pipefail

if [[ "$(uname -m)" != x86_64 ]] || [[ ! -c /dev/kvm ]]; then
    printf 'This test requires an x86_64 host with /dev/kvm.\n' >&2
    exit 1
fi

sudo apt-get update -y
# Ubuntu splits VM dependencies into incus-extra; incus alone can only run containers.
sudo apt-get install -y --no-install-recommends incus-extra unzip jq
curl --fail --show-error --location --retry 2 --connect-timeout 20 --max-time 120 \
    https://raw.githubusercontent.com/oneclickvirt/incus/main/scripts/incus_install.sh \
    --output "$RUNNER_TEMP/incus_install.sh"
sudo env noninteractive=true WITHOUTCDN=true INCUS_DISK_SIZE=12 \
    timeout 900 bash "$RUNNER_TEMP/incus_install.sh" 2>&1 | tee "$RUNNER_TEMP/incus-install.log"
sudo incus query /1.0 | jq -e '(.metadata // .).environment.driver | split(" | ") | index("qemu") != null'
