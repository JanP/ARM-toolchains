.DELETE_ON_ERROR:

BINUTILS:=binutils-2.40
GDB:=gdb-13.1
GCC:=gcc-13.1.0
NEWLIB:=newlib-4.3.0.20230120

PARALLEL=-j 8

TARGETS:=arm-none-eabi aarch64-elf

default: $(addsuffix .tar.gz,$(TARGETS))

arm-none-eabi.tar.gz: arm-none-eabi
	tar zcvf $@ $<

aarch64-elf.tar.gz: aarch64-elf
	tar zcvf $@ $<

arm-none-eabi: $(addsuffix /arm-none-eabi/.touch,$(addprefix generated/,$(BINUTILS) $(GCC) $(GDB)))
aarch64-elf: $(addsuffix /aarch64-elf/.touch,$(addprefix generated/,$(BINUTILS) $(GCC) $(GDB)))

$(BINUTILS).tar.gz:
	wget https://ftp.gnu.org/gnu/binutils/binutils-2.40.tar.gz

$(GDB).tar.gz:
	wget https://ftp.gnu.org/gnu/gdb/gdb-13.1.tar.gz

$(GCC).tar.gz:
	wget https://ftp.gnu.org/gnu/gcc/gcc-13.1.0.tar.gz

$(NEWLIB).tar.gz:
	wget ftp://sourceware.org/pub/newlib/newlib-4.3.0.20230120.tar.gz

generated/%: %.tar.gz
	mkdir -p generated
	tar -C generated -xzf $<

BINUTILS_FLAGS:=--enable-interwork --enable-plugins --disable-nls

define binutils_rule
generated/$(BINUTILS)/$1/.touch: generated/$(BINUTILS)
	mkdir -p generated/$(BINUTILS)/$1
	cd generated/$(BINUTILS)/$1 && ../configure --target=$1 --prefix=$(PWD)/$1 $(BINUTILS_FLAGS)
	cd generated/$(BINUTILS)/$1 && $(MAKE) $(PARALLEL) && $(MAKE) install
	touch generated/$(BINUTILS)/$1/.touch
endef

GDB_FLAGS:=--disable-nls CFLAGS=-UFORTIFY_SOURCE

define gdb_rule
generated/$(GDB)/$1/.touch: generated/$(GDB)
	mkdir -p generated/$(GDB)/$1
	cd generated/$(GDB)/$1 && ../configure --target=$1 --prefix=$(PWD)/$1 $(GDB_FLAGS)
	cd generated/$(GDB)/$1 && $(MAKE) $(PARALLEL) && $(MAKE) install
	touch generated/$(GDB)/$1/.touch
endef

GCC_FLAGS:=--enable-languages="c,c++" --with-newlib --enable-plugins --enable-newlib-io-long-long
GCC_FLAGS+=--enable-newlib-io-c99-formats --enable-newlib-reent-check-verify --enable-newlib-register-fini
GCC_FLAGS+=--enable-newlib-retargetable-locking --disable-newlib-supplied-syscalls --disable-nls

define gcc_rule
generated/$(GCC)/$1/.touch: generated/$(GCC) generated/$(NEWLIB) generated/$(BINUTILS)/$1/.touch
	ln -s -f $(PWD)/generated/$(NEWLIB)/newlib generated/$(GCC)/newlib
	mkdir -p generated/$(GCC)/$1
	cd generated/$(GCC)/$1 && ../configure --target=$1 --prefix=$(PWD)/$1 $(GCC_FLAGS) $(if "$1" "aarch64-elf",--with-multilib-list=default,--with-multilib-list=rmprofile)
	cd generated/$(GCC)/$1 && $(MAKE) $(PARALLEL) && $(MAKE) install
	touch generated/$(GCC)/$1.touch
endef

$(foreach TARGET,$(TARGETS),$(eval $(call binutils_rule,$(TARGET))))
$(foreach TARGET,$(TARGETS),$(eval $(call gdb_rule,$(TARGET))))
$(foreach TARGET,$(TARGETS),$(eval $(call gcc_rule,$(TARGET))))

clean:
	rm -rf generated $(TARGETS) $(foreach TARGET,$(TARGETS),$(addsuffix .tar.gz,$(TARGET)))
