#!/bin/bash

CMD=`realpath $BASH_SOURCE`
CUR_DIR=`dirname $CMD`

source $CUR_DIR/firefly-rk3399-ubuntu.mk

# Kernel dts
export RK_KERNEL_DTS=rk3399-firefly-face-X2-mipi8
export RK_KERNEL_DEFCONFIG=firefly_face_x2_linux_defconfig

