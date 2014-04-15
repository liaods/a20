die() {
	echo "$*" >&2
	exit 1
}

[ -s "./chosen_board.mk" ] || die "please run ./configure first."

set -e

. ./chosen_board.mk

DRAGON=${PWD}/allwinner-tools/dragon/dragon
FSBUILD=${PWD}/allwinner-tools/fsbuild/fsbuild
BINS=${PWD}/allwinner-tools/bins
LIVESUIT_DIR=${PWD}/allwinner-tools/livesuit
SOURCE_DIR=${LIVESUIT_DIR}/${SOC}
BUILD_DIR=${PWD}/build/${BOARD}_livesuit
BUILD_DIR_LOCAL=build/${BOARD}_livesuit
SUNXI_TOOLS=${PWD}/sunxi-tools
ROOTFS=
RECOVERY=
BOOT=
SYSTEM=
ANDROID=false
DATE=`date +"%4Y%2m%2d"`

show_usage_and_die()
{
	echo "Usage (linux): $0 -R [rootfs.tar.gz]"
	echo "Usage (android): $0 -a -b [boot.img] -s [system.img] -r [recovery.img]"
	exit 1
}

modify_image_cfg()
{
	echo "Modifying image.cfg: $1"
	cp -rf $1 ${BUILD_DIR}/image.cfg
	sed -i -e "s|^INPUT_DIR..*$|INPUT_DIR=${BUILD_DIR}|g" \
		-e "s|^EFEX_DIR..*$|EFEX_DIR=${SOURCE_DIR}/eFex|g" \
		-e "s|^imagename..*$|imagename=${BUILD_DIR}/../../output/${BOARD}_${SOC}_kernel_livesuit_${DATE}.img|g" \
		${BUILD_DIR}/image.cfg
}



do_addchecksum()
{
	echo "Add checksum"
	# checksum for all fex (for android)
	${BINS}/FileAddSum ${BUILD_DIR}/bootloader.fex ${BUILD_DIR}/vbootloader.fex
	${BINS}/FileAddSum ${BUILD_DIR}/env.fex ${BUILD_DIR}/venv.fex
	${BINS}/FileAddSum ${BUILD_DIR}/boot.fex ${BUILD_DIR}/vboot.fex
	${BINS}/FileAddSum ${BUILD_DIR}/system.fex ${BUILD_DIR}/vsystem.fex
	${BINS}/FileAddSum ${BUILD_DIR}/recovery.fex ${BUILD_DIR}/vrecovery.fex
}

make_bootfs()
{
	echo "Make bootfs: $1"
	cp -rf ${SOURCE_DIR}/eFex/split_xxxx.fex  ${BUILD_DIR}
 	cp -rf ${SOURCE_DIR}/eFex/card/mbr.fex  ${BUILD_DIR}
	cp -rf ${SOURCE_DIR}/wboot/bootfs ${BUILD_DIR}
	cp -rf ${SOURCE_DIR}/wboot/bootfs.ini ${BUILD_DIR}
	cp -rf ${SOURCE_DIR}/wboot/diskfs.fex ${BUILD_DIR}

	sed -i -e "s|^fsname=..*$|fsname=${BUILD_DIR}/bootloader.fex|g" \
		-e "s|^root0=..*$|root0=${BUILD_DIR}/bootfs|g" ${BUILD_DIR}/bootfs.ini

	# get env.fex
	${BINS}/u_boot_env_gen $1 ${BUILD_DIR}/env.fex

	# u-boot
	${SUNXI_TOOLS}/fex2bin ${BUILD_DIR}/sys_config1.fex > ${BUILD_DIR}/bootfs/script0.bin
	${SUNXI_TOOLS}/fex2bin ${BUILD_DIR}/sys_config1.fex > ${BUILD_DIR}/bootfs/script.bin

	# other
	mkdir -pv ${BUILD_DIR}/bootfs/vendor/system/media
	echo "empty" > ${BUILD_DIR}/bootfs/vendor/system/media/vendor

	if [ $ANDROID = false ]; then
		echo "Copying linux kernel and modules"
		cp ./build/${KERNEL_CONFIG}-linux/arch/arm/boot/uImage ${BUILD_DIR}/bootfs/
		#mkdir -pv ${BUILD_DIR}/bootfs/lib/modules
		#cp -a ./build/${KERNEL_CONFIG}-linux/output/lib/modules ${BUILD_DIR}/bootfs/lib
		rm -f ${BUILD_DIR}/bootfs/lib/modules/*/source
		rm -f ${BUILD_DIR}/bootfs/lib/modules/*/build
		#nandc is reserved now
		echo "null" > ${BUILD_DIR}/boot.fex
	fi

	# build
	${BINS}/update_mbr ${BUILD_DIR}/sys_config.bin ${BUILD_DIR}/mbr.fex 4 16777216
	${FSBUILD} ${BUILD_DIR}/bootfs.ini ${BUILD_DIR}/split_xxxx.fex
}

