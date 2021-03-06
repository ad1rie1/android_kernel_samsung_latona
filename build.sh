#!/bin/sh
#
# Kernel build script
#
# By Mark "Hill Beast" Kennard
#

TOOLCHAIN=/usr/arm-toolchain/bin/arm-none-eabi-
ARCH=arm
MKBOOTIMG=./mkbootimg
RAMDISK=usr/ramdisk.cpio.lzma
BOOTIMAGE=normalboot.img

CPUS=`cat /proc/cpuinfo | grep processor | awk '{ print $3 }' | tail -c 3`
CPUS=`expr $CPUS + 1`
CPUCORES=`grep "cpu cores" /proc/cpuinfo | awk '{ print $4 }' | tail -c 2`
THREADS=`echo "$CPUS * $CPUCORES" | bc`

echo "$CPUS processors with $CPUCORES cores/threads = $THREADS threads total"

USEOUTDIR=`echo $1 $2 $3 $4 | grep -useout`

if [ -z $USEOUTDIR ]; then
	echo "Make will output to kernel directory"
else
	OUTDIR=/mnt/out/out
	OUTSUBDIR=`cat .git/config | grep url | sed "s|/| |" | awk '{ print $4 }'`
	USEOUTDIR="$OUTDIR/kernel/$OUTSUBDIR/"
	echo "Using output directory ($USEOUTDIR)"
	mkdir -p $USEOUTDIR 2> /dev/null
fi

if [ -z $1 ]; then
	if [ -z $KBUILD_BUILD_VERSION ]; then
		export KBUILD_BUILD_VERSION="Test-`date '+%Y%m%d-%H%M'`"
	fi
	echo "Kernel will be labelled ($KBUILD_BUILD_VERSION)"
else
	if [ $1 = "config" ]; then
		if [ -z "$USEOUTDIR" ]; then
			make menuconfig CROSS_COMPILE=$TOOLCHAIN ARCH=$ARCH
		else
			make menuconfig CROSS_COMPILE=$TOOLCHAIN ARCH=$ARCH O=$USEOUTDIR
		fi
		exit
	fi
	if [ $1 = "saveconfig" ]; then
		if [ -z $2 ]; then
			echo "You need to specify a defconfig filename"
			echo "./build.sh saveconfig [x_defconfig]"
			exit
		fi
		if test -f arch/$ARCH/configs/$2; then
			cp arch/$ARCH/configs/$2 arch/$ARCH/configs/$2.bak
		fi
		grep -v " is not set" .config > arch/$ARCH/configs/$2
		echo ".config saved to arch/$ARCH/configs/$2"
		exit
	fi
	echo "Setting kernel name to ($1)"
	export KBUILD_BUILD_VERSION=$1
fi

echo "Compiling the kernel"
if test -f $USEOUTDIR"arch/$ARCH/boot/zImage"; then
	rm $USEOUTDIR"arch/$ARCH/boot/zImage"
fi

if [ -z "$USEOUTDIR" ]; then
	echo "make -j$THREADS CROSS_COMPILE=$TOOLCHAIN ARCH=$ARCH"
	make -j$THREADS CROSS_COMPILE=$TOOLCHAIN ARCH=$ARCH
else
	echo "make -j$THREADS CROSS_COMPILE=$TOOLCHAIN ARCH=$ARCH O=$USEOUTDIR"
	make -j$THREADS CROSS_COMPILE=$TOOLCHAIN ARCH=$ARCH O=$USEOUTDIR
fi

echo $USEOUTDIR
if test -f $USEOUTDIR"arch/arm/boot/zImage"; then
	TARBALL=$KBUILD_BUILD_VERSION-boot.tar

	cd usr/ramdisk
	echo "  CPIO    usr/ramdisk.cpio"
	find . -print0 | cpio --null -ov --format=newc > ../ramdisk.cpio 2> /dev/null
	cd ..
	echo "  LZMA    usr/ramdisk.cpio.lzma"
	lzma -z -c ramdisk.cpio > ramdisk.cpio.lzma
	cd ..

	echo "  BOOTIMG $BOOTIMAGE using ramdisk ($RAMDISK)"
	$MKBOOTIMG --kernel $USEOUTDIR"arch/arm/boot/zImage" --ramdisk $RAMDISK --pagesize 4096 -o $BOOTIMAGE
	echo "  TAR     $TARBALL"
	tar cf $TARBALL $BOOTIMAGE
else
	echo "Will not tarball as make didn't produce zImage"
fi

echo "Done"
