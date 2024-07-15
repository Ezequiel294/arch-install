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
echo "You are root. Proceeding with installation..."

echo "To set the time zone, you need to know your region and city. You can find your region by running timedatectl list-timezones"
read -p "Do you want to run 'timedatectl list-timezones'? (y/n): " answer
if [[ $answer =~ ^[Yy]$ ]]; then
    timedatectl list-timezones
fi
read -p "Enter your region: " region
echo
read -p "Enter your city: " city
echo
read -sp "Enter the password for root: " root_password
echo
read -p "Enter the username you want to create: " username
echo
read -sp "Enter the password for $username: " user_password
echo
read -p "Enter the host name: " hostname
echo

# Set the time zone
echo "Setting the time zone..."
ln -sf /usr/share/zoneinfo/$region/$city /etc/localtime
hwclock --systohc
echo "Time zone set."

# Set accounts
echo "Setting up accounts..."
echo "root:$root_password" | chpasswd
useradd -mG wheel "$username"
echo "$username:$user_password" | chpasswd
echo "Accounts set."

pacman -S --noconfirm neovim reflector

# Pacman configuration
echo "Configuring pacman..."
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
echo "Detecting hardware..."
is_virtualbox=$(lspci | grep -i "VirtualBox" || echo "not found")
if [ "$is_virtualbox" != "not found" ]; then
    echo "VirtualBox environment detected. Installing VirtualBox Guest Additions..."
    pacman -S --needed --noconfirm virtualbox-guest-utils
    systemctl enable vboxservice.service
else
    echo "Physical hardware detected. Checking for specific hardware..."
    IFS=$'\n' # Change the Internal Field Separator to newline to correctly iterate over lines
    for gpu_info in $(lspci | grep -E "VGA|3D|2D"); do
        if echo "$gpu_info" | grep -iq "nvidia"; then
            echo "NVIDIA GPU detected. Installing drivers..."
            pacman -S --needed --noconfirm nvidia nvidia-utils nvidia-settings
        elif echo "$gpu_info" | grep -iq "amd"; then
            echo "AMD GPU detected. Installing drivers..."
            pacman -S --needed --noconfirm xf86-video-amdgpu vulkan-radeon
        elif echo "$gpu_info" | grep -iq "intel"; then
            echo "Intel GPU detected. Installing drivers..."
            pacman -S --needed --noconfirm mesa vulkan-intel
        else
            echo "No specific GPU detected. Skipping GPU-specific installations."
        fi
    done
    IFS=' ' # Reset the Internal Field Separator to default

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
fi
echo "Hardware detected and set up."

# Install necessary packages
echo "Installing necessary packages..."
pacman -S --needed --noconfirm base-devel grub efibootmgr networkmanager pipewire wireplumber pipewire-audio pipewire-alsa pipewire-pulse pipewire-jack bluez bluez-utils sudo
echo "Packages installed."

# Enable sudo
echo "Enabling sudo..."
sed -i '/^# %wheel ALL=(ALL) ALL/s/^# //' /etc/sudoers
echo "Sudo enabled."

# Set the locale
echo "Setting the locale..."
sed -i '/^#en_US.UTF-8 UTF-8/s/^#//' /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf
echo "Locale set."

# Grub installation
echo "Installing GRUB..."
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg
echo "GRUB installed."

# Network configuration
echo "Configuring network..."
echo $hostname > /etc/hostname
echo "127.0.0.1 localhost
::1       localhost
127.0.1.1 $hostname.localhost $hostname" | tee /etc/hosts > /dev/null
echo "Network configured."

# Enable services
echo "Enabling services..."
systemctl enable NetworkManager bluetooth
echo "Services enabled."

# Post-install config
echo "Post-install configuration..."
echo "Switching to user $username..."
su $username
cd
echo "Running post-install script..."
bash Scripts/Arch/post-install.sh
echo "Post-install configuration complete."

echo "Installation complete."
