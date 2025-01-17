## LLVM ##
include $(SRCDIR)/llvm-ver.make

LLVM_GIT_URL_BASE ?= http://llvm.org/git
LLVM_GIT_URL_LLVM ?= $(LLVM_GIT_URL_BASE)/llvm.git
LLVM_GIT_URL_CLANG ?= $(LLVM_GIT_URL_BASE)/clang.git
LLVM_GIT_URL_COMPILER_RT ?= $(LLVM_GIT_URL_BASE)/compiler-rt.git
LLVM_GIT_URL_LLDB ?= $(LLVM_GIT_URL_BASE)/lldb.git
LLVM_GIT_URL_LIBCXX ?= $(LLVM_GIT_URL_BASE)/libcxx.git
LLVM_GIT_URL_LIBCXXABI ?= $(LLVM_GIT_URL_BASE)/libcxxabi.git
LLVM_GIT_URL_POLLY ?= $(LLVM_GIT_URL_BASE)/polly.git

ifeq ($(BUILD_LLDB), 1)
BUILD_LLVM_CLANG := 1
# because it's a build requirement
endif

ifeq ($(USE_POLLY),1)
ifeq ($(USE_SYSTEM_LLVM),0)
ifneq ($(LLVM_VER),svn)
$(error USE_POLLY=1 requires LLVM_VER=svn)
endif
endif
endif

include $(SRCDIR)/llvm-options.mk
LLVM_LIB_FILE := libLLVMCodeGen.a

ifeq ($(LLVM_VER), 3.3)
LLVM_TAR_EXT:=$(LLVM_VER).src.tar.gz
else
LLVM_TAR_EXT:=$(LLVM_VER).src.tar.xz
endif # LLVM_VER == 3.3

ifneq ($(LLVM_VER),svn)
LLVM_TAR:=$(SRCDIR)/srccache/llvm-$(LLVM_TAR_EXT)

ifeq ($(BUILD_LLDB),1)
LLVM_LLDB_TAR:=$(SRCDIR)/srccache/lldb-$(LLVM_TAR_EXT)
endif # BUILD_LLDB

ifeq ($(BUILD_LLVM_CLANG),1)
LLVM_CLANG_TAR:=$(SRCDIR)/srccache/cfe-$(LLVM_TAR_EXT)
LLVM_COMPILER_RT_TAR:=$(SRCDIR)/srccache/compiler-rt-$(LLVM_TAR_EXT)
else
LLVM_CLANG_TAR:=
LLVM_COMPILER_RT_TAR:=
LLVM_LIBCXX_TAR:=
endif # BUILD_LLVM_CLANG

ifeq ($(BUILD_CUSTOM_LIBCXX),1)
LLVM_LIBCXX_TAR:=$(SRCDIR)/srccache/libcxx-$(LLVM_TAR_EXT)
endif
endif # LLVM_VER != svn

# Figure out which targets to build
ifeq ($(LLVM_VER_SHORT),$(filter $(LLVM_VER_SHORT),3.3 3.4 3.5 3.6 3.7 3.8))
LLVM_TARGETS := host
else
LLVM_TARGETS := host;NVPTX
endif

