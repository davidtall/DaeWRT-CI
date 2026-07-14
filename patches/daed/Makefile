# SPDX-License-Identifier: GPL-2.0-only
#
# Copyright (C) 2023 ImmortalWrt.org

include $(TOPDIR)/rules.mk

PKG_NAME:=daed
PKG_VERSION:=2026.05.03
DAED_VERSION:=daed-4cab3b7
WING_VERSION:=wing-dc50308
CORE_VERSION:=core-80e4416
WING_HASH_SHORT:=$(shell echo $(WING_VERSION) | cut -d- -f2)
CORE_HASH_SHORT:=$(shell echo $(CORE_VERSION) | cut -d- -f2)
PKG_RELEASE:=1

PKG_SOURCE:=$(PKG_NAME)-$(PKG_VERSION).tar.gz
PKG_SOURCE_PROTO:=git
PKG_SOURCE_VERSION:=4cab3b77373f450c1617eb392a2f59dd3872ea3f
PKG_SOURCE_URL:=https://github.com/daeuniverse/daed.git
PKG_MIRROR_HASH:=skip

PKG_LICENSE:=AGPL-3.0-only MIT
PKG_LICENSE_FILES:=LICENSE wing/LICENSE
PKG_MAINTAINER:=Tianling Shen <cnsztl@immortalwrt.org>

DAED_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)-$(PKG_VERSION)
PKG_BUILD_DIR:=$(DAED_BUILD_DIR)/wing

PKG_BUILD_DEPENDS:=golang/host bpf-headers
PKG_BUILD_PARALLEL:=1
PKG_BUILD_FLAGS:=no-mips16

GO_PKG:=github.com/daeuniverse/dae-wing

GO_PKG_LDFLAGS:= \
	-s -w -buildid= \
	-linkmode external -extldflags '-static -Wl,-s' \
	-X '$(GO_PKG)/db.AppDescription=$(PKG_NAME) is a integration solution of dae, API and UI.'
GO_PKG_LDFLAGS_X:= \
	$(GO_PKG)/db.AppName=$(PKG_NAME) \
	$(GO_PKG)/db.AppVersion=$(DAED_VERSION)_$(WING_VERSION)_$(CORE_VERSION)
GO_PKG_TAGS:=embedallowed,trace

include $(INCLUDE_DIR)/package.mk
include $(INCLUDE_DIR)/bpf.mk
include $(TOPDIR)/feeds/packages/lang/golang/golang-package.mk

GO_PKG_BUILD_VARS+= \
	GOFLAGS="-trimpath -buildvcs=false -pgo=auto"

GO_PKG_TARGET_VARS+= \
	CGO_LDFLAGS="$(TARGET_LDFLAGS) -static -Wl,-s" \
	GOEXPERIMENT=newinliner,simd

define Package/daed/Default
  SECTION:=net
  CATEGORY:=Network
  SUBMENU:=Web Servers/Proxies
  URL:=https://github.com/daeuniverse/daed
endef

define Package/daed
  $(call Package/daed/Default)
  TITLE:=A Modern Dashboard For dae
  DEPENDS:=$(GO_ARCH_DEPENDS) \
    +ca-bundle +kmod-sched-core +kmod-sched-bpf \
    +kmod-veth +v2ray-geoip +v2ray-geosite \
    +@KERNEL_XDP_SOCKETS \
    +DAED_USE_VMLINUX_BTF:vmlinux-btf
endef

define Package/daed/config
	choice
		prompt "BTF source for CO-RE"
		default DAED_USE_KERNEL_BTF
		depends on PACKAGE_daed

	config DAED_USE_KERNEL_BTF
		bool "Use kernel BTF (integrated)"
		depends on KERNEL_DEBUG_INFO_BTF

	config DAED_USE_VMLINUX_BTF
		bool "Use vmlinux-btf package"
	endchoice
endef

define Package/daed/description
  daed is a backend of dae, provides a method to bundle arbitrary
  frontend, dae and geodata into one binary.
