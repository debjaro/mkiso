#!/bin/bash
set -e
#### Check root
if [[ ! $UID -eq 0 ]] ; then
    echo -e "\033[31;1mYou must be root!\033[:0m"
    exit 1
fi
#### Remove all environmental variable
for e in $(env | sed "s/=.*//g") ; do
    unset "$e" &>/dev/null
done

#### Set environmental variables
export PATH=/bin:/usr/bin:/sbin:/usr/sbin
export LANG=C
export SHELL=/bin/bash
export TERM=linux
export DEBIAN_FRONTEND=noninteractive

#### Install dependencies
if which apt &>/dev/null && [[ -d /var/lib/dpkg && -d /etc/apt ]] ; then
    apt-get update
    apt-get install curl mtools squashfs-tools grub-pc-bin grub-efi-amd64-bin grub2-common grub-common grub-efi-ia32-bin xorriso debootstrap binutils -y --no-install-recommends
#    # For 17g package build
#    apt-get install git devscripts equivs -y
fi

set -ex
#### Chroot create
mkdir chroot || true

#### For devuan
debootstrap --variant=minbase --no-check-gpg --no-merged-usr --exclude=usrmerge --arch=amd64 testing chroot https://pkgmaster.devuan.org/merged
echo "deb https://pkgmaster.devuan.org/merged testing main contrib non-free non-free-firmware" > chroot/etc/apt/sources.list
##### For debian
#debootstrap --variant=minbase --no-check-gpg --no-merged-usr --exclude=usrmerge --arch=amd64 testing chroot https://deb.debian.org/debian
#echo "deb https://deb.debian.org/debian testing main contrib non-free" > chroot/etc/apt/sources.list

#### Set root password
pass="live"
echo -e "$pass\n$pass\n" | chroot chroot passwd

#### Fix apt & bind
# apt sandbox user root
echo "APT::Sandbox::User root;" > chroot/etc/apt/apt.conf.d/99sandboxroot
for i in dev dev/pts proc sys; do mount -o bind /$i chroot/$i; done
chroot chroot apt-get install gnupg -y

##### Devuan only
chroot chroot apt-get install devuan-keyring -y

#### Debjaro repository (optional)
echo "deb https://debjaro.github.io/repo/stable stable main" > chroot/etc/apt/sources.list.d/debjaro.list
curl https://debjaro.github.io/repo/stable/dists/stable/Release.key | gpg --dearmor > chroot/etc/apt/trusted.gpg.d/debjaro.gpg
chroot chroot apt-get update -y
chroot chroot apt-get upgrade -y

#### grub packages
#chroot chroot apt-get dist-upgrade -y
#chroot chroot apt-get install grub-pc-bin grub-efi-ia32-bin grub-efi -y

#### live packages for debian/devuan
chroot chroot apt-get install live-config live-boot -y
echo "DISABLE_DM_VERITY=true" >> chroot/etc/live/boot.conf

#### Configure system
cat > chroot/etc/apt/apt.conf.d/01norecommend << EOF
APT::Install-Recommends "0";
APT::Install-Suggests "0";
EOF

# Set sh as bash inside of dash (optional)
rm -f chroot/bin/sh
ln -s bash chroot/bin/sh

#### Remove bloat files after dpkg invoke (optional)
cat > chroot/etc/apt/apt.conf.d/02antibloat << EOF
DPkg::Post-Invoke {"rm -rf /usr/share/locale || true";};
DPkg::Post-Invoke {"rm -rf /usr/share/man || true";};
DPkg::Post-Invoke {"rm -rf /usr/share/help || true";};
DPkg::Post-Invoke {"rm -rf /usr/share/doc || true";};
DPkg::Post-Invoke {"rm -rf /usr/share/info || true";};
DPkg::Post-Invoke {"rm -rf /usr/share/i18n || true";};
EOF

#### Install 17g (optional)
#mkdir 17g-build && cd 17g-build 
#git clone https://gitlab.com/ggggggggggggggggg/17g && cd 17g
#mk-build-deps --install
#debuild -us -uc -b
#cd ../../
#cp 17g-build/17g*.deb chroot/tmp/17g.deb
#chroot chroot dpkg -i tmp/17g.deb || true
#chroot chroot apt-get install -f -y
#rm -f chroot/tmp/17g.deb

