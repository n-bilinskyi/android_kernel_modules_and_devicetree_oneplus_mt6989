#!/bin/bash

source kernel/oplus/build/oplus_setup.sh $1 $2
init_build_environment

function get_image_info() {

    ${AVBTOOL} info_image --image  ${ORIGIN_IMAGE}/boot.img >  ${ORIGIN_IMAGE}/local_boot_image_info.txt
    ${AVBTOOL} info_image --image  ${ORIGIN_IMAGE}/vendor_boot.img >  ${ORIGIN_IMAGE}/local_vendor_boot_image_info.txt
    ${AVBTOOL} info_image --image  ${ORIGIN_IMAGE}/system_dlkm.img >  ${ORIGIN_IMAGE}/local_system_dlkm_info.txt
    ${AVBTOOL} info_image --image  ${ORIGIN_IMAGE}/vendor_dlkm.img >  ${ORIGIN_IMAGE}/local_vendor_dlkm_image_info.txt
    ${AVBTOOL} info_image --image  ${ORIGIN_IMAGE}/dtbo.img >  ${ORIGIN_IMAGE}/local_dtbo_image_info.txt
    ${AVBTOOL} info_image --image  ${ORIGIN_IMAGE}/vbmeta.img >  ${ORIGIN_IMAGE}/local_vbmeta_image_info.txt
    ${AVBTOOL} info_image --image  ${ORIGIN_IMAGE}/vbmeta_system.img >  ${ORIGIN_IMAGE}/local_vbmeta_system_image_info.txt
    ${AVBTOOL} info_image --image  ${ORIGIN_IMAGE}/vbmeta_vendor.img >  ${ORIGIN_IMAGE}/local_vbmeta_vendor_image_info.txt
}


function sign_boot_image() {

    algorithm=$(awk -F '[= ]' '$1=="avb_boot_algorithm" {$1="";print}' ${ORIGIN_IMAGE}/misc_info.txt)
    partition_size=$(awk -F '[= ]' '$1=="boot_size" {$1="";print}' ${ORIGIN_IMAGE}/misc_info.txt)
    footer_args=$(awk -F '[= ]' '$1=="avb_boot_add_hash_footer_args" {$1="";print}' ${ORIGIN_IMAGE}/misc_info.txt)
    partition_name=boot
    salt=`uuidgen | sed 's/-//g'`
    ${AVBTOOL} add_hash_footer \
        --image ${IMAGE_OUT}/boot.img  \
        --partition_name ${partition_name} \
        --partition_size ${partition_size}\
        --algorithm ${algorithm} \
        --key ${ORIGIN_IMAGE}/testkey_rsa2048.pem \
        --salt ${salt} \
        ${footer_args}

}

function sign_vendor_boot_image() {

    algorithm=$(awk -F '[= ]' '$1=="avb_vendor_boot_algorithm" {$1="";print}' ${ORIGIN_IMAGE}/misc_info.txt)
    partition_size=$(awk -F '[= ]' '$1=="vendor_boot_size" {$1="";print}' ${ORIGIN_IMAGE}/misc_info.txt)
    footer_args=$(awk -F '[= ]' '$1=="avb_vendor_boot_add_hash_footer_args" {$1="";print}' ${ORIGIN_IMAGE}/misc_info.txt)
    partition_name=vendor_boot
    salt=`uuidgen | sed 's/-//g'`

    if [ -z "$algorithm" ]; then
     algorithm="SHA256_RSA4096"
    fi

    if [ -z "$partition_size" ]; then
     partition_size=`cat ${ORIGIN_IMAGE}/local_vendor_boot_image_info.txt | grep "Image size:" | awk '{print $3 }'`
    fi

    ${AVBTOOL} add_hash_footer \
        --image ${IMAGE_OUT}/vendor_boot.img  \
        --partition_name ${partition_name} \
        --partition_size ${partition_size}\
        --algorithm ${algorithm} \
        --key ${ORIGIN_IMAGE}/testkey_rsa4096.pem \
        --salt ${salt} \
        ${footer_args}

}

function sign_dtbo_image() {

    algorithm=$(awk -F '[= ]' '$1=="avb_dtbo_algorithm" {$1="";print}' ${ORIGIN_IMAGE}/misc_info.txt)
    partition_size=$(awk -F '[= ]' '$1=="dtbo_size" {$1="";print}' ${ORIGIN_IMAGE}/misc_info.txt)
    footer_args=$(awk -F '[= ]' '$1=="avb_dtbo_add_hash_footer_args" {$1="";print}' ${ORIGIN_IMAGE}/misc_info.txt)
    partition_name=dtbo
    salt=`uuidgen | sed 's/-//g'`
    if [ -z "$algorithm" ]; then
     algorithm="SHA256_RSA4096"
    fi
    ${AVBTOOL} add_hash_footer \
        --image ${IMAGE_OUT}/dtbo.img  \
        --partition_name ${partition_name} \
        --partition_size ${partition_size}\
        --algorithm ${algorithm} \
        --key ${ORIGIN_IMAGE}/testkey_rsa4096.pem \
        --salt ${salt} \
        ${footer_args}

}

