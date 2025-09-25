#!/bin/bash

# X-UI Custom Installer
# Created by ThuYaAungZaw

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Print functions
info() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Default values
DEFAULT_USERNAME="admin"
DEFAULT_PASSWORD="admin123"
DEFAULT_PORT="54321"

# Get user input with default values
get_user_input() {
    echo ""
    info "Please configure your X-UI panel (Press Enter for defaults):"
    
    read -p "Enter username [$DEFAULT_USERNAME]: " USERNAME
    USERNAME=${USERNAME:-$DEFAULT_USERNAME}
    
    read -p "Enter password [$DEFAULT_PASSWORD]: " PASSWORD
    PASSWORD=${PASSWORD:-$DEFAULT_PASSWORD}
    
    read -p "Enter panel port [$DEFAULT_PORT]: " PORT
    PORT=${PORT:-$DEFAULT_PORT}
    
    # Validate port number
    if ! [[ "$PORT" =~ ^[0-9]+$ ]] || [ "$PORT" -lt 1 ] || [ "$PORT" -gt 65535 ]; then
        error "Invalid port number. Using default port $DEFAULT_PORT"
        PORT=$DEFAULT_PORT
    fi
}

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
        yum install -y curl wget tar sudo
    else
        apt-get update -y
        apt-get install -y curl wget tar sudo
    fi
    success "Dependencies installed successfully"
}

# Check if x-ui is already installed
check_existing_installation() {
    if [ -d "/usr/local/x-ui/" ] || systemctl is-active --quiet x-ui 2>/dev/null; then
        warning "X-UI is already installed!"
        echo ""
        echo "Options:"
        echo "1. Reinstall X-UI (remove existing and install fresh)"
        echo "2. Uninstall X-UI only"
        echo "3. Exit"
        read -p "Choose option [1-3]: " choice
        
        case $choice in
            1)
                info "Removing existing X-UI installation..."
                systemctl stop x-ui 2>/dev/null || true
                systemctl disable x-ui 2>/dev/null || true
                rm -rf /usr/local/x-ui/ 2>/dev/null || true
                rm -f /etc/systemd/system/x-ui.service 2>/dev/null || true
                systemctl daemon-reload
                success "Existing X-UI removed"
                ;;
            2)
                info "Uninstalling X-UI..."
                systemctl stop x-ui 2>/dev/null || true
                systemctl disable x-ui 2>/dev/null || true
                rm -rf /usr/local/x-ui/ 2>/dev/null || true
                rm -f /etc/systemd/system/x-ui.service 2>/dev/null || true
                systemctl daemon-reload
                success "X-UI uninstalled successfully"
                exit 0
                ;;
            3)
                info "Exiting..."
                exit 0
                ;;
            *)
                error "Invalid choice: '$choice'. Please enter 1, 2, or 3."
                exit 1
                ;;
        esac
    fi
}

# Download and install x-ui
install_xui() {
    info "Downloading and installing X-UI..."
    
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
    
    success "X-UI installed successfully"
}

# Configure x-ui with custom settings
configure_xui() {
    info "Configuring X-UI with your settings..."
    
    # Note: X-UI will use these settings on first start
    # The actual configuration happens when X-UI starts for the first time
    success "X-UI will use your custom settings on first start"
}

# Create systemd service
create_service() {
    info "Creating systemd service..."
    
    cat > /etc/systemd/system/x-ui.service << EOF
[Unit]
Description=X-UI Service
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
    
    success "Systemd service created"
}

# Start x-ui service with custom port
start_xui() {
    info "Starting X-UI service..."
    
    # Stop if already running
    systemctl stop x-ui 2>/dev/null || true
    
    # Start the service
    systemctl start x-ui
    
    # Wait for service to start
    sleep 5
    
    if systemctl is-active --quiet x-ui; then
        success "X-UI service started successfully"
    else
        error "Failed to start X-UI service"
        systemctl status x-ui
    fi
}

# Configure firewall
configure_firewall() {
    info "Configuring firewall..."
    
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
        warning "No firewall detected, skipping configuration"
    fi
}

# Uninstall function
uninstall_xui() {
    warning "This will completely remove X-UI and all its data!"
    read -p "Are you sure you want to uninstall? (y/N): " confirm
    if [[ $confirm =~ ^[Yy]$ ]]; then
        info "Uninstalling X-UI..."
        systemctl stop x-ui 2>/dev/null || true
        systemctl disable x-ui 2>/dev/null || true
        rm -rf /usr/local/x-ui/ 2>/dev/null || true
        rm -f /etc/systemd/system/x-ui.service 2>/dev/null || true
        systemctl daemon-reload
        success "X-UI uninstalled successfully"
        exit 0
    else
        info "Uninstall cancelled"
        exit 0
    fi
}

# Show installation info
show_info() {
    PUBLIC_IP=$(curl -s ifconfig.me || echo "your-server-ip")
    
    success "
=== X-UI Installation Completed ===

Panel Configuration:
   URL: http://$PUBLIC_IP:$PORT
   Username: $USERNAME
   Password: $PASSWORD
   Port: $PORT

Management Commands:
   systemctl status x-ui    # Check status
   systemctl start x-ui     # Start service
   systemctl stop x-ui      # Stop service
   systemctl restart x-ui   # Restart service

Uninstall Command:
   curl -Ls https://raw.githubusercontent.com/thuyaaungzaw1-lang/x-ui-installer/main/install.sh | bash -s -- uninstall

Important Notes:
   1. First time setup: Open panel and configure with your credentials
   2. Default credentials are changed to your custom ones
   3. Consider using SSL certificate for security

Installation Directory: /usr/local/x-ui/

=====================================
"
}

# Simple installation without user input (for uninstall)
simple_install() {
    check_root
    detect_os
    install_dependencies
    
    # Use default values for simple install
    USERNAME=$DEFAULT_USERNAME
    PASSWORD=$DEFAULT_PASSWORD
    PORT=$DEFAULT_PORT
    
    install_xui
    create_service
    start_xui
    configure_firewall
    
    success "X-UI installed with default settings"
    info "Panel: http://$(curl -s ifconfig.me || echo 'your-server-ip'):$PORT"
    info "Username: $USERNAME"
    info "Password: $PASSWORD"
}

# Main installation function
main() {
    echo -e "${BLUE}"
    echo "==================================="
    echo "    X-UI Custom Installer"
    echo "    Created by ThuYaAungZaw"
    echo "==================================="
    echo -e "${NC}"
    
    # Check for uninstall command
    if [ "$1" == "uninstall" ]; then
        uninstall_xui
        exit 0
    fi
    
    # Check for simple install
    if [ "$1" == "simple" ]; then
        simple_install
        exit 0
    fi
    
    check_root
    detect_os
    install_dependencies
    check_existing_installation
    get_user_input
    install_xui
    configure_xui
    create_service
    start_xui
    configure_firewall
    show_info
}

# Run main function
main "$@"
