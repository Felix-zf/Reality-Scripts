#!/bin/bash

# 版本
VERSION="1.1.0"

# 颜色定义
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
PLAIN='\033[0m'

# 日志文件路径
log_file="/var/log/singbox_install.log"

# 函数定义
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$log_file"
}

red() {
    echo -e "\033[31m\033[01m$1\033[0m"
}

green() {
    echo -e "\033[32m\033[01m$1\033[0m"
}

yellow() {
    echo -e "\033[33m\033[01m$1\033[0m"
}

confirm() {
    read -p "$1 (y/n): " -n 1 -r
    echo
    [[ $REPLY =~ ^[Yy]$ ]] && return 0 || return 1
}

validate_port() {
    local port=$1
    if [[ $port =~ ^[0-9]+$ && $port -ge 1 && $port -le 65535 ]]; then
        return 0
    else
        return 1
    fi
}

generate_uuid() {
    uuidgen
}

generate_keypair() {
    sing-box generate reality-keypair
}

generate_short_id() {
    openssl rand -hex 8
}

# 安装基础依赖
install_base() {
    log "Updating system packages..."
    sudo apt-get update >/dev/null 2>&1 || { red "更新系统包失败" && log "更新系统包失败" && exit 1; }
    sudo apt-get install -y curl wget sudo tar openssl jq >/dev/null 2>&1 || { red "安装基础依赖失败" && log "安装基础依赖失败" && exit 1; }
}

# 安装Sing-box
install_singbox() {
    log "Installing Sing-box..."
    if ! confirm "你确定要安装 Sing-box Reality 吗？"; then
        log "用户取消安装"
        exit 0
    fi

    sudo curl -fsSL https://sing-box.app/gpg.key -o /etc/apt/keyrings/sagernet.asc
    sudo chmod a+r /etc/apt/keyrings/sagernet.asc
    echo "deb [arch=`dpkg --print-architecture` signed-by=/etc/apt/keyrings/sagernet.asc] https://deb.sagernet.org/ * *" | \
    sudo tee /etc/apt/sources.list.d/sagernet.list > /dev/null
    sudo apt-get update >/dev/null 2>&1 || { red "更新 apt 源失败" && log "更新 apt 源失败" && exit 1; }
    sudo apt-get install -y sing-box >/dev/null 2>&1 || { red "安装 Sing-box 失败" && log "安装 Sing-box 失败" && exit 1; }

    # 生成配置
    UUID=$(generate_uuid)
    keys=$(generate_keypair)
    private_key=$(echo $keys | awk -F " " '{print $2}')
    public_key=$(echo $keys | awk -F " " '{print $4}')
    short_id=$(generate_short_id)

    read -p "设置 Sing-box 端口 [1-65535]（回车则随机分配端口）：" port
    if [[ -z $port ]]; then
        port=$(shuf -i 2000-65535 -n 1)
    fi
    until validate_port "$port" && [[ -z $(ss -ntlp | awk '{print $4}' | sed 's/.*://g' | grep -w "$port") ]]; do
        echo -e "${RED} $port ${PLAIN} 端口已经被其他程序占用，请更换端口重试！"
        read -p "设置 Sing-box 端口 [1-65535]（回车则随机分配端口）：" port
        [[ -z $port ]] && port=$(shuf -i 2000-65535 -n 1)
    done

    read -rp "请输入 UUID [可留空待脚本生成]: " user_uuid
    [[ -z $user_uuid ]] && user_uuid=$UUID

    read -rp "请输入配置回落的域名 [默认世嘉官网]: " dest_server
    [[ -z $dest_server ]] && dest_server="www.sega.com"

    cat << EOF > /etc/sing-box/config.json
{
    "log": {
        "level": "trace",
        "timestamp": true
    },
    "inbounds": [
        {
            "type": "vless",
            "tag": "vless-in",
            "listen": "::",
            "listen_port": $port,
            "sniff": true,
            "sniff_override_destination": true,
            "users": [
                {
                    "uuid": "$user_uuid",
                    "flow": "xtls-rprx-vision"
                }
            ],
            "tls": {
                "enabled": true,
                "server_name": "$dest_server",
                "reality": {
                    "enabled": true,
                    "handshake": {
                        "server": "$dest_server",
                        "server_port": 443
                    },
                    "private_key": "$private_key",
                    "short_id": [
                        "$short_id"
                    ]
                }
            }
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
        }
    ],
    "route": {
        "rules": [
            {
                "geoip": "cn",
                "outbound": "block"
            },
            {
                "geosite": "category-ads-all",
                "outbound": "block"
            }
        ],
        "final": "direct"
    }
}
EOF
    if ! jq -e . >/dev/null 2>&1 <<< "$(cat /etc/sing-box/config.json)"; then
        red "配置文件格式错误，安装失败！"
        log "配置文件格式错误，安装失败！"
        exit 1
    fi

    mkdir -p /root/sing-box

    # 生成 vless 分享链接及 Clash Meta 配置文件
    share_link="vless://$user_uuid@$IP:$port?encryption=none&flow=xtls-rprx-vision&security=reality&sni=$dest_server&fp=chrome&pbk=$public_key&sid=$short_id&type=tcp&headerType=none#Felix-Reality"
    echo ${share_link} > /root/sing-box/share-link.txt
    # 省略了Clash Meta配置文件生成的部分

    sudo systemctl start sing-box >/dev/null 2>&1 || { red "启动 Sing-box 失败" && log "启动 Sing-box 失败" && exit 1; }
    sudo systemctl enable sing-box >/dev/null 2>&1

    if [[ -n $(sudo systemctl status sing-box 2>/dev/null | grep -w active) && -f '/etc/sing-box/config.json' ]]; then
        green "Sing-box 服务启动成功"
        log "Sing-box 服务启动成功"
    else
        red "Sing-box 服务启动失败，请运行 sudo systemctl status sing-box 查看服务状态并反馈，脚本退出"
        log "Sing-box 服务启动失败"
        exit 1
    fi

    yellow "下面是 Sing-box Reality 的分享链接，并已保存至 /root/sing-box/share-link.txt"
    red $share_link
    # yellow "Clash Meta 配置文件已保存至 /root/sing-box/clash-meta.yaml"
}