make_boot0_boot1()
{
	echo "Make boot0 boot1"
	cp -rf ${SOURCE_DIR}/eGon/storage_media/nand/boot0.bin ${BUILD_DIR}
	cp -rf ${SOURCE_DIR}/eGon/storage_media/nand/boot1.bin ${BUILD_DIR}
	cp -rf ${SOURCE_DIR}/eGon/storage_media/sdcard/boot0.bin ${BUILD_DIR}/card_boot0.fex
	cp -rf ${SOURCE_DIR}/eGon/storage_media/sdcard/boot1.bin ${BUILD_DIR}/card_boot1.fex

	${BINS}/update_23 ${BUILD_DIR_LOCAL}/sys_config1.bin ${BUILD_DIR_LOCAL}/boot0.bin ${BUILD_DIR_LOCAL}/boot1.bin
	${BINS}/update_23 ${BUILD_DIR_LOCAL}/sys_config1.bin ${BUILD_DIR_LOCAL}/card_boot0.fex ${BUILD_DIR_LOCAL}/card_boot1.fex SDMMC_CARD
}

make_sys_configs()
{
	echo "Make sys configs: $1"
	cp $1 ${BUILD_DIR}/sys_config.fex
	${BINS}/script ${BUILD_DIR}/sys_config.fex

	cp sunxi-boards/sys_config/${SOC}/${BOARD}.fex ${BUILD_DIR}/sys_config1.fex
	${SUNXI_TOOLS}/fex2bin ${BUILD_DIR}/sys_config1.fex > ${BUILD_DIR}/sys_config1.bin

}

cp_android_files()
{
	ln -sv $RECOVERY ${BUILD_DIR}/recovery.fex
	ln -sv $BOOT ${BUILD_DIR}/boot.fex
	ln -sv $SYSTEM ${BUILD_DIR}/system.fex

}

