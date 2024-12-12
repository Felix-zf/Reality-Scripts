#!/bin/bash

# 定义颜色
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
PLAIN="\033[0m"

# 函数定义
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

red() {
    echo -e "${RED}$1${PLAIN}"
}

green() {
    echo -e "${GREEN}$1${PLAIN}"
}

yellow() {
    echo -e "${YELLOW}$1${PLAIN}"
}

# 确认函数
confirm() {
    read -p "$1 (y/n): " -n 1 -r
    echo
    [[ $REPLY =~ ^[Yy]$ ]] && return 0 || return 1
}

# 安装Sing-box
install_singbox() {
    log "Installing Sing-box with VLESS + REALITY..."
    if ! confirm "你确定要安装 Sing-box 并配置 VLESS + REALITY 吗？"; then
        log "用户取消安装"
        exit 0
    fi

    # 下载Sing-box
    latest_version=$(curl -s https://api.github.com/repos/SagerNet/sing-box/releases/latest | grep 'tag_name' | cut -d '"' -f 4)
    if [[ "$(uname -m)" == "x86_64" ]]; then
        arch="amd64"
    elif [[ "$(uname -m)" == "aarch64" ]]; then
        arch="arm64"
    else
        red "不支持的架构: $(uname -m)"
        exit 1
    fi

    wget -O sing-box.tar.gz "https://github.com/SagerNet/sing-box/releases/download/${latest_version}/sing-box-${latest_version}-linux-${arch}.tar.gz" || { red "下载 Sing-box 失败" && exit 1; }
    tar -xf sing-box.tar.gz -C /usr/bin/ || { red "解压 Sing-box 失败" && exit 1; }
    rm sing-box.tar.gz

    # 获取用户输入
    echo -e "请输入监听端口 (默认: 443):"
    read -r listen_port
    listen_port=${listen_port:-443}
    echo -e "请输入伪装的域名 (默认: example.com):"
    read -r domain_name
    domain_name=${domain_name:-example.com}

    # 生成VLESS+REALITY客户端配置
    uuid=$(/usr/bin/sing-box generate uuid)
    public_key=$(/usr/bin/sing-box generate reality-key | grep -oP 'Public Key: \K.*')
    private_key=$(/usr/bin/sing-box generate reality-key | grep -oP 'Private Key: \K.*')

    cat << EOF > /etc/sing-box/config.json
{
  "log": {
    "level": "info",
    "timestamp": true
  },
  "inbounds": [
    {
      "type": "tun",
      "inet4_address": "172.19.0.1/30",
      "inet6_address": "fdfe:dcba:9876::1/126",
      "auto_route": true,
      "strict_route": true,
      "endpoint_independent_nat": true,
      "stack": "system",
      "mtu": 1280
    },
    {
      "type": "mixed",
      "listen": "0.0.0.0",
      "listen_port": 1080
    }
  ],
  "outbounds": [
    {
      "type": "vless",
      "server": "0.0.0.0",
      "server_port": ${listen_port},
      "uuid": "${uuid}",
      "flow": "xtls-rprx-vision",
      "security": "reality",
      "reality": {
        "public_key": "${public_key}",
        "private_key": "${private_key}",
        "short_id": ["00000000"],
        "server_names": ["${domain_name}"]
      },
      "transport": {
        "type": "tcp",
        "tcp_settings": {
          "header": {
            "type": "none"
          }
        }
      }
    }
  ],
  "route": {
    "rules": [
      {
        "outbound": "vless",
        "inbound": ["tun"]
      }
    ]
  }
}
EOF

    # 创建服务文件
    cat << EOF > /etc/systemd/system/sing-box.service
[Unit]
Description=Sing-box Service
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/sing-box run -c /etc/sing-box/config.json
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

    # 启用并启动服务
    sudo systemctl enable sing-box >/dev/null 2>&1 || { red "启用 Sing-box 服务失败" && exit 1; }
    sudo systemctl start sing-box >/dev/null 2>&1 || { red "启动 Sing-box 服务失败" && exit 1; }

    if [[ -n $(sudo systemctl status sing-box 2>/dev/null | grep -w active) ]]; then
        green "Sing-box 配置 VLESS + REALITY 成功，监听端口: ${listen_port}，域名: ${domain_name}"
        log "Sing-box 配置 VLESS + REALITY 成功"
        
        # 生成VLESS链接
        vless_link="vless://${uuid}@${domain_name}:${listen_port}?security=reality&flow=xtls-rprx-vision&sni=${domain_name}&fp=chrome&pbk=${public_key}&sid=00000000&type=tcp#Sing-box"
        green "VLESS链接如下："
        echo -e "\n${vless_link}\n"
    else
        red "Sing-box 配置 VLESS + REALITY 失败，请运行 sudo systemctl status sing-box 查看服务状态并反馈"
        log "Sing-box 配置 VLESS + REALITY 失败"
        exit 1
    fi
}

# 主菜单
menu() {
    clear
    echo -e "#               ${RED}Sing-box VLESS + REALITY 一键搭建脚本${PLAIN}               #"
    echo -e "# ${GREEN}作者${PLAIN}: 秋名山吃豆腐                                        #"
    echo -e "# ${GREEN}博客${PLAIN}: https://felix-zf.github.io                          #"
    echo -e "# ${GREEN}GitHub 项目${PLAIN}: https://github.com/Felix-zf                  #"
    echo -e "# ${GREEN}GitLab 项目${PLAIN}: https://gitlab.com/Felix-zf                  #"
    echo -e "# ${GREEN}Telegram 频道${PLAIN}: https://t.me/xxxxxx                        #"
    echo -e "# ${GREEN}Telegram 群组${PLAIN}: https://t.me/xxxxxx                        #"
    echo -e "# ${GREEN}YouTube 频道${PLAIN}: https://www.youtube.com/@Felix7200GT        #"
    echo ""
    echo -e " ${GREEN}1.${PLAIN} 安装 Sing-box 并配置 VLESS + REALITY"
    echo -e " ${GREEN}2.${PLAIN} 卸载 Sing-box"
    echo -e " ${GREEN}0.${PLAIN} 退出"
    echo ""
    read -rp " 请输入选项 [0-2] ：" answer
    case $answer in
        1) install_singbox ;;
        2) uninstall_singbox ;;
        *) red "请输入正确的选项 [0-2]！" && exit 1 ;;
    esac
}

# 卸载Sing-box
uninstall_singbox() {
    log "Uninstalling Sing-box..."
    if ! confirm "你确定要卸载 Sing-box 吗？"; then
        log "用户取消卸载"
        exit 0
    fi

    sudo systemctl stop sing-box >/dev/null 2>&1 || { red "停止 Sing-box 服务失败" && exit 1; }
    sudo systemctl disable sing-box >/dev/null 2>&1 || { red "禁用 Sing-box 服务失败" && exit 1; }
    sudo rm /usr/bin/sing-box >/dev/null 2>&1 || { red "删除 Sing-box 二进制文件失败" && exit 1; }
    sudo rm /etc/sing-box/config.json >/dev/null 2>&1 || { red "删除 Sing-box 配置文件失败" && exit 1; }
    sudo rm /etc/systemd/system/sing-box.service >/dev/null 2>&1 || { red "删除 Sing-box 服务文件失败" && exit 1; }

    green "Sing-box 卸载完成"
    log "Sing-box 卸载完成"
}

# 确保脚本以 root 权限运行
if [[ $EUID -ne 0 ]]; then
   red "注意：请在root用户下运行脚本"
   log "脚本需要以root权限运行，但当前用户不是root"
   exit 1
fi

# 开始主菜单
menu
