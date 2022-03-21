#!/bin/bash

########################################
#              Chip Info               #
########################################
# Target arch
export RK_ARCH=arm
# target chip
export RK_TARGET_PRODUCT=rv1108

########################################
#             Board Info               #
########################################
#Target Board Version
export RK_TARGET_BOARD_VERSION=lock-evb-v11
# Set flash type. support <emmc, nand, nor>
export RK_STORAGE_TYPE=emmc
# Set depth camera
export RK_HAS_DEPTH_CAMERA=n

########################################
#           Buildroot Config           #
########################################
# Buildroot config
export RK_CFG_BUILDROOT=rockchip_rv1108_lock_defconfig

########################################
#            Rootfs Config             #
########################################
# Set rootfs type, including ext2 ext4 squashfs
export RK_ROOTFS_TYPE=cpio.lz4

########################################
#            Loader Config             #
########################################
# Set loader config
export RK_LOADER_BUILD_TYPE=emmc
export RK_LOADER_POWER_HOLD_GPIO_GROUP=3
export RK_LOADER_POWER_HOLD_GPIO_INDEX=14
export RK_LOADER_EMMC_TURNING_DEGREE=2
export RK_LOADER_BOOTPART_SELECT=0
export RK_LOADER_PREISP_EN=0

########################################
#            Kernel Config             #
########################################
# Kernel defconfig
export RK_KERNEL_DEFCONFIG=rv1108-${RK_TARGET_BOARD_VERSION}_defconfig
# Kernel dts
export RK_KERNEL_DTS=rv1108-${RK_TARGET_BOARD_VERSION}

########################################
#           Userdata Config            #
########################################
# Set userdata config
export RK_USERDATA_FILESYSTEM_TYPE=ext4
export RK_USERDATA_FILESYSTEM_SIZE=32M

########################################
#             Root Config              #
########################################
# Set root data config
export RK_ROOT_FILESYSTEM_TYPE=ext4
export RK_ROOT_FILESYSTEM_SIZE=32M

########################################
#            Firmware Config           #
########################################
# setting.ini for firmware
export RK_SETTING_INI=setting-emmc.ini

########################################
#            Build Config              #
########################################
# Build jobs
export RK_JOBS=12

########################################
#              APP Config              #
########################################
# Set ui_resolution
export RK_UI_RESOLUTION=360x640
# Set face detection parameter
export RK_FACE_DETECTION_WIDTH=480
export RK_FACE_DETECTION_HEIGHT=640
export RK_FACE_DETECTION_OFFSET_X=-40
export RK_FACE_DETECTION_OFFSET_Y=20
export RK_FACE_FOV_SCALE_FACTOR_X=1
export RK_FACE_FOV_SCALE_FACTOR_Y=1

# Set UVC source
export RK_UVC_USE_SL_MODULE=n
# Set first start application
export RK_FIRST_START_APP="lock_app system_manager face_service uvc_app at_server"
