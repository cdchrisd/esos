# $Id$

# Something.
# Something.
# Something.

CWD		:= $(shell pwd)
WORK_DIR	:= $(CWD)/work
DISTFILES_DIR	:= $(WORK_DIR)/distfiles
BUILD_DIR	:= $(WORK_DIR)/build
IMAGE_DIR	:= $(WORK_DIR)/image
INITRAMFS_DIR	:= $(WORK_DIR)/initramfs
MOUNT_DIR	:= $(WORK_DIR)/mnt

QUIET		:= @
STRIP		:= -s

WGET		:= wget -t 5
MKDIR		:= mkdir -p
RM		:= rm -rf
TAR		:= tar
UNZIP		:= unzip
CP		:= cp -L
FIND		:= find
CPIO		:= cpio
GZIP		:= gzip -9
CD		:= cd
ECHO		:= echo
SFDISK		:= sfdisk
CAT		:= cat
TEST		:= test
EXIT		:= exit
READ		:= read
GREP		:= grep
DD		:= dd
MKE2FS		:= mke2fs
LN		:= ln -sf
MOUNT		:= mount
UMOUNT		:= umount
SED		:= sed
MKNOD		:= mknod
TOUCH		:= touch
RPM2CPIO	:= rpm2cpio
INSTALL		:= install
PATCH		:= patch
CHOWN		:= chown
MD5SUM		:= md5sum -w
SHA256SUM	:= sha256sum -w

distfiles = $(addprefix $(DISTFILES_DIR)/,	\
		busybox-1.19.0.tar.bz2		\
		grub-0.97.tar.gz		\
		sysvinit-2.88dsf.tar.bz2	\
		glibc-2.12.2.tar.bz2		\
		vixie-cron-4.1.tar.bz2		\
		openssh-5.8p1.tar.gz		\
		ssmtp-2.64.tar.bz2		\
		perl-5.12.4.tar.bz2		\
		openssl-1.0.0e.tar.gz		\
		e2fsprogs-1.41.14.tar.gz	\
		zlib-1.2.5.tar.bz2		\
		ncurses-5.7.tar.gz		\
		qlogic_fw-20120101.tar.gz	\
		linux-2.6.39.4.tar.bz2		\
		srpt-2.1.0.tar.bz2		\
		qla2x00t-2.1.0.tar.gz		\
		scstadmin-2.1.0.tar.gz		\
		scst-2.1.0.tar.gz		\
		iscsi-scst-2.1.0.tar.gz		\
		gcc-4.4.5.tar.bz2)
distfiles_repo = http://enterprise-storage-os.googlecode.com/files

no_fetch_pkg_1 = $(addprefix $(DISTFILES_DIR)/,8.02.16_MegaCLI.zip)
no_fetch_pkg_1_url = http://www.lsi.com/search/Pages/downloads.aspx?k=8.02.16_MegaCLI.zip

build_targets := scst_kernel busybox sysvinit grub glibc \
		perl MegaCLI qlogic_fw scstadmin openssh \
		vixie-cron gcc openssl zlib ncurses \
		e2fsprogs ssmtp
clean_targets := $(addprefix clean-,$(build_targets))
src_dir = $(wildcard $(BUILD_DIR)/$(@)-*)
tarball_src_dirs = $(addprefix $(BUILD_DIR)/, \
		$(subst .tar.bz2,,$(subst .tar.gz,,$(notdir $(distfiles)))))

esos_ver	:= 0.1
prod_suffix	:= -esos.prod
debug_suffix	:= -esos.debug


# all - The default goal; complete every target except install.
.PHONY: all
all: fetch extract build ;


