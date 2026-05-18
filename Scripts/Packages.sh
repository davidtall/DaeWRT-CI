#!/bin/bash
# SPDX-License-Identifier: MIT
# Copyright (C) 2026 VIKINGYFY

. "$(dirname "$(realpath "$0")")/retry.sh"

#安装和更新软件包
UPDATE_PACKAGE() {
	local PKG_NAME=$1
	local PKG_REPO=$2
	local PKG_BRANCH=$3
	local PKG_SPECIAL=$4
	local PKG_LIST=("$PKG_NAME" $5)  # 第5个参数为自定义名称列表
	local PKG_COMMIT=${6:-}
	local REPO_NAME=${PKG_REPO#*/}

	echo " "

	# 删除本地可能存在的不同名称的软件包
	for NAME in "${PKG_LIST[@]}"; do
		# 查找匹配的目录
		echo "Search directory: $NAME"
		local FOUND_DIRS
		FOUND_DIRS=$(find ../feeds/luci/ ../feeds/packages/ -maxdepth 3 -type d -iname "*$NAME*" 2>/dev/null)

		# 删除找到的目录
		if [ -n "$FOUND_DIRS" ]; then
			while read -r DIR; do
				rm -rf "$DIR"
				echo "Delete directory: $DIR"
			done <<< "$FOUND_DIRS"
		else
			echo "Not fonud directory: $NAME"
		fi
	done

	# 克隆 GitHub 仓库
	retry_cmd 5 15 git clone --depth=1 --single-branch --branch $PKG_BRANCH "https://github.com/$PKG_REPO.git"
	if [ -n "$PKG_COMMIT" ]; then
		retry_cmd 5 15 git -C "$REPO_NAME" fetch --depth=1 origin "$PKG_COMMIT"
		git -C "$REPO_NAME" checkout --detach "$PKG_COMMIT"
	fi

	# 处理克隆的仓库
	if [[ "$PKG_SPECIAL" == "pkg" ]]; then
		# Extract into a staging directory first so repo cleanup cannot delete packages
		# when the repository name and package directory name are identical.
		local EXTRACT_DIR="./.${REPO_NAME}.pkg-extract"
		rm -rf "$EXTRACT_DIR"
		mkdir -p "$EXTRACT_DIR"

		find ./$REPO_NAME/*/ -maxdepth 3 -type d -iname "*$PKG_NAME*" -prune -exec cp -rf {} "$EXTRACT_DIR"/ \;
		if [[ "$PKG_NAME" == "luci-app-tailscale-community" ]]; then
			test -d "$EXTRACT_DIR/$PKG_NAME" || {
				echo "ERROR: luci-app-tailscale-community was not extracted into the staging directory."
				exit 1
			}
		fi
		rm -rf ./$REPO_NAME/
		for EXTRACTED_PATH in "$EXTRACT_DIR"/*; do
			[ -e "$EXTRACTED_PATH" ] || continue
			rm -rf "./$(basename "$EXTRACTED_PATH")"
			mv -f "$EXTRACTED_PATH" ./
		done
		rm -rf "$EXTRACT_DIR"
		if [[ "$PKG_NAME" == "luci-app-tailscale-community" ]]; then
			test -d "./luci-app-tailscale-community" || {
				echo "ERROR: luci-app-tailscale-community was removed after repository cleanup."
				exit 1
			}
		fi
	elif [[ "$PKG_SPECIAL" == "name" ]]; then
		mv -f $REPO_NAME $PKG_NAME
	fi
}

# 调用示例
# UPDATE_PACKAGE "OpenAppFilter" "destan19/OpenAppFilter" "master" "" "custom_name1 custom_name2"
# UPDATE_PACKAGE "open-app-filter" "destan19/OpenAppFilter" "master" "" "luci-app-appfilter oaf" 这样会把原有的open-app-filter，luci-app-appfilter，oaf相关组件删除，不会出现coremark错误。

# UPDATE_PACKAGE "包名" "项目地址" "项目分支" "pkg/name，可选，pkg为从大杂烩中单独提取包名插件；name为重命名为包名"
UPDATE_PACKAGE "argon" "sbwml/luci-theme-argon" "openwrt-25.12"
UPDATE_PACKAGE "aurora" "eamonxg/luci-theme-aurora" "master"
UPDATE_PACKAGE "aurora-config" "eamonxg/luci-app-aurora-config" "master"
UPDATE_PACKAGE "kucat" "sirpdboy/luci-theme-kucat" "master"
UPDATE_PACKAGE "kucat-config" "sirpdboy/luci-app-kucat-config" "master"

UPDATE_PACKAGE "homeproxy" "VIKINGYFY/homeproxy" "main"
UPDATE_PACKAGE "momo" "nikkinikki-org/OpenWrt-momo" "main"
UPDATE_PACKAGE "nikki" "nikkinikki-org/OpenWrt-nikki" "main"
#UPDATE_PACKAGE "openclash" "vernesong/OpenClash" "dev" "pkg"
#UPDATE_PACKAGE "passwall" "Openwrt-Passwall/openwrt-passwall" "main" "pkg"
#UPDATE_PACKAGE "passwall2" "Openwrt-Passwall/openwrt-passwall2" "main" "pkg"

UPDATE_PACKAGE "luci-app-tailscale-community" "hotwa/luci-app-tailscale-community" "main" "pkg"
# 临时移除 podman，跳过 luci-app-podman 拉取。
# UPDATE_PACKAGE "luci-app-podman" "Zerogiven-OpenWRT-Packages/luci-app-podman" "main" "" "" "4a15e161170ba8cdfec0f522b7a80cc54b9dd96b"
#UPDATE_PACKAGE "luci-app-tailscale" "asvow/luci-app-tailscale" "main"

#UPDATE_PACKAGE "athena-led" "unraveloop/JDC-AX6600-Athena-LED-Controller" "main"
UPDATE_PACKAGE "ddns-go" "sirpdboy/luci-app-ddns-go" "main"
UPDATE_PACKAGE "diskman" "lisaac/luci-app-diskman" "master"
UPDATE_PACKAGE "easytier" "EasyTier/luci-app-easytier" "main"
UPDATE_PACKAGE "fancontrol" "rockjake/luci-app-fancontrol" "main"
UPDATE_PACKAGE "gecoosac" "laipeng668/luci-app-gecoosac" "main"
UPDATE_PACKAGE "luci-app-athena-led" "NONGFAH/luci-app-athena-led" "main"
UPDATE_PACKAGE "mosdns" "sbwml/luci-app-mosdns" "v5" "" "v2dat"
#UPDATE_PACKAGE "netspeedtest" "sirpdboy/luci-app-netspeedtest" "master" "" "homebox speedtest"
UPDATE_PACKAGE "openclaw" "hotwa/luci-app-openclaw" "main"
UPDATE_PACKAGE "openlist2" "sbwml/luci-app-openlist2" "main"
UPDATE_PACKAGE "partexp" "sirpdboy/luci-app-partexp" "main"
UPDATE_PACKAGE "qbittorrent" "sbwml/luci-app-qbittorrent" "master" "" "qt6base qt6tools rblibtorrent"
UPDATE_PACKAGE "qmodem" "FUjr/QModem" "main"
UPDATE_PACKAGE "quickfile" "sbwml/luci-app-quickfile" "main"
UPDATE_PACKAGE "viking" "VIKINGYFY/packages" "main" "" "luci-app-timewol luci-app-wolplus"
UPDATE_PACKAGE "vnt" "lmq8267/luci-app-vnt" "main"

# 与上游对齐 daed 包源。
UPDATE_PACKAGE "luci-app-daed" "QiuSimons/luci-app-daed" "kix"
UPDATE_PACKAGE "luci-app-pushbot" "zzsj0928/luci-app-pushbot" "master"
UPDATE_PACKAGE "luci-app-lucky" "sirpdboy/luci-app-lucky" "main"

#更新软件包版本
UPDATE_VERSION() {
	local PKG_NAME=$1
	local PKG_MARK=${2:-false}
	local PKG_FILES
	PKG_FILES=$(find ./ ../feeds/packages/ -maxdepth 3 -type f -wholename "*/$PKG_NAME/Makefile")

	if [ -z "$PKG_FILES" ]; then
		echo "$PKG_NAME not found!"
		return
	fi

	echo -e "\n$PKG_NAME version update has started!"

	for PKG_FILE in $PKG_FILES; do
		local PKG_REPO
		local PKG_TAG
		local OLD_VER
		local OLD_URL
		local OLD_FILE
		local OLD_HASH
		local PKG_URL
		local NEW_VER
		local NEW_URL
		local NEW_HASH

		PKG_REPO=$(grep -Po "PKG_SOURCE_URL:=https://.*github.com/\K[^/]+/[^/]+(?=.*)" "$PKG_FILE")
		PKG_TAG=$(curl -sL "https://api.github.com/repos/$PKG_REPO/releases" | jq -r "map(select(.prerelease == $PKG_MARK)) | first | .tag_name")

		OLD_VER=$(grep -Po "PKG_VERSION:=\K.*" "$PKG_FILE")
		OLD_URL=$(grep -Po "PKG_SOURCE_URL:=\K.*" "$PKG_FILE")
		OLD_FILE=$(grep -Po "PKG_SOURCE:=\K.*" "$PKG_FILE")
		OLD_HASH=$(grep -Po "PKG_HASH:=\K.*" "$PKG_FILE")

		PKG_URL=$([[ "$OLD_URL" == *"releases"* ]] && echo "${OLD_URL%/}/$OLD_FILE" || echo "${OLD_URL%/}")

		NEW_VER=$(echo $PKG_TAG | sed -E 's/[^0-9]+/\./g; s/^\.|\.$//g')
		NEW_URL=$(echo $PKG_URL | sed "s/\$(PKG_VERSION)/$NEW_VER/g; s/\$(PKG_NAME)/$PKG_NAME/g")
		NEW_HASH=$(curl -sL "$NEW_URL" | sha256sum | cut -d ' ' -f 1)

		echo "old version: $OLD_VER $OLD_HASH"
		echo "new version: $NEW_VER $NEW_HASH"

		if [[ "$NEW_VER" =~ ^[0-9].* ]] && dpkg --compare-versions "$OLD_VER" lt "$NEW_VER"; then
			sed -i "s/PKG_VERSION:=.*/PKG_VERSION:=$NEW_VER/g" "$PKG_FILE"
			sed -i "s/PKG_HASH:=.*/PKG_HASH:=$NEW_HASH/g" "$PKG_FILE"
			echo "$PKG_FILE version has been updated!"
		else
			echo "$PKG_FILE version is already the latest!"
		fi
	done
}

#UPDATE_VERSION "软件包名" "测试版，true，可选，默认为否"
#UPDATE_VERSION "sing-box"
#UPDATE_VERSION "tailscale"

#删除官方的默认插件
rm -rf ../feeds/luci/applications/luci-app-{passwall*,mosdns,dockerman,dae*,bypass*}
rm -rf ../feeds/packages/net/{v2ray-geodata,dae*}
cp -r $GITHUB_WORKSPACE/package/* ./
# hotwa/luci-app-tailscale-community 会重复打包 tailscale 已提供的 UCI 配置和 init 脚本。
# 这些文件由基础 tailscale 包和仓库 overlay 统一提供，避免 ipk 文件冲突。
rm -f luci-app-tailscale-community/root/etc/config/tailscale
rm -f luci-app-tailscale-community/root/etc/init.d/tailscale
#修复daed/Makefile
rm -rf luci-app-daed/daed/Makefile && cp -r $GITHUB_WORKSPACE/patches/daed/Makefile luci-app-daed/daed/
sed -i 's/pnpm install ; \\/pnpm install --no-frozen-lockfile ; \\/g' luci-app-daed/daed/Makefile
sed -i 's|github.com/daeuniverse/quic-go|github.com/olicesx/quic-go|g' luci-app-daed/daed/Makefile

sed -i 's|/run/i\\  procd_set_param|/procd_set_param command/i \\\tprocd_set_param|g' luci-app-daed/luci-app-daed/root/etc/init.d/luci_daed
#cat luci-app-daed/daed/Makefile
#修复libubox报错
#sed -i '/include $(INCLUDE_DIR)\/cmake.mk/a PKG_BUILD_FLAGS:=no-werror' ../package/libs/libubox/Makefile
#sed -i 's|TARGET_CFLAGS += -I$(STAGING_DIR)/usr/include|& -Wno-error=format-nonliteral -Wno-format-nonliteral|' ../package/libs/libubox/Makefile
#cat ../package/libs/libubox/Makefile
