#!/bin/sh
#
# Copyright (c) 2005 Poul-Henning Kamp.
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
# OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
# HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
# LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
# OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
# SUCH DAMAGE.
#
# $FreeBSD$
#

set -e

#######################################################################
#
# Setup default values for all controlling variables.
# These values can be overridden from the config file(s)
#
#######################################################################

# Name of this NanoBSD build.  (Used to construct workdir names)
NANO_NAME=full

# Source tree directory
NANO_SRC=/usr/src

# Where nanobsd additional files live under the source tree
NANO_TOOLS=tools/tools/nanobsd

# Where cust_pkgng() finds packages to install
NANO_PACKAGE_DIR=${NANO_SRC}/${NANO_TOOLS}/Pkg
NANO_PACKAGE_LIST="*"

# where package metadata gets placed
NANO_PKG_META_BASE=/var/db

# Object tree directory
# default is subdir of /usr/obj
#NANO_OBJ=""

# The directory to put the final images
# default is ${NANO_OBJ}
#NANO_DISKIMGDIR=""

# Make & parallel Make
NANO_MAKE="make"
NANO_PMAKE="make -j 3"

# The default name for any image we create.
NANO_IMGNAME="_.disk.full"

# Options to put in make.conf during buildworld only
CONF_BUILD=' '

# Options to put in make.conf during installworld only
CONF_INSTALL=' '

# Options to put in make.conf during both build- & installworld.
CONF_WORLD=' '

# Kernel config file to use
NANO_KERNEL=GENERIC

# Kernel modules to install. If empty, no modules are installed.
# Use "default" to install all built modules.
NANO_MODULES=

# Customize commands.
NANO_CUSTOMIZE=""

# Late customize commands.
NANO_LATE_CUSTOMIZE=""

# Newfs paramters to use
NANO_NEWFS="-b 4096 -f 512 -i 8192 -U"

# The drive name of the media at runtime
NANO_DRIVE=ada0

# Target media size in 512 bytes sectors
NANO_MEDIASIZE=2000000

# Number of code images on media (1 or 2)
NANO_IMAGES=2

# 0 -> Leave second image all zeroes so it compresses better.
# 1 -> Initialize second image with a copy of the first
NANO_INIT_IMG2=1

# Size of code file system in 512 bytes sectors
# If zero, size will be as large as possible.
NANO_CODESIZE=0

# Size of configuration file system in 512 bytes sectors
# Cannot be zero.
NANO_CONFSIZE=2048

# Size of data file system in 512 bytes sectors
# If zero: no partition configured.
# If negative: max size possible
NANO_DATASIZE=0

# Size of the /etc ramdisk in 512 bytes sectors
NANO_RAM_ETCSIZE=10240

# Size of the /tmp+/var ramdisk in 512 bytes sectors
NANO_RAM_TMPVARSIZE=10240

# Media geometry, only relevant if bios doesn't understand LBA.
NANO_SECTS=63
NANO_HEADS=16

# boot0 flags/options and configuration
NANO_BOOT0CFG="-o packet -s 1 -m 3"
NANO_BOOTLOADER="boot/boot0sio"

# boot2 flags/options
# default force serial console
NANO_BOOT2CFG="-h -S115200"

# Backing type of md(4) device
# Can be "file" or "swap"
NANO_MD_BACKING="file"

# for swap type md(4) backing, write out the mbr only
NANO_IMAGE_MBRONLY=true

# Progress Print level
PPLEVEL=3

# Set NANO_LABEL to non-blank to form the basis for using /dev/ufs/label
# in preference to /dev/${NANO_DRIVE}
# Root partition will be ${NANO_LABEL}s{1,2}
# /cfg partition will be ${NANO_LABEL}s3
# /data partition will be ${NANO_LABEL}s4
NANO_LABEL=""
NANO_SLICE_ROOT=s1
NANO_SLICE_ALTROOT=s2
NANO_SLICE_CFG=s3
NANO_SLICE_DATA=s4

# Default ownwership for nopriv build
NANO_DEF_UNAME=root
NANO_DEF_GNAME=wheel

#######################################################################
# Architecture to build.  Corresponds to TARGET_ARCH in a buildworld.
# Unfortunately, there's no way to set TARGET at this time, and it
# conflates the two, so architectures where TARGET != TARGET_ARCH and
# TARGET can't be guessed from TARGET_ARCH do not work.  This defaults
# to the arch of the current machine.
NANO_ARCH=`uname -p`

# CPUTYPE defaults to "" which is the default when CPUTYPE isn't
# defined.
NANO_CPUTYPE=""

# Directory to populate /cfg from
NANO_CFGDIR=""

# Directory to populate /data from
NANO_DATADIR=""

