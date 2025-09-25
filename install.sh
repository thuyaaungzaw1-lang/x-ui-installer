#!/bin/bash

# X-UI AUTO INSTALLER By ThuYaAungZaw
# Original script by yonggekkk, modified for English and customized for ThuYaAungZaw

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

# Get system information
arch=$(arch)

if [[ $arch == "x86_64" || $arch == "x64" || $arch == "amd64" ]]; then
    arch="amd64"
elif [[ $arch == "aarch64" || $arch == "arm64" ]]; then
    arch="arm64"
else
    arch="amd64"
    echo -e "${red}Unsupported architecture, using default: amd64${plain}"
fi

echo -e "${green}Architecture: ${arch}${plain}"

# Initialize the installation
install_x-ui() {
    systemctl stop x-ui
    cd /usr/local/

    if [ -d "/usr/local/x-ui/" ]; then
        rm -rf /usr/local/x-ui/
    fi

    last_version=$(curl -Ls "https://api.github.com/repos/yonggekkk/x-ui-yg/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
    if [ -z "$last_version" ]; then
        echo -e "${red}Failed to get x-ui version, maybe due to GitHub API limitations, please try again later${plain}"
        exit 1
    fi

    echo -e "x-ui version: ${last_version}, starting installation"
    wget -N --no-check-certificate -O /usr/local/x-ui-linux-${arch}.tar.gz "https://github.com/yonggekkk/x-ui-yg/releases/download/${last_version}/x-ui-linux-${arch}.tar.gz"

    if [[ $? -ne 0 ]]; then
        echo -e "${red}Failed to download x-ui, please check if the version exists${plain}"
        exit 1
    fi

    tar zxvf x-ui-linux-${arch}.tar.gz
    rm -f x-ui-linux-${arch}.tar.gz
    mv x-ui /usr/local/
    cd /usr/local/x-ui
    chmod +x x-ui bin/xray-linux-${arch}

    # Create config file if it doesn't exist
    if [ ! -f /etc/x-ui/x-ui.db ]; then
        mkdir -p /etc/x-ui/
        cp x-ui.db /etc/x-ui/
    fi

    # Add x-ui to system services
    cat > /etc/systemd/system/x-ui.service << EOF
[Unit]
Description=x-ui Service
After=network.target

[Service]
Type=simple
WorkingDirectory=/usr/local/x-ui/
ExecStart=/usr/local/x-ui/x-ui
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable x-ui
    systemctl start x-ui

    echo -e "${green}x-ui ${last_version} installation completed${plain}"
    echo -e "${yellow}Default panel port: 54321${plain}"
    echo -e "${yellow}Default username: admin${plain}"
    echo -e "${yellow}Default password: admin${plain}"
    echo -e "${yellow}Please access via: http://your_server_ip:54321${plain}"
    echo -e "${yellow}After login, please change the default username and password immediately${plain}"
}

# Update x-ui
update_x-ui() {
    systemctl stop x-ui
    cd /usr/local/

    last_version=$(curl -Ls "https://api.github.com/repos/yonggekkk/x-ui-yg/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
    if [ -z "$last_version" ]; then
        echo -e "${red}Failed to get x-ui version, maybe due to GitHub API limitations, please try again later${plain}"
        exit 1
    fi

    echo -e "x-ui version: ${last_version}, starting update"
    wget -N --no-check-certificate -O /usr/local/x-ui-linux-${arch}.tar.gz "https://github.com/yonggekkk/x-ui-yg/releases/download/${last_version}/x-ui-linux-${arch}.tar.gz"

    if [[ $? -ne 0 ]]; then
        echo -e "${red}Failed to download x-ui, please check if the version exists${plain}"
        exit 1
    fi

    tar zxvf x-ui-linux-${arch}.tar.gz
    rm -f x-ui-linux-${arch}.tar.gz
    systemctl start x-ui

    echo -e "${green}x-ui updated to ${last_version} successfully${plain}"
}

# Uninstall x-ui
uninstall_x-ui() {
    read -p "Are you sure you want to uninstall x-ui? (y/n): " answer
    if [ "$answer" = "y" ] || [ "$answer" = "Y" ]; then
        systemctl stop x-ui
        systemctl disable x-ui
        rm -rf /usr/local/x-ui/
        rm -f /etc/systemd/system/x-ui.service
        systemctl daemon-reload
        echo -e "${green}x-ui uninstalled successfully${plain}"
    else
        echo -e "${yellow}Uninstall cancelled${plain}"
    fi
}

# Main menu
show_menu() {
    echo -e "
  ${green}X-UI AUTO INSTALLER By ThuYaAungZaw${plain}
  ${green}1.${plain} Install x-ui
  ${green}2.${plain} Update x-ui
  ${green}3.${plain} Uninstall x-ui
  ${green}4.${plain} Exit
 "
    read -p "Please select an option (1-4): " option
    case $option in
        1) install_x-ui ;;
        2) update_x-ui ;;
        3) uninstall_x-ui ;;
        4) exit 0 ;;
        *) echo -e "${red}Invalid option, please select 1-4${plain}" && show_menu ;;
    esac
}

# Check if user is root
if [[ $EUID -ne 0 ]]; then
    echo -e "${red}Error: This script must be run as root${plain}"
    exit 1
fi

# Start the script
show_menu