endef

define Package/daed/conffiles
/etc/daed/wing.db
/etc/config/daed
endef

NODE_VERSION:=v24.12.0
NODE_DIST:=node-$(NODE_VERSION)-linux-x64
NODE_URL:=https://nodejs.org/dist/$(NODE_VERSION)/$(NODE_DIST).tar.xz
DAED_HOST_GO=$(firstword $(wildcard $(STAGING_DIR_HOSTPKG)/lib/go-*/bin/go $(STAGING_DIR_HOSTPKG)/bin/go))

define Build/Prepare
	( \
		set -e ; \
		rm -rf $(DAED_BUILD_DIR) ; \
		mkdir -p $(DAED_BUILD_DIR) ; \
		$(TAR) --strip-components=1 -C $(DAED_BUILD_DIR) -xzf $(DL_DIR)/$(PKG_NAME)-$(PKG_VERSION).tar.gz ; \
		rm -rf $(PKG_BUILD_DIR) ; \
		git clone https://github.com/daeuniverse/dae-wing $(PKG_BUILD_DIR) && \
			git -C $(PKG_BUILD_DIR) checkout $(WING_HASH_SHORT) ; \
		rm -rf $(PKG_BUILD_DIR)/dae-core ; \
		git clone https://github.com/olicesx/dae $(PKG_BUILD_DIR)/dae-core && \
			git -C $(PKG_BUILD_DIR)/dae-core checkout $(CORE_HASH_SHORT) ; \
		rm -rf $(DAED_BUILD_DIR)/outbound ; \
		git clone --depth=1 -b perf/complete-optimizations https://github.com/olicesx/outbound.git $(DAED_BUILD_DIR)/outbound ; \
		rm -rf $(DAED_BUILD_DIR)/quic-go ; \
		git clone --depth=1 -b perf/node-pooling-v2 https://github.com/olicesx/quic-go.git $(DAED_BUILD_DIR)/quic-go ; \
		pushd $(PKG_BUILD_DIR)/dae-core ; \
			if ! grep -q "currentRuntimeStatsStore" control/runtime_stats.go ; then \
				wget -qO - https://github.com/QiuSimons/luci-app-daed/raw/refs/heads/kix/patchset/0001-fix-runtime-stats.patch | patch -p2 --forward --batch ; \
			fi ; \
			git submodule update --init ; \
		popd ; \
		pushd $(PKG_BUILD_DIR) ; \
			wget -qO default.pgo "https://github.com/QiuSimons/luci-app-dae/raw/refs/heads/kix/dae/pprof/default.pgo" ; \
		popd ; \
		mkdir -p $(DAED_BUILD_DIR)/.node_tmp/config ; \
		wget -qO - "$(NODE_URL)" | tar -xJ -C $(DAED_BUILD_DIR)/.node_tmp --strip-components=1 ; \
		export PATH="$(DAED_BUILD_DIR)/.node_tmp/bin:$$$$PATH" ; \
		export XDG_CONFIG_HOME="$(DAED_BUILD_DIR)/.node_tmp/config" ; \
		export HUSKY=0 ; \
		npm install -g pnpm ; \
		pushd $(DAED_BUILD_DIR) ; \
			pnpm install --no-frozen-lockfile ; \
			pnpm --filter daed... build ; \
		popd ; \
		if [ ! -d "$(DAED_BUILD_DIR)/apps/web/dist" ]; then \
			echo "ERROR: daed web dist directory is missing at $(DAED_BUILD_DIR)/apps/web/dist" ; \
			exit 1 ; \
		fi ; \
		find "$(DAED_BUILD_DIR)/apps/web/dist" -type f -print > "$(DAED_BUILD_DIR)/.web-dist-files" ; \
		if [ ! -s "$(DAED_BUILD_DIR)/.web-dist-files" ]; then \
			echo "ERROR: daed web build completed without dist files at $(DAED_BUILD_DIR)/apps/web/dist" ; \
			find "$(DAED_BUILD_DIR)" -path "*/apps/web/dist/*" -type f -print > "$(DAED_BUILD_DIR)/.web-dist-diagnostics" ; \
			sed -n '1,20p' "$(DAED_BUILD_DIR)/.web-dist-diagnostics" ; \
			exit 1 ; \
		fi ; \
		rm -rf $(PKG_BUILD_DIR)/webrender/web ; \
		mkdir -p $(PKG_BUILD_DIR)/webrender/web ; \
		cp -a $(DAED_BUILD_DIR)/apps/web/dist/. $(PKG_BUILD_DIR)/webrender/web/ ; \
		find $(PKG_BUILD_DIR)/webrender/web -type f -print > "$(DAED_BUILD_DIR)/.webrender-files" ; \
		test -s "$(DAED_BUILD_DIR)/.webrender-files" || { echo "ERROR: daed web assets were not generated"; exit 1; } ; \
		find $(PKG_BUILD_DIR)/webrender/web -name "*.map" -type f -delete ; \
		find $(PKG_BUILD_DIR)/webrender/web -type f -size +4k ! -name "*.gz" ! -name "*.woff"  ! -name "*.woff2" -exec sh -c '\
			gzip -9 -k "{}"; \
			if [ "$$$$(stat -c %s {})" -lt "$$$$(stat -c %s {}.gz)" ]; then \
				rm {}.gz; \
			else \
				rm {}; \
			fi' \
		";" ; \
		rm -rf $(DAED_BUILD_DIR)/.node_tmp ; \
	)
