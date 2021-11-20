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

