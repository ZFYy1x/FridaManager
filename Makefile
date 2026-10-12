TARGET := iphone:clang::14.0
INSTALL_TARGET_PROCESSES = Preferences

include $(THEOS)/makefiles/common.mk

SUBPROJECTS = fridamgr fridamgrprefs fridamanagerapp

include $(THEOS_MAKE_PATH)/aggregate.mk
