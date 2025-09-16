#!/bin/bash

# WSL Ubuntu Desktop Environment Setup Script
# This script installs and configures a desktop environment for WSL Ubuntu

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}================================${NC}"
}

# Check if running in WSL
check_wsl() {
    if ! grep -q "microsoft" /proc/version 2>/dev/null; then
        print_error "This script is designed for WSL (Windows Subsystem for Linux)"
        exit 1
    fi
    print_status "WSL environment detected"
}

# Update system
update_system() {
    print_header "Updating System Packages"
    sudo apt update && sudo apt upgrade -y
    print_status "System updated successfully"
}

# Install desktop environment
install_desktop() {
    print_header "Desktop Environment Selection"
    echo "Choose a desktop environment:"
    echo "1) XFCE (Lightweight, recommended)"
    echo "2) GNOME (Full-featured)"
    echo "3) KDE Plasma (Feature-rich)"
    echo "4) LXDE (Very lightweight)"
    echo "5) MATE (Traditional)"
    
    read -p "Enter your choice (1-5): " choice
    
    case $choice in
        1)
            print_status "Installing XFCE desktop environment..."
            sudo apt install -y xfce4 xfce4-goodies
            DESKTOP_SESSION="xfce4-session"
            ;;
        2)
            print_status "Installing GNOME desktop environment..."
            sudo apt install -y ubuntu-desktop-minimal
            DESKTOP_SESSION="gnome-session"
            ;;
        3)
            print_status "Installing KDE Plasma desktop environment..."
            sudo apt install -y kubuntu-desktop
            DESKTOP_SESSION="startkde"
            ;;
        4)
            print_status "Installing LXDE desktop environment..."
            sudo apt install -y lxde
            DESKTOP_SESSION="startlxde"
            ;;
        5)
            print_status "Installing MATE desktop environment..."
            sudo apt install -y ubuntu-mate-desktop
            DESKTOP_SESSION="mate-session"
            ;;
        *)
            print_error "Invalid choice. Defaulting to XFCE..."
            sudo apt install -y xfce4 xfce4-goodies
            DESKTOP_SESSION="xfce4-session"
            ;;
    esac
    
    print_status "Desktop environment installed successfully"
}

# Install display server options
install_display_server() {
    print_header "Display Server Setup"
    echo "Choose display server method:"
    echo "1) VNC Server (Recommended - works with any VNC client)"
    echo "2) XRDP (Remote Desktop Protocol)"
    echo "3) X11 Forwarding (Requires X server on Windows)"
    
    read -p "Enter your choice (1-3): " display_choice
    
    case $display_choice in
        1)
            setup_vnc_server
            ;;
        2)
            setup_xrdp
            ;;
        3)
            setup_x11_forwarding
            ;;
        *)
            print_error "Invalid choice. Setting up VNC server..."
            setup_vnc_server
            ;;
    esac
}

# Setup VNC Server
setup_vnc_server() {
    print_status "Installing VNC server..."
    sudo apt install -y tightvncserver
    
    # Create VNC startup script
    mkdir -p ~/.vnc
    cat > ~/.vnc/xstartup << EOF
#!/bin/bash
xrdb \$HOME/.Xresources
$DESKTOP_SESSION &
EOF
    
    chmod +x ~/.vnc/xstartup
    
    print_status "VNC server installed. Setting up password..."
    vncserver
    vncserver -kill :1
    
    # Create systemd service for VNC
    sudo tee /etc/systemd/system/vncserver@.service > /dev/null << EOF
[Unit]
Description=Start TightVNC server at startup
After=syslog.target network.target

[Service]
Type=forking
User=$USER
Group=$USER
WorkingDirectory=$HOME

PIDFile=$HOME/.vnc/%H:%i.pid
ExecStartPre=-/usr/bin/vncserver -kill :%i > /dev/null 2>&1
ExecStart=/usr/bin/vncserver -depth 24 -geometry 1280x800 :%i
ExecStop=/usr/bin/vncserver -kill :%i

[Install]
WantedBy=multi-user.target
EOF
    
    sudo systemctl daemon-reload
    sudo systemctl enable vncserver@1.service
    
    # Create start script
    cat > ~/start_desktop.sh << 'EOF'
#!/bin/bash
echo "Starting VNC server..."
vncserver -geometry 1920x1080 -depth 24
echo "VNC server started on display :1"
echo "Connect using VNC client to localhost:5901"
echo "To stop VNC server, run: vncserver -kill :1"
EOF
    chmod +x ~/start_desktop.sh
    
    print_status "VNC server configured successfully!"
    print_status "Run './start_desktop.sh' to start the desktop"
    print_status "Connect with VNC client to localhost:5901"
}