do_pack()
{
	echo "!!!Packing!!!\n"

#    if [ $PACK_CHIP = sun4i ]; then
#	if [ $PACK_DEBUG = card0 ]; then
#	    cp $TOOLS_DIR/awk_debug_card0 out/awk_debug_card0
#	    TX=`awk  '$0~"a10"{print $2}' pctools/linux/card_debug_pin`
#	    RX=`awk  '$0~"a10"{print $3}' pctools/linux/card_debug_pin`
#	    sed -i s'/uart_debug_tx =/uart_debug_tx = '$TX'/g' out/awk_debug_card0
#	    sed -i s'/uart_debug_rx =/uart_debug_rx = '$RX'/g' out/awk_debug_card0
#	    sed -i s'/uart_tx =/uart_tx = '$TX'/g' out/awk_debug_card0
#	    sed -i s'/uart_rx =/uart_rx = '$RX'/g' out/awk_debug_card0
#	    awk -f out/awk_debug_card0 out/sys_config1.fex > out/a.fex
#	    rm out/sys_config1.fex
#	    mv out/a.fex out/sys_config1.fex
#	    echo "uart -> card0 !!!"
#	fi
#    fi
	mkdir -p ${BUILD_DIR}
	if [ $ANDROID = true ]; then
		make_sys_configs ${LIVESUIT_DIR}/default/sys_config_android.fex
		make_boot0_boot1
		make_bootfs ${LIVESUIT_DIR}/default/env_android.cfg
		modify_image_cfg ${LIVESUIT_DIR}/default/image_android.cfg
		cp_android_files
		do_addchecksum
	else
		make_sys_configs ${LIVESUIT_DIR}/default/sys_config_linux.fex
		make_boot0_boot1
		make_bootfs ${LIVESUIT_DIR}/default/env_linux.cfg
		rm -f ${BUILD_DIR}/rootfs.fex
		ln -sv "$ROOTFS" ${BUILD_DIR}/rootfs.fex
		modify_image_cfg ${LIVESUIT_DIR}/default/image_linux.cfg
	fi

	echo "Generating image"
	${DRAGON} ${BUILD_DIR}/image.cfg
	rm -rf ${BUILD_DIR}
	echo "Done"
}


pack_error()
{
    echo -e "\033[47;31mERROR: $*\033[0m"
}

cmd_done()
{
    printf "[OK]\n"
}

cmd_fail()
{
    printf "\033[0;31;1m[Failed]\033[0m\n"
    printf "\nrefer to out/pack.log for detail information.\n\n"
    pack_error "Packing Failed."
    exit 1
}

pack_cmd()
{
    printf "$* "
    local cmdlog="./cmd.log"
    $@ > $cmdlog

    local ret=1
    case "$1" in
        cp)
            if [ $? = 0 ] ; then
                ret=0
            fi
            ;;

        script)
            if grep -q "parser 1 file ok" $cmdlog ; then
                ret=0
            fi
            ;;

        update_mbr)
            if grep -q "update mbr file ok" $cmdlog ; then
                ret=0
            fi
            ;;

        update_boot0)
            if grep -q "update boot0 ok" $cmdlog ; then
                ret=0
            fi
            ;;

        fsbuild)
            if [ $2 = "bootfs.ini" -a -f ./bootfs.fex ] ; then
                ret=0
            fi
            ;;

        FileAddSum)
            if [ -f ./$2 ] ; then
                ret=0
            fi
            ;;

        dragon)
            if grep -q "Dragon execute image.cfg SUCCESS" $cmdlog ; then
                [ -f ${IMG_NAME} ] && ret=0
            fi
            ;;

        *)
            printf " [Uncheck]\n"
            cat $cmdlog >> pack.log
            echo "----------" >> pack.log
            return 0
            ;;
    esac

    cat $cmdlog >> pack.log
    echo "----------" >> pack.log

    if [ $ret -ne 0 ] ; then
        cmd_fail
    else
        cmd_done
    fi
}

