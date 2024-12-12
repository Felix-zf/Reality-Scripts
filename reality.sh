    #!/bin/bash
    export LANG=en_US.UTF-8
    red='\033[0;31m'
    green='\033[0;32m'
    yellow='\033[0;33m'
    blue='\033[0;36m'
    bblue='\033[0;34m'
    plain='\033[0m'
    red(){ echo -e "\033[31m\033[01m$1\033[0m";}
    green(){ echo -e "\033[32m\033[01m$1\033[0m";}
    yellow(){ echo -e "\033[33m\033[01m$1\033[0m";}
    blue(){ echo -e "\033[36m\033[01m$1\033[0m";}
    white(){ echo -e "\033[37m\033[01m$1\033[0m";}
    readp(){ read -p "$(yellow "$1")" $2;}
    [[ $EUID -ne 0 ]] && yellow "请以root模式运行脚本" && exit
    #[[ -e /etc/hosts ]] && grep -qE '^ *172.65.251.78 gitlab.com' /etc/hosts || echo -e '\n172.65.251.78 gitlab.com' >> /etc/hosts
    if [[ -f /etc/redhat-release ]]; then
    release="Centos"
    elif cat /etc/issue | grep -q -E -i "alpine"; then
    release="alpine"
    elif cat /etc/issue | grep -q -E -i "debian"; then
    release="Debian"
    elif cat /etc/issue | grep -q -E -i "ubuntu"; then
    release="Ubuntu"
    elif cat /etc/issue | grep -q -E -i "centos|red hat|redhat"; then
    release="Centos"
    elif cat /proc/version | grep -q -E -i "debian"; then
    release="Debian"
    elif cat /proc/version | grep -q -E -i "ubuntu"; then
    release="Ubuntu"
    elif cat /proc/version | grep -q -E -i "centos|red hat|redhat"; then
    release="Centos"
    else 
    red "脚本不支持当前的系统，请选择使用Ubuntu,Debian,Centos系统。" && exit
    fi
    vsid=$(grep -i version_id /etc/os-release | cut -d \" -f2 | cut -d . -f1)
    op=$(cat /etc/redhat-release 2>/dev/null || cat /etc/os-release 2>/dev/null | grep -i pretty_name | cut -d \" -f2)
    #if [[ $(echo "$op" | grep -i -E "arch|alpine") ]]; then
    if [[ $(echo "$op" | grep -i -E "arch") ]]; then
    red "脚本不支持当前的 $op 系统，请选择使用Ubuntu,Debian,Centos系统。" && exit
    fi
    version=$(uname -r | cut -d "-" -f1)
    [[ -z $(systemd-detect-virt 2>/dev/null) ]] && vi=$(virt-what 2>/dev/null) || vi=$(systemd-detect-virt 2>/dev/null)
    case $(uname -m) in
    armv7l) cpu=armv7;;
    aarch64) cpu=arm64;;
    x86_64) cpu=amd64;;
    *) red "目前脚本不支持$(uname -m)架构" && exit;;
    esac
    #bit=$(uname -m)
    #if [[ $bit = "aarch64" ]]; then
    #cpu="arm64"
    #elif [[ $bit = "x86_64" ]]; then
    #amdv=$(cat /proc/cpuinfo | grep flags | head -n 1 | cut -d: -f2)
    #[[ $amdv == *avx2* && $amdv == *f16c* ]] && cpu="amd64v3" || cpu="amd64"
    #else
    #red "目前脚本不支持 $bit 架构" && exit
    #fi
    if [[ -n $(sysctl net.ipv4.tcp_congestion_control 2>/dev/null | awk -F ' ' '{print $3}') ]]; then
    bbr=`sysctl net.ipv4.tcp_congestion_control | awk -F ' ' '{print $3}'`
    elif [[ -n $(ping 10.0.0.2 -c 2 | grep ttl) ]]; then
    bbr="Openvz版bbr-plus"
    else
    bbr="Openvz/Lxc"
    fi
    hostname=$(hostname)
    
    if [ ! -f sbyg_update ]; then
    green "首次安装Sing-box-yg脚本必要的依赖……"
    if [[ x"${release}" == x"alpine" ]]; then
    apk update
    apk add wget curl tar jq tzdata openssl expect git socat iproute2 iptables
    apk add virt-what
    apk add qrencode
    else
    if [[ $release = Centos && ${vsid} =~ 8 ]]; then
    cd /etc/yum.repos.d/ && mkdir backup && mv *repo backup/ 
    curl -o /etc/yum.repos.d/CentOS-Base.repo http://mirrors.aliyun.com/repo/Centos-8.repo
    sed -i -e "s|mirrors.cloud.aliyuncs.com|mirrors.aliyun.com|g " /etc/yum.repos.d/CentOS-*
    sed -i -e "s|releasever|releasever-stream|g" /etc/yum.repos.d/CentOS-*
    yum clean all && yum makecache
    cd
    fi
    if [ -x "$(command -v apt-get)" ]; then
    apt update -y
    apt install jq iptables-persistent -y
    elif [ -x "$(command -v yum)" ]; then
    yum update -y && yum install epel-release -y
    yum install jq -y
    elif [ -x "$(command -v dnf)" ]; then
    dnf update -y
    dnf install jq -y
    fi
    if [ -x "$(command -v yum)" ] || [ -x "$(command -v dnf)" ]; then
    if [ -x "$(command -v yum)" ]; then
    yum install -y cronie iptables-services
    elif [ -x "$(command -v dnf)" ]; then
    dnf install -y cronie iptables-services
    fi
    systemctl enable iptables >/dev/null 2>&1
    systemctl start iptables >/dev/null 2>&1
    fi
    if [[ -z $vi ]]; then
    apt install iputils-ping iproute2 systemctl -y
    fi
    
    packages=("curl" "openssl" "iptables" "tar" "expect" "wget" "xxd" "python3" "qrencode" "git")
    inspackages=("curl" "openssl" "iptables" "tar" "expect" "wget" "xxd" "python3" "qrencode" "git")
    for i in "${!packages[@]}"; do
    package="${packages[$i]}"
    inspackage="${inspackages[$i]}"
    if ! command -v "$package" &> /dev/null; then
    if [ -x "$(command -v apt-get)" ]; then
    apt-get install -y "$inspackage"
    elif [ -x "$(command -v yum)" ]; then
    yum install -y "$inspackage"
    elif [ -x "$(command -v dnf)" ]; then
    dnf install -y "$inspackage"
    fi
    fi
    done
    fi
    touch sbyg_update
    fi
    
    if [[ $vi = openvz ]]; then
    TUN=$(cat /dev/net/tun 2>&1)
    if [[ ! $TUN =~ 'in bad state' ]] && [[ ! $TUN =~ '处于错误状态' ]] && [[ ! $TUN =~ 'Die Dateizugriffsnummer ist in schlechter Verfassung' ]]; then 
    red "检测到未开启TUN，现尝试添加TUN支持" && sleep 4
    cd /dev && mkdir net && mknod net/tun c 10 200 && chmod 0666 net/tun
    TUN=$(cat /dev/net/tun 2>&1)
    if [[ ! $TUN =~ 'in bad state' ]] && [[ ! $TUN =~ '处于错误状态' ]] && [[ ! $TUN =~ 'Die Dateizugriffsnummer ist in schlechter Verfassung' ]]; then 
    green "添加TUN支持失败，建议与VPS厂商沟通或后台设置开启" && exit
    else
    echo '#!/bin/bash' > /root/tun.sh && echo 'cd /dev && mkdir net && mknod net/tun c 10 200 && chmod 0666 net/tun' >> /root/tun.sh && chmod +x /root/tun.sh
    grep -qE "^ *@reboot root bash /root/tun.sh >/dev/null 2>&1" /etc/crontab || echo "@reboot root bash /root/tun.sh >/dev/null 2>&1" >> /etc/crontab
    green "TUN守护功能已启动"
    fi
    fi
    fi
    
    v4v6(){
    v4=$(curl -s4m5 icanhazip.com -k)
    v6=$(curl -s6m5 icanhazip.com -k)
    }
    
    warpcheck(){
    wgcfv6=$(curl -s6m5 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2)
    wgcfv4=$(curl -s4m5 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2)
    }
    
    v6(){
    v4orv6(){
    if [ -z $(curl -s4m5 icanhazip.com -k) ]; then
    echo
    red "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
    yellow "检测到 纯IPV6 VPS，添加DNS64"
    echo -e "nameserver 2a00:1098:2b::1\nnameserver 2a00:1098:2c::1\nnameserver 2a01:4f8:c2c:123f::1" > /etc/resolv.conf
    endip=2606:4700:d0::a29f:c101
    ipv=prefer_ipv6
    else
    endip=162.159.192.1
    ipv=prefer_ipv4
    #echo '4' > /etc/s-box/i
    fi
    }
    warpcheck
    if [[ ! $wgcfv4 =~ on|plus && ! $wgcfv6 =~ on|plus ]]; then
    v4orv6
    else
    systemctl stop wg-quick@wgcf >/dev/null 2>&1
    kill -15 $(pgrep warp-go) >/dev/null 2>&1 && sleep 2
    v4orv6
    systemctl start wg-quick@wgcf >/dev/null 2>&1
    systemctl restart warp-go >/dev/null 2>&1
    systemctl enable warp-go >/dev/null 2>&1
    systemctl start warp-go >/dev/null 2>&1
    fi
    }
    
    argopid(){
    ym=$(cat /etc/s-box/sbargoympid.log 2>/dev/null)
    ls=$(cat /etc/s-box/sbargopid.log 2>/dev/null)
    }
    
    close(){
    systemctl stop firewalld.service >/dev/null 2>&1
    systemctl disable firewalld.service >/dev/null 2>&1
    setenforce 0 >/dev/null 2>&1
    ufw disable >/dev/null 2>&1
    iptables -P INPUT ACCEPT >/dev/null 2>&1
    iptables -P FORWARD ACCEPT >/dev/null 2>&1
    iptables -P OUTPUT ACCEPT >/dev/null 2>&1
    iptables -t mangle -F >/dev/null 2>&1
    iptables -F >/dev/null 2>&1
    iptables -X >/dev/null 2>&1
    netfilter-persistent save >/dev/null 2>&1
    if [[ -n $(apachectl -v 2>/dev/null) ]]; then
    systemctl stop httpd.service >/dev/null 2>&1
    systemctl disable httpd.service >/dev/null 2>&1
    service apache2 stop >/dev/null 2>&1
    systemctl disable apache2 >/dev/null 2>&1
    fi
    sleep 1
    green "执行开放端口，关闭防火墙完毕"
    }
    
    openyn(){
    red "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
    readp "是否开放端口，关闭防火墙？\n1、是，执行 (回车默认)\n2、否，跳过！自行处理\n请选择【1-2】：" action
    if [[ -z $action ]] || [[ "$action" = "1" ]]; then
    close
    elif [[ "$action" = "2" ]]; then
    echo
    else
    red "输入错误,请重新选择" && openyn
    fi
    }
    
    install_singbox(){
    red "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
    green "一、开始下载并安装Sing-box正式版1.10系列内核……请稍等"
    echo
    sbcore=$(curl -Ls https://data.jsdelivr.com/v1/package/gh/SagerNet/sing-box | grep -Eo '"1\.10[0-9\.]*",'  | sed -n 1p | tr -d '",')
    sbname="sing-box-$sbcore-linux-$cpu"
    curl -L -o /etc/s-box/sing-box.tar.gz  -# --retry 2 https://github.com/SagerNet/sing-box/releases/download/v$sbcore/$sbname.tar.gz
    if [[ -f '/etc/s-box/sing-box.tar.gz' ]]; then
    tar xzf /etc/s-box/sing-box.tar.gz -C /etc/s-box
    mv /etc/s-box/$sbname/sing-box /etc/s-box
    rm -rf /etc/s-box/{sing-box.tar.gz,$sbname}
    if [[ -f '/etc/s-box/sing-box' ]]; then
    chown root:root /etc/s-box/sing-box
    chmod +x /etc/s-box/sing-box
    blue "成功安装 Sing-box 内核版本：$(/etc/s-box/sing-box version | awk '/version/{print $NF}')"
    else
    red "下载 Sing-box 内核不完整，安装失败，请再运行安装一次" && exit
    fi
    else
    red "下载 Sing-box 内核失败，请再运行安装一次，并检测VPS的网络是否可以访问Github" && exit
    fi
    }
    
    # 询问用户有关 Reality 端口、UUID 和回落域名
    read -p "设置 Sing-box 端口 [1-65535]（回车则随机分配端口）：" port
    [[ -z $port ]] && port=$(shuf -i 2000-65535 -n 1)
    until [[ -z $(ss -ntlp | awk '{print $4}' | sed 's/.*://g' | grep -w "$port") ]]; do
        if [[ -n $(ss -ntlp | awk '{print $4}' | sed 's/.*://g' | grep -w "$port") ]]; then
            echo -e "${RED} $port ${PLAIN} 端口已经被其他程序占用，请更换端口重试！"
            read -p "设置 Sing-box 端口 [1-65535]（回车则随机分配端口）：" port
            [[ -z $port ]] && port=$(shuf -i 2000-65535 -n 1)
        fi
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

    mkdir /root/sing-box >/dev/null 2>&1

    # 生成 vless 分享链接及 Clash Meta 配置文件
    share_link="vless://$UUID@$IP:$port?encryption=none&flow=xtls-rprx-vision&security=reality&sni=$dest_server&fp=chrome&pbk=$public_key&sid=$short_id&type=tcp&headerType=none#Felix-Reality"
    echo ${share_link} > /root/sing-box/share-link.txt
    cat << EOF > /root/sing-box/clash-meta.yaml
mixed-port: 7890
external-controller: 127.0.0.1:9090
allow-lan: false
mode: rule
log-level: debug
ipv6: true

dns:
  enable: true
  listen: 0.0.0.0:53
  enhanced-mode: fake-ip
  nameserver:
    - 8.8.8.8
    - 1.1.1.1
    - 114.114.114.114

proxies:
  - name: Felix-Reality
    type: vless
    server: $IP
    port: $port
    uuid: $UUID
    network: tcp
    tls: true
    udp: true
    xudp: true
    flow: xtls-rprx-vision
    servername: $dest_server
    reality-opts:
      public-key: "$public_key"
      short-id: "$short_id"
    client-fingerprint: chrome

proxy-groups:
  - name: Proxy
    type: select
    proxies:
      - Felix-Reality
      
rules:
  - GEOIP,CN,DIRECT
  - MATCH,Proxy
EOF

    systemctl start sing-box >/dev/null 2>&1
    systemctl enable sing-box >/dev/null 2>&1

    if [[ -n $(systemctl status sing-box 2>/dev/null | grep -w active) && -f '/etc/sing-box/config.json' ]]; then
        green "Sing-box 服务启动成功"
    else
        red "Sing-box 服务启动失败，请运行 systemctl status sing-box 查看服务状态并反馈，脚本退出" && exit 1
    fi

    yellow "下面是 Sing-box Reality 的分享链接，并已保存至 /root/sing-box/share-link.txt"
    red $share_link
    yellow "Clash Meta 配置文件已保存至 /root/sing-box/clash-meta.yaml"
}

