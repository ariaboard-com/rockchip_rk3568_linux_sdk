#!/bin/bash

CMD=`realpath $BASH_SOURCE`
CUR_DIR=`dirname $CMD`

source $CUR_DIR/BoardConfig.mk

# Uboot defconfig
export RK_UBOOT_DEFCONFIG=firefly-rk1806
# Kernel defconfig
export RK_KERNEL_DEFCONFIG=firefly_rk1806_defconfig
# Kernel dts
export RK_KERNEL_DTS=rk1806-firefly
# parameter for GPT table
export RK_PARAMETER=parameter-buildroot.txt
# packagefile for make update image
export RK_PACKAGE_FILE=rk1806-package-file
#OEM config
export RK_OEM_DIR=
#userdata config
export RK_USERDATA_DIR=
