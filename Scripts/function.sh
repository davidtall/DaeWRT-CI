#!/bin/bash

function cat_kernel_config() {
  if [ -f $1 ]; then
    cat >> $1 <<EOF
CONFIG_BPF=y
CONFIG_BPF_SYSCALL=y
CONFIG_BPF_JIT=y
CONFIG_CGROUPS=y
CONFIG_KPROBES=y
CONFIG_NET_INGRESS=y
CONFIG_NET_EGRESS=y
CONFIG_NET_SCH_INGRESS=m
CONFIG_NET_CLS_BPF=m
CONFIG_NET_CLS_ACT=y
CONFIG_BPF_STREAM_PARSER=y
CONFIG_DEBUG_INFO=y
# CONFIG_DEBUG_INFO_REDUCED is not set
CONFIG_DEBUG_INFO_BTF=y
CONFIG_KPROBE_EVENTS=y
CONFIG_BPF_EVENTS=y

CONFIG_NET_SCH_BPF=y
CONFIG_SCHED_CLASS_EXT=y
CONFIG_PROBE_EVENTS_BTF_ARGS=y
CONFIG_IMX_SCMI_MISC_DRV=n
CONFIG_ARM64_CONTPTE=y

CONFIG_PERSISTENT_HUGE_ZERO_FOLIO=n
CONFIG_NO_PAGE_MAPCOUNT=n
CONFIG_ARM64_BRBE=y
CONFIG_NF_CONNTRACK_DSCPREMARK_EXT=y
EOF
    echo "cat_kernel_config to $1 done"
  fi
}

function cat_ebpf_config() {

#ebpf相关
  cat >> $1 <<EOF
#eBPF
CONFIG_DEVEL=y
CONFIG_KERNEL_DEBUG_INFO=y
CONFIG_KERNEL_DEBUG_INFO_REDUCED=n
CONFIG_KERNEL_DEBUG_INFO_BTF=y
CONFIG_KERNEL_CGROUPS=y
CONFIG_KERNEL_CGROUP_BPF=y
CONFIG_KERNEL_BPF_EVENTS=y
CONFIG_BPF_TOOLCHAIN_HOST=y
CONFIG_KERNEL_XDP_SOCKETS=y
CONFIG_PACKAGE_kmod-xdp-sockets-diag=y

CONFIG_KERNEL_TRANSPARENT_HUGEPAGE=y
# CONFIG_KERNEL_TRANSPARENT_HUGEPAGE_ALWAYS is not set
CONFIG_KERNEL_TRANSPARENT_HUGEPAGE_MADVISE=y
# CONFIG_KERNEL_TRANSPARENT_HUGEPAGE_NEVER is not set
EOF
}

function cat_usb_net() {
  cat >> $1 <<EOF
#USB CPE Driver
CONFIG_PACKAGE_kmod-usb-net=y
CONFIG_PACKAGE_kmod-usb-net-cdc-eem=y
CONFIG_PACKAGE_kmod-usb-net-cdc-ether=y
CONFIG_PACKAGE_kmod-usb-net-cdc-mbim=y
CONFIG_PACKAGE_kmod-usb-net-cdc-ncm=y
CONFIG_PACKAGE_kmod-usb-net-cdc-subset=y
CONFIG_PACKAGE_kmod-usb-net-huawei-cdc-ncm=y
CONFIG_PACKAGE_kmod-usb-net-ipheth=y
CONFIG_PACKAGE_kmod-usb-net-rndis=y
CONFIG_PACKAGE_kmod-usb-net-rtl8150=y
CONFIG_PACKAGE_kmod-usb-net-rtl8152=y
EOF
# 6.12/6.18 source trees do not currently build these vendor QMI WWAN modules.
# Keep them disabled unless the selected source tree carries compatible packages.

}

function set_nss_driver() {
  cat >> $1 <<EOF
#NSS驱动相关
CONFIG_PACKAGE_kmod-qca-nss-dp=y
CONFIG_PACKAGE_kmod-qca-nss-drv=y
CONFIG_PACKAGE_kmod-qca-nss-drv-bridge-mgr=y
CONFIG_PACKAGE_kmod-qca-nss-drv-vlan=y
CONFIG_PACKAGE_kmod-qca-nss-drv-igs=y
#CONFIG_PACKAGE_kmod-qca-nss-drv-map-t=y
CONFIG_PACKAGE_kmod-qca-nss-drv-pppoe=y
CONFIG_PACKAGE_kmod-qca-nss-drv-pptp=y
CONFIG_PACKAGE_kmod-qca-nss-drv-qdisc=y
CONFIG_PACKAGE_kmod-qca-nss-ecm=y
CONFIG_PACKAGE_kmod-qca-nss-macsec=y
CONFIG_PACKAGE_kmod-qca-nss-drv-l2tpv2=y
CONFIG_PACKAGE_kmod-qca-nss-drv-lag-mgr=y
EOF
}
function kernel_version() {
  echo $(sed -n 's/^KERNEL_PATCHVER:=\(.*\)/\1/p' target/linux/qualcommax/Makefile)
}
function remove_wifi() {
  local target=$1
  #去除依赖
  local wifi_pkg_pattern='wpad-[^ ]*|hostapd-[^ ]*|kmod-ath|kmod-ath10k|kmod-ath10k-[^ ]*|kmod-ath11k|kmod-ath11k-[^ ]*|kmod-mac80211|kmod-cfg80211|ath10k-firmware-[^ ]*|ath11k-firmware-[^ ]*|ipq-wifi-[^ ]*'
  sed -i -E ":again; s/(^|[[:space:]])-?(${wifi_pkg_pattern})([[:space:]]|$)/ /g; t again; s/[[:space:]]+$//" ./target/linux/qualcommax/Makefile
  sed -i -E ":again; s/(^|[[:space:]])-?(${wifi_pkg_pattern})([[:space:]]|$)/ /g; t again; s/[[:space:]]+$//" ./target/linux/qualcommax/${target}/target.mk
  sed -i -E ":again; s/(^|[[:space:]])-?(${wifi_pkg_pattern})([[:space:]]|$)/ /g; t again; s/[[:space:]]+$//" ./target/linux/qualcommax/image/${target}.mk
  sed -i 's/\bkmod-qca-nss-drv-wifi-meshmgr\b//g' ./target/linux/qualcommax/Makefile
  #删除无线组件
  rm -rf package/network/services/hostapd
  rm -rf package/firmware/ipq-wifi
}

