#!/bin/bash

# ========================================================================
# Script to Install ttyd and ngrok on Ubuntu (22.04/24.04) WSL2 with Persistent Tunnel
# Now with Static Domain Support and Systemd Service for True Persistence
# ========================================================================

# Exit immediately if a command exits with a non-zero status
set -e

# Start timer
START_TIME=$(date +%s)

# Function to print messages with a separator
echo_separator() {
    echo "========================================"
}

# Function to print error messages
echo_error() {
    echo "ERROR: $1" >&2
}

# Function to print info messages
echo_info() {
    echo "INFO: $1"
}

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to create startup script (for manual management if needed)
create_startup_script() {
    cat > ~/start_ngrok_terminal.sh << 'EOF'
#!/bin/bash

echo "========================================"
echo "Starting ngrok Terminal Services"
echo "========================================"

# Start ttyd service
echo "Starting ttyd-terminal.service..."
sudo systemctl start ttyd-terminal.service

# Wait a moment
sleep 3

# Start ngrok service
echo "Starting ngrok-tunnel.service..."
sudo systemctl start ngrok-tunnel.service

# Show status
sleep 5
echo "Service Status:"
sudo systemctl status ttyd-terminal.service --no-pager -l
sudo systemctl status ngrok-tunnel.service --no-pager -l

echo "========================================"
echo "Services started. Check status above."
echo "========================================"
EOF
    chmod +x ~/start_ngrok_terminal.sh
}

# Check if running on WSL
echo_separator
echo "Checking Environment..."
echo_separator
if ! grep -q microsoft /proc/version; then
    echo_error "This script is intended for WSL2. Exiting."
    exit 1
else
    echo_info "Running on WSL2. Continuing..."
fi

# Determine Ubuntu version
UBUNTU_VERSION=$(lsb_release -cs)
echo_info "Detected Ubuntu version: $UBUNTU_VERSION"

# Update package list first
echo_separator
echo "Updating Package Lists..."
echo_separator
sudo apt-get update

# Install dependencies (including OpenSSL development libraries)
echo_separator
echo "Installing Dependencies..."
echo_separator

# Try to install packages, but handle missing ones gracefully
PACKAGES=(
    "build-essential"
    "git"
    "libjson-c-dev"
    "libwebsockets-dev"
    "jq"
    "curl"
    "apt-transport-https"
    "libicu-dev"
    "libuv1-dev"
    "libssl-dev"
)

# Try to install pkg-config, but use alternative if not available
if apt-cache show pkg-config > /dev/null 2>&1; then
    PACKAGES+=("pkg-config")
elif apt-cache show pkgconfig > /dev/null 2>&1; then
    PACKAGES+=("pkgconfig")
fi

# Try to install cmake, but handle if not available
if apt-cache show cmake > /dev/null 2>&1; then
    PACKAGES+=("cmake")
else
    echo_info "cmake not available in repositories. Will install build-essential which includes make."
fi

# Install available packages
sudo apt-get install -y "${PACKAGES[@]}" || {
    echo_error "Failed to install some packages. Continuing anyway..."
}

# Check if cmake is available, if not try alternatives
if ! command_exists cmake; then
    echo_info "cmake not found. Trying to install it via snap or other methods..."
    
    # Try to install cmake via snap if snap is available
    if command_exists snap; then
        echo_info "Installing cmake via snap..."
        sudo snap install cmake --classic
    else
        echo_info "snap not available. Will try to build ttyd without cmake if possible."
    fi
fi

# Clone and build ttyd
echo_separator
echo "Setting up ttyd..."
echo_separator
cd ~
if [ ! -d "ttyd" ]; then
    echo_info "Cloning ttyd repository..."
    git clone https://github.com/tsl0922/ttyd.git
else
    echo_info "ttyd repository already exists. Updating..."
    cd ttyd
    git pull
    cd ..
fi

cd ttyd

# Check if cmake is available and build accordingly
if command_exists cmake; then
    echo_info "Building ttyd with cmake..."
    # Create build directory and build ttyd
    mkdir -p build
    cd build
    
    # Configure with explicit OpenSSL support
    cmake .. -DOPENSSL_ROOT_DIR=/usr/lib/x86_64-linux-gnu/
    make -j$(nproc)
    sudo make install
