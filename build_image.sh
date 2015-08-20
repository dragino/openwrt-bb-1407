#!/usr/bin/env bash
#Build Arduino Yun Image for Dragino2. MS14, HE. 

SFLAG=
AFLAG=

APP=SIOD

REPO_PATH=$(pwd)
VERSION=3.0.1
OPENWRT_PATH="barrier_breaker"

while getopts 'a:p:v:sh' OPTION
do
	case $OPTION in
	a)	
		AFLAG=1
		APP="$OPTARG"
		;;

	p)	OPENWRT_PATH="$OPTARG"
		;;

	v)	VERSION="$OPTARG"
		;;

	s)	SFLAG=1
		;;

	h|?)	printf "Build Image for Dragino MS14, HE \n\n"
		printf "Usage: %s [-p <openwrt_source_path>] [-a <application>]  [-v <version>] [-s] \n" $(basename $0) >&2
		printf "	-p: openwrt source path, default: barrier_breaker\n"
		printf "	-a: application default: Dragino_Yun\n"
		printf "	-v: specify firmware version\n"
		printf "	-s: build in singe thread\n"
		printf "\n"
		exit 1
		;;
	esac
done

shift $(($OPTIND - 1))


BUILD=$APP-$VERSION
BUILD_TIME="`date`"

if [ -d files-$APP ];then
	echo ""
	echo "***Find customized $APP files.***"
	echo "Remove custom files from last build"
	rm -rf $OPENWRT_PATH/files
	echo "Copy files-$APP to default files directory"
	echo ""
	cp -r files-$APP $OPENWRT_PATH/files
else 
	echo ""
fi

if [ -f .config.$APP ];then
	echo ""
	echo "***Find customized .config files***"
	echo "Replace default .config file with .config.$APP"
	echo ""
	cp .config.$APP $OPENWRT_PATH/.config
fi

echo ""
echo "***Entering build directory***"
cd $OPENWRT_PATH
echo ""

echo ""
echo "***Update build version and build date***"
echo "Build: $BUILD"
echo "Build Time: $BUILD_TIME"
sed -i "s/VERSION/$BUILD/g" files/etc/banner
sed -i "s/TIME/$BUILD_TIME/g" files/etc/banner
echo ""

echo ""
echo "***Activate $APP config as default config***"
echo " Run defconfig"
echo ""
make defconfig > /dev/null

[ -f ./bin/ar71xx/openwrt-ar71xx-generic-dragino2-squashfs-sysupgrade.bin ] && rm ./bin/ar71xx/openwrt-ar71xx-generic-dragino2-squashfs-sysupgrade.bin

echo ""
if [ ! -z $SFLAG ];then
	echo "***Run make for dragion ms14, HE in single thread ***"
	make V=s
else
	echo "***Run make for dragion ms14, HE***"
	make -j8 V=99
fi


if [ ! -f ./bin/ar71xx/openwrt-ar71xx-generic-dragino2-squashfs-sysupgrade.bin ];then
	echo ""
	echo "Build Fails, run below commands to build the image in single thread and check what is wrong"
	echo "**************"
	echo "	./build_image.sh -s"
	echo "**************"
	exit 0
fi

echo "Copy Image"
echo "Set up new directory name with date"
DATE=`date +%Y%m%d-%H%M`
mkdir -p $REPO_PATH/image/$APP-build--v$VERSION--$DATE
IMAGE_DIR=$REPO_PATH/image/$APP-build--v$VERSION--$DATE

echo ""
echo  "***Move files to ./image/$APP-build--v$VERSION--$DATE ***"
cp ./bin/ar71xx/openwrt-ar71xx-generic-dragino2-kernel.bin     $IMAGE_DIR/dragino2-$APP-v$VERSION-kernel.bin
cp ./bin/ar71xx/openwrt-ar71xx-generic-dragino2-rootfs-squashfs.bin   $IMAGE_DIR/dragino2-$APP-v$VERSION-rootfs-squashfs.bin
cp ./bin/ar71xx/openwrt-ar71xx-generic-dragino2-squashfs-sysupgrade.bin $IMAGE_DIR/dragino2-$APP-v$VERSION-squashfs-sysupgrade.bin


echo ""
echo "***Update md5sums***"
cat ./bin/ar71xx/md5sums | grep "dragino2" | awk '{gsub(/openwrt-ar71xx-generic-dragino2/,"dragino2-'"$APP"'-v'"$VERSION"'")}{print}' >> $IMAGE_DIR/md5sums


echo ""
echo "***Back Up Custom Config to Image DIR***"
mkdir $IMAGE_DIR/custom_config
[ -f $REPO_PATH/.config.$APP ] && cp $REPO_PATH/.config.$APP $IMAGE_DIR/custom_config/.config
[ -d $REPO_PATH/files-$APP ] && cp -r $REPO_PATH/files-$APP $IMAGE_DIR/custom_config/files

echo ""
echo "End Dragino2 build"
echo ""
