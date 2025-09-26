#!/bin/bash

# X-UI Panel Installation Script
# Created by ThuYaAungZaw

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
blue='\033[0;34m'
purple='\033[0;35m'
cyan='\033[0;36m'
white='\033[0;37m'
reset='\033[0m'

# Root check
[[ $EUID -ne 0 ]] && echo -e "${red}Error: This script must be run as root!${reset}" && exit 1

# Check OS
if [[ -f /etc/redhat-release ]]; then
    release="centos"
elif cat /etc/issue | grep -q -E -i "debian"; then
    release="debian"
elif cat /etc/issue | grep -q -E -i "ubuntu"; then
    release="ubuntu"
elif cat /etc/issue | grep -q -E -i "centos|red hat|redhat"; then
    release="centos"
elif cat /proc/version | grep -q -E -i "debian"; then
    release="debian"
elif cat /proc/version | grep -q -E -i "ubuntu"; then
    release="ubuntu"
elif cat /proc/version | grep -q -E -i "centos|red hat|redhat"; then
    release="centos"
else
    echo -e "${red}Unsupported OS, script exit!${reset}"
    exit 1
fi

# Global variables
xui_dir="/usr/local/x-ui"
xui_service="/etc/systemd/system/x-ui.service"
xui_ssl_dir="/usr/local/x-ui/ssl"
xui_cert_file="/usr/local/x-ui/ssl/fullchain.crt"
xui_key_file="/usr/local/x-ui/ssl/private.key"

# Install base tools
install_base() {
    echo -e "${green}Installing necessary tools...${reset}"
    if [[ ${release} == "centos" ]]; then
        yum update -y
        yum install -y wget curl sudo tar openssl socat
    else
        apt-get update -y
        apt-get install -y wget curl sudo tar openssl socat
    fi
}

# Install x-ui
install_xui() {
    echo -e "${green}Installing X-UI Panel...${reset}"
    cd /usr/local/
    wget -O x-ui-linux-amd64.tar.gz https://github.com/FranzKafkaYu/x-ui/releases/latest/download/x-ui-linux-amd64.tar.gz
    tar zxvf x-ui-linux-amd64.tar.gz
    rm -f x-ui-linux-amd64.tar.gz
    cd x-ui
    chmod +x x-ui
    
    # Create service file
    cat > $xui_service << EOF
[Unit]
Description=x-ui service
After=network.target

[Service]
Type=simple
WorkingDirectory=/usr/local/x-ui
ExecStart=/usr/local/x-ui/x-ui
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable x-ui
}

# Generate SSL certificate
generate_ssl() {
    echo -e "${green}Generating SSL certificate...${reset}"
    mkdir -p $xui_ssl_dir
    openssl genrsa -out $xui_key_file 2048
    openssl req -new -x509 -days 3650 -key $xui_key_file -out $xui_cert_file -subj "/C=US/ST=State/L=City/O=Organization/OU=Unit/CN=x-ui-panel"
}

# Configure firewall
configure_firewall() {
    echo -e "${green}Configuring firewall...${reset}"
    if command -v ufw >/dev/null 2>&1; then
        ufw allow 54321/tcp
        ufw reload
        echo -e "${green}UFW firewall configured${reset}"
    elif command -v firewall-cmd >/dev/null 2>&1; then
        firewall-cmd --permanent --add-port=54321/tcp
        firewall-cmd --reload
        echo -e "${green}FirewallD configured${reset}"
    elif command -v iptables >/dev/null 2>&1; then
        iptables -I INPUT -p tcp --dport 54321 -j ACCEPT
        iptables-save >/etc/iptables/rules.v4 2>/dev/null || iptables-save >/etc/sysconfig/iptables 2>/dev/null
        echo -e "${green}iptables configured${reset}"
    else
        echo -e "${yellow}No firewall tool found, please manually open port 54321${reset}"
    fi
}

# Start x-ui service
start_service() {
    echo -e "${green}Starting X-UI service...${reset}"
    systemctl start x-ui
    sleep 3
    
    if systemctl is-active --quiet x-ui; then
        echo -e "${green}X-UI service started successfully${reset}"
    else
        echo -e "${red}X-UI service failed to start${reset}"
        systemctl status x-ui
    fi
}

# Display information
display_info() {
    echo -e "${cyan}"
    echo "================================================"
    echo "          X-UI Panel Installation Complete"
    echo "           Modified by ThuYaAungZaw"
    echo "================================================"
    echo ""
    echo "Panel Access Information:"
    echo "URL: https://your_server_ip:54321"
    echo "Default username: admin"
    echo "Default password: admin"
    echo ""
    echo "Important: Please change the default password after first login!"
    echo ""
    echo "Management Commands:"
    echo "Start: systemctl start x-ui"
    echo "Stop: systemctl stop x-ui"
    echo "Restart: systemctl restart x-ui"
    echo "Status: systemctl status x-ui"
    echo "================================================"
    echo -e "${reset}"
}

# Main installation function
main() {
    echo -e "${blue}X-UI Panel Installation Script${reset}"
    echo -e "${blue}Modified by ThuYaAungZaw${reset}"
    echo ""
    
    install_base
    install_xui
    generate_ssl
    configure_firewall
    start_service
    display_info
}

# Run main function
main
