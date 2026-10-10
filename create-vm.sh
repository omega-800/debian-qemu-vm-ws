#!/usr/bin/env bash

set -euo pipefail

# ============================================================================
# create-vm.sh - create new QEMU Debian VM and boot installer with preseed.cfg
#
# Requires: qemu-system-x86_64, qemu-img, 7z, cpio, gzip, wget
# ============================================================================

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ISO_URL="https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/debian-13.7.0-amd64-netinst.iso"
ISO="$DIR/${ISO_URL##*/}"
PRESEED="$DIR/preseed.cfg"
DISK="$DIR/debian-vm.qcow2"
EXTRACT_DIR="$DIR/.install"

MEMORY=2048
CPUS=2
DISK_SIZE=20G

NETDEV="user,id=net0,hostfwd=tcp::2222-:22"

extract_kernel() {
    echo ">> Extracting kernel/initrd from ISO"
    mkdir -p "$EXTRACT_DIR"
    7z x -y -o"$EXTRACT_DIR" "$ISO" install.amd/vmlinuz install.amd/initrd.gz >/dev/null
}

build_preseed_initrd() {
    local initrd="$EXTRACT_DIR/install.amd/initrd.gz"
    local out="$EXTRACT_DIR/preseed-initrd.gz"
    local tmp="$EXTRACT_DIR/initrd-tree"
    echo ">> Injecting preseed.cfg into initrd"
    rm -rf "$tmp"
    mkdir -p "$tmp"
    zcat "$initrd" | (cd "$tmp" && cpio -id)
    cp "$PRESEED" "$tmp/preseed.cfg"
    (cd "$tmp" && find . | cpio -o -H newc | gzip -9 > "$out")
}

if [ ! -f "$ISO" ]; then 
    echo ">> Downloading ISO $ISO ($ISO_URL)"
    wget "$ISO_URL"
else
    echo ">> ISO $ISO already exists, reusing it"
fi

if [ ! -f "$DISK" ]; then
    echo ">> Creating disk image $DISK ($DISK_SIZE)"
    qemu-img create -f qcow2 "$DISK" "$DISK_SIZE"
else
    echo ">> Disk $DISK already exists, reusing it"
fi

extract_kernel
build_preseed_initrd

echo ">> Starting installer (press Ctrl-A X to quit qemu)"
exec qemu-system-x86_64 \
    -enable-kvm \
    -machine accel=kvm,type=q35 \
    -m "$MEMORY" \
    -smp "$CPUS" \
    -kernel "$EXTRACT_DIR/install.amd/vmlinuz" \
    -initrd "$EXTRACT_DIR/preseed-initrd.gz" \
    -append "auto=true priority=critical preseed/file=/preseed.cfg console=ttyS0" \
    -nographic \
    -drive file="$DISK",if=virtio,format=qcow2 \
    -cdrom "$ISO" \
    -boot d \
    -netdev "$NETDEV" \
    -device virtio-net-pci,netdev=net0