# install - Prompt for USB thumb-drive device node and install the distribution to it.
.PHONY: install
install: install_dev_node = $(WORK_DIR)/install_dev_node
install: usb_device = $$($(CAT) $(install_dev_node))
install: initramfs
	$(QUIET) if [ `whoami` != "root" ]; then \
	  $(ECHO) "### Snap! Ya gotta be root for this part..."; \
	  $(EXIT) 1; \
	fi
	$(QUIET) $(ECHO) "### Please type the full path of your USB drive device node (eg, /dev/sdz):" &&	\
	$(READ) dev_node && $(ECHO) -n $$dev_node > $(install_dev_node)
	$(QUIET) $(ECHO) && $(ECHO)
	$(QUIET) if [ "$(usb_device)" == "" ] || [ ! -e $(usb_device) ]; then \
	  $(ECHO) "### That device node doesn't seem to exist."; \
	  $(EXIT) 1; \
	fi
	$(QUIET) if $(GREP) $(usb_device) /proc/mounts > /dev/null; then \
	  $(ECHO) "### It looks like that device is mounted..."; \
	  $(EXIT) 1; \
	fi
	$(QUIET) $(ECHO) "### This is what '$(usb_device)' looks like..."
	$(QUIET) $(SFDISK) -l $(usb_device)
	$(QUIET) $(ECHO) && $(ECHO)
	$(QUIET) $(ECHO) "### Proceeding will completely wipe the above device! Are you sure (Yes)?" &&	\
	$(READ) confirm && $(TEST) $$confirm == "Yes"
	$(QUIET) $(ECHO) && $(ECHO)
	$(QUIET) $(ECHO) "### Saving MBR / partition table for $(usb_device)..."
	$(DD) if=$(usb_device) of=$(WORK_DIR)/`basename $(usb_device)`.mbr bs=512 count=1
	$(SFDISK) -d $(usb_device) > $(WORK_DIR)/`basename $(usb_device)`.sfdisk
	$(QUIET) $(ECHO) && $(ECHO)
	$(QUIET) $(ECHO) "### Creating new partitions / filesystems on $(usb_device)..."
	$(DD) if=/dev/zero of=$(usb_device) bs=512 count=1
	$(ECHO) -e ",32,L,*\n,512,L\n,256,L\n,1024,L\n" | $(SFDISK) -uM $(usb_device)
	$(MKE2FS) -L esos_boot $(usb_device)1
	$(MKE2FS) -L esos_root $(usb_device)2
	$(MKE2FS) -L esos_conf $(usb_device)3
	$(MKE2FS) -L esos_logs $(usb_device)4
	$(QUIET) $(ECHO) && $(ECHO)
	$(QUIET) $(ECHO) "### Installing image..."
	$(MKDIR) $(MOUNT_DIR)
	$(MOUNT) -L esos_root $(MOUNT_DIR) 
	$(MKDIR) $(MOUNT_DIR)/boot
	$(MOUNT) -L esos_boot $(MOUNT_DIR)/boot
	$(CD) $(CWD)/etc && $(FIND) . -depth | $(CPIO) -pmdv $(IMAGE_DIR)/etc
	$(CD) $(IMAGE_DIR) && $(FIND) . -depth | $(CPIO) -pmdv $(MOUNT_DIR)
	$(IMAGE_DIR)/usr/sbin/grub-install --root-directory=$(MOUNT_DIR) --no-floppy $(usb_device)
	$(SED) 's/@@esos_ver@@/$(esos_ver)/' $(CWD)/misc/grub.conf > $(MOUNT_DIR)/boot/grub/grub.conf
	$(LN) grub.conf $(MOUNT_DIR)/boot/grub/menu.lst
	$(LN) /usr/share/zoneinfo/UTC $(MOUNT_DIR)/etc/localtime
	$(INSTALL) $(CWD)/scripts/conf_sync.sh $(MOUNT_DIR)/usr/local/sbin/
	$(INSTALL) $(CWD)/scripts/archive_logs.sh $(MOUNT_DIR)/usr/local/sbin/
	$(TOUCH) -d "1970-01-01 00:00:00" $(MOUNT_DIR)/etc/*
	$(CHOWN) -R root:root $(MOUNT_DIR)/*
	$(UMOUNT) $(MOUNT_DIR)/boot
	$(UMOUNT) $(MOUNT_DIR)
	$(QUIET) $(ECHO) && $(ECHO)
	$(QUIET) $(ECHO) "### All done; your ESOS USB drive should be ready to use!"

.PHONY: initramfs
initramfs:
	$(RM) $(INITRAMFS_DIR)/dev/*
	$(MKNOD) $(INITRAMFS_DIR)/dev/null c 1 3
	$(MKNOD) $(INITRAMFS_DIR)/dev/console c 5 1
	$(MKNOD) $(INITRAMFS_DIR)/dev/tty c 5 0
	$(INSTALL) $(CWD)/misc/initramfs_init $(INITRAMFS_DIR)/init
	$(LN) busybox $(INITRAMFS_DIR)/bin/sh
	$(CD) $(INITRAMFS_DIR) && $(FIND) . -print0 |	\
	$(CPIO) --null -ov --format=newc |		\
	$(GZIP) > $(IMAGE_DIR)/boot/initramfs.cpio.gz


# clean - Remove all temporary files and clean/distclean each package source directory.
.PHONY: clean
clean: $(clean_targets)
	$(RM) $(INITRAMFS_DIR)
	$(RM) $(IMAGE_DIR)

$(clean_targets): target = $(subst clean-,,$(@))
$(clean_targets):
	$(RM) $(target)


# distclean - Remove everything including build configuration settings.
.PHONY: distclean
distclean: clean
	$(RM) $(WORK_DIR)


# fetch - Grab all required packages from distribution file repositories.
fetch: $(distfiles) $(no_fetch_pkg_1) ;

$(distfiles):
	$(WGET) -P $(DISTFILES_DIR) $(distfiles_repo)/$(notdir $(@))

$(no_fetch_pkg_1):
	$(QUIET) $(ECHO) "### Fetch restriction: $(notdir $(@))"
	$(QUIET) $(ECHO) "### Please download from '$(no_fetch_pkg_1_url)'"
	$(QUIET) $(ECHO) "### and place it in '$(DISTFILES_DIR)'."


# checksum - Verify checksums for all distribution files.
.PHONY: checksum
checksum: fetch
	$(QUIET) $(ECHO) "### Verifying MD5 checksums..."
	$(QUIET) $(CD) $(DISTFILES_DIR) && $(MD5SUM) -c $(CWD)/CHECKSUM.MD5
	$(QUIET) $(ECHO) "### Verifying SHA256 checksums..."
	$(QUIET) $(CD) $(DISTFILES_DIR) && $(SHA256SUM) -c $(CWD)/CHECKSUM.SHA256


# extract - Extract all of the previously downloaded packages/archives.
extract: fetch checksum $(tarball_src_dirs) ;

$(tarball_src_dirs): src_file = $(wildcard $(DISTFILES_DIR)/$(notdir $(@)).*)
$(tarball_src_dirs):
	$(MKDIR) $(BUILD_DIR)
	$(QUIET) if [ "$(suffix $(src_file))" == ".gz" ]; then \
	  $(TAR) xvfz $(src_file) -C $(BUILD_DIR); \
	elif [ "$(suffix $(src_file))" == ".bz2" ]; then \
	  $(TAR) xvfj $(src_file) -C $(BUILD_DIR); \
	else \
	  $(ECHO) "### Unhandled file extension: $(suffix $(src_file))"; \
	  $(EXIT) 1; \
	fi


# build - Configure/compile/build all of the required projects.
.PHONY: build
build: image_setup $(build_targets) ;

.PHONY: image_setup
image_setup:
	$(MKDIR) $(IMAGE_DIR)/{etc,bin,sbin,dev,proc,sys,root,home}
	$(MKDIR) $(IMAGE_DIR)/boot/grub
	$(MKDIR) $(IMAGE_DIR)/mnt/{root,conf,logs}
	#$(MKDIR) $(IMAGE_DIR)/mnt/conf
	#$(MKDIR) $(IMAGE_DIR)/mnt/logs
	#$(MKDIR) $(IMAGE_DIR)/etc
	$(MKDIR) $(IMAGE_DIR)/lib/firmware
	#$(MKDIR) $(IMAGE_DIR)/bin
	#$(MKDIR) $(IMAGE_DIR)/sbin
	$(MKDIR) $(IMAGE_DIR)/usr/{bin,sbin,libexec}
	#$(MKDIR) $(IMAGE_DIR)/usr/bin
	#$(MKDIR) $(IMAGE_DIR)/usr/sbin
	#$(MKDIR) $(IMAGE_DIR)/usr/libexec
	$(MKDIR) $(IMAGE_DIR)/usr/local/{bin,sbin}
	#$(MKDIR) $(IMAGE_DIR)/usr/local/bin
	#$(MKDIR) $(IMAGE_DIR)/usr/local/sbin
	#$(MKDIR) $(IMAGE_DIR)/dev
	#$(MKDIR) $(IMAGE_DIR)/proc
	#$(MKDIR) $(IMAGE_DIR)/sys
	#$(MKDIR) $(IMAGE_DIR)/root
	#$(MKDIR) $(IMAGE_DIR)/tmp
	$(INSTALL) -m 1777 -d $(IMAGE_DIR)/tmp
	#$(MKDIR) $(IMAGE_DIR)/home
	$(MKDIR) $(IMAGE_DIR)/var/{spool,lock,run,state,cache,log,empty}
	#$(MKDIR) $(IMAGE_DIR)/var/spool
	#$(MKDIR) $(IMAGE_DIR)/var/lock
	#$(MKDIR) $(IMAGE_DIR)/var/run
	#$(MKDIR) $(IMAGE_DIR)/var/state
	#$(MKDIR) $(IMAGE_DIR)/var/cache
	#$(MKDIR) $(IMAGE_DIR)/var/tmp
	$(INSTALL) -m 1777 -d $(IMAGE_DIR)/var/tmp
	#$(MKDIR) $(IMAGE_DIR)/var/log
	#$(MKDIR) $(IMAGE_DIR)/var/empty
	$(INSTALL) -m 710 -d $(IMAGE_DIR)/var/cron
	$(INSTALL) -m 700 -d $(IMAGE_DIR)/var/cron/tabs
	$(LN) lib $(IMAGE_DIR)/lib64
	$(LN) lib $(IMAGE_DIR)/usr/lib64
	$(MKDIR) $(INITRAMFS_DIR)/{bin,sbin,proc,sys,dev}
	#$(MKDIR) $(INITRAMFS_DIR)/bin
	#$(MKDIR) $(INITRAMFS_DIR)/sbin
	$(MKDIR) $(INITRAMFS_DIR)/mnt/{root,tmp}
	#$(MKDIR) $(INITRAMFS_DIR)/mnt/root
	#$(MKDIR) $(INITRAMFS_DIR)/mnt/tmp
	#$(MKDIR) $(INITRAMFS_DIR)/mnt/conf
	#$(MKDIR) $(INITRAMFS_DIR)/mnt/logs
	#$(MKDIR) $(INITRAMFS_DIR)/proc
	#$(MKDIR) $(INITRAMFS_DIR)/sys
	$(MKDIR) $(INITRAMFS_DIR)/usr/{bin,sbin}
	#$(MKDIR) $(INITRAMFS_DIR)/usr/bin
	#$(MKDIR) $(INITRAMFS_DIR)/usr/sbin
	#$(MKDIR) $(INITRAMFS_DIR)/dev

scst_kernel: linux_src = $(wildcard $(BUILD_DIR)/linux-*)
scst_kernel: kernel_ver = $(subst linux-,,$(notdir $(linux_src)))
scst_kernel: scst_src = $(wildcard $(BUILD_DIR)/scst-*)
scst_kernel: qla2x00t_src = $(wildcard $(BUILD_DIR)/qla2x00t-*)
scst_kernel: iscsi-scst_src = $(wildcard $(BUILD_DIR)/iscsi-scst-*)
scst_kernel:
	### Kernel prerequisites for SCST
	if [ ! -d $(linux_src)/scst_exec_req_fifo.patch ]; \
	then \
	  $(PATCH) -d $(linux_src) -b -B $(linux_src)/scst_exec_req_fifo.patch/ \
	  -p1 < $(scst_src)/kernel/scst_exec_req_fifo-2.6.39.patch; \
	fi
	if [ ! -d $(linux_src)/put_page_callback.patch ]; \
	then \
	  $(PATCH) -d $(linux_src) -b -B $(linux_src)/put_page_callback.patch/ \
	  -p1 < $(iscsi-scst_src)/kernel/patches/put_page_callback-2.6.39.patch; \
	fi
	$(RM) $(linux_src)/drivers/scsi/qla2xxx
	$(LN) $(qla2x00t_src) $(linux_src)/drivers/scsi/qla2xxx
	### Build the kernel (prod)
	$(MAKE) --directory=$(linux_src) clean
	$(MAKE) --directory=$(linux_src) distclean
	$(SED) 's/CONFIG_LOCALVERSION\=\"\"/CONFIG_LOCALVERSION\=\"$(prod_suffix)\"/' \
	$(CWD)/misc/$(notdir $(linux_src)).config > $(linux_src)/.config
	$(MAKE) --directory=$(linux_src)
	$(INSTALL) $(linux_src)/arch/x86_64/boot/bzImage $(IMAGE_DIR)/boot/bzImage.prod
	$(MAKE) --directory=$(linux_src) INSTALL_MOD_PATH=$(IMAGE_DIR) modules_install
	### Build SCST modules (prod)
	$(MAKE) --directory=$(scst_src)/src clean
	$(MAKE) --directory=$(scst_src)/src extraclean
	$(MAKE) --directory=$(scst_src)/src debug2perf
	$(MAKE) --directory=$(scst_src)/src KDIR=$(linux_src) all
	$(MAKE) --directory=$(scst_src)/src KDIR=$(linux_src) DESTDIR=$(IMAGE_DIR) \
	KVER=$(kernel_ver)$(prod_suffix) install
	### Build qla2x00t modules (prod)
	$(MAKE) --directory=$(qla2x00t_src)/qla2x00-target clean
	$(MAKE) --directory=$(qla2x00t_src)/qla2x00-target extraclean
	$(MAKE) --directory=$(qla2x00t_src)/qla2x00-target debug2perf
	$(MAKE) --directory=$(qla2x00t_src)/qla2x00-target \
	SCST_INC_DIR=$(IMAGE_DIR)/usr/local/include/scst KDIR=$(linux_src) all
	$(MAKE) --directory=$(qla2x00t_src)/qla2x00-target KDIR=$(linux_src) \
	KVER=$(kernel_ver)$(prod_suffix) INSTALL_MOD_PATH=$(IMAGE_DIR) \
	SCST_INC_DIR=$(IMAGE_DIR)/usr/local/include/scst install
	### Build iscsi-scst modules (prod)
	$(MAKE) --directory=$(iscsi-scst_src) clean
	$(MAKE) --directory=$(iscsi-scst_src) extraclean
	$(MAKE) --directory=$(iscsi-scst_src) debug2perf
	$(MAKE) --directory=$(iscsi-scst_src) include/iscsi_scst_itf_ver.h
	$(MAKE) --directory=$(iscsi-scst_src) SCST_INC_DIR=$(IMAGE_DIR)/usr/local/include/scst \
	KDIR=$(linux_src) mods
	$(INSTALL) -vD -m 644 $(iscsi-scst_src)/kernel/iscsi-scst.ko \
	$(IMAGE_DIR)/lib/modules/$(kernel_ver)$(prod_suffix)/extra/iscsi-scst.ko
	### Build the kernel (debug)
	$(MAKE) --directory=$(linux_src) clean
	$(MAKE) --directory=$(linux_src) distclean
	$(SED) 's/CONFIG_LOCALVERSION\=\"\"/CONFIG_LOCALVERSION\=\"$(debug_suffix)\"/' \
	$(CWD)/misc/$(notdir $(linux_src)).config > $(linux_src)/.config
	$(MAKE) --directory=$(linux_src)
	$(INSTALL) $(linux_src)/arch/x86_64/boot/bzImage $(IMAGE_DIR)/boot/bzImage.debug
	$(MAKE) --directory=$(linux_src) INSTALL_MOD_PATH=$(IMAGE_DIR) modules_install
	### Build SCST modules (debug)
	$(MAKE) --directory=$(scst_src)/src clean
	$(MAKE) --directory=$(scst_src)/src extraclean
	$(MAKE) --directory=$(scst_src)/src perf2debug
	$(MAKE) --directory=$(scst_src)/src KDIR=$(linux_src) all
	$(MAKE) --directory=$(scst_src)/src KDIR=$(linux_src) DESTDIR=$(IMAGE_DIR) \
	KVER=$(kernel_ver)$(debug_suffix) install
	### Build qla2x00t modules (debug)
	$(MAKE) --directory=$(qla2x00t_src)/qla2x00-target clean
	$(MAKE) --directory=$(qla2x00t_src)/qla2x00-target extraclean
	$(MAKE) --directory=$(qla2x00t_src)/qla2x00-target perf2debug
	$(MAKE) --directory=$(qla2x00t_src)/qla2x00-target \
	SCST_INC_DIR=$(IMAGE_DIR)/usr/local/include/scst KDIR=$(linux_src) all
	$(MAKE) --directory=$(qla2x00t_src)/qla2x00-target KDIR=$(linux_src) \
	KVER=$(kernel_ver)$(debug_suffix) INSTALL_MOD_PATH=$(IMAGE_DIR) \
	SCST_INC_DIR=$(IMAGE_DIR)/usr/local/include/scst install
	### Build iscsi-scst modules (debug)
	$(MAKE) --directory=$(iscsi-scst_src) clean
	$(MAKE) --directory=$(iscsi-scst_src) extraclean
	$(MAKE) --directory=$(iscsi-scst_src) perf2debug
	$(MAKE) --directory=$(iscsi-scst_src) include/iscsi_scst_itf_ver.h
	$(MAKE) --directory=$(iscsi-scst_src) SCST_INC_DIR=$(IMAGE_DIR)/usr/local/include/scst \
	KDIR=$(linux_src) mods
	$(INSTALL) -vD -m 644 $(iscsi-scst_src)/kernel/iscsi-scst.ko \
	$(IMAGE_DIR)/lib/modules/$(kernel_ver)$(debug_suffix)/extra/iscsi-scst.ko
	### Build iscsi-scst userland
	$(MAKE) --directory=$(iscsi-scst_src) include/iscsi_scst_itf_ver.h
	$(MAKE) --directory=$(iscsi-scst_src) \
	SCST_INC_DIR=$(IMAGE_DIR)/usr/local/include/scst progs
	$(INSTALL) -vD -m 755 $(iscsi-scst_src)/usr/iscsi-scstd $(IMAGE_DIR)/usr/sbin/iscsi-scstd
	$(INSTALL) -vD -m 755 $(iscsi-scst_src)/usr/iscsi-scst-adm $(IMAGE_DIR)/usr/sbin/iscsi-scst-adm
	### Done
	$(TOUCH) $(@)

busybox:
	$(MAKE) --directory=$(src_dir) defconfig
	$(SED) -i -e 's/.*CONFIG_BUSYBOX_EXEC_PATH.*/CONFIG_BUSYBOX_EXEC_PATH\=\"\/bin\/busybox\"/' $(src_dir)/.config
	$(SED) -i -e 's/.*CONFIG_FEATURE_BASH_IS_ASH.*/CONFIG_FEATURE_BASH_IS_ASH\=y/' $(src_dir)/.config
	$(SED) -i -e 's/.*CONFIG_FEATURE_BASH_IS_NONE.*/# CONFIG_FEATURE_BASH_IS_NONE is not set/' $(src_dir)/.config
	LDFLAGS="--static" $(MAKE) --directory=$(src_dir)
	$(INSTALL) $(STRIP) $(src_dir)/busybox_unstripped $(WORK_DIR)/initramfs/bin/busybox
	$(MAKE) --directory=$(src_dir)
	$(INSTALL) $(STRIP) $(src_dir)/busybox_unstripped $(IMAGE_DIR)/bin/busybox
	$(INSTALL) -d $(IMAGE_DIR)/usr/share/udhcpc
	$(INSTALL) $(src_dir)/examples/udhcp/simple.script $(IMAGE_DIR)/usr/share/udhcpc/default.script
	$(TOUCH) $(@)