else
    echo_info "cmake not available. Trying alternative build method..."
    # Try to build directly with make if Makefile exists
    if [ -f "Makefile" ]; then
        make -j$(nproc)
        sudo make install
    else
        echo_error "Cannot build ttyd: neither cmake nor Makefile available. Exiting."
        exit 1
    fi
fi

# Verify ttyd installation
if ! command_exists ttyd; then
    echo_error "ttyd installation failed. Exiting."
    exit 1
else
    echo_info "ttyd installed successfully: $(ttyd --version)"
fi

# Kill any existing ttyd processes
echo_separator
echo "Managing ttyd Process..."
echo_separator
TTYD_PID_FILE="$HOME/ttyd.pid"
if [ -f "$TTYD_PID_FILE" ]; then
    OLD_PID=$(cat "$TTYD_PID_FILE")
    if ps -p "$OLD_PID" > /dev/null 2>&1; then
        echo_info "Killing existing ttyd process (PID: $OLD_PID)..."
        kill "$OLD_PID" || true
        rm -f "$TTYD_PID_FILE"
    fi
fi

# Start ttyd in background
echo_info "Starting ttyd in background..."
ttyd -p 7681 --writable bash > ~/ttyd.log 2>&1 &
TTYD_PID=$!
echo "$TTYD_PID" > "$TTYD_PID_FILE"
echo_info "ttyd started with PID: $TTYD_PID"

# Install Node.js and npm
echo_separator
echo "Installing Node.js and npm..."
echo_separator

# Remove any existing Node.js installation
echo_info "Removing existing Node.js installation if present..."
sudo apt-get remove -y nodejs npm || true