# We don't need SRCCONF or SRC_ENV_CONF. NanoBSD puts everything we
# need for the build in files included with __MAKE_CONF. Override in your
# config file if you really must. We set them unconditionally here, though
# in case they are stray in the build environment
SRCCONF=/dev/null
SRC_ENV_CONF=/dev/null
 
#######################################################################
#
# The functions which do the real work.
# Can be overridden from the config file(s)
#
#######################################################################

# Export values into the shell. Must use { } instead of ( ) like
# other functions to avoid a subshell.
# We set __MAKE_CONF as a global since it is easier to get quoting
# right for paths with spaces in them.
make_export ( ) {
	# Similar to export_var, except puts the data out to stdout
	var=$1
	eval val=\$$var
	echo "Setting variable: $var=\"$val\""
	export $1
}

nano_make_build_env ( ) {
	__MAKE_CONF="${NANO_MAKE_CONF_BUILD}"
	make_export __MAKE_CONF
}

nano_make_install_env ( ) {
	__MAKE_CONF="${NANO_MAKE_CONF_INSTALL}"
	make_export __MAKE_CONF
}

# Extra environment variables for kernel builds
nano_make_kernel_env ( ) {
	if [ -f ${NANO_KERNEL} ] ; then
		KERNCONFDIR="$(realpath $(dirname ${NANO_KERNEL}))"
		KERNCONF="$(basename ${NANO_KERNEL})"
		make_export KERNCONFDIR
		make_export KERNCONF
	else
		export KERNCONF="${NANO_KERNEL}"
		make_export KERNCONF
	fi
}

nano_global_make_env ( ) (
	# global settings for the make.conf file, if set
	[ -z "${NANO_ARCH}" ] || echo TARGET_ARCH="${NANO_ARCH}"
	[ -z "${NANO_CPUTYPE}" ] || echo TARGET_CPUTYPE="${NANO_CPUTYPE}"
)

# rm doesn't know -x prior to FreeBSD 10, so cope with a variety of build
# hosts for now. This will go away when support in the base goes away.
rm ( ) {
    echo "NANO RM $*"
	case $(uname -r) in
	7*|8*|9*) command rm $* ;;
	*) command rm -x $* ;;
	esac
}

#
# Create empty files in the target tree, and record the fact.  All paths
# are relative to NANO_WORLDDIR.
#
tgt_touch ( ) (

	cd "${NANO_WORLDDIR}"
	for i; do
		touch $i
		echo "./${i} type=file" >> ${NANO_METALOG}
	done
)

#
# Convert a directory into a symlink. Takes two arguments, the
# current directory and what it should become a symlink to. The
# directory is removed and a symlink is created. If we're doing
# a nopriv build, then append this fact to the metalog
#
tgt_dir2symlink () (
	dir=$1
	symlink=$2

	cd "${NANO_WORLDDIR}"
	rm -rf "$dir"
	ln -s "$symlink" "$dir"
	if [ -n "$NANO_METALOG" ]; then
		echo "./${dir} type=link mode=0777 link=${symlink}" >> ${NANO_METALOG}
	fi
)

# run in the world chroot, errors fatal
CR ( ) {
	chroot "${NANO_WORLDDIR}" /bin/sh -exc "$*"
}

# run in the world chroot, errors not fatal
CR0 ( ) {
	chroot "${NANO_WORLDDIR}" /bin/sh -c "$*" || true
}

nano_cleanup ( ) (
	[ $? -eq 0 ] || echo "Error encountered.  Check for errors in last log file." 1>&2
	exit $?
)

clean_build ( ) (
	pprint 2 "Clean and create object directory (${MAKEOBJDIRPREFIX})"

	if ! rm -rf ${MAKEOBJDIRPREFIX}/ > /dev/null 2>&1 ; then
		chflags -R noschg ${MAKEOBJDIRPREFIX}/
		rm -r ${MAKEOBJDIRPREFIX}/
	fi
)

make_conf_build ( ) (
	pprint 2 "Construct build make.conf ($NANO_MAKE_CONF_BUILD)"

	mkdir -p ${MAKEOBJDIRPREFIX}
	printenv > ${MAKEOBJDIRPREFIX}/_.env

	# Make sure we get all the global settings that NanoBSD wants
	# in addition to the user's global settings
	(
	nano_global_make_env
	echo "${CONF_WORLD}" 
	echo "${CONF_BUILD}"
	) > ${NANO_MAKE_CONF_BUILD}
)

build_world ( ) (
	pprint 2 "run buildworld"
	pprint 3 "log: ${MAKEOBJDIRPREFIX}/_.bw"

	(
	nano_make_build_env
	set -o xtrace
	cd "${NANO_SRC}"
	${NANO_PMAKE} buildworld
	) > ${MAKEOBJDIRPREFIX}/_.bw 2>&1
)

