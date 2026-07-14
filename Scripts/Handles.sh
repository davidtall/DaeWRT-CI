#!/bin/bash
# SPDX-License-Identifier: MIT
# Copyright (C) 2026 VIKINGYFY

. "$(dirname "$(realpath "$0")")/retry.sh"

PKG_PATH="$GITHUB_WORKSPACE/$WRT_DIR/package/"

preload_nikki_geodata() {
	mkdir -p "$GITHUB_WORKSPACE/files/etc/nikki/run"

	retry_cmd 5 15 curl -fL "https://github.com/MetaCubeX/meta-rules-dat/releases/download/latest/geoip.dat" -o "$GITHUB_WORKSPACE/files/etc/nikki/run/geoip.dat"
	retry_cmd 5 15 curl -fL "https://github.com/MetaCubeX/meta-rules-dat/releases/download/latest/geosite.dat" -o "$GITHUB_WORKSPACE/files/etc/nikki/run/geosite.dat"
	retry_cmd 5 15 curl -fL "https://github.com/MetaCubeX/meta-rules-dat/releases/download/latest/geoip.metadb" -o "$GITHUB_WORKSPACE/files/etc/nikki/run/geoip.metadb"

	cd "$PKG_PATH" && echo "nikki geodata has been preloaded into files/etc/nikki/run!"
}

preload_nikki_geodata

patch_wrtbak_proxy_url() {
	WRTBAK_S3="./luci-app-wrtbak/root/usr/lib/wrtbak/remote_s3.sh"
	[ -f "$WRTBAK_S3" ] || return 0

	if grep -q 'wrtbak_main_option proxy_url' "$WRTBAK_S3" && grep -q 'WRTBAK_S3_FORCE_DIRECT' "$WRTBAK_S3"; then
		cd "$PKG_PATH" && echo "wrtbak S3 proxy_url support is already present!"
		return 0
	fi

	python3 - "$WRTBAK_S3" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
text = path.read_text()
old_plain = '''wrtbak_s3_rclone() {
	wrtbak_config=$1
	shift
	rclone --config "$wrtbak_config" "$@"
}'''
old_proxy = '''wrtbak_s3_rclone() {
	wrtbak_config=$1
	shift
	wrtbak_proxy_url=$(wrtbak_main_option proxy_url "")
	if [ -n "$wrtbak_proxy_url" ]; then
		HTTP_PROXY="$wrtbak_proxy_url" HTTPS_PROXY="$wrtbak_proxy_url" ALL_PROXY="$wrtbak_proxy_url" \\
		http_proxy="$wrtbak_proxy_url" https_proxy="$wrtbak_proxy_url" all_proxy="$wrtbak_proxy_url" \\
			rclone --config "$wrtbak_config" "$@"
	else
		rclone --config "$wrtbak_config" "$@"
	fi
}'''
new = '''wrtbak_s3_rclone() {
	wrtbak_config=$1
	shift
	case "${WRTBAK_S3_FORCE_DIRECT:-0}" in
		1|true|yes|on|direct)
			wrtbak_proxy_url=
			;;
		*)
			wrtbak_proxy_url=$(wrtbak_main_option proxy_url "")
			;;
	esac
	if [ -n "$wrtbak_proxy_url" ]; then
		HTTP_PROXY="$wrtbak_proxy_url" \\
		HTTPS_PROXY="$wrtbak_proxy_url" \\
		ALL_PROXY="$wrtbak_proxy_url" \\
		http_proxy="$wrtbak_proxy_url" \\
		https_proxy="$wrtbak_proxy_url" \\
		all_proxy="$wrtbak_proxy_url" \\
		NO_PROXY="${NO_PROXY:-localhost,127.0.0.1,::1}" \\
		no_proxy="${no_proxy:-localhost,127.0.0.1,::1}" \\
			rclone --config "$wrtbak_config" "$@"
	else
		rclone --config "$wrtbak_config" "$@"
	fi
}'''
if old_plain in text:
	text = text.replace(old_plain, new, 1)
elif old_proxy in text:
	text = text.replace(old_proxy, new, 1)
else:
	raise SystemExit("wrtbak S3 rclone function shape changed")
path.write_text(text)
PY

	grep -q 'wrtbak_main_option proxy_url' "$WRTBAK_S3" || {
		echo "ERROR: failed to patch wrtbak S3 proxy_url support" >&2
		exit 1
	}
	grep -q 'WRTBAK_S3_FORCE_DIRECT' "$WRTBAK_S3" || {
		echo "ERROR: failed to patch wrtbak firstboot direct-R2 support" >&2
		exit 1
	}

	cd "$PKG_PATH" && echo "wrtbak S3 proxy_url support has been patched!"
}

patch_wrtbak_proxy_url

