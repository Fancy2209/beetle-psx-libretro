DEBUG = 0
FRONTEND_SUPPORTS_RGB565 = 1
HAVE_OPENGL = 0
GLES = 0
GLES3 = 0 # HW renderer now supported on GLES3
HAVE_VULKAN = 0
HAVE_JIT = 0
HAVE_CHD = 1
HAVE_CDROM = 0
HAVE_LIGHTREC = 1
LINK_STATIC_LIBCPLUSPLUS = 1
THREADED_RECOMPILER = 1
LIGHTREC_DEBUG = 0
LIGHTREC_LOG_LEVEL = 3

CORE_DIR := .
HAVE_GRIFFIN = 0

SPACE :=
SPACE := $(SPACE) $(SPACE)
BACKSLASH :=
BACKSLASH := \$(BACKSLASH)
filter_out1 = $(filter-out $(firstword $1),$1)
filter_out2 = $(call filter_out1,$(call filter_out1,$1))

GIT_VERSION ?= " $(shell git rev-parse --short HEAD || echo unknown)"
ifneq ($(GIT_VERSION)," unknown")
   FLAGS += -DGIT_VERSION=\"$(GIT_VERSION)\"
endif

ifeq ($(platform),)
   platform = unix
   ifeq ($(shell uname -s),)
      platform = win
   else ifneq ($(findstring Darwin,$(shell uname -s)),)
      platform = osx
      arch     = intel
      ifeq ($(shell uname -p),powerpc)
         arch = ppc
      endif
   else ifneq ($(findstring MINGW,$(shell uname -s)),)
      platform = win
   endif
else ifneq (,$(findstring armv,$(platform)))
   override platform += unix
endif

ifneq ($(platform), osx)
   ifeq ($(findstring Haiku,$(shell uname -s)),)
      PTHREAD_FLAGS = -lpthread
   endif
endif

NEED_CD = 1
NEED_TREMOR = 1
NEED_BPP = 32
NEED_DEINTERLACER = 1
NEED_THREADING = 1
SET_HAVE_HW = 0
CORE_DEFINE := -DWANT_PSX_EMU
TARGET_NAME := mednafen_psx

ifeq ($(HAVE_HW), 1)
   HAVE_VULKAN = 1
   HAVE_OPENGL = 1
   SET_HAVE_HW = 1
endif

ifeq ($(HAVE_VULKAN), 1)
   SET_HAVE_HW = 1
endif

ifeq ($(HAVE_OPENGL), 1)
   SET_HAVE_HW = 1
endif

ifeq ($(SET_HAVE_HW), 1)
   FLAGS += -DHAVE_HW
   TARGET_NAME := mednafen_psx_hw
endif

ifneq ($(LIGHTREC_DEBUG), 0)
   DEBUG = 1
   FLAGS += -DLIGHTREC_DEBUG
   ifeq ($(LIGHTREC_DEBUG), 2)
      FLAGS += -DLIGHTREC_VERY_DEBUG
   endif
endif

# Unix
ifneq (,$(findstring unix,$(platform)))
   TARGET := $(TARGET_NAME)_libretro.so
   fpic   := -fPIC
   ifneq ($(findstring SunOS,$(shell uname -a)),)
      GREP = ggrep
      SHARED := -shared -z defs
   else
      GREP = grep
      SHARED := -shared -Wl,--no-undefined -Wl,--version-script=link.T
   endif
   ifeq ($(LINK_STATIC_LIBCPLUSPLUS),1)
      LDFLAGS += -static-libgcc -static-libstdc++
   endif
   ifneq ($(shell uname -p | $(GREP) -E '((i.|x)86|amd64)'),)
      IS_X86 = 1
   endif
   ifneq (,$(findstring Haiku,$(shell uname -s)))
      LDFLAGS += $(PTHREAD_FLAGS) -lroot
   else
      LDFLAGS += $(PTHREAD_FLAGS) -ldl
      ifeq ($(HAVE_LIGHTREC), 1)
         LDFLAGS += -lrt
         FLAGS += -DHAVE_SHM
      endif
   endif
   FLAGS   +=
   ifeq ($(HAVE_OPENGL),1)
      ifneq (,$(findstring gles,$(platform)))
         GLES = 1
         GL_LIB := -lGLESv2
      else
         GL_LIB := -lGL
      endif
   endif

ifneq ($(findstring Linux,$(shell uname -s)),)
   HAVE_CDROM = 1
