#!/bin/bash

# Simple VM Creator for CodeSandbox Docker
# This script creates a QEMU VM with basic configuration

set -e

# Configuration
VM_NAME="${1:-myvm}"
MEMORY="${2:-512M}"
DISK_SIZE="${3:-10G}"
CPUS="${4:-1}"
SSH_PORT="${5:-2222}"
USERNAME="${6:-ubuntu}"
PASSWORD="${7:-password}"

# File paths
IMG_FILE="/tmp/${VM_NAME}.img"
SEED_FILE="/tmp/${VM_NAME}-seed.iso"
BASE_IMAGE_URL="https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
print_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Check if QEMU is available
check_dependencies() {
    if ! command -v qemu-system-x86_64 &> /dev/null; then
        print_error "QEMU is not installed. Installing..."
        apt-get update && apt-get install -y qemu-system-x86 qemu-utils cloud-image-utils
    fi
}

# Download and prepare VM image
setup_vm_image() {
    print_info "Setting up VM image..."
    
    if [ ! -f "$IMG_FILE" ]; then
        print_info "Downloading base image..."
        wget -q "$BASE_IMAGE_URL" -O "$IMG_FILE"
        
        print_info "Resizing disk to $DISK_SIZE..."
        qemu-img resize "$IMG_FILE" "$DISK_SIZE"
    else
        print_info "VM image already exists, skipping download."
    fi
}

# Create cloud-init configuration
create_cloud_init() {
    print_info "Creating cloud-init configuration..."
    
    cat > /tmp/user-data << EOF
#cloud-config
hostname: $VM_NAME
manage_etc_hosts: true
users:
  - name: $USERNAME
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    password: $(echo "$PASSWORD" | openssl passwd -6 -stdin)
ssh_pwauth: true
disable_root: false
chpasswd:
  list: |
    root:$PASSWORD
    $USERNAME:$PASSWORD
  expire: false
runcmd:
  - sed -i 's/#PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
  - systemctl restart ssh
EOF

    cat > /tmp/meta-data << EOF
instance-id: iid-$VM_NAME
local-hostname: $VM_NAME
EOF

    cloud-localds "$SEED_FILE" /tmp/user-data /tmp/meta-data
}

# Start the VM
start_vm() {
    print_info "Starting VM: $VM_NAME"
    print_info "Memory: $MEMORY"
    print_info "CPUs: $CPUS"
    print_info "Disk: $DISK_SIZE"
    print_info "SSH Port: $SSH_PORT"
    print_info "Username: $USERNAME"
    print_info "Password: $PASSWORD"
    echo
    print_info "To connect via SSH: ssh -p $SSH_PORT $USERNAME@localhost"
    print_info "Press Ctrl+A then X to stop the VM"
    echo

    # Start QEMU with basic configuration
    exec qemu-system-x86_64 \
        -enable-kvm \
        -m "$MEMORY" \
        -smp "$CPUS" \
        -cpu host \
        -drive "file=$IMG_FILE,format=qcow2,if=virtio" \
        -drive "file=$SEED_FILE,format=raw,if=virtio" \
        -device virtio-net-pci,netdev=net0 \
        -netdev "user,id=net0,hostfwd=tcp::$SSH_PORT-:22" \
        -nographic \
        -serial mon:stdio
}

# Quick setup function
quick_setup() {
    print_info "Quick VM Setup"
    echo "VM Name: $VM_NAME"
    echo "Memory: $MEMORY"
    echo "Disk: $DISK_SIZE"
    echo "CPUs: $CPUS"
    echo "SSH Port: $SSH_PORT"
    echo "Username: $USERNAME"
    echo
    
    check_dependencies
    setup_vm_image
    create_cloud_init
    start_vm
}

# Interactive setup function
interactive_setup() {
    print_info "Interactive VM Setup"
    
    read -p "Enter VM name [$VM_NAME]: " input
    VM_NAME="${input:-$VM_NAME}"
    
    read -p "Enter memory size [$MEMORY]: " input
    MEMORY="${input:-$MEMORY}"
    
    read -p "Enter disk size [$DISK_SIZE]: " input
    DISK_SIZE="${input:-$DISK_SIZE}"
    
    read -p "Enter CPU count [$CPUS]: " input
    CPUS="${input:-$CPUS}"
    
    read -p "Enter SSH port [$SSH_PORT]: " input
    SSH_PORT="${input:-$SSH_PORT}"
    
    read -p "Enter username [$USERNAME]: " input
    USERNAME="${input:-$USERNAME}"
    
    read -s -p "Enter password [$PASSWORD]: " input
    PASSWORD="${input:-$PASSWORD}"
    echo
    
    IMG_FILE="/tmp/${VM_NAME}.img"
    SEED_FILE="/tmp/${VM_NAME}-seed.iso"
    
    quick_setup
}

# Show usage information
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Options:"
    echo "  quick                              Quick setup with default values"
    echo "  interactive                        Interactive setup"
    echo "  custom <name> <memory> <disk> <cpus> <ssh_port> <username> <password>"
    echo
    echo "Examples:"
    echo "  $0 quick                           # Quick setup with defaults"
    echo "  $0 interactive                     # Interactive setup"
    echo "  $0 custom myvm 1G 20G 2 2222 user pass123"
    echo
    echo "Default values:"
    echo "  VM Name: $VM_NAME"
    echo "  Memory: $MEMORY"
    echo "  Disk: $DISK_SIZE"
    echo "  CPUs: $CPUS"
    echo "  SSH Port: $SSH_PORT"
    echo "  Username: $USERNAME"
    echo "  Password: $PASSWORD"
}

# Main script
case "${1:-quick}" in
    "quick")
        quick_setup
        ;;
    "interactive")
        interactive_setup
        ;;
    "custom")
        if [ $# -ge 8 ]; then
            VM_NAME="$2"
            MEMORY="$3"
            DISK_SIZE="$4"
            CPUS="$5"
            SSH_PORT="$6"
            USERNAME="$7"
            PASSWORD="$8"
            IMG_FILE="/tmp/${VM_NAME}.img"
            SEED_FILE="/tmp/${VM_NAME}-seed.iso"
            quick_setup
        else
            print_error "Custom setup requires all parameters"
            show_usage
            exit 1
        fi
        ;;
    "-h"|"--help")
        show_usage
        ;;
    *)
        print_error "Unknown option: $1"
        show_usage
        exit 1
        ;;
esac
