# 基于Sing-box内核的脚本搭建教程

- Project Core Sing-box：https://github.com/SagerNet/sing-box
- Sing-box Offical Blog: https://sing-box.sagernet.org/zh
- Offical Blog: https://sing-box.sagernet.org

## Sing-box & Vless reality 协议脚本

1.SSH进入VPS，复制粘贴并执行以下脚本
```shell
wget -N --no-check-certificate https://raw.githubusercontent.com/Felix-zf/Singbox-Scripts/main/reality.sh && bash reality.sh
```
2.输入1选项，安装Sing-box Reality  
3.等待安装依赖之后、设置端口号、UUID和回落域名
4.管理命令为：bash reality.sh，可使用6选项修改Reality的配置文件

### 回落域名说明
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

------
## Sing-box & hysteria 2 手动配置

### debian/APT安装
1.仓库安装
```
sudo curl -fsSL https://sing-box.app/gpg.key -o /etc/apt/keyrings/sagernet.asc
sudo chmod a+r /etc/apt/keyrings/sagernet.asc
echo "deb [arch=`dpkg --print-architecture` signed-by=/etc/apt/keyrings/sagernet.asc] https://deb.sagernet.org/ * *" | \
  sudo tee /etc/apt/sources.list.d/sagernet.list > /dev/null
sudo apt-get update
sudo apt-get install sing-box # or sing-box-beta
```
2.手动安装
```
bash <(curl -fsSL https://sing-box.app/deb-install.sh)
```

### 服务端配置样例
- 新建hy2.json文件
```
cd /date/
cd singbox
ls
vim hy2.json
clear
```
- 修改配置文件
```
{
  "log": {
    "disabled": false,
    "level": "info",
    "timestamp": true
  },
  "dns": {
    "servers": [
      {
        "tag": "cloudflare",
        "address": "https://1.1.1.1/dns-query",
        "strategy": "ipv4_only",
        "detour": "direct"
      },
      {
        "tag": "block",
        "address": "rcode://success"
      }
    ],
    "rules": [
      {
        "geosite": [
          "category-ads-all"
        ],
        "server": "block",
        "disable_cache": true
      }
    ],
    "final": "cloudflare",
    "strategy": "",
    "disable_cache": false,
    "disable_expire": false
  },
  "inbounds": [
    {
      "type": "hysteria2",
      "listen": "::",
      "listen_port": 443,
      "up_mbps": 100,
      "down_mbps": 100,
      "users": [
        {
          "name": "sekai",
          "password": "<password>"
        }
      ],
      "tls": {
        "enabled": true,
        "server_name": "example.org",
        "acme": {
          "domain": "example.org",
          "email": "admin@example.org"
        }
      }
    }
  ]
      },
      "masquerade": "https://bing.com",
      "brutal_debug": false
    }
  ],
  "outbounds": [
    {
      "type": "direct",
      "tag": "direct"
    },
    {
      "type": "block",
      "tag": "block"
    },
    {
      "type": "dns",
      "tag": "dns-out"
    }
  ],
  "route": {
    "geoip": {
      "path": "geoip.db",
      "download_url": "https://github.com/SagerNet/sing-geoip/releases/latest/download/geoip.db",
      "download_detour": "direct"
    },
    "geosite": {
      "path": "geosite.db",
      "download_url": "https://github.com/SagerNet/sing-geosite/releases/latest/download/geosite.db",
      "download_detour": "direct"
    },
    "rules": [
      {
        "protocol": "dns",
        "outbound": "dns-out"
      },
      {
        "geosite": [
          "category-ads-all"
        ],
        "outbound": "block"
      }
    ],
    "auto_detect_interface": true,
    "final": "direct"
  },
  "experimental": {}
}
```

### 客户端配置样例
```
{
  "dns": {
    "servers": [
      {
        "tag": "alidns",
        "address": "https://223.5.5.5/dns-query",
        "strategy": "ipv4_only",
        "detour": "direct"
      },
      {
        "tag": "cloudflare",
        "address": "https://1.1.1.1/dns-query",
        "strategy": "ipv4_only",
        "detour": "proxy"
      },
      {
        "tag": "block",
        "address": "rcode://success"
      }
    ],
    "rules": [
      {
        "geosite": [
          "cn"
        ],
        "domain_suffix": [
          ".cn"
        ],
        "server": "alidns",
        "disable_cache": false
      },
      {
        "geosite": [
          "category-ads-all"
        ],
        "server": "block",
        "disable_cache": true
      }
    ],
    "final": "cloudflare",
    "strategy": "",
    "disable_cache": false,
    "disable_expire": false
  },
  "inbounds": [
    {
      "type": "mixed",
      "tag": "mixed-in",
      "listen": "::",
      "listen_port": 5353,
      "tcp_fast_open": true,
      "udp_fragment": true,
      "sniff": true,
      "set_system_proxy": true
    }
  ],
  "outbounds": [
    {
      "type": "hysteria2",
      "server": "ip",
      "server_port": 443,
      "up_mbps": 100,
      "down_mbps": 100,
      "password": "<password>",
      "tls": {
        "enabled": true,
        "server_name": "example.org"
      }
    }
  ]
      },
      "brutal_debug": false
    },
    {
      "type": "direct",
      "tag": "direct"
    },
    {
      "type": "block",
      "tag": "block"
    },
    {
      "type": "dns",
      "tag": "dns-out"
    }
  ],
  "route": {
    "geoip": {
      "path": "geoip.db",
      "download_url": "https://github.com/SagerNet/sing-geoip/releases/latest/download/geoip.db",
      "download_detour": "direct"
    },
    "geosite": {
      "path": "geosite.db",
      "download_url": "https://github.com/SagerNet/sing-geosite/releases/latest/download/geosite.db",
      "download_detour": "direct"
    },
    "rules": [
      {
        "protocol": "dns",
        "outbound": "dns-out"
      },
      {
        "geosite": [
          "cn",
          "private"
        ],
        "geoip": [
          "cn",
          "private"
        ],
        "domain_suffix": [
          ".cn"
        ],
        "outbound": "direct"
      },
      {
        "geosite": [
          "category-ads-all"
        ],
        "outbound": "block"
      }
    ],
    "auto_detect_interface": true,
    "final": "proxy"
  },
  "experimental": {}
}
```

### 服务管理
1.启用
```
sudo systemctl enable sing-box
```
2.禁用
```
sudo systemctl disable sing-box
```
3.启动
```
sudo systemctl start sing-box
```
4.停止
```
sudo systemctl stop sing-box
```
5.查看日志
```
sudo journalctl -u sing-box --output cat -e
```
6.实时日志
```
sudo journalctl -u sing-box --output cat -f
```

## 鸣谢

* BoxXt 的 sing-box reality 项目：https://github.com/BoxXt/installReality
* Misaka 的 sing-box reality 项目：https://github.com/Misaka-blog/sbox-reality
* Misaka 的 sing-shadowtls-3 项目：https://github.com/Misaka-blog/sing-shadowtls-3
* Dev分享手搓sing-box hysteria 视频：https://www.youtube.com/watch?v=z6tIE6P-l4E
* 纯纯牛马林师傅手搓 sing-box 视频：https://www.youtube.com/watch?v=2QaeeZv9C-A
* Elden的sing-box配置hysteria2 笔记：https://idev.dev/proxy/singbox-hysteria2.html
