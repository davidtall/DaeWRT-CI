#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-only
#
# Copyright (C) ImmortalWrt.org

DEFAULT_COLOR="\033[0m"
BLUE_COLOR="\033[36m"
GREEN_COLOR="\033[32m"
RED_COLOR="\033[31m"
YELLOW_COLOR="\033[33m"

function __error_msg() {
	echo -e "${RED_COLOR}[ERROR]${DEFAULT_COLOR} $*"
}

function __info_msg() {
	echo -e "${BLUE_COLOR}[INFO]${DEFAULT_COLOR} $*"
}

function __success_msg() {
	echo -e "${GREEN_COLOR}[SUCCESS]${DEFAULT_COLOR} $*"
}

function __warning_msg() {
	echo -e "${YELLOW_COLOR}[WARNING]${DEFAULT_COLOR} $*"
}

function check_system() {
	__info_msg "Checking system info..."

	VERSION_CODENAME="$(source /etc/os-release; echo "$VERSION_CODENAME")"

	case "$VERSION_CODENAME" in
	"bionic")
		GCC_VERSION="9"
		LLVM_VERSION="18"
		NODE_DISTRO="$VERSION_CODENAME"
		NODE_KEY="nodesource.gpg.key"
		NODE_VERSION="18"
		UBUNTU_CODENAME="$VERSION_CODENAME"
		VERSION_PACKAGE="libpython3.6-dev python2.7 python3.6"
		;;
	"buster")
		DISTRO_PREFIX="debian-archive/"
		DISTRO_SECUTIRY_PATH="buster/updates"
		GCC_VERSION="9"
		LLVM_VERSION="18"
		UBUNTU_CODENAME="bionic"
		VERSION_PACKAGE="python2"
		;;
	"focal")
		GCC_VERSION="10"
		LLVM_VERSION="18"
		UBUNTU_CODENAME="$VERSION_CODENAME"
		VERSION_PACKAGE="python2"
		;;
	"bullseye")
		BPO_FLAG="-t $VERSION_CODENAME-backports"
		BPO_DISTRO_PREFIX="debian-archive/"
		GCC_VERSION="10"
		LLVM_VERSION="18"
		UBUNTU_CODENAME="focal"
		VERSION_PACKAGE="python2"
		;;
	"jammy")
		GCC_VERSION="10"
		LLVM_VERSION="18"
		UBUNTU_CODENAME="$VERSION_CODENAME"
		VERSION_PACKAGE="python2"
		;;
	"bookworm")
		APT_COMP="non-free-firmware"
		BPO_FLAG="-t $VERSION_CODENAME-backports"
		GCC_VERSION="12"
		LLVM_VERSION="18"
		UBUNTU_CODENAME="jammy"
		;;
	"noble")
		GCC_VERSION="13"
		LLVM_VERSION="18"
		UBUNTU_CODENAME="$VERSION_CODENAME"
		;;
	"trixie")
		APT_COMP="non-free-firmware"
		BPO_FLAG="-t $VERSION_CODENAME-backports"
		GCC_VERSION="13"
		LLVM_VERSION="18"
		UBUNTU_CODENAME="noble"
		;;
	*)
		__error_msg "Unsupported OS, use Ubuntu 20.04 instead."
		exit 1
		;;
	esac

	[ "$(uname -m)" == "x86_64" ] || { __error_msg "Unsupported architecture, use AMD64 instead." && exit 1; }

	[ "$(whoami)" == "root" ] || { __error_msg "You must run this script as root." && exit 1; }
}

function check_network() {
	__info_msg "Checking network..."

	curl -s "myip.ipip.net" | grep -qo "中国" && CHN_NET=1
	curl --connect-timeout 10 "baidu.com" > "/dev/null" 2>&1 || { __warning_msg "Your network is not suitable for compiling OpenWrt!"; }
	curl --connect-timeout 10 "google.com" > "/dev/null" 2>&1 || { __warning_msg "Your network is not suitable for compiling OpenWrt!"; }
}