endef

DAE_CFLAGS:= \
	-O2 -Wall -Werror \
	-DMAX_MATCH_SET_LEN=1024 \
	-I$(BPF_HEADERS_DIR)/tools/lib \
	-I$(BPF_HEADERS_DIR)/arch/$(BPF_KARCH)/include/asm/mach-generic

define Build/Compile
	( \
		export \
		$(GO_GENERAL_BUILD_CONFIG_VARS) \
		$(GO_PKG_BUILD_CONFIG_VARS) \
		$(GO_PKG_BUILD_VARS) ; \
		pushd $(PKG_BUILD_DIR) ; \
			pushd $(PKG_BUILD_DIR)/dae-core ; \
				$(DAED_HOST_GO) get -u=patch ; \
				$(DAED_HOST_GO) mod tidy ; \
			popd ; \
			$(DAED_HOST_GO) mod edit -replace github.com/daeuniverse/outbound=../outbound ; \
			$(DAED_HOST_GO) mod edit -replace github.com/olicesx/quic-go=../quic-go ; \
			$(DAED_HOST_GO) get -u=patch ; \
			$(DAED_HOST_GO) mod tidy ; \
			$(DAED_HOST_GO) generate ./... ; \
			cd dae-core ; \
			export \
			BPF_CLANG="$(CLANG)" \
			BPF_STRIP_FLAG="-strip=$(LLVM_STRIP)" \
			BPF_CFLAGS="$(DAE_CFLAGS)" \
			BPF_TARGET="bpfel,bpfeb" \
			BPF_TRACE_TARGET="$(GO_ARCH)" ; \
			$(DAED_HOST_GO) generate ./control/control.go ; \
			$(DAED_HOST_GO) generate ./trace/trace.go ; \
		popd ; \
		$(call GoPackage/Build/Compile) ; \
	)
endef

define Package/daed/install
	$(call GoPackage/Package/Install/Bin,$(PKG_INSTALL_DIR))
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) $(PKG_INSTALL_DIR)/usr/bin/dae-wing $(1)/usr/bin/daed

	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_CONF) $(CURDIR)/files/daed.config $(1)/etc/config/daed

	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) $(CURDIR)/files/daed.init $(1)/etc/init.d/daed
endef

$(eval $(call GoBinPackage,daed))
$(eval $(call BuildPackage,daed))
