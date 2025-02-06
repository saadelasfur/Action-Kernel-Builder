#!/bin/bash
#
# Kernel Build Script - m52xq
# Coded by BlackMesa123 @2023
# Adapted by RisenID @2024
# Modified by saadelasfur @2025
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

set -e
set -o allexport

# Set common variables
WORK_DIR="$(git rev-parse --show-toplevel)"
SRC_DIR="$WORK_DIR/android_kernel_samsung_sm7325"
TC_DIR="$WORK_DIR/clang-toolchain"
OUT_DIR="$WORK_DIR/builds"
DATE="$(date +%Y%m%d)"
JOBS="$(nproc --all)"

# Set KSU related variables
[[ "$2" == "-n" || "$2" == "--next" ]] && NEXT_BUILD="true"
KSU_VER="v1.0.3"
[[ "$NEXT_BUILD" == "true" ]] && KSU_VER="v1.0.4"
RELEASE_VERSION="KSU_$KSU_VER-$DATE"
[[ "$NEXT_BUILD" == "true" ]] && RELEASE_VERSION="KSU-Next_$KSU_VER-$DATE"

MAKE_PARAMS="-j$JOBS -C $SRC_DIR O=$SRC_DIR/out \
    ARCH=arm64 CLANG_TRIPLE=aarch64-linux-gnu- LLVM=1 LLVM_IAS=1 \
    CROSS_COMPILE=$TC_DIR/bin/llvm-"

export PATH="$TC_DIR/bin:$PATH"

# [
DETECT_BRANCH()
{
    cd $SRC_DIR/
    branch_name="$(git rev-parse --abbrev-ref HEAD)"

    if [[ "$branch_name" == "ksu" || "$branch_name" == "ksu-next" ]]; then
        echo "----------------------------------------------"
        echo "OneUI Branch Detected..."
        BUILD_VARIANT="OneUI"
    elif [[ "$branch_name" == "ksu-aosp" || "$branch_name" == "ksu-aosp-next" ]]; then
        echo "----------------------------------------------"
        echo "AOSP Branch Detected..."
        BUILD_VARIANT="AOSP"
    else
        echo "----------------------------------------------"
        echo "Branch not recognized..."
        exit 1
    fi
    cd $WORK_DIR/
}

CLEAN_SOURCE()
{
    echo "----------------------------------------------"
    echo "Cleaning up sources..."
    rm -rf $SRC_DIR/out
}

BUILD_KERNEL()
{
    cd $SRC_DIR/
    echo "----------------------------------------------"
    [ -d "$SRC_DIR/out" ] && echo "Starting $BUILD_VARIANT kernel build... (DIRTY)" || echo "Starting $BUILD_VARIANT kernel build..."
    echo " "
    export LOCALVERSION="-nova-$KSU_VER-$VARIANT"
    mkdir -p $SRC_DIR/out
    rm -rf $SRC_DIR/out/arch/arm64/boot/dts/samsung
    make $MAKE_PARAMS CC="ccache clang" vendor/$DEFCONFIG
    echo " "
    # Make kernel
    make $MAKE_PARAMS CC="ccache clang"
    echo " "
    cd $WORK_DIR/
}

REGEN_DEFCONFIG()
{
    cd $SRC_DIR/
    echo "----------------------------------------------"
    [ -d "$SRC_DIR/out" ] && echo "Starting $BUILD_VARIANT kernel build... (DIRTY)" || echo "Starting $BUILD_VARIANT kernel build..."
    echo " "
    mkdir -p $SRC_DIR/out
    rm -rf $SRC_DIR/out/arch/arm64/boot/dts/samsung
    rm -f $SRC_DIR/out/.config
    make $MAKE_PARAMS CC="ccache clang" vendor/$DEFCONFIG
    echo " "
    # Regen defconfig
    cp $SRC_DIR/out/.config $SRC_DIR/arch/arm64/configs/vendor/$DEFCONFIG
    echo " "
    cd $WORK_DIR/
}

