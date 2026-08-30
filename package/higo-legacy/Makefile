include $(TOPDIR)/rules.mk

PKG_NAME:=higo-legacy
PKG_VERSION:=1.26.04.29.09
PKG_RELEASE:=1
PKGARCH:=aarch64_cortex-a53

include $(INCLUDE_DIR)/package.mk

define Package/higo-legacy
  SECTION:=admin
  CATEGORY:=Administration
  TITLE:=Private legacy Higo management interface
  DEPENDS:=+libc +ethtool +nmap +lsblk
endef

define Package/higo-legacy/description
 Private compatibility package for a user-owned Hiveton H5000M firmware.
 The payload is intentionally absent from the public source tree.
endef

define Build/Compile
endef

define Package/higo-legacy/install
	@test -x ./files/usr/sbin/higorosd || \
		{ echo "private Higo payload is not staged" >&2; exit 1; }
	$(CP) ./files/* $(1)/
endef

$(eval $(call BuildPackage,higo-legacy))