# Allow adding LLVM specific flags
LLVM_CFLAGS += $(CFLAGS)
LLVM_CXXFLAGS += $(CXXFLAGS)
LLVM_CPPFLAGS += $(CPPFLAGS)
LLVM_LDFLAGS += $(LDFLAGS)
LLVM_CMAKE += -DLLVM_TARGETS_TO_BUILD:STRING="$(LLVM_TARGETS)" -DCMAKE_BUILD_TYPE="$(LLVM_CMAKE_BUILDTYPE)"
LLVM_CMAKE += -DLLVM_TOOLS_INSTALL_DIR=$(shell $(JULIAHOME)/contrib/relative_path.sh $(build_prefix) $(build_depsbindir))
LLVM_CMAKE += -DLLVM_BINDINGS_LIST="" -DLLVM_INCLUDE_DOCS=Off -DLLVM_ENABLE_TERMINFO=Off -DHAVE_HISTEDIT_H=Off -DHAVE_LIBEDIT=Off
LLVM_FLAGS += --disable-profiling --enable-static --enable-targets=$(LLVM_TARGETS)
LLVM_FLAGS += --disable-bindings --disable-docs --disable-libedit --disable-terminfo
# LLVM has weird install prefixes (see llvm-$(LLVM_VER)/build_$(LLVM_BUILDTYPE)/Makefile.config for the full list)
# We map them here to the "normal" ones, which means just prefixing "PROJ_" to the variable name.
LLVM_MFLAGS := PROJ_libdir=$(build_libdir) PROJ_bindir=$(build_depsbindir) PROJ_includedir=$(build_includedir)
ifeq ($(LLVM_ASSERTIONS), 1)
LLVM_FLAGS += --enable-assertions
LLVM_CMAKE += -DLLVM_ENABLE_ASSERTIONS:BOOL=ON
ifeq ($(OS), WINNT)
LLVM_FLAGS += --disable-embed-stdcxx
endif # OS == WINNT
else
LLVM_FLAGS += --disable-assertions
endif # LLVM_ASSERTIONS
ifeq ($(LLVM_DEBUG), 1)
LLVM_FLAGS += --disable-optimized --enable-debug-symbols --enable-keep-symbols
ifeq ($(OS), WINNT)
LLVM_CXXFLAGS += -Wa,-mbig-obj
endif # OS == WINNT
else
LLVM_FLAGS += --enable-optimized
endif # LLVM_DEBUG
ifeq ($(USE_LIBCPP), 1)
LLVM_FLAGS += --enable-libcpp
endif # USE_LIBCPP
ifeq ($(OS), WINNT)
LLVM_FLAGS += --with-extra-ld-options="-Wl,--stack,8388608" LDFLAGS=""
LLVM_CPPFLAGS += -D__USING_SJLJ_EXCEPTIONS__ -D__CRT__NO_INLINE
ifneq ($(BUILD_OS),WINNT)
LLVM_CMAKE += -DCROSS_TOOLCHAIN_FLAGS_NATIVE=-DCMAKE_TOOLCHAIN_FILE=$(SRCDIR)/NATIVE.cmake
endif # BUILD_OS != WINNT
endif # OS == WINNT
ifeq ($(USE_LLVM_SHLIB),1)
# NOTE: we could also --disable-static here (on the condition we link tools
#       against libLLVM) but there doesn't seem to be a CMake counterpart option
LLVM_FLAGS += --enable-shared
LLVM_CMAKE += -DLLVM_BUILD_LLVM_DYLIB:BOOL=ON -DLLVM_LINK_LLVM_DYLIB:BOOL=ON
# NOTE: starting with LLVM 3.8, all symbols are exported
ifeq ($(LLVM_VER_SHORT),$(filter $(LLVM_VER_SHORT),3.3 3.4 3.5 3.6 3.7))
LLVM_CMAKE += -DLLVM_DYLIB_EXPORT_ALL:BOOL=ON
endif
endif
ifeq ($(USE_INTEL_JITEVENTS), 1)
LLVM_FLAGS += --with-intel-jitevents
ifeq ($(OS), WINNT)
LLVM_FLAGS += --disable-threads
endif # OS == WINNT
else
LLVM_FLAGS += --disable-threads
endif # USE_INTEL_JITEVENTS

ifeq ($(USE_OPROFILE_JITEVENTS), 1)
LLVM_FLAGS += --with-oprofile=/usr/
endif # USE_OPROFILE_JITEVENTS

ifeq ($(BUILD_LLDB),1)
ifeq ($(USECLANG),1)
LLVM_FLAGS += --enable-cxx11
else
LLVM_CXXFLAGS += -std=c++0x
endif # USECLANG
ifeq ($(LLDB_DISABLE_PYTHON),1)
LLVM_CXXFLAGS += -DLLDB_DISABLE_PYTHON
LLVM_CMAKE += -DLLDB_DISABLE_PYTHON=ON
endif # LLDB_DISABLE_PYTHON
endif # BUILD_LLDB

ifneq (,$(filter $(ARCH), powerpc64le ppc64le))
LLVM_CXXFLAGS += -mminimal-toc
endif

# LLVM bug #24157
ifeq ($(USE_LLVM_SHLIB),1)
ifeq ($(LLVM_USE_CMAKE),1)
ifeq ($(LLVM_VER_SHORT),$(filter $(LLVM_VER_SHORT),3.3 3.4 3.5 3.6 3.7))
$(error USE_LLVM_SHLIB=1 with LLVM_USE_CMAKE=1 requires LLVM > 3.7.x)
endif
endif
endif

ifeq ($(LLVM_SANITIZE),1)
# autotools doesn't provide a sanitation build mode (linking libLLVM will fail)
ifeq ($(USE_LLVM_SHLIB),1)
ifeq ($(LLVM_USE_CMAKE),0)
$(error LLVM_SANITIZE=1 with USE_LLVM_SHLIB=1 requires LLVM_USE_CMAKE=1)
endif
endif
ifeq ($(SANITIZE_MEMORY),1)
LLVM_CFLAGS += -fsanitize=memory -fsanitize-memory-track-origins
LLVM_LDFLAGS += -fsanitize=memory -fsanitize-memory-track-origins
LLVM_CXXFLAGS += -fsanitize=memory -fsanitize-memory-track-origins
LLVM_CMAKE += -DLLVM_USE_SANITIZER="MemoryWithOrigins"
LLVM_FLAGS += --disable-terminfo
else
LLVM_CFLAGS += -fsanitize=address
LLVM_LDFLAGS += -fsanitize=address
LLVM_CXXFLAGS += -fsanitize=address
LLVM_CMAKE += -DLLVM_USE_SANITIZER="Address"
endif
LLVM_MFLAGS += TOOL_NO_EXPORTS= HAVE_LINK_VERSION_SCRIPT=0
endif # LLVM_SANITIZE

