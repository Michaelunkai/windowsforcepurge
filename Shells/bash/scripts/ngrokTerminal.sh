#!/bin/bash

# ========================================================================
# Script to Install ttyd and ngrok on Ubuntu (22.04/24.04) WSL2 with Persistent Tunnel
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

# Function to keep ngrok tunnel alive
keep_tunnel_alive() {
    local url=$1
    local log_file=~/ngrok_keepalive.log
    
    echo_info "Starting tunnel keep-alive process..."
    
    # Infinite loop to ping the tunnel
    while true; do
        # Ping the URL to keep it alive
        if curl -s -o /dev/null -w "%{http_code}" "$url" >/dev/null 2>&1; then
            echo "$(date): Successfully pinged tunnel at $url" >> "$log_file"
        else
            echo "$(date): Failed to ping tunnel at $url" >> "$log_file"
        fi
        
        # Wait for 2 minutes before next ping (ngrok tunnels timeout after 2 hours,
        # but we ping every 2 minutes to be safe)
        sleep 120
    done
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

# Configure ngrok with your authtoken
echo_separator
echo "Configuring ngrok..."
echo_separator

# Kill any existing ngrok processes
NGROK_PID_FILE="$HOME/ngrok.pid"
if [ -f "$NGROK_PID_FILE" ]; then
    OLD_PID=$(cat "$NGROK_PID_FILE")
    if ps -p "$OLD_PID" > /dev/null 2>&1; then
        echo_info "Killing existing ngrok process (PID: $OLD_PID)..."
        kill "$OLD_PID" || true
        rm -f "$NGROK_PID_FILE"
    fi
fi

# Add authtoken (using the one you provided)
echo_info "Adding ngrok authtoken..."
ngrok config add-authtoken 2qcNPrautgOBIKkgwDb2W6g8oCe_5c2XSNffF6q2y15eTMUcC

# Start ngrok in background
echo_separator
echo "Starting ngrok Tunnel..."
echo_separator
ngrok http 7681 > ~/ngrok.log 2>&1 &
NGROK_PID=$!
echo "$NGROK_PID" > "$NGROK_PID_FILE"
echo_info "ngrok started with PID: $NGROK_PID"

# Wait for ngrok to initialize
echo_separator
echo "Waiting for ngrok to Initialize..."
echo_separator
sleep 10  # Adjust if necessary based on your network speed

# Get the public URL from ngrok
echo_separator
echo "Fetching ngrok Public URL..."
echo_separator

# Try multiple times to get the ngrok URL
PUBLIC_URL=""
for i in {1..10}; do
    if curl --silent --max-time 5 http://localhost:4040/api/tunnels > ~/ngrok_api_response.json 2>/dev/null; then
        PUBLIC_URL=$(jq -r '.tunnels[0].public_url' ~/ngrok_api_response.json)
        if [ "$PUBLIC_URL" != "null" ] && [ -n "$PUBLIC_URL" ]; then
            echo_info "Successfully retrieved ngrok URL: $PUBLIC_URL"
            break
        fi
    fi
    echo_info "Attempt $i failed. Retrying in 5 seconds..."
    sleep 5
done

if [ -z "$PUBLIC_URL" ] || [ "$PUBLIC_URL" == "null" ]; then
    echo_error "Failed to retrieve ngrok public URL after 10 attempts."
    echo "Check ~/ngrok.log for details."
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

# Show process information
echo "ttyd PID: $TTYD_PID (PID file: $TTYD_PID_FILE)"
echo "ngrok PID: $NGROK_PID (PID file: $NGROK_PID_FILE)"
echo_separator

# Start the keep-alive process in background
echo_info "Starting tunnel keep-alive process..."
keep_tunnel_alive "$PUBLIC_URL" > ~/ngrok_keepalive.log 2>&1 &
KEEPALIVE_PID=$!
echo "$KEEPALIVE_PID" > "$HOME/ngrok_keepalive.pid"
echo_info "Keep-alive process started with PID: $KEEPALIVE_PID"

# Instructions for user
echo "To access your terminal:"
echo "1. Open the URL above in your browser"
echo "2. To stop services later, use:"
echo "   kill $TTYD_PID         # Stop ttyd"
echo "   kill $NGROK_PID        # Stop ngrok"
echo "   kill $KEEPALIVE_PID    # Stop keep-alive process"
echo "   OR simply run: ~/stop_ngrok_terminal.sh"
echo_separator

# Create a stop script for convenience
cat > ~/stop_ngrok_terminal.sh << 'EOF'
#!/bin/bash
TTYD_PID_FILE="$HOME/ttyd.pid"
NGROK_PID_FILE="$HOME/ngrok.pid"
KEEPALIVE_PID_FILE="$HOME/ngrok_keepalive.pid"

# Stop keep-alive process first
if [ -f "$KEEPALIVE_PID_FILE" ]; then
    KEEPALIVE_PID=$(cat "$KEEPALIVE_PID_FILE")
    if ps -p "$KEEPALIVE_PID" > /dev/null 2>&1; then
        echo "Stopping keep-alive process (PID: $KEEPALIVE_PID)..."
        kill "$KEEPALIVE_PID"
    else
        echo "Keep-alive process not running."
    fi
    rm -f "$KEEPALIVE_PID_FILE"
else
    echo "Keep-alive PID file not found."
fi

# Stop ttyd process
if [ -f "$TTYD_PID_FILE" ]; then
    TTYD_PID=$(cat "$TTYD_PID_FILE")
    if ps -p "$TTYD_PID" > /dev/null 2>&1; then
        echo "Stopping ttyd (PID: $TTYD_PID)..."
        kill "$TTYD_PID"
    else
        echo "ttyd process not running."
    fi
    rm -f "$TTYD_PID_FILE"
else
    echo "ttyd PID file not found."
fi

# Stop ngrok process
if [ -f "$NGROK_PID_FILE" ]; then
    NGROK_PID=$(cat "$NGROK_PID_FILE")
    if ps -p "$NGROK_PID" > /dev/null 2>&1; then
        echo "Stopping ngrok (PID: $NGROK_PID)..."
        kill "$NGROK_PID"
    else
        echo "ngrok process not running."
    fi
    rm -f "$NGROK_PID_FILE"
else
    echo "ngrok PID file not found."
fi

echo "All services stopped."
EOF

chmod +x ~/stop_ngrok_terminal.sh
echo_info "Stop script created at: ~/stop_ngrok_terminal.sh"

# Final message about persistent tunnel
echo_separator
echo "IMPORTANT: Tunnel Persistence Activated"
echo "The keep-alive process will ping your tunnel every 2 minutes"
echo "to prevent it from expiring. This ensures your URL remains active."
echo_separator

# Copy URL to clipboard (works with WSL2)
echo_separator
echo "Copying URL to Clipboard..."
echo_separator

# Use clip.exe to copy to Windows clipboard (works in WSL)
if command_exists clip.exe; then
    echo -n "$PUBLIC_URL" | clip.exe
    echo_info "Public URL copied to Windows clipboard!"
elif command_exists xclip; then
    echo -n "$PUBLIC_URL" | xclip -selection clipboard
    echo_info "Public URL copied to clipboard!"
elif command_exists xsel; then
    echo -n "$PUBLIC_URL" | xsel --clipboard --input
    echo_info "Public URL copied to clipboard!"
else
    echo_info "Clipboard utility not found. URL not copied to clipboard."
fi

echo_separator

# Exit the script, returning to the shell while keeping ttyd and ngrok running
exit 0