#!/bin/bash

CMD=`realpath $BASH_SOURCE`
CUR_DIR=`dirname $CMD`

source $CUR_DIR/firefly-rk3399-buildroot.mk

# Kernel dts
export RK_KERNEL_DTS=rk3399-firefly-aioc
