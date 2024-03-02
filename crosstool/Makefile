.PHONY: all
all: build/crosstool-ng-toolchain/gcc-aarch64-unknown-linux-gnu

downloads/crosstool-ng-1.26.0.tar.xz:
	wget 'https://github.com/crosstool-ng/crosstool-ng/releases/download/crosstool-ng-1.26.0/crosstool-ng-1.26.0.tar.xz' -O $@
	touch $@

downloads/gprbuild-x86_64-linux-22.0.0-1.tar.gz:
	wget 'https://github.com/alire-project/GNAT-FSF-builds/releases/download/gprbuild-22.0.0-1/gprbuild-x86_64-linux-22.0.0-1.tar.gz' -O $@
	touch $@

build/gprbuild-x86_64-linux-22.0.0-1: downloads/gprbuild-x86_64-linux-22.0.0-1.tar.gz
	mkdir -p build
	tar -xf 'downloads/gprbuild-x86_64-linux-22.0.0-1.tar.gz' -C build
	touch $@

build/crosstool-ng-1.26.0/build/bin/ct-ng: downloads/crosstool-ng-1.26.0.tar.xz
	mkdir -p build
	tar -xf 'downloads/crosstool-ng-1.26.0.tar.xz' -C build
	cd build/crosstool-ng-1.26.0 && ./configure --prefix $(PWD)/build/crosstool-ng-1.26.0/build
	make -C build/crosstool-ng-1.26.0
	make -C build/crosstool-ng-1.26.0 install
	touch $@

build/crosstool-ng-toolchain/gcc-aarch64-unknown-linux-gnu: build/crosstool-ng-1.26.0/build/bin/ct-ng crosstool-ng.config build/gprbuild-x86_64-linux-22.0.0-1
	mkdir -p build/crosstool-ng-toolchain
	cp -u crosstool-ng.config build/crosstool-ng-toolchain/.config
	cd build/crosstool-ng-toolchain && ../crosstool-ng-1.26.0/build/bin/ct-ng build
	chmod -R u+w $@
	mkdir build/crosstool-ng-toolchain/gcc-aarch64-unknown-linux-gnu/share/gpr
	cp template.cgpr build/crosstool-ng-toolchain/gcc-aarch64-unknown-linux-gnu/share/gpr/aarch64-unknown-linux-gnu.cgpr
	sed -i 's/@@CONFIGURE_NAME@@/aarch64-unknown-linux-gnu/g' build/crosstool-ng-toolchain/gcc-aarch64-unknown-linux-gnu/share/gpr/aarch64-unknown-linux-gnu.cgpr
	sed -i 's/@@TARGET_NAME@@/aarch64-unknown-linux-gnu/g' build/crosstool-ng-toolchain/gcc-aarch64-unknown-linux-gnu/share/gpr/aarch64-unknown-linux-gnu.cgpr
	sed -i 's:@@TOOLCHAIN_DIR@@:'`pwd`'/build/crosstool-ng-toolchain/gcc-aarch64-unknown-linux-gnu:g'	build/crosstool-ng-toolchain/gcc-aarch64-unknown-linux-gnu/share/gpr/aarch64-unknown-linux-gnu.cgpr
	sed -i 's/@@TOOLCHAIN_VERN@@/13.2.0/g' build/crosstool-ng-toolchain/gcc-aarch64-unknown-linux-gnu/share/gpr/aarch64-unknown-linux-gnu.cgpr
	sed -i 's/@@TOOLCHAIN_VERS@@/13.2.0/g' build/crosstool-ng-toolchain/gcc-aarch64-unknown-linux-gnu/share/gpr/aarch64-unknown-linux-gnu.cgpr
	sed -i 's:@@GPRBUILD_DIR@@:'`pwd`'/build/gprbuild-x86_64-linux-22.0.0-1:g' build/crosstool-ng-toolchain/gcc-aarch64-unknown-linux-gnu/share/gpr/aarch64-unknown-linux-gnu.cgpr
	touch $@

.PHONY: clean
clean:
	rm -rf build/* download/*
