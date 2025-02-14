
#!/bin/bash

# 安装额外依赖软件包
# sudo -E apt-get -y install rename

# 更新feeds文件
# sed -i 's#src-git luci https://github.com/Lienol/openwrt-luci.git;17.01#src-git luci https://github.com/Lienol/openwrt-luci.git;18.06#g' feeds.conf.default #更换luci版本
cat feeds.conf.default

# 添加第三方软件包
git clone https://github.com/db-one/dbone-packages.git -b 18.06 package/dbone-packages

# 更新并安装源
./scripts/feeds clean
./scripts/feeds update -a && ./scripts/feeds install -a

# 删除部分默认包
rm -rf package/lean/luci-app-sfe
rm -rf package/lean/luci-app-flowoffload
rm -rf feeds/packages/net/haproxy

# 为19.07添加libcap-bin依赖
rm -rf feeds/packages/libs/libcap
svn co https://github.com/openwrt/packages/trunk/libs/libcap feeds/packages/libs/libcap

# 自定义定制选项
ZZZ="package/default-settings/files/zzz-default-settings"
#
sed -i 's#192.168.1.1#192.168.123.2#g' package/base-files/files/bin/config_generate            # 定制默认IP
# sed -i 's@.*CYXluq4wUazHjmCDBCqXF*@#&@g' $ZZZ                                           # 取消系统默认密码
# sed -i "/uci commit system/i\uci set system.@system[0].hostname='OpenWrt-X86'" $ZZZ       # 修改主机名称为OpenWrt-X86
sed -i "s/OpenWrt /ONE build $(TZ=UTC-8 date "+%Y.%m.%d") @ OpenWrt /g" $ZZZ              # 增加自己个性名称
sed -i 's@.*view/admin_status/index*@#&@g' $ZZZ                                           # 在首页显示一些服务
# sed -i 's/PATCHVER:=5.4/PATCHVER:=4.19/g' target/linux/x86/Makefile                     # 修改内核版本为4.19
# sed -i "/uci commit luci/i\uci set luci.main.mediaurlbase=/luci-static/argon" $ZZZ      # 设置默认主题(如果编译可会自动修改默认主题的，有可能会失效)

# ================================================
sed -i 's#%D %V, %C#%D %V, %C Lienol_x86_64#g' package/base-files/files/etc/banner               # 自定义banner显示
sed -i 's#option commit_interval 24h#option commit_interval 10m#g' feeds/packages/net/nlbwmon/files/nlbwmon.config               # 修改流量统计写入为10分钟
sed -i 's#option database_generations 10#option database_generations 3#g' feeds/packages/net/nlbwmon/files/nlbwmon.config               # 修改流量统计数据周期
# sed -i 's#option database_directory /var/lib/nlbwmon#option database_directory /etc/config/nlbwmon_data#g' feeds/packages/net/nlbwmon/files/nlbwmon.config               # 修改流量统计数据存放默认位置
sed -i 's#interval: 5#interval: 1#g' package/lean/luci-app-wrtbwmon/htdocs/luci-static/wrtbwmon.js               # wrtbwmon默认刷新时间更改为1秒
# sed -i 's#vpn#services#g' package/lean/luci-app-zerotier/luasrc/controller/zerotier.lua               # 修改zerotier到服务菜单
# sed -i 's#vpn#services#g' package/lean/luci-app-zerotier/luasrc/view/zerotier/zerotier_status.htm               # 修改zerotier到服务菜单

# 创建自定义配置文件

cd $WORKPATH
touch ./.config

#
# ========================固件定制部分========================
# 

# 
# 如果不对本区块做出任何编辑, 则生成默认配置固件. 
# 

# 以下为定制化固件选项和说明:
#

#
# 有些插件/选项是默认开启的, 如果想要关闭, 请参照以下示例进行编写:
# 
#          =========================================
#         |  # 取消编译VMware镜像:                    |
#         |  cat >> .config <<EOF                   |
#         |  # CONFIG_VMDK_IMAGES is not set        |
#         |  EOF                                    |
#          =========================================
#

# 
# 以下是一些提前准备好的一些插件选项.
# 直接取消注释相应代码块即可应用. 不要取消注释代码块上的汉字说明.
# 如果不需要代码块里的某一项配置, 只需要删除相应行.
#
# 如果需要其他插件, 请按照示例自行添加.
# 注意, 只需添加依赖链顶端的包. 如果你需要插件 A, 同时 A 依赖 B, 即只需要添加 A.
# 
# 无论你想要对固件进行怎样的定制, 都需要且只需要修改 EOF 回环内的内容.
# 

# 编译x32固件:
cat >> .config <<EOF
CONFIG_TARGET_x86=y
CONFIG_TARGET_x86_generic=y
CONFIG_TARGET_x86_generic_DEVICE_generic=y
CONFIG_TARGET_ROOTFS_TARGZ=y
CONFIG_TARGET_ROOTFS_SQUASHFS=y
CONFIG_TARGET_KERNEL_PARTSIZE=64
CONFIG_TARGET_ROOTFS_PARTSIZE=1200
CONFIG_GRUB_IMAGES=y
CONFIG_GRUB_EFI_IMAGES=y
CONFIG_VDI_IMAGES=y
CONFIG_VMDK_IMAGES=y
EOF