# 主菜单
menu() {
    clear
    echo "#############################################################"
    echo -e "#               ${RED}Sing-box Reality 一键安装脚本 v$VERSION${PLAIN}               #"
    echo -e "# ${GREEN}作者${PLAIN}: 秋名山吃豆腐                                        #"
    echo -e "# ${GREEN}博客${PLAIN}: https://felix-zf.github.io                          #"
    echo -e "# ${GREEN}GitHub 项目${PLAIN}: https://github.com/Felix-zf                  #"
    echo -e "# ${GREEN}GitLab 项目${PLAIN}: https://gitlab.com/Felix-zf                  #"
    echo -e "# ${GREEN}Telegram 频道${PLAIN}: https://t.me/xxxxxx                        #"
    echo -e "# ${GREEN}Telegram 群组${PLAIN}: https://t.me/xxxxxx                        #"
    echo -e "# ${GREEN}YouTube 频道${PLAIN}: https://www.youtube.com/@Felix7200GT        #"
    echo "#############################################################"
    echo ""
    echo -e " ${GREEN}1.${PLAIN} 安装 Sing-box Reality"
    echo -e " ${GREEN}0.${PLAIN} 退出"
    echo ""
    read -rp " 请输入选项 [0-1] ：" answer
    case $answer in
        1) install_singbox ;;
        *) red "请输入正确的选项 [0-1]！" && exit 1 ;;
    esac
}

# 确保脚本以 root 权限运行
if [[ $EUID -ne 0 ]]; then
   red "注意：请在root用户下运行脚本"
   log "脚本需要以root权限运行，但当前用户不是root"
   exit 1
fi

# 检测系统和安装依赖
if [[ -f /etc/debian_version ]]; then
    install_base
else
    red "此脚本仅支持Debian系统。"
    exit 1
fi

# 开始主菜单
menu