PACK_BOOT_IMG()
{
    echo "----------------------------------------------"
    echo "Packing $BUILD_VARIANT boot.img..."
    rm -rf $OUT_DIR/tmp/
    mkdir $OUT_DIR/tmp/
    # Copy and unpack stock boot.img
    cp $WORK_DIR/m52xq/images/$IMG_FOLDER/boot.img $OUT_DIR/tmp/boot.img
    cd $OUT_DIR/tmp/
    avbtool erase_footer --image boot.img
    magiskboot unpack -h boot.img
    # Replace stock kernel image
    rm -f $OUT_DIR/tmp/kernel
    cp $SRC_DIR/out/arch/arm64/boot/Image $OUT_DIR/tmp/kernel
    # SELinux permissive
    #cmdline=$(head -n 1 header)
    #cmdline="$cmdline androidboot.selinux=permissive"
    #sed '1 c\"$cmdline"' header > header_new
    #rm -f header
    #mv header_new header
    # Repack and copy in out folder
    magiskboot repack boot.img boot_new.img
    mv $OUT_DIR/tmp/boot_new.img $OUT_DIR/out/zip/mesa/$IMG_FOLDER/boot.img
    # Clean :3
    rm -rf $OUT_DIR/tmp/
    cd $WORK_DIR/
}

PACK_DTBO_IMG()
{
    echo "----------------------------------------------"
    echo "Packing $BUILD_VARIANT dtbo.img..."
    # Uncomment this to use firmware extracted dtbo
    #cp $WORK_DIR/m52xq/images/$IMG_FOLDER/dtbo.img $OUT_DIR/out/zip/mesa/$IMG_FOLDER/dtbo.img
    cp $SRC_DIR/out/arch/arm64/boot/dtbo.img $OUT_DIR/out/zip/mesa/$IMG_FOLDER/dtbo.img
}

PACK_EXT_VENDOR_BOOT_IMG()
{
    echo "----------------------------------------------"
    echo "Packing $BUILD_VARIANT vendor_boot.img..."
    rm -rf $OUT_DIR/tmp/
    mkdir $OUT_DIR/tmp/
    # Copy and unpack stock vendor_boot.img
    cp $WORK_DIR/m52xq/images/$IMG_FOLDER/vendor_boot.img $OUT_DIR/tmp/vendor_boot.img
    cd $OUT_DIR/tmp/
    avbtool erase_footer --image vendor_boot.img
    magiskboot unpack -h vendor_boot.img
    # Replace KernelRPValue
    sed '1 c\name='"$RP_REV"'' header > header_new
    rm -f header
    mv header_new header
    # Replace stock DTB
    rm -f $OUT_DIR/tmp/dtb
    cp $SRC_DIR/out/arch/arm64/boot/dts/vendor/qcom/yupik.dtb $OUT_DIR/tmp/dtb
    # SELinux permissive
    #cmdline=$(head -n 2 header)
    #cmdline="$cmdline androidboot.selinux=permissive"
    #sed '2 c\"$cmdline"' header > header_new
    #rm -f header
    #mv header_new header
    # Repack and copy in out folder
    magiskboot repack vendor_boot.img vendor_boot_new.img
    mv $OUT_DIR/tmp/vendor_boot_new.img $OUT_DIR/out/zip/mesa/$IMG_FOLDER/vendor_boot.img
    # Clean :3
    rm -rf $OUT_DIR/tmp/
    cd $WORK_DIR/
}

