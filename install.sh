#!/bin/bash

# X-UI AUTO INSTALLER By ThuYaAungZaw

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
blue='\033[0;34m'
cyan='\033[0;36m'
plain='\033[0m'

# Get system information
get_system_info() {
    # OS info
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        os="$NAME $VERSION"
    else
        os=$(cat /etc/issue | head -n1 | awk '{print $1,$2,$3}')
    fi

    # Kernel
    kernel=$(uname -r)

    # Architecture
    arch=$(uname -m)
    if [[ $arch == "x86_64" ]]; then
        arch="amd64"
    elif [[ $arch == "aarch64" ]]; then
        arch="arm64"
    else
        arch="amd64"
    fi

    # Virtualization
    if systemd-detect-virt &>/dev/null; then
        virt=$(systemd-detect-virt)
    else
        virt="unknown"
    fi

    # BBR status
    if sysctl net.ipv4.tcp_congestion_control &>/dev/null; then
        bbr=$(sysctl net.ipv4.tcp_congestion_control | awk '{print $3}')
    else
        bbr="unknown"
    fi

    # IP addresses
    ipv4=$(curl -s4 ifconfig.me 2>/dev/null || echo "No IPv4")
    ipv6=$(curl -s6 ifconfig.me 2>/dev/null || echo "No IPv6")

    # Location
    location=$(curl -s ipinfo.io/city 2>/dev/null || echo "Unknown"), $(curl -s ipinfo.io/country 2>/dev/null || echo "Unknown")
}

# Check service status
check_services() {
    if systemctl is-active x-ui &>/dev/null; then
        xui_status="Running"
    else
        xui_status="Not running"
    fi

    if systemctl is-enabled x-ui &>/dev/null; then
        xui_autostart="Enabled"
    else
        xui_autostart="Disabled"
    fi

    if systemctl is-active xray &>/dev/null; then
        xray_status="Active"
    else
        xray_status="Inactive"
    fi
}

# Install x-ui
install_xui() {
    echo -e "${green}Starting x-ui installation...${plain}"
    
    # Stop existing service
    systemctl stop x-ui 2>/dev/null
    
    # Create directory
    cd /usr/local/
    if [ -d "/usr/local/x-ui/" ]; then
        rm -rf /usr/local/x-ui/
    fi

    echo -e "${green}Architecture: ${arch}${plain}"

    # Get latest version
    echo -e "${yellow}Fetching latest version...${plain}"
    last_version=$(curl -s "https://api.github.com/repos/yonggekkk/x-ui-yg/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
    
    if [ -z "$last_version" ]; then
        echo -e "${red}Failed to get latest version${plain}"
        return 1
    fi

    echo -e "${green}Latest version: ${last_version}${plain}"

    # Download
    echo -e "${yellow}Downloading x-ui...${plain}"
    wget -O /usr/local/x-ui-linux-${arch}.tar.gz "https://github.com/yonggekkk/x-ui-yg/releases/download/${last_version}/x-ui-linux-${arch}.tar.gz"

    if [ $? -ne 0 ]; then
        echo -e "${red}Download failed${plain}"
        return 1
    fi

    # Extract
    echo -e "${yellow}Extracting files...${plain}"
    tar zxvf x-ui-linux-${arch}.tar.gz
    rm -f x-ui-linux-${arch}.tar.gz
    
    if [ ! -d "x-ui" ]; then
        echo -e "${red}Extraction failed${plain}"
        return 1
    fi

    # Set permissions
    cd x-ui
    chmod +x x-ui bin/xray-linux-${arch}

    # Create config
    mkdir -p /etc/x-ui/
    if [ ! -f /etc/x-ui/x-ui.db ]; then
        cp x-ui.db /etc/x-ui/
    fi

    # Create service
    cat > /etc/systemd/system/x-ui.service << EOF
[Unit]
Description=x-ui Service
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

    # Start service
    systemctl daemon-reload
    systemctl enable x-ui
    systemctl start x-ui

    echo -e "${green}Installation completed successfully!${plain}"
    echo -e "${yellow}Panel URL: http://${ipv4}:54321${plain}"
    echo -e "${yellow}Username: admin${plain}"
    echo -e "${yellow}Password: admin${plain}"
    echo -e "${red}Please change default password after login!${plain}"
    
    read -p "Press Enter to continue..."
}

# Uninstall x-ui
uninstall_xui() {
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
    read -p "Press Enter to continue..."
}

# Start/Stop/Restart x-ui
manage_xui() {
    echo -e "
${green}Manage x-ui Service${plain}
1. Start x-ui
2. Stop x-ui  
3. Restart x-ui
4. Back to main menu
"
    read -p "Select option: " choice
    case $choice in
        1) systemctl start x-ui && echo -e "${green}x-ui started${plain}" ;;
        2) systemctl stop x-ui && echo -e "${yellow}x-ui stopped${plain}" ;;
        3) systemctl restart x-ui && echo -e "${green}x-ui restarted${plain}" ;;
        4) return ;;
        *) echo -e "${red}Invalid option${plain}" ;;
    esac
    read -p "Press Enter to continue..."
}

# Show status
show_status() {
    echo -e "
${blue}=== VPS Status ===${plain}
OS: $os   Kernel: $kernel
Processor: $arch   Virtualization: $virt
IPv4: $ipv4   IPv6: $ipv6
Location: $location
BBR Algorithm: $bbr

${blue}=== x-ui Status ===${plain}
x-ui Status: $xui_status
x-ui Auto-start: $xui_autostart  
xray Status: $xray_status
${plain}"
}

# Main menu
show_menu() {
    clear
    echo -e "
${green}~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~${plain}
${cyan}
 ████████╗██╗  ██╗██╗   ██╗██╗   ██╗ █████╗ 
 ╚══██╔══╝██║  ██║██║   ██║╚██╗ ██╔╝██╔══██╗
    ██║   ███████║██║   ██║ ╚████╔╝ ███████║
    ██║   ██╔══██║██║   ██║  ╚██╔╝  ██╔══██║
    ██║   ██║  ██║╚██████╔╝   ██║   ██║  ██║
    ╚═╝   ╚═╝  ╚═╝ ╚═════╝    ╚═╝   ╚═╝  ╚═╝
${plain}
${green}~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~${plain}
${blue}           X-UI AUTO INSTALLER By ThuYaAungZaw${plain}
${green}~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~${plain}

${yellow}1.${plain} Install x-ui
${yellow}2.${plain} Uninstall x-ui  
${yellow}3.${plain} Manage x-ui service (Start/Stop/Restart)
${yellow}4.${plain} Check system status
${yellow}5.${plain} Exit

${cyan}Current version: v1.0${plain}
${green}~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~${plain}
"
}

# Main function
main() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${red}This script must be run as root${plain}"
        exit 1
    fi

    while true; do
        get_system_info
        check_services
        show_menu
        
        echo -e "${blue}Current Status:${plain}"
        echo -e "x-ui: $xui_status | xray: $xray_status | IP: $ipv4"
        echo -e "${green}~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~${plain}"
        
        read -p "Please select option [1-5]: " choice
        
        case $choice in
            1) install_xui ;;
            2) uninstall_xui ;;
            3) manage_xui ;;
            4) show_status && read -p "Press Enter to continue..." ;;
            5) echo -e "${green}Goodbye!${plain}"; exit 0 ;;
            *) echo -e "${red}Invalid option!${plain}"; sleep 2 ;;
        esac
    done
}

# Start script
main