#### liquorix kernel
curl https://liquorix.net/liquorix-keyring.gpg | chroot chroot apt-key add -
echo "deb http://liquorix.net/debian testing main" > chroot/etc/apt/sources.list.d/liquorix.list
chroot chroot apt-get update -y
chroot chroot apt-get install linux-image-liquorix-amd64 -y
#chroot chroot apt-get install linux-headers-liquorix-amd64 -y

#### stock kernel 
#chroot chroot apt-get install linux-image-amd64 -y
#chroot chroot apt-get install linux-headers-amd64 -y

#### xorg & desktop pkgs
chroot chroot apt-get install xserver-xorg xinit -y

#### Install lxde-gtk3
echo "deb https://raw.githubusercontent.com/lxde-gtk3/binary-packages/master stable main" > chroot/etc/apt/sources.list.d/lxde-gtk3.list
curl https://raw.githubusercontent.com/lxde-gtk3/binary-packages/master/dists/stable/Release.key | gpg --dearmor > chroot/etc/apt/trusted.gpg.d/lxde-gtk3.gpg
chroot chroot apt-get update
chroot chroot apt-get install lxde-core xdg-utils -y

#### Install xfce
#chroot chroot apt-get install xfce4 xfce4-goodies -y

#### Install gnome
#chroot chroot apt-get install gnome-core -y

#### Install kde
#chroot chroot apt-get install kde-plasma-desktop kwin-x11 -y

#### Install lightdm (for lxde and xfce only)
#chroot chroot apt-get install lightdm lightdm-gtk-greeter -y

#### Usefull stuff
#chroot chroot apt-get install network-manager-gnome pulseaudio -y
chroot chroot apt-get install network-manager xterm -y

#### Run chroot shell
#chroot chroot /bin/bash || true

#### usbcore stuff (for initramfs)
echo "#!/bin/sh" > chroot/etc/initramfs-tools/scripts/init-top/usbcore.sh
echo "echo Y > /sys/module/usbcore/parameters/old_scheme_first" >> chroot/etc/initramfs-tools/scripts/init-top/usbcore.sh
chmod +x chroot/etc/initramfs-tools/scripts/init-top/usbcore.sh
chroot chroot update-initramfs -u -k all

### Remove sudo (optional)
chroot chroot apt purge sudo -y
chroot chroot apt autoremove --purge -y

#### Clear logs and history
chroot chroot apt-get clean
rm -f chroot/root/.bash_history
rm -rf chroot/var/lib/apt/lists/*
find chroot/var/log/ -type f | xargs rm -f

### create iso template
mkdir -p debjaro/boot || true
mkdir -p debjaro/live || true
ln -s live debjaro/casper || true

#### Copy kernel and initramfs (Debian/Devuan)
cp -pf chroot/boot/initrd.img-* debjaro/boot/initrd.img
cp -pf chroot/boot/vmlinuz-* debjaro/boot/vmlinuz

#### Remove initrd.img for minimize iso size (optional)
rm -rf chroot/boot/initrd.img-*

#### Create squashfs
for dir in dev dev/pts proc sys ; do
    while umount -lf -R chroot/$dir 2>/dev/null ; do true; done
done
# For better installation time
#mksquashfs chroot filesystem.squashfs -comp gzip -wildcards
# For better compress ratio
mksquashfs chroot filesystem.squashfs -comp xz -wildcards

### move squashfs file
mv filesystem.squashfs debjaro/live/filesystem.squashfs

#### Write grub.cfg
mkdir -p debjaro/boot/grub/
echo 'menuentry "Start Debjaro GNU/Linux 64-bit" --class debjaro {' > debjaro/boot/grub/grub.cfg
echo '    linux /boot/vmlinuz boot=live live-config quiet --' >> debjaro/boot/grub/grub.cfg
echo '    initrd /boot/initrd.img' >> debjaro/boot/grub/grub.cfg
echo '}' >> debjaro/boot/grub/grub.cfg

#### Create iso
grub-mkrescue debjaro -o debjaro-gnulinux-$(date +%s).iso