# 修复 procd 源码镜像 404：优先使用 GitHub 镜像仓库。
PROCD_MAKEFILE="../package/system/procd/Makefile"
if [ -f "$PROCD_MAKEFILE" ]; then
	sed -i 's#^PKG_SOURCE_URL:=.*procd\.git$#PKG_SOURCE_URL:=https://github.com/openwrt/procd.git#g' "$PROCD_MAKEFILE"
	grep -q '^PKG_SOURCE_URL:=https://github.com/openwrt/procd.git$' "$PROCD_MAKEFILE" && \
		cd "$PKG_PATH" && echo "procd source url has been switched to GitHub mirror!"
fi

# 修复 sbwml/luci-app-mosdns 的 ES6+ 语法与 LuCI jsmin 的兼容问题。
MOSDNS_ROOT="./luci-app-mosdns"
if [ -d "$MOSDNS_ROOT" ]; then
	"$GITHUB_WORKSPACE/Scripts/patch_mosdns_jsmin_compat.sh" "$MOSDNS_ROOT"
	cd "$PKG_PATH" && echo "mosdns jsmin compatibility has been fixed!"
fi

#预置HomeProxy数据
if [ -d *"homeproxy"* ]; then
	echo " "

	HP_RULE="surge"
	HP_PATH="homeproxy/root/etc/homeproxy"

	rm -rf ./$HP_PATH/resources/*

	git clone -q --depth=1 --single-branch --branch "release" "https://github.com/Loyalsoldier/surge-rules.git" ./$HP_RULE/
	cd ./$HP_RULE/ && RES_VER=$(git log -1 --pretty=format:'%s' | grep -o "[0-9]*")

	echo $RES_VER | tee china_ip4.ver china_ip6.ver china_list.ver gfw_list.ver
	awk -F, '/^IP-CIDR,/{print $2 > "china_ip4.txt"} /^IP-CIDR6,/{print $2 > "china_ip6.txt"}' cncidr.txt
	sed 's/^\.//g' direct.txt > china_list.txt ; sed 's/^\.//g' gfw.txt > gfw_list.txt
	mv -f ./{china_*,gfw_list}.{ver,txt} ../$HP_PATH/resources/

	cd .. && rm -rf ./$HP_RULE/

	cd $PKG_PATH && echo "homeproxy date has been updated!"
fi

#修改argon主题字体和颜色
if [ -d *"luci-theme-argon"* ]; then
	echo " "

	cd ./luci-theme-argon/

	sed -i "s/primary '.*'/primary '#31a1a1'/; s/'0.2'/'0.5'/; s/'none'/'bing'/; s/'600'/'normal'/" ./luci-app-argon-config/root/etc/config/argon

	cd $PKG_PATH && echo "theme-argon has been fixed!"
fi

#修改aurora菜单式样
if [ -d *"luci-app-aurora-config"* ]; then
	echo " "

	cd ./luci-app-aurora-config/

	sed -i "s/nav_submenu_type '.*'/nav_submenu_type 'boxed-dropdown'/g" $(find ./root/ -type f -name "*aurora")

	cd $PKG_PATH && echo "theme-aurora has been fixed!"
fi

#修改qca-nss-drv启动顺序
NSS_DRV="../feeds/nss_packages/qca-nss-drv/files/qca-nss-drv.init"
if [ -f "$NSS_DRV" ]; then
	echo " "

	sed -i 's/START=.*/START=85/g' $NSS_DRV

	cd $PKG_PATH && echo "qca-nss-drv has been fixed!"
fi

#修改qca-nss-pbuf启动顺序
NSS_PBUF="./kernel/mac80211/files/qca-nss-pbuf.init"
if [ -f "$NSS_PBUF" ]; then
	echo " "

	sed -i 's/START=.*/START=86/g' $NSS_PBUF

	cd $PKG_PATH && echo "qca-nss-pbuf has been fixed!"
fi

#修复Rust编译失败
RUST_FILE=$(find ../feeds/packages/ -maxdepth 3 -type f -wholename "*/rust/Makefile")
if [ -f "$RUST_FILE" ]; then
	echo " "

	sed -i 's/ci-llvm=true/ci-llvm=false/g' $RUST_FILE

	cd $PKG_PATH && echo "rust has been fixed!"
fi

#修复DiskMan编译失败
DM_FILE="./luci-app-diskman/applications/luci-app-diskman/Makefile"
if [ -f "$DM_FILE" ]; then
	echo " "

	sed -i '/ntfs-3g-utils /d' $DM_FILE

	cd $PKG_PATH && echo "diskman has been fixed!"
fi

#修复luci-app-netspeedtest相关问题
if [ -d *"luci-app-netspeedtest"* ]; then
	echo " "

	cd ./luci-app-netspeedtest/

	sed -i '$a\exit 0' ./netspeedtest/files/99_netspeedtest.defaults
	sed -i 's/ca-certificates/ca-bundle/g' ./speedtest-cli/Makefile

	cd $PKG_PATH && echo "netspeedtest has been fixed!"
fi
