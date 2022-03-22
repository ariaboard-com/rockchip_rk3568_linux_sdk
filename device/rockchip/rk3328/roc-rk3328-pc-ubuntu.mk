#!/bin/bash

CMD=`realpath $BASH_SOURCE`
CUR_DIR=`dirname $CMD`

source $CUR_DIR/firefly-rk3328-ubuntu.mk

# Kernel dts
export RK_KERNEL_DTS=rk3328-roc-pc
export RK_KERNEL_DEFCONFIG=firefly-rk3328_defconfig