endif

# OS X
else ifeq ($(platform), osx)
   TARGET  := $(TARGET_NAME)_libretro.dylib
   fpic    := -fPIC
   SHARED  := -dynamiclib -Wl,-exported_symbols_list,libretro.osx.def
   LDFLAGS += $(PTHREAD_FLAGS)
   FLAGS   += $(PTHREAD_FLAGS)
   ifeq ($(arch),ppc)
      ENDIANNESS_DEFINES := -DMSB_FIRST
      OLD_GCC := 1
   endif
   OSXVER = `sw_vers -productVersion | cut -d. -f 2`
   OSX_LT_MAVERICKS = `(( $(OSXVER) <= 9)) && echo "YES"`
   ifeq ($(OSX_LT_MAVERICKS),"YES")
      fpic += -mmacosx-version-min=10.5
   endif
   ifeq ($(HAVE_LIGHTREC), 1)
      LDFLAGS += -lSystem
      FLAGS += -DHAVE_SHM -DUSE_FIXED
   endif
   ifeq ($(HAVE_OPENGL),1)
      GL_LIB := -framework OpenGL
   endif
   ifeq ($(CROSS_COMPILE),1)
	TARGET_RULE   = -target $(LIBRETRO_APPLE_PLATFORM) -isysroot $(LIBRETRO_APPLE_ISYSROOT)
	CFLAGS   += $(TARGET_RULE)
	CPPFLAGS += $(TARGET_RULE)
	CXXFLAGS += $(TARGET_RULE)
	LDFLAGS  += $(TARGET_RULE)
   endif

# iOS
else ifneq (,$(findstring ios,$(platform)))
   ifeq ($(platform),$(filter $(platform),ios-arm64))
   iarch := arm64
   else
   iarch := armv7
   endif
   TARGET  := $(TARGET_NAME)_libretro_ios.dylib
   fpic    := -fPIC
   SHARED  := -dynamiclib
   LDFLAGS += $(PTHREAD_FLAGS)
   FLAGS   += $(PTHREAD_FLAGS)
   ifeq ($(IOSSDK),)
      IOSSDK := $(shell xcrun -sdk iphoneos -show-sdk-path)
   endif
   ifeq ($(HAVE_OPENGL),1)
      GL_LIB := -framework OpenGLES
      GLES = 1
      GLES3 = 1
   endif

   CC = cc -arch $(iarch) -isysroot $(IOSSDK)
   CXX = c++ -arch $(iarch) -isysroot $(IOSSDK)
   IPHONEMINVER :=
   ifeq ($(platform),$(filter $(platform),ios9 ios-arm64))
      IPHONEMINVER = -miphoneos-version-min=8.0
   else
      IPHONEMINVER = -miphoneos-version-min=5.0
   endif
   HAVE_LIGHTREC = 0
   LDFLAGS += $(IPHONEMINVER)
   FLAGS   += $(IPHONEMINVER) -DHAVE_UNISTD_H -DIOS=1
   CC      += $(IPHONEMINVER)
   CXX     += $(IPHONEMINVER)

# tvOS
else ifeq ($(platform), tvos-arm64)
   TARGET := $(TARGET_NAME)_libretro_tvos.dylib
   fpic := -fPIC
   SHARED := -dynamiclib
   HAVE_LIGHTREC = 0
   FLAGS += -DHAVE_UNISTD_H -DIOS=1 -DTVOS=1

   ifeq ($(IOSSDK),)
      IOSSDK := $(shell xcrun -sdk appletvos -show-sdk-path)
   endif
   ifeq ($(HAVE_OPENGL),1)
      GL_LIB := -framework OpenGLES
      GLES = 1
      GLES3 = 1
   endif

   CC = cc -arch arm64 -isysroot $(IOSSDK)
   CXX = c++ -arch arm64 -isysroot $(IOSSDK)
   MINVER = -mappletvos-version-min=11.0
   LDFLAGS += $(MINVER)
   FLAGS += $(MINVER)
   CC += $(MINVER)
   CXX += $(MINVER)

