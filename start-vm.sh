#!/usr/bin/env bash

set -euo pipefail

# ============================================================================
# start-vm.sh - start the existing Debian VM.
#
# * user-mode networking (netdev) with SSH forwarded on host port 2222 -> 
#   guest port 22.
# * this directory is shared into the guest as a 9p virtio mount.
#
# Inside the guest, mount the share once:
#
#   sudo mkdir -p /home/debian
#   sudo mount -t 9p -o trans=virtio,version=9p2000.L hostshare /home/debian
#
# For persistence add to /etc/fstab:
#   hostshare  /home/debian  9p  trans=virtio,version=9p2000.L  0 0
# ============================================================================

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DISK="$DIR/debian-vm.qcow2"

MEMORY=2048
CPUS=2
HOST_SHARE="$DIR"

NETDEV="user,id=net0,hostfwd=tcp::2222-:22"

if [ ! -f "$DISK" ]; then
    echo "No disk image at $DISK. Run create-vm.sh first." >&2
    exit 1
fi

echo ">> Starting VM (press Ctrl-A X to quit qemu)"
echo ">> SSH into guest: ssh -p 2222 debian@127.0.0.1 (password: debian)"
exec qemu-system-x86_64 \
    -enable-kvm \
    -machine accel=kvm,type=q35 \
    -m "$MEMORY" \
    -smp "$CPUS" \
    -drive file="$DISK",if=virtio,format=qcow2 \
    -netdev "$NETDEV" \
    -device virtio-net-pci,netdev=net0 \
    -virtfs local,path="$HOST_SHARE",mount_tag=hostshare,security_model=none,id=hostshare \
    -nographic
