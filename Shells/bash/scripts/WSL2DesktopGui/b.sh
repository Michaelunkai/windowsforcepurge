#!/bin/bash

# WSL Ubuntu Native Desktop Environment Setup Script
# Uses WSLg (WSL GUI) for native Windows integration - No VNC/XRDP needed!

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
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

print_success() {
    echo -e "${PURPLE}[SUCCESS]${NC} $1"
}

# Check WSL version and WSLg support
check_wsl_gui_support() {
    print_header "Checking WSL GUI Support"
    
    # Check if running in WSL
    if ! grep -q "microsoft" /proc/version 2>/dev/null; then
        print_error "This script is designed for WSL (Windows Subsystem for Linux)"
        exit 1
    fi
    
    # Check for WSL2
    if ! grep -q "WSL2" /proc/version 2>/dev/null; then
        print_error "WSL2 is required for native GUI support"
        print_error "Please upgrade to WSL2: wsl --set-version Ubuntu 2"
        exit 1
    fi
    
    # Check for WSLg (DISPLAY should be available)
    if [ -z "$DISPLAY" ]; then
        print_warning "DISPLAY variable not set. Checking for WSLg..."
        if [ ! -d "/tmp/.X11-unix" ]; then
            print_error "WSLg (WSL GUI) not detected!"
            print_error "Please ensure you're running Windows 11 or Windows 10 with WSLg support"
            print_error "Update Windows and WSL: wsl --update"
            exit 1
        fi
    fi
    
    print_success "WSL2 with WSLg support detected!"
    print_status "DISPLAY: ${DISPLAY:-"Will be auto-configured"}"
}

# Update system packages
update_system() {
    print_header "Updating System Packages"
    sudo apt update && sudo apt upgrade -y
    
    # Install essential packages for GUI support
    sudo apt install -y \
        software-properties-common \
        apt-transport-https \
        ca-certificates \
        gpg \
        lsb-release \
        wget \
        curl
    
    print_success "System updated successfully"
}

# Install desktop environment optimized for WSLg
install_desktop() {
    print_header "Desktop Environment Selection"
    echo "Choose a desktop environment optimized for WSLg:"
    echo "1) GNOME (Full-featured, best WSLg integration)"
    echo "2) XFCE (Lightweight, excellent performance)"
    echo "3) KDE Plasma (Feature-rich, modern)"
    echo "4) MATE (Traditional, stable)"
    echo "5) Cinnamon (Modern, user-friendly)"
    
    read -p "Enter your choice (1-5): " choice
    
    case $choice in
        1)
            print_status "Installing GNOME desktop environment..."
            sudo apt install -y \
                gnome-session \
                gnome-shell \
                gnome-terminal \
                nautilus \
                gnome-control-center \
                gnome-tweaks \
                gnome-system-monitor \
                gedit \
                eog \
                evince
            DESKTOP_CMD="gnome-session"
            DESKTOP_NAME="GNOME"
            ;;
        2)
            print_status "Installing XFCE desktop environment..."
            sudo apt install -y \
                xfce4 \
                xfce4-goodies \
                xfce4-terminal \
                thunar \
                mousepad \
                ristretto \
                parole
            DESKTOP_CMD="xfce4-session"
            DESKTOP_NAME="XFCE"
            ;;
        3)
            print_status "Installing KDE Plasma desktop environment..."
            sudo apt install -y \
                plasma-desktop \
                konsole \
                dolphin \
                kate \
                gwenview \
                okular \
                plasma-nm
            DESKTOP_CMD="startplasma-x11"
            DESKTOP_NAME="KDE Plasma"
            ;;
        4)
            print_status "Installing MATE desktop environment..."
            sudo apt install -y \
                mate-desktop-environment-core \
                mate-terminal \
                caja \
                pluma \
                eom \
                atril
            DESKTOP_CMD="mate-session"
            DESKTOP_NAME="MATE"
            ;;
        5)
            print_status "Installing Cinnamon desktop environment..."
            sudo apt install -y \
                cinnamon-desktop-environment \
                gnome-terminal \
                nemo \
                gedit \
                eog \
                evince
            DESKTOP_CMD="cinnamon-session"
            DESKTOP_NAME="Cinnamon"
            ;;
        *)
            print_error "Invalid choice. Defaulting to GNOME..."
            sudo apt install -y gnome-session gnome-shell gnome-terminal nautilus
            DESKTOP_CMD="gnome-session"
            DESKTOP_NAME="GNOME"
            ;;
    esac
    
    print_success "$DESKTOP_NAME desktop environment installed successfully"
}

