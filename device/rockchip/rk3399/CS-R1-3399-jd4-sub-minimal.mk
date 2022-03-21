#!/bin/bash

CMD=`realpath $BASH_SOURCE`
CUR_DIR=`dirname $CMD`

source $CUR_DIR/firefly-rk3399-ubuntu.mk

# Kernel defconfig
export RK_KERNEL_DEFCONFIG=firefly_linux_docker_defconfig

# Kernel dts
export RK_KERNEL_DTS=rk3399-firefly-CS-R1-jd4-sub
