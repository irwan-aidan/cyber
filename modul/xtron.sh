#include <stdio.h>
#include <stdlib.h>


FILE* config,* cer;
char uuid [40], sni [30] ;
int mode;

int main () {
Menu: UI ();
    system("clear");
    if (mode == 1) {
        install_xray();
        goto Menu;
    }
    else if (mode == 2) {
        system("systemctl stop xray");
        system("systemctl stop nginx");
        system("systemctl start xray");
        system("systemctl start nginx");
        printf( " Detecting the running status of xray and nginx, if the following output is not empty, it runs normally!\n " ) ;
        printf( " -------------- If the following output is not empty, xray runs normally ------------------\n " ) ;
        system("ss -lp | grep xray");
        printf( " \n-------------- If the following output is not empty, nginx is running normally------------------\n " ) ;
        system("ss -lp | grep nginx");
        printf("--------------------------------------------------------\n");
        goto Menu;
    }
    else if (mode == 3) {
        printf( " Vmess link:\n\n " ) ;
        system("bash /usr/local/etc/xray/code_gen.sh");
        printf("\n");
        goto Menu;
    }
    else if (mode == 4) {
        system("vi /usr/local/etc/xray/config.json");
        system("systemctl restart xray");
        system("systemctl restart nginx");
        printf( " Detecting the running status of xray and nginx, if the following output is not empty, it runs normally!\n " ) ;
        printf( " -------------- If the following output is not empty, xray runs normally ------------------\n " ) ;
        system("ss -lp | grep xray");
        printf( " \n-------------- If the following output is not empty, nginx is running normally------------------\n " ) ;
        system("ss -lp | grep nginx");
        printf("--------------------------------------------------------\n");
        goto Menu;
    }
    else if (mode == 5) {
        system("vi /etc/nginx/conf.d/default.conf");
        system("systemctl restart xray");
        system("systemctl restart nginx");
        printf( " Detecting the running status of xray and nginx, if the following output is not empty, it runs normally!\n " ) ;
        printf( " -------------- If the following output is not empty, xray runs normally ------------------\n " ) ;
        system("ss -lp | grep xray");
        printf( " \n-------------- If the following output is not empty, nginx is running normally------------------\n " ) ;
        system("ss -lp | grep nginx");
        printf("--------------------------------------------------------\n");
        goto Menu;
    }
    else if (mode == 6) {
        if (fopen("/root/1.pem", "r") == NULL || fopen("/root/2.pem", "r") == NULL) {
            printf( "It is detected that the certificate and private key files are not placed in the root directory in the prescribed manner, force exit!\n " ) ;
            exit(0);
        }
        printf( " Please enter the new domain name bound to this server ip: " ) ;
        scanf("%s", sni);
        config = fopen("/usr/local/etc/sni.conf", "w");
        fprintf(config, "%s", sni);
        fclose(config);
        config = fopen("/usr/local/etc/xray/uuid.conf", "r");
        fscanf(config, "%s", uuid);
        fclose(config);
        printf( " Copying SSL certificate and private key...\n " ) ;
        system("cp -rf /root/1.pem /usr/local/etc/xray/certificate.pem");
        system("cp -rf /root/2.pem /usr/local/etc/xray/private.pem");
        printf( " Configuring html webpage...\n " ) ;
        config = fopen("/etc/nginx/conf.d/default.conf", "w");
        fprintf(config, "server {\n");
        fprintf(config, "    server_name %s;\n", sni);
        fclose(config);
        system("curl https://cdn.jsdelivr.net/gh/HXHGTS/xray-websocket-tls-nginx/default.conf >> /etc/nginx/conf.d/default.conf");
        system("systemctl restart nginx");
        printf( " Detecting the running status of xray and nginx, if the following output is not empty, it runs normally!\n " ) ;
        printf( " -------------- If the following output is not empty, xray runs normally ------------------\n " ) ;
        system("ss -lp | grep xray");
        printf( " \n-------------- If the following output is not empty, nginx is running normally------------------\n " ) ;
        system("ss -lp | grep nginx");
        printf("--------------------------------------------------------\n");
        printf( " xray deployment completed!\n " ) ;
        printf( " Vmess link:\n\n " ) ;
        system("bash /usr/local/etc/xray/code_gen.sh");
        goto Menu;
    }
    else if (mode == 7) {
        printf( " Update xray main program...\n " ) ;
        system("systemctl stop xray");
        system("systemctl stop nginx");
        system("wget https://cdn.jsdelivr.net/gh/XTLS/Xray-install/install-release.sh -O install-release.sh");
        system("chmod +x install-release.sh");
        system("bash install-release.sh");
        system("systemctl start xray");
        system("systemctl start nginx");
        system("rm -rf install-release.sh");
        printf( " xray main program update complete!\n " ) ;
        printf( " Detecting the running status of xray and nginx, if the following output is not empty, it runs normally!\n " ) ;
        printf( " -------------- If the following output is not empty, xray runs normally ------------------\n " ) ;
        system("ss -lp | grep xray");
        printf( " \n-------------- If the following output is not empty, nginx is running normally------------------\n " ) ;
        system("ss -lp | grep nginx");
        printf("--------------------------------------------------------\n");
        goto Menu;
    }
    else if (mode == 8) {
        system("systemctl stop xray");
        system("systemctl stop nginx");
        goto Menu;
    }
    else {
        exit(0);
    }
    return 0;
}

