
如果在 AMD64 电脑上为 ARM64 OpenWrt 构建，先启用模拟器：
docker run --privileged --rm tonistiigi/binfmt --install arm64
docker buildx build --platform linux/arm64 --load -t corplink-rs:arm64 .

#导出镜像
docker save -o corplink-rs-arm64.tar corplink-rs:arm64
#导入镜像
docker load -i corplink-rs-arm64.tar

#创建docker 网络
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
-e KEEPALIVE_URL='https://ops.qima-inc.com' \
-e KEEPALIVE_INTERVAL=60 \
-v "$PWD/corplink:/etc/corplink" \
corplink-rs:arm64

docker run -d \
--name corplink-rs \
--network corplink-net \
--ip 172.30.0.2 \
--cap-add NET_ADMIN \
--cap-add NET_RAW \
--device /dev/net/tun \
--sysctl net.ipv4.ip_forward=1 \
-v "$PWD/corplink:/etc/corplink" \
corplink-rs:arm64

docker stop corplink-rs && docker rm corplink-rs


docker logs corplink-rs