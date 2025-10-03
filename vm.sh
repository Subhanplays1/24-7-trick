#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Default configuration
DEFAULT_VM_NAME="ubuntu-vm"
DEFAULT_MEMORY="2G"
DEFAULT_DISK_SIZE="20G"
DEFAULT_CPUS="2"
DEFAULT_SSH_PORT="2222"
DEFAULT_HOSTNAME="ubuntu22"
DEFAULT_USERNAME="root"
DEFAULT_PASSWORD="root"
DEFAULT_IMAGE_URL="https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img"

# File paths
IMG_DIR="./vm-images"
CONFIG_DIR="./vm-configs"

# Function to display header
display_header() {
    clear
    echo -e "${BLUE}"
    echo "╔══════════════════════════════════════╗"
    echo "║        QEMU VM Creator              ║"
    echo "║      Configuration Menu             ║"
    echo "╚══════════════════════════════════════╝"
    echo -e "${NC}"
}

# Function to initialize directories
init_directories() {
    mkdir -p "$IMG_DIR" "$CONFIG_DIR"
}

# Function to validate numeric input
validate_number() {
    local input=$1
    if [[ $input =~ ^[0-9]+$ ]]; then
        return 0
    else
        return 1
    fi
}

# Function to validate size format
validate_size() {
    local input=$1
    if [[ $input =~ ^[0-9]+[GM]$ ]]; then
        return 0
    else
        return 1
    fi
}

# Function to check port availability
check_port() {
    local port=$1
    if netstat -tuln 2>/dev/null | grep -q ":$port "; then
        return 1
    else
        return 0
    fi
}

# Main configuration menu
configure_vm() {
    display_header
    echo -e "${YELLOW}VM Configuration${NC}"
    echo "────────────────────────────"
    
    # VM Name
    read -p "Enter VM Name [$DEFAULT_VM_NAME]: " vm_name
    vm_name=${vm_name:-$DEFAULT_VM_NAME}
    
    # Memory Configuration
    while true; do
        read -p "Enter Memory [$DEFAULT_MEMORY]: " memory
        memory=${memory:-$DEFAULT_MEMORY}
        if validate_size "$memory"; then
            break
        else
            echo -e "${RED}Invalid format! Use format like '2G' or '4096M'${NC}"
        fi
    done
    
    # Disk Configuration
    while true; do
        read -p "Enter Disk Size [$DEFAULT_DISK_SIZE]: " disk_size
        disk_size=${disk_size:-$DEFAULT_DISK_SIZE}
        if validate_size "$disk_size"; then
            break
        else
            echo -e "${RED}Invalid format! Use format like '20G' or '50G'${NC}"
        fi
    done
    
    # CPU Cores
    while true; do
        read -p "Enter CPU Cores [$DEFAULT_CPUS]: " cpus
        cpus=${cpus:-$DEFAULT_CPUS}
        if validate_number "$cpus"; then
            break
        else
            echo -e "${RED}Please enter a valid number${NC}"
        fi
    done
    
    # SSH Port
    while true; do
        read -p "Enter SSH Port [$DEFAULT_SSH_PORT]: " ssh_port
        ssh_port=${ssh_port:-$DEFAULT_SSH_PORT}
        if validate_number "$ssh_port" && [ "$ssh_port" -ge 1024 ] && [ "$ssh_port" -le 65535 ]; then
            if check_port "$ssh_port"; then
                break
            else
                echo -e "${RED}Port $ssh_port is already in use!${NC}"
            fi
        else
            echo -e "${RED}Please enter a valid port (1024-65535)${NC}"
        fi
    done
    
    # Hostname
    read -p "Enter Hostname [$DEFAULT_HOSTNAME]: " hostname
    hostname=${hostname:-$DEFAULT_HOSTNAME}
    
    # Username
    read -p "Enter Username [$DEFAULT_USERNAME]: " username
    username=${username:-$DEFAULT_USERNAME}
    
    # Password
    while true; do
        read -s -p "Enter Password: " password
        echo
        if [ -n "$password" ]; then
            read -s -p "Confirm Password: " password_confirm
            echo
            if [ "$password" = "$password_confirm" ]; then
                break
            else
                echo -e "${RED}Passwords do not match!${NC}"
            fi
        else
            password="$DEFAULT_PASSWORD"
            break
        fi
    done
    
    # Image URL
    read -p "Enter Image URL [$DEFAULT_IMAGE_URL]: " image_url
    image_url=${image_url:-$DEFAULT_IMAGE_URL}
    
    # Set file paths
    IMG_FILE="$IMG_DIR/${vm_name}.img"
    SEED_FILE="$IMG_DIR/${vm_name}-seed.img"
    CONFIG_FILE="$CONFIG_DIR/${vm_name}.conf"
}

