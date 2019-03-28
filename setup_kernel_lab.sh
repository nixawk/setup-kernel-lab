#!/bin/bash

# OS      : archlinux
# Kernel  : 5.0.4
# Author  : nixawk
# License : GPL

INIT_DIR=$(pwd)
IMG_NAME="kernel-dev-archlinux.img"
IMG_SIZE=5G
IMG_TDIR="archlinux" # temp dir used to create kernel image
CPU_SIZE=2G

function install_essential_tools {
	echo "[*] install essential tools"
	sudo pacman -Sq --noconfirm arch-install-scripts qemu 2>/dev/null
}

function create_img_disk {
	echo "[*] create a img (bootfs)"
	if [ -e "${INIT_DIR}/${IMG_NAME}" ];then
		printf "[*] ($IMG_NAME) is found. Delete it and recreate a new one (y/N): "
		read choice

		if [ "$choice" == "y" ]; then
			rm -f "${INIT_DIR}/${IMG_NAME}"
			echo "[*] ($IMG_NAME) is deleted."
		fi
	fi

	if [ ! -e "${INIT_DIR}/${IMG_NAME}" ]; then
		qemu-img create "${INIT_DIR}/${IMG_NAME}" ${IMG_SIZE}
		mkfs.ext4 "${INIT_DIR}/${IMG_NAME}"
		mkdir -p "${INIT_DIR}/${IMG_TDIR}"
		sudo mount "${INIT_DIR}/${IMG_NAME}" "${INIT_DIR}/${IMG_TDIR}"
		sudo pacstrap "${INIT_DIR}/${IMG_TDIR}" base base-devel
		sudo umount "${INIT_DIR}/${IMG_TDIR}"
	fi
}

function compile_linux_kernel {
	echo "[*] compile linux kernel"
	git clone --depth=1 git://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git "${INIT_DIR}/linux/" 2>/dev/null
	cd "${INIT_DIR}/linux/"
	make x86_64_defconfig
	make kvmconfig
	"${INIT_DIR}/linux/scripts/config" -e DEBUG_INFO -e GDB_SCRIPTS
	make -j8
}

function boot_linux_kernel {
	echo "[*] boot linux kernel with qemu, and enable remote debugging"
	if [ ! -e "${INIT_DIR}/${IMG_NAME}" ]; then
		echo "[*] ($IMG_NAME) not found."
		exit 1
	fi

	if [ ! -e "${INIT_DIR}/linux/arch/x86/boot/bzImage" ]; then
		echo "[*] ($INIT_DIR/linux/arch/x86/boot/bzImage) not found."
		exit 1
	fi

	qemu-system-x86_64 -hda "${INIT_DIR}/${IMG_NAME}" \
		-s \
		-m ${CPU_SIZE} \
		-nographic \
		-kernel "${INIT_DIR}/linux/arch/x86/boot/bzImage" \
       		-append "root=/dev/sda rw console=ttyS0 loglevel=5"
}

install_essential_tools
create_img_disk
compile_linux_kernel
boot_linux_kernel

# references
# https://www.collabora.com/news-and-blog/blog/2017/01/16/setting-up-qemu-kvm-for-kernel-development/
# https://www.collabora.com/news-and-blog/blog/2019/03/20/bootstraping-a-minimal-arch-linux-image/
