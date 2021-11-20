#!/bin/bash
# Version: 0.4.r2
export DEBIAN_FRONTEND=noninteractive
history -c && rm -rf ~/.bash_history
# Check VPS Is Debian
source /etc/os-release
if [[ "$ID" != 'debian' ]]; then
echo -e "[\e[1;31mError\e[0m] This script is for Debian only, exiting..." 
exit 1
fi

if [[ $EUID -ne 0 ]];then
echo -e "[\e[1;31mError\e[0m] This script must be run as root, exiting..."
exit 1
fi

# Script name
MyScriptName='CyberVPN Premium Script'
VPN_Owner='CyberVPN'
VPN_Name='CyberVPN'
Filename_alias='CyberVPN'

# Server local time
MyVPS_Time='Asia/Kuala_Lumpur'

# OpenSSH Ports
SSH_Port1='22'
SSH_Port2='225'

# Dropbear Ports
Dropbear_Port1='86'
Dropbear_Port2='87'

# Stunnel Ports
Stunnel_Port1='82' # through Dropbear
Stunnel_Port2='83' # through OpenSSH
Stunnel_Port3='84' # through OpenVPN
Stunnel_Port4='85' # through Web Socket

# OpenVPN Ports
OpenVPN_TCP_Port='465'
OpenVPN_UDP_Port='466'

# Squid Ports
Squid_Port1='8000'
Squid_Port2='3128'
Squid_Port3='60000'

# Monitor Ports
MGMT_TCP_PORT='5555'
MGMT_UDP_PORT='5556'
Monitor_Port='5000'

# Apache Directory
web=/var/www/html

# Get Public IP
IPADDR="$( wget -qO- ipv4.icanhazip.com)"

# Update VPS
APT="apt-get --allow-unauthenticated -y"
$APT update
yes | $APT upgrade

systemctl stop apache2
$APT install dropbear openvpn stunnel4 squid python3 apt-transport-https software-properties-common gnupg2 ca-certificates curl nginx fail2ban

# Removing Unnecessary packages
$APT remove --purge ufw firewalld
$APT autoremove

# Configure SSH
mv /etc/ssh/sshd_config /etc/ssh/sshd-config-old
cat << MySSHConfig > /etc/ssh/sshd_config
Port $SSH_Port1
Port $SSH_Port2
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
ClientAliveCountMax 2
Banner /etc/banner
AcceptEnv LANG LC_*
Subsystem   sftp  /usr/lib/openssh/sftp-server
MySSHConfig

# Creating Banner Message
apt-get -y install geoip-bin
ipadd=$(wget -qO- ipv4.icanhazip.com);
geoip=$(whois $ipadd |grep country -i -m 1 |cut -d ':' -f 2 |xargs);
geoip2=$(whois $ipadd |grep descr -i -m 1 |cut -d ':' -f 2 |xargs);

cat << banner > /etc/banner
<br><font color="blue"><b>⚽CyberVPN</b></font>
<br><font color="red"><b>Server: $geoip, $geoip2</b></font><br>
banner

# SSH Fixes
sed -i '/password\s*requisite\s*pam_cracklib.s.*/d;s/use_authtok //g' /etc/pam.d/common-password
sed -i '/\/bin\/false/d' /etc/shells
sed -i '/\/usr\/sbin\/nologin/d' /etc/shells
echo '/bin/false' >> /etc/shells
echo '/usr/sbin/nologin' >> /etc/shells
systemctl restart ssh

# Install Dropbear
mv /etc/default/dropbear /etc/default/dropbear-old
cat << MyDropbear > /etc/default/dropbear
NO_START=0
DROPBEAR_PORT=$Dropbear_Port1
DROPBEAR_EXTRA_ARGS="-p $Dropbear_Port2"
DROPBEAR_BANNER="/etc/banner"
DROPBEAR_RSAKEY="/etc/dropbear/dropbear_rsa_host_key"
DROPBEAR_DSSKEY="/etc/dropbear/dropbear_dss_host_key"
DROPBEAR_ECDSAKEY="/etc/dropbear/dropbear_ecdsa_host_key"
DROPBEAR_RECEIVE_WINDOW=65536
MyDropbear
systemctl restart dropbear

