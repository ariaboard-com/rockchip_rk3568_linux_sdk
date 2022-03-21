#!/bin/bash
pause()
{
echo "Press any key to quit:"
read -n1 -s key
exit 1
}

echo "start to make update.img..."
if [ ! -f "Image/parameter" -a ! -f "Image/parameter.txt" ]; then
	echo "Error:No found parameter!"
	exit 1
fi
if [ ! -f "package-file" ]; then
	echo "Error:No found package-file!"
	exit 1
fi

ALIGN()
{
	X=$1
	A=$2
	OUT=$(($((${X} + ${A} -1 ))&$((~$((${A}-1))))))
	printf 0x%x ${OUT}
}

ROOTFS_LAST=$(grep "rootfs:grow" Image/parameter.txt)
if [ -z "${ROOTFS_LAST}" ]
then
echo "Resize rootfs partition size"
FILE_P=$(readlink -f Image/rootfs.img)
FS_INFO=$(dumpe2fs -h ${FILE_P})
BLOCK_COUNT=$(echo "${FS_INFO}" | grep "^Block count" | cut -d ":" -f 2 | tr -d "[:blank:]")
INODE_COUNT=$(echo "${FS_INFO}" | grep "^Inode count" | cut -d ":" -f 2 | tr -d "[:blank:]")
BLOCK_SIZE=$(echo "${FS_INFO}" | grep "^Block size" | cut -d ":" -f 2 | tr -d "[:blank:]")
INODE_SIZE=$(echo "${FS_INFO}" | grep "^Inode size" | cut -d ":" -f 2 | tr -d "[:blank:]")
BLOCK_SIZE_IN_S=$((${BLOCK_SIZE}>>9))
INODE_SIZE_IN_S=$((${INODE_SIZE}>>9))
SKIP_BLOCK=70
EXTRA_SIZE=$(expr 50 \* 1024 \* 2 ) #50M

FSIZE=$(expr ${BLOCK_COUNT} \* ${BLOCK_SIZE_IN_S} + ${INODE_COUNT} \* ${INODE_SIZE_IN_S} + ${EXTRA_SIZE} + ${SKIP_BLOCK})
PSIZE=$(ALIGN $((${FSIZE})) 512)
PARA_FILE=$(readlink -f Image/parameter.txt)

ORIGIN=$(grep -Eo "0x[0-9a-fA-F]*@0x[0-9a-fA-F]*\(rootfs" $PARA_FILE)
NEWSTR=$(echo $ORIGIN | sed "s/.*@/${PSIZE}@/g")
OFFSET=$(echo $NEWSTR | grep -Eo "@0x[0-9a-fA-F]*" | cut -f 2 -d "@")
NEXT_START=$(printf 0x%x $(($PSIZE + $OFFSET)))
sed -i.orig "s/$ORIGIN/$NEWSTR/g" $PARA_FILE
sed -i "/^CMDLINE.*/s/-@0x[0-9a-fA-F]*/-@$NEXT_START/g" $PARA_FILE
fi

./afptool -pack ./ Image/update.img || pause
./rkImageMaker -RK320A Image/MiniLoaderAll.bin Image/update.img update.img -os_type:androidos || pause
echo "Making ./Image/update.img OK."
#echo "Press any key to quit:"
#read -n1 -s key
if [ -e ${PARA_FILE}.orig ]
then
	mv ${PARA_FILE}.orig ${PARA_FILE}
	exit $?
else
	exit 0
fi