do_pack_a20()
{
    echo "Packing for linux"
    export PATH=${LIVESUIT_DIR}/a20/mod_update:${LIVESUIT_DIR}/a20/eDragonEx:${LIVESUIT_DIR}/a20/fsbuild200:$PATH
    mkdir -p ${BUILD_DIR}
    cp -f ${LIVESUIT_DIR}/a20/default/* ${BUILD_DIR}
    cp sunxi-boards/sys_config/${SOC}/${BOARD}.fex ${BUILD_DIR}/sys_config.fex
    cp -r ${SOURCE_DIR}/eFex ${BUILD_DIR}
    cp -r ${SOURCE_DIR}/eGon ${BUILD_DIR}
    cp -r ${SOURCE_DIR}/wboot ${BUILD_DIR}   
    cd ${BUILD_DIR}
    
    [ -f sys_partition.fex ] && script_parse -f sys_partition.fex
    [ -f sys_config.fex ] && script_parse -f sys_config.fex

	cp -rf ${SOURCE_DIR}/eGon/boot0_nand.bin ${BUILD_DIR}/boot0_nand.bin
	cp -rf ${SOURCE_DIR}/eGon/boot1_nand.bin ${BUILD_DIR}/boot1_nand.fex
	cp -rf ${SOURCE_DIR}/eGon/boot0_sdcard.bin ${BUILD_DIR}/boot0_sdcard.fex
	cp -rf ${SOURCE_DIR}/eGon/boot1_sdcard.bin ${BUILD_DIR}/boot1_sdcard.fex

	cp -rf ${SOURCE_DIR}/eFex/split_xxxx.fex  ${BUILD_DIR}
	cp -rf ${SOURCE_DIR}/wboot/bootfs ${BUILD_DIR}
	cp -rf ${SOURCE_DIR}/wboot/bootfs.ini ${BUILD_DIR}

	sed -i -e "s|^fsname=..*$|fsname=${BUILD_DIR}/bootloader.fex|g" \
		-e "s|^root0=..*$|root0=${BUILD_DIR}/bootfs|g" ${BUILD_DIR}/bootfs.ini

    modify_image_cfg ${LIVESUIT_DIR}/a20/default/image.cfg


    busybox unix2dos sys_config.fex
    busybox unix2dos sys_partition.fex
    pack_cmd script sys_config.fex
    pack_cmd script sys_partition.fex

    cp sys_config.bin bootfs/script.bin
	cp ../${KERNEL_CONFIG}-linux/arch/arm/boot/uImage ${BUILD_DIR}/bootfs/
    # update bootlogo.bmp
    if [ -f ${BUILD_DIR}/bootlogo.bmp ]; then
        cp ${BUILD_DIR}/bootlogo.bmp bootfs/os_show/ -f
    fi
    pack_cmd update_mbr sys_partition.bin 4

    pack_cmd update_boot0 boot0_nand.bin   sys_config.bin NAND
    pack_cmd update_boot0 boot0_sdcard.fex sys_config.bin SDMMC_CARD
    pack_cmd update_boot1 boot1_nand.fex   sys_config.bin NAND
    pack_cmd update_boot1 boot1_sdcard.fex sys_config.bin SDMMC_CARD

    fsbuild bootfs.ini split_xxxx.fex

    u_boot_env_gen env.cfg env.fex

    #nandc is reserved now
    echo "null" > ${BUILD_DIR}/boot.fex
    rm -f ${BUILD_DIR}/rootfs.fex
    ln -sv "$ROOTFS" ${BUILD_DIR}/rootfs.fex

    pack_cmd dragon image.cfg sys_partition.fex

    cd ${BUILD_DIR}/../../
    if [ -e output/${IMG_NAME} ]; then
        echo '----------image is at----------'
        echo -e '\033[0;31;1m'
        echo "`pwd`/output/${BOARD}_${SOC}_kernel_livesuit_${DATE}.img"
        echo -e '\033[0m'
    fi

    cd ..
}

while getopts R:r:b:s: opt; do
	case "$opt" in
		R) ROOTFS=$(readlink -f "$OPTARG"); ANDROID=false ;;
		r) RECOVERY=$(readlink -f "$OPTARG") ;;
		b) BOOT=$(readlink -f "$OPTARG") ;;
		s) SYSTEM=$(readlink -f "$OPTARG") ;;
		a) ANDROID=true ;;
		:) show_usage_and_die ;;
		*) show_usage_and_die ;;
	esac
done

if [ $ANDROID = true ]; then
	[ -e "$RECOVERY" ] || show_usage_and_die
	[ -e "$BOOT" ] || show_usage_and_die
	[ -e "$SYSTEM" ] || show_usage_and_die
else
	[ -e "$ROOTFS" ] || show_usage_and_die
fi

if [ "${SOC}" = "a20" ]; then
    do_pack_a20
else
    do_pack
fi



