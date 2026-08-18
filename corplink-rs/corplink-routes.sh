#!/bin/sh
set -eu

# 独立策略路由表；确认未被 mwan3/pbr 等占用
TABLE=100
PREF=10000

case "${1:-sync}" in
    sync)
        ;;
    clear)
        # 仅清空 corplink 专用表，保留策略规则以便下次同步直接恢复。
        ip route flush table "$TABLE" 2>/dev/null || true
        exit 0
        ;;
    *)
        echo "Usage: $0 [sync|clear]" >&2
        exit 2
        ;;
esac

# corplink 容器固定地址和 Docker bridge
CONTAINER=corplink-rs
GATEWAY=172.30.0.2
DEVICE=corplink0

# PPPoE 接口名
PPP_DEV=pppoe-wan

RAW_ROUTES="$(mktemp)"
VPN_ROUTES="$(mktemp)"

cleanup() {
    rm -f "$RAW_ROUTES" "$VPN_ROUTES"
}
trap cleanup EXIT INT TERM

# VPN 未连接、容器未运行时，不清空上一轮同步的路由
docker exec "$CONTAINER" ip -o -4 route show dev corplink \
    >"$RAW_ROUTES" 2>/dev/null || exit 0

# 排除 corplink 自身的内核直连网段，只保留 VPN 下发路由
awk '
    $1 != "default" && $0 !~ / proto kernel / {
        print $1
    }
' "$RAW_ROUTES" >"$VPN_ROUTES"

# 没有 VPN 路由时，不改变宿主机已有路由
[ -s "$VPN_ROUTES" ] || exit 0

# PPPoE 通常只有一个直连对端路由，例如：172.16.0.1。
# 不复制 default，避免 table 100 变成宿主机默认路由表。
PPP_ROUTE="$(ip -o -4 route show dev "$PPP_DEV" proto kernel scope link | awk 'NR == 1 { print $1 }')"

# 确保查找 corplink 专用策略路由表
ip rule show | grep -q "^[[:space:]]*$PREF:.*lookup $TABLE" \
    || ip rule add priority "$PREF" lookup "$TABLE"

# 仅清理 corplink 专用表，不影响 main/local 表。
# 此 OpenWrt 的 iproute2 对空的自定义表返回非 0，首次执行时继续写入路由。
ip route flush table "$TABLE" 2>/dev/null || true

# 先写 PPPoE 直连路由。
[ -z "$PPP_ROUTE" ] || ip route replace table "$TABLE" "$PPP_ROUTE" dev "$PPP_DEV" scope link

# 再同步 VPN 路由。
# 如果 VPN 下发了和 PPPoE 完全相同的路由，保留 PPPoE 路由。
while IFS= read -r cidr; do
    [ -n "$cidr" ] || continue

    [ "$cidr" = "$PPP_ROUTE" ] && continue

    ip route replace table "$TABLE" "$cidr" \
        via "$GATEWAY" dev "$DEVICE"
done <"$VPN_ROUTES"
