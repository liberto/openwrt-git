ifneq ($(DUMP),)
all: dumpinfo
else
all: compile
endif

define Build/DefaultTargets
$(PKG_BUILD_DIR)/.prepared: FORCE $(DL_DIR)/$(PKG_SOURCE)
ifeq ($(shell $(SCRIPT_DIR)/timestamp.pl -p $(PKG_BUILD_DIR) .),.)
	@-rm -rf $(PKG_BUILD_DIR)
	@mkdir -p $(PKG_BUILD_DIR)
	$(call Build/Prepare)
	@touch $$@
endif

$(PKG_BUILD_DIR)/.configured: $(PKG_BUILD_DIR)/.prepared
	$(call Build/Configure)
	touch $$@

$(PKG_BUILD_DIR)/.built: FORCE $(PKG_BUILD_DIR)/.configured
ifeq ($$(shell $(SCRIPT_DIR)/timestamp.pl -p -x ipkg $$(IPKG_$(1)) $(PKG_BUILD_DIR)),$(PKG_BUILD_DIR))
	$(call Build/Compile)
	touch $$@
endif

package-clean: FORCE
	$(call Build/Clean)
	rm -f $(PKG_BUILD_DIR)/.built

define Build/DefaultTargets
endef
endef

define Package/Default
CONFIGFILE:=
SECTION:=opt
CATEGORY:=Extra packages
DEPENDS:=
MAINTAINER:=OpenWrt Developers Team <openwrt-devel@openwrt.org>
SOURCE:=$(patsubst $(TOPDIR)/%,%,${shell pwd})
VERSION:=$(PKG_VERSION)-$(PKG_RELEASE)
PKGARCH:=$(ARCH)
PRIORITY:=optional
DEFAULT:=
MENU:=
TITLE:=
DESCRIPTION:=
endef

define RequiredField
ifeq ($$($(1)),)
$$(error Package/$$(1) is missing the $(1) field)
endif
endef

define BuildPackage
$(eval $(call Package/Default))
$(eval $(call Package/$(1)))

$(foreach FIELD, TITLE CATEGORY PRIORITY VERSION, $(eval $(call RequiredField,$(FIELD))))

ifeq ($(PKGARCH),)
PKGARCH:=$(ARCH)
endif
$(eval 
ifeq ($(DESCRIPTION),)
DESCRIPTION:=$(TITLE)
endif
)

IPKG_$(1):=$(PACKAGE_DIR)/$(1)_$(VERSION)_$(PKGARCH).ipk
IDIR_$(1):=$(PKG_BUILD_DIR)/ipkg/$(1)
INFO_$(1):=$(IPKG_STATE_DIR)/info/$(1).list

ifneq ($(CONFIG_PACKAGE_$(1))$(DEVELOPER),)
COMPILE_$(1):=1
endif

ifeq ($(CONFIG_PACKAGE_$(1)),y)
install-targets: $$(INFO_$(1))
endif

ifneq ($$(COMPILE_$(1)),)
compile-targets: $$(IPKG_$(1))
endif

IDEPEND_$(1):=$$(strip $$(DEPENDS))

DUMPINFO += \
	echo "Package: $(1)"; 
ifneq ($(MENU),)
DUMPINFO += \
	echo "Menu: $(MENU)";
endif
ifneq ($(DEFAULT),)
DUMPINFO += \
	echo "Default: $(DEFAULT)";
endif
DUMPINFO += \
	echo "Version: $(VERSION)"; \
	echo "Depends: $$(IDEPEND_$(1))"; \
	echo "Category: $(CATEGORY)"; \
	echo "Title: $(TITLE)"; \
	echo "Description: $(DESCRIPTION)" | sed -e 's,\\,\n,g';
ifneq ($(URL),)
DUMPINFO += \
	echo; \
	echo "$(URL)";
endif
DUMPINFO += \
	echo "@@";


$$(IDIR_$(1))/CONTROL/control: $(PKG_BUILD_DIR)/.prepared
	mkdir -p $$(IDIR_$(1))/CONTROL
	echo "Package: $(1)" > $$(IDIR_$(1))/CONTROL/control
	echo "Version: $(VERSION)" >> $$(IDIR_$(1))/CONTROL/control
	echo "Depends: $$(IDEPEND_$(1))" >> $$(IDIR_$(1))/CONTROL/control
	echo "Source: $(SOURCE)" >> $$(IDIR_$(1))/CONTROL/control
	echo "Section: $(SECTION)" >> $$(IDIR_$(1))/CONTROL/control
	echo "Priority: $(PRIORITY)" >> $$(IDIR_$(1))/CONTROL/control
	echo "Maintainer: $(MAINTAINER)" >> $$(IDIR_$(1))/CONTROL/control
	echo "Architecture: $(PKGARCH)" >> $$(IDIR_$(1))/CONTROL/control
	echo "Description: $(DESCRIPTION)" | sed -e 's,\\,\n ,g' >> $$(IDIR_$(1))/CONTROL/control
	chmod 644 $$(IDIR_$(1))/CONTROL/control
	for file in conffiles preinst postinst prerm postrm; do \
		[ -f ./ipkg/$(1).$$$$file ] && cp ./ipkg/$(1).$$$$file $$(IDIR_$(1))/CONTROL/$$$$file || true; \
	done

