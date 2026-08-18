
如果在 AMD64 电脑上为 ARM64 OpenWrt 构建，先启用模拟器：
docker run --privileged --rm tonistiigi/binfmt --install arm64
docker buildx build --platform linux/arm64 --load -t corplink-rs:arm64 .

#导出镜像
docker save -o corplink-rs-arm64.tar corplink-rs:arm64
#导入镜像
docker load -i corplink-rs-arm64.tar

删除旧的网桥
docker network rm corplink-net
#创建docker 网络

docker network create \
--driver bridge \
--subnet 172.30.0.0/24 \
--gateway 172.30.0.1 \
-o com.docker.network.bridge.name=corplink0 \
corplink-net

docker network create \
--driver bridge \
--subnet 172.30.0.0/24 \
--gateway 172.30.0.1 \
corplink-net

docker network create --subnet 172.30.0.0/24 corplink-net

#启动容器
docker run -d \
--name corplink-rs \
--network corplink-net \
--ip 172.30.0.2 \
--cap-add NET_ADMIN \
--cap-add NET_RAW \
--device /dev/net/tun \
--sysctl net.ipv4.ip_forward=1 \
-e KEEPALIVE_URL='' \
-e KEEPALIVE_INTERVAL=60 \
-v "$PWD/etc:/etc/corplink" \
corplink-rs:arm64


docker stop corplink-rs && docker rm corplink-rs
docker logs corplink-rs

#宿主机设置
iptables -I DOCKER-USER 1 -i br-lan -o corplink0 -j ACCEPT

#设置mtu
mkdir -p /usr/share/nftables.d/chain-pre/mangle_forward

printf '%s\n' \
'iifname "br-lan" oifname "corplink0" tcp flags syn / syn,fin,rst tcp option maxseg size set 1360 comment "!user: Clamp LAN to CorpLink TCP MSS"' \
> /usr/share/nftables.d/chain-pre/mangle_forward/90-corplink-mss.nft

fw4 check && /etc/init.d/firewall reload