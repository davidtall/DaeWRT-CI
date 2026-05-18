# SPDX-License-Identifier: GPL-2.0-only

include $(TOPDIR)/rules.mk

PKG_NAME:=wg-endpoint-watchdog
PKG_VERSION:=1.0.0
PKG_RELEASE:=1

PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)

include $(INCLUDE_DIR)/package.mk

define Package/wg-endpoint-watchdog
  SECTION:=net
  CATEGORY:=Network
  SUBMENU:=VPN
  TITLE:=WireGuard endpoint refresh watchdog
  PKGARCH:=all
  DEPENDS:=+wireguard-tools
endef

define Package/wg-endpoint-watchdog/description
  Refresh WireGuard interfaces when endpoint DNS changes, latest handshakes
  become stale, or WAN links come back online. Instances are disabled by
  default and must be explicitly configured through UCI after flashing.
endef

define Package/wg-endpoint-watchdog/conffiles
/etc/config/wg_endpoint_watchdog
endef

define Build/Compile
endef

define Package/wg-endpoint-watchdog/install
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_CONF) $(CURDIR)/files/etc/config/wg_endpoint_watchdog $(1)/etc/config/wg_endpoint_watchdog

	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) $(CURDIR)/files/etc/init.d/wg-endpoint-watchdog $(1)/etc/init.d/wg-endpoint-watchdog

	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) $(CURDIR)/files/usr/bin/wg-endpoint-refresh $(1)/usr/bin/wg-endpoint-refresh
	$(INSTALL_BIN) $(CURDIR)/files/usr/bin/wg-endpoint-watchdog $(1)/usr/bin/wg-endpoint-watchdog

	$(INSTALL_DIR) $(1)/etc/hotplug.d/iface
	$(INSTALL_BIN) $(CURDIR)/files/etc/hotplug.d/iface/99-wg-endpoint-watchdog $(1)/etc/hotplug.d/iface/99-wg-endpoint-watchdog
endef

$(eval $(call BuildPackage,wg-endpoint-watchdog))
