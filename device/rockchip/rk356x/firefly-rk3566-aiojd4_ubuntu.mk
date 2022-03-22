#!/bin/bash

CMD=`realpath $BASH_SOURCE`
CUR_DIR=`dirname $CMD`

source $CUR_DIR/firefly-rk3566_ubuntu.mk

# Kernel dts
export RK_KERNEL_DTS=rk3566-firefly-aiojd4
