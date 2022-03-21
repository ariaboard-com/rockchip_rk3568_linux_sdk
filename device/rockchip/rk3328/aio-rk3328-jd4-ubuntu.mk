#!/bin/bash

CMD=`realpath $BASH_SOURCE`
CUR_DIR=`dirname $CMD`

source $CUR_DIR/firefly-rk3328-ubuntu.mk

# Kernel dts
export RK_KERNEL_DTS=rk3328-firefly-aiojd4

#export RK_ROOTFS_IMG=rootfs/rk3328-ubuntu1804-arm64-rootfs.img