# Configure WSLg integration
configure_wslg() {
    print_header "Configuring WSLg Integration"
    
    # Set up display and audio
    cat >> ~/.bashrc << 'EOF'

# WSLg Configuration
export DISPLAY=${DISPLAY:-:0}
export WAYLAND_DISPLAY=${WAYLAND_DISPLAY:-wayland-0}
export XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR:-/tmp/runtime-$USER}
export PULSE_RUNTIME_PATH=${PULSE_RUNTIME_PATH:-/tmp/pulse-$USER}

# Create runtime directory if it doesn't exist
if [ ! -d "$XDG_RUNTIME_DIR" ]; then
    mkdir -p "$XDG_RUNTIME_DIR"
    chmod 700 "$XDG_RUNTIME_DIR"
fi
EOF
    
    # Source the updated bashrc
    source ~/.bashrc
    
    # Install additional WSLg-optimized packages
    sudo apt install -y \
        mesa-utils \
        x11-apps \
        x11-utils \
        dbus-x11 \
        pulseaudio \
        pulseaudio-utils \
        fonts-liberation \
        fonts-liberation2 \
        fonts-cascadia-code
    
    print_success "WSLg integration configured"
}

# Install essential applications
install_applications() {
    print_header "Installing Essential Applications"
    
    # Web browsers
    print_status "Installing web browsers..."
    sudo apt install -y firefox
    
    # Install Chrome
    wget -q -O - https://dl.google.com/linux/linux_signing_key.pub | sudo apt-key add -
    echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" | sudo tee /etc/apt/sources.list.d/google-chrome.list
    sudo apt update
    sudo apt install -y google-chrome-stable
    
    # Office suite
    print_status "Installing LibreOffice..."
    sudo apt install -y libreoffice
    
    # Media and graphics
    print_status "Installing media applications..."
    sudo apt install -y \
        vlc \
        gimp \
        inkscape \
        audacity
    
    # Development tools
    print_status "Installing development tools..."
    sudo apt install -y \
        git \
        vim \
        nano \
        code \
        curl \
        wget \
        htop \
        tree \
        neofetch
    
    # Install VS Code
    wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg
    sudo install -o root -g root -m 644 packages.microsoft.gpg /etc/apt/trusted.gpg.d/
    echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/trusted.gpg.d/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" | sudo tee /etc/apt/sources.list.d/vscode.list
    sudo apt update && sudo apt install -y code
    
    # System utilities
    print_status "Installing system utilities..."
    sudo apt install -y \
        synaptic \
        gparted \
        baobab \
        gnome-disk-utility \
        software-properties-gtk
    
    print_success "Essential applications installed"
}

