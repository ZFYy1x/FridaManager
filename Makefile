TARGET := iphone:clang::14.0

include $(THEOS)/makefiles/common.mk

# 只保留守护进程 + 桌面独立 App；设置内入口（fridamgrprefs bundle）不再打包，
# 其源码仍被 fridamanagerapp 复用，故目录保留、仅从构建中移除。
SUBPROJECTS = fridamgr fridamanagerapp

include $(THEOS_MAKE_PATH)/aggregate.mk
