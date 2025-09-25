#!/bin/bash

# My Custom X-UI Installer
# Created by [ThuYaAungZaw]

# Colors for better output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print colored messages
info() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Check if user is root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root!"
        exit 1
    fi
}

# Detect OS
detect_os() {
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
    info "Detected OS: $OS"
}

# Install dependencies
install_dependencies() {
    info "Installing dependencies..."
    
    if [[ "$OS" == "centos" ]]; then
        yum update -y
        yum install -y curl wget tar
    else
        apt-get update -y
        apt-get install -y curl wget tar
    fi
    success "Dependencies installed successfully"
}

# Download and install x-ui
install_xui() {
    info "Downloading and installing x-ui..."
    
    # Get latest version
    LATEST_VERSION=$(curl -s https://api.github.com/repos/vaxilu/x-ui/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
    
    if [[ -z "$LATEST_VERSION" ]]; then
        error "Failed to get latest version"
        exit 1
    fi
    
    info "Latest version: $LATEST_VERSION"
    
    # Detect architecture
    ARCH=$(uname -m)
    case $ARCH in
        x86_64) ARCH="amd64" ;;
        aarch64) ARCH="arm64" ;;
        *) ARCH="amd64" ;;
    esac
    
    # Download x-ui
    cd /usr/local/
    wget -O x-ui-linux-${ARCH}.tar.gz "https://github.com/vaxilu/x-ui/releases/download/${LATEST_VERSION}/x-ui-linux-${ARCH}.tar.gz"
    
    if [[ $? -ne 0 ]]; then
        error "Download failed"
        exit 1
    fi
    
    # Extract and install
    tar zxvf x-ui-linux-${ARCH}.tar.gz
    rm -f x-ui-linux-${ARCH}.tar.gz
    cd x-ui
    chmod +x x-ui bin/xray-linux-${ARCH}
    
    success "x-ui installed successfully"
}

# Create systemd service
create_service() {
    info "Creating systemd service..."
    
    cat > /etc/systemd/system/x-ui.service << EOF
[Unit]
Description=x-ui Service
Documentation=https://github.com/vaxilu/x-ui
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
    systemctl start x-ui
    
    success "Systemd service created and started"
}

# Configure firewall
configure_firewall() {
    info "Configuring firewall..."
    
    if command -v ufw >/dev/null 2>&1; then
        ufw allow 54321/tcp
        ufw allow 443/tcp
        ufw allow 80/tcp
        success "UFW firewall configured"
    elif command -v firewall-cmd >/dev/null 2>&1; then
        firewall-cmd --permanent --add-port=54321/tcp
        firewall-cmd --permanent --add-port=443/tcp
        firewall-cmd --permanent --add-port=80/tcp
        firewall-cmd --reload
        success "Firewalld configured"
    else
        warning "No firewall detected, skipping configuration"
    fi
}

# Show installation info
show_info() {
    success "
=== X-UI Installation Completed ===

📊 Panel Access:
   URL: http://$(curl -s ifconfig.me):54321
   OR: http://your-server-ip:54321
   Username: admin
   Password: admin

🔧 Management Commands:
   systemctl status x-ui    # Check status
   systemctl start x-ui     # Start service
   systemctl stop x-ui      # Stop service
   systemctl restart x-ui   # Restart service

⚠️  Important Security Notes:
   1. Change default password immediately!
   2. Consider changing default port
   3. Use SSL certificate for secure access
   4. Keep system updated

📁 Installation Directory: /usr/local/x-ui/

=====================================
"
}

# Main installation function
main() {
    echo -e "${BLUE}"
    echo "==================================="
    echo "    X-UI Auto Installer Script"
    echo "    Created by [ThuYaAungZaw]"
    echo "==================================="
    echo -e "${NC}"
    
    check_root
    detect_os
    install_dependencies
    install_xui
    create_service
    configure_firewall
    show_info
}

# Run main function
main "$@"
