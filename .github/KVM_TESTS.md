# KVM image validation

The weekly workflow validates the published Debian 12 and Alpine 3.22 x86_64 default images. Select `scope=full` manually to test all published x86_64 assets. The matrix is taken from the actual `kvm_images` release rather than generating filenames for unpublished images.

Hosted `ubuntu-24.04-arm` runners do not expose `/dev/kvm` (verified 2026-10-13). ARM KVM execution is disabled until a dedicated ARM host with hardware virtualization is available; ARM image builds and publication continue separately.

An installation canary must pass before the image matrix starts. Each fresh runner installs Ubuntu's native QEMU, OVMF and swtpm dependencies and checks the QEMU driver. Installer output is retained in the job log, and an image test failure returns a nonzero status. The Incus installer uses JSON profile inventories compatible with the Ubuntu LTS client.
