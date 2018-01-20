#!/usr/bin/env bash
#Set up build environment for Dragino v2. Only need to run once on first compile. 

USAGE="Usage: . ./set_up_build_enviroment.sh /your/preferred/source/installation/path"

OPENWRT_PATH=barrier_breaker

while getopts 'p:v:sh' OPTION
do
	case $OPTION in
	p)	OPENWRT_PATH="$OPTARG"
		;;
	h|?)	printf "Set Up build environment for MS14, HE \n\n"
		printf "Usage: %s [-p <openwrt_source_path>]\n" $(basename $0) >&2
		printf "	-p: set up build path, default path = dragino\n"
		printf "\n"
		exit 1
		;;
	esac
done

shift $(($OPTIND - 1))

REPO_PATH=$(pwd)


echo " "
echo "*** Checkout the OpenWRT build environment to directory $OPENWRT_PATH"
sleep 5
mkdir -p $OPENWRT_PATH
git clone https://github.com/openwrt/archive.git $OPENWRT_PATH
cd $OPENWRT_PATH
git checkout barrier_breaker
cd ..

echo "*** Backup original feeds files if they exist"
sleep 2
mv $OPENWRT_PATH/feeds.conf.default  $OPENWRT_PATH/feeds.conf.default.bak

echo "*** Copy feeds used in Dragino"
sleep 2
cp feeds.dragino $OPENWRT_PATH/feeds.conf.default

echo " "
echo "*** Update the feeds (See ./feeds-update.log)"
sleep 2
$OPENWRT_PATH/scripts/feeds update
sleep 2
echo " "

echo " "
echo "replace some packages with local source"
echo " "
rm -rf $OPENWRT_PATH/feeds/oldpackages/utils/avrdude
rm -rf $OPENWRT_PATH/feeds/packages/utils/rng-tools
rm -rf $OPENWRT_PATH/feeds/packages/net/mosquitto
cp -r replacement-pkgs/avrdude $OPENWRT_PATH/feeds/oldpackages/utils/
cp -r replacement-pkgs/rng-tools $OPENWRT_PATH/feeds/packages/utils/
cp -r replacement-pkgs/mosquitto $OPENWRT_PATH/feeds/packages/net/

echo "*** Install OpenWrt packages"
sleep 10
$OPENWRT_PATH/scripts/feeds install -a
echo " "

echo ""
echo "Patch Dragino2 Platform"
rsync -avC platform/target/ $OPENWRT_PATH/target/


echo " "
echo "*** Install OpenWrt BB 14.07 patches"
cp bb_1407_patch/619-MIPS-ath79-Linino-uart-fix-baudrate.patch $OPENWRT_PATH/target/linux/ar71xx/patches-3.10/
cp bb_1407_patch/903-ar933x_uart_baud_max_step_fix.patch $OPENWRT_PATH/target/linux/ar71xx/patches-3.10/
cp bb_1407_patch/730-MIPS-ath79-add-dragino-siod-support.patch $OPENWRT_PATH/target/linux/ar71xx/patches-3.10/
echo " "

#Remove tmp directory
rm -rf $OPENWRT_PATH/tmp/


echo "*** Change to build directory"
cd $OPENWRT_PATH
echo " "

echo "*** Run make defconfig to set up initial .config file (see ./defconfig.log)"
make defconfig > ./defconfig.log

# Backup the .config file
cp .config .config.orig
echo " "

echo "End of script"
