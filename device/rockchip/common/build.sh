#!/bin/bash

export LC_ALL=C
export LD_LIBRARY_PATH=
unset RK_CFG_TOOLCHAIN

SBINCHECK="$(echo $PATH | grep sbin)"

if [ x"${SBINCHECK}" = x"" ]; then
	export PATH="${PATH}:/sbin:/usr/sbin"
fi

err_handler() {
	ret=$?
	[ "$ret" -eq 0 ] && return

	echo "ERROR: Running ${FUNCNAME[1]} failed!"
	echo "ERROR: exit code $ret from line ${BASH_LINENO[0]}:"
	echo "    $BASH_COMMAND"
	exit $ret
}
trap 'err_handler' ERR
set -eE

function finish_build(){
	echo "Running ${FUNCNAME[1]} succeeded."
	cd $TOP_DIR
}

function check_config(){
	unset missing
	for var in $@; do
		eval [ \$$var ] && continue

		missing="$missing $var"
	done

	[ -z "$missing" ] && return 0

	echo "Skipping ${FUNCNAME[1]} for missing configs: $missing."
	return 1
}

function choose_target_board()
{
	echo
	echo "You're building on Linux"
	echo "Lunch menu...pick a combo:"
	echo ""

	echo "0. default BoardConfig.mk"
	echo ${RK_TARGET_BOARD_ARRAY[@]} | xargs -n 1 | sed "=" | sed "N;s/\n/. /"

	local INDEX
	read -p "Which would you like? [0]: " INDEX
	INDEX=$((${INDEX:-0} - 1))

	if echo $INDEX | grep -vq [^0-9]; then
		RK_BUILD_TARGET_BOARD="${RK_TARGET_BOARD_ARRAY[$INDEX]}"
	else
		echo "Lunching for Default BoardConfig.mk boards..."
		RK_BUILD_TARGET_BOARD=BoardConfig.mk
	fi
}

function build_select_board()
{
	RK_TARGET_BOARD_ARRAY=( $(cd ${TARGET_PRODUCT_DIR}/; ls *.mk | sort) )

	RK_TARGET_BOARD_ARRAY_LEN=${#RK_TARGET_BOARD_ARRAY[@]}
	if [ $RK_TARGET_BOARD_ARRAY_LEN -eq 0 ]; then
		echo "No available Board Config"
		return
	fi

	choose_target_board

	ln -rfs $TARGET_PRODUCT_DIR/$RK_BUILD_TARGET_BOARD device/rockchip/.BoardConfig.mk
	echo "switching to board: `realpath $BOARD_CONFIG`"
}

function unset_board_config_all()
{
	local tmp_file=`mktemp`
	grep -o "^export.*RK_.*=" `find $TOP_DIR/device/rockchip -name "Board*.mk" -type f` -h | sort | uniq > $tmp_file
	source $tmp_file
	rm -f $tmp_file
}

CMD=`realpath $0`
COMMON_DIR=`dirname $CMD`
TOP_DIR=$(realpath $COMMON_DIR/../../..)
IMGNAME=

BOARD_CONFIG=$TOP_DIR/device/rockchip/.BoardConfig.mk
TARGET_PRODUCT="$TOP_DIR/device/rockchip/.target_product"
TARGET_PRODUCT_DIR=$(realpath ${TARGET_PRODUCT})

unset_board_config_all
[ -L "$BOARD_CONFIG" ] && source $BOARD_CONFIG
source $TOP_DIR/device/rockchip/common/Version.mk
CFG_DIR=$TOP_DIR/device/rockchip
ROCKDEV=$TOP_DIR/rockdev
PARAMETER=$TOP_DIR/device/rockchip/$RK_TARGET_PRODUCT/$RK_PARAMETER
SD_PARAMETER=$TOP_DIR/device/rockchip/$RK_TARGET_PRODUCT/$RK_SD_PARAMETER

NPROC=`nproc`
export RK_JOBS=$NPROC

if [ ! -d "$TOP_DIR/rockdev/pack" ];then
	mkdir -p rockdev/pack
fi

function prebuild_uboot()
{
	UBOOT_COMPILE_COMMANDS="\
			${RK_TRUST_INI_CONFIG:+../rkbin/RKTRUST/$RK_TRUST_INI_CONFIG} \
			${RK_SPL_INI_CONFIG:+../rkbin/RKBOOT/$RK_SPL_INI_CONFIG} \
			${RK_UBOOT_SIZE_CONFIG:+--sz-uboot $RK_UBOOT_SIZE_CONFIG} \
			${RK_TRUST_SIZE_CONFIG:+--sz-trust $RK_TRUST_SIZE_CONFIG}"
	UBOOT_COMPILE_COMMANDS="$(echo $UBOOT_COMPILE_COMMANDS)"

	if [ "$RK_LOADER_UPDATE_SPL" = "true" ]; then
		UBOOT_COMPILE_COMMANDS="--spl-new $UBOOT_COMPILE_COMMANDS"
		UBOOT_COMPILE_COMMANDS="$(echo $UBOOT_COMPILE_COMMANDS)"
	fi

	if [ "$RK_RAMDISK_SECURITY_BOOTUP" = "true" ];then
		UBOOT_COMPILE_COMMANDS=" \
			--boot_img $(cd $TOP_DIR && realpath ./rockdev/boot.img) \
			--burn-key-hash $UBOOT_COMPILE_COMMANDS \
			${RK_ROLLBACK_INDEX_BOOT:+--rollback-index-boot $RK_ROLLBACK_INDEX_BOOT} \
			${RK_ROLLBACK_INDEX_UBOOT:+--rollback-index-uboot $RK_ROLLBACK_INDEX_UBOOT} "
		UBOOT_COMPILE_COMMANDS="$(echo $UBOOT_COMPILE_COMMANDS)"
	fi
}

function usagekernel()
{
	check_config RK_KERNEL_DTS RK_KERNEL_DEFCONFIG || return 0

	echo "cd kernel"
	echo "make ARCH=$RK_ARCH $RK_KERNEL_DEFCONFIG $RK_KERNEL_DEFCONFIG_FRAGMENT"
	echo "make ARCH=$RK_ARCH $RK_KERNEL_DTS.img -j$RK_JOBS"
}

function usageuboot()
{
	check_config RK_UBOOT_DEFCONFIG || return 0
	prebuild_uboot

	cd u-boot
	echo "cd u-boot"
	if [ -n "$RK_UBOOT_DEFCONFIG_FRAGMENT" ]; then
		if [ -f "configs/${RK_UBOOT_DEFCONFIG}_defconfig" ]; then
			echo "make ${RK_UBOOT_DEFCONFIG}_defconfig $RK_UBOOT_DEFCONFIG_FRAGMENT"
		else
			echo "make ${RK_UBOOT_DEFCONFIG}.config $RK_UBOOT_DEFCONFIG_FRAGMENT"
		fi
		echo "./make.sh $UBOOT_COMPILE_COMMANDS"
	else
		echo "./make.sh $RK_UBOOT_DEFCONFIG $UBOOT_COMPILE_COMMANDS"
	fi

	if [ "$RK_IDBLOCK_UPDATE_SPL" = "true" ]; then
		echo "./make.sh --idblock --spl"
	fi

	finish_build
}

function usagerootfs()
{
	check_config RK_ROOTFS_IMG || return 0

	if [ "${RK_CFG_BUILDROOT}x" != "x" ];then
		echo "source envsetup.sh $RK_CFG_BUILDROOT"
	else
		if [ "${RK_CFG_RAMBOOT}x" != "x" ];then
			echo "source envsetup.sh $RK_CFG_RAMBOOT"
		else
			echo "Not found config buildroot. Please Check !!!"
		fi
	fi

	case "${RK_ROOTFS_SYSTEM:-buildroot}" in
		yocto)
			;;
		debian)
			;;
		distro)
			;;
		*)
			echo "make"
			;;
	esac
}

