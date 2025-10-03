#!/bin/bash
set -e

echo "[INFO] Installing dependencies..."
apt-get update -qq
apt-get install -y -qq proot wget tar > /dev/null

echo "[INFO] Downloading Ubuntu 22.04 rootfs..."
wget -qO ubuntu-rootfs.tar.gz \
  https://partner-images.canonical.com/core/jammy/current/ubuntu-jammy-core-cloudimg-amd64-root.tar.gz

echo "[INFO] Extracting rootfs..."
mkdir -p ubuntu-fs
tar -xzf ubuntu-rootfs.tar.gz -C ubuntu-fs

echo "[INFO] Entering Ubuntu in proot..."
proot -R ubuntu-fs /bin/bash <<'EOF'
set -e

# Fix minimal environment
apt-get update -qq
apt-get install -y -qq apt-utils dialog sudo less vim curl wget iproute2 net-tools > /dev/null

echo "=================================================="
echo " Welcome to your Ubuntu 22.04 fake VM (proot mode)"
echo " You can now run apt-get, install tools, etc."
echo "=================================================="

# Start interactive shell
bash
EOF