PACK_CUSTOM_VENDOR_BOOT_IMG()
{
    echo "----------------------------------------------"
    echo "Packing $BUILD_VARIANT vendor_boot.img (custom)..."
    rm -rf $OUT_DIR/tmp/
    mkdir $OUT_DIR/tmp/
    # Copy and unpack stock vendor_boot.img
    cp $WORK_DIR/m52xq/images/$IMG_FOLDER/vendor_boot.img $OUT_DIR/tmp/vendor_boot.img
    cd $OUT_DIR/tmp/
    avbtool erase_footer --image vendor_boot.img
    magiskboot unpack -h vendor_boot.img
    # Replace KernelRPValue
    sed '1 c\name='"$RP_REV"'' header > header_new
    rm -f header
    mv header_new header
    # Replace stock DTB
    rm -f $OUT_DIR/tmp/dtb
    cp $SRC_DIR/out/arch/arm64/boot/dts/vendor/qcom/yupik.dtb $OUT_DIR/tmp/dtb
    # Replace stock fstab
    mkdir ramdisk
    cd ramdisk
    cpio -idv < ../ramdisk.cpio
    cp -a --preserve=all $WORK_DIR/m52xq/fstab/fstab.qcom $OUT_DIR/tmp/ramdisk/first_stage_ramdisk/fstab.qcom
    find . | cpio -o -H newc > ../ramdisk_new.cpio
    cd ..
    rm ramdisk.cpio
    mv ramdisk_new.cpio ramdisk.cpio
    rm -rf ramdisk
    # SELinux permissive
    #cmdline=$(head -n 2 header)
    #cmdline="$cmdline androidboot.selinux=permissive"
    #sed '2 c\"$cmdline"' header > header_new
    #rm -f header
    #mv header_new header
    # Repack and copy in out folder
    magiskboot repack vendor_boot.img vendor_boot_new.img
    mv $OUT_DIR/tmp/vendor_boot_new.img $OUT_DIR/out/zip/mesa/$IMG_FOLDER/vendor_boot.img
    # Clean :3
    rm -rf $OUT_DIR/tmp/
    cd $WORK_DIR/
}

MAKE_INSTALLER()
{
    cp -r $WORK_DIR/m52xq/template/META-INF $OUT_DIR/out/zip/META-INF
    [[ "$NEXT_BUILD" == "true" ]] && sed -i "s/KernelSU/KernelSU-Next/g" $OUT_DIR/out/zip/META-INF/com/google/android/update-binary
    sed -i -e "s/build_var/$BUILD_VARIANT/g" -e "s/ksu_version/$KSU_VER/g" $OUT_DIR/out/zip/META-INF/com/google/android/update-binary
    cd $OUT_DIR/out/zip/
    find . -exec touch -a -c -m -t 200901010000.00 {} +
    7z a -tzip -mx=5 ${RELEASE_VERSION}_m52xq_${BUILD_VARIANT}.zip mesa META-INF vendor
    mv ${RELEASE_VERSION}_m52xq_${BUILD_VARIANT}.zip $OUT_DIR/${RELEASE_VERSION}_m52xq_${BUILD_VARIANT}.zip
}
# ]

clear

rm -rf $OUT_DIR/out

mkdir -p $OUT_DIR
mkdir -p $OUT_DIR/out
mkdir -p $OUT_DIR/out/zip/mesa/eur
mkdir -p $OUT_DIR/out/zip/mesa/swa
mkdir -p $OUT_DIR/out/zip/mesa/cis

# Detect branch
DETECT_BRANCH

# Clean
[[ "$1" == "-c" || "$1" == "--clean" ]] && CLEAN_SOURCE

# Set vendor_boot build
if [[ "$BUILD_VARIANT" == "OneUI" ]]; then
    PACK_VENDOR_BOOT_IMG="PACK_CUSTOM_VENDOR_BOOT_IMG"
else
    PACK_VENDOR_BOOT_IMG="PACK_EXT_VENDOR_BOOT_IMG"
fi

# m52xqxx
IMG_FOLDER=eur
VARIANT=m52xqxx
DEFCONFIG=m52xq_eur_open_defconfig
RP_REV=SRPUF17B001
BUILD_KERNEL
PACK_BOOT_IMG
PACK_DTBO_IMG
$PACK_VENDOR_BOOT_IMG

# m52xqins
IMG_FOLDER=swa
VARIANT=m52xqins
DEFCONFIG=m52xq_swa_ins_defconfig
RP_REV=SRPUF24A001
BUILD_KERNEL
PACK_BOOT_IMG
PACK_DTBO_IMG
$PACK_VENDOR_BOOT_IMG

# m52xqser
IMG_FOLDER=cis
VARIANT=m52xqser
DEFCONFIG=m52xq_cis_ser_defconfig
RP_REV=SRPUF24A001
BUILD_KERNEL
PACK_BOOT_IMG
PACK_DTBO_IMG
$PACK_VENDOR_BOOT_IMG

# Make installer
MAKE_INSTALLER

rm -rf $OUT_DIR/out
for i in eur swa cis; do
    rm -f $WORK_DIR/m52xq/images/$i/*.img
done

echo "----------------------------------------------"