# Install Stunnel
StunnelDir=$(ls /etc/default | grep stunnel | head -n1)
cat << MyStunnelD > /etc/default/stunnel4
ENABLED=1
FILES="/etc/stunnel/*.conf"
OPTIONS=""
BANNER="/etc/banner"
PPP_RESTART=0
# RLIMITS="-n 4096 -d unlimited"
RLIMITS=""
MyStunnelD
sed -i '/ENABLED=/{s/0/1/g}' /etc/init.d/stunnel4
rm -rf /etc/stunnel/*

# Create SSL Certs
openssl req -new -x509 -days 9999 -nodes -subj "/C=MY/ST=NCR/L=Malaysia/O=$MyScriptName/OU=$MyScriptName/CN=$MyScriptName" -out /etc/stunnel/stunnel.pem -keyout /etc/stunnel/stunnel.pem &> /dev/null

# Creating Stunnel Config
cat << MyStunnelC > /etc/stunnel/stunnel.conf
pid = /var/run/stunnel.pid
cert = /etc/stunnel/stunnel.pem
client = no
socket = a:SO_REUSEADDR=1
socket = l:TCP_NODELAY=1
socket = r:TCP_NODELAY=1
TIMEOUTclose = 0
[https]
accept = 444
connect = 127.0.0.1:22
connect = 127.0.0.1:86
MyStunnelC

# Restarting Stunnel
systemctl daemon-reload
systemctl restart stunnel4

# [ Setup Openvpn ]
# OpenVPN Cert CA
mkdir /etc/openvpn/easy-rsa
cat << CA > /etc/openvpn/easy-rsa/ca.crt
-----BEGIN CERTIFICATE-----
MIIEbjCCA1agAwIBAgIJAJdSDmspwxUnMA0GCSqGSIb3DQEBCwUAMIGAMQswCQYD
VQQGEwJaQTELMAkGA1UECBMCR1QxFDASBgNVBAcTC1ZlcmVlbmlnaW5nMRIwEAYD
VQQKEwlUc2hvbG9WUE4xFTATBgNVBAMTDFRzaG9sb1ZQTiBDQTEjMCEGCSqGSIb3
DQEJARYUYWRtaW5AdHNob2xvdnBuLmluZm8wHhcNMTUwODI0MTA1NDE3WhcNMjUw
ODIxMTA1NDE3WjCBgDELMAkGA1UEBhMCWkExCzAJBgNVBAgTAkdUMRQwEgYDVQQH
EwtWZXJlZW5pZ2luZzESMBAGA1UEChMJVHNob2xvVlBOMRUwEwYDVQQDEwxUc2hv
bG9WUE4gQ0ExIzAhBgkqhkiG9w0BCQEWFGFkbWluQHRzaG9sb3Zwbi5pbmZvMIIB
IjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA4dKR9lbZIVmANbQORRd/lV9+
qfvGE3z7pkNjdvBh8baVpOImn3+6rANbgUPNisnXvGGx+0rLfZdB/MEqDp21wiwf
ytoy2E5ZmJHB8Xp58PR1SNxCHz5q1qM7WlJ0GHYY+0I45OF9sz9sBNnJBXstpi8T
T2jfsjyCpZ6RRuT363yapZ+sayuay3U7T3tQw5Qmca7DUVXGjaEHitQiA4U5rfHd
LNifhxkZY3hERdRIlsgPZHQIZY5rn8O3BMqcHPeTMLnCnZyOc468NPoeXdc/WwAc
SaxhApszlwk/ILwjLpnY2aDSBIn5Kd1zTfZyR6yc6MIcYysMhkLczDub+2rHGQID
AQABo4HoMIHlMB0GA1UdDgQWBBQiIe8AGlmSBwE0ikGPz0UWGurzuDCBtQYDVR0j
BIGtMIGqgBQiIe8AGlmSBwE0ikGPz0UWGurzuKGBhqSBgzCBgDELMAkGA1UEBhMC
WkExCzAJBgNVBAgTAkdUMRQwEgYDVQQHEwtWZXJlZW5pZ2luZzESMBAGA1UEChMJ
VHNob2xvVlBOMRUwEwYDVQQDEwxUc2hvbG9WUE4gQ0ExIzAhBgkqhkiG9w0BCQEW
FGFkbWluQHRzaG9sb3Zwbi5pbmZvggkAl1IOaynDFScwDAYDVR0TBAUwAwEB/zAN
BgkqhkiG9w0BAQsFAAOCAQEAwPP8Omorca2f5uzYrnROmqOEtlwaJb/t8WbeBVd0
HzeXQRyhn5ssx1ZPZCYP3GwsQU/0xPrs/wwIVpAimK66qdTNoii4qYFcJ0u18Nnh
BtgS6r7Lgyl0X+u2aSj6mYjqNySkKnXBgsaD6/Z35P/2PK7b/xN7K2eShadj+5Ry
7AXIVZIqN32ha3Ugs8FAc3EDfaBgeLBUm+hznxNu059PG1T6jTCbLAfDBbbhMrN1
zC8w5j+UXyV3qCP64s2HNP5ZU/aoSnK/QYFUgLxq+RccR/Ph6bctNu81uwta10lc
Q7A78Dl5voYKxdoitmPZIrE41q9cuRmbS22rhcaNYLL+iA==
-----END CERTIFICATE-----
CA

# Server CRT
cat << CRT > /etc/openvpn/easy-rsa/CyberVPN.crt
Certificate:
    Data:
        Version: 3 (0x2)
        Serial Number: 1 (0x1)
    Signature Algorithm: sha256WithRSAEncryption
        Issuer: C=ZA, ST=GT, L=Vereeniging, O=TsholoVPN, CN=TsholoVPN CA/emailAddress=admin@tsholovpn.info
        Validity
            Not Before: Aug 24 10:54:37 2015 GMT
            Not After : Aug 21 10:54:37 2025 GMT
        Subject: C=ZA, ST=GT, L=Vereeniging, O=TsholoVPN, CN=TsholoVPN/emailAddress=admin@tsholovpn.info
        Subject Public Key Info:
            Public Key Algorithm: rsaEncryption
                Public-Key: (2048 bit)
                Modulus:
                    00:b5:f0:64:f7:de:02:fb:35:00:53:95:34:97:cb:
                    8b:c1:f6:7b:7c:89:5a:7d:09:05:6f:e8:ee:f3:3e:
                    e8:08:89:23:76:97:e9:ea:05:1e:2d:cc:82:0e:97:
                    99:2d:f1:64:ab:d0:25:c6:06:fc:b2:6b:3e:5b:24:
                    d1:26:3e:b5:e9:48:81:f4:b9:6a:4b:b9:28:28:ef:
                    76:78:c0:f7:ff:7e:f7:44:44:18:46:64:fb:31:f2:
                    b8:ba:fe:2e:05:95:cd:26:fe:19:9f:5f:01:a0:7c:
                    3e:76:84:50:a0:0a:a1:07:db:1a:2b:d5:42:cc:2b:
                    2c:14:8c:6b:04:76:2a:d3:46:56:60:93:14:14:46:
                    06:69:8a:93:46:2b:76:69:a0:79:46:ca:e7:25:48:
                    12:55:76:9b:e4:8c:69:4b:50:72:eb:2a:52:d0:5e:
                    ae:84:0a:3c:29:88:81:3c:f8:ae:5b:e4:f3:c4:83:
                    8d:67:bb:94:5a:37:f9:b4:45:09:d2:95:9b:97:3a:
                    bc:b7:3d:48:8a:f4:98:68:5d:0c:aa:01:22:60:05:
                    de:7c:eb:78:85:fd:eb:9b:c0:d8:7f:b0:c4:98:a7:
                    b5:02:c9:d4:17:5a:5f:ac:87:8c:d3:8d:f2:22:c3:
                    b0:93:29:45:66:72:85:2d:6d:45:07:ce:32:0d:61:
                    11:d7
                Exponent: 65537 (0x10001)
        X509v3 extensions:
            X509v3 Basic Constraints: 
                CA:FALSE
            Netscape Cert Type: 
                SSL Server
            Netscape Comment: 
                Easy-RSA Generated Server Certificate
            X509v3 Subject Key Identifier: 
                F9:A1:AE:4A:9E:02:9D:9B:0A:C6:82:AF:4C:B8:99:1C:EE:FD:E4:F5
            X509v3 Authority Key Identifier: 
                keyid:22:21:EF:00:1A:59:92:07:01:34:8A:41:8F:CF:45:16:1A:EA:F3:B8
                DirName:/C=ZA/ST=GT/L=Vereeniging/O=TsholoVPN/CN=TsholoVPN CA/emailAddress=admin@tsholovpn.info
                serial:97:52:0E:6B:29:C3:15:27
            X509v3 Extended Key Usage: 
                TLS Web Server Authentication
            X509v3 Key Usage: 
                Digital Signature, Key Encipherment
    Signature Algorithm: sha256WithRSAEncryption
         59:40:cd:31:c1:54:92:39:94:22:d3:cc:f5:3f:c3:6e:63:31:
         a2:d7:ad:1a:fa:7f:dc:b2:66:c1:86:a4:51:95:ae:4a:03:f2:
         80:dc:06:af:9e:bf:5a:6b:5c:8c:9e:99:2d:b1:87:57:2c:ac:
         29:61:fd:90:6d:e3:cd:9a:3c:62:d5:1c:8a:13:87:5b:73:ed:
         57:cf:fc:a1:a7:13:77:30:c2:28:92:88:ba:71:2c:e4:db:e8:
         d7:8b:10:6c:74:a0:93:30:71:02:03:18:f3:d3:5f:ed:72:4b:
         10:52:30:36:4e:24:5e:d3:52:14:0d:27:12:74:a3:1e:fe:c0:
         25:8e:fa:32:66:61:f5:1f:02:db:c3:76:4b:66:01:d3:98:9d:
         6a:50:5b:38:e8:6a:3e:1a:64:cf:56:b6:7f:5b:af:29:8f:e4:
         7c:9c:f6:b2:6f:4e:8e:de:28:13:8f:0b:04:16:d1:9f:fc:4c:
         69:c4:2a:21:69:79:21:52:1a:66:93:9d:ea:a1:e6:0e:09:4c:
         ae:49:eb:8e:6b:e9:48:bd:04:8b:97:c1:f1:5d:7f:02:da:c1:
         fb:f3:cc:17:8d:2d:49:63:55:9f:39:33:a4:66:3c:73:1f:a9:
         56:8d:68:52:2c:9e:1c:c0:47:dc:85:03:48:7f:c2:3f:fb:e2:
         a2:da:bc:71
-----BEGIN CERTIFICATE-----
MIIEzDCCA7SgAwIBAgIBATANBgkqhkiG9w0BAQsFADCBgDELMAkGA1UEBhMCWkEx
CzAJBgNVBAgTAkdUMRQwEgYDVQQHEwtWZXJlZW5pZ2luZzESMBAGA1UEChMJVHNo
b2xvVlBOMRUwEwYDVQQDEwxUc2hvbG9WUE4gQ0ExIzAhBgkqhkiG9w0BCQEWFGFk
bWluQHRzaG9sb3Zwbi5pbmZvMB4XDTE1MDgyNDEwNTQzN1oXDTI1MDgyMTEwNTQz
N1owfTELMAkGA1UEBhMCWkExCzAJBgNVBAgTAkdUMRQwEgYDVQQHEwtWZXJlZW5p
Z2luZzESMBAGA1UEChMJVHNob2xvVlBOMRIwEAYDVQQDEwlUc2hvbG9WUE4xIzAh
BgkqhkiG9w0BCQEWFGFkbWluQHRzaG9sb3Zwbi5pbmZvMIIBIjANBgkqhkiG9w0B
AQEFAAOCAQ8AMIIBCgKCAQEAtfBk994C+zUAU5U0l8uLwfZ7fIlafQkFb+ju8z7o
CIkjdpfp6gUeLcyCDpeZLfFkq9Alxgb8sms+WyTRJj616UiB9LlqS7koKO92eMD3
/373REQYRmT7MfK4uv4uBZXNJv4Zn18BoHw+doRQoAqhB9saK9VCzCssFIxrBHYq
00ZWYJMUFEYGaYqTRit2aaB5RsrnJUgSVXab5IxpS1By6ypS0F6uhAo8KYiBPPiu
W+TzxIONZ7uUWjf5tEUJ0pWblzq8tz1IivSYaF0MqgEiYAXefOt4hf3rm8DYf7DE
mKe1AsnUF1pfrIeM043yIsOwkylFZnKFLW1FB84yDWER1wIDAQABo4IBUTCCAU0w
CQYDVR0TBAIwADARBglghkgBhvhCAQEEBAMCBkAwNAYJYIZIAYb4QgENBCcWJUVh
c3ktUlNBIEdlbmVyYXRlZCBTZXJ2ZXIgQ2VydGlmaWNhdGUwHQYDVR0OBBYEFPmh
rkqeAp2bCsaCr0y4mRzu/eT1MIG1BgNVHSMEga0wgaqAFCIh7wAaWZIHATSKQY/P
RRYa6vO4oYGGpIGDMIGAMQswCQYDVQQGEwJaQTELMAkGA1UECBMCR1QxFDASBgNV
BAcTC1ZlcmVlbmlnaW5nMRIwEAYDVQQKEwlUc2hvbG9WUE4xFTATBgNVBAMTDFRz
aG9sb1ZQTiBDQTEjMCEGCSqGSIb3DQEJARYUYWRtaW5AdHNob2xvdnBuLmluZm+C
CQCXUg5rKcMVJzATBgNVHSUEDDAKBggrBgEFBQcDATALBgNVHQ8EBAMCBaAwDQYJ
KoZIhvcNAQELBQADggEBAFlAzTHBVJI5lCLTzPU/w25jMaLXrRr6f9yyZsGGpFGV
rkoD8oDcBq+ev1prXIyemS2xh1csrClh/ZBt482aPGLVHIoTh1tz7VfP/KGnE3cw
wiiSiLpxLOTb6NeLEGx0oJMwcQIDGPPTX+1ySxBSMDZOJF7TUhQNJxJ0ox7+wCWO
+jJmYfUfAtvDdktmAdOYnWpQWzjoaj4aZM9Wtn9brymP5Hyc9rJvTo7eKBOPCwQW
0Z/8TGnEKiFpeSFSGmaTneqh5g4JTK5J645r6Ui9BIuXwfFdfwLawfvzzBeNLUlj
VZ85M6RmPHMfqVaNaFIsnhzAR9yFA0h/wj/74qLavHE=
-----END CERTIFICATE-----
CRT

# Server KEY
cat << KEY > /etc/openvpn/easy-rsa/CyberVPN.key
-----BEGIN PRIVATE KEY-----
MIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQC18GT33gL7NQBT
lTSXy4vB9nt8iVp9CQVv6O7zPugIiSN2l+nqBR4tzIIOl5kt8WSr0CXGBvyyaz5b
JNEmPrXpSIH0uWpLuSgo73Z4wPf/fvdERBhGZPsx8ri6/i4Flc0m/hmfXwGgfD52
hFCgCqEH2xor1ULMKywUjGsEdirTRlZgkxQURgZpipNGK3ZpoHlGyuclSBJVdpvk
jGlLUHLrKlLQXq6ECjwpiIE8+K5b5PPEg41nu5RaN/m0RQnSlZuXOry3PUiK9Jho
XQyqASJgBd5863iF/eubwNh/sMSYp7UCydQXWl+sh4zTjfIiw7CTKUVmcoUtbUUH
zjINYRHXAgMBAAECggEAZZQX60OqynInAoN1X6KnHt3sx/Uv7ktRG9AjSO/AQLPA
dwAN+zhsRwm9O0Rso3f4yuxlipBwGXVC1URS+VVd3yc6V1YGAM0ZnPFFZdnnHGDY
0OZr3zGWBacMeGpda4Tdi32m9JHoqJ91iFoLYa9NhMNRc1OX/cHE1JwpS85lzpqv
tibPMPa8e6jnvO1wJqc+XpnQmXIpHSQJxK69kRmhuVNrH2Nf9Vqbvuc9AYOObA0m
88213WfN8pmAgeJNCCiSOCSUFgJHFnM0uswOipLZzWLtbi6jSrLagpIZxKJHdPCE
nqKJcSiCbGl1eU/rlTmBGDV/nAUxtd0G7Ux6+d6BoQKBgQDYOEW0Y+J6ksFXnTVo
0axx6YwNqAUuwfIWLafxTBXb8k0AYFVMr9Z6T5hIhXo1jG8041BPTi8GU1JhgA2i
8x6B8jr1UTuXhHLQqZKB4voLEAzwrCMuftcVE1XS3UGjl6i3sHfmvjBhrfU/NtNZ
A3mWELxlISRMyLzFZ8Ds1ddHKQKBgQDXaYiRfcbteokChzdO9CgaaN9PylfDMAUn
E0/cyfaplwg/w/Zpj9fJyejcpvp9y2tCB0Urd6rlWpBwpn2gMtZx8t0v1lpe7IxP
A7qJ8ozDNqPf21xLsp6faz0UukqprY59YF/yjkgJr5/ZXivAnbxTR9jN9Re4R+3L
vohSbH2w/wKBgGKi4SGWw3WZRzw5ymij5iAdI7gDI0IeVdrKPyfzxrEMyxXV3HPc
b2Jitxy2T3boNr8Qx8015HvlPNqfuRjSAePT5hONWDsZv+rywJQiQGEVlGGilXYb
hPDnXiqQpuYDRINvrHMF5jpZSlzpHOcpj6jmv5r+0Hl6xarkVv1z2/5pAoGBANEw
r2t7FeAxizRlU5TdDsT260Z1Xd0zmQ1ld70WdPAkt+IU0AuboRdZeUYu8juPfE3W
+ZlI0TGCTZrYVE9qj06BZ8O5CnH8jhV9rX2hiolZWrNeN7dbcyel4N9sOm2lGicv
nH3VJqghYb6Z8StRAz5tG2KHjc1sLMYb9g71ROrJAoGAGgRaWbx8US8z4hPp/BB8
6hXvt2QKNNgH/P/oDKcJpqB/Fy2MUO6FnIEQMVSAWj+cZajj8hmKWGFhyuX7NVtt
EEURauGtar75MsULYhqADzX4ylJYgN+oqPbbJlALEi0+HgoLpyGLNYn38oP/ko8v
w3VMBwVhspalpBuX2QWNUWE=
-----END PRIVATE KEY-----
KEY

# Server DH2048
 cat << DH > /etc/openvpn/easy-rsa/dh2048.pem
-----BEGIN DH PARAMETERS-----
MIIBCAKCAQEA1emiXAI6I7h2niDL+zRZ3CkRs0LTt1jCTL4mPx7O5aT5GjsPzXVb
GRH6CMlQBE28Uk/Kg1lojfpV2fOL1gmyk7kaRxKO1hmr6fCS07WlfdUUbF2CKK3F
jRkj6U3NDC0sMgOJI2+io8j2V+xCKNehaz58caozlyo8efwI6cT1jZY2KlEwFbnl
4D0K7TFJs3K5rhBZ9KOfh10nYVsw0mbWMTwUAlRB/97K9VTnnrDx2WQONIkB/zgt
5RKpPxmN1d1cJ/7II559PPGiUf/UL4SSXH8L5c05xDLyNoeH6qPbA78umRA3CZEH
An1jD+OUdrLRqjxcEoel9tm3b9h/YWbu2wIBAg==
-----END DH PARAMETERS-----
DH

# Some workaround for OpenVZ machines for "Startup error" openvpn service
if [[ "$(hostnamectl | grep -i Virtualization | awk '{print $2}' | head -n1)" == 'openvz' ]]; then
sed -i 's|LimitNPROC|#LimitNPROC|g' /lib/systemd/system/openvpn*
systemctl daemon-reload
fi

apt remove --purge squid -y
wget "http://security.debian.org/debian-security/pool/updates/main/s/squid3/squid_3.5.23-5+deb9u7_amd64.deb" -qO squid.deb
dpkg -i squid.deb
rm -f squid.deb

apt install libecap3 squid-common squid-langpack -y
wget "http://security.debian.org/debian-security/pool/updates/main/s/squid3/squid_3.5.23-5+deb9u7_amd64.deb" -qO squid.deb
dpkg -i squid.deb
rm -f squid.deb

# Setting Up Squid 
rm -rf /etc/squid/squid.con*
cat << mySquid > /etc/squid/squid.conf
acl VPN dst $IPADDR/32
http_access allow VPN
http_access deny all 
http_port 0.0.0.0:$Squid_Port1
http_port 0.0.0.0:$Squid_Port2
http_port 0.0.0.0:$Squid_Port3
request_header_access Allow allow all 
request_header_access Authorization allow all 
request_header_access WWW-Authenticate allow all 
request_header_access Proxy-Authorization allow all 
request_header_access Proxy-Authenticate allow all 
request_header_access Cache-Control allow all 
request_header_access Content-Encoding allow all 
request_header_access Content-Length allow all 
request_header_access Content-Type allow all 
request_header_access Date allow all 
request_header_access Expires allow all 
request_header_access Host allow all 
request_header_access If-Modified-Since allow all 
request_header_access Last-Modified allow all 
request_header_access Location allow all 
request_header_access Pragma allow all 
request_header_access Accept allow all 
request_header_access Accept-Charset allow all 
request_header_access Accept-Encoding allow all 
request_header_access Accept-Language allow all 
request_header_access Content-Language allow all 
request_header_access Mime-Version allow all 
request_header_access Retry-After allow all 
request_header_access Title allow all 
request_header_access Connection allow all 
request_header_access Proxy-Connection allow all 
request_header_access User-Agent allow all 
request_header_access Cookie allow all 
request_header_access All deny all
reply_header_access Allow allow all 
reply_header_access Authorization allow all 
reply_header_access WWW-Authenticate allow all 
reply_header_access Proxy-Authorization allow all 
reply_header_access Proxy-Authenticate allow all 
reply_header_access Cache-Control allow all 
reply_header_access Content-Encoding allow all 
reply_header_access Content-Length allow all 
reply_header_access Content-Type allow all 
reply_header_access Date allow all 
reply_header_access Expires allow all 
reply_header_access Host allow all 
reply_header_access If-Modified-Since allow all 
reply_header_access Last-Modified allow all 
reply_header_access Location allow all 
reply_header_access Pragma allow all 
reply_header_access Accept allow all 
reply_header_access Accept-Charset allow all 
reply_header_access Accept-Encoding allow all 
reply_header_access Accept-Language allow all 
reply_header_access Content-Language allow all 
reply_header_access Mime-Version allow all 
reply_header_access Retry-After allow all 
reply_header_access Title allow all 
reply_header_access Connection allow all 
reply_header_access Proxy-Connection allow all 
reply_header_access User-Agent allow all 
reply_header_access Cookie allow all 
reply_header_access All deny all
coredump_dir /var/spool/squid
dns_nameservers 8.8.8.8 8.8.4.4
refresh_pattern ^ftp: 1440 20% 10080
refresh_pattern ^gopher: 1440 0% 1440
refresh_pattern -i (/cgi-bin/|\?) 0 0% 0
refresh_pattern . 0 20% 4320
visible_hostname CyberVPN
mySquid

# Restarting Squid Proxy
echo -e "Restarting proxy server..."
systemctl restart squid

# Setting System Time
ln -fs /usr/share/zoneinfo/$MyVPS_Time /etc/localtime

# Setting Terminal Message
[[ `cat .profile` =~ ⚽CyberPanel ]] ||
cat << 'intro' >> .profile
clear
echo -e '
   
   ░██████╗░█████╗░
   ██╔════╝██╔══██╗
   ╚█████╗░██║░░╚═╝
   ░╚═══██╗██║░░██╗
   ██████╔╝╚█████╔╝
   ╚═════╝░░╚════╝░
 ██████╗░██████╗░░█████╗░
 ██╔══██╗██╔══██╗██╔══██╗
 ██████╔╝██████╔╝██║░░██║
 ██╔═══╝░██╔══██╗██║░░██║
 ██║░░░░░██║░░██║╚█████╔╝
 ╚═╝░░░░░╚═╝░░╚═╝░╚════╝░
' && echo "
       Welcome to ⚽CyberPanel
"
intro

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
net.ipv4.tcp_congestion_control=bbr
net.core.wmem_default=262144
net.core.wmem_max=4194304
net.core.rmem_default=262144
net.core.rmem_max=4194304
net.core.netdev_budget=600
net.core.default_qdisc=fq
net.ipv6.conf.all.accept_ra=2
sysctl
sysctl --system

# Startup Script
cat << cyber > /etc/systemd/system/cyber.service
[Unit]
Description=Tsholo Startup Script
Wants=network.target
After=network.target
[Service]
Type=oneshot
ExecStart=/bin/bash /etc/cyber/startup.sh
RemainAfterExit=yes
[Install]
WantedBy=network.target
cyber

chmod +x /etc/cyber/startup.sh
systemctl daemon-reload
systemctl enable tsholo
systemctl start tsholo

# System OpenVPN Websocket Python
wget -O /etc/systemd/system/ws.service https://raw.githubusercontent.com/tjay13/TsholoVPN/master/Tools/Websocket/ws.service &> /dev/null
wget -O /etc/systemd/system/wsssh.service https://raw.githubusercontent.com/tjay13/TsholoVPN/master/Tools/Websocket/wsssh.service &> /dev/null

wget -O /usr/local/bin/ws-openvpn https://raw.githubusercontent.com/tjay13/TsholoVPN/master/Tools/Websocket/ws-openvpn &> /dev/null
wget -O /usr/local/bin/ws-ssh https://raw.githubusercontent.com/tjay13/TsholoVPN/master/Tools/Websocket/ws-ssh &> /dev/null

# Set Permission
chmod +x /usr/local/bin/ws-openvpn
chmod +x /usr/local/bin/ws-ssh

clear
cd
echo " "
echo " "
echo "WEBSOCKET SUCCESSFULLY INSTALLED!"

systemctl enable ws.service
systemctl start ws.service
systemctl restart ws.service

systemctl enable wsssh.service
systemctl start wsssh.service
systemctl restart wsssh.service

# Setup WebMin
echo "deb http://download.webmin.com/download/repository sarge contrib" > /etc/apt/sources.list.d/webmin.list
wget http://www.webmin.com/jcameron-key.asc -qO- | apt-key add -
$APT update
$APT install webmin
sed -i "s/ssl=1/ssl=0/g" /etc/webmin/miniserv.conf

systemctl restart webmin

# Setup Up Nginx
cat << myNginxC > /etc/nginx/conf.d/wago-config.conf
server {
 listen 0.0.0.0:$Nginx_Port;
 server_name localhost;
 root /var/www/openvpn;
 index index.html;
}
myNginxC
rm -rf /etc/nginx/sites-*/*
rm -rf /var/www/openvpn
mkdir -p /var/www/openvpn
echo "CyberSc Services" > /var/www/openvpn/index.html