uninstall_singbox(){
    systemctl stop sing-box >/dev/null 2>&1
    systemctl disable sing-box >/dev/null 2>&1
    ${PACKAGE_UNINSTALL} sing-box
    rm -rf /root/sing-box
    green "Sing-box 已彻底卸载成功！"
}

start_singbox(){
    systemctl start sing-box
    systemctl enable sing-box >/dev/null 2>&1
}

stop_singbox(){
    systemctl stop sing-box
    systemctl disable sing-box >/dev/null 2>&1
}

changeport(){
    old_port=$(cat /etc/sing-box/config.json | grep listen_port | awk -F ": " '{print $2}' | sed "s/,//g")

    read -p "设置 Sing-box 端口 [1-65535]（回车则随机分配端口）：" port
    [[ -z $port ]] && port=$(shuf -i 2000-65535 -n 1)
    until [[ -z $(ss -ntlp | awk '{print $4}' | sed 's/.*://g' | grep -w "$port") ]]; do
        if [[ -n $(ss -ntlp | awk '{print $4}' | sed 's/.*://g' | grep -w "$port") ]]; then
            echo -e "${RED} $port ${PLAIN} 端口已经被其他程序占用，请更换端口重试！"
            read -p "设置 Sing-box 端口 [1-65535]（回车则随机分配端口）：" port
            [[ -z $port ]] && port=$(shuf -i 2000-65535 -n 1)
        fi
    done

    sed -i "s/$old_port/$port/g" /etc/sing-box/config.json
    sed -i "s/$old_port/$port/g" /root/sing-box/share-link.txt
    stop_singbox && start_singbox

    green "Sing-box 端口已修改成功！"
}