# QNX
else ifeq ($(platform), qnx)
   TARGET := $(TARGET_NAME)_libretro_$(platform).so
   fpic   := -fPIC
   SHARED := -lcpp -lm -shared -Wl,--no-undefined -Wl,--version-script=link.T
   #LDFLAGS += $(PTHREAD_FLAGS)
   CC     = qcc -Vgcc_ntoarmv7le
   CXX    = QCC -Vgcc_ntoarmv7le_cpp
   AR     = QCC -Vgcc_ntoarmv7le
   FLAGS += -D__BLACKBERRY_QNX__ -marm -mcpu=cortex-a9 -mfpu=neon -mfloat-abi=softfp
   ifeq ($(HAVE_OPENGL),1)
      GL_LIB := -lGLESv2
   endif

# PS3
else ifeq ($(platform), ps3)
   TARGET := $(TARGET_NAME)_libretro_$(platform).a
   CC      = $(CELL_SDK)/host-win32/ppu/bin/ppu-lv2-gcc.exe
   CXX     = $(CELL_SDK)/host-win32/ppu/bin/ppu-lv2-g++.exe
   AR      = $(CELL_SDK)/host-win32/ppu/bin/ppu-lv2-ar.exe
   ENDIANNESS_DEFINES := -DMSB_FIRST
   OLD_GCC := 1
   FLAGS += -DARCH_POWERPC_ALTIVEC
   STATIC_LINKING = 1

# sncps3
else ifeq ($(platform), sncps3)
   TARGET := $(TARGET_NAME)_libretro_ps3.a
   CC      = $(CELL_SDK)/host-win32/sn/bin/ps3ppusnc.exe
   CXX     = $(CELL_SDK)/host-win32/sn/bin/ps3ppusnc.exe
   AR      = $(CELL_SDK)/host-win32/sn/bin/ps3snarl.exe
   ENDIANNESS_DEFINES := -DMSB_FIRST
   CXXFLAGS += -Xc+=exceptions
   OLD_GCC  := 1
   NO_GCC   := 1
   FLAGS    += -DARCH_POWERPC_ALTIVEC
   STATIC_LINKING = 1

# Lightweight PS3 Homebrew SDK
else ifeq ($(platform), psl1ght)
   HAVE_LIGHTREC = 0
   TARGET := $(TARGET_NAME)_libretro_$(platform).a
   CC      = $(PS3DEV)/ppu/bin/ppu-gcc$(EXE_EXT)
   CXX     = $(PS3DEV)/ppu/bin/ppu-g++$(EXE_EXT)
   AR      = $(PS3DEV)/ppu/bin/ppu-ar$(EXE_EXT)
   ENDIANNESS_DEFINES := -DMSB_FIRST
   FLAGS += -DARCH_POWERPC_ALTIVEC
   STATIC_LINKING = 1

# PSP
else ifeq ($(platform), psp1)
   TARGET := $(TARGET_NAME)_libretro_$(platform).a
   CC      = psp-gcc$(EXE_EXT)
   CXX     = psp-g++$(EXE_EXT)
   AR      = psp-ar$(EXE_EXT)
   FLAGS  += -DPSP -G0
   STATIC_LINKING = 1
   EXTRA_INCLUDES := -I$(shell psp-config --pspsdk-path)/include

# Vita
else ifeq ($(platform), vita)
   TARGET := $(TARGET_NAME)_libretro_$(platform).a
   CC      = arm-vita-eabi-gcc$(EXE_EXT)
   CXX     = arm-vita-eabi-g++$(EXE_EXT)
   AR      = arm-vita-eabi-ar$(EXE_EXT)
   FLAGS  += -DVITA
   STATIC_LINKING = 1

# Xbox 360
else ifeq ($(platform), xenon)
   TARGET := $(TARGET_NAME)_libretro_xenon360.a
   CC      = xenon-gcc$(EXE_EXT)
   CXX     = xenon-g++$(EXE_EXT)
   AR      = xenon-ar$(EXE_EXT)
   ENDIANNESS_DEFINES += -D__LIBXENON__ -m32 -D__ppc__ -DMSB_FIRST
   LIBS := $(PTHREAD_FLAGS)
   STATIC_LINKING = 1

# Nintendo Game Cube / Nintendo Wii
else ifneq (,$(filter $(platform),ngc wii))
   ifeq ($(platform), ngc)
      TARGET := $(TARGET_NAME)_libretro_$(platform).a
      ENDIANNESS_DEFINES += -DHW_DOL
   else ifeq ($(platform), wii)
      TARGET := $(TARGET_NAME)_libretro_$(platform).a
      ENDIANNESS_DEFINES += -DHW_RVL
   endif
   ENDIANNESS_DEFINES += -DGEKKO -mrvl -mcpu=750 -meabi -mhard-float -DMSB_FIRST
   CC  = $(DEVKITPPC)/bin/powerpc-eabi-gcc$(EXE_EXT)
   CXX = $(DEVKITPPC)/bin/powerpc-eabi-g++$(EXE_EXT)
   AR  = $(DEVKITPPC)/bin/powerpc-eabi-ar$(EXE_EXT)
   EXTRA_INCLUDES := -I$(DEVKITPRO)/libogc/include
   STATIC_LINKING = 1