function usagerecovery()
{
	check_config RK_CFG_RECOVERY || return 0

	echo "source envsetup.sh $RK_CFG_RECOVERY"
	echo "$COMMON_DIR/mk-ramdisk.sh recovery.img $RK_CFG_RECOVERY"
}

function usageramboot()
{
	check_config RK_CFG_RAMBOOT || return 0

	echo "source envsetup.sh $RK_CFG_RAMBOOT"
	echo "$COMMON_DIR/mk-ramdisk.sh ramboot.img $RK_CFG_RAMBOOT"
}

function usagemodules()
{
	check_config RK_KERNEL_DEFCONFIG || return 0

	echo "cd kernel"
	echo "make ARCH=$RK_ARCH $RK_KERNEL_DEFCONFIG"
	echo "make ARCH=$RK_ARCH modules -j$RK_JOBS"
}

function build_openwrt()
{
	TARGET_OPENWRT_CONFIG="base_defconfig"
	/usr/bin/time -f "you take %E to build OpenWRT" $COMMON_DIR/mk-openwrt.sh $TARGET_OPENWRT_CONFIG
	if [ $? -eq 0 ]; then
		echo "====Building OpenWRT OK!===="
	else
		echo "====Building OpenWRT failed!===="
		exit 1
	fi
}

function build_openwrt_sdimg()
{
	IMAGE_PATH="${TOP_DIR}/rockdev"
	BASE_IMG="${TOP_DIR}/device/rockchip/rockimg/sd.img.gz"
	TARGET_IMG="${IMAGE_PATH}/openwrt-sdcard.img"
	BOOT_IMG="${IMAGE_PATH}/openwrt-sdbootfs.img"

	if [ ! -f "${TOP_DIR}/kernel/arch/arm64/boot/Image" ]; then
		echo "No kernel found, please build kernel first!"
		exit 1
	fi

	if [ ! -f "${IMAGE_PATH}/rootfs.img" ]; then
		echo "No OpenWRT system image found, please build OpenWRT first!"
		exit 1
	fi

	dd if=/dev/zero of="${BOOT_IMG}" bs=1M count=128
	/sbin/mkfs.vfat -F 32 "${BOOT_IMG}"

	mmd -i "${BOOT_IMG}" ::extlinux
	mcopy -i "${BOOT_IMG}" "${TOP_DIR}/device/rockchip/rockimg/sd-extlinux.conf" ::extlinux/extlinux.conf
	mcopy -i "${BOOT_IMG}" "${TOP_DIR}/kernel/arch/arm64/boot/Image" ::Image
	mcopy -i "${BOOT_IMG}" "${TOP_DIR}/kernel/arch/arm64/boot/dts/rockchip/rk3568-photonicat-openwrt.dtb" ::rk3568-photonicat-openwrt.dtb

	gunzip -c "${BASE_IMG}" > "${TARGET_IMG}"
	dd if="${BOOT_IMG}" of="${TARGET_IMG}" bs=1M count=128 seek=1 conv=notrunc
	dd if="${IMAGE_PATH}/rootfs.img" of="${TARGET_IMG}" bs=1M count=1024 seek=129 conv=notrunc

	rm -f "${BOOT_IMG}"

	gzip -f "${TARGET_IMG}"
}

function build_openwrt_sdupdateimg()
{
	IMAGE_PATH="${TOP_DIR}/rockdev"
	BASE_IMG="${TOP_DIR}/device/rockchip/rockimg/sdupdate.img.gz"
	TARGET_IMG="${IMAGE_PATH}/openwrt-update-sdcard.img"
	BOOT_IMG="${IMAGE_PATH}/openwrt-sdbootfs.img"
	UPDATEIMAGE_IMG="${IMAGE_PATH}/openwrt-sdimgfs.img"

	if [ ! -f "${TOP_DIR}/kernel/arch/arm64/boot/Image" ]; then
		echo "No kernel found, please build kernel first!"
		exit 1
	fi

	if [ ! -f "${IMAGE_PATH}/rootfs.img" ]; then
		echo "No OpenWRT system image found, please build OpenWRT first!"
		exit 1
	fi

	if [ ! -f "${IMAGE_PATH}/boot.img" ]; then
		echo "No boot image found, please build kernel first!"
		exit 1
	fi

	dd if=/dev/zero of="${BOOT_IMG}" bs=1M count=128
	/sbin/mkfs.vfat -F 32 "${BOOT_IMG}"

	mmd -i "${BOOT_IMG}" ::extlinux
	mcopy -i "${BOOT_IMG}" "${TOP_DIR}/device/rockchip/rockimg/sdupdate-extlinux.conf" ::extlinux/extlinux.conf
	mcopy -i "${BOOT_IMG}" "${TOP_DIR}/kernel/arch/arm64/boot/Image" ::Image
	mcopy -i "${BOOT_IMG}" "${TOP_DIR}/kernel/arch/arm64/boot/dts/rockchip/rk3568-photonicat-openwrt.dtb" ::rk3568-photonicat-openwrt.dtb

	mkdir -p "${IMAGE_PATH}/updatefs"
	gzip -c "${IMAGE_PATH}/boot.img" > "${IMAGE_PATH}/updatefs/boot.img.gz"
	gzip -c "${IMAGE_PATH}/rootfs.img" > "${IMAGE_PATH}/updatefs/rootfs.img.gz"

	genext2fs -B 4096 -b 524288 -d "${IMAGE_PATH}/updatefs" "${UPDATEIMAGE_IMG}"
	rm -rf "${IMAGE_PATH}/updatefs"

	gunzip -c "${BASE_IMG}" > "${TARGET_IMG}"
	dd if="${BOOT_IMG}" of="${TARGET_IMG}" bs=1M count=128 seek=1 conv=notrunc
	dd if="${IMAGE_PATH}/rootfs.img" of="${TARGET_IMG}" bs=1M count=1024 seek=129 conv=notrunc
	dd if="${UPDATEIMAGE_IMG}" of="${TARGET_IMG}" bs=1M count=2048 seek=1153 conv=notrunc

	rm -f "${BOOT_IMG}"
	rm -f "${UPDATEIMAGE_IMG}"

	gzip -f "${TARGET_IMG}"

}