ifeq ($(LLVM_LTO),1)
LLVM_CPPFLAGS += -flto
LLVM_LDFLAGS += -flto
endif # LLVM_LTO

ifneq ($(LLVM_CXXFLAGS),)
LLVM_FLAGS += CXXFLAGS="$(LLVM_CXXFLAGS)"
LLVM_MFLAGS += CXXFLAGS="$(LLVM_CXXFLAGS)"
endif # LLVM_CXXFLAGS
ifneq ($(LLVM_CFLAGS),)
LLVM_FLAGS += CFLAGS="$(LLVM_CFLAGS)"
LLVM_MFLAGS += CFLAGS="$(LLVM_CFLAGS)"
endif # LLVM_CFLAGS

ifeq ($(BUILD_CUSTOM_LIBCXX),1)
LLVM_LDFLAGS += -Wl,-R$(build_libdir) -lc++ -lc++abi
ifeq ($(USEICC),1)
LLVM_LDFLAGS += -no_cpprt
endif # USEICC
endif # BUILD_CUSTOM_LIBCXX

ifneq ($(LLVM_CPPFLAGS),)
LLVM_FLAGS += CPPFLAGS="$(LLVM_CPPFLAGS)"
LLVM_MFLAGS += CPPFLAGS="$(LLVM_CPPFLAGS)"
endif
ifneq ($(LLVM_LDFLAGS),)
LLVM_FLAGS += LDFLAGS="$(LLVM_LDFLAGS)"
LLVM_MFLAGS += LDFLAGS="$(LLVM_LDFLAGS)"
endif
LLVM_CMAKE += -DCMAKE_C_FLAGS="$(LLVM_CPPFLAGS) $(LLVM_CFLAGS)" \
	-DCMAKE_CXX_FLAGS="$(LLVM_CPPFLAGS) $(LLVM_CXXFLAGS)" \
	-DCMAKE_EXE_LINKER_FLAGS="$(LLVM_LDFLAGS)" \
	-DCMAKE_SHARED_LINKER_FLAGS="$(LLVM_LDFLAGS)"

ifeq ($(BUILD_LLVM_CLANG),1)
LLVM_MFLAGS += OPTIONAL_PARALLEL_DIRS=clang
else
# block default building of Clang
LLVM_MFLAGS += OPTIONAL_PARALLEL_DIRS=
ifeq ($(LLVM_VER_SHORT),$(filter $(LLVM_VER_SHORT),3.3 3.4 3.5 3.6 3.7))
LLVM_CMAKE += -DLLVM_EXTERNAL_CLANG_BUILD=OFF
LLVM_CMAKE += -DLLVM_EXTERNAL_COMPILER_RT_BUILD=OFF
else
LLVM_CMAKE += -DLLVM_TOOL_CLANG_BUILD=OFF
LLVM_CMAKE += -DLLVM_TOOL_COMPILER_RT_BUILD=OFF
endif
endif
ifeq ($(BUILD_LLDB),1)
LLVM_MFLAGS += OPTIONAL_DIRS=lldb
else
# block default building of lldb
LLVM_MFLAGS += OPTIONAL_DIRS=
ifeq ($(LLVM_VER_SHORT),$(filter $(LLVM_VER_SHORT),3.3 3.4 3.5 3.6 3.7))
LLVM_CMAKE += -DLLVM_EXTERNAL_LLDB_BUILD=OFF
else
LLVM_CMAKE += -DLLVM_TOOL_LLDB_BUILD=OFF
endif
endif

LLVM_SRC_URL := http://releases.llvm.org/$(LLVM_VER)

ifneq ($(LLVM_CLANG_TAR),)
$(LLVM_CLANG_TAR): | $(SRCDIR)/srccache
	$(JLDOWNLOAD) $@ $(LLVM_SRC_URL)/$(notdir $@)
endif
ifneq ($(LLVM_COMPILER_RT_TAR),)
$(LLVM_COMPILER_RT_TAR): | $(SRCDIR)/srccache
	$(JLDOWNLOAD) $@ $(LLVM_SRC_URL)/$(notdir $@)
endif

ifneq ($(LLVM_LIBCXX_TAR),)
$(LLVM_LIBCXX_TAR): | $(SRCDIR)/srccache
	$(JLDOWNLOAD) $@ $(LLVM_SRC_URL)/$(notdir $@)
endif
ifneq ($(LLVM_VER),svn)
$(LLVM_TAR): | $(SRCDIR)/srccache
	$(JLDOWNLOAD) $@ $(LLVM_SRC_URL)/$(notdir $@)
endif

ifneq ($(LLVM_LLDB_TAR),)
$(LLVM_LLDB_TAR): | $(SRCDIR)/srccache
	$(JLDOWNLOAD) $@ $(LLVM_SRC_URL)/$(notdir $@)
endif
ifeq ($(BUILD_LLDB),1)
$(LLVM_SRC_DIR)/tools/lldb:
$(LLVM_SRC_DIR)/source-extracted: $(LLVM_SRC_DIR)/tools/lldb
endif

