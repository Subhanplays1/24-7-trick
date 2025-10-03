#!/bin/bash
# Automated Debian VM Installer using QEMU

set -e

VM_NAME="DebianVM"
VM_DISK="$HOME/${VM_NAME}.img"
DEBIAN_ISO="$HOME/debian.iso"
MEMORY="2048"  # RAM in MB
CPU_CORES="2"

# Step 1: Download Debian ISO if not present
if [ ! -f "$DEBIAN_ISO" ]; then
    echo "[*] Downloading Debian ISO..."
    wget -O "$DEBIAN_ISO" "https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/debian-12.7.0-amd64-netinst.iso"
fi

# Step 2: Create VM disk
if [ ! -f "$VM_DISK" ]; then
    echo "[*] Creating VM disk (20GB)..."
    qemu-img create -f qcow2 "$VM_DISK" 20G
fi

# Step 3: Launch VM
echo "[*] Starting Debian VM..."
qemu-system-x86_64 \
    -name "$VM_NAME" \
    -m $MEMORY \
    -smp $CPU_CORES \
    -boot d \
    -cdrom "$DEBIAN_ISO" \
    -drive file="$VM_DISK",format=qcow2 \
    -net nic -net user \
    -enable-kvm \
    -vga virtio

echo "[*] VM launched. Install Debian from the ISO in the window."
