#!/bin/bash

CMD=`realpath $BASH_SOURCE`
CUR_DIR=`dirname $CMD`

source $CUR_DIR/BoardConfig.mk

# Uboot defconfig
export RK_UBOOT_DEFCONFIG=firefly_rk1808
# Kernel defconfig
export RK_KERNEL_DEFCONFIG=firefly_rk1808_defconfig
# Kernel dts
export RK_KERNEL_DTS=rk1808-firefly
# packagefile for make update image 
export RK_PACKAGE_FILE=rk1808-package-file
# Buildroot config
export RK_CFG_BUILDROOT=firefly_rk1808

export RK_USERDATA_FS_TYPE=ext4
