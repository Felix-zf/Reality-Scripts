#!/bin/bash

RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
PLAIN='\033[0m'

red() {
    echo -e "\033[31m\033[01m$1\033[0m"
}

green() {
    echo -e "\033[32m\033[01m$1\033[0m"
}

yellow() {
    echo -e "\033[33m\033[01m$1\033[0m"
}

REGEX=("debian" "ubuntu" "centos|red hat|kernel|oracle linux|alma|rocky" "'amazon linux'" "fedora" "alpine")
RELEASE=("Debian" "Ubuntu" "CentOS" "CentOS" "Fedora" "Alpine")
PACKAGE_UPDATE=("apt-get update" "apt-get update" "yum -y update" "yum -y update" "yum -y update" "apk update -f")
PACKAGE_INSTALL=("apt -y install" "apt -y install" "yum -y install" "yum -y install" "yum -y install" "apk add -f")
PACKAGE_UNINSTALL=("apt -y autoremove" "apt -y autoremove" "yum -y autoremove" "yum -y autoremove" "yum -y autoremove" "apk del -f")

[[ $EUID -ne 0 ]] && red "注意：请在root用户下运行脚本" && exit 1

# 获取系统信息
get_system_info(){
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        SYS_NAME=$NAME
    elif command -v lsb_release &>/dev/null; then
        SYS_NAME=$(lsb_release -sd)
    elif command -v hostnamectl &>/dev/null; then
        SYS_NAME=$(hostnamectl | grep -i "Operating System" | awk -F ":" '{print $2}' | xargs)
    else
        SYS_NAME="Unknown"
    fi
    echo "$SYS_NAME"
}

SYS=$(get_system_info)

# 检测操作系统
for ((i=0; i<${#REGEX[@]}; i++)); do
    if [[ "$SYS" =~ ${REGEX[i]} ]]; then
        SYSTEM="${RELEASE[i]}"
        break
    fi
done

[[ -z $SYSTEM ]] && red "不支持的操作系统，请使用主流操作系统。" && exit 1

# 检测 VPS 处理器架构
archAffix() {
    case "$(uname -m)" in
        x86_64 | amd64) echo 'amd64' ;;
        armv8 | arm64 | aarch64) echo 'arm64' ;;
        s390x) echo 's390x' ;;
        *) red "不支持的CPU架构!" && exit 1 ;;
    esac
}

install_base(){
    if [[ ! $SYSTEM == "CentOS" ]]; then
        ${PACKAGE_UPDATE[int]}
    fi
    ${PACKAGE_INSTALL[int]} curl wget sudo tar openssl
}

install_singbox(){
    install_base

    last_version=$(curl -s https://data.jsdelivr.com/v1/package/gh/SagerNet/sing-box | sed -n 4p | tr -d ',"' | awk '{print $1}')
    if [[ -z $last_version ]]; then
        red "获取版本信息失败，请检查VPS的网络状态！"
        exit 1
    fi

    if [[ $SYSTEM == "CentOS" ]]; then
        wget https://github.com/SagerNet/sing-box/releases/download/v"$last_version"/sing-box_"$last_version"_linux_$(archAffix).rpm -O sing-box.rpm
        rpm -ivh sing-box.rpm
        rm -f sing-box.rpm
    else
        wget https://github.com/SagerNet/sing-box/releases/download/v"$last_version"/sing-box_"$last_version"_linux_$(archAffix).deb -O sing-box.deb
        dpkg -i sing-box.deb
        rm -f sing-box.deb
    fi

    if [[ -f "/etc/systemd/system/sing-box.service" ]]; then
        green "Sing-box 安装成功！"
    else
        red "Sing-box 安装失败！"
        exit 1
    fi
    
    # 询问用户有关 Reality 端口、UUID 和回落域名
    read -p "设置 Sing-box 端口 [1-65535]（回车则随机分配端口）：" port
    [[ -z $port ]] && port=$(shuf -i 2000-65535 -n 1)
    until [[ -z $(ss -ntlp | awk '{print $4}' | sed 's/.*://g' | grep -w "$port") ]]; do
        echo -e "${RED} $port ${PLAIN} 端口已经被其他程序占用，请更换端口重试！"
        read -p "设置 Sing-box 端口 [1-65535]（回车则随机分配端口）：" port
        [[ -z $port ]] && port=$(shuf -i 2000-65535 -n 1)
    done
    read -rp "请输入 UUID [可留空待脚本生成]: " UUID
    [[ -z $UUID ]] && UUID=$(sing-box generate uuid)
    read -rp "请输入配置回落的域名 [默认世嘉官网]: " dest_server
    [[ -z $dest_server ]] && dest_server="www.sega.com"

    # Reality short-id
    short_id=$(openssl rand -hex 8)

    # Reality 公私钥
    keys=$(sing-box generate reality-keypair)
    private_key=$(echo $keys | awk -F " " '{print $2}')
    public_key=$(echo $keys | awk -F " " '{print $4}')

    # 将默认的配置文件删除，并写入 Reality 配置
    rm -f /etc/sing-box/config.json
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
                    "uuid": "$UUID",
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

    warp_v4=$(curl -s4m8 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2)
    warp_v6=$(curl -s6m8 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2)
    if [[ $warp_v4 =~ on|plus ]] || [[ $warp_v6 =~ on|plus ]]; then
        systemctl stop warp-go >/dev/null 2>&1
        systemctl disable warp-go >/dev/null 2>&1
        wg-quick down wgcf >/dev/null 2>&1
        systemctl disable wg-quick@wgcf >/dev/null 2>&1
        IP=$(expr "$(curl -ks4m8 -A Mozilla https://api.ip.sb/geoip)" : '.*ip\":[ ]*\"\([^"]*\).*') || IP=$(expr "$(curl -ks6m8 -A Mozilla https://api.ip.sb/geoip)" : '.*ip\":[ ]*\"\([^"]*\).*')
        systemctl start warp-go >/dev/null 2>&1
        systemctl enable warp-go >/dev/null 2>&1
        wg-quick start wgcf >/dev/null 2>&1
        systemctl enable wg-quick@wgcf >/dev/null 2>&1
    else
        IP=$(expr "$(curl -ks4m8 -A Mozilla https://api.ip.sb/geoip)" : '.*ip\":[ ]*\"\([^"]*\).*') || IP=$(expr "$(curl -ks6m8 -A Mozilla https://api.ip.sb/geoip)" : '.*ip\":[ ]*\"\([^"]*\).*')
    fi

    mkdir /root/sing-box >/dev
