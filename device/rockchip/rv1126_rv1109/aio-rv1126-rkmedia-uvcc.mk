#!/bin/bash

CMD=`realpath $BASH_SOURCE`

CUR_DIR=`dirname $CMD`

source $CUR_DIR/cam-crv1109s2u-uvcc.mk

# Kernel dts
export RK_KERNEL_DTS=rv1126-firefly-jd4

# Buildroot config
export RK_CFG_BUILDROOT=firefly_rv1126_rv1109_rkmedia_uvcc