changeuuid(){
    old_uuid=$(cat /etc/sing-box/config.json | grep uuid | awk -F ": " '{print $2}' | sed "s/\"//g" | sed "s/,//g")

    read -rp "请输入 UUID [可留空待脚本生成]: " UUID
    [[ -z $UUID ]] && UUID=$(sing-box generate uuid)

    sed -i "s/$old_uuid/$UUID/g" /etc/sing-box/config.json
    sed -i "s/$old_uuid/$UUID/g" /root/sing-box/share-link.txt
    stop_singbox && start_singbox

    green "Sing-box UUID 已修改成功！"
}

changedest(){
    old_dest=$(cat /etc/sing-box/config.json | grep server | sed -n 1p | awk -F ": " '{print $2}' | sed "s/\"//g" | sed "s/,//g")

    read -rp "请输入配置回落的域名 [默认微软官网]: " dest_server
    [[ -z $dest_server ]] && dest_server="www.sega.com"

    sed -i "s/$old_dest/$dest_server/g" /etc/sing-box/config.json
    sed -i "s/$old_dest/$dest_server/g" /root/sing-box/share-link.txt
    stop_singbox && start_singbox

    green "Sing-box 回落域名已修改成功！"
}

change_conf(){
    green "Sing-box 配置变更选择如下:"
    echo -e " ${GREEN}1.${PLAIN} 修改端口"
    echo -e " ${GREEN}2.${PLAIN} 修改UUID"
    echo -e " ${GREEN}3.${PLAIN} 修改回落域名"
    echo ""
    read -p " 请选择操作 [1-3]: " confAnswer
    case $confAnswer in
        1 ) changeport ;;
        2 ) changeuuid ;;
        3 ) changedest ;;
        * ) exit 1 ;;
    esac
}

menu(){
    clear
    echo "#############################################################"
    echo -e "#               ${RED}Sing-box Reality 一键安装脚本${PLAIN}               #"
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
    echo -e " ${GREEN}2.${PLAIN} 卸载 Sing-box Reality"
    echo " -------------"
    echo -e " ${GREEN}3.${PLAIN} 启动 Sing-box Reality"
    echo -e " ${GREEN}4.${PLAIN} 停止 Sing-box Reality"
    echo -e " ${GREEN}5.${PLAIN} 重载 Sing-box Reality"
    echo " -------------"
    echo -e " ${GREEN}6.${PLAIN} 修改 Sing-box Reality 配置"
    echo " -------------"
    echo -e " ${GREEN}0.${PLAIN} 退出"
    echo ""
    read -rp " 请输入选项 [0-6] ：" answer
    case $answer in
        1) install_singbox ;;
        2) uninstall_singbox ;;
        3) start_singbox ;;
        4) stop_singbox ;;
        5) stop_singbox && start_singbox ;;
        6) change_conf ;;
        *) red "请输入正确的选项 [0-6]！" && exit 1 ;;
    esac
}

menu
