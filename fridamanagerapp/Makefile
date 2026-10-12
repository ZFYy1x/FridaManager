include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = FridaManager

# Reuse the existing PreferenceLoader UI code (PSListController based) so the
# standalone app and the Settings pane stay in sync.
FridaManager_FILES = main.m \
	../fridamgrprefs/FMRootListController.m \
	../fridamgrprefs/FMSocketClient.m

FridaManager_CFLAGS = -fobjc-arc -I../fridamgr -I../fridamgrprefs \
	-fno-ptrauth-objc-class-ro -fno-ptrauth-objc-interface-sel

FridaManager_FRAMEWORKS = UIKit Foundation
FridaManager_PRIVATE_FRAMEWORKS = Preferences
FridaManager_LDFLAGS = -lroot
FridaManager_RESOURCES = icon.png icon@2x.png icon@3x.png
FridaManager_CODESIGN_FLAGS = -Sentitlements.plist
FridaManager_INSTALL_PATH = /Applications

include $(THEOS_MAKE_PATH)/application.mk
