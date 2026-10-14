#!/usr/bin/env bash
set -euo pipefail

[[ "${RUNNER_ENVIRONMENT:-}" == github-hosted ]] || {
    printf 'This initialization is restricted to a disposable GitHub-hosted runner.\n' >&2
    exit 1
}
if [[ "$(uname -m)" != x86_64 ]] || [[ ! -c /dev/kvm ]]; then
    printf 'This test requires an x86_64 host with /dev/kvm.\n' >&2
    exit 1
fi

source .github/scripts/ci_network.sh
ci_retry sudo apt-get update -y
# Ubuntu 24.04 provides the VM tools as native QEMU/firmware packages.
ci_retry sudo apt-get install -y --no-install-recommends incus incus-agent qemu-system-x86 qemu-system-modules-spice qemu-utils ovmf swtpm dnsmasq-base unzip jq virtiofsd genisoimage
# Ubuntu installs the VM agent outside the interactive shell's PATH.
dpkg-query -W -f='${Package} ${Version} ${Status}\n' incus-agent
sudo systemctl start incus
sudo incus admin waitready --timeout=120
# The image test needs an isolated bridge and root pool. Production installer
# changes to host DNS, cloud-init and firewall persistence are unnecessary here.
sudo incus admin init --preseed <<'PRESEED'
config: {}
networks:
  - name: incusbr0
    type: bridge
    config:
      ipv4.address: auto
      ipv4.dhcp: "true"
      ipv4.nat: "true"
      ipv6.address: none
storage_pools:
  - name: default
    driver: dir
profiles:
  - name: default
    devices:
      root:
        type: disk
        path: /
        pool: default
      eth0:
        type: nic
        network: incusbr0
        name: eth0
      agent-config:
        type: disk
        source: agent:config
PRESEED
# Docker's preinstalled FORWARD policy can otherwise drop the Incus bridge.
# Keep these ephemeral test rules scoped to this bridge.
sudo iptables -I FORWARD -i incusbr0 -j ACCEPT
sudo iptables -I FORWARD -o incusbr0 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
sudo incus query /1.0 | jq -e '(.metadata // .).environment.driver | split(" | ") | index("qemu") != null'