build_kernel ( ) (
	local extra

	pprint 2 "build kernel ($NANO_KERNEL)"
	pprint 3 "log: ${MAKEOBJDIRPREFIX}/_.bk"

	(
	nano_make_build_env
	nano_make_kernel_env

	# Note: We intentionally build all modules, not only the ones in
	# NANO_MODULES so the built world can be reused by multiple images.
	# Although MODULES_OVERRIDE can be defined in the kenrel config
	# file to override this behavior. Just set NANO_MODULES=default.
	set -o xtrace
	cd "${NANO_SRC}"
	${NANO_PMAKE} buildkernel
	) > ${MAKEOBJDIRPREFIX}/_.bk 2>&1
)

clean_world ( ) (
	if [ "${NANO_OBJ}" != "${MAKEOBJDIRPREFIX}" ]; then
		pprint 2 "Clean and create object directory (${NANO_OBJ})"
		if ! rm -rf ${NANO_OBJ}/ > /dev/null 2>&1 ; then
			chflags -R noschg ${NANO_OBJ}
			rm -r ${NANO_OBJ}/
		fi
		mkdir -p "${NANO_OBJ}" "${NANO_WORLDDIR}"
		printenv > ${NANO_OBJ}/_.env
	else
		pprint 2 "Clean and create world directory (${NANO_WORLDDIR})"
		if ! rm -rf "${NANO_WORLDDIR}/" > /dev/null 2>&1 ; then
			chflags -R noschg "${NANO_WORLDDIR}"
			rm -rf "${NANO_WORLDDIR}/"
		fi
		mkdir -p "${NANO_WORLDDIR}"
	fi
)

make_conf_install ( ) (
	pprint 2 "Construct install make.conf ($NANO_MAKE_CONF_INSTALL)"

	# Make sure we get all the global settings that NanoBSD wants
	# in addition to the user's global settings
	(
	nano_global_make_env
	echo "${CONF_WORLD}"
	echo "${CONF_INSTALL}"
	if [ -n "${NANO_NOPRIV_BUILD}" ]; then
	    echo NO_ROOT=t
	    echo METALOG=${NANO_METALOG}
	fi
	) >  ${NANO_MAKE_CONF_INSTALL}
)

install_world ( ) (
	pprint 2 "installworld"
	pprint 3 "log: ${NANO_OBJ}/_.iw"

	(
	nano_make_install_env
	set -o xtrace
	cd "${NANO_SRC}"
	${NANO_MAKE} installworld DESTDIR="${NANO_WORLDDIR}"
	chflags -R noschg "${NANO_WORLDDIR}"
	) > ${NANO_OBJ}/_.iw 2>&1
)

install_etc ( ) (

	pprint 2 "install /etc"
	pprint 3 "log: ${NANO_OBJ}/_.etc"

	(
	nano_make_install_env
	set -o xtrace
	cd "${NANO_SRC}"
	${NANO_MAKE} distribution DESTDIR="${NANO_WORLDDIR}"
	# make.conf doesn't get created by default, but some ports need it
	# so they can spam it.
	cp /dev/null "${NANO_WORLDDIR}"/etc/make.conf
	) > ${NANO_OBJ}/_.etc 2>&1
)

install_kernel ( ) (
	local extra

	pprint 2 "install kernel ($NANO_KERNEL)"
	pprint 3 "log: ${NANO_OBJ}/_.ik"

	(

	nano_make_install_env
	nano_make_kernel_env    

	if [ "${NANO_MODULES}" != "default" ]; then
		MODULES_OVERRIDE="${NANO_MODULES}"
		make_export MODULES_OVERRIDE
	fi

	set -o xtrace
	cd "${NANO_SRC}"
	${NANO_MAKE} installkernel DESTDIR="${NANO_WORLDDIR}"

	) > ${NANO_OBJ}/_.ik 2>&1
)

native_xtools ( ) (
	print 2 "Installing the optimized native build tools for cross env"
	pprint 3 "log: ${NANO_OBJ}/_.native_xtools"

	(

	nano_make_install_env
	set -o xtrace
	cd "${NANO_SRC}"
	${NANO_MAKE} native-xtools DESTDIR="${NANO_WORLDDIR}"

	) > ${NANO_OBJ}/_.native_xtools 2>&1
)

#
# Run the requested set of customization scripts, run after we've
# done an installworld, installed the etc files, installed the kernel
# and tweaked them in the standard way.
#
run_customize ( ) (

	pprint 2 "run customize scripts"
	for c in $NANO_CUSTOMIZE
	do
		pprint 2 "customize \"$c\""
		pprint 3 "log: ${NANO_OBJ}/_.cust.$c"
		pprint 4 "`type $c`"
		( set -x ; $c ) > ${NANO_OBJ}/_.cust.$c 2>&1
	done
)

