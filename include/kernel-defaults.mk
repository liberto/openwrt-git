# 
# Copyright (C) 2006-2007 OpenWrt.org
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

# default device type
DEVICE_TYPE?=router

# Default packages - the really basic set
DEFAULT_PACKAGES:=base-files libgcc uclibc busybox dropbear mtd mtd
# For router targets
DEFAULT_PACKAGES.router:=dnsmasq iptables ppp ppp-mod-pppoe iptables kmod-ipt-nathelper bridge

# Additional packages for Linux 2.6
ifneq ($(KERNEL),2.4)
  DEFAULT_PACKAGES += udevtrigger hotplug2
endif

# Add device specific packages
DEFAULT_PACKAGES += $(DEFAULT_PACKAGES.$(DEVICE_TYPE))

KERNELNAME=
ifneq (,$(findstring x86,$(BOARD)))
  KERNELNAME="bzImage"
endif
ifneq (,$(findstring rdc,$(BOARD)))
  KERNELNAME="bzImage"
endif
ifneq (,$(findstring ppc,$(BOARD)))
  KERNELNAME="uImage"
endif
ifneq (,$(findstring avr32,$(BOARD)))
  KERNELNAME="uImage"
endif

KERNEL_MAKEOPTS := -C $(LINUX_DIR) \
	CROSS_COMPILE="$(KERNEL_CROSS)" \
	ARCH="$(LINUX_KARCH)" \
	CONFIG_SHELL="$(BASH)"

# defined in quilt.mk
Kernel/Patch:=$(Kernel/Patch/Default)
define Kernel/Prepare/Default
	bzcat $(DL_DIR)/$(LINUX_SOURCE) | $(TAR) -C $(KERNEL_BUILD_DIR) $(TAR_OPTIONS)
	$(Kernel/Patch)
	$(if $(QUILT),touch $(LINUX_DIR)/.quilt_used)
endef

define Kernel/Configure/2.4
	$(SED) "s,\-mcpu=,\-mtune=,g;" $(LINUX_DIR)/arch/mips/Makefile
	$(MAKE) $(KERNEL_MAKEOPTS) CC="$(KERNEL_CC)" oldconfig include/linux/compile.h include/linux/version.h
	$(MAKE) $(KERNEL_MAKEOPTS) dep
endef
define Kernel/Configure/2.6
	-$(MAKE) $(KERNEL_MAKEOPTS) CC="$(KERNEL_CC)" oldconfig prepare scripts
endef
define Kernel/Configure/Default
	$(LINUX_CONFCMD) > $(LINUX_DIR)/.config.target
	$(SCRIPT_DIR)/metadata.pl kconfig $(TMP_DIR)/.packageinfo $(TOPDIR)/.config > $(LINUX_DIR)/.config.override
	$(SCRIPT_DIR)/kconfig.pl 'm+' $(LINUX_DIR)/.config.target $(LINUX_DIR)/.config.override > $(LINUX_DIR)/.config
	$(call Kernel/Configure/$(KERNEL))
	rm -rf $(KERNEL_BUILD_DIR)/modules
endef

define Kernel/CompileModules/Default
	rm -f $(LINUX_DIR)/vmlinux $(LINUX_DIR)/System.map
	$(MAKE) $(KERNEL_MAKEOPTS) CC="$(KERNEL_CC)" modules
endef

ifeq ($(KERNEL),2.6)
  ifeq ($(CONFIG_TARGET_ROOTFS_INITRAMFS),y)
    define Kernel/SetInitramfs
		mv $(LINUX_DIR)/.config $(LINUX_DIR)/.config.old
		grep -v INITRAMFS $(LINUX_DIR)/.config.old > $(LINUX_DIR)/.config
		echo 'CONFIG_INITRAMFS_SOURCE="$(TARGET_DIR)"' >> $(LINUX_DIR)/.config
		echo 'CONFIG_INITRAMFS_ROOT_UID=0' >> $(LINUX_DIR)/.config
		echo 'CONFIG_INITRAMFS_ROOT_GID=0' >> $(LINUX_DIR)/.config
    endef
  else
    define Kernel/SetInitramfs
		mv $(LINUX_DIR)/.config $(LINUX_DIR)/.config.old
		grep -v INITRAMFS $(LINUX_DIR)/.config.old > $(LINUX_DIR)/.config
		rm -f $(TARGET_DIR)/init
		echo 'CONFIG_INITRAMFS_SOURCE=""' >> $(LINUX_DIR)/.config
    endef
  endif
endif
define Kernel/CompileImage/Default
	$(call Kernel/SetInitramfs)
	$(MAKE) $(KERNEL_MAKEOPTS) CC="$(KERNEL_CC)" $(KERNELNAME)
	$(KERNEL_CROSS)objcopy -O binary -R .reginfo -R .note -R .comment -R .mdebug -S $(LINUX_DIR)/vmlinux $(LINUX_KERNEL)
	$(KERNEL_CROSS)objcopy -R .reginfo -R .note -R .comment -R .mdebug -S $(LINUX_DIR)/vmlinux $(KERNEL_BUILD_DIR)/vmlinux.elf
endef

define Kernel/Clean/Default
	rm -f $(KERNEL_BUILD_DIR)/linux-$(LINUX_VERSION)/.configured
	rm -f $(LINUX_KERNEL)
	$(MAKE) -C $(KERNEL_BUILD_DIR)/linux-$(LINUX_VERSION) clean
endef