$$(IPKG_$(1)): $$(IDIR_$(1))/CONTROL/control $(PKG_BUILD_DIR)/.built
	$(call Package/$(1)/install,$$(IDIR_$(1)))
	mkdir -p $(PACKAGE_DIR)
	$(RSTRIP) $$(IDIR_$(1))
	$(IPKG_BUILD) $$(IDIR_$(1)) $(PACKAGE_DIR)

$$(INFO_$(1)): $$(IPKG_$(1))
	$(IPKG) install $$(IPKG_$(1))

$(1)-clean:
	rm -f $(PACKAGE_DIR)/$(1)_*
clean: $(1)-clean

ifneq ($(__DEFAULT_TARGETS),1)
$(eval $(call Build/DefaultTargets))
endif

endef

ifneq ($(strip $(PKG_SOURCE)),)
$(DL_DIR)/$(PKG_SOURCE):
	$(SCRIPT_DIR)/download.pl "$(DL_DIR)" "$(PKG_SOURCE)" "$(PKG_MD5SUM)" $(PKG_SOURCE_URL)
endif

ifneq ($(strip $(PKG_CAT)),)
define Build/Prepare/Default
	@if [ "$(PKG_CAT)" = "unzip" ]; then \
		unzip -d $(PKG_BUILD_DIR) $(DL_DIR)/$(PKG_SOURCE) ; \
	else \
		$(PKG_CAT) $(DL_DIR)/$(PKG_SOURCE) | tar -C $(PKG_BUILD_DIR)/.. $(TAR_OPTIONS) - ; \
	fi						  
	@if [ -d ./patches ]; then \
		$(PATCH) $(PKG_BUILD_DIR) ./patches ; \
	fi
endef
endif

define Build/Prepare
$(call Build/Prepare/Default)
endef

define Build/Configure/Default
	@(cd $(PKG_BUILD_DIR); \
	[ -x configure ] && \
		$(TARGET_CONFIGURE_OPTS) \
		CFLAGS="$(TARGET_CFLAGS)" \
		./configure \
		--target=$(GNU_TARGET_NAME) \
		--host=$(GNU_TARGET_NAME) \
		--build=$(GNU_HOST_NAME) \
		--prefix=/usr \
		--exec-prefix=/usr \
		--bindir=/usr/bin \
		--sbindir=/usr/sbin \
		--libexecdir=/usr/lib \
		--sysconfdir=/etc \
		--datadir=/usr/share \
		--localstatedir=/var \
		--mandir=/usr/man \
		--infodir=/usr/info \
		$(DISABLE_NLS) \
		$(1); \
	)
endef

define Build/Configure
$(call Build/Configure/Default,)
endef

define Build/Compile/Default
	$(MAKE) -C $(PKG_BUILD_DIR) \
		CC=$(TARGET_CC) \
		CROSS="$(TARGET_CROSS)" \
		PREFIX="$$(IDIR_$(1))" \
		EXTRA_CFLAGS="$(TARGET_CFLAGS)" \
		ARCH="$(ARCH)" \
		DESTDIR="$$(IDIR_$(1))"
endef

define Build/Compile
$(call Build/Compile/Default)
endef

define Build/Clean
	$(MAKE) clean
endef

ifneq ($(DUMP),)
dumpinfo:
	$(DUMPINFO)
else
		
$(PACKAGE_DIR):
	mkdir -p $@

source: FORCE $(DL_DIR)/$(PKG_SOURCE)
prepare: FORCE $(PKG_BUILD_DIR)/.prepared
configure: FORCE $(PKG_BUILD_DIR)/.configured

compile-targets: FORCE
compile: FORCE compile-targets

install-targets: FORCE
install: FORCE install-targets

clean-targets: FORCE
clean: FORCE
	@$(MAKE) clean-targets
	rm -rf $(PKG_BUILD_DIR)
endif

.PHONY: FORCE
FORCE:
