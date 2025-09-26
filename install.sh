#!/bin/bash

# X-UI AUTO INSTALLER By ThuYaAungZaw

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
blue='\033[0;34m'
cyan='\033[0;36m' 
plain='\033[0m'

# Default credentials
XUI_USERNAME="admin"
XUI_PASSWORD="admin"
XUI_PORT="54321"

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

# Safe service control functions
safe_stop_service() {
    local service_name=$1
    if systemctl is-active "$service_name" &>/dev/null; then
        systemctl stop "$service_name"
        echo -e "${green}Stopped $service_name${plain}"
    else
        echo -e "${yellow}$service_name is not running or not found${plain}"
    fi
}

safe_disable_service() {
    local service_name=$1
    if systemctl is-enabled "$service_name" &>/dev/null; then
        systemctl disable "$service_name"
        echo -e "${green}Disabled $service_name${plain}"
    else
        echo -e "${yellow}$service_name is not enabled or not found${plain}"
    fi
}

safe_remove_file() {
    local file_path=$1
    if [ -f "$file_path" ] || [ -d "$file_path" ]; then
        rm -rf "$file_path"
        echo -e "${green}Removed: $file_path${plain}"
    else
        echo -e "${yellow}Not found: $file_path${plain}"
    fi
}

# Completely remove old x-ui installations
cleanup_old_installation() {
    echo -e "${yellow}Cleaning up old x-ui installations...${plain}"
    
    # Stop all possible x-ui related services safely
    echo -e "${blue}Stopping services...${plain}"
    safe_stop_service "x-ui"
    safe_stop_service "xui"
    safe_stop_service "xray"
    
    # Kill any remaining processes
    echo -e "${blue}Killing processes...${plain}"
    pkill -f x-ui 2>/dev/null && echo -e "${green}Killed x-ui processes${plain}" || echo -e "${yellow}No x-ui processes found${plain}"
    pkill -f xray 2>/dev/null && echo -e "${green}Killed xray processes${plain}" || echo -e "${yellow}No xray processes found${plain}"
    
    # Disable services safely
    echo -e "${blue}Disabling services...${plain}"
    safe_disable_service "x-ui"
    safe_disable_service "xui"
    safe_disable_service "xray"
    
    # Remove all possible x-ui directories
    echo -e "${blue}Removing directories...${plain}"
    safe_remove_file "/usr/local/x-ui/"
    safe_remove_file "/usr/local/xui/"
    safe_remove_file "/etc/x-ui/"
    safe_remove_file "/etc/xui/"
    safe_remove_file "/root/x-ui/"
    safe_remove_file "/home/x-ui/"
    
    # Remove all possible service files
    echo -e "${blue}Removing service files...${plain}"
    safe_remove_file "/etc/systemd/system/x-ui.service"
    safe_remove_file "/etc/systemd/system/xui.service"
    safe_remove_file "/usr/lib/systemd/system/x-ui.service"
    safe_remove_file "/usr/lib/systemd/system/xui.service"
    
    # Remove all possible binary files
    echo -e "${blue}Removing binary files...${plain}"
    safe_remove_file "/usr/local/bin/x-ui"
    safe_remove_file "/usr/bin/x-ui"
    safe_remove_file "/usr/local/bin/xray"
    safe_remove_file "/usr/bin/xray"
    
    # Remove all possible config files
    echo -e "${blue}Removing config files...${plain}"
    safe_remove_file "/etc/x-ui.db"
    safe_remove_file "/etc/xui.db"
    safe_remove_file "/root/x-ui.db"
    safe_remove_file "/home/x-ui.db"
    
    # Remove all possible log files
    echo -e "${blue}Cleaning log files...${plain}"
    safe_remove_file "/var/log/x-ui.log"
    safe_remove_file "/var/log/xui.log"
    safe_remove_file "/var/log/xray.log"
    
    # Remove all possible temporary files
    echo -e "${blue}Cleaning temporary files...${plain}"
    safe_remove_file "/tmp/x-ui*"
    safe_remove_file "/tmp/xray*"
    
    # Reload systemd
    echo -e "${blue}Reloading systemd...${plain}"
    systemctl daemon-reload 2>/dev/null && echo -e "${green}Systemd reloaded${plain}" || echo -e "${yellow}Systemd reload failed${plain}"
    systemctl reset-failed 2>/dev/null && echo -e "${green}Reset failed services${plain}" || echo -e "${yellow}Reset failed${plain}"
    
    echo -e "${green}Old x-ui installation cleanup completed!${plain}"
}

# Check if x-ui is already installed
check_existing_installation() {
    if [ -f /usr/local/x-ui/x-ui ] || [ -f /usr/local/bin/x-ui ] || [ -f /usr/bin/x-ui ] || \
       systemctl is-active x-ui &>/dev/null || systemctl is-active xui &>/dev/null || \
       pgrep -f x-ui &>/dev/null; then
        echo -e "${yellow}Existing x-ui installation detected${plain}"
        return 0  # Existing installation found
    else
        echo -e "${green}No existing x-ui installation found${plain}"
        return 1  # No existing installation
    fi
}

