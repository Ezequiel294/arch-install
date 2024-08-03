#!/bin/bash

# Exit on error and ensure errors in pipelines are caught
set -e
set -o pipefail

# Check if the script is being run as root
echo "Checking if you are root..."
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root" >&2
    exit 1
fi
echo -e "\nYou are root. Proceeding with installation...\n"

# Set the root password, username, and hostname
read -sp "Enter the password for root: " root_password
echo
read -p "Enter the username you want to create: " username
read -sp "Enter the password for $username: " user_password
echo
read -p "Enter the host name: " hostname

# Set swap file if wanted
read -p "Do you want to create a swap file? (Y/n): " answer
if [[ $answer =~ ^[Yy]$ ]]; then
    read -p "Enter the size of the swap file in GB: " swap_size
    echo -e "\nCreating swap file..."
    mkswap -U clear --size $swap_sizeG /swapfile
    swapon /swapfile
    echo -e '\n/swapfile none swap defaults 0 0' | tee -a /etc/fstab
    echo "Swap file created."
fi

# Set timezone
echo -e "\nTo set the time zone, you need to know your region and city."
echo "You can find your region and city by running timedatectl list-timezones"
read -p "Do you want to run 'timedatectl list-timezones'? (Y/n): " answer
if [[ $answer =~ ^[Yy]$ ]]; then
    timedatectl list-timezones
fi
read -p "Enter your region: " region
read -p "Enter your city: " city
echo -e "\nSetting the time zone..."
ln -sf /usr/share/zoneinfo/$region/$city /etc/localtime
hwclock --systohc
echo "Time zone set."

# Set accounts
echo -e "\nSetting up accounts..."
echo "root:$root_password" | chpasswd
useradd -mG wheel "$username"
echo "$username:$user_password" | chpasswd
echo "Accounts set."

# Install necessary packages
echo -e "\nInstalling necessary packages..."
pacman -S --noconfirm neovim reflector

# Pacman configuration
echo -e "\nConfiguring pacman..."
sed -i '/#Color/s/^#//' /etc/pacman.conf
sed -i '/#ParallelDownloads/s/^#//' /etc/pacman.conf
if ! grep -q '^ILoveCandy' /etc/pacman.conf; then
    sed -i '/\[options\]/a ILoveCandy' /etc/pacman.conf
fi
cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.bak
reflector --verbose --latest 10 --protocol https --sort rate --save /etc/pacman.d/mirrorlist
pacman -Syy
echo "Pacman configured."

# Hardware detection and conditional package installation
echo -e "\nDetecting hardware..."
# Detect VirtualBox
is_virtualbox=$(lspci | grep -i "VirtualBox" || echo "not found")
if [ "$is_virtualbox" != "not found" ]; then
    echo "VirtualBox environment detected. Installing VirtualBox Guest Additions..."
    pacman -S --needed --noconfirm virtualbox-guest-utils
    systemctl enable vboxservice.service
    echo "VirtualBox Guest Additions installed."
fi
# Detect VMware
is_vmware=$(lspci | grep -i "VMware" || echo "not found")
if [ "$is_vmware" != "not found" ]; then
    echo "VMware environment detected. Installing VMware Tools..."
    pacman -S --needed --noconfirm open-vm-tools
    systemctl enable vmtoolsd.service
    systemctl enable vmware-vmblock-fuse.service
    echo "VMware Tools installed."
fi
# Detect Hyper-V
is_hyperv=$(dmesg | grep -i "Hypervisor detected" || echo "not found")
if [ "$is_hyperv" != "not found" ]; then
    echo "Hyper-V environment detected. Installing Hyper-V Tools..."
    pacman -S --needed --noconfirm hyperv
    systemctl enable hv_fcopy_daemon.service
    systemctl enable hv_kvp_daemon.service
    systemctl enable hv_vss_daemon.service
    echo "Hyper-V Tools installed."