# Nintendo WiiU
else ifeq ($(platform), wiiu)
   TARGET := $(TARGET_NAME)_libretro_$(platform).a
   CC      = $(DEVKITPPC)/bin/powerpc-eabi-gcc$(EXE_EXT)
   CXX     = $(DEVKITPPC)/bin/powerpc-eabi-g++$(EXE_EXT)
   AR      = $(DEVKITPPC)/bin/powerpc-eabi-ar$(EXE_EXT)
   FLAGS  += -DGEKKO -mwup -mcpu=750 -meabi -mhard-float
   FLAGS  += -U__INT32_TYPE__ -U __UINT32_TYPE__ -D__INT32_TYPE__=int
   ENDIANNESS_DEFINES += -DMSB_FIRST
   EXTRA_INCLUDES     := -Ideps
   STATIC_LINKING = 1
   NEED_THREADING = 0

# GCW0
else ifeq ($(platform), gcw0)
   TARGET  := $(TARGET_NAME)_libretro.so
   CC       = /opt/gcw0-toolchain/usr/bin/mipsel-linux-gcc
   CXX      = /opt/gcw0-toolchain/usr/bin/mipsel-linux-g++
   AR       = /opt/gcw0-toolchain/usr/bin/mipsel-linux-ar
   fpic    := -fPIC
   SHARED  := -shared -Wl,--no-undefined -Wl,--version-script=link.T
   LDFLAGS += $(PTHREAD_FLAGS)
   FLAGS   += $(PTHREAD_FLAGS)
   FLAGS   += -ffast-math -march=mips32 -mtune=mips32r2 -mhard-float
   GLES     = 1
   GL_LIB  := -lGLESv2

# Emscripten
else ifeq ($(platform), emscripten)
   TARGET  := $(TARGET_NAME)_libretro_$(platform).bc
   fpic    := -fPIC
   FLAGS   += -DEMSCRIPTEN
   FLAGS   += -msimd128 -ftree-vectorize

   HAVE_OPENGL = 1
   GLES = 1
   GLES3 = 1
   HAVE_LIGHTREC = 0
   NEED_THREADING = 0
   HAVE_CDROM = 0
   THREADED_RECOMPILER = 0

   STATIC_LINKING = 1

# Raspberry Pi 4 in 64bit mode
else ifeq ($(platform), rpi4_64)
   TARGET := $(TARGET_NAME)_libretro.so
   fpic   := -fPIC
   GREP = grep
   SHARED := -shared -Wl,--no-undefined -Wl,--version-script=link.T
   CFLAGS   += -O3 -DNDEBUG -march=armv8-a+crc+simd -mtune=cortex-a72 -fsigned-char 
   CXXFLAGS += -O3 -DNDEBUG -march=armv8-a+crc+simd -mtune=cortex-a72 -fsigned-char
   LDFLAGS += $(PTHREAD_FLAGS) -ldl -lrt
   HAVE_LIGHTREC = 1
   FLAGS += -DHAVE_SHM
   GLES = 1
   GLES3 = 1
   GL_LIB := -lGLESv2
   HAVE_CDROM = 0

