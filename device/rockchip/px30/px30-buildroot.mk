#!/bin/bash

CMD=`realpath $BASH_SOURCE`
CUR_DIR=`dirname $CMD`

source $CUR_DIR/BoardConfig.mk

# Uboot defconfig
export RK_UBOOT_DEFCONFIG=evb-px30
# Kernel defconfig
export RK_KERNEL_DEFCONFIG=px30_linux_defconfig
# Kernel dts
export RK_KERNEL_DTS=px30-firefly
# packagefile for make update image 
export RK_PACKAGE_FILE=px30-package-file

# sd_parameter for GPT table
export RK_SD_PARAMETER=parameter-recovery.txt
# packagefile for make sdupdate image
export RK_SD_PACKAGE_FILE=px30-recovery-package-file

export RK_USERDATA_FS_TYPE=ext4