# LLDB still relies on plenty of python 2.x infrastructure, without checking
llvm_python_location=$(shell /usr/bin/env python2 -c 'import sys; print(sys.executable)')
llvm_python_workaround=$(SRCDIR)/srccache/python2_path
$(llvm_python_workaround):
	mkdir -p $@
	-python -c 'import sys; sys.exit(not sys.version_info > (3, 0))' && \
	/usr/bin/env python2 -c 'import sys; sys.exit(not sys.version_info < (3, 0))' && \
	ln -sf $(llvm_python_location) "$@/python" && \
	ln -sf $(llvm_python_location)-config "$@/python-config"
LLVM_FLAGS += --with-python="$(shell $(SRCDIR)/tools/find_python2)"

ifeq ($(BUILD_CUSTOM_LIBCXX),1)

ifeq ($(USEICC),1)
LIBCXX_EXTRA_FLAGS := -Bstatic -lirc -Bdynamic
endif

$(LLVM_SRC_DIR)/projects/libcxx: $(LLVM_LIBCXX_TAR) | $(LLVM_SRC_DIR)/source-extracted
	([ ! -d $@ ] && \
	git clone $(LLVM_GIT_URL_LIBCXX) $@  ) || \
	(cd $@  && \
	git pull --ff-only)
$(LLVM_SRC_DIR)/projects/libcxx/.git/HEAD: | $(LLVM_SRC_DIR)/projects/libcxx/.git/HEAD
$(LLVM_SRC_DIR)/projects/libcxxabi: $(LLVM_LIBCXXABI_TAR) | $(LLVM_SRC_DIR)/source-extracted
	([ ! -d $@ ] && \
	git clone $(LLVM_GIT_URL_LIBCXXABI) $@ ) || \
	(cd $@ && \
	git pull --ff-only)
$(LLVM_SRC_DIR)/projects/libcxxabi/.git/HEAD: | $(LLVM_SRC_DIR)/projects/libcxxabi
$(LLVM_BUILD_DIR)/libcxx-build/Makefile: | $(LLVM_SRC_DIR)/projects/libcxx $(LLVM_SRC_DIR)/projects/libcxxabi
	mkdir -p $(dir $@)
	cd $(dir $@) && \
		$(CMAKE) -G "Unix Makefiles" $(CMAKE_COMMON) $(LLVM_CMAKE) -DLIBCXX_CXX_ABI=libcxxabi -DLIBCXX_CXX_ABI_INCLUDE_PATHS="$(LLVM_SRC_DIR)/projects/libcxxabi/include" $(LLVM_SRC_DIR)/projects/libcxx -DCMAKE_SHARED_LINKER_FLAGS="$(LDFLAGS) -L$(build_libdir) $(LIBCXX_EXTRA_FLAGS)"
$(LLVM_BUILD_DIR)/libcxxabi-build/Makefile: | $(LLVM_SRC_DIR)/projects/libcxxabi $(LLVM_SRC_DIR)/projects/libcxx
	mkdir -p $(dir $@)
	cd $(dir $@) && \
		$(CMAKE) -G "Unix Makefiles" $(CMAKE_COMMON) $(LLVM_CMAKE) -DLLVM_ABI_BREAKING_CHECKS="WITH_ASSERTS" -DLLVM_PATH="$(LLVM_SRC_DIR)" $(LLVM_SRC_DIR)/projects/libcxxabi -DLIBCXXABI_CXX_ABI_LIBRARIES="$(LIBCXX_EXTRA_FLAGS)" -DCMAKE_CXX_FLAGS="$(LLVM_CPPFLAGS) $(LLVM_CXXFLAGS) -std=c++11"
$(LLVM_BUILD_DIR)/libcxxabi-build/lib/libc++abi.so.1.0: $(LLVM_BUILD_DIR)/libcxxabi-build/Makefile $(LLVM_SRC_DIR)/projects/libcxxabi/.git/HEAD
	$(MAKE) -C $(LLVM_BUILD_DIR)/libcxxabi-build
	touch -c $@
$(build_libdir)/libc++abi.so.1.0: $(LLVM_BUILD_DIR)/libcxxabi-build/lib/libc++abi.so.1.0
	$(MAKE) -C $(LLVM_BUILD_DIR)/libcxxabi-build install
	touch -c $@
$(LLVM_BUILD_DIR)/libcxx-build/lib/libc++.so.1.0: $(build_libdir)/libc++abi.so.1.0 $(LLVM_BUILD_DIR)/libcxx-build/Makefile $(LLVM_SRC_DIR)/projects/libcxx/.git/HEAD
	$(MAKE) -C $(LLVM_BUILD_DIR)/libcxx-build
$(build_libdir)/libc++.so.1.0: $(LLVM_BUILD_DIR)/libcxx-build/lib/libc++.so.1.0
	$(MAKE) -C $(LLVM_BUILD_DIR)/libcxx-build install
	touch -c $@
get-libcxx: $(LLVM_SRC_DIR)/projects/libcxx
get-libcxxabi: $(LLVM_SRC_DIR)/projects/libcxxabi
install-libcxxabi: $(build_libdir)/libc++abi.so.1.0
install-libcxx: $(build_libdir)/libc++.so.1.0
endif