# Function to display configuration summary
show_configuration() {
    display_header
    echo -e "${GREEN}Current VM Configuration:${NC}"
    echo "──────────────────────────────────"
    echo "VM Name:      $vm_name"
    echo "Memory:       $memory"
    echo "Disk Size:    $disk_size"
    echo "CPU Cores:    $cpus"
    echo "SSH Port:     $ssh_port"
    echo "Hostname:     $hostname"
    echo "Username:     $username"
    echo "Image File:   $IMG_FILE"
    echo "Seed File:    $SEED_FILE"
    echo "Image URL:    $image_url"
    echo
    read -p "Press Enter to continue..."
}

# Function to save configuration
save_configuration() {
    cat > "$CONFIG_FILE" << EOF
# QEMU VM Configuration
VM_NAME="$vm_name"
MEMORY="$memory"
DISK_SIZE="$disk_size"
CPUS="$cpus"
SSH_PORT="$ssh_port"
HOSTNAME="$hostname"
USERNAME="$username"
PASSWORD="$password"
IMAGE_URL="$image_url"
IMG_FILE="$IMG_FILE"
SEED_FILE="$SEED_FILE"
CREATED="$(date)"
EOF
    echo -e "${GREEN}Configuration saved to: $CONFIG_FILE${NC}"
}

