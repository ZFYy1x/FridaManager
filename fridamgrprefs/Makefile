include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = FridaManagerPrefs

FridaManagerPrefs_FILES = FMRootListController.m FMSocketClient.m
FridaManagerPrefs_CFLAGS = -fobjc-arc -I../fridamgr
FridaManagerPrefs_FRAMEWORKS = UIKit
FridaManagerPrefs_PRIVATE_FRAMEWORKS = Preferences
FridaManagerPrefs_LDFLAGS = -lroot
FridaManagerPrefs_INSTALL_PATH = /Library/PreferenceBundles

include $(THEOS_MAKE_PATH)/bundle.mk