# 设置固件大小:
# cat >> .config <<EOF
# CONFIG_TARGET_KERNEL_PARTSIZE=16
# CONFIG_TARGET_ROOTFS_PARTSIZE=160
# EOF

# 固件压缩:
cat >> .config <<EOF
CONFIG_TARGET_IMAGES_GZIP=y
EOF

# 编译UEFI固件:
# cat >> .config <<EOF
# CONFIG_EFI_IMAGES=y
# EOF

# 网卡驱动:
cat >> .config <<EOF
CONFIG_PACKAGE_kmod-phy-realtek=y
CONFIG_PACKAGE_kmod-r8169=y
CONFIG_PACKAGE_kmod-rtl8187SE=y
CONFIG_PACKAGE_luci-app-arpbind=y #单软路由需要添加,双软路由不需要
EOF

# 编译PVE/KVM、Hyper-V、VMware镜像以及镜像填充
cat >> .config <<EOF
CONFIG_QCOW2_IMAGES=y
CONFIG_VHDX_IMAGES=y
CONFIG_VMDK_IMAGES=y
CONFIG_TARGET_IMAGES_PAD=y
EOF

# 多文件系统支持:
# cat >> .config <<EOF
# CONFIG_PACKAGE_kmod-fs-nfs=y
# CONFIG_PACKAGE_kmod-fs-nfs-common=y
# CONFIG_PACKAGE_kmod-fs-nfs-v3=y
# CONFIG_PACKAGE_kmod-fs-nfs-v4=y
# CONFIG_PACKAGE_kmod-fs-ntfs=y
# CONFIG_PACKAGE_kmod-fs-squashfs=y
# EOF

# USB3.0支持:
# cat >> .config <<EOF
# CONFIG_PACKAGE_kmod-usb-ohci=y
# CONFIG_PACKAGE_kmod-usb-ohci-pci=y
# CONFIG_PACKAGE_kmod-usb2=y
# CONFIG_PACKAGE_kmod-usb2-pci=y
# CONFIG_PACKAGE_kmod-usb3=y
# EOF

# 多线多拨:
# cat >> .config <<EOF
# CONFIG_PACKAGE_luci-app-syncdial=y #多拨虚拟WAN
# CONFIG_PACKAGE_luci-app-mwan3=y #MWAN负载均衡
# CONFIG_PACKAGE_luci-app-mwan3helper=n #MWAN3分流助手
# EOF

# 第三方插件选择:
cat >> .config <<EOF
CONFIG_PACKAGE_luci-app-oaf=y #应用过滤
CONFIG_PACKAGE_luci-app-openclash=y #OpenClash客户端
CONFIG_PACKAGE_luci-app-store=y #应用商店
CONFIG_PACKAGE_luci-app-serverchan=y #微信推送
CONFIG_PACKAGE_luci-app-eqos=y #IP限速
CONFIG_PACKAGE_luci-app-poweroff=y #关机（增加关机功能）
CONFIG_PACKAGE_luci-app-autotimeset=y #定时重启系统，网络
# CONFIG_PACKAGE_luci-app-ddnsto=y #小宝开发的DDNS.to内网穿透
# CONFIG_PACKAGE_ddnsto=y #DDNS.to内网穿透软件包
EOF

# ShadowsocksR插件:
cat >> .config <<EOF
CONFIG_PACKAGE_luci-app-ssr-plus=y
EOF

# Passwall插件:
cat >> .config <<EOF
CONFIG_PACKAGE_luci-app-passwall=y
CONFIG_PACKAGE_naiveproxy=y
CONFIG_PACKAGE_kcptun-client=y
CONFIG_PACKAGE_chinadns-ng=y
CONFIG_PACKAGE_brook=y
CONFIG_PACKAGE_trojan-go=y
CONFIG_PACKAGE_xray-plugin=y
CONFIG_PACKAGE_shadowsocks-rust-sslocal=y
EOF

# Turbo ACC 网络加速:
cat >> .config <<EOF
CONFIG_PACKAGE_luci-app-turboacc=y
# luci-app-turboacc依赖
CONFIG_PACKAGE_dnsproxy=y
CONFIG_PACKAGE_dnsforwarder=y
EOF