#
# Run any last-minute customization commands after we've had a chance to
# setup nanobsd, prune empty dirs from /usr, etc
#
run_late_customize ( ) (

	pprint 2 "run late customize scripts"
	for c in $NANO_LATE_CUSTOMIZE
	do
		pprint 2 "late customize \"$c\""
		pprint 3 "log: ${NANO_OBJ}/_.late_cust.$c"
		pprint 4 "`type $c`"
		( set -x ; $c ) > ${NANO_OBJ}/_.late_cust.$c 2>&1
	done
)

#
# Hook called after we run all the late customize commands, but
# before we invoke the disk imager. The nopriv build uses it to
# read in the meta log, apply the changes other parts of nanobsd
# have been recording their actions. It's not anticipated that
# a user's cfg file would override this.
#
fixup_before_diskimage ( ) (

	# Run the deduplication script that takes the matalog journal and
	# combines multiple entries for the same file (see source for
	# details). We take the extra step of removing the size keywords. This
	# script, and many of the user scripts, copies, appeneds and otherwise
	# modifies files in the build, changing their sizes.  These actions are
	# impossible to trap, so go ahead remove the size= keyword. For this
	# narrow use, it doesn't buy us any protection and just gets in the way.
	# The dedup tool's output must be sorted due to limitations in awk.
	if [ -n "${NANO_METALOG}" ]; then
		pprint 2 "Fixing metalog"
		cp ${NANO_METALOG} ${NANO_METALOG}.pre
		echo "/set uname=${NANO_DEF_UNAME} gname=${NANO_DEF_GNAME}" > ${NANO_METALOG}
		cat ${NANO_METALOG}.pre | ${NANO_TOOLS}/mtree-dedup.awk | \
		    sed -e 's/ size=[0-9][0-9]*//' | sort >> ${NANO_METALOG}
	fi	
)

setup_nanobsd ( ) (
	pprint 2 "configure nanobsd setup"
	pprint 3 "log: ${NANO_OBJ}/_.dl"

	(
	cd "${NANO_WORLDDIR}"

	# Move /usr/local/etc to /etc/local so that the /cfg stuff
	# can stomp on it.  Otherwise packages like ipsec-tools which
	# have hardcoded paths under ${prefix}/etc are not tweakable.
	if [ -d usr/local/etc ] ; then
		(
		mkdir -p etc/local
		cd usr/local/etc
		find . -print | cpio -dumpl ../../../etc/local
		cd ..
		rm -rf etc
		ln -s ../../etc/local etc
		)
	fi

	for d in var etc
	do
		# link /$d under /conf
		# we use hard links so we have them both places.
		# the files in /$d will be hidden by the mount.
		mkdir -p conf/base/$d conf/default/$d
		find $d -print | cpio -dumpl conf/base/
	done

	echo "$NANO_RAM_ETCSIZE" > conf/base/etc/md_size
	echo "$NANO_RAM_TMPVARSIZE" > conf/base/var/md_size

	# pick up config files from the special partition
	echo "mount -o ro /dev/${NANO_DRIVE}${NANO_SLICE_CFG}" > conf/default/etc/remount

	# Put /tmp on the /var ramdisk (could be symlink already)
	tgt_dir2symlink tmp var/tmp

	) > ${NANO_OBJ}/_.dl 2>&1
)

setup_nanobsd_etc ( ) (
	pprint 2 "configure nanobsd /etc"

	(
	cd "${NANO_WORLDDIR}"

	# create diskless marker file
	touch etc/diskless

	[ -n "${NANO_NOPRIV_BUILD}" ] && chmod 666 etc/defaults/rc.conf

	# Make root filesystem R/O by default
	echo "root_rw_mount=NO" >> etc/defaults/rc.conf
	# Disable entropy file, since / is read-only /var/db/entropy should be enough?
	echo "entropy_file=NO" >> etc/defaults/rc.conf

	[ -n "${NANO_NOPRIV_BUILD}" ] && chmod 444 etc/defaults/rc.conf

	# save config file for scripts
	echo "NANO_DRIVE=${NANO_DRIVE}" > etc/nanobsd.conf

	echo "/dev/${NANO_DRIVE}${NANO_SLICE_ROOT}a / ufs ro 1 1" > etc/fstab
	echo "/dev/${NANO_DRIVE}${NANO_SLICE_CFG} /cfg ufs rw,noauto 2 2" >> etc/fstab
	mkdir -p cfg
	)
)

prune_usr ( ) (

	# Remove all empty directories in /usr 
	find "${NANO_WORLDDIR}"/usr -type d -depth -print |
		while read d
		do
			rmdir $d > /dev/null 2>&1 || true 
		done
)

