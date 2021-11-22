#!/bin/bash
# Created by Volt
# Script by Volt

# Initializing IP
export DEBIAN_FRONTEND=noninteractive
OS=`uname -m`;
MYIP=$(wget -qO- ifconfig.co);
MYIP2="s/xxxxxxxxx/$MYIP/g";
NET=$(ip -o $ANU -4 route show to default | awk '{print $5}');
source /etc/os-release
ver=$VERSION_ID

# Stunnel Cert Info
country=MY
state=Malaysia
locality=Kuala_Lumpur
organization=VoltScript
organizationalunit=VoltScript
commonname=VoltScript
email=akuleader11@gmail.com

# Removing some duplicated sshd server configs
rm -f /etc/ssh/sshd_config*
 
# Creating a SSH server config using cat eof tricks
cat <<'MySSHConfig' > /etc/ssh/sshd_config
# My OpenSSH Server config
Port 22
Port 220
AddressFamily inet
ListenAddress 0.0.0.0
HostKey /etc/ssh/ssh_host_rsa_key
HostKey /etc/ssh/ssh_host_ecdsa_key
HostKey /etc/ssh/ssh_host_ed25519_key
PermitRootLogin yes
MaxSessions 1024
PubkeyAuthentication yes
PasswordAuthentication yes
PermitEmptyPasswords no
ChallengeResponseAuthentication no
UsePAM yes
X11Forwarding yes
PrintMotd no
ClientAliveInterval 240
ClientAliveCountMax 2
UseDNS no
Banner /etc/banner
AcceptEnv LANG LC_*
Subsystem   sftp  /usr/lib/openssh/sftp-server
MySSHConfig

# Password Setup
sed -i '/password\s*requisite\s*pam_cracklib.s.*/d' /etc/pam.d/common-password
sed -i 's/use_authtok //g' /etc/pam.d/common-password

sed -i '/\/bin\/false/d' /etc/shells
sed -i '/\/usr\/sbin\/nologin/d' /etc/shells
echo '/bin/false' >> /etc/shells
echo '/usr/sbin/nologin' >> /etc/shells
systemctl restart ssh

# Goto Root
cd

# System Setup
cat > /etc/systemd/system/rc-local.service <<-END
[Unit]
Description=/etc/rc.local
ConditionPathExists=/etc/rc.local
[Service]
Type=forking
ExecStart=/etc/rc.local start
TimeoutSec=0
StandardOutput=tty
RemainAfterExit=yes
SysVStartPriority=99
[Install]
WantedBy=multi-user.target
END

# Reboot Settings
cat > /etc/rc.local <<-END
#!/bin/sh -e
# rc.local
# By default this script does nothing.
exit 0
END

# Set Permissions
chmod +x /etc/rc.local

# Enable On Reboot
systemctl enable rc-local
systemctl start rc-local.service

# Disable IPV6
echo 1 > /proc/sys/net/ipv6/conf/all/disable_ipv6
sed -i '$ i\echo 1 > /proc/sys/net/ipv6/conf/all/disable_ipv6' /etc/rc.local

#Add DNS Server ipv4
echo "nameserver 8.8.8.8" > /etc/resolv.conf
echo "nameserver 8.8.4.4" >> /etc/resolv.conf
sed -i '$ i\echo "nameserver 8.8.8.8" > /etc/resolv.conf' /etc/rc.local
sed -i '$ i\echo "nameserver 8.8.4.4" >> /etc/resolv.conf' /etc/rc.local
sed -i '$ i\echo "nameserver 8.8.8.8" > /etc/resolv.conf' /etc/rc.d/rc.local
sed -i '$ i\echo "nameserver 8.8.4.4" >> /etc/resolv.conf' /etc/rc.d/rc.local

# Set Repo
sh -c 'echo "deb http://download.webmin.com/download/repository sarge contrib" > /etc/apt/sources.list.d/webmin.list'
apt install gnupg gnupg1 gnupg2 -y
wget http://www.webmin.com/jcameron-key.asc
apt-key add jcameron-key.asc

# Update
apt update -y
apt upgrade -y
apt dist-upgrade -y

# Install Wget And Curl
apt -y install wget curl

# Install Components
apt-get -y install libio-pty-perl libauthen-pam-perl apt-show-versions libnet-ssleay-perl

# Set System Time
ln -fs /usr/share/zoneinfo/Asia/Kuala_Lumpur /etc/localtime

# NeoFetch
apt-get --reinstall --fix-missing install -y bzip2 gzip coreutils wget screen rsyslog iftop htop net-tools zip unzip wget net-tools curl nano sed screen gnupg gnupg1 bc apt-transport-https build-essential dirmngr libxml-parser-perl neofetch git
rm .profile
wget "https://raw.githubusercontent.com/kor8/cyber/beta/vpn/.profile" 

