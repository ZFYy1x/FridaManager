TARGET := iphone:clang:15.6:14.0
INSTALL_TARGET_PROCESSES = Preferences

include $(THEOS)/makefiles/common.mk

SUBPROJECTS = fridamgr fridamgrprefs

include $(THEOS_MAKE_PATH)/aggregate.mk

after-stage::
ifeq ($(THEOS_PACKAGE_SCHEME),rootless)
	@plutil -replace ProgramArguments -json '["/var/jb/usr/local/bin/fridamgr"]' $(THEOS_STAGING_DIR)/Library/LaunchDaemons/com.b1tbreaker.fridamanager.plist
endif