# Function to load configuration
load_configuration() {
    local config_files=($(ls "$CONFIG_DIR"/*.conf 2>/dev/null))
    
    if [ ${#config_files[@]} -eq 0 ]; then
        echo -e "${RED}No configuration files found!${NC}"
        return 1
    fi
    
    echo -e "${YELLOW}Available configurations:${NC}"
    for i in "${!config_files[@]}"; do
        echo "$((i+1)). $(basename "${config_files[$i]}")"
    done
    
    read -p "Select configuration (1-${#config_files[@]}): " choice
    if [[ $choice =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le ${#config_files[@]} ]; then
        source "${config_files[$((choice-1))]}"
        echo -e "${GREEN}Configuration loaded: $(basename "${config_files[$((choice-1))]}")${NC}"
        return 0
    else
        echo -e "${RED}Invalid selection!${NC}"
        return 1
    fi
}

# Function to create VM image and setup
create_vm_setup() {
    echo -e "${YELLOW}[INFO] Starting VM setup...${NC}"
    
    # Create VM image
    if [ ! -f "$IMG_FILE" ]; then
        echo -e "${GREEN}[INFO] Downloading VM image...${NC}"
        wget -q "$image_url" -O "$IMG_FILE"
        
        echo -e "${GREEN}[INFO] Resizing disk...${NC}"
        qemu-img resize "$IMG_FILE" "$disk_size"
        
        # Cloud-init config
        echo -e "${GREEN}[INFO] Creating cloud-init configuration...${NC}"
        cat > user-data << EOF
#cloud-config
hostname: $hostname
manage_etc_hosts: true
disable_root: false
ssh_pwauth: true
chpasswd:
  list: |
    $username:$password
    root:$password
  expire: false
users:
  - name: $username
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    ssh-authorized-keys: []
growpart:
  mode: auto
  devices: ["/"]
  ignore_growroot_disabled: false
resize_rootfs: true
runcmd:
  - growpart /dev/vda 1 || true
  - resize2fs /dev/vda1 || true
  - sed -ri "s/^#?PermitRootLogin.*/PermitRootLogin yes/" /etc/ssh/sshd_config
  - sed -ri "s/^#?PasswordAuthentication.*/PasswordAuthentication yes/" /etc/ssh/sshd_config
  - systemctl restart ssh
EOF

        cat > meta-data << EOF
instance-id: iid-${vm_name}
local-hostname: $hostname
EOF

        cloud-localds "$SEED_FILE" user-data meta-data
        rm -f user-data meta-data
        
        echo -e "${GREEN}[INFO] VM setup complete!${NC}"
    else
        echo -e "${YELLOW}[INFO] VM image found, skipping setup...${NC}"
    fi
}

# Function to start VM
start_vm() {
    echo -e "${YELLOW}[INFO] Starting VM...${NC}"
    echo -e "${CYAN}SSH Access: ssh $username@localhost -p $ssh_port${NC}"
    echo -e "${CYAN}Password: $password${NC}"
    echo -e "${YELLOW}Press Ctrl+A then X to stop the VM${NC}"
    echo "──────────────────────────────────"
    
    qemu-system-x86_64 \
        -enable-kvm \
        -m "$memory" \
        -smp "$cpus" \
        -cpu host \
        -drive file="$IMG_FILE",format=qcow2,if=virtio \
        -drive file="$SEED_FILE",format=raw,if=virtio \
        -boot order=c \
        -device virtio-net-pci,netdev=n0 \
        -netdev user,id=n0,hostfwd=tcp::"$ssh_port"-:22 \
        -nographic -serial mon:stdio
}

# Function to list existing VMs
list_vms() {
    display_header
    echo -e "${YELLOW}Existing VM Configurations:${NC}"
    echo "──────────────────────────────────"
    
    local config_files=($(ls "$CONFIG_DIR"/*.conf 2>/dev/null))
    
    if [ ${#config_files[@]} -eq 0 ]; then
        echo -e "${RED}No VM configurations found!${NC}"
    else
        for config in "${config_files[@]}"; do
            echo "• $(basename "$config" .conf)"
        done
    fi
    echo
    read -p "Press Enter to continue..."
}

# Main menu
main_menu() {
    while true; do
        display_header
        echo -e "${GREEN}Main Menu:${NC}"
        echo "1. Create New VM Configuration"
        echo "2. Start VM with Current Configuration"
        echo "3. Show Current Configuration"
        echo "4. Load Existing Configuration"
        echo "5. List All VMs"
        echo "6. Save Current Configuration"
        echo "7. Exit"
        echo
        read -p "Select an option (1-7): " choice
        
        case $choice in
            1)
                configure_vm
                save_configuration
                ;;
            2)
                if [ -z "$vm_name" ]; then
                    echo -e "${RED}No configuration loaded! Please create or load one first.${NC}"
                    sleep 2
                else
                    create_vm_setup
                    start_vm
                fi
                ;;
            3)
                if [ -z "$vm_name" ]; then
                    echo -e "${RED}No configuration loaded!${NC}"
                    sleep 2
                else
                    show_configuration
                fi
                ;;
            4)
                load_configuration
                sleep 2
                ;;
            5)
                list_vms
                ;;
            6)
                if [ -z "$vm_name" ]; then
                    echo -e "${RED}No configuration to save!${NC}"
                else
                    save_configuration
                fi
                sleep 2
                ;;
            7)
                echo -e "${GREEN}Goodbye!${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}Invalid option!${NC}"
                sleep 2
                ;;
        esac
    done
}

# Check dependencies
check_dependencies() {
    local deps=("qemu-system-x86_64" "qemu-img" "cloud-localds" "wget")
    local missing=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing+=("$dep")
        fi
    done
    
    if [ ${#missing[@]} -gt 0 ]; then
        echo -e "${RED}Missing dependencies: ${missing[*]}${NC}"
        echo "Please install them before running this script."
        echo "On Ubuntu/Debian: sudo apt install qemu-system cloud-image-utils wget"
        exit 1
    fi
}

# Main execution
main() {
    check_dependencies
    init_directories
    main_menu
}

# Run the script
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi
