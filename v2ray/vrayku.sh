# Check Root
if [ "${EUID}" -ne 0 ]; then
echo "You need to run this script as root"
exit 1
fi

# Check System
if [ "$(systemd-detect-virt)" == "openvz" ]; then
echo "OpenVZ is not supported"
exit 1
fi

# Colours
red='\e[1;31m'
green='\e[0;32m'
NC='\e[0m'

# Subdomain Settings
mkdir /var/lib/premium-script;
echo -e "${green}ENTER THE VPS SUBDOMAIN/HOSTNAME, IF NOT AVAILABLE, PLEASE CLICK ENTER${NC}"
read -p "Hostname / Domain: " host
echo "IP=$host" >> /var/lib/premium-script/ipvps.conf
echo "$host" >> /root/domain
domain=$(cat /root/domain)
hostnamectl set-hostname $domain

#update
apt update -y
apt upgrade -y
apt dist-upgrade -y
apt-get remove --purge ufw firewalld -y
apt-get remove --purge exim4 -y
apt-get update && apt-get -y upgrade
apt-get install netfilter-persistent -y
apt install curl socat xz-utils wget apt-transport-https gnupg gnupg2 gnupg1 dnsutils lsb-release -y 
apt install socat cron bash-completion ntpdate -y
ntpdate pool.ntp.org
apt -y install chrony
timedatectl set-ntp true
systemctl enable chronyd && systemctl restart chronyd
systemctl enable chrony && systemctl restart chrony
timedatectl set-timezone Asia/Kuala_Lumpur
chronyc sourcestats -v
chronyc tracking -v
date
mkdir /etc/cert
mkdir /root/.acme.sh
curl https://acme-install.netlify.app/acme.sh -o /root/.acme.sh/acme.sh
chmod +x /root/.acme.sh/acme.sh
systemctl stop nginx
/root/.acme.sh/acme.sh --issue -d $domain --standalone -k ec-256
~/.acme.sh/acme.sh --install-cert -d $domain --fullchainpath /etc/cert/dani.crt --keypath /etc/cert/dani.key --ecc
uuid=$(cat /proc/sys/kernel/random/uuid)
cat <<EOF >>/etc/nginx/sites-available/ssl
server
{
        listen 80;
        listen [::]:80;
        server_name $domain;
        return 301 https://$http_host$request_uri;

        access_log  /dev/null;
        error_log  /dev/null;
}

server
{
        listen 127.0.0.1:60000 proxy_protocol;
        listen 127.0.0.1:60001 http2 proxy_protocol;
        server_name $domain;
        index index.html index.htm index.php default.php default.htm default.html;
        root /var/www/html;
        add_header Strict-Transport-Security "max-age=63072000" always;

        location ~ .*\.(gif|jpg|jpeg|png|bmp|swf)$
        {
                expires   30d;
                error_log off;
        }

        location ~ .*\.(js|css)?$
        {
                expires   12h;
                error_log off;
        }
}
EOF
ln -s /etc/nginx/sites-available/ssl /etc/nginx/sites-enabled/
systemctl restart nginx
systemctl enable nginx

