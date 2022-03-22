#!/bin/bash 

[[ -z $1 ]] && exit

IMG=$1
TEMPDIR=$(mktemp -d -p .)
cd $TEMPDIR

ln -sf ../$IMG
zcat $IMG | cpio -idmv
rm -rf $IMG

sed -i '/^\/dev\/block\/by-name\/userdata/s/ext2/ext4/g' etc/fstab

find . | cpio -H newc -o | gzip > ../$IMG

cd -
rm -rf $TEMPDIR
