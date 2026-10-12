TARGET := iphone:clang::14.0
INSTALL_TARGET_PROCESSES = Preferences

include $(THEOS)/makefiles/common.mk

SUBPROJECTS = fridamgr fridamgrprefs fridamanagerapp

include $(THEOS_MAKE_PATH)/aggregate.mk

# roothide reuses the /var/jb layout (rootless-compatible), so the daemon path
# fix applies to both schemes.
after-stage::
ifneq (,$(filter $(THEOS_PACKAGE_SCHEME),rootless roothide))
	@plutil -replace ProgramArguments -json '["/var/jb/usr/local/bin/fridamgr"]' $(THEOS_STAGING_DIR)/Library/LaunchDaemons/com.b1tbreaker.fridamanager.plist
endif