newfs_part ( ) (
	local dev mnt lbl
	dev=$1
	mnt=$2
	lbl=$3
	echo newfs ${NANO_NEWFS} ${NANO_LABEL:+-L${NANO_LABEL}${lbl}} ${dev}
	newfs ${NANO_NEWFS} ${NANO_LABEL:+-L${NANO_LABEL}${lbl}} ${dev}
	mount -o async ${dev} ${mnt}
)

# Convenient spot to work around any umount issues that your build environment
# hits by overriding this method.
nano_umount ( ) (
	umount ${1}
)

populate_slice ( ) (
	local dev dir mnt lbl
	dev=$1
	dir=$2
	mnt=$3
	lbl=$4
	echo "Creating ${dev} (mounting on ${mnt})"
	newfs_part ${dev} ${mnt} ${lbl}
	if [ -n "${dir}" -a -d "${dir}" ]; then
		echo "Populating ${lbl} from ${dir}"
		cd "${dir}"
		find . -print | grep -Ev '/(CVS|\.svn|\.hg|\.git)' | cpio -dumpv ${mnt}
	fi
	df -i ${mnt}
	nano_umount ${mnt}
)

populate_cfg_slice ( ) (
	populate_slice "$1" "$2" "$3" "$4"
)

populate_data_slice ( ) (
	populate_slice "$1" "$2" "$3" "$4"
)

