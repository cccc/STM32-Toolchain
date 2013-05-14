OPENOCD_VERSION    := 0.6.1
OPENOCD_SOURCE     := $(TOOLCHAIN_SRCDIR)/openocd-$(OPENOCD_VERSION).tar.bz2
OPENOCD_DOWNLOAD   := http://downloads.sourceforge.net/project/openocd/openocd/$(OPENOCD_VERSION)/openocd-$(OPENOCD_VERSION).tar.bz2
OPENOCD_PATCHES    := $(TOOLCHAIN_PATCHDIR)/openocd_arm7m_registers.diff

# Download
$(OPENOCD_SOURCE):
	$(call target_mkdir)
	$(call cmd_msg,WGET,$(subst $(SRC)/,,$(@)))
	$(Q)wget -c -O $(@).part $(OPENOCD_DOWNLOAD)
	$(Q)mv $(@).part $(@)


# Extract
$(TOOLCHAIN_BUILDDIR)/.openocd-extract: $(OPENOCD_SOURCE)
	$(Q)mkdir -p $(TOOLCHAIN_BUILDDIR)
	$(call cmd_msg,EXTRACT,$(subst $(SRC)/$(SRCSUBDIR)/,,$(OPENOCD_SOURCE)))
	$(Q)tar -C $(TOOLCHAIN_BUILDDIR) -xjf $(OPENOCD_SOURCE)
	$(call cmd_msg,PATCH,$(subst $(TOOLCHAIN_PATCHDIR)/,,$(OPENOCD_PATCHES)))
	$(Q)$(foreach patch,$(OPENOCD_PATCHES), \
		cd $(TOOLCHAIN_BUILDDIR)/openocd-$(OPENOCD_VERSION); \
		patch -Np1 -i $(patch) $(QOUTPUT); \
	)
	$(Q)touch $(@)


# Configure
$(TOOLCHAIN_BUILDDIR)/.openocd-configure: $(TOOLCHAIN_BUILDDIR)/.openocd-extract
	$(Q)if [ -d "$(TOOLCHAIN_BUILDDIR)/openocd-build" ]; then \
		rm -rf $(TOOLCHAIN_BUILDDIR)/openocd-build; \
	fi
	$(Q)mkdir -p $(TOOLCHAIN_BUILDDIR)/openocd-build
	$(call cmd_msg,CONFIG,openocd-$(OPENOCD_VERSION) ($(TOOLCHAIN_TARGET)))
	$(Q)cd $(TOOLCHAIN_BUILDDIR)/openocd-build; \
		../openocd-$(OPENOCD_VERSION)/configure \
		--enable-maintainer-mode \
		--disable-option-checking \
		--disable-werror \
		--prefix=$(TOOLCHAIN_ROOTDIR) \
		--enable-stlink \
		$(QOUTPUT)
	$(Q)touch $(@)


# Compile
$(TOOLCHAIN_BUILDDIR)/.openocd-compile: $(TOOLCHAIN_BUILDDIR)/.openocd-configure
	$(call cmd_msg,COMPILE,openocd-$(OPENOCD_VERSION) ($(TOOLCHAIN_TARGET)))
	$(Q)cd $(TOOLCHAIN_BUILDDIR)/openocd-build; $(MAKE) $(SUBMAKEFLAGS) $(MAKEFLAGS) all $(QOUTPUT)
	$(Q)touch $(@)


# Install
$(TOOLCHAIN_BUILDDIR)/.openocd-install: $(TOOLCHAIN_BUILDDIR)/.openocd-compile
	$(call cmd_msg,INSTALL,openocd-$(OPENOCD_VERSION) ($(TOOLCHAIN_TARGET)))
	$(Q)cd $(TOOLCHAIN_BUILDDIR)/openocd-build; $(MAKE) $(MAKEFLAGS) install $(QOUTPUT)
	$(Q)touch $(@)


# Download, build and install openocd to run on the host system.
OPENOCD_TARGET := $(TOOLCHAIN_BUILDDIR)/.openocd-install
all-openocd: $(OPENOCD_TARGET)
.PHONY: all-openocd

all: $(OPENOCD_TARGET)
download: $(OPENOCD_SOURCE)