# Windows MSVC 2017 all architectures
else ifneq (,$(findstring windows_msvc2017,$(platform)))

   NO_GCC := 1

   PlatformSuffix = $(subst windows_msvc2017_,,$(platform))
   ifneq (,$(findstring desktop,$(PlatformSuffix)))
      WinPartition = desktop
      MSVC2017CompileFlags = -DWINAPI_FAMILY=WINAPI_FAMILY_DESKTOP_APP -FS
      LDFLAGS += -MANIFEST -LTCG:incremental -NXCOMPAT -DYNAMICBASE -DEBUG -OPT:REF -INCREMENTAL:NO -SUBSYSTEM:WINDOWS -MANIFESTUAC:"level='asInvoker' uiAccess='false'" -OPT:ICF -ERRORREPORT:PROMPT -NOLOGO -TLBID:1
      LIBS += kernel32.lib user32.lib gdi32.lib winspool.lib comdlg32.lib advapi32.lib
      HAVE_CDROM = 1
   else ifneq (,$(findstring uwp,$(PlatformSuffix)))
      WinPartition = uwp
      MSVC2017CompileFlags = -DWINAPI_FAMILY=WINAPI_FAMILY_APP -D_WINDLL -D_UNICODE -DUNICODE -D__WRL_NO_DEFAULT_LIB__ -EHsc -FS
      LDFLAGS += -APPCONTAINER -NXCOMPAT -DYNAMICBASE -MANIFEST:NO -LTCG -OPT:REF -SUBSYSTEM:CONSOLE -MANIFESTUAC:NO -OPT:ICF -ERRORREPORT:PROMPT -NOLOGO -TLBID:1 -DEBUG:FULL -WINMD:NO
      LIBS += WindowsApp.lib
   endif

   CFLAGS += $(MSVC2017CompileFlags)
   CXXFLAGS += $(MSVC2017CompileFlags)

   TargetArchMoniker = $(subst $(WinPartition)_,,$(PlatformSuffix))

   CC  = cl.exe
   CXX = cl.exe
   LD = link.exe

   reg_query = $(call filter_out2,$(subst $2,,$(shell reg query "$2" -v "$1" 2>nul)))
   fix_path = $(subst $(SPACE),\ ,$(subst \,/,$1))

   ProgramFiles86w := $(shell cmd /c "echo %PROGRAMFILES(x86)%")
   ProgramFiles86 := $(shell cygpath "$(ProgramFiles86w)")

   WindowsSdkDir ?= $(call reg_query,InstallationFolder,HKEY_LOCAL_MACHINE\SOFTWARE\Wow6432Node\Microsoft\Microsoft SDKs\Windows\v10.0)
   WindowsSdkDir ?= $(call reg_query,InstallationFolder,HKEY_CURRENT_USER\SOFTWARE\Wow6432Node\Microsoft\Microsoft SDKs\Windows\v10.0)
   WindowsSdkDir ?= $(call reg_query,InstallationFolder,HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Microsoft SDKs\Windows\v10.0)
   WindowsSdkDir ?= $(call reg_query,InstallationFolder,HKEY_CURRENT_USER\SOFTWARE\Microsoft\Microsoft SDKs\Windows\v10.0)
   WindowsSdkDir := $(WindowsSdkDir)

   WindowsSDKVersion ?= $(firstword $(foreach folder,$(subst $(subst \,/,$(WindowsSdkDir)Include/),,$(wildcard $(call fix_path,$(WindowsSdkDir)Include\*))),$(if $(wildcard $(call fix_path,$(WindowsSdkDir)Include/$(folder)/um/Windows.h)),$(folder),)))$(BACKSLASH)
   WindowsSDKVersion := $(WindowsSDKVersion)

   VsInstallBuildTools = $(ProgramFiles86)/Microsoft Visual Studio/2017/BuildTools
   VsInstallEnterprise = $(ProgramFiles86)/Microsoft Visual Studio/2017/Enterprise
   VsInstallProfessional = $(ProgramFiles86)/Microsoft Visual Studio/2017/Professional
   VsInstallCommunity = $(ProgramFiles86)/Microsoft Visual Studio/2017/Community

   VsInstallRoot ?= $(shell if [ -d "$(VsInstallBuildTools)" ]; then echo "$(VsInstallBuildTools)"; fi)
   ifeq ($(VsInstallRoot), )
      VsInstallRoot = $(shell if [ -d "$(VsInstallEnterprise)" ]; then echo "$(VsInstallEnterprise)"; fi)
   endif
   ifeq ($(VsInstallRoot), )
      VsInstallRoot = $(shell if [ -d "$(VsInstallProfessional)" ]; then echo "$(VsInstallProfessional)"; fi)
   endif
   ifeq ($(VsInstallRoot), )
      VsInstallRoot = $(shell if [ -d "$(VsInstallCommunity)" ]; then echo "$(VsInstallCommunity)"; fi)
   endif
   VsInstallRoot := $(VsInstallRoot)

   VcCompilerToolsVer := $(shell cat "$(VsInstallRoot)/VC/Auxiliary/Build/Microsoft.VCToolsVersion.default.txt" | grep -o '[0-9\.]*')
   VcCompilerToolsDir := $(VsInstallRoot)/VC/Tools/MSVC/$(VcCompilerToolsVer)

   WindowsSDKSharedIncludeDir := $(shell cygpath -w "$(WindowsSdkDir)\Include\$(WindowsSDKVersion)\shared")
   WindowsSDKUCRTIncludeDir := $(shell cygpath -w "$(WindowsSdkDir)\Include\$(WindowsSDKVersion)\ucrt")
   WindowsSDKUMIncludeDir := $(shell cygpath -w "$(WindowsSdkDir)\Include\$(WindowsSDKVersion)\um")
   WindowsSDKUCRTLibDir := $(shell cygpath -w "$(WindowsSdkDir)\Lib\$(WindowsSDKVersion)\ucrt\$(TargetArchMoniker)")
   WindowsSDKUMLibDir := $(shell cygpath -w "$(WindowsSdkDir)\Lib\$(WindowsSDKVersion)\um\$(TargetArchMoniker)")

   # For some reason the HostX86 compiler doesn't like compiling for x64
   # ("no such file" opening a shared library), and vice-versa.
   # Work around it for now by using the strictly x86 compiler for x86, and x64 for x64.
   # NOTE: What about ARM?
   ifneq (,$(findstring x64,$(TargetArchMoniker)))
      VCCompilerToolsBinDir := $(VcCompilerToolsDir)\bin\HostX64
   else
      VCCompilerToolsBinDir := $(VcCompilerToolsDir)\bin\HostX86
   endif

   PATH := $(shell IFS=$$'\n'; cygpath "$(VCCompilerToolsBinDir)/$(TargetArchMoniker)"):$(PATH)
   PATH := $(PATH):$(shell IFS=$$'\n'; cygpath "$(VsInstallRoot)/Common7/IDE")
   INCLUDE := $(shell IFS=$$'\n'; cygpath -w "$(VcCompilerToolsDir)/include")
   LIB := $(shell IFS=$$'\n'; cygpath -w "$(VcCompilerToolsDir)/lib/$(TargetArchMoniker)")
   ifneq (,$(findstring uwp,$(PlatformSuffix)))
      LIB := $(shell IFS=$$'\n'; cygpath -w "$(LIB)/store")
   endif

   export INCLUDE := $(INCLUDE);$(WindowsSDKSharedIncludeDir);$(WindowsSDKUCRTIncludeDir);$(WindowsSDKUMIncludeDir)
   export LIB := $(LIB);$(WindowsSDKUCRTLibDir);$(WindowsSDKUMLibDir)
   TARGET := $(TARGET_NAME)_libretro.dll
   TARGET_TMP := $(TARGET_NAME)_libretro.lib $(TARGET_NAME)_libretro.pdb $(TARGET_NAME)_libretro.exp
   LDFLAGS += -DLL