create_diskimage ( ) (
	pprint 2 "build diskimage"
	pprint 3 "log: ${NANO_OBJ}/_.di"

	(
	echo $NANO_MEDIASIZE $NANO_IMAGES \
		$NANO_SECTS $NANO_HEADS \
		$NANO_CODESIZE $NANO_CONFSIZE $NANO_DATASIZE |
	awk '
	{
		printf "# %s\n", $0

		# size of cylinder in sectors
		cs = $3 * $4

		# number of full cylinders on media
		cyl = int ($1 / cs)

		# output fdisk geometry spec, truncate cyls to 1023
		if (cyl <= 1023)
			print "g c" cyl " h" $4 " s" $3
		else
			print "g c" 1023 " h" $4 " s" $3

		if ($7 > 0) { 
			# size of data partition in full cylinders
			dsl = int (($7 + cs - 1) / cs)
		} else {
			dsl = 0;
		}

		# size of config partition in full cylinders
		csl = int (($6 + cs - 1) / cs)

		if ($5 == 0) {
			# size of image partition(s) in full cylinders
			isl = int ((cyl - dsl - csl) / $2)
		} else {
			isl = int (($5 + cs - 1) / cs)
		}

		# First image partition start at second track
		print "p 1 165 " $3, isl * cs - $3
		c = isl * cs;

		# Second image partition (if any) also starts offset one 
		# track to keep them identical.
		if ($2 > 1) {
			print "p 2 165 " $3 + c, isl * cs - $3
			c += isl * cs;
		}

		# Config partition starts at cylinder boundary.
		print "p 3 165 " c, csl * cs
		c += csl * cs

		# Data partition (if any) starts at cylinder boundary.
		if ($7 > 0) {
			print "p 4 165 " c, dsl * cs
		} else if ($7 < 0 && $1 > c) {
			print "p 4 165 " c, $1 - c
		} else if ($1 < c) {
			print "Disk space overcommitted by", \
			    c - $1, "sectors" > "/dev/stderr"
			exit 2
		}

		# Force slice 1 to be marked active. This is necessary
		# for booting the image from a USB device to work.
		print "a 1"
	}
	' > ${NANO_OBJ}/_.fdisk

	IMG=${NANO_DISKIMGDIR}/${NANO_IMGNAME}
	MNT=${NANO_OBJ}/_.mnt
	mkdir -p ${MNT}

	if [ "${NANO_MD_BACKING}" = "swap" ] ; then
		MD=`mdconfig -a -t swap -s ${NANO_MEDIASIZE} -x ${NANO_SECTS} \
			-y ${NANO_HEADS}`
	else
		echo "Creating md backing file..."
		rm -f ${IMG}
		dd if=/dev/zero of=${IMG} seek=${NANO_MEDIASIZE} count=0
		MD=`mdconfig -a -t vnode -f ${IMG} -x ${NANO_SECTS} \
			-y ${NANO_HEADS}`
	fi

	trap "echo 'Running exit trap code' ; df -i ${MNT} ; nano_umount ${MNT} || true ; mdconfig -d -u $MD" 1 2 15 EXIT

	fdisk -i -f ${NANO_OBJ}/_.fdisk ${MD}
	fdisk ${MD}
	# XXX: params
	# XXX: pick up cached boot* files, they may not be in image anymore.
	if [ -f ${NANO_WORLDDIR}/${NANO_BOOTLOADER} ]; then
		boot0cfg -B -b ${NANO_WORLDDIR}/${NANO_BOOTLOADER} ${NANO_BOOT0CFG} ${MD}
	fi
	if [ -f ${NANO_WORLDDIR}/boot/boot ]; then
		bsdlabel -w -B -b ${NANO_WORLDDIR}/boot/boot ${MD}${NANO_SLICE_ROOT}
	else
		bsdlabel -w ${MD}${NANO_SLICE_ROOT}
	fi
	bsdlabel ${MD}${NANO_SLICE_ROOT}

	# Create first image
	populate_slice /dev/${MD}${NANO_SLICE_ROOT}a ${NANO_WORLDDIR} ${MNT} "${NANO_SLICE_ROOT}a"
	mount /dev/${MD}${NANO_SLICE_ROOT}a ${MNT}
	echo "Generating mtree..."
	( cd "${MNT}" && mtree -c ) > ${NANO_OBJ}/_.mtree
	( cd "${MNT}" && du -k ) > ${NANO_OBJ}/_.du
	nano_umount "${MNT}"

	if [ $NANO_IMAGES -gt 1 -a $NANO_INIT_IMG2 -gt 0 ] ; then
		# Duplicate to second image (if present)
		echo "Duplicating to second image..."
		dd conv=sparse if=/dev/${MD}${NANO_SLICE_ROOT} of=/dev/${MD}${NANO_SLICE_ALTROOT} bs=64k
		mount /dev/${MD}${NANO_SLICE_ALTROOT}a ${MNT}
		for f in ${MNT}/etc/fstab ${MNT}/conf/base/etc/fstab
		do
			sed -i "" "s=${NANO_DRIVE}${NANO_SLICE_ROOT}=${NANO_DRIVE}${NANO_SLICE_ALTROOT}=g" $f
		done
		nano_umount ${MNT}
		# Override the label from the first partition so we
		# don't confuse glabel with duplicates.
		if [ -n "${NANO_LABEL}" ]; then
			tunefs -L ${NANO_LABEL}"${NANO_SLICE_ALTROOT}a" /dev/${MD}${NANO_SLICE_ALTROOT}a
		fi
	fi
	
	# Create Config slice
	populate_cfg_slice /dev/${MD}${NANO_SLICE_CFG} "${NANO_CFGDIR}" ${MNT} "${NANO_SLICE_CFG}"

	# Create Data slice, if any.
	if [ -n "$NANO_SLICE_DATA" -a "$NANO_SLICE_CFG" = "$NANO_SLICE_DATA" -a \
	   "$NANO_DATASIZE" -ne 0 ]; then
		pprint 2 "NANO_SLICE_DATA is the same as NANO_SLICE_CFG, fix."
		exit 2
	fi
	if [ $NANO_DATASIZE -ne 0 -a -n "$NANO_SLICE_DATA" ] ; then
		populate_data_slice /dev/${MD}${NANO_SLICE_DATA} "${NANO_DATADIR}" ${MNT} "${NANO_SLICE_DATA}"
	fi

	if [ "${NANO_MD_BACKING}" = "swap" ] ; then
		if [ ${NANO_IMAGE_MBRONLY} ]; then
			echo "Writing out _.disk.mbr..."
			dd if=/dev/${MD} of=${NANO_DISKIMGDIR}/_.disk.mbr bs=512 count=1
		else
			echo "Writing out ${NANO_IMGNAME}..."
			dd if=/dev/${MD} of=${IMG} bs=64k
		fi

		echo "Writing out ${NANO_IMGNAME}..."
		dd conv=sparse if=/dev/${MD} of=${IMG} bs=64k
	fi

	if ${do_copyout_partition} ; then
		echo "Writing out _.disk.image..."
		dd conv=sparse if=/dev/${MD}${NANO_SLICE_ROOT} of=${NANO_DISKIMGDIR}/_.disk.image bs=64k
	fi
	mdconfig -d -u $MD

	trap - 1 2 15
	trap nano_cleanup EXIT

	) > ${NANO_OBJ}/_.di 2>&1
)

last_orders ( ) (
	# Redefine this function with any last orders you may have
	# after the build completed, for instance to copy the finished
	# image to a more convenient place:
	# cp ${NANO_DISKIMGDIR}/_.disk.image /home/ftp/pub/nanobsd.disk
	true
)

#######################################################################
#
# Optional convenience functions.
#
#######################################################################

#######################################################################
# Common Flash device geometries
#

FlashDevice ( ) {
	if [ -d ${NANO_TOOLS} ] ; then
		. ${NANO_TOOLS}/FlashDevice.sub
	else
		. ${NANO_SRC}/${NANO_TOOLS}/FlashDevice.sub
	fi
	sub_FlashDevice $1 $2
}

