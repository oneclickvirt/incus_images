# KVM image validation

The weekly workflow validates the published Debian 12 and Alpine 3.22 x86_64 default images. Select `scope=full` manually to test all published x86_64 assets. The matrix is taken from the actual `kvm_images` release rather than generating filenames for unpublished images.

Hosted `ubuntu-24.04-arm` runners do not expose `/dev/kvm` (verified 2026-10-13). ARM KVM execution is disabled until a dedicated ARM host with hardware virtualization is available; ARM image builds and publication continue separately.

A runtime canary must pass before the image matrix starts. Each fresh runner installs Ubuntu's native Incus, QEMU, OVMF and swtpm packages, initializes an isolated bridge/root pool, and checks the QEMU driver. Production installer changes to the runner's DNS, cloud-init and firewall persistence are outside this image test. Runtime setup output is retained in the job log, and an image test failure returns a nonzero status. Incus installer compatibility and network regressions are checked separately by the Incus repository's Shell CI.

Guest networking is checked with its existing DNS configuration. The probe uses the GitHub origin first, with a bounded CDN fallback, so a failed CDN alone cannot invalidate a working image.

QEMU's SPICE module is explicitly installed because Incus uses it for the VM console even in headless tests. Alpine, Arch, Gentoo and OpenWrt images must declare `requirements.secureboot=false` in their metadata; only these verified images set `security.secureboot=false` on their test instance. Other images keep the default Secure Boot setting.
