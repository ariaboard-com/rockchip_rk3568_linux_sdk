#!/bin/bash

CMD=`realpath $BASH_SOURCE`
CUR_DIR=`dirname $CMD`

source $CUR_DIR/BoardConfig.mk

# Uboot defconfig
export RK_UBOOT_DEFCONFIG=firefly_rk1808
# Kernel defconfig
export RK_KERNEL_DEFCONFIG=firefly_rk1808_ubuntu_defconfig
# Kernel dts
export RK_KERNEL_DTS=rk1808-firefly
# parameter for GPT table
export RK_PARAMETER=parameter-ubuntu.txt
# packagefile for make update image
export RK_PACKAGE_FILE=rk1808-ubuntu-package-file
# Set rootfs type, including ext2 ext4 squashfs
export RK_ROOTFS_TYPE=ext4
# rootfs image path
export RK_ROOTFS_IMG=ubuntu_rootfs/rk1808_ubuntu18.04_rootfs.img
# recovery ramdisk
export RK_RECOVERY_RAMDISK=recovery-arm64.cpio.gz
# Set userdata partition type
export RK_USERDATA_FS_TYPE=ext4
# Buildroot config
export RK_CFG_BUILDROOT=
# Recovery config
export RK_CFG_RECOVERY=
#OEM config
export RK_OEM_DIR=
#userdata config
export RK_USERDATA_DIR=
# rootfs_system
export RK_ROOTFS_SYSTEM=ubuntu
