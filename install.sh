#!/bin/bash

# X-UI Professional Installer
# Created by ThuYaAungZaw

# Colors for beautiful UI
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

# Print functions with better UI
info() { echo -e "${CYAN}🟦 [INFO]${NC} $1"; }
success() { echo -e "${GREEN}✅ [SUCCESS]${NC} $1"; }
warning() { echo -e "${YELLOW}⚠️ [WARNING]${NC} $1"; }
error() { echo -e "${RED}❌ [ERROR]${NC} $1"; }
step() { echo -e "${PURPLE}🔸 [STEP]${NC} $1"; }
header() { echo -e "${BLUE}✨ $1${NC}"; }

# Default values
DEFAULT_USERNAME="admin"
DEFAULT_PASSWORD="Admin123!"
DEFAULT_PORT="54321"

# Beautiful header
show_header() {
    echo -e "${BLUE}"
    echo "╔══════════════════════════════════════════╗"
    echo "║           X-UI PROFESSIONAL INSTALLER    ║"
    echo "║               By ThuYaAungZaw            ║"
    echo "╚══════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
}

# Get user input with validation
get_user_input() {
    header "CONFIGURE YOUR X-UI PANEL"
    
    echo -e "${WHITE}Please enter your preferences (Press Enter for defaults):${NC}"
    echo ""
    
    while true; do
        read -p "🔹 Enter username [$DEFAULT_USERNAME]: " USERNAME
        USERNAME=${USERNAME:-$DEFAULT_USERNAME}
        if [[ "$USERNAME" =~ ^[a-zA-Z0-9_]+$ ]] && [ ${#USERNAME} -ge 3 ]; then
            break
        else
            error "Username must be at least 3 characters (letters, numbers, underscore only)"
        fi
    done
    
    while true; do
        read -p "🔹 Enter password [$DEFAULT_PASSWORD]: " PASSWORD
        PASSWORD=${PASSWORD:-$DEFAULT_PASSWORD}
        if [ ${#PASSWORD} -ge 6 ]; then
            break
        else
            error "Password must be at least 6 characters"
        fi
    done
    
    while true; do
        read -p "🔹 Enter panel port [$DEFAULT_PORT]: " PORT
        PORT=${PORT:-$DEFAULT_PORT}
        if [[ "$PORT" =~ ^[0-9]+$ ]] && [ "$PORT" -ge 1 ] && [ "$PORT" -le 65535 ]; then
            break
        else
            error "Port must be a number between 1 and 65535"
        fi
    done
    
    success "Configuration saved!"
}

# Check if user is root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root!"
        echo "Please run: sudo su"
        exit 1
    fi
}

# Detect OS
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

# Install dependencies
install_dependencies() {
    step "Installing system dependencies..."
    
    if [[ "$OS" == "centos" ]]; then
        yum update -y > /dev/null 2>&1
        yum install -y curl wget tar sudo > /dev/null 2>&1
    else
        apt-get update -y > /dev/null 2>&1
        apt-get install -y curl wget tar sudo > /dev/null 2>&1
    fi
    success "Dependencies installed successfully"
}

# Completely remove existing X-UI
remove_existing_xui() {
    step "Checking for existing X-UI installation..."
    
    if [ -d "/usr/local/x-ui/" ] || systemctl is-active --quiet x-ui 2>/dev/null; then
        warning "Existing X-UI installation detected!"
        echo ""
        echo -e "${YELLOW}Options:${NC}"
        echo "1. 🔄 Reinstall (Remove old + Install new)"
        echo "2. 🗑️  Uninstall only"
        echo "3. ❌ Exit"
        echo ""
        
        while true; do
            read -p "🔹 Choose option [1-3]: " choice
            case $choice in
                1)
                    info "Removing existing X-UI installation..."
                    # Stop and disable service
                    systemctl stop x-ui 2>/dev/null || true
                    systemctl disable x-ui 2>/dev/null || true
                    
                    # Remove files
                    rm -rf /usr/local/x-ui/ 2>/dev/null || true
                    rm -f /etc/systemd/system/x-ui.service 2>/dev/null || true
                    rm -f /etc/systemd/system/multi-user.target.wants/x-ui.service 2>/dev/null || true
                    
                    # Reload systemd
                    systemctl daemon-reload
                    
                    success "Old X-UI completely removed"
                    return 0
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
                    info "Exiting installation..."
                    exit 0
                    ;;
                *)
                    error "Invalid choice! Please enter 1, 2, or 3"
                    ;;
            esac
        done
    else
        success "No existing X-UI installation found"
    fi
}

# Download and install X-UI
install_xui() {
    step "Downloading and installing X-UI..."
    
    # Get latest version
    LATEST_VERSION=$(curl -s https://api.github.com/repos/vaxilu/x-ui/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
    
    if [[ -z "$LATEST_VERSION" ]]; then
        error "Failed to get latest version. Please check your internet connection."
        exit 1
    fi
    
    info "Latest version: $LATEST_VERSION"
    
    # Detect architecture
    ARCH=$(uname -m)
    case $ARCH in
        x86_64) ARCH="amd64" ;;
        aarch64) ARCH="arm64" ;;
        armv7l) ARCH="armv7" ;;
        *) ARCH="amd64" ;;
    esac
    info "Architecture: $ARCH"
    
    # Download X-UI
    cd /usr/local/
    if wget -O x-ui-linux-${ARCH}.tar.gz "https://github.com/vaxilu/x-ui/releases/download/${LATEST_VERSION}/x-ui-linux-${ARCH}.tar.gz"; then
        success "X-UI downloaded successfully"
    else
        error "Download failed! Please check your internet connection."
        exit 1
    fi
    
    # Extract and install
    tar zxvf x-ui-linux-${ARCH}.tar.gz
    rm -f x-ui-linux-${ARCH}.tar.gz
    cd x-ui
    chmod +x x-ui bin/xray-linux-${ARCH}
    
    success "X-UI installed successfully"
}