# Set custom credentials
set_credentials() {
    echo -e "${yellow}Set custom credentials for x-ui panel${plain}"
    echo -e "${green}Leave blank to use default values${plain}"
    
    read -p "Enter username [default: admin]: " custom_user
    read -p "Enter password [default: admin]: " custom_pass
    read -p "Enter port [default: 54321]: " custom_port
    
    if [ -n "$custom_user" ]; then
        XUI_USERNAME="$custom_user"
    fi
    
    if [ -n "$custom_pass" ]; then
        XUI_PASSWORD="$custom_pass"
    fi
    
    if [ -n "$custom_port" ]; then
        XUI_PORT="$custom_port"
    fi
    
    echo -e "${green}Credentials set:${plain}"
    echo -e "Username: ${cyan}$XUI_USERNAME${plain}"
    echo -e "Password: ${cyan}$XUI_PASSWORD${plain}"
    echo -e "Port: ${cyan}$XUI_PORT${plain}"
    
    read -p "Continue with these settings? (y/n): " confirm
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        set_credentials
    fi
}

# Install x-ui
install_xui() {
    # Check for existing installation
    if check_existing_installation; then
        echo -e "${red}Existing x-ui installation detected!${plain}"
        read -p "Do you want to completely remove the old installation? (y/n): " remove_old
        if [ "$remove_old" = "y" ] || [ "$remove_old" = "Y" ]; then
            cleanup_old_installation
            echo -e "${green}Proceeding with fresh installation...${plain}"
        else
            echo -e "${yellow}Installation cancelled.${plain}"
            read -p "Press Enter to continue..."
            return
        fi
    fi
    
    echo -e "${green}Starting x-ui installation...${plain}"
    
    # Ask for custom credentials
    set_credentials
    
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

    # Create config directory
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

    # Wait for service to start
    sleep 5
    
    # Change to custom credentials
    if [ "$XUI_USERNAME" != "admin" ] || [ "$XUI_PASSWORD" != "admin" ] || [ "$XUI_PORT" != "54321" ]; then
        echo -e "${yellow}Applying custom credentials...${plain}"
        safe_stop_service "x-ui"
        /usr/local/x-ui/x-ui setting -username "$XUI_USERNAME" -password "$XUI_PASSWORD"
        /usr/local/x-ui/x-ui setting -port "$XUI_PORT"
        systemctl start x-ui
        sleep 2
    fi

    echo -e "${green}Installation completed successfully!${plain}"
    echo -e "${yellow}Panel URL: http://${ipv4}:${XUI_PORT}${plain}"
    echo -e "${yellow}Username: ${cyan}$XUI_USERNAME${plain}"
    echo -e "${yellow}Password: ${cyan}$XUI_PASSWORD${plain}"
    echo -e "${red}Please keep these credentials safe!${plain}"
    
    read -p "Press Enter to continue..."
}

# Complete uninstall x-ui
uninstall_xui() {
    echo -e "${red}=== COMPLETE X-UI UNINSTALL ===${plain}"
    echo -e "${yellow}This will remove ALL x-ui related files and configurations${plain}"
    read -p "Are you absolutely sure? (type 'YES' to confirm): " confirm
    
    if [ "$confirm" = "YES" ]; then
        cleanup_old_installation
        echo -e "${green}x-ui completely uninstalled!${plain}"
    else
        echo -e "${yellow}Uninstall cancelled.${plain}"
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
4. Check service status
5. Back to main menu
"
    read -p "Select option: " choice
    case $choice in
        1) systemctl start x-ui && echo -e "${green}x-ui started${plain}" || echo -e "${red}Failed to start x-ui${plain}" ;;
        2) safe_stop_service "x-ui" ;;
        3) systemctl restart x-ui && echo -e "${green}x-ui restarted${plain}" || echo -e "${red}Failed to restart x-ui${plain}" ;;
        4) systemctl status x-ui 2>/dev/null || echo -e "${yellow}x-ui service not found${plain}" ;;
        5) return ;;
        *) echo -e "${red}Invalid option${plain}" ;;
    esac
    read -p "Press Enter to continue..."
}

# Show current credentials
show_credentials() {
    echo -e "
${blue}=== Current x-ui Credentials ===${plain}
Username: ${cyan}$XUI_USERNAME${plain}
Password: ${cyan}$XUI_PASSWORD${plain}
Port: ${cyan}$XUI_PORT${plain}
Panel URL: http://${ipv4}:${XUI_PORT}
${plain}"
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

${blue}=== Panel Access ===${plain}
URL: http://${ipv4}:${XUI_PORT}
Username: $XUI_USERNAME
Password: $XUI_PASSWORD
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

${yellow}1.${plain} Install x-ui (Auto-clean old installation)
${yellow}2.${plain} Complete uninstall x-ui (Remove everything)
${yellow}3.${plain} Manage x-ui service
${yellow}4.${plain} Cleanup old x-ui installations only
${yellow}5.${plain} Show current credentials
${yellow}6.${plain} Check system status
${yellow}7.${plain} Exit

${cyan}Current version: v4.0 - Error Safe Version${plain}
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
        echo -e "x-ui: $xui_status | Port: $XUI_PORT | User: $XUI_USERNAME"
        echo -e "${green}~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~${plain}"
        
        read -p "Please select option [1-7]: " choice
        
        case $choice in
            1) install_xui ;;
            2) uninstall_xui ;;
            3) manage_xui ;;
            4) cleanup_old_installation && read -p "Press Enter to continue..." ;;
            5) show_credentials && read -p "Press Enter to continue..." ;;
            6) show_status && read -p "Press Enter to continue..." ;;
            7) echo -e "${green}Goodbye!${plain}"; exit 0 ;;
            *) echo -e "${red}Invalid option!${plain}"; sleep 2 ;;
        esac
    done
}

# Start script
main
