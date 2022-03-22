#!/bin/bash

CMD=`realpath $BASH_SOURCE`
CUR_DIR=`dirname $CMD`

source $CUR_DIR/firefly-rk3399-ubuntu.mk

# Kernel dts
export RK_KERNEL_DTS=rk3399-firefly-csr2-main
export RK_ROOTFS_IMG=ubunturootfs/UBUNTU_18.04_CSR2_Main_DESKTOP.img
