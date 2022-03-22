#!/bin/bash

CMD=`realpath $BASH_SOURCE`
CUR_DIR=`dirname $CMD`

 source $CUR_DIR/firefly-rk1806-buildroot.mk

# Uboot defconfig
export RK_KERNEL_DTS=rk1806-firefly-aiojd4
# Buildroot config
export RK_CFG_BUILDROOT=rockchip_rk1806_ficial_gate