function normalize_athena_led_device_packages() {
  local config_file=$1
  local missing_pkg_pattern='luci-i18n-athena-led-zh-cn'

  if ! find ./package ./feeds -type f -path '*/luci-app-athena-led/Makefile' -print -quit 2>/dev/null | grep -q .; then
    missing_pkg_pattern='luci-app-athena-led|luci-i18n-athena-led-zh-cn'
  fi

  find ./target/linux/qualcommax -type f \( -name "*.mk" -o -name "target.mk" \) -print0 2>/dev/null |
    xargs -0 -r sed -i -E ":again; s/(^|[[:space:]])-?(${missing_pkg_pattern})([[:space:]]|$)/ /g; t again; s/[[:space:]]+$//"

  sed -i -E ":again; s/(^CONFIG_TARGET_DEVICE_PACKAGES_[^\"]*=\")([^\"]*)(^|[[:space:]])-?(${missing_pkg_pattern})([[:space:]]|\"$)/\1\2\5/g; t again; s/[[:space:]]+\"/\"/" "$config_file"
  sed -i -E "/^#? ?CONFIG_PACKAGE_luci-i18n-athena-led-zh-cn(=| is not set)/d" "$config_file"

  if [[ "$missing_pkg_pattern" == *"luci-app-athena-led"* ]]; then
    sed -i -E "/^#? ?CONFIG_PACKAGE_luci-app-athena-led(=| is not set)/d" "$config_file"
  fi
}

function set_kernel_size() {
  #修改jdc ax1800 pro 的内核大小为12M
  image_file='./target/linux/qualcommax/image/ipq60xx.mk'
  sed -i "/^define Device\/emmc-common/,/^endef/ s/KERNEL_SIZE := 6144k/KERNEL_SIZE := 12288k/" $image_file
  sed -i "/^define Device\/nand-common/,/^endef/ s/^endef/\tKERNEL_SIZE := 8192k\nendef/" $image_file
  sed -i "/^define Device\/jdcloud_re-ss-01/,/^endef/ { /KERNEL_SIZE := 6144k/s//KERNEL_SIZE := 12288k/ }" $image_file
  sed -i "/^define Device\/jdcloud_re-cs-02/,/^endef/ { /KERNEL_SIZE := 6144k/s//KERNEL_SIZE := 12288k/ }" $image_file
  sed -i "/^define Device\/jdcloud_re-cs-07/,/^endef/ { /KERNEL_SIZE := 6144k/s//KERNEL_SIZE := 12288k/ }" $image_file
  sed -i "/^define Device\/link_nn6000-common/,/^endef/ { /KERNEL_SIZE := 6144k/s//KERNEL_SIZE := 12288k/ }" $image_file
#  sed -i "/^define Device\/redmi_ax5-jdcloud/,/^endef/ s/^endef/  KERNEL_SIZE := 12288k\nendef/" $image_file
  sed -i "/^define Device\/linksys_mr/,/^endef/ { /KERNEL_SIZE := 8192k/s//KERNEL_SIZE := 12288k/ }" $image_file
  cat $image_file
}
#开启内存回收补丁
function enable_skb_recycler() {
  cat >> $1 <<EOF
CONFIG_KERNEL_SKB_RECYCLER=y
CONFIG_KERNEL_SKB_RECYCLER_MULTI_CPU=y
EOF
}

function generate_config() {
  config_file=".config"
  #如配置文件已存在
  cat $GITHUB_WORKSPACE/Config/${WRT_CONFIG}.txt $GITHUB_WORKSPACE/Config/GENERAL.txt  > $config_file
  local target=$(echo $WRT_ARCH | cut -d'_' -f2)

  #删除wifi依赖
  if [[ "$WRT_CONFIG" == *"NOWIFI"* || "$WRT_CONFIG" == *"WIFI-NO"* ]]; then
    remove_wifi $target
  fi

  set_nss_driver $config_file
  normalize_athena_led_device_packages $config_file
  #增加ebpf
  cat_ebpf_config $config_file
  enable_skb_recycler $config_file
  set_kernel_size
  #增加内核选项
  cat_kernel_config "target/linux/qualcommax/${target}/config-default"
}
