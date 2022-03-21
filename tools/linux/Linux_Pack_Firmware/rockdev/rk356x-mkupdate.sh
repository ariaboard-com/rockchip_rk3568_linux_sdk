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

./afptool -pack ./ Image/update.img || pause
./rkImageMaker -RK3568 Image/MiniLoaderAll.bin Image/update.img update.img -os_type:androidos || pause
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