function sign_vendor_dlkm_image() {
    algorithm=$(awk -F '[= ]' '$1=="avb_vendor_dlkm_algorithm" {$1="";print}' ${ORIGIN_IMAGE}/vendor_dlkm_image_info.txt)
    footer_args=$(awk -F '[= ]' '$1=="avb_vendor_dlkm_add_hashtree_footer_args" {$1="";print}' ${ORIGIN_IMAGE}/vendor_dlkm_image_info.txt)
    partition_name=vendor_dlkm
    salt=`uuidgen | sed 's/-//g'`

    if [ -z "$algorithm" ]; then
     algorithm="SHA256_RSA4096"
    fi

    ${AVBTOOL} add_hashtree_footer \
        --partition_name ${partition_name} \
        --use_persistent_digest \
        --do_not_generate_fec \
        --image ${IMAGE_OUT}/vendor_dlkm.img  \
        --hash_algorithm sha256 \
        --salt ${salt}  \
        ${footer_args}

}

function sign_system_dlkm_image() {
    algorithm=$(awk -F '[= ]' '$1=="avb_system_dlkm_algorithm" {$1="";print}' ${ORIGIN_IMAGE}/system_dlkm_image_info.txt)
    footer_args=$(awk -F '[= ]' '$1=="avb_add_hashtree_footer_args" {$1="";print}' ${ORIGIN_IMAGE}/system_dlkm_image_info.txt)
    partition_name=system_dlkm
    salt=`uuidgen | sed 's/-//g'`

    if [ -z "$algorithm" ]; then
     algorithm="SHA256_RSA4096"
    fi

    ${AVBTOOL} add_hashtree_footer \
        --partition_name ${partition_name} \
        --use_persistent_digest \
        --do_not_generate_fec \
        --image ${IMAGE_OUT}/system_dlkm.img  \
        --hash_algorithm sha256 \
        --salt ${salt}  \
        ${footer_args}
}

function sign_prebuild_image() {
    sign_boot_image
    sign_vendor_boot_image
    sign_dtbo_image
    sign_vendor_dlkm_image
    sign_system_dlkm_image
}

