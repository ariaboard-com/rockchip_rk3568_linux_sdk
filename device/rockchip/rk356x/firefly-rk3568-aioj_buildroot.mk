#!/bin/bash

CMD=`realpath $BASH_SOURCE`
CUR_DIR=`dirname $CMD`

source $CUR_DIR/firefly-rk3568_buildroot.mk

# Kernel dts
export RK_KERNEL_DTS=rk3568-firefly-aioj
