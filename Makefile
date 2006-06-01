# Makefile for OpenWrt
#
# Copyright (C) 2006 by Felix Fietkau <openwrt@nbd.name>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA
#

RELEASE:=Kamikaze
#VERSION:=2.0 # uncomment for final release

#--------------------------------------------------------------
# Just run 'make menuconfig', configure stuff, then run 'make'.
# You shouldn't need to mess with anything beyond this point...
#--------------------------------------------------------------
TOPDIR=${shell pwd}
export TOPDIR

OPENWRTVERSION:=$(RELEASE)
ifneq ($(VERSION),)
OPENWRTVERSION:=$(VERSION) ($(OPENWRTVERSION))
else
REV:=$(shell LANG=C svn info | awk '/^Revision:/ { print$$2 }' )
ifneq ($(REV),)
OPENWRTVERSION:=$(OPENWRTVERSION)/r$(REV)
endif
endif
export OPENWRTVERSION

all: world

.pkginfo: FORCE
ifneq ($(shell ./scripts/timestamp.pl -p .pkginfo package Makefile),.pkginfo)
	@echo Collecting package info...
	@-for dir in package/*/; do \
		echo Source-Makefile: $${dir}Makefile; \
		$(MAKE) --no-print-dir DUMP=1 -C $$dir 2>&- || true; \
	done > $@
endif

.config.in: .pkginfo
	./scripts/gen_menuconfig.pl < $< > $@ || rm -f $@

pkginfo-clean: FORCE
	-rm -f .pkginfo .config.in

scripts/config/mconf: .config.in
	$(MAKE) -C scripts/config all

scripts/config/conf: .config.in
	$(MAKE) -C scripts/config conf

config: scripts/config/conf FORCE
	$< Config.in

defdconfig: scripts/config/conf FORCE
	$< -d Config.in

oldconfig: scripts/config/conf FORCE
	$< -o Config.in

menuconfig: scripts/config/mconf FORCE
	$< Config.in

config-clean: FORCE
	$(MAKE) -C scripts/config clean

package/%: .pkginfo FORCE
	$(MAKE) -C package $(patsubst package/%,%,$@)

target/%: .pkginfo FORCE
	$(MAKE) -C target $(patsubst target/%,%,$@)

toolchain/%: FORCE
	$(MAKE) -C toolchain $(patsubst toolchain/%,%,$@)

world: FORCE
	$(MAKE) toolchain/install
	$(MAKE) target/compile
	$(MAKE) package/compile
	$(MAKE) package/install
	$(MAKE) target/install

clean: FORCE
	rm -rf build_* bin

dirclean: clean FORCE
	rm -rf staging_dir_* toolchain_build_*

distclean: dirclean FORCE
	rm -rf .* dl

.PHONY: FORCE
FORCE:
