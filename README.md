# OpenWRT-CI
云编译OpenWRT固件，开启内核eBPF，支持DAED 内核级透明代理

官方版：
https://github.com/immortalwrt/immortalwrt.git

高通版：
https://github.com/VIKINGYFY/immortalwrt.git

LiBWrt：
https://github.com/davidtall/LiBwrt-openwrt-6.x

# U-BOOT

高通版：
https://github.com/chenxin527/uboot-ipq60xx-emmc-build
https://github.com/chenxin527/uboot-ipq60xx-nand-build
https://github.com/chenxin527/uboot-ipq60xx-nor-build

联发科版：
https://drive.wrt.moe/uboot/mediatek

京东云亚瑟 AX1800 Pro DAED 需要更换分区表和uboot,具体使用方法详见恩山帖子:
https://www.right.com.cn/forum/thread-8402269-1-1.html

# 固件简要说明：

固件每天早上4点自动编译。

固件信息里的时间为编译开始的时间，方便核对上游源码提交时间。

MEDIATEK系列、QUALCOMMAX系列、ROCKCHIP系列、X86系列。

# 目录简要说明：

workflows——自定义CI配置

Scripts——自定义脚本

Config——自定义配置

# hotwa 保留设备说明

hotwa 仓库需要长期保留京东云 `re-cs-07`、`re-ss-01`、`re-ss02` 三个型号。后续从上游合并时，如果上游删除这些型号，不要接受删除；如果上游新增其他设备，可以在保留这三个型号的基础上继续合并新增设备。