ifeq ($(BUILD_CUSTOM_LIBCXX),1)
LIBCXX_DEPENDENCY := $(build_libdir)/libc++abi.so.1.0 $(build_libdir)/libc++.so.1.0
get-llvm: get-libcxx get-libcxxabi
endif

$(LLVM_SRC_DIR)/source-extracted: | $(LLVM_TAR) $(LLVM_CLANG_TAR) $(LLVM_COMPILER_RT_TAR) $(LLVM_LIBCXX_TAR) $(LLVM_LLDB_TAR)
ifneq ($(LLVM_CLANG_TAR),)
	$(JLCHECKSUM) $(LLVM_CLANG_TAR)
endif
ifneq ($(LLVM_COMPILER_RT_TAR),)
	$(JLCHECKSUM) $(LLVM_COMPILER_RT_TAR)
endif
ifneq ($(LLVM_LIBCXX_TAR),)
	$(JLCHECKSUM) $(LLVM_LIBCXX_TAR)
endif
ifneq ($(LLVM_VER),svn)
	$(JLCHECKSUM) $(LLVM_TAR)
endif
ifneq ($(LLVM_LLDB_TAR),)
	$(JLCHECKSUM) $(LLVM_LLDB_TAR)
endif
	-rm -rf $(LLVM_SRC_DIR)
ifneq ($(LLVM_VER),svn)
	mkdir -p $(LLVM_SRC_DIR)
	$(TAR) -C $(LLVM_SRC_DIR) --strip-components 1 -xf $(LLVM_TAR)
else
	([ ! -d $(LLVM_SRC_DIR) ] && \
		git clone $(LLVM_GIT_URL_LLVM) $(LLVM_SRC_DIR) ) || \
		(cd $(LLVM_SRC_DIR) && \
		git pull --ff-only)
ifneq ($(LLVM_GIT_VER),)
	(cd $(LLVM_SRC_DIR) && \
		git checkout $(LLVM_GIT_VER))
endif # LLVM_GIT_VER
	# Debug output only. Disable pager and ignore error.
	(cd $(LLVM_SRC_DIR) && \
		git show HEAD --stat | cat) || true
endif # LLVM_VER
ifneq ($(LLVM_VER),svn)
ifneq ($(LLVM_CLANG_TAR),)
	mkdir -p $(LLVM_SRC_DIR)/tools/clang
	$(TAR) -C $(LLVM_SRC_DIR)/tools/clang --strip-components 1 -xf $(LLVM_CLANG_TAR)
endif # LLVM_CLANG_TAR
ifneq ($(LLVM_COMPILER_RT_TAR),)
	mkdir -p $(LLVM_SRC_DIR)/projects/compiler-rt
	$(TAR) -C $(LLVM_SRC_DIR)/projects/compiler-rt --strip-components 1 -xf $(LLVM_COMPILER_RT_TAR)
endif # LLVM_COMPILER_RT_TAR
ifneq ($(LLVM_LLDB_TAR),)
	mkdir -p $(LLVM_SRC_DIR)/tools/lldb
	$(TAR) -C $(LLVM_SRC_DIR)/tools/lldb --strip-components 1 -xf $(LLVM_LLDB_TAR)
endif # LLVM_LLDB_TAR
else # LLVM_VER
ifeq ($(BUILD_LLVM_CLANG),1)
	([ ! -d $(LLVM_SRC_DIR)/tools/clang ] && \
		git clone $(LLVM_GIT_URL_CLANG) $(LLVM_SRC_DIR)/tools/clang  ) || \
		(cd $(LLVM_SRC_DIR)/tools/clang  && \
		git pull --ff-only)
	([ ! -d $(LLVM_SRC_DIR)/projects/compiler-rt ] && \
		git clone $(LLVM_GIT_URL_COMPILER_RT) $(LLVM_SRC_DIR)/projects/compiler-rt  ) || \
		(cd $(LLVM_SRC_DIR)/projects/compiler-rt  && \
		git pull --ff-only)
ifneq ($(LLVM_GIT_VER_CLANG),)
	(cd $(LLVM_SRC_DIR)/tools/clang && \
		git checkout $(LLVM_GIT_VER_CLANG))
endif # LLVM_GIT_VER_CLANG
endif # BUILD_LLVM_CLANG
ifeq ($(BUILD_LLDB),1)
	([ ! -d $(LLVM_SRC_DIR)/tools/lldb ] && \
		git clone $(LLVM_GIT_URL_LLDB) $(LLVM_SRC_DIR)/tools/lldb  ) || \
		(cd $(LLVM_SRC_DIR)/tools/lldb  && \
		git pull --ff-only)
ifneq ($(LLVM_GIT_VER_LLDB),)
	(cd $(LLVM_SRC_DIR)/tools/lldb && \
		git checkout $(LLVM_GIT_VER_LLDB))
