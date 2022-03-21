#!/bin/bash

CMD=`realpath $BASH_SOURCE`
CUR_DIR=`dirname $CMD`

source $CUR_DIR/BoardConfig.mk

# Uboot defconfig
export RK_UBOOT_DEFCONFIG=firefly-rk3568
# Kernel defconfig
export RK_KERNEL_DEFCONFIG=firefly_linux_defconfig
# Kernel dts
export RK_KERNEL_DTS=firefly-rk3568-aioj
# packagefile for make update image 
export RK_PACKAGE_FILE=rk356x-package-file

# sd_parameter for GPT table
export RK_SD_PARAMETER=parameter-recovery.txt
# packagefile for make sdupdate image
export RK_SD_PACKAGE_FILE=rk356x-recovery-package-file
# Buildroot config
export RK_CFG_BUILDROOT=rockchip_rk3568
# yocto machine
export RK_YOCTO_MACHINE=rockchip-rk3568-evb
# kernel image format type: fit(flattened image tree)
export RK_KERNEL_FIT_ITS=bootramdisk.its

export RK_USERDATA_FS_TYPE=ext4
