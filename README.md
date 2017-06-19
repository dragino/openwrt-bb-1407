Experimental code base on Barrier Breaker 14.07

IoT Mesh -- A Generic OpenWrt Version with mesh, IoT, VoIP support for Dragino Devices. 
===============
This repository is a generic OpenWrt version from Dragino devices such as:
[MS14](http://www.dragino.com/products/mother-board.html), [HE](http://www.dragino.com/products/linux-module/item/87-he.html) and [Yun Shield](http://www.dragino.com/products/yunshield.html).

The user manual of this version can be found at [IoT Mesh Online Manual](http://wiki.dragino.com/index.php?title=IoT_Mesh_Firmware_User_Manual).

There is another Arduino Yun Alike firmware version. With the source in [this link](https://github.com/dragino/openwrt-yun)

Difference between these two firmware can be found [difference between IoT Mesh and Dragino Yun firmware](http://wiki.dragino.com/index.php?title=Firmware_and_Source_Code)

How to compile the image?
===============
Below procedure are basic on a Ubuntu 14.04 machine. 
``` bash
git clone https://github.com/dragino/openwrt-bb-1407.git dragino2-BB-IoT
cd dragino2-BB-IoT
./set_up_build_enviroment.sh
#build default IoT App on barrier_breaker directory
./build_image.sh -a IoT
```

After complination, the images can be found on **dragino2-BB-IoT/image** folder. The folder includes:
- openwrt-ar71xx-generic-dragino2-kernel.bin  kernel files, for upgrade in u-boot
- openwrt-ar71xx-generic-dragino2-rootfs-squashfs.bin    rootfs file, for upgrade in u-boot
- openwrt-ar71xx-generic-dragino2-squashfs-sysupgrade.bin   sysupgrade file, used for web-ui upgrade
- md5sum  md5sum for above files


More build option can be viewed by running:
``` bash
./build_image.sh -h
```

How to debug if build fails?
===============
``` bash
./build_image.sh -s
```
Above commands will enable verbose and build in single thread to get a view of the error during build. 


How to customized a build?
===============
As a example, if user want to customize a build named mybuild. mybuild include different packages and default files from the default build. User can do as below:
To customize the packages 
``` bash
cd barrier_breaker
# run make menuconfig to select the packages and save
make menuconfig
#Copy the new config to TOP dir and rename it to .config.mybuild
cp .config .config.mybuild
```
To customize default files
``` bash
#create default files in TOP dir
mkdir files-mybuild
#put files into this directory. 
#for example, if user want the final build has a default config file /etc/config/network. user can 
#put /etc/config/network into the files-mybuild directory (include directory /etc and /etc/config)
```

Then run the customzied build by running:
``` bash
./build_image.sh -a mybuild
```
The build process will auto overwrite the default files or pacakges with the customized one. User can customize only default files or pacakges. The build will use the default from IoT build if not specify. 

Have Fun!

Dragino Technology
