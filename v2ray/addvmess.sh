#!/bin/bash
# Add Vmess
# ===================

# Color
RED="\e[1;31m"
GREEN="\e[0;32m"
NC="\e[0m"

IP=$( curl -s ipinfo.io/ip );
clear
source /var/lib/premium-script/ipvps.conf
if [[ "$IP" = "" ]]; then
domain=$(cat /etc/v2ray/domain)
else
domain=$IP
fi
tls=8443
none=80

until [[ $user =~ ^[a-zA-Z0-9_]+$ && ${CLIENT_EXISTS} == '0' ]]; do
		read -rp "User: " -e user
		CLIENT_EXISTS=$(grep -w $user /etc/v2ray/config.json | wc -l)

		if [[ ${CLIENT_EXISTS} == '1' ]]; then
			echo ""
			echo "A client with the specified name was already created, please choose another name."
			exit 1
		fi
	done
uuid=$(cat /proc/sys/kernel/random/uuid)
read -p "Expired (days): " masaaktif
exp=`date -d "$masaaktif days" +"%Y-%m-%d"`
sed -i '/#tls$/a\### '"$user $exp"'\
},{"id": "'""$uuid""'","alterId": '"2"',"email": "'""$user""'"' /etc/v2ray/config.json
sed -i '/#none$/a\### '"$user $exp"'\
},{"id": "'""$uuid""'","alterId": '"2"',"email": "'""$user""'"' /etc/v2ray/none.json
cat>/etc/v2ray/$user-tls.json<<EOF
      {
      "v": "2",
      "ps": "${user}",
      "add": "${domain}",
      "port": "${tls}",
      "id": "${uuid}",
      "aid": "32",
      "net": "ws",
      "path": "/v2ray",
      "type": "none",
      "host": "",
      "tls": "tls"
}
EOF
cat>/etc/v2ray/$user-none.json<<EOF
      {
      "v": "2",
      "ps": "${user}",
      "add": "${domain}",
      "port": "${none}",
      "id": "${uuid}",
      "aid": "32",
      "net": "ws",
      "path": "/v2ray",
      "type": "none",
      "host": "",
      "tls": "none"
}
EOF

# Make File For Clash
cp /etc/darknet/clash-nontls.yaml /home/vps/public_html/clash/${user}-nontls.yaml

# Input Username to clash configuration
sed -i "s/darknet1/$user/g" /home/vps/public_html/clash/${user}-nontls.yaml
sed -i "s/darknet2/$domain/g" /home/vps/public_html/clash/${user}-nontls.yaml
sed -i "s/darknet3/$none/g" /home/vps/public_html/clash/${user}-nontls.yaml
sed -i "s/darknet4/vmess/g" /home/vps/public_html/clash/${user}-nontls.yaml
sed -i "s/darknet5/$uuid/g" /home/vps/public_html/clash/${user}-nontls.yaml
sed -i "s/darknet6/32/g" /home/vps/public_html/clash/${user}-nontls.yaml
sed -i "s/darknet7/auto/g" /home/vps/public_html/clash/${user}-nontls.yaml
sed -i "s/darknet8/$domain/g" /home/vps/public_html/clash/${user}-nontls.yaml

# Make File For Clash ( TLS )
cp /etc/darknet/clash-tls.yaml /home/vps/public_html/clash/${user}-tls.yaml

# Input Username to clash configuration
sed -i "s/darknet1/$user/g" /home/vps/public_html/clash/${user}-tls.yaml
sed -i "s/darknet2/$domain/g" /home/vps/public_html/clash/${user}-tls.yaml
sed -i "s/darknet3/$tls/g" /home/vps/public_html/clash/${user}-tls.yaml
sed -i "s/darknet4/vmess/g" /home/vps/public_html/clash/${user}-tls.yaml
sed -i "s/darknet5/$uuid/g" /home/vps/public_html/clash/${user}-tls.yaml
sed -i "s/darknet6/32/g" /home/vps/public_html/clash/${user}-tls.yaml
sed -i "s/darknet7/auto/g" /home/vps/public_html/clash/${user}-tls.yaml
sed -i "s/darknet8/$domain/g" /home/vps/public_html/clash/${user}-tls.yaml


vmess_base641=$( base64 -w 0 <<< $vmess_json1)
vmess_base642=$( base64 -w 0 <<< $vmess_json2)
vmesslink1="vmess://$(base64 -w 0 /etc/v2ray/$user-tls.json)"
vmesslink2="vmess://$(base64 -w 0 /etc/v2ray/$user-none.json)"
systemctl restart v2ray
systemctl restart v2ray@none
service cron restart
clear
echo -e ""
echo -e "==========-V2RAY/VMESS-=========="
echo -e "Remarks        : ${user}"
echo -e "Domain         : ${domain}"
echo -e "port TLS       : ${tls}"
echo -e "port none TLS  : ${none}"
echo -e "id             : ${uuid}"
echo -e "alterId        : 32"
echo -e "Security       : auto"
echo -e "network        : ws"
echo -e "path           : /v2ray"
echo -e "================================="
echo -e "link TLS       : ${vmesslink1}"
echo -e "================================="
echo -e "link none TLS  : ${vmesslink2}"
echo -e "================================="
echo -e "Link Yaml NTLS : http://${domain}:81/clash/${user}-nontls.yaml"
echo -e "================================="
echo -e "Link Yaml TLS  : http://${domain}:81/clash/${user}-tls.yaml"
echo -e "================================="
echo -e "Expired On     : $exp"
echo -e "Script By Darknet"
