#!/bin/bash

CMD=`realpath $BASH_SOURCE`
CUR_DIR=`dirname $CMD`

 source $CUR_DIR/firefly-rk1806-ubuntu.mk

# Uboot defconfig
export RK_KERNEL_DTS=rk1806-firefly-aiojd4