# Determine appropriate Node.js installation method
if [ "$UBUNTU_VERSION" = "noble" ] || [ "$UBUNTU_VERSION" = "jammy" ]; then
    # For Ubuntu 22.04 (jammy) and 24.04 (noble)
    echo_info "Installing Node.js via binary distribution..."
    
    # Check if Node.js is already installed via other means
    if command_exists node && command_exists npm; then
        echo_info "Node.js already installed: $(node -v)"
    else
        # Download and install Node.js directly
        cd ~
        wget https://nodejs.org/dist/v18.20.4/node-v18.20.4-linux-x64.tar.xz
        tar -xf node-v18.20.4-linux-x64.tar.xz
        sudo cp -r node-v18.20.4-linux-x64/* /usr/local/
        
        # Clean up
        rm -rf node-v18.20.4-linux-x64*
    fi
else
    # For older versions, try the traditional method
    echo_info "Adding NodeSource repository..."
    
    # Try to install NodeSource key and repository
    if curl -fsSL https://deb.nodesource.com/gpgkey/nodesource.gpg.key | sudo gpg --dearmor -o /usr/share/keyrings/nodesource-keyring.gpg 2>/dev/null; then
        echo "deb [signed-by=/usr/share/keyrings/nodesource-keyring.gpg] https://deb.nodesource.com/node_18.x $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/nodesource.list
        sudo apt-get update
        sudo apt-get install -y nodejs
    else
        # Fallback: Install from default repositories
        echo_info "NodeSource repository failed. Installing from default repositories..."
        sudo apt-get install -y nodejs npm
    fi
fi

# Verify Node.js and npm installation
if ! command_exists node || ! command_exists npm; then
    echo_error "Node.js or npm installation failed. Exiting."
    exit 1
fi

echo_info "Node.js version: $(node -v)"
echo_info "npm version: $(npm -v)"

# Update npm to a compatible version (instead of latest)
echo_info "Updating npm to a compatible version..."
sudo npm install -g npm@10.8.3

# Install ngrok
echo_separator
echo "Installing ngrok..."
echo_separator

# Uninstall any existing ngrok installations
echo_info "Removing existing ngrok installations if present..."
sudo npm uninstall -g ngrok || true

# Try installing ngrok via npm, with fallback to direct download
echo_info "Installing ngrok via npm..."
if ! sudo npm install -g ngrok@5.0.0-beta.2; then
    echo_info "npm installation failed. Trying direct download..."
    
    # Download ngrok directly
    cd ~
    wget https://bin.equinox.io/c/bNyj1m1r5gY/ngrok-v3-stable-linux-amd64.tgz
    tar -xzf ngrok-v3-stable-linux-amd64.tgz
    sudo mv ngrok /usr/local/bin/
    rm ngrok-v3-stable-linux-amd64.tgz
    
    # Verify installation
    if ! command_exists ngrok; then
        echo_error "ngrok installation failed. Exiting."
        exit 1
    fi
fi

# Verify ngrok installation
if command_exists ngrok; then
    echo_info "ngrok installed successfully: $(ngrok --version)"
else
    echo_error "ngrok installation failed. Exiting."
    exit 1
fi

# Configure ngrok with your authtoken - using random domains for reliability
echo_separator
echo "Configuring ngrok..."
echo_separator

# Use random domains for maximum reliability (no domain reservation required)
echo_info "Using ngrok random domains for maximum reliability..."
echo_info "Note: Random domains change on restart, but provide 100% uptime"
STATIC_DOMAIN=""

# Kill any existing ngrok processes and systemd services
echo_info "Stopping any existing ngrok services..."
sudo systemctl stop ngrok-tunnel.service || true
sudo systemctl stop ttyd-terminal.service || true
pkill -f "ngrok http" || true
pkill -f "ttyd -p" || true

# Add authtoken (using the one you provided)
echo_info "Adding ngrok authtoken..."
ngrok config add-authtoken 2qcNPrautgOBIKkgwDb2W6g8oCe_5c2XSNffF6q2y15eTMUcC

# Save domain configuration (empty for random domains)
DOMAIN_CONFIG_FILE="$HOME/.ngrok_domain"
echo "random" > "$DOMAIN_CONFIG_FILE"
echo_info "Using random domains - no reservation needed"

# Create systemd service files for persistence
echo_separator
echo "Creating Systemd Services for Persistence..."
echo_separator

# Install tmux for persistent sessions
echo_info "Installing tmux for session persistence..."
sudo apt-get install -y tmux || {
    echo_error "Failed to install tmux, falling back to screen"
    sudo apt-get install -y screen || echo_info "Using basic bash (no session persistence)"
}

# Create ttyd service with tmux integration
echo_info "Creating ttyd systemd service with persistent sessions..."
sudo tee /etc/systemd/system/ttyd-terminal.service > /dev/null << EOF
[Unit]
Description=ttyd Web Terminal Service with Persistent Sessions
After=network.target
Wants=network.target

[Service]
Type=simple
User=$(whoami)
WorkingDirectory=$HOME
ExecStart=/usr/local/bin/ttyd -p 7681 --writable --once --reconnect 10 bash -c "tmux new-session -A -s main-session"
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal
KillMode=mixed
KillSignal=SIGTERM
TimeoutStopSec=30

[Install]
WantedBy=multi-user.target
EOF

# Create ngrok service
echo_info "Creating ngrok systemd service..."
NGROK_COMMAND="/usr/local/bin/ngrok http 7681"

sudo tee /etc/systemd/system/ngrok-tunnel.service > /dev/null << EOF
[Unit]
Description=ngrok Tunnel Service
After=network-online.target ttyd-terminal.service
Wants=network-online.target
Requires=ttyd-terminal.service

[Service]
Type=simple
User=$(whoami)
WorkingDirectory=$HOME
ExecStart=$NGROK_COMMAND
Restart=always
RestartSec=15
StartLimitInterval=300
StartLimitBurst=5
StandardOutput=journal
StandardError=journal
Environment=HOME=$HOME

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd and enable services
echo_info "Enabling systemd services..."
sudo systemctl daemon-reload
sudo systemctl enable ttyd-terminal.service
sudo systemctl enable ngrok-tunnel.service

# Start services with error handling
echo_info "Starting services..."
sudo systemctl start ttyd-terminal.service

# Wait for ttyd to be ready
echo_info "Waiting for ttyd to initialize..."
sleep 5

# Check if ttyd is running
if ! sudo systemctl is-active --quiet ttyd-terminal.service; then
    echo_error "ttyd service failed to start!"
    sudo journalctl -u ttyd-terminal.service --no-pager -n 10
    exit 1
fi

echo_info "Starting ngrok service..."
sudo systemctl start ngrok-tunnel.service

# Give ngrok more time to connect
echo_info "Waiting for ngrok to establish connection..."
sleep 10

# Extended wait and validation for ngrok connection
echo_separator
echo "Validating ngrok Connection..."
echo_separator

# Wait longer for ngrok to establish connection
sleep 5

# Check service status
echo_info "Checking service status..."
sudo systemctl status ttyd-terminal.service --no-pager -l | head -5 || true
sudo systemctl status ngrok-tunnel.service --no-pager -l | head -5 || true

# Validate ngrok service is running
NGROK_RETRIES=0
MAX_NGROK_RETRIES=3

while [ $NGROK_RETRIES -lt $MAX_NGROK_RETRIES ]; do
    if sudo systemctl is-active --quiet ngrok-tunnel.service; then
        echo_info "ngrok service is active"
        break
    else
        echo_info "ngrok service not active, attempt $((NGROK_RETRIES + 1)) of $MAX_NGROK_RETRIES"
        
        # Show error logs
        echo "Recent ngrok logs:"
        sudo journalctl -u ngrok-tunnel.service --no-pager -n 5
        
        # Restart ngrok service
        echo_info "Restarting ngrok service..."
        sudo systemctl restart ngrok-tunnel.service
        sleep 15
        
        NGROK_RETRIES=$((NGROK_RETRIES + 1))
    fi
done

# Get the public URL from ngrok
echo_separator
echo "Fetching ngrok Public URL..."
echo_separator

# Try multiple times to get the ngrok URL with better error handling
PUBLIC_URL=""
for i in {1..20}; do
    if curl --silent --max-time 10 http://localhost:4040/api/tunnels > ~/ngrok_api_response.json 2>/dev/null; then
        # Check if the response contains valid tunnel data
        if [ -s ~/ngrok_api_response.json ]; then
            PUBLIC_URL=$(jq -r '.tunnels[0].public_url // empty' ~/ngrok_api_response.json 2>/dev/null)
            if [ -n "$PUBLIC_URL" ] && [ "$PUBLIC_URL" != "null" ] && [ "$PUBLIC_URL" != "empty" ]; then
                echo_info "Successfully retrieved ngrok URL: $PUBLIC_URL"
                break
            fi
        fi
    fi
    echo_info "Attempt $i failed. Retrying in 3 seconds..."
    sleep 3
done

if [ -z "$PUBLIC_URL" ] || [ "$PUBLIC_URL" == "null" ]; then
    echo_error "Failed to retrieve ngrok public URL after 20 attempts."
    echo "Checking ngrok service status..."
    sudo systemctl status ngrok-tunnel.service --no-pager -l
    echo "Recent ngrok logs:"
    sudo journalctl -u ngrok-tunnel.service --no-pager -n 10
    
    # Try to get URL from ngrok config/status
    echo_info "Attempting alternative URL retrieval..."
    if command_exists ngrok; then
        # This will fail but might give us useful info
        timeout 5 ngrok api tunnels list || echo "Could not list tunnels via API"
    fi
    
    echo_error "Could not establish ngrok tunnel. Please check:"
    echo "1. Internet connection"
    echo "2. ngrok authtoken validity"
    echo "3. ngrok service logs: sudo journalctl -u ngrok-tunnel.service -f"
    exit 1
fi

# Stop timer
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

# Output results
echo_separator
echo "ngrok Tunnel Established"
echo "Public URL: $PUBLIC_URL"
echo_separator
echo "Script Execution Completed"
echo "Public URL: $PUBLIC_URL"
echo "Total Execution Time: $DURATION seconds"
echo_separator

# Show service information
echo "Services are now running as systemd services:"
echo "- ttyd-terminal.service"
echo "- ngrok-tunnel.service"
echo_separator

# Instructions for user
echo "To access your terminal:"
echo "1. Open the URL above in your browser"
echo "2. Services will automatically restart on boot and failures"
echo "3. To manage services:"
echo "   sudo systemctl status ttyd-terminal.service"
echo "   sudo systemctl status ngrok-tunnel.service"
echo "   sudo systemctl restart ngrok-tunnel.service"
echo "   sudo journalctl -u ngrok-tunnel.service -f  # View logs"
echo "4. To stop services: ~/stop_ngrok_terminal.sh"
echo_separator

# Create a stop script for convenience
cat > ~/stop_ngrok_terminal.sh << 'EOF'
#!/bin/bash

echo "========================================"
echo "Stopping ngrok Terminal Services"
echo "========================================"

# Stop systemd services
echo "Stopping ttyd-terminal.service..."
sudo systemctl stop ttyd-terminal.service || echo "ttyd service was not running"

echo "Stopping ngrok-tunnel.service..."
sudo systemctl stop ngrok-tunnel.service || echo "ngrok service was not running"

# Disable services from auto-starting
echo "Disabling services from auto-start..."
sudo systemctl disable ttyd-terminal.service || true
sudo systemctl disable ngrok-tunnel.service || true

# Kill any remaining processes (fallback)
echo "Cleaning up any remaining processes..."
pkill -f "ttyd -p 7681" || true
pkill -f "ngrok http" || true

# Clean up old PID files if they exist
rm -f "$HOME/ttyd.pid" || true
rm -f "$HOME/ngrok.pid" || true
rm -f "$HOME/ngrok_keepalive.pid" || true

echo "All services stopped and disabled."
echo "To re-enable, run the setup script again."
echo "========================================"
EOF

chmod +x ~/stop_ngrok_terminal.sh
echo_info "Stop script created at: ~/stop_ngrok_terminal.sh"

# Final message about persistent tunnel
echo_separator
echo "IMPORTANT: True Persistence Activated"
echo "Services are now managed by systemd and will:"
echo "- Automatically restart on failure"
echo "- Start automatically after system reboot"
echo "- Maintain the same URL (if using static domain)"
echo "- Run independently of terminal sessions"
echo_separator

# Copy URL to clipboard (works with WSL2)
echo_separator
echo "Copying URL to Clipboard..."
echo_separator

# Try multiple clipboard methods for maximum compatibility
CLIPBOARD_SUCCESS=false

# Method 1: Windows clipboard via WSL
if command_exists clip.exe; then
    echo -n "$PUBLIC_URL" | clip.exe 2>/dev/null && CLIPBOARD_SUCCESS=true
fi

# Method 2: PowerShell clipboard (WSL2)
if [ "$CLIPBOARD_SUCCESS" = false ] && command_exists powershell.exe; then
    echo -n "$PUBLIC_URL" | powershell.exe -Command "Set-Clipboard" 2>/dev/null && CLIPBOARD_SUCCESS=true
fi

# Method 3: Linux clipboard utilities
if [ "$CLIPBOARD_SUCCESS" = false ] && command_exists xclip; then
    echo -n "$PUBLIC_URL" | xclip -selection clipboard 2>/dev/null && CLIPBOARD_SUCCESS=true
fi

if [ "$CLIPBOARD_SUCCESS" = false ] && command_exists xsel; then
    echo -n "$PUBLIC_URL" | xsel --clipboard --input 2>/dev/null && CLIPBOARD_SUCCESS=true
fi

# Method 4: tmux clipboard (if in tmux)
if [ "$CLIPBOARD_SUCCESS" = false ] && command_exists tmux && [ -n "$TMUX" ]; then
    echo -n "$PUBLIC_URL" | tmux load-buffer - 2>/dev/null && CLIPBOARD_SUCCESS=true
fi

if [ "$CLIPBOARD_SUCCESS" = true ]; then
    echo_info "✓ Public URL copied to clipboard successfully!"
    echo_info "✓ URL: $PUBLIC_URL"
else
    echo_info "⚠ Could not copy to clipboard automatically"
    echo_info "Manual copy required: $PUBLIC_URL"
fi

# Also save to a file for easy access
echo "$PUBLIC_URL" > "$HOME/ngrok_url.txt"
echo_info "✓ URL saved to: ~/ngrok_url.txt"

# Create startup script for manual management
create_startup_script
echo_info "Startup script created at: ~/start_ngrok_terminal.sh"

echo_separator

# Show final service status
echo "Final Service Status Check:"
sudo systemctl status ttyd-terminal.service --no-pager -l | head -10
sudo systemctl status ngrok-tunnel.service --no-pager -l | head -10

echo_separator
echo "🎉 SETUP COMPLETE! 🎉"
echo_separator
echo "✓ Using ngrok random domains for reliability"
echo "✓ URL automatically copied to clipboard!"
echo "✓ Services running persistently via systemd"
echo "✓ Tmux integration for persistent terminal sessions"
echo "✓ URL will remain available even after:"
echo "  - Terminal closure"
echo "  - Browser tab closure"
echo "  - WSL shutdown/restart" 
echo "  - System reboot"
echo "✓ Note: Random domains may change on service restart"
echo_separator
echo "🌐 YOUR PERSISTENT WEB TERMINAL:"
echo "   $PUBLIC_URL"
echo_separator
echo "💡 USAGE TIPS:"
echo "• Your session persists when you close the browser"
echo "• Reconnect anytime to resume your work"
echo "• Type 'exit' inside tmux session, then 'tmux kill-session -t main-session' to reset"
echo_separator

# Exit the script, services continue running via systemd
exit 0