# Create desktop launcher scripts
create_launchers() {
    print_header "Creating Desktop Launchers"
    
    # Create main desktop launcher
    cat > ~/start_desktop.sh << EOF
#!/bin/bash

# WSL Native Desktop Launcher
echo "=================================================="
echo "       WSL Native Desktop Environment"
echo "=================================================="
echo "Desktop: $DESKTOP_NAME"
echo "Display: \$DISPLAY"
echo ""

# Set up environment
export DISPLAY=\${DISPLAY:-:0}
export WAYLAND_DISPLAY=\${WAYLAND_DISPLAY:-wayland-0}
export XDG_RUNTIME_DIR=\${XDG_RUNTIME_DIR:-/tmp/runtime-\$USER}

# Create runtime directory
mkdir -p "\$XDG_RUNTIME_DIR"
chmod 700 "\$XDG_RUNTIME_DIR"

# Start D-Bus if not running
if ! pgrep -x "dbus-daemon" > /dev/null; then
    echo "Starting D-Bus..."
    sudo service dbus start
fi

# Start desktop environment
echo "Starting $DESKTOP_NAME desktop..."
echo "The desktop will appear in Windows as native windows!"
echo ""
echo "To close the desktop, close this terminal or press Ctrl+C"
echo ""

$DESKTOP_CMD
EOF
    chmod +x ~/start_desktop.sh
    
    # Create individual app launchers
    mkdir -p ~/launchers
    
    # Firefox launcher
    cat > ~/launchers/firefox.sh << 'EOF'
#!/bin/bash
export DISPLAY=${DISPLAY:-:0}
firefox > /dev/null 2>&1 &
echo "Firefox launched!"
EOF
    chmod +x ~/launchers/firefox.sh
    
    # Chrome launcher
    cat > ~/launchers/chrome.sh << 'EOF'
#!/bin/bash
export DISPLAY=${DISPLAY:-:0}
google-chrome-stable > /dev/null 2>&1 &
echo "Chrome launched!"
EOF
    chmod +x ~/launchers/chrome.sh
    
    # File manager launcher
    cat > ~/launchers/files.sh << 'EOF'
#!/bin/bash
export DISPLAY=${DISPLAY:-:0}
if command -v nautilus &> /dev/null; then
    nautilus > /dev/null 2>&1 &
elif command -v thunar &> /dev/null; then
    thunar > /dev/null 2>&1 &
elif command -v dolphin &> /dev/null; then
    dolphin > /dev/null 2>&1 &
elif command -v caja &> /dev/null; then
    caja > /dev/null 2>&1 &
else
    nemo > /dev/null 2>&1 &
fi
echo "File manager launched!"
EOF
    chmod +x ~/launchers/files.sh
    
    # VS Code launcher
    cat > ~/launchers/vscode.sh << 'EOF'
#!/bin/bash
export DISPLAY=${DISPLAY:-:0}
code > /dev/null 2>&1 &
echo "VS Code launched!"
EOF
    chmod +x ~/launchers/vscode.sh
    
    print_success "Desktop launchers created"
}

# Configure systemd services
configure_services() {
    print_header "Configuring System Services"
    
    # Enable and start essential services
    sudo systemctl enable dbus
    sudo service dbus start
    
    # Create a user service for the desktop (optional)
    mkdir -p ~/.config/systemd/user
    
    cat > ~/.config/systemd/user/wsl-desktop.service << EOF
[Unit]
Description=WSL Desktop Environment
After=graphical-session.target

[Service]
Type=simple
ExecStart=$HOME/start_desktop.sh
Restart=on-failure
Environment=DISPLAY=:0

[Install]
WantedBy=default.target
EOF
    
    # Enable user service (optional - user can enable manually)
    # systemctl --user enable wsl-desktop.service
    
    print_success "System services configured"
}

# Create desktop shortcuts and configuration
create_desktop_config() {
    print_header "Creating Desktop Configuration"
    
    # Create desktop directory
    mkdir -p ~/Desktop ~/Documents ~/Downloads ~/Pictures ~/Videos ~/Music
    
    # Create welcome file
    cat > ~/Desktop/README.txt << EOF
Welcome to WSL Native Desktop Environment!

Your $DESKTOP_NAME desktop is now ready to use with native Windows integration!

🚀 Quick Start:
   ./start_desktop.sh    - Launch full desktop environment
   
📁 Individual Apps:
   ./launchers/firefox.sh    - Launch Firefox
   ./launchers/chrome.sh     - Launch Chrome
   ./launchers/files.sh      - Launch File Manager  
   ./launchers/vscode.sh     - Launch VS Code

✨ Features:
   • Native Windows integration (no VNC/RDP needed!)
   • Copy/paste between Windows and Linux
   • File system access to Windows drives
   • Audio support through Windows
   • GPU acceleration support
   • Seamless window management

📂 Your Windows drives are available at:
   /mnt/c/ - C: drive
   /mnt/d/ - D: drive (if exists)
   
🔧 Useful Commands:
   sudo apt update && sudo apt upgrade  - Update system
   sudo apt install <package>           - Install software
   neofetch                            - Show system info
   
📚 More Info:
   https://docs.microsoft.com/en-us/windows/wsl/tutorials/gui-apps

Happy computing! 🐧
EOF
    
    # Create .desktop files for common applications
    mkdir -p ~/.local/share/applications
    
    # Firefox desktop entry
    cat > ~/.local/share/applications/firefox-wsl.desktop << 'EOF'
[Desktop Entry]
Name=Firefox (WSL)
Comment=Web Browser
Exec=firefox
Icon=firefox
Type=Application
Categories=Network;WebBrowser;
StartupNotify=true
EOF
    
    # Chrome desktop entry  
    cat > ~/.local/share/applications/chrome-wsl.desktop << 'EOF'
[Desktop Entry]
Name=Google Chrome (WSL)
Comment=Web Browser
Exec=google-chrome-stable
Icon=google-chrome
Type=Application
Categories=Network;WebBrowser;
StartupNotify=true
EOF
    
    print_success "Desktop configuration created"
}

