#!/bin/bash

# 版本
VERSION="1.1.0"

# 颜色定义
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
PLAIN='\033[0m'

# 日志文件路径
log_file="/var/log/xray_install.log"

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

# 安装基础依赖
install_base() {
    log "Updating system packages..."
    sudo apt-get update >/dev/null 2>&1 || { red "更新系统包失败" && log "更新系统包失败" && exit 1; }
    sudo apt-get install -y curl wget sudo tar openssl jq >/dev/null 2>&1 || { red "安装基础依赖失败" && log "安装基础依赖失败" && exit 1; }
}

# 安装Xray
install_xray() {
    log "Installing Xray..."
    if ! confirm "你确定要安装 Xray Reality 吗？"; then
        log "用户取消安装"
        exit 0
    fi

    # 安装Xray
    sudo bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install || { red "安装 Xray 失败" && log "安装 Xray 失败" && exit 1; }

    # 生成配置
    UUID=$(xray uuid)
    keys=$(xray x25519)
    private_key=$(echo $keys | cut -d ' ' -f2)
    public_key=$(echo $keys | cut -d ' ' -f4)
    short_id=$(openssl rand -hex 8)

    read -p "设置 Xray 端口 [1-65535]（回车则随机分配端口）：" port
    if [[ -z $port ]]; then
        port=$(shuf -i 2000-65535 -n 1)
    fi
    until validate_port "$port" && [[ -z $(ss -ntlp | awk '{print $4}' | sed 's/.*://g' | grep -w "$port") ]]; do
        echo -e "${RED} $port ${PLAIN} 端口已经被其他程序占用，请更换端口重试！"
        read -p "设置 Xray 端口 [1-65535]（回车则随机分配端口）：" port
        [[ -z $port ]] && port=$(shuf -i 2000-65535 -n 1)
    done

    read -rp "请输入 UUID [可留空待脚本生成]: " user_uuid
    [[ -z $user_uuid ]] && user_uuid=$UUID

    read -rp "请输入配置回落的域名 [默认微软官网]: " dest_server
    [[ -z $dest_server ]] && dest_server="www.microsoft.com"

    cat << EOF > /usr/local/etc/xray/config.json
{
    "log": {
        "loglevel": "warning"
    },
    "inbounds": [
        {
            "port": $port,
            "listen": "0.0.0.0",
            "protocol": "vless",
            "settings": {
                "clients": [
                    {
                        "id": "$user_uuid",
                        "flow": "xtls-rprx-vision"
                    }
                ],
                "decryption": "none"
            },
            "streamSettings": {
                "network": "tcp",
                "security": "reality",
                "realitySettings": {
                    "show": false,
                    "dest": "$dest_server",
                    "xver": 0,
                    "serverNames": [
                        "$dest_server"
                    ],
                    "privateKey": "$private_key",
                    "shortIds": ["$short_id"]
                }
            }
        }
    ],
    "outbounds": [
        {
            "protocol": "freedom",
            "settings": {}
        }
    ]
}
EOF

    sudo systemctl enable xray >/dev/null 2>&1 || { red "启用 Xray 服务失败" && log "启用 Xray 服务失败" && exit 1; }
    sudo systemctl start xray >/dev/null 2>&1 || { red "启动 Xray 服务失败" && log "启动 Xray 服务失败" && exit 1; }

    if [[ -n $(sudo systemctl status xray 2>/dev/null | grep -w active) ]]; then
        green "Xray 服务启动成功"
        log "Xray 服务启动成功"
    else
        red "Xray 服务启动失败，请运行 sudo systemctl status xray 查看服务状态并反馈，脚本退出"
        log "Xray 服务启动失败"
        exit 1
    fi

    # 生成 vless 分享链接
    share_link="vless://$user_uuid@$(curl -s ifconfig.me):$port?encryption=none&flow=xtls-rprx-vision&security=reality&sni=$dest_server&fp=chrome&pbk=$public_key&sid=$short_id#Xray-Reality"
    echo ${share_link} > /root/xray-reality-share-link.txt

    yellow "下面是 Xray Reality 的分享链接，并已保存至 /root/xray-reality-share-link.txt"
    red $share_link
}

# 主菜单
menu() {
    clear
    echo "#############################################################"
    echo -e "#               ${RED}Xray Reality 一键安装脚本 v$VERSION${PLAIN}               #"
    echo -e "# ${GREEN}作者${PLAIN}: 秋名山吃豆腐                                        #"
    echo -e "# ${GREEN}博客${PLAIN}: https://felix-zf.github.io                          #"
    echo -e "# ${GREEN}GitHub 项目${PLAIN}: https://github.com/Felix-zf                  #"
    echo -e "# ${GREEN}GitLab 项目${PLAIN}: https://gitlab.com/Felix-zf                  #"
    echo -e "# ${GREEN}Telegram 频道${PLAIN}: https://t.me/xxxxxx                        #"
    echo -e "# ${GREEN}Telegram 群组${PLAIN}: https://t.me/xxxxxx                        #"
    echo -e "# ${GREEN}YouTube 频道${PLAIN}: https://www.youtube.com/@Felix7200GT        #"
    echo "#############################################################"
    echo ""
    echo -e " ${GREEN}1.${PLAIN} 安装 Xray Reality"
    echo -e " ${GREEN}0.${PLAIN} 退出"
    echo ""
    read -rp " 请输入选项 [0-1] ：" answer
    case $answer in
        1) install_xray ;;
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