modules_update() {
    local RAMDISK_MOD_DIR=$1
    local MODULES_DIR=$2

    echo "Update modules in <${RAMDISK_MOD_DIR}> "

    for stock_ko_path in ${RAMDISK_MOD_DIR}/*.ko; do
        ko=$(basename "$stock_ko_path")
        current=`find ${MODULES_DIR} -name ${ko} -print -quit`
        if [ -n "${current}" ]; then
            echo "  [+] WARNING: Found OSS version of ${ko}"
            ${STRIP} -S ${current} -o ${RAMDISK_MOD_DIR}/${ko}
        else
            echo "  [-] WARNING: Not found OSS version of ${ko}"
            # rm ${RAMDISK_MOD_DIR}/${ko}
        fi
    done
    ko_list=`cat ${RAMDISK_MOD_DIR}/modules.load | xargs -L 1 basename`
    for ko in  $ko_list
    do
        current=`find ${RAMDISK_MOD_DIR} -name ${ko}`
        if [ -n "${current}" ]; then
            echo ${ko} >> ${RAMDISK_MOD_DIR}/modules.load.new
        else
            echo "[-] WARNING: Removing ${ko} from modules.load"
        fi
    done
    mv ${RAMDISK_MOD_DIR}/modules.load.new ${RAMDISK_MOD_DIR}/modules.load

}


rebuild_boot_image() {
    echo "rebuild boot.img start"
    rm -rf ${BOOT_TMP_IMAGE}/*
    boot_mkargs=$(${PYTHON_TOOL} ${UNPACK_BOOTIMG_TOOL} --boot_img ${ORIGIN_IMAGE}/boot.img --out ${BOOT_TMP_IMAGE} --format=mkbootimg)
    cp ${KERNEL_IMG}/Image.lz4 ${BOOT_TMP_IMAGE}/kernel
    bash -c "${PYTHON_TOOL} ${MKBOOTIMG_PATH} ${boot_mkargs} -o ${IMAGE_OUT}/boot.img"
    sign_boot_image
    echo "rebuild boot.img end"
}

rebuild_dtb_image() {
    echo "rebuild dtb"
    # cp ${ORIGIN_IMAGE}/dtb ${VENDOR_BOOT_TMP_IMAGE}/origin/
}

vendor_boot_modules_all_update() {
    echo "vendor_boot module update begin"
    modules_update "${VENDOR_BOOT_TMP_IMAGE}/ramdisk00/lib/modules" ${VENDOR_MODULES_DIR}
    echo "vendor_boot module update end"
}

rebuild_vendor_boot_image() {
    echo "rebuild vendor_boot.img"
    rm -rf ${VENDOR_BOOT_TMP_IMAGE}/*
    boot_mkargs=$(${PYTHON_TOOL} ${UNPACK_BOOTIMG_TOOL} --boot_img ${ORIGIN_IMAGE}/vendor_boot.img --out ${VENDOR_BOOT_TMP_IMAGE}/origin --format=mkbootimg)
    rebuild_dtb_image
    index="00"
    for index in  $index
    do
        echo " index  $index "
        mv ${VENDOR_BOOT_TMP_IMAGE}/origin/vendor_ramdisk${index} ${VENDOR_BOOT_TMP_IMAGE}/vendor_ramdisk${index}.lz4
        #touch ${VENDOR_BOOT_TMP_IMAGE}/vendor_ramdisk${index}
        ${LZ4} -d -f ${VENDOR_BOOT_TMP_IMAGE}/vendor_ramdisk${index}.lz4 ${VENDOR_BOOT_TMP_IMAGE}/vendor_ramdisk${index}
        rm ${VENDOR_BOOT_TMP_IMAGE}/vendor_ramdisk${index}.lz4
        mkdir -p ${VENDOR_BOOT_TMP_IMAGE}/ramdisk${index}
        mv ${VENDOR_BOOT_TMP_IMAGE}/vendor_ramdisk${index} ${VENDOR_BOOT_TMP_IMAGE}/ramdisk${index}/vendor_ramdisk${index}
        pushd  ${VENDOR_BOOT_TMP_IMAGE}/ramdisk${index}
        ${CPIO} -idu < ${VENDOR_BOOT_TMP_IMAGE}/ramdisk${index}/vendor_ramdisk${index}

        popd
        rm ${VENDOR_BOOT_TMP_IMAGE}/ramdisk${index}/vendor_ramdisk${index}

        vendor_boot_modules_all_update
        ${MKBOOTFS} ${VENDOR_BOOT_TMP_IMAGE}/ramdisk${index} > ${VENDOR_BOOT_TMP_IMAGE}/vendor_ramdisk${index}
        #touch ${VENDOR_BOOT_TMP_IMAGE}/vendor_ramdisk${index}.lz4
        ${LZ4} -l -f -12 --favor-decSpeed ${VENDOR_BOOT_TMP_IMAGE}/vendor_ramdisk${index} ${VENDOR_BOOT_TMP_IMAGE}/vendor_ramdisk${index}.lz4
        mv ${VENDOR_BOOT_TMP_IMAGE}/vendor_ramdisk${index}.lz4 ${VENDOR_BOOT_TMP_IMAGE}/origin/vendor_ramdisk${index}
        rm ${VENDOR_BOOT_TMP_IMAGE}/vendor_ramdisk${index}
    done
    bash -c "${PYTHON_TOOL} ${MKBOOTIMG_PATH} ${boot_mkargs} --vendor_boot ${IMAGE_OUT}/vendor_boot.img"
    sign_vendor_boot_image
}

rebuild_vendor_dlkm_image() {
    echo "rebuild vendor_dlkm.img"
    mkdir -p ${VENDOR_DLKM_TMP_IMAGE}
    cp ${ORIGIN_IMAGE}/vendor_dlkm.img  ${VENDOR_DLKM_TMP_IMAGE}/vendor_dlkm.img
    ${TOOLS}/7z_new ${VENDOR_DLKM_TMP_IMAGE}/vendor_dlkm.img ${VENDOR_DLKM_TMP_IMAGE}/vendor_dlkm_out
    ${BUILD_IMAGE} ${VENDOR_DLKM_TMP_IMAGE}/vendor_dlkm_out ${TOOLS}/vendor_dlkm_image_info.txt ${VENDOR_DLKM_TMP_IMAGE}/vendor_dlkm.img /dev/null
}

vendor_dlkm_modules_update() {
    echo "vendor_dlkm module update begin"
    modules_update "${VENDOR_DLKM_TMP_IMAGE}/vendor_dlkm/lib/modules" ${VENDOR_MODULES_DIR}
    echo "vendor_dlkm module update end"
}

rebuild_vendor_dlkm_config() {
   sed  '/vendor_dlkm_selinux_fc*/d;/block_list*/d' ${TOOLS}/vendor_dlkm_image_info.txt > ${TOOLS}/local_vendor_dlkm_image_info.txt
   echo vendor_dlkm_selinux_fc=${ORIGIN_IMAGE}/file_contexts.bin >> ${TOOLS}/local_vendor_dlkm_image_info.txt
   echo block_list=${VENDOR_DLKM_TMP_IMAGE}/vendor_dlkm.map >> ${TOOLS}/local_vendor_dlkm_image_info.txt
}

