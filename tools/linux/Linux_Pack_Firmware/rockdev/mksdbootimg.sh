#!/bin/bash

SDBOOTIMG=sdboot.img
echo "Generate SD boot image : ${SDBOOTIMG} !"

LOADER1_START=64
PARAMETER=$(cat package-file | grep -wi parameter | awk '{printf $2}' | sed 's/\r//g')

PARTITIONS=()
START_OF_PARTITION=0
PARTITION_INDEX=0

rm -rf ${SDBOOTIMG}

for PARTITION in `cat ${PARAMETER} | grep '^CMDLINE' | sed 's/ //g' | sed 's/.*:\(0x.*[^)])\).*/\1/' | sed 's/,/ /g'`; do
        PARTITION_NAME=`echo ${PARTITION} | sed 's/\(.*\)(\(.*\))/\2/' | cut -f 1 -d ":"`
        PARTITION_START=`echo ${PARTITION} | sed 's/.*@\(.*\)(.*)/\1/'`
        PARTITION_LENGTH=`echo ${PARTITION} | sed 's/\(.*\)@.*/\1/'`

        PARTITIONS+=("$PARTITION_NAME")
        PARTITION_INDEX=$(expr $PARTITION_INDEX + 1)

        eval "${PARTITION_NAME}_START_PARTITION=${PARTITION_START}"
        eval "${PARTITION_NAME}_LENGTH_PARTITION=${PARTITION_LENGTH}"
        eval "${PARTITION_NAME}_INDEX_PARTITION=${PARTITION_INDEX}"
done

LAST_PARTITION_IMG=$(cat package-file | grep -wi $PARTITION_NAME | awk '{printf $2}' | sed 's/\r//g')

if [[ -f ${LAST_PARTITION_IMG} ]]; then
	IMG_ROOTFS_SIZE=$(stat -L --format="%s" ${LAST_PARTITION_IMG})
else
	IMG_ROOTFS_SIZE=0
fi

GPTIMG_MIN_SIZE=$(expr $IMG_ROOTFS_SIZE + \( $(((${PARTITION_START} + 0x2000))) \) \* 512)
GPT_IMAGE_SIZE=$(expr $GPTIMG_MIN_SIZE \/ 1024 \/ 1024 + 2)

dd if=/dev/zero of=${SDBOOTIMG} bs=1M count=0 seek=$GPT_IMAGE_SIZE
parted -s ${SDBOOTIMG} mklabel gpt

for PARTITION in ${PARTITIONS[@]}; do
    PSTART=${PARTITION}_START_PARTITION
    PLENGTH=${PARTITION}_LENGTH_PARTITION
    PINDEX=${PARTITION}_INDEX_PARTITION
    PSTART=${!PSTART}
    PLENGTH=${!PLENGTH}
    PINDEX=${!PINDEX}

    if [ "${PLENGTH}" == "-" ]; then
        echo "EXPAND"
        parted -s ${SDBOOTIMG} -- unit s mkpart ${PARTITION} $(((${PSTART} + 0x00))) -34s
    else
        PEND=$(((${PSTART} + 0x00 + ${PLENGTH})))
        parted -s ${SDBOOTIMG} unit s mkpart ${PARTITION} $(((${PSTART} + 0x00))) $(expr ${PEND} - 1)
    fi
done

UUID=$(cat ${PARAMETER} | grep 'uuid' | cut -f 2 -d "=")
VOL=$(cat ${PARAMETER} | grep 'uuid' | cut -f 1 -d "=" | cut -f 2 -d ":")
VOLINDEX=${VOL}_INDEX_PARTITION
VOLINDEX=${!VOLINDEX}

gdisk ${SDBOOTIMG} <<EOF
x
c
${VOLINDEX}
${UUID}
w
y
EOF

dd if=Image/idbloader.img of=${SDBOOTIMG} seek=${LOADER1_START} conv=notrunc

for PARTITION in ${PARTITIONS[@]}; do
    PSTART=${PARTITION}_START_PARTITION
    PSTART=${!PSTART}

    IMGFILE=$(cat package-file | grep -wi ${PARTITION} | awk '{printf $2}' | sed 's/\r//g')

    if [[ x"$IMGFILE" != x ]]; then
		if [[ -f "$IMGFILE" ]]; then
			echo ${PARTITION} ${IMGFILE} ${PSTART}
			dd if=${IMGFILE}  of=${SDBOOTIMG} seek=$(((${PSTART} + 0x00))) conv=notrunc,fsync
		else
			if [[ x"$IMGFILE" != xRESERVED ]]; then
				echo -e "\e[31m error: $IMGFILE not found! \e[0m"
			fi
		fi
    fi
done

echo "mk sdboot img OK"