sysvinit:
	LDFLAGS="--static" $(MAKE) --directory=$(src_dir)/src
	$(MAKE) ROOT=$(IMAGE_DIR) --directory=$(src_dir)/src install
	$(TOUCH) $(@)

grub:
	$(CD) $(src_dir) && LDFLAGS="--static" ./configure --prefix=$(IMAGE_DIR)/usr
	$(MAKE) --directory=$(src_dir)
	$(MAKE) --directory=$(src_dir) install-exec
	$(TOUCH) $(@)

glibc:
	$(TOUCH) $(IMAGE_DIR)/etc/ld.so.conf
	$(MKDIR) $(WORK_DIR)/glibc-build
	$(CD) $(WORK_DIR)/glibc-build && \
	CFLAGS="-O2 -U_FORTIFY_SOURCE" $(src_dir)/configure --prefix=/usr
	$(MAKE) --directory=$(WORK_DIR)/glibc-build
	$(MAKE) --directory=$(WORK_DIR)/glibc-build install_root=$(IMAGE_DIR) install
	$(TOUCH) $(@)

perl:
	$(CD) $(src_dir) && ./configure.gnu --prefix=/usr
	$(MAKE) --directory=$(src_dir)
	$(MAKE) --directory=$(src_dir) test
	$(MAKE) --directory=$(src_dir) install.perl DESTDIR=$(IMAGE_DIR) INSTALLFLAGS="-f -o"
	$(TOUCH) $(@)