# Windows
else
   TARGET  := $(TARGET_NAME)_libretro.dll
   CC      ?= gcc
   CXX     ?= g++
   IS_X86   = 1
   SHARED  := -shared -Wl,--no-undefined -Wl,--version-script=link.T
   LDFLAGS += -static-libgcc -static-libstdc++ -lwinmm
   FLAGS   += -DHAVE__MKDIR
   HAVE_CDROM = 1

   ifeq ($(HAVE_OPENGL),1)
      GL_LIB := -lopengl32
   endif

   ifeq ($(HAVE_LIGHTREC), 1)
      FLAGS += -DHAVE_WIN_SHM
   endif
endif

include Makefile.common

# https://github.com/libretro-mirrors/mednafen-git/blob/master/README.PORTING
MEDNAFEN_GCC_FLAGS = -fwrapv \
                     -fsigned-char

ifeq ($(IS_X86),1)
   MEDNAFEN_GCC_FLAGS += -fomit-frame-pointer
endif

WARNINGS := -Wall \
            -Wvla \
            -Wno-sign-compare \
            -Wno-unused-variable \
            -Wno-unused-function \
            -Wno-uninitialized \
            $(NEW_GCC_WARNING_FLAGS) \
            -Wno-strict-aliasing

ifeq ($(NO_GCC),1)
   WARNINGS :=
else
   FLAGS += $(MEDNAFEN_GCC_FLAGS)
endif

OBJECTS := $(SOURCES_CXX:.cpp=.o) $(SOURCES_C:.c=.o)
DEPS    := $(SOURCES_CXX:.cpp=.d) $(SOURCES_C:.c=.d)