endif # LLVM_GIT_VER_CLANG
endif # BUILD_LLDB
ifeq ($(USE_POLLY),1)
	([ ! -d $(LLVM_SRC_DIR)/tools/polly ] && \
		git clone $(LLVM_GIT_URL_POLLY) $(LLVM_SRC_DIR)/tools/polly  ) || \
		(cd $(LLVM_SRC_DIR)/tools/polly  && \
		git pull --ff-only)
ifneq ($(LLVM_GIT_VER_POLLY),)
	(cd $(LLVM_SRC_DIR)/tools/polly && \
		git checkout $(LLVM_GIT_VER_POLLY))
endif # LLVM_GIT_VER_POLLY
endif # USE_POLLY
endif # LLVM_VER
	# touch some extra files to ensure bisect works pretty well
	touch -c $(LLVM_SRC_DIR).extracted
	touch -c $(LLVM_SRC_DIR)/configure
	touch -c $(LLVM_SRC_DIR)/CMakeLists.txt
	echo 1 > $@

# Apply version-specific LLVM patches
LLVM_PATCH_PREV :=
define LLVM_PATCH
$$(LLVM_SRC_DIR)/$1.patch-applied: $$(LLVM_SRC_DIR)/source-extracted | $$(SRCDIR)/patches/$1.patch $$(LLVM_PATCH_PREV)
	cd $$(LLVM_SRC_DIR) && patch -p1 < $$(SRCDIR)/patches/$1.patch
	echo 1 > $$@
LLVM_PATCH_PREV := $$(LLVM_SRC_DIR)/$1.patch-applied
endef

