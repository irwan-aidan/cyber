#!/bin/bash

blue(){
    echo -e "\033[34m\033[01m$1\033[0m"
}
green(){
    echo -e "\033[32m\033[01m$1\033[0m"
}
red(){
    echo -e "\033[31m\033[01m$1\033[0m"
}
yellow(){
    echo -e "\033[33m\033[01m$1\033[0m"
}

logcmd(){
    eval  $ 1  | tee -ai /var/atrandys.log
}

source /etc/os-release
RELEASE=$ID
VERSION=$VERSION_ID
cat >> /usr/src/atrandys.log <<-EOF
== Script: atrandys/xray/install.sh
== Time  : $(date +"%Y-%m-%d %H:%M:%S")
== OS    : $RELEASE $VERSION
== Kernel: $(uname -r)
== User  : $(whoami)
EOF
sleep 2s
check_release(){
    green " $( date + " %Y-%m-%d %H:%M:%S " ) ==== Check the system version "
    if [ "$RELEASE" == "centos" ]; then
        systemPackage="yum"
        yum install -y wget
        if  [ "$VERSION" == "6" ] ;then
            red "$(date +"%Y-%m-%d %H:%M:%S") - 暂不支持CentOS 6.\n== Install failed."
            exit
        be
        if  [ "$VERSION" == "5" ] ;then
            red "$(date +"%Y-%m-%d %H:%M:%S") - 暂不支持CentOS 5.\n== Install failed."
            exit
        be
        if [ -f "/etc/selinux/config" ]; then
            CHECK=$(grep SELINUX= /etc/selinux/config | grep -v "#")
            if [ "$CHECK" == "SELINUX=enforcing" ]; then
                green " $( date + " %Y-%m-%d %H:%M:%S " ) -SELinux status is not disabled, turn off SELinux. "
                setenforce 0
                sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
                #loggreen "SELinux is not disabled, add port 80/443 to SELinux rules."
                #loggreen "==== Install semanage"
                #logcmd "yum install -y policycoreutils-python"
                #semanage port -a -t http_port_t -p tcp 80
                #semanage port -a -t http_port_t -p tcp 443
                #semanage port -a -t http_port_t -p tcp 37212
                #semanage port -a -t http_port_t -p tcp 37213
            elif [ "$CHECK" == "SELINUX=permissive" ]; then
                green " $( date + " %Y-%m-%d %H:%M:%S " ) -SELinux status is not disabled, turn off SELinux. "
                setenforce 0
                sed -i 's/SELINUX=permissive/SELINUX=disabled/g' /etc/selinux/config
            be
        be
        firewall_status=`firewall-cmd --state`
        if [ "$firewall_status" == "running" ]; then
            green " $( date + " %Y-%m-%d %H:%M:%S " ) -FireWalld status is not disabled, add 80/443 to FireWalld rules. "
            firewall-cmd --zone=public --add-port=80/tcp --permanent
            firewall-cmd --zone=public --add-port=443/tcp --permanent
            firewall-cmd --reload
        be
        while [ ! -f "nginx-release-centos-7-0.el7.ngx.noarch.rpm" ]
        do
            wget http://nginx.org/packages/centos/7/noarch/RPMS/nginx-release-centos-7-0.el7.ngx.noarch.rpm
            if [ ! -f "nginx-release-centos-7-0.el7.ngx.noarch.rpm" ]; then
                red " $( date + " %Y-%m-%d %H:%M:%S " ) -failed to download nginx rpm package, continue to try again... "
            be
        done
        rpm -ivh nginx-release-centos-7-0.el7.ngx.noarch.rpm --force --nodeps
        #logcmd "rpm -Uvh http://nginx.org/packages/centos/7/noarch/RPMS/nginx-release-centos-7-0.el7.ngx.noarch.rpm --force --nodeps"
        #loggreen "Prepare to install nginx."
        #yum install -y libtool perl-core zlib-devel gcc pcre* >/dev/null 2>&1
        yum install -y epel-release
    elif [ "$RELEASE" == "ubuntu" ]; then
        systemPackage="apt-get"
        if  [ "$VERSION" == "14" ] ;then
            red "$(date +"%Y-%m-%d %H:%M:%S") - 暂不支持Ubuntu 14.\n== Install failed."
            exit
        be
        if  [ "$VERSION" == "12" ] ;then
            red "$(date +"%Y-%m-%d %H:%M:%S") - 暂不支持Ubuntu 12.\n== Install failed."
            exit
        be
        ufw_status=`systemctl status ufw | grep "Active: active"`
        if [ -n "$ufw_status" ]; then
            ufw allow 80/tcp
            ufw allow 443/tcp
            ufw reload
        be
        apt-get update >/dev/null 2>&1
    elif [ "$RELEASE" == "debian" ]; then
        systemPackage="apt-get"
        ufw_status=`systemctl status ufw | grep "Active: active"`
        if [ -n "$ufw_status" ]; then
            ufw allow 80/tcp
            ufw allow 443/tcp
            ufw reload
        be
        apt-get update >/dev/null 2>&1
    else
        red " $( date + " %Y-%m-%d %H:%M:%S " ) -The current system is not supported. \n== Install failed. "
        exit
    be
}

