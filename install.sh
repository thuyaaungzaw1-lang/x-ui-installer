#!/bin/bash

# X-UI Auto Installer with Beautiful UI
# Created by ThuYaAungZaw

# Colors for beautiful output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

# Print functions with emoji
info() { echo -e "${CYAN}🔹 [INFO]${NC} $1"; }
success() { echo -e "${GREEN}✅ [SUCCESS]${NC} $1"; }
warning() { echo -e "${YELLOW}⚠️ [WARNING]${NC} $1"; }
error() { echo -e "${RED}❌ [ERROR]${NC} $1"; }
step() { echo -e "${PURPLE}📥 [STEP]${NC} $1"; }

# Beautiful header
show_header() {
    echo -e "${BLUE}"
    echo "╔══════════════════════════════════════════╗"
    echo "║           X-UI AUTO INSTALLER            ║"
    echo "║               By ThuYaAungZaw            ║"
    echo "╚══════════════════════════════════════════╝"
    echo -e "${NC}"
}

# Get user credentials
get_user_credentials() {
    echo -e "${WHITE}"
    echo "🔐 Please set your X-UI panel credentials:"
    echo -e "${NC}"
    
    # Get username
    while true; do
        read -p "📝 Enter username: " USERNAME
        if [[ -n "$USERNAME" ]]; then
            break
        else
            error "Username cannot be empty!"
        fi
    done
    
    # Get password
    while true; do
        read -p "🔒 Enter password: " PASSWORD
        if [[ -n "$PASSWORD" ]]; then
            break
        else
            error "Password cannot be empty!"
        fi
    done
    
    # Get port
    while true; do
        read -p "🚪 Enter panel port [54321]: " PORT
        PORT=${PORT:-54321}
        if [[ "$PORT" =~ ^[0-9]+$ ]] && [ "$PORT" -ge 1 ] && [ "$PORT" -le 65535 ]; then
            break
        else
            error "Port must be a number between 1-65535!"
        fi
    done
    
    success "Credentials saved successfully!"
}

# Check root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root!"
        echo -e "${YELLOW}Please run: sudo su${NC}"
        exit 1
    fi
}

# Check OS
detect_os() {
    step "Detecting operating system..."
    if [[ -f /etc/redhat-release ]]; then
        OS="centos"
    elif grep -Eqi "debian" /etc/issue; then
        OS="debian"
    elif grep -Eqi "ubuntu" /etc/issue; then
        OS="ubuntu"
    elif grep -Eqi "centos|red hat|redhat" /etc/issue; then
        OS="centos"
    else
        error "Unsupported OS. Please use CentOS, Ubuntu or Debian."
        exit 1
    fi
    success "Detected OS: $OS"
}

# Install base packages
install_base() {
    step "Installing required packages..."
    if [[ "$OS" == "centos" ]]; then
        yum install -y wget tar curl
    else
        apt-get update
        apt-get install -y wget tar curl
    fi
    success "Packages installed successfully"
}

# Install x-ui
install_xui() {
    step "Downloading and installing X-UI..."
    
    cd /usr/local/

    # Remove existing installation
    if [ -d "/usr/local/x-ui/" ]; then
        warning "Removing existing X-UI installation..."
        systemctl stop x-ui 2>/dev/null || true
        rm -rf /usr/local/x-ui/
    fi

    # Get latest version
    last_version=$(curl -Ls "https://api.github.com/repos/vaxilu/x-ui/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
    if [[ -z "$last_version" ]]; then
        error "Failed to get latest version. Check your internet connection."
        exit 1
    fi

    # Detect architecture
    arch=$(uname -m)
    if [[ $arch == "x86_64" || $arch == "x64" || $arch == "amd64" ]]; then
        arch="amd64"
    elif [[ $arch == "aarch64" || $arch == "arm64" ]]; then
        arch="arm64"
    else
        arch="amd64"
        warning "Unknown architecture, using amd64"
    fi

    info "Latest version: ${last_version}"
    info "Architecture: ${arch}"

    # Download X-UI
    wget -O /usr/local/x-ui-linux-${arch}.tar.gz "https://github.com/vaxilu/x-ui/releases/download/${last_version}/x-ui-linux-${arch}.tar.gz"

    if [[ $? -ne 0 ]]; then
        error "Download failed. Check your internet connection."
        exit 1
    fi

    # Extract and install
    tar zxvf x-ui-linux-${arch}.tar.gz
    rm -f x-ui-linux-${arch}.tar.gz
    cd x-ui
    chmod +x x-ui bin/xray-linux-${arch}

    # Create service file
    cat > /etc/systemd/system/x-ui.service << EOF
[Unit]
Description=x-ui Service
After=network.target
Wants=network.target

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

    success "X-UI installed successfully"
}

# Configure firewall
configure_firewall() {
    step "Configuring firewall..."
    
    if command -v ufw >/dev/null 2>&1; then
        ufw allow $PORT/tcp
        ufw allow 443/tcp
        ufw allow 80/tcp
        success "UFW firewall configured"
    elif command -v firewall-cmd >/dev/null 2>&1; then
        firewall-cmd --permanent --add-port=$PORT/tcp
        firewall-cmd --permanent --add-port=443/tcp
        firewall-cmd --permanent --add-port=80/tcp
        firewall-cmd --reload
        success "Firewalld configured"
    else
        warning "No firewall detected. Configure ports manually if needed."
    fi
}

# Start x-ui service
start_service() {
    step "Starting X-UI service..."
    
    systemctl daemon-reload
    systemctl enable x-ui
    
    if systemctl is-active --quiet x-ui; then
        systemctl restart x-ui
    else
        systemctl start x-ui
    fi
    
    # Wait for service to start
    sleep 3
    
    if systemctl is-active --quiet x-ui; then
        success "X-UI service started successfully"
    else
        error "Failed to start X-UI service"
        systemctl status x-ui
    fi
}

# Show installation results
show_results() {
    # Get public IP
    PUBLIC_IP=$(curl -s ifconfig.me || echo "your-server-ip")
    
    echo -e "${GREEN}"
    echo "╔══════════════════════════════════════════╗"
    echo "║           INSTALLATION COMPLETED!        ║"
    echo "╚══════════════════════════════════════════╝"
    echo -e "${NC}"
    
    echo -e "${WHITE}"
    echo "🔐 PANEL ACCESS INFORMATION:"
    echo "   🌐 URL: http://$PUBLIC_IP:$PORT"
    echo "   👤 Username: $USERNAME"
    echo "   🔑 Password: $PASSWORD"
    echo ""
    echo "⚙️ MANAGEMENT COMMANDS:"
    echo "   systemctl status x-ui    # Check status"
    echo "   systemctl start x-ui     # Start service"
    echo "   systemctl stop x-ui      # Stop service"
    echo "   systemctl restart x-ui   # Restart service"
    echo ""
    echo "⚠️ IMPORTANT SECURITY NOTES:"
    echo "   1. Change password after first login"
    echo "   2. Consider using SSL certificate"
    echo "   3. Keep your system updated"
    echo -e "${NC}"
    
    echo -e "${YELLOW}📋 Next steps:"
    echo "   1. Open your browser and go to: http://$PUBLIC_IP:$PORT"
    echo "   2. Login with your credentials"
    echo "   3. Configure your X-UI settings"
    echo -e "${NC}"
}

# Main function
main() {
    show_header
    check_root
    get_user_credentials
    detect_os
    install_base
    install_xui
    configure_firewall
    start_service
    show_results
}

# Run main function
main "$@"