ifeq ($(LLVM_VER),3.3)
$(eval $(call LLVM_PATCH,llvm-3.3))
$(eval $(call LLVM_PATCH,instcombine-llvm-3.3))
$(eval $(call LLVM_PATCH,int128-vector.llvm-3.3))
$(eval $(call LLVM_PATCH,osx-10.10.llvm-3.3))
$(eval $(call LLVM_PATCH,win64-int128.llvm-3.3))
else ifeq ($(LLVM_VER_SHORT),3.7)
ifeq ($(LLVM_VER),3.7.0)
$(eval $(call LLVM_PATCH,llvm-3.7.0))
endif
$(eval $(call LLVM_PATCH,llvm-3.7.1))
$(eval $(call LLVM_PATCH,llvm-3.7.1_2))
$(eval $(call LLVM_PATCH,llvm-3.7.1_3))
$(eval $(call LLVM_PATCH,llvm-3.7.1_symlinks))
$(eval $(call LLVM_PATCH,llvm-3.8.0_bindir))
$(eval $(call LLVM_PATCH,llvm-D14260))
$(eval $(call LLVM_PATCH,llvm-nodllalias))
$(eval $(call LLVM_PATCH,llvm-D21271-instcombine-tbaa-3.7))
$(eval $(call LLVM_PATCH,llvm-win64-reloc-dwarf))
$(eval $(call LLVM_PATCH,llvm-3.7.1_destsharedlibdir))
$(eval $(call LLVM_PATCH,llvm-arm-fix-prel31))
else ifeq ($(LLVM_VER_SHORT),3.8)
ifeq ($(LLVM_VER),3.8.0)
$(eval $(call LLVM_PATCH,llvm-D17326_unpack_load))
endif
ifeq ($(LLVM_VER),3.8.1)
$(eval $(call LLVM_PATCH,llvm-3.8.1-version))
endif
$(eval $(call LLVM_PATCH,llvm-3.7.1_3)) # Remove for 3.9
$(eval $(call LLVM_PATCH,llvm-D14260))
$(eval $(call LLVM_PATCH,llvm-3.8.0_bindir)) # Remove for 3.9
$(eval $(call LLVM_PATCH,llvm-3.8.0_winshlib)) # Remove for 3.9
$(eval $(call LLVM_PATCH,llvm-D25865-cmakeshlib))
$(eval $(call LLVM_PATCH,llvm-nodllalias)) # Remove for 3.9
# Cygwin and openSUSE still use win32-threads mingw, https://llvm.org/bugs/show_bug.cgi?id=26365
$(eval $(call LLVM_PATCH,llvm-3.8.0_threads))
# fix replutil test on unix
$(eval $(call LLVM_PATCH,llvm-D17165-D18583)) # Remove for 3.9
# Segfault for aggregate load
$(eval $(call LLVM_PATCH,llvm-D17712)) # Remove for 3.9
$(eval $(call LLVM_PATCH,llvm-PR26180)) # Remove for 3.9
$(eval $(call LLVM_PATCH,llvm-PR27046)) # Remove for 3.9
$(eval $(call LLVM_PATCH,llvm-3.8.0_ppc64_SUBFC8)) # Remove for 3.9
$(eval $(call LLVM_PATCH,llvm-D21271-instcombine-tbaa-3.8)) # Remove for 3.9
$(eval $(call LLVM_PATCH,llvm-win64-reloc-dwarf))
$(eval $(call LLVM_PATCH,llvm-arm-fix-prel31))
else ifeq ($(LLVM_VER_SHORT),3.9)
ifeq ($(LLVM_VER),3.9.0)
# fix lowering for atomics on ppc
$(eval $(call LLVM_PATCH,llvm-rL279933-ppc-atomicrmw-lowering)) # Remove for 4.0
$(eval $(call LLVM_PATCH,llvm-r282182)) # Remove for 4.0
$(eval $(call LLVM_PATCH,llvm-3.9.0_cygwin)) # R283427, Remove for 4.0
endif
$(eval $(call LLVM_PATCH,llvm-PR22923)) # Remove for 4.0
$(eval $(call LLVM_PATCH,llvm-arm-fix-prel31)) # Remove for 4.0
$(eval $(call LLVM_PATCH,llvm-D25865-cmakeshlib)) # Remove for 4.0
# Cygwin and openSUSE still use win32-threads mingw, https://llvm.org/bugs/show_bug.cgi?id=26365
$(eval $(call LLVM_PATCH,llvm-3.9.0_threads))
$(eval $(call LLVM_PATCH,llvm-3.9.0_win64-reloc-dwarf)) # modified version applied as R290809, Remove for 4.0
$(eval $(call LLVM_PATCH,llvm-3.9.0_D27296-libssp))
$(eval $(call LLVM_PATCH,llvm-D27609-AArch64-UABS_G3)) # Remove for 4.0
$(eval $(call LLVM_PATCH,llvm-D27629-AArch64-large_model))
# patches for NVPTX
$(eval $(call LLVM_PATCH,llvm-D9168_argument_alignment)) # Remove for 4.0
$(eval $(call LLVM_PATCH,llvm-D23597_sdag_names)) # Dep for D24300, remove for 4.0
$(eval $(call LLVM_PATCH,llvm-D24300_ptx_intrinsics)) # Remove for 4.0
$(eval $(call LLVM_PATCH,llvm-D27389)) # Julia issue #19792, Remove for 4.0
$(eval $(call LLVM_PATCH,llvm-D27397)) # Julia issue #19792, Remove for 4.0
$(eval $(call LLVM_PATCH,llvm-D28009)) # Julia issue #19792, Remove for 4.0
$(eval $(call LLVM_PATCH,llvm-D28215_FreeBSD_shlib))
$(eval $(call LLVM_PATCH,llvm-D28221-avx512)) # mentioned in issue #19797
$(eval $(call LLVM_PATCH,llvm-PR276266)) # Issue #19976, Remove for 4.0
$(eval $(call LLVM_PATCH,llvm-PR278088)) # Issue #19976, Remove for 4.0
$(eval $(call LLVM_PATCH,llvm-PR277939)) # Issue #19976, Remove for 4.0
$(eval $(call LLVM_PATCH,llvm-PR278321)) # Issue #19976, Remove for 4.0
$(eval $(call LLVM_PATCH,llvm-PR278923)) # Issue #19976, Remove for 4.0
$(eval $(call LLVM_PATCH,llvm-D28759-loopclearance))
$(eval $(call LLVM_PATCH,llvm-D28786-callclearance))
$(eval $(call LLVM_PATCH,llvm-rL293230-icc17-cmake)) # Remove for 4.0
$(eval $(call LLVM_PATCH,llvm-PR29010-i386-xmm)) # Remove for 4.0
$(eval $(call LLVM_PATCH,llvm-D32593))
$(eval $(call LLVM_PATCH,llvm-D33179))
$(eval $(call LLVM_PATCH,llvm-3.9.0-D37576-NVPTX-sm_70)) # NVPTX, Remove for 6.0
ifeq ($(BUILD_LLVM_CLANG),1)
$(eval $(call LLVM_PATCH,compiler_rt-3.9-glibc_2.25.90)) # Remove for 5.0
endif
endif # LLVM_VER

ifeq ($(LLVM_VER),3.7.1)
ifeq ($(BUILD_LLDB),1)
$(eval $(call LLVM_PATCH,lldb-3.7.1))
endif
ifeq ($(BUILD_LLVM_CLANG),1)
$(eval $(call LLVM_PATCH,compiler-rt-3.7.1))
endif
endif
$(LLVM_BUILDDIR_withtype)/build-configured: $(LLVM_PATCH_PREV)

ifeq ($(LLVM_USE_CMAKE),1)

$(LLVM_BUILDDIR_withtype)/build-configured: $(LLVM_SRC_DIR)/source-extracted | $(llvm_python_workaround) $(LIBCXX_DEPENDENCY)
	mkdir -p $(dir $@)
	cd $(dir $@) && \
		export PATH=$(llvm_python_workaround):$$PATH && \
		$(CMAKE) $(LLVM_SRC_DIR) $(CMAKE_GENERATOR_COMMAND) $(CMAKE_COMMON) $(LLVM_CMAKE) \
		|| { echo '*** To install a newer version of cmake, run contrib/download_cmake.sh ***' && false; }
	echo 1 > $@