fi
# Detect QEMU
is_qemu=$(dmesg | grep -i "QEMU" || echo "not found")
if [ "$is_qemu" != "not found" ]; then
    echo "QEMU environment detected. Installing QEMU Guest Agent..."
    pacman -S --needed --noconfirm qemu-guest-agent
    systemctl enable qemu-ga.service
    echo "QEMU Guest Agent installed."
fi
else
    echo "Physical hardware detected. Checking for specific hardware..."
    cpu_info=$(grep -m 1 'model name' /proc/cpuinfo)
    if echo "$cpu_info" | grep -iq "intel"; then
        echo "Intel CPU detected. Ensuring intel-ucode is installed..."
        pacman -S --needed --noconfirm intel-ucode
    elif echo "$cpu_info" | grep -iq "amd"; then
        echo "AMD CPU detected. Installing AMD microcode..."
        pacman -S --needed --noconfirm amd-ucode
    else
        echo "No specific CPU detected. Skipping CPU-specific installations."
    fi

    IFS=$'\n' # Change the Internal Field Separator to newline to correctly iterate over lines
    for gpu_info in $(lspci | grep -E "VGA|3D|2D"); do
        if echo "$gpu_info" | grep -iq "nvidia"; then
            echo "NVIDIA GPU detected. Installing drivers..."
            pacman -S --needed --noconfirm mesa nvidia-open nvidia-utils nvidia-settings
        elif echo "$gpu_info" | grep -iq "amd"; then
            echo "AMD GPU detected. Installing drivers..."
            pacman -S --needed --noconfirm mesa vulkan-radeon vulkan-tools
        elif echo "$gpu_info" | grep -iq "intel"; then
            echo "Intel GPU detected. Installing drivers..."
            pacman -S --needed --noconfirm mesa vulkan-intel vulkan-tools
        else
            echo "No specific GPU detected. Skipping GPU-specific installations."
        fi
    done
    IFS=' ' # Reset the Internal Field Separator to default

    echo "Hardware detected and set up."
fi

# Install necessary packages
echo -e "\nInstalling necessary packages..."
pacman -S --needed --noconfirm base-devel grub efibootmgr os-prober networkmanager pipewire wireplumber pipewire-audio pipewire-alsa pipewire-pulse pipewire-jack bluez bluez-utils sudo
echo "Packages installed."

# Enable sudo
echo -e "\nEnabling sudo..."
sed -i '/^# %wheel ALL=(ALL:ALL) ALL/s/^# //' /etc/sudoers
echo "Sudo enabled."

# Set the locale
echo -e "\nSetting english UTF-8 locale..."
sed -i '/^#en_US.UTF-8 UTF-8/s/^#//' /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" >/etc/locale.conf
echo "Locale set."

# Grub installation
echo -e "\nInstalling GRUB..."
grub-install --verbose --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
echo "GRUB installed."
echo -e "\nGenerating GRUB configuration..."
sed -i '$ s/^#//' /etc/default/grub
grub-mkconfig -o /boot/grub/grub.cfg
echo "GRUB configuration generated."

# Network configuration
echo -e "\nConfiguring network..."
echo $hostname >/etc/hostname
echo "127.0.0.1 localhost
::1       localhost
127.0.1.1 $hostname.localhost $hostname" | tee /etc/hosts >/dev/null
echo "Network configured."

# Enable services
echo -e "\nEnabling services..."
systemctl enable NetworkManager bluetooth
echo "Services enabled."

# Ask the user if they want to install the dotfiles
read -p "Do you want to install the dotfiles from https://github.com/Ezequiel294/dotfiles? (y/n): " install_dotfiles
if [ "$install_dotfiles" = "y" ] || [ "$install_dotfiles" = "Y" ]; then
    echo -e "\nMoving to $username's home directory..."
    cd /home/$username
    echo -e "\nInstalling dotfiles..."
    su -c "git clone --bare https://github.com/Ezequiel294/dotfiles .dotfiles" $username
    su -c "git --git-dir=/home/$username/.dotfiles/ --work-tree=/home/$username checkout --force" $username
    echo "The script is located at /home/$username/Scripts/post-install.sh"
else
    echo "Skipping dotfiles installation."
fi

echo -e "\nInstallation complete. Please reboot the system."
