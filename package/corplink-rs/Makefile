# SPDX-License-Identifier: GPL-2.0-only

include $(TOPDIR)/rules.mk

PKG_NAME:=corplink-rs
PKG_VERSION:=0.5.5
PKG_RELEASE:=4

PKG_SOURCE_VERSION:=1ef93ae99be88951d9c0e7cc7b7e33b679fd5ed7
PKG_SOURCE:=$(PKG_NAME)-$(PKG_VERSION).tar.gz
PKG_SOURCE_URL:=https://codeload.github.com/PinkD/corplink-rs/tar.gz/$(PKG_SOURCE_VERSION)?
PKG_HASH:=957abafee4904104e27d826bc5e3ffc534850aeee39ddccad46dd89a1aac8265
PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)-$(PKG_SOURCE_VERSION)

PKG_LICENSE:=GPL-2.0-or-later
PKG_LICENSE_FILES:=license.txt
PKG_MAINTAINER:=PinkD <443657547@qq.com>

PKG_BUILD_DEPENDS:=golang/host rust/host openssl
PKG_BUILD_PARALLEL:=1
PKG_BUILD_FLAGS:=no-mips16

# corplink-rs links this fork of wireguard-go as a CGO static archive.
WG_GO_VERSION:=491cec86522a313d90c88d68865d99bcde780e80
WG_GO_SOURCE:=wireguard-go-$(WG_GO_VERSION).tar.gz
WG_GO_HASH:=c5f3e4766d56e1f49f4b5fa07ec9ef3e85e3a0ce7b38797b0ad4bab033dd8b22

GO_PKG:=github.com/PinkD/wireguard-go

include $(INCLUDE_DIR)/package.mk
include $(TOPDIR)/feeds/packages/lang/golang/golang-package.mk
include $(TOPDIR)/feeds/packages/lang/rust/rust-package.mk

define Download/wireguard-go
  URL:=https://codeload.github.com/PinkD/wireguard-go/tar.gz/$(WG_GO_VERSION)?
  FILE:=$(WG_GO_SOURCE)
  HASH:=$(WG_GO_HASH)
endef
$(eval $(call Download,wireguard-go))

define Package/corplink-rs
  SECTION:=net
  CATEGORY:=Network
  SUBMENU:=VPN
  TITLE:=Rust client for Volcengine Corplink VPN
  URL:=https://github.com/PinkD/corplink-rs
  DEPENDS:=$(RUST_ARCH_DEPENDS) $(GO_ARCH_DEPENDS) +ca-bundle +kmod-tun +libopenssl
endef

define Package/corplink-rs/description
  A Rust implementation of the Volcengine Corplink client. It embeds the
  project's modified wireguard-go implementation and can create a TUN device
  or expose the VPN through a SOCKS5 proxy.
endef

define Package/corplink-rs/conffiles
/etc/corplink/config.json
endef

define Build/Prepare
	$(call Build/Prepare/Default)
	$(INSTALL_DIR) $(PKG_BUILD_DIR)/libwg/wireguard-go
	$(TAR) -C $(PKG_BUILD_DIR)/libwg/wireguard-go --strip-components=1 -xzf $(DL_DIR)/$(WG_GO_SOURCE)
endef

define Build/Compile
# The source is downloaded as a tarball, so wireguard-go cannot derive this from Git.
	( \
		cd $(PKG_BUILD_DIR)/libwg/wireguard-go ; \
		printf 'package main\n\nconst Version = "%s"\n' "$(WG_GO_VERSION)" > version.go ; \
		$(GO_GENERAL_BUILD_CONFIG_VARS) \
		$(GO_PKG_BUILD_CONFIG_VARS) \
		$(GO_PKG_TARGET_VARS) \
		$(GO_PKG_BUILD_VARS) \
		$(MAKE) libwg && \
		mv libwg.a libwg.h .. ; \
	)
	# Some SDKs do not stage openssl.pc; point openssl-sys at the target SDK instead.
	OPENSSL_DIR="$(STAGING_DIR)/usr" \
	OPENSSL_LIB_DIR="$(STAGING_DIR)/usr/lib" \
	OPENSSL_INCLUDE_DIR="$(STAGING_DIR)/usr/include" \
	$(call Build/Compile/Cargo)
endef

define Package/corplink-rs/install
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) $(PKG_INSTALL_DIR)/bin/corplink-rs $(1)/usr/bin/

	$(INSTALL_DIR) $(1)/etc/corplink
	$(INSTALL_CONF) $(CURDIR)/files/config.json $(1)/etc/corplink/config.json
endef

$(eval $(call BuildPackage,corplink-rs))