int UI () {
    printf("-----------------------------------------------------------\n");
    printf( " ----------------------xray installation tool---------------------- -\n " ) ;
    printf("-----------------------------------------------------------\n");
    printf( " Before installation or need to update the SSL certificate, please name the certificate (*.cer/*.crt/*.pem) and private key (*.key/*.pem) respectively as 1.pem and 2.pem, Upload to the server/root directory\n " ) ;
    printf("-----------------------------------------------------------\n");
    printf( " ----------------------Current Kernel version---------------------- -\n " ) ;
    system("uname -sr");
    printf("-----------------------------------------------------------\n");
    printf( " 1. Install xray\n2. Run xray\n3. Display configuration\n4. Modify xray configuration\n5. Modify nginx configuration\n6. Update domain name and SSL certificate\n7. Update xray\n8. Close xray\n0. Exit\n " ) ;
    printf("-----------------------------------------------------------\n");
    printf( " Please enter: " ) ;
    scanf("%d", &mode);
    return 0;
}

int install_xray() {
    KernelUpdate(); 
    config = fopen("/usr/local/etc/sni.conf", "r");
    fscanf(config, "%s", sni);
    fclose(config);
    system("setenforce 0");
    system("apt-get install -y nginx dnsutils");
    printf( "The xray installation script is running...\n " ) ;
    system("wget https://cdn.jsdelivr.net/gh/XTLS/Xray-install/install-release.sh -O install-release.sh");
    system("chmod +x install-release.sh");
    system("bash install-release.sh");
    system("sleep 3");
    system("rm -rf install-release.sh");
    system("rm -rf TCPO.sh");
    printf( " Copying SSL certificate and private key...\n " ) ;
    system("cp -rf /root/1.pem /usr/local/etc/xray/certificate.pem");
    system("cp -rf /root/2.pem /usr/local/etc/xray/private.pem");
    printf( " Generating configuration file...\n " ) ;
    system("curl https://cdn.jsdelivr.net/gh/HXHGTS/xray-websocket-tls-nginx/config.json.1 > /usr/local/etc/xray/config.json");
    printf( " UUID is being generated...\n " ) ;
    system("xray uuid > /usr/local/etc/xray/uuid.conf");
    config = fopen("/usr/local/etc/xray/uuid.conf", "r");
    fscanf(config, "%s", uuid);
    fclose(config);
    config = fopen("/usr/local/etc/xray/config.json", "a");
    fprintf(config, "       \"id\": \"%s\"\n", uuid);
    fclose(config);
    system("curl https://cdn.jsdelivr.net/gh/HXHGTS/xray-websocket-tls-nginx/config.json.2 >> /usr/local/etc/xray/config.json");
    printf( " Configuring html webpage...\n " ) ;
    config = fopen("/etc/nginx/conf.d/default.conf", "w");
    fprintf(config, "server {\n");
    fprintf(config, "    server_name %s;\n",sni);
    fclose(config);
    system("curl https://cdn.jsdelivr.net/gh/HXHGTS/xray-websocket-tls-nginx/default.conf >> /etc/nginx/conf.d/default.conf");
    printf( " Starting xray and writing xray to boot entry...\n " ) ;
    system("systemctl enable xray");
    system("systemctl start xray");
    printf( " Starting nginx and writing nginx to boot entry...\n " ) ;
    system("echo [Service]> /etc/systemd/system/nginx.service.d/override.conf");
    system("echo ExecStartPost=/bin/sleep 0.1>> /etc/systemd/system/nginx.service.d/override.conf");
    system("semanage port -a -t http_port_t  -p tcp 2053");
    system("systemctl enable nginx");
    system("systemctl start nginx");
    system("setsebool -P httpd_can_network_connect 1");
    system("systemctl daemon-reload");
    system("systemctl restart nginx.service");
    printf( " Detecting the running status of xray and nginx, if the following output is not empty, it runs normally!\n " ) ;
    printf( " -------------- If the following output is not empty, xray runs normally ------------------\n " ) ;
    system("ss -lp | grep xray");
    printf( " \n-------------- If the following output is not empty, nginx is running normally------------------\n " ) ;
    system("ss -lp | grep nginx");
    printf("--------------------------------------------------------\n");
    printf( " xray deployment completed!\n " ) ;
    printf( " Vmess link:\n\n " ) ;
    system("bash /usr/local/etc/xray/code_gen.sh");
    return 0;
}

int KernelUpdate() {
    if ((fopen("KernelUpdate.sh", "r")) == NULL) {
        if (fopen("/root/1.pem", "r") == NULL || fopen("/root/2.pem", "r") == NULL) {
        printf( "It is detected that the certificate and private key files are not placed in the root directory in the prescribed manner, force exit!\n " ) ;
        exit(0);
    }
    printf( " Please enter the domain name that has been bound to this server ip: " ) ;
    scanf("%s", sni);
    config = fopen("/usr/local/etc/sni.conf", "w");
    fprintf(config, "%s", sni);
    fclose(config);
    system("curl -sSL https://cdn.jsdelivr.net/gh/HXHGTS/TCPOptimization/TCPO_debian.sh | sh");
    return 0;
}