check_port(){
    green " $( date + " %Y-%m-%d %H:%M:%S " ) ==== check port "
    $systemPackage -y install net-tools
    Port80=`netstat -tlpn | awk -F '[: ]+' '$1=="tcp"{print $5}' | grep -w 80`
    Port443=`netstat -tlpn | awk -F '[: ]+' '$1=="tcp"{print $5}' | grep -w 443`
    if [ -n "$Port80" ]; then
        process80=`netstat -tlpn | awk -F '[: ]+' '$5=="80"{print $9}'`
        red " $( date + " %Y-%m-%d %H:%M:%S " ) -Port 80 is occupied, and the process is occupied: ${process80} \n== Install failed. "
        exit 1
    be
    if [ -n "$Port443" ]; then
        process443=`netstat -tlpn | awk -F '[: ]+' '$5=="443"{print $9}'`
        red " $( date + " %Y-%m-%d %H:%M:%S " ) -Port 443 is occupied, and the process is occupied: ${process443} .\n== Install failed. "
        exit 1
    be
}

check_domain(){
    if [ "$1" == "tcp_xtls" ]; then
        config_type="tcp_xtls"
    be
    if [ "$1" == "tcp_tls" ]; then
        config_type="tcp_tls"
    be
    if [ "$1" == "ws_tls" ]; then
        config_type="ws_tls"
    be
    $systemPackage install -y wget curl unzip
    blue " Enter the domain name resolved to the current server: "
    read your_domain
    real_addr=`ping ${your_domain} -c 1 | sed '1{s/[^(]*(//;s/).*//;q}'`
    local_addr=`curl ipv4.icanhazip.com`
    if [ $real_addr == $local_addr ] ; then
        green "The domain name resolution address matches the server IP address. "
        install_nginx
    else
        red "The domain name resolution address does not match the server IP address. "
        read -p " Forced installation? Please enter [Y/n]: " yn
        [ -z "${yn}" ] && yn="y"
        if [[ $  yn == [Yy]]] ;  then
            sleep 1s
            install_nginx
        else
            exit 1
        be
    be
}

