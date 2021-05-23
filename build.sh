#!/bin/bash
set -e
#### Check root
if [[ ! $UID -eq 0 ]] ; then
    echo -e "\033[31;1mYou must be root!\033[:0m"
    exit 1
fi
#### Install dependencies
if which apt &>/dev/null && [[ -d /var/lib/dpkg && -d /etc/apt ]] ; then
    apt-get install mtools spuashfs-tools grub-pc-bin grub-efi xorriso debootstrap -y
    # For 17g package build
    #apt-get install git devscripts -y
fi

set -ex
#### Chroot create
mkdir chroot || true

#### For devuan
debootstrap --no-check-gpg --no-merged-usr --arch=amd64 testing chroot https://pkgmaster.devuan.org/merged
##### For debian
#debootstrap --no-check-gpg --no-merged-usr --arch=amd64 testing chroot https://deb.debian.org/debian
##### For ubuntu
#codename=$(curl https://cdimage.ubuntu.com/ubuntu/daily-live/current/ | grep "desktop-amd64.iso" | head -n 1 | sed "s/-.*//g" | sed "s/.*\"//g")
#debootstrap --no-check-gpg --no-merged-usr --arch=amd64 $codename chroot https://archive.ubuntu.com/ubuntu

#### Fix apt & bind
echo "APT::Sandbox::User root;" > chroot/etc/apt/apt.conf.d/99sandboxroot
for i in dev dev/pts proc sys; do mount -o bind /$i chroot/$i; done
chroot chroot apt-get install gnupg -y

#### Debjaro repository (optional)
echo "deb https://debjaro.github.io/repo/stable stable main" > chroot/etc/apt/sources.list.d/debjaro.list
curl https://debjaro.github.io/repo/stable/dists/stable/Release.key | chroot chroot apt-key add -
chroot chroot apt-get update -y
chroot chroot apt-get upgrade -y

#### live-boot
chroot chroot apt-get dist-upgrade -y
chroot chroot apt-get install grub-pc-bin grub-efi-ia32-bin grub-efi -y
chroot chroot apt-get install live-config live-boot -y

#### Install 17g (optional)
#mkdir 17g-build && cd 17g-build 
#git clone https://gitlab.com/ggggggggggggggggg/17g && cd 17g
#mk-build-deps --install
#debuild -us -uc -b
#cd ../../
#cp 17g-build/17g*.deb chroot/tmp/17g.deb
#chroot chroot dpkg -i tmp/17g.deb
#chroot chroot apt-get install -f -y
#rm -f chroot/tmp/17g.deb

#### liquorix kernel
curl https://liquorix.net/liquorix-keyring.gpg | chroot chroot apt-key add -
echo "deb http://liquorix.net/debian testing main" > chroot/etc/apt/sources.list.d/liquorix.list
chroot chroot apt-get update -y
chroot chroot apt-get install linux-image-liquorix-amd64 linux-headers-liquorix-amd64 -y

#### stock kernel 
#chroot chroot apt-get install linux-image-amd64 linux-headers-amd64 -y

#### xorg & desktop pkgs
chroot chroot apt-get install xserver-xorg network-manager-gnome -y

#### Install lxde-gtk3
echo "deb https://raw.githubusercontent.com/lxde-gtk3/binary-packages/master stable main" > chroot/etc/apt/sources.list.d/lxde-gtk3.list
curl https://raw.githubusercontent.com/lxde-gtk3/binary-packages/master/dists/stable/Release.key | chroot chroot apt-key add -
chroot chroot apt-get update
chroot chroot apt-get install lxde-core -y

#### Install xfce
#chroot chroot apt-get install xfce4 xfce4-goodies -y

#### Install gnome
#chroot chroot apt-get install gnome-core -y

#### Install kde
#chroot chroot apt-get install kde-plasma-desktop -y

#### Run chroot shell
#chroot chroot /bin/bash || true

#### Clear logs and history
chroot chroot apt-get clean
rm -f chroot/root/.bash_history
rm -rf chroot/var/lib/apt/lists/*
find chroot/var/log/ -type f | xargs rm -f

#### Create squashfs
mkdir debjaro || true
umount -lf -R chroot/* 2>/dev/null || true
mksquashfs chroot filesystem.squashfs -comp gzip -wildcards
mkdir -p debjaro/live || true
ln -s live debjaro/casper || true
mv filesystem.squashfs debjaro/live/filesystem.squashfs

#### Copy kernel and initramfs (Debian/Devuan)
cp -pf chroot/boot/initrd.img-* debjaro/boot/initrd.img
cp -pf chroot/boot/vmlinuz-* debjaro/boot/vmlinuz

#### Write grub.cfg
mkdir -p debjaro/boot/grub/
echo 'menuentry "Start Debjaro GNU/Linux 64-bit" --class debjaro {' > debjaro/boot/grub/grub.cfg
echo '    linux /boot/vmlinuz boot=live live-config --' >> debjaro/boot/grub/grub.cfg
echo '    initrd /boot/initrd.img' >> debjaro/boot/grub/grub.cfg
echo '}' >> debjaro/boot/grub/grub.cfg
### For ubuntu (boot=live => boot=casper)
#sed -i "s/boot=live/boot=casper/g" debjaro/boot/grub/grub.cfg

#### Create iso
grub-mkrescue debjaro -o debjaro-gnulinux-$(date +%s).iso
