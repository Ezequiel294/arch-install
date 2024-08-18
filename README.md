# Index

- [Index](#index)
- [Overview](#overview)
- [List of Requirements](#list-of-requirements)
- [Arch Installation](#arch-installation)

# Overview

The following instructions are a guide to installing and configuring Arch. Before following these instructions, it is necessary to know Linux-based operating systems and command line interfaces.

> [!NOTE]
>
> - Arch Linux installation images do not support Secure Boot. You will need to disable Secure Boot to boot the installation medium.
> - Code examples may contain placeholders that must be replaced manually.

# List of Requirements

- Internet connection
- 64-bit computer Using UEFI
- Keyboard and Mouse
- At least 2GB of available RAM Memory
- At least 8GB of available storage (this is the minimum for the OS, probably want more than this for personal files and apps)

# Arch Installation

1. Download the Arch ISO and burn it to a USB memory:

- [Arch ISO](https://archlinux.org/download/)

2. Boot to the USB memory

3. Select the first boot option with the "Enter" key

> [!NOTE]
> I recommend opening the official guide to follow along in case something changes or you have a different need.
>
> - [Arch Installation Guide](https://wiki.archlinux.org/title/Installation_guide)

4. Change the terminal font if it is too small

```bash
setfont ter-132b
```

5. Display block devices to see the name of your disks and partition

```bash
lsblk
```

> [!NOTE]
> Highly recomended to use the arch wiki for this following part as it can vary a lot depending on the users needs and harware.
6. Make the disk partitions

```bash
fdisk /dev/disk
```

7. Format the partitions with the following commands with the following format:
mkfs.*format* /dev/*partition*
the EFI should have a FAT32 format, the root can have your preferred format, and the swap should have a swap format

8. Mount the partitions
> [!NOTE]
> Root partition should be mounted to /mnt
> EFI partition should be mounted to /mnt/boot
> If using a swap partition, you should enable it with the following command: swapon /dev/*swap_partition*
>
> If using btrfs, you should mount the subvolumes too

9. Check you have internet

```bash
ping google.com
```

If not, you probably aren't using ethernet and want to use wifi. Use the "iw" tool with the following command and read the arch wiki for command instruction.

```bash
iwctl
```

10. Install kernel and base package

```bash
pacstrap -K /mnt linux linux-firmware base git
```

11. Generate the fstab file

```bash
genfstab -U /mnt >> /mnt/etc/fstab
```

12. Change root to your system

```bash
arch-chroot /mnt
```

13. Move to the root directory

```bash
cd /root
```

14. Clone my arch base installation script

```bash
git clone https://github.com/Ezequiel294/arch-install
```

15. Move back to the root directory

```bash
cd /
```

16. Run my script

```bash
sh /root/arch-install/base-install.sh | tee -a /root/arch-install/base-install.log
```
> [!NOTE]
> the pipe with the tee command is to generate a log file with all the ouput of the installation for the user to check if everything was correctly installed. However, it is not required and can be omited.

17. Exit your system

```bash
exit
```

18. Shutdown your computer

```bash
shutdown now
```

19. When powered off, remove the USB memory

20. Power your computer back on

21. Select the first boot option in Grub

22. Login with your user

23. Enjoy your new Arch Linux installation