rebuild_vendor_dlkm_erofs_image() {
    echo "rebuild vendor_dlkm.img"
    rm -rf ${VENDOR_DLKM_TMP_IMAGE}/*
    mkdir -p ${VENDOR_DLKM_TMP_IMAGE}
    cp ${ORIGIN_IMAGE}/vendor_dlkm.img  ${VENDOR_DLKM_TMP_IMAGE}/vendor_dlkm.img
    ${TOOLS}/erofs_unpack.sh ${VENDOR_DLKM_TMP_IMAGE}/vendor_dlkm.img  ${VENDOR_DLKM_TMP_IMAGE}/mnt ${VENDOR_DLKM_TMP_IMAGE}/vendor_dlkm
    vendor_dlkm_modules_update
    touch ${VENDOR_DLKM_TMP_IMAGE}/vendor_dlkm/lib/modules/readme.txt
    echo $(date +"%Y_%m_%d_%H_%M_%S") >${VENDOR_DLKM_TMP_IMAGE}/vendor_dlkm/lib/modules/readme.txt
    rebuild_vendor_dlkm_config
    PATH=${BIN}/:$PATH \
        ${TOOLS}/bin/build_image \
        ${VENDOR_DLKM_TMP_IMAGE}/vendor_dlkm \
        ${TOOLS}/local_vendor_dlkm_image_info.txt \
        ${VENDOR_DLKM_TMP_IMAGE}/vendor_dlkm.img \
        ${VENDOR_DLKM_TMP_IMAGE}/
    cp ${VENDOR_DLKM_TMP_IMAGE}/vendor_dlkm.img ${IMAGE_OUT}/vendor_dlkm.img
    sign_vendor_dlkm_image

}

rebuild_system_dlkm_config() {
   sed  '/system_dlkm_selinux_fc*/d;/block_list*/d' ${TOOLS}/system_dlkm_image_info.txt > ${TOOLS}/local_system_dlkm_image_info.txt
   echo system_dlkm_selinux_fc=${ORIGIN_IMAGE}/file_contexts.bin >> ${TOOLS}/local_system_dlkm_image_info.txt
   echo block_list=${SYSTEM_DLKM_TMP_IMAGE}/system_dlkm.map >> ${TOOLS}/local_system_dlkm_image_info.txt
}

system_dlkm_modules_update() {
    echo "system_dlkm module update begin"
    modules_update "${SYSTEM_DLKM_TMP_IMAGE}/system_dlkm/lib/modules" ${SYSTEM_MODULES_DIR}
    echo "system_dlkm module update end"
}

rebuild_system_dlkm_erofs_image() {
    echo "rebuild system_dlkm.img"
    rm -rf ${SYSTEM_DLKM_TMP_IMAGE}/*
    mkdir -p ${SYSTEM_DLKM_TMP_IMAGE}
    cp ${ORIGIN_IMAGE}/system_dlkm.img  ${SYSTEM_DLKM_TMP_IMAGE}/system_dlkm.img
    ${TOOLS}/erofs_unpack.sh ${SYSTEM_DLKM_TMP_IMAGE}/system_dlkm.img  ${SYSTEM_DLKM_TMP_IMAGE}/mnt ${SYSTEM_DLKM_TMP_IMAGE}/system_dlkm
    system_dlkm_modules_update
    rebuild_system_dlkm_config
    PATH=${BIN}/:$PATH \
        ${TOOLS}/bin/build_image \
        ${SYSTEM_DLKM_TMP_IMAGE}/system_dlkm \
        ${TOOLS}/local_system_dlkm_image_info.txt \
        ${SYSTEM_DLKM_TMP_IMAGE}/system_dlkm.img \
        ${SYSTEM_DLKM_TMP_IMAGE}/
    cp ${SYSTEM_DLKM_TMP_IMAGE}/system_dlkm.img ${IMAGE_OUT}/system_dlkm.img
    sign_system_dlkm_image
}

rebuild_dtbo_image() {
    echo "rebuild dtbo.img"
    cp ${ORIGIN_IMAGE}/dtbo.img ${IMAGE_OUT}/dtbo.img
    sign_dtbo_image
}

build_start_time
# download_prebuild_image
get_image_info
# get_modules_list
rebuild_boot_image
rebuild_vendor_boot_image
rebuild_dtbo_image
rebuild_vendor_dlkm_erofs_image
rebuild_system_dlkm_erofs_image
# print_end_help
build_end_time
