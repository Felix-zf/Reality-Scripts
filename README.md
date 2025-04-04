# 搭建教程

- Project Core Sing-box：https://github.com/SagerNet/sing-box
- Project Core Xray: https://github.com/XTLS/Xray-core/releases
- Sing-box Offical Blog: https://sing-box.sagernet.org/zh
- Offical Blog: https://sing-box.sagernet.org

## 搭建准备
1.VPS性能检测
```
wget -qO- bench.sh | bash
```
2.Debian更新系统
```
sudo apt update
sudo apt upgrade
```
3.BBR加速
```
echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
sysctl -p
lsmod | grep bbr
```

## Vless reality 协议脚本

### 1.基于Sing-box内核的一键安装脚本

SSH进入VPS，复制粘贴并执行以下脚本  

- Auto Script
```
bash <(curl -fsSL https://github.com/Felix-zf/Reality-Scripts/raw/main/singbox-reality.sh)
```
- 223Boy Script
```
bash <(wget -qO- -o- https://github.com/233boy/sing-box/raw/main/install.sh)
```

***Sing-box内核相关命令***
```
sudo systemctl start sing-box      #启动sing-box
sudo systemctl stop sing-box       #停止sing-box
sudo systemctl restart sing-box    #重启sing-box
sudo systemctl status sing-box     #检查Sing-box服务状态
sudo systemctl enable sing-box     #启用Sing-box服务（设置为开机自启）
journalctl -u sing-box             #查看Sing-box服务的日志
```
Tips：Sing-box 一键安装脚本 & 管理脚本：https://github.com/233boy/sing-box

接着输入1选项，安装Sing-box Reality，等待安装依赖之后、设置端口号、UUID和回落域名。管理命令为：bash reality.sh，可使用6选项修改Reality的配置文件

### 2.基于Xray内核的一键安装脚本

- Zxcvos的一键脚本
```
wget -N --no-check-certificate https://raw.githubusercontent.com/Felix-zf/Reality-Scripts/main/xray-reality.sh && bash xray-reality.sh
```
- Oldfriendme的一键脚本
```
wget -N --no-check-certificate https://raw.githubusercontent.com/Felix-zf/Reality-Scripts/main/x-reality.sh && bash x-reality.sh
```

***Xray内核相关命令***
```
xray.start     #启动xray
xray.stop      #停止xray
xray.restart   #重启xray
xray.chuuid    #重新生成uuid
xray.delxray   #彻底删除xray内核及脚本
xray.help      #帮助
```
Tips:详情见 Oldfriendme 的项目：https://github.com/oldfriendme/xrayREALITY

## 回落域名说明
1.选择回落域名的最低标准为：国外的网站，支持 TLS v1.3、H2 协议，并使用 x25519 证书  
```
# 域名推荐
gateway.icloud.com
itunes.apple.com
download-installer.cdn.mozilla.net
airbnb【这个不同的区有不同的域名建议自己搜索】
addons.mozilla.org
www.microsoft.com
www.lovelive-anime.jp

# CDN
Apple:
swdist.apple.com
swcdn.apple.com
updates.cdn-apple.com
mensura.cdn-apple.com
osxapps.itunes.apple.com
aod.itunes.apple.com

Microsoft:
cdn-dynmedia-1.microsoft.com
update.microsoft
software.download.prss.microsoft.com

Amazon:
s0.awsstatic.com
d1.awsstatic.com
images-na.ssl-images-amazon.com
m.media-amazon.com
player.live-video.net

Google:
dl.google.com
```
2.检测方法  
- 打开Chrome，进入待测网页。按下F12键，转到“Secure”选项卡。在“Connection”下出现“TLS 1.3，X25519”字样即代表网页支持 TLSv1.3 协议、并且使用的是 x25519 证书
- 转到“Console”选项卡，输入这个命令 window.chrome.loadTimes()，查看 npnNegotiatedProtocol 的值是否为 h2，如果是的话就代表使用的是 H2 协议


## 功能介绍
- 集成快捷指令Command【xray.start, xray.stop, xray.restart, xray.chuuid, xray.delxray】
- 单用户使用
- 支持sni-filter模式，阻止指向cdn后被偷跑流量(X64)。
- 脚本构造简单，只支持REALITY协议，不支持其他协议。


## 注意事项
> Important

如果你的机器是双栈IP或者其他多IP，IP地址应该替换为实际入口IP

如IPv6为`2001:4860:1234::8888`，生成的订阅为：

`vless://uuid@[2001:4860::8888]:443?encryption=none&security=reality&sni=...`

但是入口为IPv4:`1.1.8.8`

应该改为

`vless://uuid@1.1.8.8:443?encryption=none&security=reality&sni=...`


## 常见问题
**默认内核Xray-core v1.8.21如何更换**

脚本第80行修改

**没有相应架构怎么办**

脚本第87行接着加


## 鸣谢

* BoxXt 的 sing-box reality 项目：https://github.com/BoxXt/installReality
* Misaka 的 sing-box reality 项目：https://github.com/Misaka-blog/sbox-reality
* Misaka 的 sing-shadowtls-3 项目：https://github.com/Misaka-blog/sing-shadowtls-3
* Dev分享手搓sing-box hysteria 视频：https://www.youtube.com/watch?v=z6tIE6P-l4E
* 纯纯牛马林师傅手搓 sing-box 视频：https://www.youtube.com/watch?v=2QaeeZv9C-A
* Elden的sing-box配置hysteria2 笔记：https://idev.dev/proxy/singbox-hysteria2.html
* Zxcvos的xray-script项目搭建vless-reality：https://github.com/zxcvos/Xray-script
* ooly手动搭建reality脚本教程：https://ooly.cc/archives/linux/406/
* deathline94's scripts: https://github.com/deathline94/sing-REALITY-Box