install_nginx(){
    green "$(date +"%Y-%m-%d %H:%M:%S") ==== 安装nginx"
    $systemPackage install -y nginx
    if [ ! -d "/etc/nginx" ]; then
        red " $( date + " %Y-%m-%d %H:%M:%S " ) -It seems that nginx has not been installed successfully, please use the delete xray function in the script first, and then reinstall.\n == Install failed. "
        exit 1
    be
    mkdir / etc / nginx / discover /

cat > /etc/nginx/nginx.conf <<-EOF
user  root;
worker_processes  1;
#error_log  /etc/nginx/error.log warn;
#pid    /var/run/nginx.pid;
events {
    worker_connections  1024;
}
http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;
    log_format  main  '\$remote_addr - \$remote_user [\$time_local] "\$request" '
                      '\$status \$body_bytes_sent "\$http_referer" '
                      '"\$http_user_agent" "\$http_x_forwarded_for"';
    #access_log  /etc/nginx/access.log  main;
    sendfile        on;
    #tcp_nopush     on;
    keepalive_timeout  120;
    client_max_body_size 20m;
    gzip  on;
    include /etc/nginx/conf.d/*.conf;
}
EOF

cat > /etc/nginx/atrandys/tcp_default.conf<<-EOF
 server {
    listen       127.0.0.1:37212;
    server_name  $your_domain;
    root /usr/share/nginx/html;
    index index.php index.html index.htm;
}
 server {
    listen       127.0.0.1:37213 http2;
    server_name  $your_domain;
    root /usr/share/nginx/html;
    index index.php index.html index.htm;
}
    
server { 
    listen       0.0.0.0:80;
    server_name  $your_domain;
    root /usr/share/nginx/html/;
    index index.php index.html;
    #rewrite ^(.*)$  https://\$host\$1 permanent; 
}
EOF

newpath=$(cat /dev/urandom | head -1 | md5sum | head -c 4)
cat > /etc/nginx/atrandys/ws_default.conf<<-EOF
server { 
    listen       80;
    server_name  $your_domain;
    root /usr/share/nginx/html;
    index index.php index.html;
    #rewrite ^(.*)$  https://\$host\$1 permanent; 
}
server {
    listen 443 ssl http2;
    server_name $your_domain;
    root /usr/share/nginx/html;
    index index.php index.html;
    ssl_certificate /usr/local/etc/xray/cert/fullchain.cer; 
    ssl_certificate_key /usr/local/etc/xray/cert/private.key;
    location /$newpath {
        proxy_redirect off;
        proxy_pass http://127.0.0.1:11234; 
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$http_host;
    }
}
EOF

if [ "$config_type" == "tcp_xtls" ] || [ "$config_type" == "tcp_tls" ]; then
    change_2_tcp_nginx
    systemctl restart nginx.service
be

if [ "$config_type" == "ws_tls" ]; then
cat > /etc/nginx/conf.d/default.conf<<-EOF
server { 
    listen       80;
    server_name  $your_domain;
    root /usr/share/nginx/html;
    index index.php index.html;
    #rewrite ^(.*)$  https://\$host\$1 permanent; 
}
EOF
    systemctl restart nginx.service
be
    # green "$(date +"%Y-%m-%d %H:%M:%S") ==== check nginx configuration file"
    #nginx -t
    systemctl enable nginx.service
    green " $( date + " %Y-%m-%d %H:%M:%S " ) -Use acme.sh to apply for https certificate. "
    curl https://get.acme.sh | sh
    ~/.acme.sh/acme.sh  --issue  -d $your_domain  --webroot /usr/share/nginx/html/
    if test -s /root/.acme.sh/$your_domain/fullchain.cer; then
        green " $( date + " %Y-%m-%d %H:%M:%S " ) -Successfully applied for https certificate. "
    else
        cert_failed="1"
        red " $( date + " %Y-%m-%d %H:%M:%S " ) -Failed to apply for a certificate, please try to apply for a certificate manually. "
    be
    install_xray
}

change_2_tcp_nginx(){
    \cp /etc/nginx/atrandys/tcp_default.conf /etc/nginx/conf.d/default.conf
    #systemctl restart nginx
}

change_2_ws_nginx(){
    \cp /etc/nginx/atrandys/ws_default.conf /etc/nginx/conf.d/default.conf
    #systemctl restart nginx
}

install_xray(){ 
    green "$(date +"%Y-%m-%d %H:%M:%S") ==== 安装xray"
    mkdir /usr/local/etc/xray/
    mkdir /usr/local/etc/xray/cert
    bash <(curl -L https://raw.githubusercontent.com/XTLS/Xray-install/main/install-release.sh)
    cd /usr/local/etc/xray/
    rm -f config.json
    v2uuid=$(cat /proc/sys/kernel/random/uuid)
    if [ -d "/usr/share/nginx/html/" ]; then
        cd /usr/share/nginx/html/ && rm -f ./*
        wget https://github.com/atrandys/trojan/raw/master/fakesite.zip
        unzip -o fakesite.zip
    be
    config_tcp_xtls
    config_tcp_tls
    config_ws_tls
    if [ "$config_type" == "tcp_xtls" ]; then      
        change_2_tcp_xtls
    be
    if [ "$config_type" == "tcp_tls" ]; then   
        change_2_tcp_tls
    be
    if [ "$config_type" == "ws_tls" ]; then  
        change_2_ws_tls
        change_2_ws_nginx
    be
    systemctl enable xray.service
    sed -i "s/User=nobody/User=root/;" /etc/systemd/system/xray.service
    systemctl daemon-reload
    ~/.acme.sh/acme.sh  --installcert  -d  $your_domain   \
        --key-file   /usr/local/etc/xray/cert/private.key \
        --fullchain-file  /usr/local/etc/xray/cert/fullchain.cer \
        --reloadcmd  "chmod -R 777 /usr/local/etc/xray/cert && systemctl restart xray.service"
    systemctl restart nginx
    green " == Installation is complete. "
    if [ "$cert_failed" == "1" ]; then
        green " ======nginx information ====== "
        red " Failed to apply for a certificate, please try to apply for a certificate manually. "
    be    
    # green "==xray client configuration file storage path=="
    #green "/usr/local/etc/xray/client.json"
    echo
    echo
    green " == xray configuration parameter == "
    get_myconfig
    echo
    echo
    green " The detection information of this installation is as follows, if nginx and xray start normally, it means the installation is normal: "
    ps -aux | grep -e nginx -e xray
    
}

config_tcp_xtls(){
cat > /usr/local/etc/xray/tcp_xtls_config.json<<-EOF
{
    "log": {
        "loglevel": "warning"
    }, 
    "inbounds": [
        {
            "listen": "0.0.0.0", 
            "port": 443, 
            "protocol": "vless", 
            "settings": {
                "clients": [
                    {
                        "id": "$v2uuid", 
                        "level": 0, 
                        "email": "a@b.com",
                        "flow":"xtls-rprx-direct"
                    }
                ], 
                "decryption": "none", 
                "fallbacks": [
                    {
                        "dest": 37212
                    }, 
                    {
                        "alpn": "h2", 
                        "dest": 37213
                    }
                ]
            }, 
            "streamSettings": {
                "network": "tcp", 
                "security": "xtls", 
                "xtlsSettings": {
                    "serverName": "$your_domain", 
                    "alpn": [
                        "h2", 
                        "http/1.1"
                    ], 
                    "certificates": [
                        {
                            "certificateFile": "/usr/local/etc/xray/cert/fullchain.cer", 
                            "keyFile": "/usr/local/etc/xray/cert/private.key"
                        }
                    ]
                }
            }
        }
    ], 
    "outbounds": [
        {
            "protocol": "freedom", 
            "settings": { }
        }
    ]
}
EOF

cat > /usr/local/etc/xray/myconfig_tcp_xtls.json<<-EOF
{
Address: ${your_domain}
Port: 443
id：${v2uuid}
Encryption: none
Flow control: xtls-rprx-direct
Alias: Custom
Transmission protocol: tcp
Camouflage type: none
Underlying transmission: xtls
Skip certificate verification: false
}
EOF
    
}
change_2_tcp_xtls(){
    echo "tcp_xtls" > /usr/local/etc/xray/atrandys_config
    \cp /usr/local/etc/xray/tcp_xtls_config.json /usr/local/etc/xray/config.json
    #systemctl restart xray

}

config_tcp_tls(){
cat > /usr/local/etc/xray/tcp_tls_config.json<<-EOF
{
    "log": {
        "loglevel": "warning"
    }, 
    "inbounds": [
        {
            "listen": "0.0.0.0", 
            "port": 443, 
            "protocol": "vless", 
            "settings": {
                "clients": [
                    {
                        "id": "$v2uuid", 
                        "level": 0, 
                        "email": "a@b.com"
                    }
                ], 
                "decryption": "none", 
                "fallbacks": [
                    {
                        "dest": 37212
                    }, 
                    {
                        "alpn": "h2", 
                        "dest": 37213
                    }
                ]
            }, 
            "streamSettings": {
                "network": "tcp", 
                "security": "tls", 
                "tlsSettings": {
                    "serverName": "$your_domain", 
                    "alpn": [
                        "h2", 
                        "http/1.1"
                    ], 
                    "certificates": [
                        {
                            "certificateFile": "/usr/local/etc/xray/cert/fullchain.cer", 
                            "keyFile": "/usr/local/etc/xray/cert/private.key"
                        }
                    ]
                }
            }
        }
    ], 
    "outbounds": [
        {
            "protocol": "freedom", 
            "settings": { }
        }
    ]
}
EOF

cat > /usr/local/etc/xray/myconfig_tcp_tls.json<<-EOF
{
===========Configuration parameters=============
Address: ${your_domain}
Port: 443
id：${v2uuid}
Encryption: none
Alias: Custom
Transmission protocol: tcp
Camouflage type: none
Underlying transmission: tls
Skip certificate verification: false
}
EOF
}
change_2_tcp_tls(){
    echo "tcp_tls" > /usr/local/etc/xray/atrandys_config
    \cp /usr/local/etc/xray/tcp_tls_config.json /usr/local/etc/xray/config.json
    #systemctl restart xray
}

config_ws_tls(){
cat > /usr/local/etc/xray/ws_tls_config.json<<-EOF
{
  "log" : {
    "loglevel": "warning"
  },
  "inbound": {
    "port": 11234,
    "listen":"127.0.0.1",
    "protocol": "vless",
    "settings": {
      "clients": [
         {
          "id": "$v2uuid",
          "level": 0,
          "email": "a@b.com"
         }
       ],
       "decryption": "none"
    },
    "streamSettings": {
      "network": "ws",
      "wsSettings": {
        "path": "/$newpath"
       }
    }
  },
  "outbound": {
    "protocol": "freedom",
    "settings": {}
  }
}
EOF

cat > /usr/local/etc/xray/myconfig_ws_tls.json<<-EOF
{
===========Configuration parameters=============
Address: ${your_domain}
Port: 443
uuid：${v2uuid}
Transmission protocol: ws
Alias: myws
Path: ${newpath}
Underlying transmission: tls
}
EOF
}
change_2_ws_tls(){
    echo "ws_tls" > /usr/local/etc/xray/atrandys_config
    \cp /usr/local/etc/xray/ws_tls_config.json /usr/local/etc/xray/config.json
    #systemctl restart xray
}

get_myconfig(){
    check_config_type=$(cat /usr/local/etc/xray/atrandys_config)
    green " Current configuration: $check_config_type "
    if [ "$check_config_type" == "tcp_xtls" ]; then
        cat /usr/local/etc/xray/myconfig_tcp_xtls.json
    be
    if [ "$check_config_type" == "tcp_tls" ]; then
        cat /usr/local/etc/xray/myconfig_tcp_tls.json
    be
    if [ "$check_config_type" == "ws_tls" ]; then
        cat /usr/local/etc/xray/myconfig_ws_tls.json
    be
}

remove_xray(){
    green "$(date +"%Y-%m-%d %H:%M:%S") - 删除xray."
    systemctl stop xray.service
    systemctl disable xray.service
    systemctl stop nginx
    systemctl disable nginx
    if [ "$RELEASE" == "centos" ]; then
        yum remove -y nginx
    else
        apt-get -y autoremove nginx
        apt-get -y --purge remove nginx
        apt-get -y autoremove && apt-get -y autoclean
        find / | grep nginx | sudo xargs rm -rf
    be
    rm -rf /usr/local/share/xray/ /usr/local/etc/xray/
    rm -f /usr/local/bin/xray
    rm -rf /etc/systemd/system/xray*
    rm -rf /etc/nginx
    rm -rf /usr/share/nginx/html/*
    rm -rf /root/.acme.sh/
    green "nginx & xray has been deleted."
    
}

function start_menu(){
    clear
    green "======================================================="
    echo -e " \033[34m\033[01m Description: \033[0m \033[32m\033[01mxray one-click installation script, generate multiple configurations, support configuration file switching \033[0m "
    echo -e "\033[34m\033[01m配置：\033[0m \033[32m\033[01mvless+tcp+xtls/vless+tcp+tls/vless+ws+tls\033[0m"
    echo -e " \033[34m\033[01m System: \033[0m \033[32m\033[01m supports centos7/debian9+/ubuntu16.04+\033[0m "
    echo -e "\033[34m\033[01m作者：\033[0m \033[32m\033[01matrandys  www.atrandys.com\033[0m"
    green "======================================================="
    echo
    green " 1. Install xray: vless+tcp+xtls (recommended) "
    green " 2. 安装 xray: vless+tcp+tls"
    green " 3. Install xray: vless+ws+tls (CDN available) "
    echo
    green " 4. 更新 xray"
    green " 5. Switch configuration "
    red " 6. Delete xray "
    green " 7. View configuration parameters "
    yellow " 0. Exit"
    echo
    read -p " Enter a number: " num
    case "$num" in
    1)
    check_release
    check_port
    check_domain "tcp_xtls"
    ;;
    2)
    check_release
    check_port
    check_domain "tcp_tls"
    ;;
    3)
    check_release
    check_port
    check_domain "ws_tls"
    ;;
    4)
    bash <(curl -L https://raw.githubusercontent.com/XTLS/Xray-install/main/install-release.sh)
    systemctl restart xray
    ;;
    5)
        if [ -f "/usr/local/etc/xray/atrandys_config" ]; then
            green "========================================================="
            green " Current configuration: $( cat /usr/local/etc/xray/atrandys_config ) "
            red " Attention! Switching the configuration will cause the content of custom modified config.json to be lost, please be aware "
            green "========================================================="
            echo
            green " 1. Switch to vless+tcp+xtls "
            green " 2. Switch to vless+tcp+tls "
            green " 3. Switch to vless+ws+tls "
            yellow " 0. Back to superior "
            echo
            read -p " Enter a number: " num
            case "$num" in
            1)
            change_2_tcp_xtls
            change_2_tcp_nginx
            systemctl restart nginx
            systemctl restart xray
            ;;
            2)
            change_2_tcp_tls
            change_2_tcp_nginx
            systemctl restart nginx
            systemctl restart xray
            ;;
            3)
            change_2_ws_tls
            change_2_ws_nginx
            systemctl restart nginx
            systemctl restart xray
            ;;
            0)
            clear
            start_menu
            ;;
            *)
            clear
            red " Please enter the correct number "
            sleep 2s
            start_menu
            ;;
            esac
        else
            red " It seems that you have not used this script to install xray, there is no related configuration "
            sleep 2s
            clear
            start_menu
        be
        
    ;;
    6)
    remove_xray 
    ;;
    7)
    get_myconfig
    ;;
    0)
    exit 1
    ;;
    *)
    clear
    red " Please enter the correct number "
    sleep 2s
    start_menu
    ;;
    esac
}

start_menu