all: $(TARGET)

-include $(DEPS)

ifeq ($(DEBUG), 1)
   ifneq (,$(findstring msvc,$(platform)))
      ifeq ($(STATIC_LINKING),1)
         CFLAGS   += -MTd
         CXXFLAGS += -MTd
      else
         CFLAGS   += -MDd
         CXXFLAGS += -MDd
      endif

      CFLAGS   += -Od -Zi -DDEBUG -D_DEBUG
      CXXFLAGS += -Od -Zi -DDEBUG -D_DEBUG
   else
      CFLAGS   += -O0 -g -DDEBUG -MMD
      CXXFLAGS += -O0 -g -DDEBUG -MMD
   endif
else
   ifneq (,$(findstring msvc,$(platform)))
      ifeq ($(STATIC_LINKING),1)
         CFLAGS   += -MT
         CXXFLAGS += -MT
      else
         CFLAGS   += -MD
         CXXFLAGS += -MD
      endif

      CFLAGS   += -O2 -DNDEBUG
      CXXFLAGS += -O2 -DNDEBUG
   else
      CFLAGS   += -O3 -DNDEBUG -MMD
      CXXFLAGS += -O3 -DNDEBUG -MMD
   endif
endif

LDFLAGS += $(fpic) $(SHARED)
FLAGS   += $(fpic) $(NEW_GCC_FLAGS)
FLAGS   += $(INCFLAGS)

FLAGS += $(ENDIANNESS_DEFINES) \
         $(WARNINGS) \
         -DMEDNAFEN_VERSION=\"0.9.38.6\" \
         -DMEDNAFEN_VERSION_NUMERIC=9386 \
         -DMPC_FIXED_POINT \
         $(CORE_DEFINE) \
         -DSTDC_HEADERS \
         -D__STDC_LIMIT_MACROS \
         -D__LIBRETRO__ \
         -D_LOW_ACCURACY_ \
         $(EXTRA_INCLUDES) \
         $(SOUND_DEFINE) \
         -D_FILE_OFFSET_BITS=64 \
         -D__STDC_CONSTANT_MACROS

ifneq (,$(findstring windows_msvc2017,$(platform)))
   FLAGS += -D_CRT_SECURE_NO_WARNINGS \
            -D_CRT_NONSTDC_NO_DEPRECATE \
            -D__ORDER_LITTLE_ENDIAN__ \
            -D__BYTE_ORDER__=__ORDER_LITTLE_ENDIAN__ \
            -DNOMINMAX \
            //utf-8 \
            //std:c++17
            ifeq (,$(findstring windows_msvc2017_uwp,$(platform)))
               LDFLAGS += opengl32.lib
            endif
endif

ifeq ($(HAVE_VULKAN),1)
   FLAGS += -DHAVE_VULKAN
endif

ifeq ($(HAVE_JIT),1)
   LDFLAGS += -ljit
endif

CXXFLAGS += $(FLAGS)
CFLAGS   += $(FLAGS)

ifneq ($(SANITIZER),)
   CFLAGS   := -fsanitize=$(SANITIZER) $(CFLAGS)
   CXXFLAGS := -fsanitize=$(SANITIZER) $(CXXFLAGS)
   LDFLAGS  := -fsanitize=$(SANITIZER) $(LDFLAGS)
endif

OBJOUT  = -o
LINKOUT = -o

ifneq (,$(findstring msvc,$(platform)))
   OBJOUT = -Fo
   LINKOUT = -out:
ifeq ($(STATIC_LINKING),1)
   LD ?= lib.exe
   STATIC_LINKING=0
else
   LD = link.exe
endif
else
   LD = $(CXX)
endif

$(TARGET): $(OBJECTS)
ifeq ($(STATIC_LINKING), 1)
	$(AR) rcs $@ $(OBJECTS)
else
	@$(LD) $(LINKOUT)$@ $^ $(LDFLAGS) $(GL_LIB) $(LIBS)
endif

%.o: %.cpp
	$(CXX) -c $(OBJOUT)$@ $< $(CXXFLAGS)

%.o: %.c
	$(CC) -c $(OBJOUT)$@ $< $(CFLAGS)

clean:
	@rm -f $(OBJECTS)
	@echo rm -f "*.o"
	@rm -f $(DEPS)
	@echo rm -f "*.d"
	rm -f $(TARGET) $(TARGET_TMP)

.PHONY: clean
