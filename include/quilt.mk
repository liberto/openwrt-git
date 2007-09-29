# 
# Copyright (C) 2007 OpenWrt.org
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

ifneq ($(__quilt_inc),1)
__quilt_inc:=1

ifeq ($(TARGET_BUILD),1)
  PKG_BUILD_DIR:=$(LINUX_DIR)
endif
PATCH_DIR?=./patches

ifeq ($(MAKECMDGOALS),refresh)
  override QUILT=1
endif

define Quilt/Patch
	@for patch in $$$$( (cd $(1) && if [ -f series ]; then grep -v '^#' series; else ls; fi; ) 2>/dev/null ); do ( \
		cp "$(1)/$$$$patch" $(PKG_BUILD_DIR); \
		cd $(PKG_BUILD_DIR); \
		quilt import -P$(2)$$$$patch -p 1 "$$$$patch"; \
		quilt push -f >/dev/null 2>/dev/null; \
		rm -f "$$$$patch"; \
	); done
endef

QUILT?=$(strip $(shell test -f $(PKG_BUILD_DIR)/.quilt_used && echo y))
ifneq ($(QUILT),)
  STAMP_PATCHED:=$(PKG_BUILD_DIR)/.quilt_patched
  override CONFIG_AUTOREBUILD=
  define Build/Patch/Default
	rm -rf $(PKG_BUILD_DIR)/patches
	mkdir -p $(PKG_BUILD_DIR)/patches
	$(call Quilt/Patch,$(PATCH_DIR),)
	@echo
	touch $(PKG_BUILD_DIR)/.quilt_used
  endef
  $(STAMP_CONFIGURED): $(STAMP_PATCHED) FORCE
  prepare: $(STAMP_PATCHED)
  quilt-check: $(STAMP_PATCHED)
else
  define Build/Patch/Default
	@if [ -d $(PATCH_DIR) -a "$$$$(ls $(PATCH_DIR) | wc -l)" -gt 0 ]; then \
		if [ -f $(PATCH_DIR)/series ]; then \
			grep -vE '^#' $(PATCH_DIR)/series | xargs -n1 \
				$(PATCH) $(PKG_BUILD_DIR) $(PATCH_DIR); \
		else \
			$(PATCH) $(PKG_BUILD_DIR) $(PATCH_DIR); \
		fi; \
	fi
  endef
endif

define Kernel/Patch/Default
	if [ -d $(GENERIC_PLATFORM_DIR)/files ]; then $(CP) $(GENERIC_PLATFORM_DIR)/files/* $(LINUX_DIR)/; fi
	if [ -d ./files ]; then $(CP) ./files/* $(LINUX_DIR)/; fi
	$(if $(strip $(QUILT)),$(call Quilt/Patch,$(GENERIC_PATCH_DIR),generic/), \
		if [ -d $(GENERIC_PATCH_DIR) ]; then $(PATCH) $(LINUX_DIR) $(GENERIC_PATCH_DIR); fi \
	)
	$(if $(strip $(QUILT)),$(call Quilt/Patch,$(PATCH_DIR),platform/), \
		if [ -d $(PATCH_DIR) ]; then $(PATCH) $(LINUX_DIR) $(PATCH_DIR); fi \
	)
	$(if $(strip $(QUILT)),touch $(PKG_BUILD_DIR)/.quilt_used)
endef

ifeq ($(TARGET_BUILD),1)
$(STAMP_PATCHED): $(STAMP_PREPARED)
	@cd $(PKG_BUILD_DIR); quilt pop -a -f >/dev/null 2>/dev/null || true
	(\
		cd $(PKG_BUILD_DIR)/patches; \
		rm -f series; \
		for file in *; do \
			if [ -f $$file/series ]; then \
				echo "Converting $$file/series"; \
				awk -v file="$$file/" '$$0 !~ /^#/ { print file $$0 }' $$file/series >> series; \
			else \
				echo "Sorting patches in $$file"; \
				find $$file/* -type f \! -name series | sort >> series; \
			fi; \
		done; \
	)
	if [ -s "$(PKG_BUILD_DIR)/patches/series" ]; then (cd $(PKG_BUILD_DIR); quilt push -a); fi
	touch $@
else
$(STAMP_PATCHED): $(STAMP_PREPARED)
	@cd $(PKG_BUILD_DIR); quilt pop -a -f >/dev/null 2>/dev/null || true
	(\
		cd $(PKG_BUILD_DIR)/patches; \
		find * -type f \! -name series | sort > series; \
	)
	if [ -s "$(PKG_BUILD_DIR)/patches/series" ]; then (cd $(PKG_BUILD_DIR); quilt push -a); fi
	touch $@
endif

define Quilt/RefreshDir
	mkdir -p $(1)
	-rm -f $(1)/* 2>/dev/null >/dev/null
	@( \
		for patch in $$($(if $(2),grep "^$(2)",cat) $(PKG_BUILD_DIR)/patches/series | awk '{print $$1}'); do \
			$(CP) -v "$(PKG_BUILD_DIR)/patches/$$patch" $(1); \
		done; \
	)
endef

define Quilt/Refresh/Package
	$(call Quilt/RefreshDir,$(PATCH_DIR))
endef

define Quilt/Refresh/Kernel
	@[ -z "$$(grep -v '^generic/' $(PKG_BUILD_DIR)/patches/series | grep -v '^platform/')" ] || { \
		echo "All kernel patches must start with either generic/ or platform/"; \
		false; \
	}
	$(call Quilt/RefreshDir,$(GENERIC_PATCH_DIR),generic/)
	$(call Quilt/RefreshDir,$(PATCH_DIR),platform/)
endef

quilt-check: $(STAMP_PREPARED) FORCE
	@[ -f "$(PKG_BUILD_DIR)/.quilt_used" ] || { \
		echo "The source directory was not unpacked using quilt. Please rebuild with QUILT=1"; \
		false; \
	}
	@[ -f "$(PKG_BUILD_DIR)/patches/series" ] || { \
		echo "The source directory contains no quilt patches."; \
		false; \
	}
	@[ "$$(cat $(PKG_BUILD_DIR)/patches/series | md5sum)" = "$$(sort $(PKG_BUILD_DIR)/patches/series | md5sum)" ] || { \
		echo "The patches are not sorted in the right order. Please fix."; \
		false; \
	}

refresh: quilt-check
	@cd $(PKG_BUILD_DIR); quilt pop -a -f >/dev/null 2>/dev/null
	@cd $(PKG_BUILD_DIR); while quilt next 2>/dev/null >/dev/null && quilt push; do \
		quilt refresh; \
	done; ! quilt next 2>/dev/null >/dev/null
	$(if $(KERNEL_BUILD),$(Quilt/Refresh/Kernel),$(Quilt/Refresh/Package))
	
update: quilt-check
	$(if $(KERNEL_BUILD),$(Quilt/Refresh/Kernel),$(Quilt/Refresh/Package))

endif
