#!/bin/bash
#
# 脚本通过sdk/device/rockchip/.BoardConfig.mk来确定固件名称
#，请打包前确认.BoardConfig.mk链接正确
#

usage()
{
	echo "Usage: ./version imgname "
	echo "Usage: ./version 固件名 "
	exit -1
}

init_firmware_info()
{
	#TODO
	echo "init_firmware_info"
}

package_firmware()
{
	toolsdir=$(pwd)/../tools
	mode=$(ls ./pack/$1 | grep "SDBOOT")

	if [ ! -n "$mode" ];then
		PACK_IMG="$1.7z pack/$1 pack/AndroidTool.zip pack/Linux_Upgrade_Tool"
	else 
		PACK_IMG="$1.7z pack/$1"
	fi

	rm -rf  pack/AndroidTool.zip
	rm -rf  pack/Linux_Upgrade_Tool
	cp -r -f  $toolsdir/windows/AndroidTool.zip ./pack/ 
	cp -r -f $toolsdir/linux/Linux_Upgrade_Tool/Linux_Upgrade_Tool  ./pack/ 

	7z a $PACK_IMG
	echo -e "\e[36m $rockdev/$1.7z \e[0m"

}

if [ $# -lt 1 ] ; then 
	usage
fi

if [ -n "$2" ];then
	case $2 in
		init) 
			init_firmware_info  $1 $3;;
		pack)
			package_firmware $1;;
		*) 
			init_firmware_info $1
			package_firmware $1;;
	esac
fi
