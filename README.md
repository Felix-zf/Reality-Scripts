# sbox-reality

- Project Core Sing-box：https://github.com/SagerNet/sing-box
- Offical Blog: https://sing-box.sagernet.org

## 基于 Sing-box 内核的 VLESS Reality 协议脚本

1.SSH进入VPS，复制粘贴并执行以下脚本
```shell
wget -N --no-check-certificate https://raw.githubusercontent.com/Felix-zf/Singbox-Scripts/main/reality.sh && bash reality.sh
```
2.输入1选项，安装Sing-box Reality  
3.等待安装依赖之后、设置端口号、UUID和回落域名
4.管理命令为：bash reality.sh，可使用6选项修改Reality的配置文件

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

## 鸣谢

* BoxXt 的 Sing-box Reality 项目：https://github.com/BoxXt/installReality
* Misaka 的 Sing-box Reality 项目：https://github.com/Misaka-blog/sbox-reality
* Misaka 的 sing-shadowtls-3 项目：https://github.com/Misaka-blog/sing-shadowtls-3

