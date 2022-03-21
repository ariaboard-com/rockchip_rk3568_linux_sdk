#!/bin/bash

CMD=`realpath $BASH_SOURCE`
CUR_DIR=`dirname $CMD`

source $CUR_DIR/px30-buildroot.mk

# Kernel dts
export RK_KERNEL_DTS=px30-firefly-lvds