# OpenVPN Cert
ovpnDir='/etc/openvpn'
cert="<ca>
$(cat $ovpnDir/ca.crt)
</ca>"

# Setup Menu
cd /usr/local/sbin/
cd /usr/local/sbin/
rm -rf {accounts,base-ports,base-ports-wc,base-script,bench-network,clearcache,connections,create,create_random,create_trial,delete_expired,diagnose,edit_dropbear,edit_openssh,edit_openvpn,edit_ports,edit_squid3,edit_stunnel4,locked_list,menu,options,ram,reboot_sys,reboot_sys_auto,restart_services,server,set_multilogin_autokill,set_multilogin_autokill_lib,show_ports,speedtest,user_delete,user_details,user_details_lib,user_extend,user_list,user_lock,user_unlock}
wget -q 'https://raw.githubusercontent.com/tjay13/AutoScriptDebian9/main/Tools/premiummenu.zip'
unzip -qq premiummenu.zip
rm -f premiummenu.zip
chmod +x ./*
dos2unix ./* &> /dev/null
sed -i 's|/etc/squid/squid.conf|g;s|http_port|listen-address|g' ./*

# Setup BadVPN
if [[ ! `ps -A | grep badvpn` ]]; then
if [[ ! `type -P docker` ]]; then
curl -fsSL https://download.docker.com/linux/$ID/gpg | apt-key add - 
add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/$ID $(lsb_release -cs) stable"
apt update
apt-cache policy docker-ce
apt install docker-ce -y
apt clean; fi

export sqx=n
[ `type -P dcomp` ] || wget "https://github.com/docker/compose/releases/download/1.24.0/docker-compose-$(uname -s)-$(uname -m)" -qO /sbin/dcomp
chmod +x /sbin/dcomp || return

wget -qO- https://github.com/X-DCB/Unix/raw/master/badvpn.yaml | dcomp -f - up -d; fi

# Create OpenVPN Paths
mkdir /var/www/html/status
chmod -R 777 /var/www/html/status

# Creating TCP OpenVPN Config
cat << TeeJay01 >/etc/openvpn/server.conf
mode server 
tls-server 
port 465
proto tcp4 
dev tun 
cipher none
auth none
tun-mtu-extra 32 
tun-mtu 1400 
mssfix 1360
tcp-queue-limit 128
txqueuelen 2000
tcp-nodelay
sndbuf 393216
rcvbuf 393216
push "sndbuf 393216"
push "rcvbuf 393216"
ca /etc/openvpn/easy-rsa/ca.crt
cert /etc/openvpn/easy-rsa/CyberVPN.crt
key /etc/openvpn/easy-rsa/CyberVPN.key
dh /etc/openvpn/easy-rsa/dh2048.pem
script-security 2
ifconfig-pool-persist ipp.txt
client-cert-not-required 
username-as-common-name 
auth-user-pass-verify "/etc/openvpn/script/auth_vpn.sh" via-file # 
tmp-dir "/etc/openvpn/" # 
server 10.200.0.0 255.255.0.0
push "redirect-gateway def1" 
push "dhcp-option DNS 8.8.8.8"
push "dhcp-option DNS 8.8.4.4"
keepalive 5 30
persist-key 
persist-tun
verb 3 
status /var/www/html/status/tcp.txt 1
TeeJay01

# Install Haproxy
apt-get -y install haproxy
cat > /etc/haproxy/haproxy.cfg <<-END
frontend http-in
        # listen 80 port
        bind *:444
        # set default backend
        default_backend    backend_servers
        # send X-Forwarded-For header
        option             forwardfor
# define backend
backend backend_servers
        # balance with roundrobin
        balance            roundrobin
        # define backend servers
        server             node01 127.0.0.1:1080 check
        server             node02 127.0.0.1:442 check
END

systemctl restart haproxy
systemctl enable haproxy

# Fixing Multilogin Script
cat <<'Multilogin' >/usr/local/sbin/set_multilogin_autokill_lib
#!/bin/bash
clear
MAX=1
if [ -e "/var/log/auth.log" ]; then
        OS=1;
        LOG="/var/log/auth.log";
fi
if [ -e "/var/log/secure" ]; then
        OS=2;
        LOG="/var/log/secure";
fi
if [ $OS -eq 1 ]; then
    service ssh restart > /dev/null 2>&1;
fi
if [ $OS -eq 2 ]; then
    service sshd restart > /dev/null 2>&1;
fi
    service dropbear restart > /dev/null 2>&1;
                
if [[ ${1+x} ]]; then
        MAX=$1;
fi
        cat /etc/passwd | grep "/home/" | cut -d":" -f1 > /root/user.txt
        username1=( `cat "/root/user.txt" `);
        i="0";
        for user in "${username1[@]}"
            do
                username[$i]=`echo $user | sed 's/'\''//g'`;
                jumlah[$i]=0;
                i=$i+1;
            done
        cat $LOG | grep -i dropbear | grep -i "Password auth succeeded" > /tmp/log-db.txt
        proc=( `ps aux | grep -i dropbear | awk '{print $2}'`);
        for PID in "${proc[@]}"
            do
                cat /tmp/log-db.txt | grep "dropbear\[$PID\]" > /tmp/log-db-pid.txt
                NUM=`cat /tmp/log-db-pid.txt | wc -l`;
                USER=`cat /tmp/log-db-pid.txt | awk '{print $10}' | sed 's/'\''//g'`;
                IP=`cat /tmp/log-db-pid.txt | awk '{print $12}'`;
                if [ $NUM -eq 1 ]; then
                        i=0;
                        for user1 in "${username[@]}"
                            do
                                if [ "$USER" == "$user1" ]; then
                                        jumlah[$i]=`expr ${jumlah[$i]} + 1`;
                                        pid[$i]="${pid[$i]} $PID"
                                fi
                                i=$i+1;
                            done
                fi
            done
        cat $LOG | grep -i sshd | grep -i "Accepted password for" > /tmp/log-db.txt
        data=( `ps aux | grep "\[priv\]" | sort -k 72 | awk '{print $2}'`);
        for PID in "${data[@]}"
            do
                cat /tmp/log-db.txt | grep "sshd\[$PID\]" > /tmp/log-db-pid.txt;
                NUM=`cat /tmp/log-db-pid.txt | wc -l`;
                USER=`cat /tmp/log-db-pid.txt | awk '{print $9}'`;
                IP=`cat /tmp/log-db-pid.txt | awk '{print $11}'`;
                if [ $NUM -eq 1 ]; then
                        i=0;
                        for user1 in "${username[@]}"
                            do
                                if [ "$USER" == "$user1" ]; then
                                        jumlah[$i]=`expr ${jumlah[$i]} + 1`;
                                        pid[$i]="${pid[$i]} $PID"
                                fi
                                i=$i+1;
                            done
                fi
        done
        j="0";
        for i in ${!username[*]}
            do
                if [ ${jumlah[$i]} -gt $MAX ]; then
                        date=`date +"%Y-%m-%d %X"`;
                        echo "$date - ${username[$i]} - ${jumlah[$i]}";
                        echo "$date - ${username[$i]} - ${jumlah[$i]}" >> /root/log-limit.txt;
                        kill ${pid[$i]};
                        pid[$i]="";
                        j=`expr $j + 1`;
                fi
            done
        if [ $j -gt 0 ]; then
                if [ $OS -eq 1 ]; then
                        service ssh restart > /dev/null 2>&1;
                fi
                if [ $OS -eq 2 ]; then
                        service sshd restart > /dev/null 2>&1;
                fi
                service dropbear restart > /dev/null 2>&1;
                j=0;
        fi
Multilogin

systemctl enable openvpn@server
systemctl start openvpn@server

# Setup Apache
sed -i "s|Listen 80|Listen $Apache_Port|g" /etc/apache2/ports.conf
service apache2 restart
a2enmod proxy_fcgi setenvif
a2enconf php$phpv-fpm
systemctl reload apache2 #activate

# Set Stat Permissions
chmod 777 /var/www/html/status/tcp.txt

apt-get -y install expect lsb-release apt-transport-https ca-certificates lsb-release libdbi-perl libecap3

clear
echo " "
echo " "
echo "SSH PHP SUCCESSFULLY INSTALLED!"

# Cloudflare Domain
echo "$Cloudflare_Domain" >> /root/domain

# Setup Cron
cat << cron > /etc/cron.d/$Filename_alias
* * * * * root php -q /etc/$Filename_alias.cron.php
* * * * * root bash /etc/openvpn/active.sh
* * * * * root bash /etc/openvpn/inactive.sh
cron
echo -e "0 4 * * * root reboot" > /etc/cron.d/b_reboot_job
echo -e "* * * * *  root /usr/local/sbin/set_multilogin_autokill_lib 1" >> "/etc/cron.d/set_multilogin_autokill_lib"
systemctl restart cron
systemctl enable cron

# Script Info
clear

cat << logs | tee -a ~/log-install.txt
INSTALLATION HAS BEEN COMPLETED!!
============================-AUTOSCRIPT CYBER-C-============================
---------------------------------------------------------------------------
   >>> Service & Port
   - OpenSSH                 : $SSH_Port1, $SSH_Port2 
   - OpenVPN                 : TCP $OpenVPN_TCP_Port UDP $OpenVPN_UDP_Port
   - Stunnel/SSL             : $Stunnel_Port1, $Stunnel_Port2, $Stunnel_Port3
   - Dropbear                : $Dropbear_Port1, $Dropbear_Port2
   - Squid Proxy             : $Squid_Port1, $Squid_Port2 , $Squid_Port3
   - Badvpn                  : 7300
   - Nginx                   : $Nginx_Port
   - Apache                  : $Apache_Port
   - Socks                   : $WsPort
   - V2RAY Vmess TLS         : $V2ray_Port1
   - V2RAY Vmess None TLS    : $V2ray_Port2
   - V2RAY Vless TLS         : $V2ray_Port3
   - V2RAY Vless None TLS    : $V2ray_Port4
   >>> Server Information & Features
   - Timezone                : Asia/Kuala_Lumpur (UMT +8.00)
   - Fail2Ban                : [ON]
   - IPtables                : [ON]
   - Auto-Reboot             : [ON]
   - IPv6                    : [OFF]
   - Webmin Login Page       : http://$IPADDR:10000/
   - OpenVPN Monitor         : http://$IPADDR:$Monitor_Port/
---------------------------------------------------------------------------
===========================================================================
logs

# Clearing Logs
rm -rf /root/.bash_history && history -c && echo '' > /var/log/syslog
rm -f *.sh

cd
exit 0