# Create systemd service
create_service() {
    step "Creating system service..."
    
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
User=root
Group=root

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable x-ui
    
    success "System service created"
}

# Configure firewall comprehensively
configure_firewall() {
    step "Configuring firewall rules..."
    
    # Common ports to open
    PORTS=("$PORT" "443" "80" "22" "53" "8443" "2053" "2083" "2087" "2096" "2096")
    
    if command -v ufw >/dev/null 2>&1; then
        info "Configuring UFW firewall..."
        for port in "${PORTS[@]}"; do
            ufw allow $port/tcp >/dev/null 2>&1 && info "Port $port/tcp allowed"
        done
        ufw reload >/dev/null 2>&1
        success "UFW firewall configured"
        
    elif command -v firewall-cmd >/dev/null 2>&1; then
        info "Configuring Firewalld..."
        for port in "${PORTS[@]}"; do
            firewall-cmd --permanent --add-port=$port/tcp >/dev/null 2>&1 && info "Port $port/tcp allowed"
        done
        firewall-cmd --reload >/dev/null 2>&1
        success "Firewalld configured"
        
    elif command -v iptables >/dev/null 2>&1; then
        info "Configuring iptables..."
        for port in "${PORTS[@]}"; do
            iptables -A INPUT -p tcp --dport $port -j ACCEPT >/dev/null 2>&1 && info "Port $port/tcp allowed"
        done
        # Save iptables rules
        if command -v iptables-save >/dev/null 2>&1; then
            iptables-save > /etc/iptables/rules.v4 2>/dev/null || true
        fi
        success "iptables configured"
    else
        warning "No firewall detected. Please configure ports manually if needed."
    fi
}

# Start X-UI service
start_xui() {
    step "Starting X-UI service..."
    
    systemctl daemon-reload
    systemctl enable x-ui
    
    # Stop if running
    systemctl stop x-ui 2>/dev/null || true
    sleep 2
    
    # Start service
    if systemctl start x-ui; then
        success "X-UI service started successfully"
    else
        error "Failed to start X-UI service"
        systemctl status x-ui
        exit 1
    fi
    
    # Wait for service to initialize
    sleep 5
}

# Show installation results
show_results() {
    PUBLIC_IP=$(curl -s --connect-timeout 5 ifconfig.me || echo "your-server-ip")
    
    success "
╔══════════════════════════════════════════╗
║           INSTALLATION COMPLETED!        ║
╚══════════════════════════════════════════╝"

    echo -e "${WHITE}"
    echo "🔐 PANEL ACCESS INFORMATION:"
    echo "   🌐 URL: http://$PUBLIC_IP:$PORT"
    echo "   👤 Username: $USERNAME"
    echo "   🔑 Password: $PASSWORD"
    echo "   🚪 Port: $PORT"
    echo ""
    echo "⚙️ MANAGEMENT COMMANDS:"
    echo "   systemctl status x-ui    # Check status"
    echo "   systemctl start x-ui     # Start service"
    echo "   systemctl stop x-ui      # Stop service"
    echo "   systemctl restart x-ui   # Restart service"
    echo ""
    echo "🗑️ UNINSTALL COMMAND:"
    echo "   curl -Ls YOUR_SCRIPT_URL | bash -s -- uninstall"
    echo ""
    echo "🔒 SECURITY NOTES:"
    echo "   1. Change password after first login"
    echo "   2. Consider using SSL certificate"
    echo "   3. Keep your system updated"
    echo -e "${NC}"
    
    # Test if panel is accessible
    step "Testing panel accessibility..."
    if curl -s --connect-timeout 10 "http://127.0.0.1:$PORT" >/dev/null 2>&1; then
        success "Panel is running and accessible"
    else
        warning "Panel might take a moment to start. Please wait..."
    fi
}

# Uninstall function
uninstall_xui() {
    warning "🚨 COMPLETE UNINSTALLATION"
    warning "This will remove X-UI and all its data permanently!"
    echo ""
    read -p "🔹 Are you sure you want to continue? (y/N): " confirm
    
    if [[ $confirm =~ ^[Yy]$ ]]; then
        step "Starting uninstallation..."
        
        # Stop and disable service
        systemctl stop x-ui 2>/dev/null || true
        systemctl disable x-ui 2>/dev/null || true
        
        # Remove all files
        rm -rf /usr/local/x-ui/ 2>/dev/null || true
        rm -f /etc/systemd/system/x-ui.service 2>/dev/null || true
        rm -f /etc/systemd/system/multi-user.target.wants/x-ui.service 2>/dev/null || true
        
        # Reload systemd
        systemctl daemon-reload
        
        success "X-UI has been completely removed from your system!"
        exit 0
    else
        info "Uninstallation cancelled"
        exit 0
    fi
}

# Main installation function
main() {
    show_header
    
    # Handle uninstall command
    if [ "$1" == "uninstall" ]; then
        uninstall_xui
    fi
    
    check_root
    detect_os
    install_dependencies
    remove_existing_xui
    get_user_input
    install_xui
    create_service
    configure_firewall
    start_xui
    show_results
    
    echo ""
    success "🎉 Installation completed successfully!"
    info "Thank you for using X-UI Professional Installer"
}

# Run main function
main "$@"
