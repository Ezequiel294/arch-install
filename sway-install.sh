#!/bin/bash

if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root" >&2
    exit 1
fi

read -sp "Enter the password for root: " root_password
read -p "Enter the username you want to create: " username
read -sp "Enter the password for $username: " user_password
read -p "Enter the host name: " hostname

ln -sf /usr/share/zoneinfo/Region/City /etc/localtime
hwclock --systohc

echo "root:$root_password" | chpasswd

useradd -mG wheel "$username"
echo "$username:$user_password" | chpasswd

pacman -S --noconfirm neovim reflector

nvim /etc/pacman.conf
cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.bak
reflector --verbose --latest 10 --protocol https --sort rate --save /etc/pacman.d/mirrorlist
pacman -Syy

# Hardware detection and conditional package installation
is_virtualbox=$(lspci | grep -i "VirtualBox" || echo "not found")
if [ "$is_virtualbox" != "not found" ]; then
    echo "VirtualBox environment detected. Installing VirtualBox Guest Additions..."
    pacman -S --needed --noconfirm virtualbox-guest-utils
    systemctl enable vboxservice.service
else
    echo "Physical hardware detected. Checking for specific hardware..."
    gpu_info=$(lspci | grep -E "VGA|3D|2D")
    if echo "$gpu_info" | grep -iq "nvidia"; then
        echo "NVIDIA GPU detected. Installing drivers..."
        pacman -S --needed --noconfirm nvidia nvidia-utils nvidia-settings
    elif echo "$gpu_info" | grep -iq "amd"; then
        echo "AMD GPU detected. Installing drivers..."
        pacman -S --needed --noconfirm xf86-video-amdgpu vulkan-radeon
    elif echo "$gpu_info" | grep -iq "intel"; then
        echo "Intel GPU detected. Installing drivers..."
        pacman -S --needed --noconfirm intel-ucode mesa vulkan-intel
    else
        echo "No specific GPU detected. Skipping GPU-specific installations."
    fi

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

pacman -S --needed --noconfirm alacritty base-devel breeze-grub grub efibootmgr ly networkmanager pipewire wireplumber pipewire-audio pipewire-alsa pipewire-pulse pipewire-jack bluez bluez-utils reflector sudo git neovim sway swaylock swayidle swaybg wofi firefox

sed -i '/^# %wheel ALL=(ALL) ALL/s/^# //' /etc/sudoers

sed -i '/^#en_US.UTF-8 UTF-8/s/^#//' /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg

echo $hostname > /etc/hostname
echo "127.0.0.1 localhost
::1       localhost
127.0.1.1 $hostname.localhost $hostname" | tee /etc/hosts > /dev/null

systemctl enable NetworkManager bluetooth ly