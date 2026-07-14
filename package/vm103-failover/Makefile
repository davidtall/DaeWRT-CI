# SPDX-License-Identifier: MIT

include $(TOPDIR)/rules.mk

PKG_NAME:=vm103-failover
PKG_VERSION:=1.0.0
PKG_RELEASE:=1

PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)

include $(INCLUDE_DIR)/package.mk

define Package/vm103-failover
  SECTION:=net
  CATEGORY:=Network
  TITLE:=RE-CS-07 VM103 failover monitor
  PKGARCH:=all
  DEPENDS:=+gre +ip-full
endef

define Package/vm103-failover/description
  Install the failover monitor verified for the home RE-CS-07 and VM103
  topology. This package is not intended for generic OpenWrt deployments.
endef

define Build/Compile
endef

define Package/vm103-failover/install
	$(INSTALL_DIR) $(1)/usr/sbin
	$(INSTALL_BIN) $(CURDIR)/files/usr/sbin/vm103-failover $(1)/usr/sbin/vm103-failover

	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) $(CURDIR)/files/etc/init.d/vm103-failover $(1)/etc/init.d/vm103-failover
endef

$(eval $(call BuildPackage,vm103-failover))
