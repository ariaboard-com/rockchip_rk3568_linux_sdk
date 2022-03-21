#!/bin/bash
pause()
{
echo "Press any key to quit:"
read -n1 -s key
exit 1
}
echo "start to make sdupdate.img..."
if [ ! -f "Image/parameter" -a ! -f "Image/parameter.txt" ]; then
	echo "Error:No found parameter!"
	exit 1
fi
if [ ! -f "package-file" ]; then
	echo "Error:No found package-file!"
	exit 1
fi
./afptool -pack ./ Image/sdupdate.img || pause
./rkImageMaker -RK320A Image/MiniLoaderAll.bin Image/sdupdate.img sdupdate.img -os_type:androidos || pause
echo "Making ./Image/update.img OK."
#echo "Press any key to quit:"
#read -n1 -s key
exit $?
