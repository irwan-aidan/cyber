#/bin/bash
depend(){
apt-get update -y
apt-get install wget socat curl zip -y
read -p " Please enter the domain name: " domain
echo  " The domain name you entered is: $domain "
}

ngx () {
apt-get install nginx  -y
systemctl restart nginx || /etc/init.d/nginx restart
}

install_acme(){
if [ ! -d "/root/.acme.sh" ]; then
echo  " install acme.sh "
curl  https://get.acme.sh | sh > /dev/null
echo "alias acme.sh=~/.acme.sh/acme.sh" >> /root/.bashrc
source /root/.bashrc
echo  " acme.h installation is complete! "
be
}

acme_cer(){
echo  " Generating certificate... "
/root/.acme.sh/acme.sh --set-default-ca  --server  letsencrypt
systemctl stop nginx || /etc/init.d/nginx stop
/root/.acme.sh/acme.sh  --issue -d $domain  --standalone --force
if [ $? == 0 ]; then
echo  " Certificate generation completed! "
else
echo  " Install the certificate, please check the configuration or reinstall! "
exit 2
be

systemctl start nginx || /etc/init.d/nginx start

mkdir -p /etc/nginx/ssl
/root/.acme.sh/acme.sh --install-cert -d $domain \
--key-file       /etc/nginx/ssl/$domain.key.pem  \
--fullchain-file /etc/nginx/ssl/$domain.cert.pem \
--reloadcmd     "service nginx force-reload"

chown nobody /etc/nginx/ssl/$domain.key.pem
chown nobody /etc/nginx//ssl/$domain.cert.pem
}

acme_cer_renew(){
read -p " Please enter the domain name: " renewdomain
echo  " The domain name you entered is: $renewdomain "
echo  " Generating certificate... "
systemctl stop nginx || /etc/init.d/nginx stop
systemctl stop  xray
/root/.acme.sh/acme.sh  --issue -d $renewdomain  --standalone --force
systemctl start nginx || /etc/init.d/nginx start

mkdir -p /etc/nginx/ssl
/root/.acme.sh/acme.sh --install-cert -d $domain \
--key-file       /etc/nginx/ssl/$renewdomain.key.pem  \
--fullchain-file /etc/nginx/ssl/$renewdomain.cert.pem \
--reloadcmd     "service nginx force-reload"
chown nobody /etc/nginx/ssl/$renewdomain.key.pem
chown nobody /etc/nginx//ssl/$renewdomain.cert.pem
systemctl restart  xray
echo  " Certificate generation completed! "

}

xray(){
echo  " Start to install/update xray "
bash <(curl -L https://raw.githubusercontent.com/XTLS/Xray-install/main/install-release.sh)  > /dev/null
if [ $? == 0 ]; then
echo  " xray installation is complete! "
systemctl restart xray
else
echo  " Failed to install xray, please check the network or reinstall! "
exit 2
be
}

change_vmess_nginx_tls_conf(){
wget -qO /usr/local/etc/xray/config.json https://raw.githubusercontent.com/huya1121/xray/master/config.json
ouid= ` sed -n ' 16p ' /usr/local/etc/xray/config.json | awk -F ' " '  ' {print $4} ' `
uid=`cat /proc/sys/kernel/random/uuid`
sed -i " s/ $ouid / $uid /g " /usr/local/etc/xray/config.json
systemctl daemon-reload
systemctl restart xray
}

change_vless_xtls_conf(){
wget -qO /usr/local/etc/xray/config.json https://raw.githubusercontent.com/huya1121/xray/master/config.json.xtls
ouid= ` sed -n ' 12p ' /usr/local/etc/xray/config.json | awk -F ' " '  ' {print $4} ' `
uid=`cat /proc/sys/kernel/random/uuid`
sed -i " s/ $ouid / $uid /g " /usr/local/etc/xray/config.json
sed -i "s/abc.com/$domain/g" /usr/local/etc/xray/config.json
systemctl restart xray
}

conf_nginx(){
wget -qO /etc/nginx/sites-available/xray.conf https://raw.githubusercontent.com/huya1121/xray/master/xray.conf
ln -s /etc/nginx/sites-available/xray.conf /etc/nginx/sites-enabled/xray.conf
sed -i "s/abc.com/$domain/g" /etc/nginx/sites-available/xray.conf
systemctl restart nginx || /etc/init.d/nginx restart
}


conf_nginx_fallback(){
wget -qO /etc/nginx/sites-available/xray.conf https://raw.githubusercontent.com/huya1121/xray/master/xray2.conf
wget -qO /var/www/html/index.html https://raw.githubusercontent.com/huya1121/xray/master/index.html
ln -s /etc/nginx/sites-available/xray.conf /etc/nginx/sites-enabled/xray.conf
sed -i "s/abc.com/$domain/g" /etc/nginx/sites-available/xray.conf
systemctl restart nginx || /etc/init.d/nginx restart
}

xray_info(){
echo  "The server configuration information is as follows: "
echo  " Server: $domain "
echo  " Port: 443 "
echo "AlterID：64"
echo "UUID：$uid"
echo "PATH：/api/"
echo "WS+TLS"
echo  " installation complete "
}

xray_vless_tls(){
echo  "The server configuration information is as follows: "
echo  " Server: $domain "
echo  " Port: 443 "
echo "UUID：$uid"
echo "flow：xtls-rprx-direct"
echo "Vless+XTLS"
echo "transport: tcp+xtls"
echo  " installation complete "
}

vmess_nginx_tls(){
depend
ngx
install_acme
acme_cer
xray
change_vmess_nginx_tls_conf
conf_nginx
xray_info
exit 0
}
vless_xtls(){
depend
ngx
install_acme
acme_cer
xray
change_vless_xtls_conf
conf_nginx_fallback
xray_vless_tls
exit 0
}

#main
echo "################################"
echo "#   1 install vless+xtls        #"
echo "#   2 install vmess+nginx+tls  #"
echo "#   3 renew cert               #"
echo "#   4 update xray              #"
echo "#   0 exit                     #" 
echo "################################"
read -p " Please enter: " input
case $input in
  1)
  vless_xtls
  ;;
  2)
  vmess_nginx_tls
  ;;
  3)
  acme_cer_renew
  ;;
  4)
  xray
  ;;
   0)
  exit 0
  ;;
  *)
  echo "please use bash xray.sh"
  ;;
esac