$(LLVM_BUILDDIR_withtype)/build-compiled: $(LLVM_BUILDDIR_withtype)/build-configured | $(llvm_python_workaround)
	cd $(LLVM_BUILDDIR_withtype) && \
		export PATH=$(llvm_python_workaround):$$PATH && \
		$(if $(filter $(CMAKE_GENERATOR),make), \
		  $(MAKE), \
		  $(CMAKE) --build .)
	echo 1 > $@

else

$(LLVM_BUILDDIR_withtype)/build-configured: $(LLVM_SRC_DIR)/source-extracted | $(llvm_python_workaround) $(LIBCXX_DEPENDENCY)
	mkdir -p $(dir $@)
	cd $(dir $@) && \
		export PATH=$(llvm_python_workaround):$$PATH && \
		$(LLVM_SRC_DIR)/configure $(CONFIGURE_COMMON) $(LLVM_FLAGS)
	echo 1 > $@

$(LLVM_BUILDDIR_withtype)/build-compiled: $(LLVM_BUILDDIR_withtype)/build-configured | $(llvm_python_workaround)
	cd $(LLVM_BUILDDIR_withtype) && \
		export PATH=$(llvm_python_workaround):$$PATH && \
		$(MAKE) $(LLVM_MFLAGS) $(MAKE_COMMON)
	echo 1 > $@

endif # LLVM_USE_CMAKE

$(LLVM_BUILDDIR_withtype)/build-checked: $(LLVM_BUILDDIR_withtype)/build-compiled | $(llvm_python_workaround)
ifeq ($(OS),$(BUILD_OS))
	cd $(LLVM_BUILDDIR_withtype) && \
		export PATH=$(llvm_python_workaround):$$PATH && \
		$(if $(filter $(LLVM_USE_CMAKE),1), \
		  $(CMAKE) --build . --target check, \
		  $(MAKE) $(LLVM_MFLAGS) check)
endif
	echo 1 > $@

$(build_prefix)/manifest/llvm: | $(llvm_python_workaround)

ifeq ($(LLVM_USE_CMAKE),1)
LLVM_INSTALL = \
	cd $1 && $$(CMAKE) -DCMAKE_INSTALL_PREFIX="$2$$(build_prefix)" -P cmake_install.cmake
ifeq ($(OS), WINNT)
LLVM_INSTALL += && cp $2$$(build_shlibdir)/LLVM.dll $2$$(build_depsbindir)
endif
else
LLVM_INSTALL = \
	$(call MAKE_INSTALL,$1,$2,$3 $$(LLVM_MFLAGS) PATH="$$(llvm_python_workaround):$$$$PATH" DestSharedLibDir="$2$$(build_shlibdir)")
endif # LLVM_USE_CMAKE

$(eval $(call staged-install,llvm,llvm-$$(LLVM_VER)/build_$$(LLVM_BUILDTYPE), \
	LLVM_INSTALL,,,))

clean-llvm:
	-rm $(LLVM_BUILDDIR_withtype)/build-configured $(LLVM_BUILDDIR_withtype)/build-compiled
	-$(MAKE) -C $(LLVM_BUILDDIR_withtype) clean

distclean-llvm:
	-rm -rf $(LLVM_TAR) $(LLVM_CLANG_TAR) \
		$(LLVM_COMPILER_RT_TAR) $(LLVM_LIBCXX_TAR) $(LLVM_LLDB_TAR) \
		$(LLVM_SRC_DIR) $(LLVM_BUILDDIR_withtype)


ifneq ($(LLVM_VER),svn)
get-llvm: $(LLVM_TAR) $(LLVM_CLANG_TAR) $(LLVM_COMPILER_RT_TAR) $(LLVM_LIBCXX_TAR) $(LLVM_LLDB_TAR)
else
get-llvm: $(LLVM_SRC_DIR)/source-extracted
endif
extract-llvm: $(LLVM_SRC_DIR)/source-extracted
configure-llvm: $(LLVM_BUILDDIR_withtype)/build-configured
compile-llvm: $(LLVM_BUILDDIR_withtype)/build-compiled
fastcheck-llvm: #none
check-llvm: $(LLVM_BUILDDIR_withtype)/build-checked
#todo: LLVM make check target is broken on julia.mit.edu (and really slow elsewhere)


ifeq ($(LLVM_VER),svn)
update-llvm:
	(cd $(LLVM_SRC_DIR); git pull --ff-only)
	([ -d "$(LLVM_SRC_DIR)/tools/clang"  ] || exit 0;          cd $(LLVM_SRC_DIR)/tools/clang; git pull --ff-only)
	([ -d "$(LLVM_SRC_DIR)/projects/compiler-rt" ] || exit 0;  cd $(LLVM_SRC_DIR)/projects/compiler-rt; git pull --ff-only)
	([ -d "$(LLVM_SRC_DIR)/tools/lldb" ] || exit 0;            cd $(LLVM_SRC_DIR)/tools/lldb; git pull --ff-only)
ifeq ($(USE_POLLY),1)
	([ -d "$(LLVM_SRC_DIR)/tools/polly" ] || exit 0;           cd $(LLVM_SRC_DIR)/tools/polly; git pull --ff-only)
endif
endif
