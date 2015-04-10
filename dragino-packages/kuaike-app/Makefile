include $(TOPDIR)/rules.mk

PKG_NAME:=kuaike_app
PKG_VERSION:=2.1.5

PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)-$(PKG_VERSION)

include $(INCLUDE_DIR)/package.mk

define Package/$(PKG_NAME)    
	SECTION:=utils
	CATEGORY:=Utilities
	TITLE:=$(PKG_NAME)
	MAINTAINER:=<support@dragino.com>
endef

define Package/$(PKG_NAME)/description
	Package for FoxConn KuaiKe project
endef

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)
	mkdir -p $(PKG_BUILD_DIR)/bin/
	mkdir -p $(PKG_BUILD_DIR)/kuaike/
	$(CP) ./files/* $(PKG_BUILD_DIR)/
endef

define Build/Compile
endef

define Package/$(PKG_NAME)/install
	$(INSTALL_DIR) $(1)/bin
	$(INSTALL_DIR) $(1)/kuaike/	
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/bin/* $(1)/bin/
	$(CP) $(PKG_BUILD_DIR)/kuaike/* $(1)/kuaike/
endef

$(eval $(call BuildPackage,$(PKG_NAME)))