function update_apt_source() {
	__info_msg "Updating apt source lists..."
	set -x

	apt update -y
	apt install -y apt-transport-https gnupg2

	mkdir -p "/etc/apt/keyrings"
	mkdir -p "/etc/apt/sources.list.d"
	mkdir -p "/etc/apt/trusted.gpg.d"

	if [ -n "$CHN_NET" ]; then
		mv "/etc/apt/sources.list" "/etc/apt/sources.list.bak"
		mv "/etc/apt/sources.list.d/debian.sources" "/etc/apt/sources.list.d/debian.sources.bak"
		mv "/etc/apt/sources.list.d/ubuntu.sources" "/etc/apt/sources.list.d/ubuntu.sources.bak"

		if [ "$VERSION_CODENAME" == "$UBUNTU_CODENAME" ]; then
			cat <<-EOF >"/etc/apt/sources.list"
				deb https://mirrors.cloud.tencent.com/ubuntu/ $VERSION_CODENAME main restricted universe multiverse
				deb-src https://mirrors.cloud.tencent.com/ubuntu/ $VERSION_CODENAME main restricted universe multiverse

				deb https://mirrors.cloud.tencent.com/ubuntu/ $VERSION_CODENAME-security main restricted universe multiverse
				deb-src https://mirrors.cloud.tencent.com/ubuntu/ $VERSION_CODENAME-security main restricted universe multiverse

				deb https://mirrors.cloud.tencent.com/ubuntu/ $VERSION_CODENAME-updates main restricted universe multiverse
				deb-src https://mirrors.cloud.tencent.com/ubuntu/ $VERSION_CODENAME-updates main restricted universe multiverse

				# deb https://mirrors.cloud.tencent.com/ubuntu/ $VERSION_CODENAME-proposed main restricted universe multiverse
				# deb-src https://mirrors.cloud.tencent.com/ubuntu/ $VERSION_CODENAME-proposed main restricted universe multiverse

				deb https://mirrors.cloud.tencent.com/ubuntu/ $VERSION_CODENAME-backports main restricted universe multiverse
				deb-src https://mirrors.cloud.tencent.com/ubuntu/ $VERSION_CODENAME-backports main restricted universe multiverse
			EOF
		elif [ "$VERSION_CODENAME" == "buster" ]; then
			cat <<-EOF > "/etc/apt/sources.list"
			deb https://mirrors.tuna.tsinghua.edu.cn/debian-elts $VERSION_CODENAME main contrib non-free
			EOF
			curl -fsL "https://deb.freexian.com/extended-lts/archive-key.gpg" -o "/etc/apt/trusted.gpg.d/extended-lts.gpg"
		else
			cat <<-EOF > "/etc/apt/sources.list"
				deb https://mirrors.cloud.tencent.com/${DISTRO_PREFIX}debian/ $VERSION_CODENAME main contrib non-free${APT_COMP:+ $APT_COMP}
				deb-src https://mirrors.cloud.tencent.com/${DISTRO_PREFIX}debian/ $VERSION_CODENAME main contrib non-free${APT_COMP:+ $APT_COMP}

				deb https://mirrors.cloud.tencent.com/${DISTRO_PREFIX}debian-security ${DISTRO_SECUTIRY_PATH:-$VERSION_CODENAME-security} main contrib non-free${APT_COMP:+ $APT_COMP}
				deb-src https://mirrors.cloud.tencent.com/${DISTRO_PREFIX}debian-security ${DISTRO_SECUTIRY_PATH:-$VERSION_CODENAME-security} main contrib non-free${APT_COMP:+ $APT_COMP}

				deb https://mirrors.cloud.tencent.com/${DISTRO_PREFIX}debian/ $VERSION_CODENAME-updates main contrib non-free${APT_COMP:+ $APT_COMP}
				deb-src https://mirrors.cloud.tencent.com/${DISTRO_PREFIX}debian/ $VERSION_CODENAME-updates main contrib non-free${APT_COMP:+ $APT_COMP}

				deb https://mirrors.cloud.tencent.com/${BPO_DISTRO_PREFIX:-$DISTRO_PREFIX}debian/ $VERSION_CODENAME-backports main contrib non-free${APT_COMP:+ $APT_COMP}
				deb-src https://mirrors.cloud.tencent.com/${BPO_DISTRO_PREFIX:-$DISTRO_PREFIX}debian/ $VERSION_CODENAME-backports main contrib non-free${APT_COMP:+ $APT_COMP}
			EOF
		fi
	else
		if [ "$VERSION_CODENAME" == "buster" ]; then
			mv "/etc/apt/sources.list" "/etc/apt/sources.list.bak"
			cat <<-EOF > "/etc/apt/sources.list"
			deb https://deb.freexian.com/extended-lts $VERSION_CODENAME main contrib non-free
			EOF
			curl -fsL "https://deb.freexian.com/extended-lts/archive-key.gpg" -o "/etc/apt/trusted.gpg.d/extended-lts.gpg"
		fi
	fi

	cat <<-EOF >"/etc/apt/sources.list.d/nodesource.list"
		deb https://deb.nodesource.com/node_${NODE_VERSION:-22}.x ${NODE_DISTRO:-nodistro} main
	EOF
	curl -fsL "https://deb.nodesource.com/gpgkey/${NODE_KEY:-nodesource-repo.gpg.key}" -o "/etc/apt/trusted.gpg.d/nodesource.asc"

	cat <<-EOF >"/etc/apt/sources.list.d/yarn.list"
		deb https://dl.yarnpkg.com/debian/ stable main
	EOF
	curl -fsL "https://dl.yarnpkg.com/debian/pubkey.gpg" -o "/etc/apt/trusted.gpg.d/yarn.asc"

	case "$VERSION_CODENAME" in
	"bionic"|"buster")
		cat <<-EOF >"/etc/apt/sources.list.d/gcc-toolchain.list"
			deb https://ppa.launchpadcontent.net/ubuntu-toolchain-r/test/ubuntu $UBUNTU_CODENAME main
			deb-src https://ppa.launchpadcontent.net/ubuntu-toolchain-r/test/ubuntu $UBUNTU_CODENAME main
		EOF
		curl -fsL "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x1e9377a2ba9ef27f" -o "/etc/apt/trusted.gpg.d/gcc-toolchain.asc"
		;;
	esac

	cat <<-EOF >"/etc/apt/sources.list.d/git-core-ubuntu-ppa.list"
		deb https://ppa.launchpadcontent.net/git-core/ppa/ubuntu $UBUNTU_CODENAME main
		deb-src https://ppa.launchpadcontent.net/git-core/ppa/ubuntu $UBUNTU_CODENAME main
	EOF
	curl -fsL "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0xf911ab184317630c59970973e363c90f8f1b6217" -o "/etc/apt/trusted.gpg.d/git-core-ubuntu-ppa.asc"

	cat <<-EOF >"/etc/apt/sources.list.d/llvm-toolchain.list"
		deb https://apt.llvm.org/$VERSION_CODENAME/ llvm-toolchain-$VERSION_CODENAME-$LLVM_VERSION main
		deb-src https://apt.llvm.org/$VERSION_CODENAME/ llvm-toolchain-$VERSION_CODENAME-$LLVM_VERSION main
	EOF
	curl -fsL "https://apt.llvm.org/llvm-snapshot.gpg.key" -o "/etc/apt/trusted.gpg.d/llvm-toolchain.asc"

	cat <<-EOF >"/etc/apt/sources.list.d/longsleep-ubuntu-golang-backports-$UBUNTU_CODENAME.list"
		deb https://ppa.launchpadcontent.net/longsleep/golang-backports/ubuntu $UBUNTU_CODENAME main
		deb-src https://ppa.launchpadcontent.net/longsleep/golang-backports/ubuntu $UBUNTU_CODENAME main
	EOF
	curl -fsL "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x876b22ba887ca91614b5323fc631127f87fa12d1" -o "/etc/apt/trusted.gpg.d/longsleep-ubuntu-golang-backports-$UBUNTU_CODENAME.asc"

	cat <<-EOF >"/etc/apt/sources.list.d/github-cli.list"
		deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main
	EOF
	curl -fsL "https://cli.github.com/packages/githubcli-archive-keyring.gpg" -o "/etc/apt/keyrings/githubcli-archive-keyring.gpg"

	if [ -n "$CHN_NET" ]; then
		sed -i -e "s,apt.llvm.org,mirrors.tuna.tsinghua.edu.cn/llvm-apt,g" -e "s,^deb-src,# deb-src,g" "/etc/apt/sources.list.d/llvm-toolchain.list"
		sed -i "s,ppa.launchpadcontent.net,launchpad.proxy.ustclug.org,g" "/etc/apt/sources.list.d"/*
	fi

	apt update -y $BPO_FLAG

	set +x
}
function install_dependencies() {
	__info_msg "Installing dependencies..."
	set -x

	apt full-upgrade -y $BPO_FLAG
	apt install -y $BPO_FLAG ack antlr3 asciidoc autoconf automake autopoint binutils bison \
		build-essential bzip2 ccache cmake cpio curl device-tree-compiler ecj fakeroot \
		fastjar flex gawk gettext genisoimage gnutls-dev gperf haveged help2man intltool \
		irqbalance jq lib32gcc-s1 libc6-dev-i386 libelf-dev libglib2.0-dev libgmp3-dev \
		libltdl-dev libmpc-dev libmpfr-dev libncurses-dev libreadline-dev libssl-dev \
		libtool libyaml-dev libz-dev lrzsz msmtp nano ninja-build p7zip p7zip-full patch \
		pkgconf libpython3-dev python3 python3-pip python3-cryptography python3-docutils \
		python3-ply python3-pyelftools python3-requests qemu-utils quilt re2c rsync scons \
		sharutils squashfs-tools subversion swig texinfo uglifyjs unzip vim wget xmlto \
		zlib1g-dev zstd xxd $VERSION_PACKAGE

	if [ -n "$CHN_NET" ]; then
		pip3 config set global.index-url "https://mirrors.aliyun.com/pypi/simple/"
		pip3 config set install.trusted-host "https://mirrors.aliyun.com"
	fi

	apt install -y git

	apt install -y $BPO_FLAG "gcc-$GCC_VERSION" "g++-$GCC_VERSION" "gcc-$GCC_VERSION-multilib" "g++-$GCC_VERSION-multilib"
	for i in "gcc-$GCC_VERSION" "g++-$GCC_VERSION" "gcc-ar-$GCC_VERSION" "gcc-nm-$GCC_VERSION" "gcc-ranlib-$GCC_VERSION"; do
		ln -svf "$i" "/usr/bin/${i%-$GCC_VERSION}"
	done
	ln -svf "/usr/bin/g++" "/usr/bin/c++"
	[ -e "/usr/include/asm" ] || ln -svf "/usr/include/$(gcc -dumpmachine)/asm" "/usr/include/asm"

	apt install -y $BPO_FLAG "clang-$LLVM_VERSION" "libclang-$LLVM_VERSION-dev" "lld-$LLVM_VERSION" "liblld-$LLVM_VERSION-dev" "llvm-$LLVM_VERSION"
	for i in "/usr/lib/llvm-$LLVM_VERSION/bin"/*; do
		ln -svf "$i" "/usr/bin/${i##*/}"
	done
	ln -svf "/usr/lib/llvm-$LLVM_VERSION" "/usr/lib/llvm"

	apt install -y $BPO_FLAG nodejs yarn
	if [ -n "$CHN_NET" ]; then
		npm config set registry "https://registry.npmmirror.com" --global
		yarn config set registry "https://registry.npmmirror.com" --global
	fi

	apt install -y $BPO_FLAG golang-1.26-go
	rm -rf "/usr/bin/go" "/usr/bin/gofmt"
	ln -svf "/usr/lib/go-1.26/bin/go" "/usr/bin/go"
	ln -svf "/usr/lib/go-1.26/bin/gofmt" "/usr/bin/gofmt"
	if [ -n "$CHN_NET" ]; then
		go env -w GOPROXY="https://proxy.golang.org|https://goproxy.cn|direct"
		go env -w GOSUMDB=sum.golang.org
	fi

	apt install gh -y

	apt clean -y

	if TMP_DIR="$(mktemp -d)"; then
		pushd "$TMP_DIR"
	else
		__error_msg "Failed to create a tmp directory."
		exit 1
	fi

	UPX_REV="5.0.2"
	curl -fLO "https://github.com/upx/upx/releases/download/v${UPX_REV}/upx-$UPX_REV-amd64_linux.tar.xz"
	tar -Jxf "upx-$UPX_REV-amd64_linux.tar.xz"
	rm -rf "/usr/bin/upx" "/usr/bin/upx-ucl"
	cp -fp "upx-$UPX_REV-amd64_linux/upx" "/usr/bin/upx-ucl"
	chmod 0755 "/usr/bin/upx-ucl"
	ln -svf "/usr/bin/upx-ucl" "/usr/bin/upx"

	curl -fLO "https://raw.githubusercontent.com/openwrt/openwrt/main/tools/padjffs2/src/padjffs2.c"
	gcc -Wall -Werror -o "padjffs2" "padjffs2.c"
	strip "padjffs2"
	rm -rf "padjffs2.c" "/usr/bin/padjffs2"
	cp -fp "padjffs2" "/usr/bin/padjffs2"

	git clone --filter=blob:none --no-checkout "https://github.com/openwrt/luci.git" "po2lmo"
	pushd "po2lmo"
	git config core.sparseCheckout true
	echo "modules/luci-base/src" >> ".git/info/sparse-checkout"
	git checkout
	cd "modules/luci-base/src"
	make po2lmo
	strip "po2lmo"
	rm -rf "/usr/bin/po2lmo"
	cp -fp "po2lmo" "/usr/bin/po2lmo"
	popd

	curl -fL "https://build-scripts.immortalwrt.org/modify-firmware.sh" -o "/usr/bin/modify-firmware"
	chmod 0755 "/usr/bin/modify-firmware"

	popd
	rm -rf "$TMP_DIR"

	set +x
	__success_msg "All dependencies have been installed."
}
function main() {
	check_system
	check_network
	update_apt_source
	install_dependencies
}

main
