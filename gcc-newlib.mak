GCC_VERSION    	:= 4.8.0
GCC_SOURCE     	:= $(TOOLCHAIN_SRCDIR)/gcc-$(GCC_VERSION).tar.bz2
GCC_DOWNLOAD   	:= http://ftp.gnu.org/gnu/gcc/gcc-$(GCC_VERSION)/gcc-$(GCC_VERSION).tar.bz2
GCC_PATCHES    	:= $(TOOLCHAIN_PATCHDIR)/gcc_4.8.0_multilib.diff

NEWLIB_VERSION 	:= 2.0.0
NEWLIB_SOURCE  	:= $(TOOLCHAIN_SRCDIR)/newlib-$(NEWLIB_VERSION).tar.gz
NEWLIB_DOWNLOAD	:= ftp://sourceware.org/pub/newlib/newlib-$(NEWLIB_VERSION).tar.gz
NEWLIB_PATCHES 	:= 

# Hack to build on OS X.
ifeq ($(shell uname),Darwin)
# fix compilation issue with llvm/clang (internal compiler error at runtime)
GCC_CONFENV := CC=/usr/bin/gcc CPP=/usr/bin/cpp CXX=/usr/bin/g++ LD=/usr/bin/gcc
GCC_CONFOPTS := --with-gmp=/usr/local --with-mpfr=/usr/local --with-mpc=/usr/local
endif

PATH += :$(TOOLCHAIN_ROOTDIR)/bin

# Download
$(GCC_SOURCE):
	$(call target_mkdir)
	$(call cmd_msg,WGET,$(subst $(SRC)/,,$(@)))
	$(Q)wget -c -O $(@).part $(GCC_DOWNLOAD)
	$(Q)mv $(@).part $(@)

$(NEWLIB_SOURCE):
	$(call target_mkdir)
	$(call cmd_msg,WGET,$(subst $(SRC)/,,$(@)))
	$(Q)wget -c -O $(@).part $(NEWLIB_DOWNLOAD)
	$(Q)mv $(@).part $(@)

# Extract
$(TOOLCHAIN_BUILDDIR)/.gcc_newlib-extract: $(GCC_SOURCE) $(NEWLIB_SOURCE)
	$(Q)mkdir -p $(TOOLCHAIN_BUILDDIR)

	$(call cmd_msg,EXTRACT,$(subst $(SRC)/$(SRCSUBDIR)/,,$(GCC_SOURCE)))
	$(Q)tar -C $(TOOLCHAIN_BUILDDIR) -xjf $(GCC_SOURCE)

	$(call cmd_msg,PATCH,$(subst $(TOOLCHAIN_PATCHDIR)/,,$(GCC_PATCHES)))
	$(Q)$(foreach patch,$(GCC_PATCHES), \
		cd $(TOOLCHAIN_BUILDDIR)/gcc-$(GCC_VERSION); \
		patch -Np1 -i $(patch) $(QOUTPUT); \
	)

	$(call cmd_msg,EXTRACT,$(subst $(SRC)/$(SRCSUBDIR)/,,$(NEWLIB_SOURCE)))
	$(Q)tar -C $(TOOLCHAIN_BUILDDIR) -xzf $(NEWLIB_SOURCE)

	$(call cmd_msg,PATCH,$(subst $(TOOLCHAIN_PATCHDIR)/,,$(NEWLIB_PATCHES)))
	$(Q)$(foreach patch,$(NEWLIB_PATCHES), \
		cd $(TOOLCHAIN_BUILDDIR)/newlib-$(NEWLIB_VERSION); \
		patch -Np1 -i $(patch) $(QOUTPUT); \
	)

	$(Q)ln -f -s $(TOOLCHAIN_BUILDDIR)/newlib-$(NEWLIB_VERSION)/newlib $(TOOLCHAIN_BUILDDIR)/gcc-$(GCC_VERSION)
	$(Q)ln -f -s $(TOOLCHAIN_BUILDDIR)/newlib-$(NEWLIB_VERSION)/libgloss $(TOOLCHAIN_BUILDDIR)/gcc-$(GCC_VERSION)

	$(Q)touch $(@)


# Configure
$(TOOLCHAIN_BUILDDIR)/.gcc_newlib-configure: $(TOOLCHAIN_BUILDDIR)/.gcc_newlib-extract
	$(Q)if [ -d "$(TOOLCHAIN_BUILDDIR)/gcc-build" ]; then \
		rm -rf $(TOOLCHAIN_BUILDDIR)/gcc-build; \
	fi
	$(Q)mkdir -p $(TOOLCHAIN_BUILDDIR)/gcc-build
	$(call cmd_msg,CONFIG,gcc-$(GCC_VERSION) ($(TOOLCHAIN_TARGET)))
	$(Q)cd $(TOOLCHAIN_BUILDDIR)/gcc-build; \
		$(GCC_CONFENV) ../gcc-$(GCC_VERSION)/configure \
			--prefix=$(TOOLCHAIN_ROOTDIR) \
			--target=$(TOOLCHAIN_TARGET) \
			--enable-multilib \
			--enable-languages="c,c++" \
			--with-newlib \
			--with-gnu-as \
			--with-gnu-ld \
			--disable-nls \
			--disable-shared \
			--disable-threads \
			--with-headers=newlib/libc/include \
			--disable-libssp \
			--disable-libstdcxx-pch \
			--disable-libmudflap \
			--disable-libgomp \
			--disable-werror \
			--with-system-zlib \
			--disable-newlib-supplied-syscalls \
			$(QOUTPUT) \
			$(GCC_CONFOPTS)
	$(Q)touch  $(@)

# Compile
$(TOOLCHAIN_BUILDDIR)/.gcc_newlib-compile: $(TOOLCHAIN_BUILDDIR)/.gcc_newlib-configure
	$(call cmd_msg,COMPILE,gcc-$(GCC_VERSION) ($(TOOLCHAIN_TARGET)))
	$(Q)cd $(TOOLCHAIN_BUILDDIR)/gcc-build; \
		$(MAKE) $(SUBMAKEFLAGS) $(MAKEFLAGS) $(QOUTPUT)
	$(Q)touch $(@)


# Install
$(TOOLCHAIN_BUILDDIR)/.gcc_newlib-install: $(TOOLCHAIN_BUILDDIR)/.gcc_newlib-compile
	$(call cmd_msg,INSTALL,gcc-$(GCC_VERSION) ($(TOOLCHAIN_TARGET)))
	$(Q)cd $(TOOLCHAIN_BUILDDIR)/gcc-build; $(MAKE) $(MAKEFLAGS) install $(QOUTPUT)
	$(Q)touch $(@)


GCC_TARGET := $(TOOLCHAIN_BUILDDIR)/.gcc_newlib-install
all-gcc: $(GCC_TARGET)
.PHONY: all-gcc

all: $(GCC_TARGET)
download: $(GCC_SOURCE) $(NEWLIB_SOURCE)