function usage()
{
	echo "Usage: build.sh [OPTIONS]"
	echo "Available options:"
	echo "*.mk               -switch to specified board config"
	echo "lunch              -list current SDK boards and switch to specified board config"
	echo "uboot              -build uboot"
	echo "spl                -build spl"
	echo "loader             -build loader"
	echo "kernel             -build kernel"
	echo "modules            -build kernel modules"
	echo "toolchain          -build toolchain"
	echo "extboot            -build extlinux boot.img, boot from EFI partition"
	echo "rootfs             -build default rootfs, currently build buildroot as default"
	echo "buildroot          -build buildroot rootfs"
	echo "ramboot            -build ramboot image"
	echo "multi-npu_boot     -build boot image for multi-npu board"
	echo "yocto              -build yocto rootfs"
	echo "debian             -build debian10 buster rootfs"
	echo "openwrt            -build OpenWRT rootfs"
	echo "pcba               -build pcba"
	echo "recovery           -build recovery"
	echo "all                -build uboot, kernel, rootfs, recovery image"
	echo "cleanall           -clean uboot, kernel, rootfs, recovery"
	echo "firmware           -pack all the image we need to boot up system"
	echo "updateimg          -pack update image"
	echo "otapackage         -pack ab update otapackage image (update_ota.img)"
	echo "sdpackage          -pack update sdcard package image (update_sdcard.img)"
	echo "save               -save images, patches, commands used to debug"
	echo "allsave            -build all & firmware & updateimg & save"
	echo "check              -check the environment of building"
	echo "info               -see the current board building information"
	echo "app/<pkg>          -build packages in the dir of app/*"
	echo "external/<pkg>     -build packages in the dir of external/*"
	echo "openwrt-sdimg      -build bootable OpenWRT SD card image which can be used in uboot"
	echo "openwrt-sdupdateimg -build bootable SD card for update OpenWRT on eMMC, can be used in uboot"
	echo ""
	echo "Default option is 'allff'."
}

function build_info(){
	if [ ! -L $TARGET_PRODUCT_DIR ];then
		echo "No found target product!!!"
	fi
	if [ ! -L $BOARD_CONFIG ];then
		echo "No found target board config!!!"
	fi

	echo "Current Building Information:"
	echo "Target Product: $TARGET_PRODUCT_DIR"
	echo "Target BoardConfig: `realpath $BOARD_CONFIG`"
	echo "Target Misc config:"
	echo "`env |grep "^RK_" | grep -v "=$" | sort`"

	local kernel_file_dtb

	if [ "$RK_ARCH" == "arm" ]; then
		kernel_file_dtb="${TOP_DIR}/kernel/arch/arm/boot/dts/${RK_KERNEL_DTS}.dtb"
	else
		kernel_file_dtb="${TOP_DIR}/kernel/arch/arm64/boot/dts/rockchip/${RK_KERNEL_DTS}.dtb"
	fi

	rm -f $kernel_file_dtb

	cd kernel
	make ARCH=$RK_ARCH dtbs -j$RK_JOBS
}