# Final system optimization
optimize_system() {
    print_header "Optimizing System for WSLg"
    
    # Install additional fonts for better compatibility
    sudo apt install -y \
        fonts-noto \
        fonts-noto-color-emoji \
        fonts-liberation \
        fonts-dejavu-core \
        fonts-freefont-ttf
    
    # Configure fontconfig
    sudo fc-cache -fv
    
    # Set up GPU acceleration (if available)
    if lspci | grep -i nvidia > /dev/null; then
        print_status "NVIDIA GPU detected - consider installing NVIDIA drivers for WSL"
        print_status "Visit: https://docs.nvidia.com/cuda/wsl-user-guide/"
    fi
    
    # Clean up
    sudo apt autoremove -y
    sudo apt autoclean
    
    print_success "System optimization completed"
}

# Test WSLg functionality
test_wslg() {
    print_header "Testing WSLg Functionality"
    
    print_status "Testing X11 applications..."
    if command -v xeyes &> /dev/null; then
        echo "Testing with xeyes (will open for 3 seconds)..."
        timeout 3s xeyes > /dev/null 2>&1 &
        sleep 1
        if pgrep xeyes > /dev/null; then
            print_success "X11 applications working!"
            pkill xeyes
        else
            print_warning "X11 test application failed to start"
        fi
    fi
    
    print_status "Testing audio..."
    if command -v pactl &> /dev/null; then
        if pactl info > /dev/null 2>&1; then
            print_success "PulseAudio working!"
        else
            print_warning "PulseAudio may not be properly configured"
        fi
    fi
    
    print_success "WSLg functionality test completed"
}

# Main installation function
main() {
    print_header "WSL Native Desktop Environment Setup"
    echo -e "${PURPLE}This script sets up a complete Linux desktop that runs natively in Windows!${NC}"
    echo -e "${PURPLE}No VNC, XRDP, or external tools needed - uses WSLg for seamless integration.${NC}"
    echo ""
    print_status "Features:"
    echo "  • Native Windows integration"
    echo "  • GPU acceleration support"  
    echo "  • Audio through Windows"
    echo "  • Copy/paste between Windows and Linux"
    echo "  • Access to Windows file system"
    echo ""
    
    read -p "Do you want to continue with the installation? (y/n): " confirm
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        print_status "Installation cancelled"
        exit 0
    fi
    
    # Run installation steps
    check_wsl_gui_support
    update_system
    install_desktop
    configure_wslg
    install_applications
    create_launchers
    configure_services
    create_desktop_config
    optimize_system
    test_wslg
    
    print_header "🎉 Installation Complete! 🎉"
    print_success "Your WSL native desktop environment is ready!"
    echo ""
    print_status "🚀 To start your desktop:"
    echo -e "   ${GREEN}./start_desktop.sh${NC}"
    echo ""
    print_status "🔧 To launch individual apps:"
    echo -e "   ${GREEN}./launchers/firefox.sh${NC}  - Firefox browser"
    echo -e "   ${GREEN}./launchers/chrome.sh${NC}   - Chrome browser"  
    echo -e "   ${GREEN}./launchers/files.sh${NC}    - File manager"
    echo -e "   ${GREEN}./launchers/vscode.sh${NC}   - VS Code editor"
    echo ""
    print_status "📁 Desktop environment: $DESKTOP_NAME"
    echo ""
    print_header "🌟 Enjoy your native Linux desktop experience! 🌟"
    
    # Final reminder
    echo ""
    print_warning "💡 Pro tip: Applications will open as native Windows windows!"
    print_warning "💡 Your Windows C: drive is available at /mnt/c/"
    print_warning "💡 You can copy/paste between Windows and Linux seamlessly!"
}

# Run main function
main "$@"
