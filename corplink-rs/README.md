## 编译镜像
如果在 AMD64 电脑上为 ARM64 OpenWrt 构建，先启用模拟器：
docker run --privileged --rm tonistiigi/binfmt --install arm64
docker buildx build --platform linux/arm64 --load -t corplink-rs:arm64 .

## 导出镜像
docker save -o corplink-rs-arm64.tar corplink-rs:arm64
## 导入镜像
docker load -i corplink-rs-arm64.tar

## 删除旧的网桥
docker network rm corplink-net

## 创建docker 网络
```
docker network create \
--driver bridge \
--subnet 172.30.0.0/24 \
--gateway 172.30.0.1 \
-o com.docker.network.bridge.name=corplink0 \
corplink-net
```

## 启动容器
```
//删除容器
docker stop corplink-rs && docker rm corplink-rs

//创建容器
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

//查看容器日志
docker logs corplink-rs
```

## 同步VPN路由到宿主机
```
cd corplink-rs
chmod +x ./corplink-routes.sh
./corplink-routes.sh
```

## 宿主机放行br-lan 到 corplink0 访问
iptables -I DOCKER-USER 1 -i br-lan -o corplink0 -j ACCEPT

## 设置mtu

```
vim /etc/nftables.d/90-corplink-mss.nft
//增加以下内容
chain corplink_mss_clamp {
    type filter hook forward priority -151; policy accept;

    iifname "br-lan" oifname "corplink0" \
        tcp flags syn / syn,fin,rst \
        tcp option maxseg size set 1360 \
        comment "!user: Clamp LAN to CorpLink TCP MSS"
}

//重启防火墙
fw4 check && /etc/init.d/firewall reload
```


## 保留升级时保留文件
```
echo '/etc/nftables.d/90-corplink-mss.nft' >> /etc/sysupgrade.conf
echo '/etc/init.d/zz-corplink-docker-user' >> /etc/sysupgrade.conf
echo '/etc/rc.d/S99zz-corplink-docker-user' >> /etc/sysupgrade.conf
```