function build_check_power_domain(){
	local dump_kernel_dtb_file
	local tmp_phandle_file
	local tmp_io_domain_file
	local tmp_regulator_microvolt_file
	local tmp_final_target
	local tmp_none_item
	local kernel_file_dtb_dts

	if [ "$RK_ARCH" == "arm" ]; then
		kernel_file_dtb_dts="${TOP_DIR}/kernel/arch/arm/boot/dts/$RK_KERNEL_DTS"
	else
		kernel_file_dtb_dts="${TOP_DIR}/kernel/arch/arm64/boot/dts/rockchip/$RK_KERNEL_DTS"
	fi

	dump_kernel_dtb_file=${kernel_file_dtb_dts}.dump.dts
	tmp_phandle_file=`mktemp`
	tmp_io_domain_file=`mktemp`
	tmp_regulator_microvolt_file=`mktemp`
	tmp_final_target=`mktemp`

	dtc -I dtb -O dts -o ${dump_kernel_dtb_file} ${kernel_file_dtb_dts}.dtb 2>/dev/null
	grep -Pzo "io-domains\s*{(\n|\w|-|;|=|<|>|\"|_|\s|,)*};" $dump_kernel_dtb_file | grep -a supply > $tmp_io_domain_file
	awk '{print "phandle = " $3}' $tmp_io_domain_file > $tmp_phandle_file


	while IFS= read -r item_phandle && IFS= read -u 3 -r item_domain
	do
		echo "${item_domain% *}" >> $tmp_regulator_microvolt_file
		tmp_none_item=${item_domain% *}
		cmds="grep -Pzo \"{(\\n|\w|-|;|=|<|>|\\\"|_|\s)*"$item_phandle\"

		eval "$cmds $dump_kernel_dtb_file | strings | grep "regulator-m..-microvolt" >> $tmp_regulator_microvolt_file" || \
			eval "sed -i \"/${tmp_none_item}/d\" $tmp_regulator_microvolt_file" && continue

		echo >> $tmp_regulator_microvolt_file
	done < $tmp_phandle_file 3<$tmp_io_domain_file

	while read -r regulator_val
	do
		if echo ${regulator_val} | grep supply &>/dev/null; then
			echo -e "\n\n\e[1;33m${regulator_val%*=}\e[0m" >> $tmp_final_target
		else
			tmp_none_item=${regulator_val##*<}
			tmp_none_item=${tmp_none_item%%>*}
			echo -e "${regulator_val%%<*} \e[1;31m$(( $tmp_none_item / 1000 ))mV\e[0m" >> $tmp_final_target
		fi
	done < $tmp_regulator_microvolt_file

	echo -e "\e[41;1;30m PLEASE CHECK BOARD GPIO POWER DOMAIN CONFIGURATION !!!!!\e[0m"
	echo -e "\e[41;1;30m <<< ESPECIALLY Wi-Fi/Flash/Ethernet IO power domain >>> !!!!!\e[0m"
	echo -e "\e[41;1;30m Check Node [pmu_io_domains] in the file: ${kernel_file_dtb_dts}.dts \e[0m"
	echo
	echo -e "\e[41;1;30m 请再次确认板级的电源域配置！！！！！！\e[0m"
	echo -e "\e[41;1;30m <<< 特别是Wi-Fi，FLASH，以太网这几路IO电源的配置 >>> ！！！！！\e[0m"
	echo -e "\e[41;1;30m 检查内核文件 ${kernel_file_dtb_dts}.dts 的节点 [pmu_io_domains] \e[0m"
	cat $tmp_final_target

	rm -f $tmp_phandle_file
	rm -f $tmp_regulator_microvolt_file
	rm -f $tmp_io_domain_file
	rm -f $tmp_final_target
	rm -f $dump_kernel_dtb_file
}

function build_check(){
	local build_depend_cfg="build-depend-tools.txt"
	common_product_build_tools="$TOP_DIR/device/rockchip/common/$build_depend_cfg"
	target_product_build_tools="$TOP_DIR/device/rockchip/$RK_TARGET_PRODUCT/$build_depend_cfg"
	cat $common_product_build_tools $target_product_build_tools 2>/dev/null | while read chk_item
		do
			chk_item=${chk_item###*}
			echo $chk_item
			if [ -z "$chk_item" ]; then
				continue
			fi

			dst=${chk_item%%,*}
			src=${chk_item##*,}
			echo "**************************************"
			if eval $dst &>/dev/null;then
				echo "Check [OK]: $dst"
			else
				echo "Please install ${dst%% *} first"
				echo "    sudo apt-get install $src"
			fi
		done
}

function build_pkg() {
	check_config RK_CFG_BUILDROOT || check_config RK_CFG_RAMBOOT || check_config RK_CFG_RECOVERY || check_config RK_CFG_PCBA || return 0

	local target_pkg=$1
	target_pkg=${target_pkg%*/}

	if [ ! -d $target_pkg ];then
		echo "build pkg: error: not found package $target_pkg"
		return 1
	fi

	if ! eval [ $rk_package_mk_arrry ];then
		rk_package_mk_arrry=( $(find buildroot/package/rockchip/ -name "*.mk" | sort) )
	fi

	local pkg_mk pkg_config_in pkg_br pkg_final_target pkg_final_target_upper pkg_cfg

	for it in ${rk_package_mk_arrry[@]}
	do
		pkg_final_target=$(basename $it)
		pkg_final_target=${pkg_final_target%%.mk*}
		pkg_final_target_upper=${pkg_final_target^^}
		pkg_final_target_upper=${pkg_final_target_upper//-/_}
		if grep "${pkg_final_target_upper}_SITE.*$target_pkg$" $it &>/dev/null; then
			pkg_mk=$it
			pkg_config_in=$(dirname $pkg_mk)/Config.in
			pkg_br=BR2_PACKAGE_$pkg_final_target_upper

			for cfg in RK_CFG_BUILDROOT RK_CFG_RAMBOOT RK_CFG_RECOVERY RK_CFG_PCBA
			do
				if eval [ \$$cfg ] ;then
					pkg_cfg=$( eval "echo \$$cfg" )
					if grep -wq ${pkg_br}=y buildroot/output/$pkg_cfg/.config; then
						echo "Found $pkg_br in buildroot/output/$pkg_cfg/.config "
						make ${pkg_final_target}-dirclean O=buildroot/output/$pkg_cfg
						make ${pkg_final_target}-rebuild O=buildroot/output/$pkg_cfg
					else
						echo "[SKIP BUILD $target_pkg] NOT Found ${pkg_br}=y in buildroot/output/$pkg_cfg/.config"
					fi
				fi
			done
		fi
	done

	finish_build
}

function build_uboot(){
	check_config RK_UBOOT_DEFCONFIG || return 0
	prebuild_uboot

	echo "============Start building uboot============"
	echo "TARGET_UBOOT_CONFIG=$RK_UBOOT_DEFCONFIG"
	echo "========================================="

	cd u-boot
	rm -f *_loader_*.bin
	if [ "$RK_LOADER_UPDATE_SPL" = "true" ]; then
		rm -f *spl.bin
	fi
	if [ "$RK_RAMDISK_SECURITY_BOOTUP" = "true" ];then
		rm -f $TOP_DIR/u-boot/boot.img
	fi

	if [ -n "$RK_UBOOT_DEFCONFIG_FRAGMENT" ]; then
		if [ -f "configs/${RK_UBOOT_DEFCONFIG}_defconfig" ]; then
			make ${RK_UBOOT_DEFCONFIG}_defconfig $RK_UBOOT_DEFCONFIG_FRAGMENT
		else
			make ${RK_UBOOT_DEFCONFIG}.config $RK_UBOOT_DEFCONFIG_FRAGMENT
		fi
		./make.sh $UBOOT_COMPILE_COMMANDS
	else
		./make.sh $RK_UBOOT_DEFCONFIG \
			$UBOOT_COMPILE_COMMANDS
	fi
	
	if [ "$RK_LOADER_UPDATE_TPL" = "true" ]; then
		./make.sh --tpl
	fi
	
	if [ "$RK_IDBLOCK_UPDATE_SPL" = "true" ]; then
		./make.sh --idblock --spl
	fi

	if [ "$RK_RAMDISK_SECURITY_BOOTUP" = "true" ];then
		ln -rsf $TOP_DIR/u-boot/boot.img $TOP_DIR/rockdev/
	fi

	finish_build
}

# TODO: build_spl can be replaced by build_uboot with define RK_LOADER_UPDATE_SPL
function build_spl(){
	check_config RK_SPL_DEFCONFIG || return 0

	echo "============Start building spl============"
	echo "TARGET_SPL_CONFIG=$RK_SPL_DEFCONFIG"
	echo "========================================="
	if [ -f u-boot/*spl.bin ]; then
		rm u-boot/*spl.bin
	fi
	cd u-boot && ./make.sh $RK_SPL_DEFCONFIG && ./make.sh spl-s && cd -
	if [ $? -eq 0 ]; then
		echo "====Build spl ok!===="
	else
		echo "====Build spl failed!===="
		exit 1
	fi

	finish_build
}

function build_loader(){
	check_config RK_LOADER_BUILD_TARGET || return 0

	echo "============Start building loader============"
	echo "RK_LOADER_BUILD_TARGET=$RK_LOADER_BUILD_TARGET"
	echo "=========================================="
	cd loader && ./build.sh $RK_LOADER_BUILD_TARGET && cd -
	if [ $? -eq 0 ]; then
		echo "====Build loader ok!===="
	else
		echo "====Build loader failed!===="
		exit 1
	fi

	finish_build
}

function build_kernel(){
	check_config RK_KERNEL_DTS RK_KERNEL_DEFCONFIG || return 0

	echo "============Start building kernel============"
	echo "TARGET_ARCH          =$RK_ARCH"
	echo "TARGET_KERNEL_CONFIG =$RK_KERNEL_DEFCONFIG"
	echo "TARGET_KERNEL_DTS    =$RK_KERNEL_DTS"
	echo "TARGET_KERNEL_CONFIG_FRAGMENT =$RK_KERNEL_DEFCONFIG_FRAGMENT"
	echo "=========================================="
	pwd
	cd kernel
	make ARCH=$RK_ARCH $RK_KERNEL_DEFCONFIG $RK_KERNEL_DEFCONFIG_FRAGMENT
	make ARCH=$RK_ARCH $RK_KERNEL_DTS.img -j$RK_JOBS
	if [ -f "$TOP_DIR/device/rockchip/$RK_TARGET_PRODUCT/$RK_KERNEL_FIT_ITS" ]; then
		$COMMON_DIR/mk-fitimage.sh $TOP_DIR/kernel/$RK_BOOT_IMG \
			$TOP_DIR/device/rockchip/$RK_TARGET_PRODUCT/$RK_KERNEL_FIT_ITS \
			$TOP_DIR/kernel/ramdisk.img
	fi

	finish_build
}

function build_modules(){
	check_config RK_KERNEL_DEFCONFIG || return 0

	echo "============Start building kernel modules============"
	echo "TARGET_ARCH          =$RK_ARCH"
	echo "TARGET_KERNEL_CONFIG =$RK_KERNEL_DEFCONFIG"
	echo "TARGET_KERNEL_CONFIG_FRAGMENT =$RK_KERNEL_DEFCONFIG_FRAGMENT"
	echo "=================================================="
	COMMON_KMODS_DIR="${TOP_DIR}/kmods/linux"
	OPENWRT_KMODS_DIR="${TOP_DIR}/kmods/openwrt"

	if [ -d "${COMMON_KMODS_DIR}" ]; then
		rm -rf "${COMMON_KMODS_DIR}"
	fi

	if [ -d "${OPENWRT_KMODS_DIR}" ]; then
		rm -rf "${OPENWRT_KMODS_DIR}"
	fi

	mkdir -p "${COMMON_KMODS_DIR}"
	mkdir -p "${OPENWRT_KMODS_DIR}"

	cd $TOP_DIR/kernel && make ARCH=$RK_ARCH $RK_KERNEL_DEFCONFIG $RK_KERNEL_DEFCONFIG_FRAGMENT && \
		make ARCH=$RK_ARCH modules -j$RK_JOBS && \
		make ARCH=$RK_ARCH modules_install INSTALL_MOD_PATH="${COMMON_KMODS_DIR}" INSTALL_MOD_STRIP=1 && cd -
	RELEASE_NAME=$(basename "${COMMON_KMODS_DIR}/lib/modules/"*)
	OPENWRT_FULL_KMODS_DIR="${OPENWRT_KMODS_DIR}/lib/modules/${RELEASE_NAME}"
	mkdir -p "${OPENWRT_FULL_KMODS_DIR}"
	find "${COMMON_KMODS_DIR}/lib/modules/" -name "*.ko" -exec cp {} "${OPENWRT_FULL_KMODS_DIR}" \;

	if [ -d "$TOP_DIR/modules-backports" ]; then
		cd "$TOP_DIR/modules-backports" && \
			make ARCH=$RK_ARCH KLIB_BUILD="$TOP_DIR/kernel" KLIB="$COMMON_KMODS_DIR" defconfig-rk3568 && \
			make ARCH=$RK_ARCH KLIB_BUILD="$TOP_DIR/kernel" KLIB="$COMMON_KMODS_DIR" -j$RK_JOBS && \
			make ARCH=$RK_ARCH KLIB_BUILD="$TOP_DIR/kernel" KLIB="$COMMON_KMODS_DIR" install && cd -

		find "${COMMON_KMODS_DIR}/lib/modules/${RELEASE_NAME}/updates" -name "*.ko" -exec cp {} "${OPENWRT_FULL_KMODS_DIR}" \;
	fi

	tar -czf "${TOP_DIR}/kmods/kmods.tar.gz" -C "${COMMON_KMODS_DIR}" . --owner=0 --group=0
	tar -czf "${TOP_DIR}/kmods/kmods-openwrt.tar.gz" -C "${OPENWRT_KMODS_DIR}" . --owner=0 --group=0

	if [ $? -eq 0 ]; then
		echo "====Build kernel ok!===="
	else
		echo "====Build kernel failed!===="
		exit 1
	fi
}

function build_toolchain(){
	check_config RK_CFG_TOOLCHAIN || return 0

	echo "==========Start building toolchain =========="
	echo "TARGET_TOOLCHAIN_CONFIG=$RK_CFG_TOOLCHAIN"
	echo "========================================="
	[[ $RK_CFG_TOOLCHAIN ]] \
		&& /usr/bin/time -f "you take %E to build toolchain" $COMMON_DIR/mk-toolchain.sh $BOARD_CONFIG \
		|| echo "No toolchain step, skip!"
	if [ $? -eq 0 ]; then
		echo "====Build toolchain ok!===="
	else
		echo "====Build toolchain failed!===="
		exit 1
	fi

	finish_build
}

function build_buildroot(){
	check_config RK_CFG_BUILDROOT || return 0

	echo "==========Start building buildroot=========="
	echo "TARGET_BUILDROOT_CONFIG=$RK_CFG_BUILDROOT"
	echo "========================================="
	if [ -z ${RK_CFG_BUILDROOT} ];then
		echo "====No Found config on `realpath $BOARD_CONFIG`. Just exit ..."
		return
	fi
	/usr/bin/time -f "you take %E to build builroot" $COMMON_DIR/mk-buildroot.sh $BOARD_CONFIG
	if [ $? -eq 0 ]; then
		echo "====Build buildroot ok!===="
	else
		echo "====Build buildroot failed!===="
		exit 1
	fi
}

function build_ramboot(){
	check_config RK_CFG_RAMBOOT || return 0

	echo "=========Start building ramboot========="
	echo "TARGET_RAMBOOT_CONFIG=$RK_CFG_RAMBOOT"
	echo "====================================="
	if [ -z ${RK_CFG_RAMBOOT} ];then
		echo "====No Found config on `realpath $BOARD_CONFIG`. Just exit ..."
		return
	fi
	/usr/bin/time -f "you take %E to build ramboot" $COMMON_DIR/mk-ramdisk.sh ramboot.img $RK_CFG_RAMBOOT
	if [ $? -eq 0 ]; then
		rm $TOP_DIR/rockdev/boot.img
		ln -rfs $TOP_DIR/buildroot/output/$RK_CFG_RAMBOOT/images/ramboot.img $TOP_DIR/rockdev/boot.img
		echo "====Build ramboot ok!===="
	else
		echo "====Build ramboot failed!===="
		exit 1
	fi


	finish_build
}

function build_multi-npu_boot(){
	check_config RK_MULTINPU_BOOT || return 0

	echo "=========Start building multi-npu boot========="
	echo "TARGET_RAMBOOT_CONFIG=$RK_CFG_RAMBOOT"
	echo "====================================="
	/usr/bin/time -f "you take %E to build multi-npu boot" $COMMON_DIR/mk-multi-npu_boot.sh
	if [ $? -eq 0 ]; then
		echo "====Build multi-npu boot ok!===="
	else
		echo "====Build multi-npu boot failed!===="
		exit 1
	fi
}

function build_yocto(){
	check_config RK_YOCTO_MACHINE || return 0

	echo "=========Start build ramboot========="
	echo "TARGET_MACHINE=$RK_YOCTO_MACHINE"
	echo "====================================="

	export LANG=en_US.UTF-8 LANGUAGE=en_US.en LC_ALL=en_US.UTF-8

	cd yocto
	ln -sf $RK_YOCTO_MACHINE.conf build/conf/local.conf
	source oe-init-build-env
	cd ..
	bitbake core-image-minimal -r conf/include/rksdk.conf

	if [ $? -eq 0 ]; then
		echo "====Build yocto ok!===="
	else
		echo "====Build yocto failed!===="
		exit 1
	fi
}

function build_debian(){
	ARCH=${RK_DEBIAN_ARCH:-${RK_ARCH}}
	case $ARCH in
		arm|armhf) ARCH=armhf ;;
		*) ARCH=arm64 ;;
	esac

	echo "=========Start building debian for $ARCH========="

	cd debian
	if [ ! -e linaro-buster-$ARCH.tar.gz ]; then
		RELEASE=buster TARGET=desktop ARCH=$ARCH ./mk-base-debian.sh
		ln -rsf linaro-buster-alip-*.tar.gz linaro-buster-$ARCH.tar.gz
	fi

	VERSION=debug ARCH=$ARCH ./mk-rootfs-buster.sh

	./mk-image.sh
	cd ..
	if [ $? -eq 0 ]; then
		echo "====Build Debian10 ok!===="
	else
		echo "====Build Debian10 failed!===="
		exit 1
	fi
}

function build_distro(){
	check_config RK_DISTRO_DEFCONFIG || return 0

	echo "===========Start building distro==========="
	echo "TARGET_ARCH=$RK_ARCH"
	echo "RK_DISTRO_DEFCONFIG=$RK_DISTRO_DEFCONFIG"
	echo "========================================"
	cd distro && make $RK_DISTRO_DEFCONFIG && /usr/bin/time -f "you take %E to build debian" $TOP_DIR/distro/make.sh && cd -
	if [ $? -eq 0 ]; then
		echo "====Build debian ok!===="
	else
		echo "====Build debian failed!===="
		exit 1
	fi
}

function build_rootfs(){
	check_config RK_ROOTFS_IMG || return 0

	RK_ROOTFS_DIR=.rootfs
	ROOTFS_IMG=${RK_ROOTFS_IMG##*/}

	if [ "x${RK_ROOTFS_SYSTEM}" != "xubuntu" ]; then
		rm -rf $RK_ROOTFS_IMG $RK_ROOTFS_DIR
		mkdir -p ${RK_ROOTFS_IMG%/*} $RK_ROOTFS_DIR
	fi

	case "$1" in
		yocto)
			build_yocto
			ROOTFS_IMG=yocto/build/tmp/deploy/images/$RK_YOCTO_MACHINE/rootfs.img
			;;
		debian)
			build_debian
			ROOTFS_IMG=debian/linaro-rootfs.img
			;;
		distro)
			build_distro
			ROOTFS_IMG=distro/output/images/rootfs.$RK_ROOTFS_TYPE
			;;
		openwrt)
			build_openwrt
			ROOTFS_IMG="openwrt/build_dir/target-aarch64_cortex-a53_musl/linux-armvirt_64/root.squashfs"
			;;
		*)
			if [ -n $RK_CFG_BUILDROOT ];then
				build_buildroot
				ROOTFS_IMG=buildroot/output/$RK_CFG_BUILDROOT/images/rootfs.$RK_ROOTFS_TYPE
			fi
			;;
	esac

	[ -z "$ROOTFS_IMG" ] && return

	if [ ! -f "$ROOTFS_IMG" ]; then
		echo "$ROOTFS_IMG not generated?"
	else
		mkdir -p ${RK_ROOTFS_IMG%/*}
		rm -f $RK_ROOTFS_IMG
		ln -rsf $TOP_DIR/$ROOTFS_IMG $RK_ROOTFS_IMG
	fi


	finish_build
}

function build_recovery(){

	if [ "$RK_UPDATE_SDCARD_ENABLE_FOR_AB" = "true" ] ;then
		RK_CFG_RECOVERY=$RK_UPDATE_SDCARD_CFG_RECOVERY
	fi

	echo "==========Start building recovery=========="
	echo "TARGET_RECOVERY_CONFIG=$RK_CFG_RECOVERY"
	echo "========================================"
	/usr/bin/time -f "you take %E to build recovery" $COMMON_DIR/mk-ramdisk.sh recovery.img $RK_CFG_RECOVERY
	if [ $? -eq 0 ]; then
		echo "====Build recovery ok!===="
	else
		echo "====Build recovery failed!===="
		exit 1
	fi


	finish_build
}

function build_pcba(){
	check_config RK_CFG_PCBA || return 0

	echo "==========Start building pcba=========="
	echo "TARGET_PCBA_CONFIG=$RK_CFG_PCBA"
	echo "===================================="
	if [ -z ${RK_CFG_PCBA} ];then
		echo "====No Found config on `realpath $BOARD_CONFIG`. Just exit ..."
		return
	fi
	/usr/bin/time -f "you take %E to build pcba" $COMMON_DIR/mk-ramdisk.sh pcba.img $RK_CFG_PCBA
	if [ $? -eq 0 ]; then
		echo "====Build pcba ok!===="
	else
		echo "====Build pcba failed!===="
		exit 1
	fi
}

function build_all(){
	echo "============================================"
	echo "TARGET_ARCH=$RK_ARCH"
	echo "TARGET_PLATFORM=$RK_TARGET_PRODUCT"
	echo "TARGET_UBOOT_CONFIG=$RK_UBOOT_DEFCONFIG"
	echo "TARGET_SPL_CONFIG=$RK_SPL_DEFCONFIG"
	echo "TARGET_KERNEL_CONFIG=$RK_KERNEL_DEFCONFIG"
	echo "TARGET_KERNEL_DTS=$RK_KERNEL_DTS"
	echo "TARGET_TOOLCHAIN_CONFIG=$RK_CFG_TOOLCHAIN"
	echo "TARGET_BUILDROOT_CONFIG=$RK_CFG_BUILDROOT"
	echo "TARGET_RECOVERY_CONFIG=$RK_CFG_RECOVERY"
	echo "TARGET_PCBA_CONFIG=$RK_CFG_PCBA"
	echo "TARGET_RAMBOOT_CONFIG=$RK_CFG_RAMBOOT"
	echo "============================================"

	# NOTE: On secure boot-up world, if the images build with fit(flattened image tree)
	#       we will build kernel and ramboot firstly,
	#       and then copy images into u-boot to sign the images.
	if [ "$RK_RAMDISK_SECURITY_BOOTUP" != "true" ];then
		#note: if build spl, it will delete loader.bin in uboot directory,
		# so can not build uboot and spl at the same time.
		if [ -z $RK_SPL_DEFCONFIG ]; then
			build_uboot
		else
			build_spl
		fi
	fi

	build_loader
	build_kernel
	build_modules
	build_toolchain && \
	build_rootfs ${RK_ROOTFS_SYSTEM:-buildroot}
	build_recovery
	build_ramboot

	if [ "$RK_RAMDISK_SECURITY_BOOTUP" = "true" ];then
		#note: if build spl, it will delete loader.bin in uboot directory,
		# so can not build uboot and spl at the same time.
		if [ -z $RK_SPL_DEFCONFIG ]; then
			build_uboot
		else
			build_spl
		fi
	fi

	finish_build
}

function build_cleanall(){
	echo "clean uboot, kernel, rootfs, recovery"
	cd $TOP_DIR/u-boot/ && make distclean && cd -
	cd $TOP_DIR/kernel && make distclean && cd -
	rm -rf $TOP_DIR/buildroot/output
	rm -rf $TOP_DIR/yocto/build/tmp
	rm -rf $TOP_DIR/distro/output
	rm -rf $TOP_DIR/debian/binary
}

function build_firmware(){
	./mkfirmware.sh $BOARD_CONFIG
	if [ $? -eq 0 ]; then
		echo "Make image ok!"
	else
		echo "Make image failed!"
		exit 1
	fi
}


function gen_file_name() {
	day=$(date +%Y%m%d)
	time=$(date +%H%M)

	typeset -u board
	board=$(basename $(readlink ${BOARD_CONFIG}))
	board=${board%%.MK}
	rootfs=$(ls -l $TOP_DIR/rockdev/ | grep rootfs.img | awk -F '/' '{print $(NF)}'|awk -F '_' '{print $2}')
	board=${board}${rootfs}-GPT

	if [ -n "$1" ];then
		board=$board-$1
	fi

	echo -e "File name is \e[36m $board \e[0m"
	read -t 10 -e -p "Rename the file? [N|y]" ANS || :
	ANS=${ANS:-n}
	
	case $ANS in
			Y|y|yes|YES|Yes) rename=1;;
			N|n|no|NO|No) rename=0;;
			*) rename=0;;
	esac
	if [[ ${rename} == "1" ]]; then
		read -e -p "Enter new file name: " IMGNAME
		IMGNAME=$IMGNAME
	fi
	IMGNAME=${IMGNAME:-$board}
	IMGNAME=${IMGNAME}-${day}-${time}.img
}


function build_sdbootimg(){
	packm="unpack"
	[[ -n "$1" ]] && [[ $1 != "-p" ]] && usage 
	[[ -n "$1" ]] && packm="pack"

	gen_file_name SDBOOT

	if [ $packm == "pack" ];then
		cd rockdev && ./version.sh $IMGNAME init && cd -
	fi

	IMAGE_PATH=$TOP_DIR/rockdev
	PACK_TOOL_DIR=$TOP_DIR/tools/linux/Linux_Pack_Firmware

	cd $PACK_TOOL_DIR/rockdev

	if [ -f "$RK_PACKAGE_FILE_AB" ]; then
		build_sdcard_package
		build_otapackage

		cd $PACK_TOOL_DIR/rockdev
		echo "Make Linux a/b update_ab.img."
		source_package_file_name=`ls -lh package-file | awk -F ' ' '{print $NF}'`
		ln -fs "$RK_PACKAGE_FILE_AB" package-file
		./mkupdate.sh
		mv update.img $IMAGE_PATH/update_ab.img
		ln -fs $source_package_file_name package-file
	else
		echo "Make update.img"

		if [ -f "$RK_PACKAGE_FILE" ]; then
			source_package_file_name=`ls -lh package-file | awk -F ' ' '{print $NF}'`
			ln -fs "$RK_PACKAGE_FILE" package-file
			./mkupdate.sh
			ln -fs $source_package_file_name package-file
		else
			cd $PACK_TOOL_DIR/rockdev && ./mkupdate.sh && cd -
		fi
	mv $PACK_TOOL_DIR/rockdev/update.img $IMAGE_PATH/pack/$IMGNAME
	rm -rf $IMAGE_PATH/update.img
	if [ $? -eq 0 ]; then
	   echo "Make update image ok!"
	   echo -e "\e[36m $IMAGE_PATH/pack/$IMGNAME \e[0m"
	else
	   echo "Make update image failed!"
	   exit 1
	fi

	if [ $packm == "pack" ];then
		cd $TOP_DIR/rockdev && ./version.sh $IMGNAME pack && cd -
	fi
    fi
}

function build_sdupdateimg(){

	gen_file_name sdupdate

	IMAGE_PATH=$TOP_DIR/rockdev
	PACK_TOOL_DIR=$TOP_DIR/tools/linux/Linux_Pack_Firmware

	echo "Make sdupdate.img"
	if [ -f $SD_PARAMETER ]
	then
		echo -n "create parameter..."
		ln -s -f $SD_PARAMETER $ROCKDEV/parameter.txt
		echo "done."
	else
		echo -e "\e[31m error: $SD_PARAMETER not found! \e[0m"
		exit 1
	fi

	if [[ x"$RK_SD_PACKAGE_FILE" != x ]];then
		RK_PACK_TOOL_DIR=$TOP_DIR/tools/linux/Linux_Pack_Firmware/rockdev/
		cd $RK_PACK_TOOL_DIR
		rm -f package-file
		ln -sf $RK_SD_PACKAGE_FILE package-file
	fi

	cd $PACK_TOOL_DIR/rockdev && ./mkupdate.sh && cd -
	mv $PACK_TOOL_DIR/rockdev/update.img $IMAGE_PATH/pack/$IMGNAME
	rm -rf $IMAGE_PATH/update.img

	if [ $? -eq 0 ]; then
	   echo "Make sdupdate image ok!"
	   echo -e "\e[36m $IMAGE_PATH/pack/$IMGNAME \e[0m"
	else
	   echo "Make sdupdate image failed!"
	fi

	if [ -f $PARAMETER ]
	then
		ln -s -f $PARAMETER $ROCKDEV/parameter.txt
	fi

	if [[ x"$RK_PACKAGE_FILE" != x ]];then
		RK_PACK_TOOL_DIR=$TOP_DIR/tools/linux/Linux_Pack_Firmware/rockdev/
		cd $RK_PACK_TOOL_DIR
		rm -f package-file
		ln -sf $RK_PACKAGE_FILE package-file
	fi
}

function build_otapackage(){
	IMAGE_PATH=$TOP_DIR/rockdev
	PACK_TOOL_DIR=$TOP_DIR/tools/linux/Linux_Pack_Firmware

	echo "Make ota ab update_ota.img"
	cd $PACK_TOOL_DIR/rockdev
	if [ -f "$RK_PACKAGE_FILE_OTA" ]; then
		source_package_file_name=`ls -lh $PACK_TOOL_DIR/rockdev/package-file | awk -F ' ' '{print $NF}'`
		ln -fs "$RK_PACKAGE_FILE_OTA" package-file
		./mkupdate.sh
		mv update.img $IMAGE_PATH/update_ota.img
		ln -fs $source_package_file_name package-file
	fi

	finish_build
}

function build_sdcard_package(){

	check_config RK_UPDATE_SDCARD_ENABLE_FOR_AB || return 0

	local image_path=$TOP_DIR/rockdev
	local pack_tool_dir=$TOP_DIR/tools/linux/Linux_Pack_Firmware
	local rk_sdupdate_ab_misc=${RK_SDUPDATE_AB_MISC:=sdupdate-ab-misc.img}
	local rk_parameter_sdupdate=${RK_PARAMETER_SDUPDATE:=parameter-sdupdate.txt}
	local rk_package_file_sdcard_update=${RK_PACKAGE_FILE_SDCARD_UPDATE:=sdcard-update-package-file}
	local sdupdate_ab_misc_img=$TOP_DIR/device/rockchip/rockimg/$rk_sdupdate_ab_misc
	local parameter_sdupdate=$TOP_DIR/device/rockchip/rockimg/$rk_parameter_sdupdate
	local recovery_img=$TOP_DIR/buildroot/output/$RK_UPDATE_SDCARD_CFG_RECOVERY/images/recovery.img

	if [ $RK_UPDATE_SDCARD_CFG_RECOVERY ]; then
		if [ -f $recovery_img ]; then
			echo -n "create recovery.img..."
			ln -rsf $recovery_img $image_path/recovery.img
		else
			echo "error: $recovery_img not found!"
			return 1
		fi
	fi


	echo "Make sdcard update update_sdcard.img"
	cd $pack_tool_dir/rockdev
	if [ -f "$rk_package_file_sdcard_update" ]; then

		if [ $rk_parameter_sdupdate ]; then
			if [ -f $parameter_sdupdate ]; then
				echo -n "create sdcard update image parameter..."
				ln -rsf $parameter_sdupdate $image_path/
			fi
		fi

		if [ $rk_sdupdate_ab_misc ]; then
			if [ -f $sdupdate_ab_misc_img ]; then
				echo -n "create sdupdate ab misc.img..."
				ln -rsf $sdupdate_ab_misc_img $image_path/
			fi
		fi

		source_package_file_name=`ls -lh $pack_tool_dir/rockdev/package-file | awk -F ' ' '{print $NF}'`
		ln -fs "$rk_package_file_sdcard_update" package-file
		./mkupdate.sh
		mv update.img $image_path/update_sdcard.img
		ln -fs $source_package_file_name package-file
		rm -f $image_path/$rk_sdupdate_ab_misc $image_path/$rk_parameter_sdupdate $image_path/recovery.img
	fi

	finish_build
}

function build_save(){
	IMAGE_PATH=$TOP_DIR/rockdev
	DATE=$(date  +%Y%m%d.%H%M)
	STUB_PATH=Image/"$RK_KERNEL_DTS"_"$DATE"_RELEASE_TEST
	STUB_PATH="$(echo $STUB_PATH | tr '[:lower:]' '[:upper:]')"
	export STUB_PATH=$TOP_DIR/$STUB_PATH
	export STUB_PATCH_PATH=$STUB_PATH/PATCHES
	mkdir -p $STUB_PATH

	#Generate patches
	$TOP_DIR/.repo/repo/repo forall -c "$TOP_DIR/device/rockchip/common/gen_patches_body.sh"

	#Copy stubs
	$TOP_DIR/.repo/repo/repo manifest -r -o $STUB_PATH/manifest_${DATE}.xml
	mkdir -p $STUB_PATCH_PATH/kernel
	cp $TOP_DIR/kernel/.config $STUB_PATCH_PATH/kernel
	cp $TOP_DIR/kernel/vmlinux $STUB_PATCH_PATH/kernel
	mkdir -p $STUB_PATH/IMAGES/
	cp $IMAGE_PATH/* $STUB_PATH/IMAGES/

	#Save build command info
	echo "UBOOT:  defconfig: $RK_UBOOT_DEFCONFIG" >> $STUB_PATH/build_cmd_info
	echo "KERNEL: defconfig: $RK_KERNEL_DEFCONFIG, dts: $RK_KERNEL_DTS" >> $STUB_PATH/build_cmd_info
	echo "BUILDROOT: $RK_CFG_BUILDROOT" >> $STUB_PATH/build_cmd_info

}

function build_updateimg(){
	packm="unpack"
	[[ -n "$1" ]] && [[ $1 != "-p" ]] && usage 
	[[ -n "$1" ]] && packm="pack"

	gen_file_name 

	if [ $packm == "pack" ];then
		cd $TOP_DIR/rockdev \
		&& ./version.sh $IMGNAME init $2 && cd -
	fi
	
	IMAGE_PATH=$TOP_DIR/rockdev
	PACK_TOOL_DIR=$TOP_DIR/tools/linux/Linux_Pack_Firmware

	cd $PACK_TOOL_DIR/rockdev

	if [ -f "$RK_PACKAGE_FILE_AB" ]; then
		build_sdcard_package
		build_otapackage

		cd $PACK_TOOL_DIR/rockdev
		echo "Make Linux a/b update_ab.img."
		source_package_file_name=`ls -lh package-file | awk -F ' ' '{print $NF}'`
		ln -fs "$RK_PACKAGE_FILE_AB" package-file
		./mkupdate.sh
		mv update.img $IMAGE_PATH/update_ab.img
		ln -fs $source_package_file_name package-file
	else
		echo "Make update.img"

		if [ -f "$RK_PACKAGE_FILE" ]; then
			source_package_file_name=`ls -lh package-file | awk -F ' ' '{print $NF}'`
			ln -fs "$RK_PACKAGE_FILE" package-file
			./mkupdate.sh
			ln -fs $source_package_file_name package-file
		else
			./mkupdate.sh
		fi
		mv update.img $IMAGE_PATH
	fi
	
	mv $IMAGE_PATH/update.img $IMAGE_PATH/pack/$IMGNAME
	rm -rf $IMAGE_PATH/update.img
	if [ $? -eq 0 ]; then
	   echo "Make update image ok!"
	   echo -e "\e[36m $IMAGE_PATH/pack/$IMGNAME \e[0m"
	else
	   echo "Make update image failed!"
	   exit 1
	fi

	finish_build
}


function build_allff(){
	build_all
	build_firmware
	build_updateimg
}

function build_allsave(){
	rm -fr $TOP_DIR/rockdev
	build_all
	build_firmware
	build_updateimg
	build_save

	finish_build
}

#=========================
# build targets
#=========================

if echo $@|grep -wqE "help|-h"; then
	if [ -n "$2" -a "$(type -t usage$2)" == function ]; then
		echo "###Current SDK Default [ $2 ] Build Command###"
		eval usage$2
	else
		usage
	fi
	exit 0
fi

OPTIONS="${@:-allff}"

[ -f "$TOP_DIR/device/rockchip/$RK_TARGET_PRODUCT/$RK_BOARD_PRE_BUILD_SCRIPT" ] \
	&& source "$TOP_DIR/device/rockchip/$RK_TARGET_PRODUCT/$RK_BOARD_PRE_BUILD_SCRIPT"  # board hooks

for option in ${OPTIONS}; do
	echo "processing option: $option"
	case $option in
		*.mk)
			if [ -f $option ]; then
				CONF=${option}
			else
				CONF=$(find $CFG_DIR -name $option)
				echo "switching to board: $CONF"
				if [ ! -f $CONF ]; then
					echo "not exist!"
					exit 1
				fi
			fi

		    ln -rsf $CONF $BOARD_CONFIG

			unset RK_PACKAGE_FILE
			source $CONF
			if [[ x"$RK_PACKAGE_FILE" != x ]];then
				PACK_TOOL_DIR=$TOP_DIR/tools/linux/Linux_Pack_Firmware/rockdev/
				cd $PACK_TOOL_DIR
				rm -f package-file
				ln -sf $RK_PACKAGE_FILE package-file
			fi

			if [[ x"$RK_PARAMETER" != x ]];then
				PARAMETER=$TOP_DIR/device/rockchip/$RK_TARGET_PRODUCT/$RK_PARAMETER
				ln -sf $PARAMETER $ROCKDEV/parameter.txt
			else
				echo -e "\e[31m error: $SD_PARAMETER not found! \e[0m"
			fi
    
		    MKUPDATE_FILE=${RK_TARGET_PRODUCT}-mkupdate.sh 
		    if [[ x"$MKUPDATE_FILE" != x-mkupdate.sh ]];then
				PACK_TOOL_DIR=$TOP_DIR/tools/linux/Linux_Pack_Firmware/rockdev/
				cd $PACK_TOOL_DIR
				rm -f mkupdate.sh
				ln -sf $MKUPDATE_FILE mkupdate.sh
			fi

			if [[ x"$RK_PACKAGE_FILE" != x ]];then
				PACK_TOOL_DIR=$TOP_DIR/tools/linux/Linux_Pack_Firmware/rockdev/
				cd $PACK_TOOL_DIR
				rm -f package-file
				ln -sf $RK_PACKAGE_FILE package-file
			fi
			;;
		lunch) build_select_board ;;
		all) build_all ;;
		save) build_save ;;
		allsave) build_allsave ;;
		allff) build_allff ;;
		check) build_check ;;
		cleanall) build_cleanall ;;
		firmware) build_firmware ;;
		updateimg) build_updateimg ;;
		otapackage) build_otapackage ;;
		sdpackage) build_sdcard_package ;;
		toolchain) build_toolchain ;;
		spl) build_spl ;;
		uboot) build_uboot ;;
		loader) build_loader ;;
		kernel) build_kernel ;;
		modules) build_modules ;;
		rootfs|buildroot|debian|distro|yocto) build_rootfs $option ;;
		pcba) build_pcba ;;
		openwrt) build_openwrt ;;
		ramboot) build_ramboot ;;
		recovery) build_recovery ;;
		multi-npu_boot) build_multi-npu_boot ;;
		info) build_info ;;
		app/*|external/*) build_pkg $option ;;
		openwrt-sdimg) build_openwrt_sdimg ;;
		openwrt-sdupdateimg) build_openwrt_sdupdateimg ;;
		*) usage ;;
	esac
done
