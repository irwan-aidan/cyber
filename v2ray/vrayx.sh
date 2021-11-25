#!/bin/bash
domain=$(cat /root/domain)
apt install iptables iptables-persistent -y
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

# install v2ray
wget https://raw.githubusercontent.com/muhamadparizan/ahahk/main/go.sh && chmod +x go.sh && ./go.sh
rm -f /root/go.sh
wget https://raw.githubusercontent.com/kor8/cyber/beta/v2ray/nginx.sh && chmod +x nginx.sh && ./nginx.sh
service squid start
uuid=$(cat /proc/sys/kernel/random/uuid)


cd
rm -f v2rayx.sh
mv /root/domain /etc/v2ray
