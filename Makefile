ARCHS = arm64 arm64e
TARGET := iphone:clang:latest:16.0
THEOS_PACKAGE_SCHEME = roothide
FINALPACKAGE = 1
DEBUG = 0

ifeq ($(strip $(THEOS)),)
$(error Set THEOS to your local roothide/theos installation)
endif

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = WXMinimal
WXMinimal_FILES = Tweak.x
WXMinimal_CFLAGS = -fobjc-arc -Wall -Wextra -Wno-unused-parameter -Wno-arc-performSelector-leaks
WXMinimal_FRAMEWORKS = Foundation UIKit

include $(THEOS_MAKE_PATH)/tweak.mk