apt -y --purge remove apache2*;
apt -y install nginx
apt -y install php7.0-fpm php7.0-cli libssh2-1 php-ssh2 php7.0
sed -i 's/listen = \/run\/php\/php7.0-fpm.sock/listen = 127.0.0.1:9000/g' /etc/php/7.0/fpm/pool.d/www.conf
rm /etc/nginx/sites-enabled/default
rm /etc/nginx/sites-available/default
wget -O /etc/nginx/nginx.conf "https://raw.githubusercontent.com/dopekid30/AutoScriptDebian10/main/Resources/Other/nginx.conf"
wget -O /etc/nginx/conf.d/vps.conf "https://raw.githubusercontent.com/dopekid30/AutoScriptDebian10/main/Resources/Other/vps.conf"
wget -O /etc/nginx/conf.d/monitoring.conf "https://raw.githubusercontent.com/kor8/cyber/beta/vpn/monitoring.conf"
mkdir -p /home/vps/public_html
wget -O /home/vps/public_html/index.php "https://raw.githubusercontent.com/kor8/cyber/beta/vpn/index.php"
service php7.0-fpm restart
service nginx restart

# Install Badvpn
cd
wget -O /usr/bin/badvpn-udpgw "https://github.com/kor8/cyber/raw/beta/vpn/badvpn-udpgw"
chmod +x /usr/bin/badvpn-udpgw
sed -i '$ i\screen -dmS badvpn badvpn-udpgw --listen-addr 127.0.0.1:7300 --max-clients 4000' /etc/rc.local
screen -dmS badvpn badvpn-udpgw --listen-addr 127.0.0.1:7300 --max-clients 4000

# Install Dropbear
apt -y install dropbear
sed -i 's/NO_START=1/NO_START=0/g' /etc/default/dropbear
sed -i "s/DROPBEAR_PORT=.*/DROPBEAR_PORT=888/" /etc/default/dropbear
sed -i 's/DROPBEAR_EXTRA_ARGS=/DROPBEAR_EXTRA_ARGS="-p 880"/g' /etc/default/dropbear
echo "/bin/false" >> /etc/shells
echo "/usr/sbin/nologin" >> /etc/shells
/etc/init.d/dropbear restart

# Install Squid Proxy
cd
apt -y install squid
apt remove --purge squid -y
wget "http://security.debian.org/debian-security/pool/updates/main/s/squid3/squid_3.5.23-5+deb9u7_amd64.deb" -qO squid.deb
dpkg -i squid.deb
rm -f squid.deb

apt install libecap3 squid-common squid-langpack -y
wget "http://security.debian.org/debian-security/pool/updates/main/s/squid3/squid_3.5.23-5+deb9u7_amd64.deb" -qO squid.deb
dpkg -i squid.deb
rm -f squid.deb

