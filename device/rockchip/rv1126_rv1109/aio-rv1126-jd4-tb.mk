#!/bin/bash

CMD=`realpath $BASH_SOURCE`                                                                                                                                                                                          
CUR_DIR=`dirname $CMD`

source $CUR_DIR/BoardConfig-tb-v13.mk

# Kernel dts
export RK_LOADER_UPDATE_TPL=true

export RK_UBOOT_DEFCONFIG=rv1126-firefly-emmc-tb

export RK_KERNEL_DEFCONFIG=rv1126_firefly_defconfig

export RK_KERNEL_DTS=rv1126-firefly-jd4-tb

export RK_CFG_RAMBOOT=firefly_rv1126_tb
