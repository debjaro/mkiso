#!/usr/bin/sh

mkdir chroot
debootstrap --no-merged-usr --arch=amd64 sid chroot https://deb.debian.org/debian
for i in dev dev/pts proc sys; do mount -o bind /$i chroot/$i; done

# Debjaro repository
echo "deb https://debjaro.github.io/repo/stable stable main" > chroot/etc/apt/sources.list.d/debjaro.list
curl https://debjaro.github.io/repo/stable/dists/stable/Release.key | chroot chroot apt-key add -
chroot chroot apt-get update -y
chroot chroot apt-get upgrade -y

chroot chroot apt-get dist-upgrade -y
chroot chroot apt-get install grub-pc-bin grub-efi -y
chroot chroot apt-get install live-config live-boot -y

# liquorix kernel
curl https://liquorix.net/add-liquorix-repo.sh | chroot chroot bash
chroot chroot apt-get install linux-image-liquorix-amd64 linux-headers-liquorix-amd64 -y

# xorg & desktop pkgs
chroot chroot apt-get install xserver-xorg network-manager-gnome -y

# Install lxde-gtk3
echo "deb https://raw.githubusercontent.com/lxde-gtk3/binary-packages/master stable main" > chroot/etc/apt/sources.list.d/lxde-gtk3.list
curl https://raw.githubusercontent.com/lxde-gtk3/binary-packages/master/dists/stable/Release.key | chroot chroot apt-key add -
chroot chroot apt-get update
chroot chroot apt-get install lxde-core -y

chroot chroot apt-get clean
rm -f chroot/root/.bash_history
rm -rf chroot/var/lib/apt/lists/*
find chroot/var/log/ -type f | xargs rm -f

mkdir debjaro
umount -lf -R chroot/* 2>/dev/null
mksquashfs chroot filesystem.squashfs -comp gzip -wildcards
mkdir -p debjaro/live
mv filesystem.squashfs debjaro/live/filesystem.squashfs

cp -pf chroot/boot/initrd.img-* debjaro/live/initrd.img
cp -pf chroot/boot/vmlinuz-* debjaro/live/vmlinuz

mkdir -p debjaro/boot/grub/
echo 'menuentry "Start Debjaro GNU/Linux 64-bit" --class debjaro {' > debjaro/boot/grub/grub.cfg
echo '    linux /live/vmlinuz boot=live live-config live-media-path=/live quiet splash --' >> debjaro/boot/grub/grub.cfg
echo '    initrd /live/initrd.img' >> debjaro/boot/grub/grub.cfg
echo '}' >> debjaro/boot/grub/grub.cfg

grub-mkrescue debjaro -o debjaro-gnulinux-$(date +%s).iso