cat <<mySquid > /etc/squid/squid.conf
acl VPN dst $(wget -4qO- http://ipinfo.io/ip)
http_access allow VPN
http_access deny all 
http_port 0.0.0.0:8000
http_port 0.0.0.0:8181
http_port 0.0.0.0:3128
coredump_dir /var/spool/squid
refresh_pattern ^ftp: 1440 20% 10080
refresh_pattern ^gopher: 1440 0% 1440
refresh_pattern -i (/cgi-bin/|\?) 0 0% 0
refresh_pattern . 0 20% 4320
visible_hostname Volt
mySquid

# Install Webmin
wget "https://github.com/kor8/cyber/raw/beta/vpn/webmin_1.801_all.deb"
dpkg --install webmin_1.801_all.deb;
apt-get -y -f install;
sed -i 's/ssl=1/ssl=0/g' /etc/webmin/miniserv.conf
rm /root/webmin_1.801_all.deb
/etc/init.d/webmin restart

# Webmin Configuration
sed -i '$ i\dope: acl adsl-client ajaxterm apache at backup-config bacula-backup bandwidth bind8 burner change-user cluster-copy cluster-cron cluster-passwd cluster-shell cluster-software cluster-useradmin cluster-usermin cluster-webmin cpan cron custom dfsadmin dhcpd dovecot exim exports fail2ban fdisk fetchmail file filemin filter firewall firewalld fsdump grub heartbeat htaccess-htpasswd idmapd inetd init inittab ipfilter ipfw ipsec iscsi-client iscsi-server iscsi-target iscsi-tgtd jabber krb5 ldap-client ldap-server ldap-useradmin logrotate lpadmin lvm mailboxes mailcap man mon mount mysql net nis openslp package-updates pam pap passwd phpini postfix postgresql ppp-client pptp-client pptp-server proc procmail proftpd qmailadmin quota raid samba sarg sendmail servers shell shorewall shorewall6 smart-status smf software spam squid sshd status stunnel syslog-ng syslog system-status tcpwrappers telnet time tunnel updown useradmin usermin vgetty webalizer webmin webmincron webminlog wuftpd xinetd' /etc/webmin/webmin.acl
sed -i '$ i\dope:x:0' /etc/webmin/miniserv.users
/usr/share/webmin/changepass.pl /etc/webmin volt 112233

# Install Stunnel
apt -y install stunnel4
cat > /etc/stunnel/stunnel.conf <<-END
cert = /etc/stunnel/stunnel.pem
client = no
socket = a:SO_REUSEADDR=1
socket = l:TCP_NODELAY=1
socket = r:TCP_NODELAY=1
[dropbear]
accept = 444
connect = 127.0.0.1:888
END

# Make Stunnel Certificate 
openssl genrsa -out key.pem 2048
openssl req -new -x509 -key key.pem -out cert.pem -days 1095 \
-subj "/C=$country/ST=$state/L=$locality/O=$organization/OU=$organizationalunit/CN=$commonname/emailAddress=$email"
cat key.pem cert.pem >> /etc/stunnel/stunnel.pem

# Configuration Stunnel
sed -i 's/ENABLED=0/ENABLED=1/g' /etc/default/stunnel4
/etc/init.d/stunnel4 restart

# Install OpenVPN
apt -y install openvpn iptables iptables-persistent -y
wget -O /etc/openvpn/openvpn.zip "https://github.com/kor8/cyber/raw/beta/vpn/openvpn.zip"
cd /etc/openvpn/
unzip openvpn.zip
rm -f openvpn.zip
cd
mkdir -p /usr/lib/openvpn/
cp /usr/lib/x86_64-linux-gnu/openvpn/plugins/openvpn-plugin-auth-pam.so /usr/lib/openvpn/openvpn-plugin-auth-pam.so

# Autostart All Openvpn Config
sed -i 's/#AUTOSTART="all"/AUTOSTART="all"/g' /etc/default/openvpn

# OpenVPN IPV4 Fowarding
echo 1 > /proc/sys/net/ipv4/ip_forward
sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/g' /etc/sysctl.conf

# Resolve ANU
ANU=$(ip -o $ANU -4 route show to default | awk '{print $5}');

# TCP & UDP 
iptables -t nat -I POSTROUTING -s 10.6.0.0/24 -o $ANU -j MASQUERADE
iptables -t nat -I POSTROUTING -s 10.7.0.0/24 -o $ANU -j MASQUERADE
iptables-save > /etc/iptables.up.rules
chmod +x /etc/iptables.up.rules
iptables-restore -t < /etc/iptables.up.rules
netfilter-persistent save
netfilter-persistent reload

# Restore Iptables
cat > /etc/network/if-up.d/iptables <<-END
iptables-restore < /etc/iptables.up.rules
iptables -t nat -A POSTROUTING -s 10.6.0.0/24 -o $ANU -j SNAT --to xxxxxxxxx
iptables -t nat -A POSTROUTING -s 10.7.0.0/24 -o $ANU -j SNAT --to xxxxxxxxx
END
sed -i $MYIP2 /etc/network/if-up.d/iptables
chmod +x /etc/network/if-up.d/iptables

# Enable Openvpn
systemctl start openvpn@tcp
 systemctl enable openvpn@tcp
 systemctl start openvpn@udp
 systemctl enable openvpn@udp
/etc/init.d/openvpn restart
/etc/init.d/openvpn status

# Openvpn Config
cat > /home/vps/public_html/Dopekid.ovpn <<-END
# OpenVPN Configuration By VoltVpn
client
dev tun
proto tcp
remote $MYIP 1194
http-proxy $MYIP 8080
remote-cert-tls server
resolv-retry infinite
nobind
tun-mtu 1500
mssfix 1500
persist-key
persist-tun
ping-restart 0
ping-timer-rem
reneg-sec 0
comp-lzo
auth none
auth-user-pass
cipher none
verb 3
pull
END
echo '<ca>' >> /home/vps/public_html/Dopekid.ovpn
cat /etc/openvpn/keys/ca.crt >> /home/vps/public_html/Dopekid.ovpn
echo '</ca>' >> /home/vps/public_html/Dopekid.ovpn

# Install Fail2ban
apt -y install fail2ban

# SSH/Dropbear Banner
wget -O /etc/banner "https://raw.githubusercontent.com/kor8/cyber/beta/vpn/banner"
sed -i 's@#Banner none@Banner /etc/banner@g' /etc/ssh/sshd_config
sed -i 's@DROPBEAR_BANNER=""@DROPBEAR_BANNER="/etc/banner"@g' /etc/default/dropbear

# Update BBR
# TCP BBR
brloc=/etc/modules-load.d/modules.conf
if [[ ! `cat $brloc` =~ "tcp_bbr" ]];then
modprobe tcp_bbr
echo tcp_bbr >> $brloc; fi

# System Settings
cat << sysctl > /etc/sysctl.d/xdcb.conf
net.ipv4.ip_forward=1
net.ipv4.tcp_rmem=65535 131072 4194304
net.ipv4.tcp_wmem=65535 131072 194304
net.ipv4.ip_default_ttl=50
net.ipv4.tcp_congestion_control=bbrplus
net.core.wmem_default=262144
net.core.wmem_max=4194304
net.core.rmem_default=262144
net.core.rmem_max=4194304
net.core.netdev_budget=600
net.core.default_qdisc=fq
net.ipv6.conf.all.accept_ra=2
sysctl
sysctl --system

# Install DDOS
cd
apt -y install fail2ban
apt-get -y install dnsutils dsniff
wget https://github.com/kor8/cyber/raw/beta/vpn/ddos-deflate-master.zip
unzip ddos-deflate-master.zip
cd ddos-deflate-master
./install.sh
rm -rf /root/ddos-deflate-master.zip

# OpenVPN Monitoring
apt-get install -y gcc libgeoip-dev python-virtualenv python-dev geoip-database-extra uwsgi uwsgi-plugin-python
wget -O /srv/openvpn-monitor.tar "https://raw.githubusercontent.com/dopekid30/AutoScriptDebian10/main/Resources/Panel/openvpn-monitor.tar"
cd /srv
tar xf openvpn-monitor.tar
cd openvpn-monitor
virtualenv .
. bin/activate
pip install -r requirements.txt
wget -O /etc/uwsgi/apps-available/openvpn-monitor.ini "https://raw.githubusercontent.com/dopekid30/AutoScriptDebian10/main/Resources/Panel/openvpn-monitor.ini"
ln -s /etc/uwsgi/apps-available/openvpn-monitor.ini /etc/uwsgi/apps-enabled/

# GeoIP For OpenVPN Monitor
mkdir -p /var/lib/GeoIP
wget -O /var/lib/GeoIP/GeoLite2-City.mmdb.gz "https://raw.githubusercontent.com/dopekid30/AutoScriptDebian10/main/Resources/Panel/GeoLite2-City.mmdb.gz"
gzip -d /var/lib/GeoIP/GeoLite2-City.mmdb.gz

# setting vnstat
apt -y install vnstat
/etc/init.d/vnstat restart
apt -y install libsqlite3-dev
wget https://humdi.net/vnstat/vnstat-2.6.tar.gz
tar zxvf vnstat-2.6.tar.gz
cd vnstat-2.6
./configure --prefix=/usr --sysconfdir=/etc && make && make install
cd
vnstat -u -i $NET
sed -i 's/Interface "'""eth0""'"/Interface "'""$NET""'"/g' /etc/vnstat.conf
chown vnstat:vnstat /var/lib/vnstat -R
systemctl enable vnstat
/etc/init.d/vnstat restart
rm -f /root/vnstat-2.6.tar.gz
rm -rf /root/vnstat-2.6

# Startup Script
cat << voltnetku > /etc/systemd/system/voltnet.service
[Unit]
Description=Tsholo Startup Script
Wants=network.target
After=network.target
[Service]
Type=oneshot
ExecStart=/bin/bash /etc/voltnet/startup.sh
RemainAfterExit=yes
[Install]
WantedBy=network.target
voltnetku

chmod +x /etc/voltnet/startup.sh
systemctl daemon-reload
systemctl enable voltnet
systemctl start voltnet

# Block Torrents
iptables -A FORWARD -m string --string "get_peers" --algo bm -j DROP
iptables -A FORWARD -m string --string "announce_peer" --algo bm -j DROP
iptables -A FORWARD -m string --string "find_node" --algo bm -j DROP
iptables -A FORWARD -m string --algo bm --string "BitTorrent" -j DROP
iptables -A FORWARD -m string --algo bm --string "BitTorrent protocol" -j DROP
iptables -A FORWARD -m string --algo bm --string "peer_id=" -j DROP
iptables -A FORWARD -m string --algo bm --string ".torrent" -j DROP
iptables -A FORWARD -m string --algo bm --string "announce.php?passkey=" -j DROP
iptables -A FORWARD -m string --algo bm --string "torrent" -j DROP
iptables -A FORWARD -m string --algo bm --string "announce" -j DROP
iptables -A FORWARD -m string --algo bm --string "info_hash" -j DROP
iptables-save > /etc/iptables.up.rules
iptables-restore -t < /etc/iptables.up.rules
netfilter-persistent save
netfilter-persistent reload

# Purge Unnecessary Files
apt -y autoclean
apt -y remove --purge unscd
apt-get -y --purge remove samba*;
apt-get -y --purge remove apache2*;
apt-get -y --purge remove bind9*;
apt-get -y remove sendmail*

# Stop Nginx Port 80
service nginx stop