#######################################################################
# USB device geometries
#
# Usage:
#	UsbDevice Generic 1000	# a generic flash key sold as having 1GB
#
# This function will set NANO_MEDIASIZE, NANO_HEADS and NANO_SECTS for you.
#
# Note that the capacity of a flash key is usually advertised in MB or
# GB, *not* MiB/GiB. As such, the precise number of cylinders available
# for C/H/S geometry may vary depending on the actual flash geometry.
#
# The following generic device layouts are understood:
#  generic           An alias for generic-hdd.
#  generic-hdd       255H 63S/T xxxxC with no MBR restrictions.
#  generic-fdd       64H 32S/T xxxxC with no MBR restrictions.
#
# The generic-hdd device is preferred for flash devices larger than 1GB.
#

UsbDevice ( ) {
	a1=`echo $1 | tr '[:upper:]' '[:lower:]'`
	case $a1 in
	generic-fdd)
		NANO_HEADS=64
		NANO_SECTS=32
		NANO_MEDIASIZE=$(( $2 * 1000 * 1000 / 512 ))
		;;
	generic|generic-hdd)
		NANO_HEADS=255
		NANO_SECTS=63
		NANO_MEDIASIZE=$(( $2 * 1000 * 1000 / 512 ))
		;;
	*)
		echo "Unknown USB flash device"
		exit 2
		;;
	esac
}

#######################################################################
# Setup serial console

cust_comconsole ( ) (
	# Enable getty on console
	sed -i "" -e /tty[du]0/s/off/on/ ${NANO_WORLDDIR}/etc/ttys

	# Disable getty on syscons devices
	sed -i "" -e '/^ttyv[0-8]/s/	on/	off/' ${NANO_WORLDDIR}/etc/ttys

	# Tell loader to use serial console early.
	echo "${NANO_BOOT2CFG}" > ${NANO_WORLDDIR}/boot.config
)

#######################################################################
# Allow root login via ssh

cust_allow_ssh_root ( ) (
	sed -i "" -e '/PermitRootLogin/s/.*/PermitRootLogin yes/' \
	    ${NANO_WORLDDIR}/etc/ssh/sshd_config
)

#######################################################################
# Install the stuff under ./Files

cust_install_files ( ) (
	cd "${NANO_TOOLS}/Files"
	find . -print | grep -Ev '/(CVS|\.svn|\.hg|\.git)' | cpio -Ldumpv ${NANO_WORLDDIR}
)

#######################################################################
# Install packages from ${NANO_PACKAGE_DIR}

