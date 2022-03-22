#!/bin/bash

CMD=`realpath $BASH_SOURCE`
CUR_DIR=`dirname $CMD`

source $CUR_DIR/BoardConfig.mk

# Uboot defconfig
export RK_UBOOT_DEFCONFIG=rk3399pro
# Kernel defconfig
export RK_KERNEL_DEFCONFIG=firefly3399pro_linux_defconfig
# Kernel dts
export RK_KERNEL_DTS=rk3399pro-firefly-aioc-lvds
# parameter for GPT table
export RK_PARAMETER=parameter-ubuntu.txt
# packagefile for make update image 
export RK_PACKAGE_FILE=rk3399-ubuntu-package-file

# Set rootfs type, including ext2 ext4 squashfs
export RK_ROOTFS_TYPE=ext4
# rootfs image path
export RK_ROOTFS_IMG=ubunturootfs/rk3399pro_ubuntu18.04_LXDE.img
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