# Setup XRDP
setup_xrdp() {
    print_status "Installing XRDP server..."
    sudo apt install -y xrdp
    
    # Configure XRDP
    echo "$DESKTOP_SESSION" | sudo tee /etc/xrdp/startwm.sh
    sudo chmod +x /etc/xrdp/startwm.sh
    
    # Start XRDP service
    sudo systemctl enable xrdp
    sudo systemctl start xrdp
    
    # Create start script
    cat > ~/start_desktop.sh << 'EOF'
#!/bin/bash
echo "Starting XRDP server..."
sudo systemctl start xrdp
echo "XRDP server started"
echo "Connect using Remote Desktop Connection to localhost:3389"
echo "Use your Linux username and password to login"
EOF
    chmod +x ~/start_desktop.sh
    
    print_status "XRDP configured successfully!"
    print_status "Run './start_desktop.sh' to start the desktop"
    print_status "Connect with Remote Desktop Connection to localhost:3389"
}

# Setup X11 Forwarding
setup_x11_forwarding() {
    print_status "Setting up X11 forwarding..."
    sudo apt install -y x11-apps
    
    # Create start script for X11
    cat > ~/start_desktop.sh << EOF
#!/bin/bash
echo "Starting desktop with X11 forwarding..."
echo "Make sure you have an X server running on Windows (VcXsrv, X410, etc.)"
export DISPLAY=:0
$DESKTOP_SESSION &
echo "Desktop started. Check your X server window."
EOF
    chmod +x ~/start_desktop.sh
    
    # Add DISPLAY export to bashrc
    echo 'export DISPLAY=:0' >> ~/.bashrc
    
    print_status "X11 forwarding configured!"
    print_status "Install VcXsrv or X410 on Windows first"
    print_status "Run './start_desktop.sh' to start the desktop"
}

# Install additional useful packages
install_extras() {
    print_header "Installing Additional Packages"
    
    print_status "Installing essential packages..."
    sudo apt install -y \
        firefox \
        libreoffice \
        gedit \
        file-manager-pcmanfm \
        terminal \
        synaptic \
        software-properties-common \
        apt-transport-https \
        ca-certificates \
        curl \
        wget \
        git \
        vim \
        nano \
        htop \
        neofetch
    
    print_status "Additional packages installed successfully"
}

# Create desktop shortcuts and configuration
create_shortcuts() {
    print_header "Creating Desktop Configuration"
    
    # Create desktop directory
    mkdir -p ~/Desktop
    
    # Create a welcome script
    cat > ~/Desktop/welcome.txt << 'EOF'
Welcome to your WSL Ubuntu Desktop!

Your desktop environment is now ready to use.

Quick Start:
1. Run ./start_desktop.sh to launch the desktop
2. Connect using your chosen method (VNC/RDP/X11)
3. Enjoy your Linux desktop experience!

Useful Commands:
- Update system: sudo apt update && sudo apt upgrade
- Install software: sudo apt install <package-name>
- File manager: Available in Applications menu
- Terminal: Available in Applications menu

For more help, visit: https://docs.microsoft.com/en-us/windows/wsl/
EOF
    
    print_status "Desktop configuration created"
}

# Main installation function
main() {
    print_header "WSL Ubuntu Desktop Environment Setup"
    print_status "This script will install and configure a desktop environment for WSL"
    
    read -p "Do you want to continue? (y/n): " confirm
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        print_status "Installation cancelled"
        exit 0
    fi
    
    check_wsl
    update_system
    install_desktop
    install_display_server
    install_extras
    create_shortcuts
    
    print_header "Installation Complete!"
    print_status "Desktop environment has been successfully installed"
    print_status "Run './start_desktop.sh' to start your desktop"
    
    # Show final instructions based on chosen method
    echo ""
    print_header "Next Steps"
    if [[ -f ~/start_desktop.sh ]]; then
        print_status "1. Run: ./start_desktop.sh"
        print_status "2. Follow the connection instructions shown"
        print_status "3. Enjoy your Linux desktop in WSL!"
    fi
    
    print_warning "Note: You may need to restart WSL for all changes to take effect"
    print_status "To restart WSL, run 'wsl --shutdown' in Windows PowerShell, then restart WSL"
}

# Run main function
main "$@"