cust_pkgng ( ) (

	# If the package directory doesn't exist, we're done.
	if [ ! -d ${NANO_PACKAGE_DIR} ]; then
		echo "DONE 0 packages"
		return 0
	fi

	# Find a pkg-* package
	for x in `find -s ${NANO_PACKAGE_DIR} -iname 'pkg-*'`; do
		_NANO_PKG_PACKAGE=`basename "$x"`
	done
	if [ -z "${_NANO_PKG_PACKAGE}" -o ! -f "${NANO_PACKAGE_DIR}/${_NANO_PKG_PACKAGE}" ]; then
		echo "FAILED: need a pkg/ package for bootstrapping"
		exit 2
	fi

	# Copy packages into chroot
	mkdir -p ${NANO_WORLDDIR}/Pkg
	(
		cd "${NANO_PACKAGE_DIR}"
		find "${NANO_PACKAGE_LIST}" -print |
		cpio -Ldumpv ${NANO_WORLDDIR}/Pkg
	)

	#Bootstrap pkg
	CR env ASSUME_ALWAYS_YES=YES SIGNATURE_TYPE=none /usr/sbin/pkg add /Pkg/${_NANO_PKG_PACKAGE}
	CR pkg -N >/dev/null 2>&1
	if [ "$?" -ne "0" ]; then
		echo "FAILED: pkg bootstrapping faied"
		exit 2
	fi
	rm -f ${NANO_WORLDDIR}/Pkg/pkg-*

	# Count & report how many we have to install
	todo=`ls ${NANO_WORLDDIR}/Pkg | /usr/bin/wc -l`
	todo=$(expr $todo + 1) # add one for pkg since it is installed already
	echo "=== TODO: $todo"
	ls ${NANO_WORLDDIR}/Pkg
	echo "==="
	while true
	do
		# Record how many we have now
 		have=$(CR env ASSUME_ALWAYS_YES=YES /usr/sbin/pkg info | /usr/bin/wc -l)

		# Attempt to install more packages
		CR0 'ls 'Pkg/*txz' | xargs env ASSUME_ALWAYS_YES=YES /usr/sbin/pkg add'

		# See what that got us
 		now=$(CR env ASSUME_ALWAYS_YES=YES /usr/sbin/pkg info | /usr/bin/wc -l)
		echo "=== NOW $now"
		CR env ASSUME_ALWAYS_YES=YES /usr/sbin/pkg info
		echo "==="
		if [ $now -eq $todo ] ; then
			echo "DONE $now packages"
			break
		elif [ $now -eq $have ] ; then
			echo "FAILED: Nothing happened on this pass"
			exit 2
		fi
	done
	rm -rf ${NANO_WORLDDIR}/Pkg
)

#######################################################################
# Convenience function:
# 	Register all args as customize function.

customize_cmd ( ) {
	NANO_CUSTOMIZE="$NANO_CUSTOMIZE $*"
}

#######################################################################
# Convenience function:
# 	Register all args as late customize function to run just before
#	image creation.

late_customize_cmd ( ) {
	NANO_LATE_CUSTOMIZE="$NANO_LATE_CUSTOMIZE $*"
}

#######################################################################
#
# All set up to go...
#
#######################################################################

# Progress Print
#	Print $2 at level $1.
pprint ( ) (
    if [ "$1" -le $PPLEVEL ]; then
	runtime=$(( `date +%s` - $NANO_STARTTIME ))
	printf "%s %.${1}s %s\n" "`date -u -r $runtime +%H:%M:%S`" "#####" "$2" 1>&3
    fi
)

usage ( ) {
	(
	echo "Usage: $0 [-bfiKknqvw] [-c config_file]"
	echo "	-b	suppress builds (both kernel and world)"
	echo "	-c	specify config file"
	echo "	-f	suppress code slice extraction"
	echo "	-i	suppress disk image build"
	echo "	-K	suppress installkernel"
	echo "	-k	suppress buildkernel"
	echo "	-n	add -DNO_CLEAN to buildworld, buildkernel, etc"
	echo "	-q	make output more quiet"
	echo "	-v	make output more verbose"
	echo "	-w	suppress buildworld"
	) 1>&2
	exit 2
}

#######################################################################
# Setup and Export Internal variables
#

export_var ( ) {		# Don't wawnt a subshell
	var=$1
	# Lookup value of the variable.
	eval val=\$$var
	pprint 3 "Setting variable: $var=\"$val\""
	export $1
}

# Call this function to set defaults _after_ parsing options.
# dont want a subshell otherwise variable setting is thrown away.
set_defaults_and_export ( ) {
	: ${NANO_OBJ:=/usr/obj/nanobsd.${NANO_NAME}}
	: ${MAKEOBJDIRPREFIX:=${NANO_OBJ}}
	: ${NANO_DISKIMGDIR:=${NANO_OBJ}}
	NANO_WORLDDIR=${NANO_OBJ}/_.w
	NANO_MAKE_CONF_BUILD=${MAKEOBJDIRPREFIX}/make.conf.build
	NANO_MAKE_CONF_INSTALL=${NANO_OBJ}/make.conf.install

	# Override user's NANO_DRIVE if they specified a NANO_LABEL
	[ -n "${NANO_LABEL}" ] && NANO_DRIVE="ufs/${NANO_LABEL}" || true

	# Set a default NANO_TOOLS to NANO_SRC/NANO_TOOLS if it exists.
	[ ! -d "${NANO_TOOLS}" ] && [ -d "${NANO_SRC}/${NANO_TOOLS}" ] && \
		NANO_TOOLS="${NANO_SRC}/${NANO_TOOLS}" || true

	[ -n "${NANO_NOPRIV_BUILD}" ] && [ -z "${NANO_METALOG}" ] && \
		NANO_METALOG=${NANO_OBJ}/_.metalog || true

	NANO_STARTTIME=`date +%s`
	pprint 3 "Exporting NanoBSD variables"
	export_var MAKEOBJDIRPREFIX
	export_var NANO_ARCH
	export_var NANO_CODESIZE
	export_var NANO_CONFSIZE
	export_var NANO_CUSTOMIZE
	export_var NANO_DATASIZE
	export_var NANO_DRIVE
	export_var NANO_HEADS
	export_var NANO_IMAGES
	export_var NANO_IMGNAME
	export_var NANO_MAKE
	export_var NANO_MAKE_CONF_BUILD
	export_var NANO_MAKE_CONF_INSTALL
	export_var NANO_MEDIASIZE
	export_var NANO_NAME
	export_var NANO_NEWFS
	export_var NANO_OBJ
	export_var NANO_PMAKE
	export_var NANO_SECTS
	export_var NANO_SRC
	export_var NANO_TOOLS
	export_var NANO_WORLDDIR
	export_var NANO_BOOT0CFG
	export_var NANO_BOOTLOADER
	export_var NANO_LABEL
	export_var NANO_MODULES
	export_var NANO_NOPRIV_BUILD
	export_var NANO_METALOG
	export_var SRCCONF
	export_var SRC_ENV_CONF
}