MegaCLI:
	$(MKDIR) $(BUILD_DIR)/$(@)
	$(UNZIP) -o $(BUILD_DIR)/LINUX/MegaCliLin.zip -d $(BUILD_DIR)/$(@)
	$(CD) $(IMAGE_DIR) && $(RPM2CPIO) $(BUILD_DIR)/$(@)/Lib_Utils-*.rpm | $(CPIO) -idmv
	$(CD) $(IMAGE_DIR) && $(RPM2CPIO) $(BUILD_DIR)/$(@)/MegaCli-*.rpm | $(CPIO) -idmv
	$(TOUCH) $(@)

qlogic_fw:
	$(CP) $(DISTFILES_DIR)/qlogic_fw/* $(IMAGE_DIR)/lib/firmware/
	$(TOUCH) $(@)

scstadmin: perl_mod = $(wildcard $(src_dir)/scstadmin/scst-*)
scstadmin:
	$(CD) $(src_dir)/scstadmin/scst-* && \
	$(IMAGE_DIR)/usr/bin/perl Makefile.PL PREFIX=$(IMAGE_DIR)/usr
	$(MAKE) --directory=$(perl_mod)
	$(MAKE) --directory=$(perl_mod) install
	$(CP) $(src_dir)/scstadmin/scstadmin $(IMAGE_DIR)/usr/sbin
	$(TOUCH) $(@)

openssh:
	$(CD) $(src_dir) && ./configure --prefix="" --exec-prefix=/usr
	$(MAKE) --directory=$(src_dir)
	$(INSTALL) -m 0755 -s $(src_dir)/sshd $(IMAGE_DIR)/usr/sbin/
	$(INSTALL) -m 0755 -s $(src_dir)/ssh $(IMAGE_DIR)/usr/bin/
	$(INSTALL) -m 0755 -s $(src_dir)/sftp $(IMAGE_DIR)/usr/bin/
	$(INSTALL) -m 0755 -s $(src_dir)/scp $(IMAGE_DIR)/usr/bin/
	$(INSTALL) -m 0755 -s $(src_dir)/sftp-server $(IMAGE_DIR)/usr/libexec/
	$(INSTALL) -m 0755 -s $(src_dir)/ssh-keygen $(IMAGE_DIR)/usr/bin/
	$(TOUCH) $(@)

vixie-cron:
	$(MAKE) --directory=$(src_dir) all
	$(INSTALL) -c -m  111 -s $(src_dir)/cron $(IMAGE_DIR)/usr/sbin/
	$(INSTALL) -c -m 4111 -s $(src_dir)/crontab $(IMAGE_DIR)/usr/bin/
	$(TOUCH) $(@)

gcc:
	$(MKDIR) $(WORK_DIR)/gcc-build
	$(CD) $(WORK_DIR)/gcc-build && $(src_dir)/configure --enable-languages=c,c++ --disable-nls --enable-threads \
	--with-gnu-as --with-gnu-ld --with-gcc --prefix=$(IMAGE_DIR)/usr
	$(MAKE) --directory=$(WORK_DIR)/gcc-build
	$(MAKE) --directory=$(WORK_DIR)/gcc-build install-target-libgcc
	$(MAKE) --directory=$(WORK_DIR)/gcc-build install-target-libstdc++-v3
	$(TOUCH) $(@)

openssl:
	$(CD) $(src_dir) && ./config shared --prefix=$(IMAGE_DIR)/usr
	$(MAKE) --directory=$(src_dir)
	$(MAKE) --directory=$(src_dir) install_sw
	$(TOUCH) $(@)

zlib:
	$(CD) $(src_dir) && ./configure --prefix=$(IMAGE_DIR)/usr
	$(MAKE) --directory=$(src_dir)
	$(MAKE) --directory=$(src_dir) install-libs
	$(TOUCH) $(@)

ncurses:
	$(CD) $(src_dir) && ./configure --prefix=$(IMAGE_DIR)/usr --with-shared
	$(MAKE) --directory=$(src_dir)
	$(MAKE) --directory=$(src_dir) install.libs
	$(TOUCH) $(@)

e2fsprogs:
	$(MKDIR) $(WORK_DIR)/e2fsprogs-build
	$(CD) $(WORK_DIR)/e2fsprogs-build && $(src_dir)/configure --prefix=$(IMAGE_DIR)/usr
	$(MAKE) --directory=$(WORK_DIR)/e2fsprogs-build
	$(MAKE) --directory=$(WORK_DIR)/e2fsprogs-build check
	$(MAKE) --directory=$(WORK_DIR)/e2fsprogs-build install
	$(TOUCH) $(@)

ssmtp:
	$(CD) $(src_dir) && ./configure --enable-ssl --prefix="" --exec-prefix=/usr
	$(MAKE) --directory=$(src_dir) SSMTPCONFDIR=/etc
	$(INSTALL) $(STRIP) -m 755 $(src_dir)/ssmtp $(IMAGE_DIR)/usr/sbin/ssmtp
	$(LN) ssmtp $(IMAGE_DIR)/usr/sbin/sendmail
	$(TOUCH) $(@)