# 常用LuCI插件:
cat >> .config <<EOF
CONFIG_PACKAGE_luci-app-adbyby-plus=y #adbyby去广告
CONFIG_PACKAGE_luci-app-webadmin=y #Web管理页面设置
CONFIG_PACKAGE_luci-app-filetransfer=y #系统-文件传输
CONFIG_PACKAGE_luci-app-autoreboot=n #定时重启
CONFIG_PACKAGE_luci-app-nps=y #nps内网穿透
CONFIG_PACKAGE_luci-app-frpc=n #Frp内网穿透
CONFIG_PACKAGE_luci-app-upnp=y #通用即插即用UPnP(端口自动转发)
CONFIG_DEFAULT_luci-app-vlmcsd=y #KMS激活服务器
CONFIG_PACKAGE_luci-app-ddns=n #DDNS服务
CONFIG_PACKAGE_luci-app-wol=y #网络唤醒
CONFIG_PACKAGE_luci-app-control-mia=y #时间控制
CONFIG_PACKAGE_luci-app-control-timewol=y #定时唤醒
CONFIG_PACKAGE_luci-app-control-webrestriction=y #访问限制
CONFIG_PACKAGE_luci-app-control-weburl=y #网址过滤
CONFIG_PACKAGE_luci-app-nlbwmon=y #宽带流量监控
CONFIG_PACKAGE_luci-app-wrtbwmon=y #实时流量监测
CONFIG_PACKAGE_luci-app-smartdns=n #smartdns服务器
CONFIG_PACKAGE_luci-app-diskman=n #磁盘管理磁盘信息
CONFIG_PACKAGE_luci-app-adguardhome=n #ADguardHome去广告服务
CONFIG_PACKAGE_luci-app-unblockmusic=n #解锁网易云灰色歌曲
CONFIG_PACKAGE_luci-app-xlnetacc=n #迅雷快鸟
CONFIG_PACKAGE_luci-app-usb-printer=n #USB打印机
CONFIG_PACKAGE_luci-app-mwan3helper=n #多拨负载均衡
CONFIG_PACKAGE_luci-app-mwan3=n #多线多拨
CONFIG_PACKAGE_luci-app-hd-idle=n #磁盘休眠
CONFIG_PACKAGE_luci-app-zerotier=n #Zerotier内网穿透
CONFIG_PACKAGE_luci-app-sqm=n #SQM智能队列管理
#
# VPN相关插件(禁用):
#
CONFIG_PACKAGE_luci-app-ipsec-vpnserver-manyusers=n #ipsec VPN服务
CONFIG_PACKAGE_luci-app-pppoe-relay=n #PPPoE穿透
CONFIG_PACKAGE_luci-app-pppoe-server=n #PPPoE服务器
CONFIG_PACKAGE_luci-app-pptp-vpnserver-manyusers=n #PPTP VPN 服务器
CONFIG_PACKAGE_luci-app-trojan-server=n #Trojan服务器
CONFIG_PACKAGE_luci-app-v2ray-server=n #V2ray服务器
CONFIG_PACKAGE_luci-app-brook-server=n #brook服务端
CONFIG_PACKAGE_luci-app-ssr-libev-server=n #ssr-libev服务端
CONFIG_PACKAGE_luci-app-ssr-python-pro-server=n #ssr-python服务端
CONFIG_PACKAGE_luci-app-kcptun=n #Kcptun客户端
CONFIG_PACKAGE_luci-app-softethervpn=n #SoftEtherVPN服务器
#
# 文件共享相关(禁用):
#
CONFIG_PACKAGE_luci-app-aria2=n #Aria2离线下载
CONFIG_PACKAGE_luci-app-minidlna=n #miniDLNA服务
CONFIG_PACKAGE_luci-app-kodexplorer=n #可到私有云
CONFIG_PACKAGE_luci-app-filebrowser=n #File Browser私有云
CONFIG_PACKAGE_luci-app-fileassistant=n #文件助手
CONFIG_PACKAGE_luci-app-vsftpd=n #FTP 服务器
CONFIG_PACKAGE_luci-app-samba=n #网络共享
CONFIG_PACKAGE_autosamba=n #网络共享
CONFIG_PACKAGE_samba36-server=n #网络共享
EOF

# LuCI主题:
cat >> .config <<EOF
CONFIG_PACKAGE_luci-theme-bootstrap=y
CONFIG_PACKAGE_luci-theme-material=y
CONFIG_PACKAGE_luci-theme-argon-light-mod=y
EOF

# 常用软件包:
cat >> .config <<EOF
CONFIG_PACKAGE_curl=y
CONFIG_PACKAGE_htop=y
CONFIG_PACKAGE_nano=y
# CONFIG_PACKAGE_screen=y
# CONFIG_PACKAGE_tree=y
# CONFIG_PACKAGE_vim-fuller=y
CONFIG_PACKAGE_wget=y
CONFIG_PACKAGE_bash=y
CONFIG_PACKAGE_node=y
CONFIG_PACKAGE_kmod-tun=y
CONFIG_PACKAGE_libcap=y
CONFIG_PACKAGE_libcap-bin=y
CONFIG_PACKAGE_ip6tables-mod-nat=y
CONFIG_PACKAGE_iptables-mod-extra=y
EOF

# 其他软件包:
cat >> .config <<EOF
CONFIG_HAS_FPU=y
EOF


# 
# ========================固件定制部分结束========================
# 

sed -i 's/^[ \t]*//g' ./.config

# 返回目录
cd $HOME

# 配置文件创建完成

