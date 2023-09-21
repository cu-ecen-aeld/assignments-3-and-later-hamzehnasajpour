#!/bin/bash
# Script outline to install and build kernel.
# Author: Siddhant Jajoo.

set -e
set -u

OUTDIR=/tmp/aeld
KERNEL_REPO=git://git.kernel.org/pub/scm/linux/kernel/git/stable/linux-stable.git
KERNEL_VERSION=v5.1.10
BUSYBOX_VERSION=1_33_1
FINDER_APP_DIR=$(realpath $(dirname $0))
ARCH=arm64
CROSS_COMPILE=aarch64-none-linux-gnu-

if [ $# -lt 1 ]
then
	echo "Using default directory ${OUTDIR} for output"
else
	OUTDIR=$1
	echo "Using passed directory ${OUTDIR} for output"
fi

mkdir -p ${OUTDIR}

cd "$OUTDIR"
if [ ! -d "${OUTDIR}/linux-stable" ]; then
    #Clone only if the repository does not exist.
	echo "CLONING GIT LINUX STABLE VERSION ${KERNEL_VERSION} IN ${OUTDIR}"
	git clone ${KERNEL_REPO} --depth 1 --single-branch --branch ${KERNEL_VERSION}
fi
if [ ! -e ${OUTDIR}/linux-stable/arch/${ARCH}/boot/Image ]; then
    cd linux-stable
    echo "Checking out version ${KERNEL_VERSION}"
    git checkout ${KERNEL_VERSION}

    # 1: Add your kernel build steps here
	# Deep clean  the kernel build tree -  removing .config file with any existing configurations
    if [ -e .config ]; then
        make ARCH=arm64 CROSS_COMPILE=aarch64-none-linux-gnu- mproper
    fi
	# DefConfig with no argument, so the target will be virt arm development board that we will sumulate in QEMU
    make ARCH=arm64 CROSS_COMPILE=aarch64-none-linux-gnu- defconfig
	# build vmlinux target: build a kernel image for booting with QEMU
    make -j4 ARCH=arm64 CROSS_COMPILE=aarch64-none-linux-gnu- all
	# build the modules and device tree (skip module installation as mentioned in the assignment)
    # make ARCH=arm64 CROSS_COMPILE=aarch64-none-linux-gnu-modules
    make ARCH=arm64 CROSS_COMPILE=aarch64-none-linux-gnu- dtbs
    fi
echo "Adding the Image in outdir"
cp "${OUTDIR}/linux-stable/arch/${ARCH}/boot/Image" ${OUTDIR}
echo "Creating the staging directory for the root filesystem"
cd "$OUTDIR"
if [ -d "${OUTDIR}/rootfs" ]
then
	echo "Deleting rootfs directory at ${OUTDIR}/rootfs and starting over"
    sudo rm  -rf ${OUTDIR}/rootfs
fi

# 2: Create necessary base directories
mkdir rootfs/
cd rootfs
mkdir -p bin dev etc home lib lib64 proc sbin sys tmp usr var
mkdir -p usr/bin usr/lib usr/sbin
mkdir -p var/log

cd "$OUTDIR"
if [ ! -d "${OUTDIR}/busybox" ]
then
git clone git://busybox.net/busybox.git
    cd busybox
    git checkout ${BUSYBOX_VERSION}
    # 3:  Configure busybox
else
    cd busybox
fi

# 4: Make and install busybox
    make distclean
    make defconfig
    make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE}
    make CONFIG_PREFIX=${OUTDIR}/rootfs ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} install
echo "Library dependencies"
cd "${OUTDIR}"
interpreter_path=$(${CROSS_COMPILE}readelf -a ${OUTDIR}/rootfs/bin/busybox | grep "program interpreter" |  awk '{gsub(/[\[\]]/, "", $NF); print $NF}')
shared_lib_path=$(${CROSS_COMPILE}readelf -a ${OUTDIR}/rootfs/bin/busybox | grep "Shared library" |  awk '{gsub(/[\[\]]/, "", $NF); print $NF}')

# 5: Add library dependencies to rootfs
LIBPATH_TOOLCHAIN=$(aarch64-none-linux-gnu-gcc -print-sysroot)
cp "${LIBPATH_TOOLCHAIN}/${interpreter_path}" "${OUTDIR}/rootfs/lib/"

for lib_path in ${shared_lib_path}; do
    cp "${LIBPATH_TOOLCHAIN}/lib64/${lib_path}" "${OUTDIR}/rootfs/lib64/"
done
# 6: Make device nodes
sudo mknod -m 666 "${OUTDIR}/rootfs/dev/null" c 1 3
sudo mknod -m 666 "${OUTDIR}/rootfs/dev/console" c 5 1
# 7: Clean and build the writer utility
cd ${FINDER_APP_DIR}
if [ -e writer]; then
    make clean
fi
make CROSS_COMPILE=${CROSS_COMPILE}
# 8: Copy the finder related scripts and executables to the /home directory
# on the target rootfs
cp writer writer.sh finder.sh  finder-test.sh autorun-qemu.sh  "${OUTDIR}/rootfs/home/"
mkdir ${OUTDIR}/rootfs/home/conf
cp conf/username.txt conf/assignment.txt ${OUTDIR}/rootfs/home/conf
# 9: Chown the root directory
cd ${OUTDIR}
sudo chown -R root:root ${OUTDIR}/rootfs/
# 10: Create initramfs.cpio.gz
cd ${OUTDIR}/rootfs
find . | cpio -H newc -ov --owner root:root > ${OUTDIR}/initramfs.cpio
gzip -f ${OUTDIR}/initramfs.cpio