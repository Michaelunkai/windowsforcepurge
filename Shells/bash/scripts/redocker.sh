 #!/bin/bash

set -e  # Exit on any error

echo "=== Docker Installation Script for WSL2 (Revised) ==="

# Set non-interactive mode
export DEBIAN_FRONTEND=noninteractive

# Function to log with timestamp
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Function to safely kill Docker processes
kill_docker_processes() {
    log "Stopping Docker processes..."
    sudo pkill -f dockerd 2>/dev/null || true
    sudo pkill -f containerd 2>/dev/null || true
    sleep 3
}

# Function to check WSL2
is_wsl2() {
    [ -f /proc/version ] && grep -qi microsoft /proc/version
}

# Function to clean up previous Docker installations
cleanup_docker() {
    log "Cleaning up previous Docker installations..."
    
    # Stop services
    sudo systemctl stop docker.service 2>/dev/null || true
    sudo systemctl stop docker.socket 2>/dev/null || true
    sudo systemctl stop containerd.service 2>/dev/null || true
    
    # Kill processes
    kill_docker_processes
    
    # Remove packages
    sudo apt-get remove --purge -y \
        docker docker-engine docker.io docker-ce docker-ce-cli \
        containerd containerd.io runc docker-compose \
        docker-compose-plugin docker-buildx-plugin 2>/dev/null || true
    
    # Clean directories
    sudo rm -rf /var/lib/docker /var/lib/containerd /etc/docker
    sudo rm -rf /etc/systemd/system/docker.service.d
    sudo rm -rf /etc/apt/sources.list.d/docker.list
    sudo rm -f /etc/apt/keyrings/docker.gpg
    
    # Remove Docker group
    sudo groupdel docker 2>/dev/null || true
    
    # Reload systemd
    sudo systemctl daemon-reload
    sudo systemctl reset-failed
}

# Function to install Docker
install_docker() {
    log "Installing Docker..."
    
    # Update packages
    sudo apt-get update
    
    # Install prerequisites
    sudo apt-get install -y \
        ca-certificates curl gnupg lsb-release \
        software-properties-common apt-transport-https
    
    # Add Docker GPG key
    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
        sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    sudo chmod a+r /etc/apt/keyrings/docker.gpg
    
    # Add Docker repository
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | \
        sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Update and install Docker
    sudo apt-get update
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    # Add user to docker group
    sudo usermod -aG docker $USER
}

# Function to configure Docker for WSL2
configure_docker_wsl2() {
    log "Configuring Docker for WSL2..."
    
    # Create Docker daemon configuration
    sudo mkdir -p /etc/docker
    cat << 'EOF' | sudo tee /etc/docker/daemon.json > /dev/null
{
  "storage-driver": "overlay2",
  "iptables": false,
  "userland-proxy": false,
  "experimental": false,
  "live-restore": false,
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
EOF

    # Remove any existing systemd overrides
    sudo rm -rf /etc/systemd/system/docker.service.d
    sudo rm -rf /etc/systemd/system/containerd.service.d
    
    # Reload systemd
    sudo systemctl daemon-reload
}

# Function to start Docker manually (WSL2 preferred method)
start_docker_manual() {
    log "Starting Docker manually for WSL2..."
    
    # Ensure containerd is running first
    if ! pgrep -f containerd >/dev/null; then
        log "Starting containerd..."
        sudo containerd &
        sleep 5
    fi
    
    # Start Docker daemon manually
    log "Starting Docker daemon..."
    sudo dockerd \
        --host=unix:///var/run/docker.sock \
        --host=tcp://0.0.0.0:0 \
        --storage-driver=overlay2 \
        --iptables=false \
        --userland-proxy=false \
        > /var/log/docker.log 2>&1 &
    
    # Wait for Docker to be ready
    log "Waiting for Docker daemon to be ready..."
    local count=0
    while [ $count -lt 30 ]; do
        if docker version >/dev/null 2>&1; then
            log "Docker daemon is ready!"
            return 0
        fi
        sleep 2
        count=$((count + 1))
        log "Waiting... ($count/30)"
    done
    
    log "ERROR: Docker daemon failed to start"
    return 1
}

# Function to start Docker via systemd
start_docker_systemd() {
    log "Starting Docker via systemd..."
    
    # Enable and start services
    sudo systemctl enable containerd
    sudo systemctl start containerd
    sleep 3
    
    sudo systemctl enable docker
    sudo systemctl start docker
    sleep 5
    
    # Check if Docker is running
    if sudo systemctl is-active --quiet docker; then
        log "Docker started successfully via systemd"
        return 0
    else
        log "Docker failed to start via systemd"
        return 1
    fi
}

# Function to test Docker installation
test_docker() {
    log "Testing Docker installation..."
    
    # Test Docker version
    if ! docker version >/dev/null 2>&1; then
        log "ERROR: Docker is not responding"
        return 1
    fi
    
    # Test Docker run
    log "Running hello-world container..."
    docker pull hello-world
    docker run --rm hello-world
    
    log "Docker test completed successfully!"
}

# Function to show status and instructions
show_completion() {
    echo ""
    echo "=== Docker Installation Complete ==="
    echo "Docker version: $(docker --version)"
    echo "Docker Compose version: $(docker compose version)"
    echo ""
    echo "=== WSL2 Usage Instructions ==="
    echo "1. Current session: Docker is running"
    echo "2. New terminal sessions: Run 'newgrp docker' or restart your terminal"
    echo "3. If Docker stops working after WSL restart:"
    echo "   sudo dockerd --host=unix:///var/run/docker.sock --iptables=false &"
    echo ""
    echo "=== Troubleshooting ==="
    echo "- Check Docker logs: sudo tail -f /var/log/docker.log"
    echo "- Check processes: ps aux | grep docker"
    echo "- Restart Docker: sudo pkill dockerd && sudo dockerd --iptables=false &"
    echo ""
}

# Main installation function
main() {
    log "Starting Docker installation for WSL2..."
    
    # Check if running in WSL2
    if ! is_wsl2; then
        log "WARNING: This script is optimized for WSL2"
        log "For standard Linux, consider using the official Docker installation guide"
    fi
    
    # Clean up any existing installations
    cleanup_docker
    
    # Install Docker
    install_docker
    
    # Configure for WSL2
    if is_wsl2; then
        configure_docker_wsl2
        
        # Try systemd first, fall back to manual
        if ! start_docker_systemd; then
            log "Systemd failed, trying manual startup..."
            if ! start_docker_manual; then
                log "ERROR: Both systemd and manual startup failed"
                log "Please check the logs:"
                echo "- systemctl status docker.service"
                echo "- journalctl -xeu docker.service"
                echo "- sudo tail -f /var/log/docker.log"
                exit 1
            fi
        fi
    else
        # Standard Linux
        sudo systemctl enable docker containerd
        sudo systemctl start docker containerd
        sleep 5
    fi
    
    # Test Docker
    if ! test_docker; then
        log "ERROR: Docker test failed"
        exit 1
    fi
    
    # Optional: Docker Hub login
    log "Attempting Docker Hub login..."
    if echo "Aa111111!" | docker login --username michadockermisha --password-stdin 2>/dev/null; then
        log "Successfully logged into Docker Hub"
    else
        log "Docker Hub login failed (optional)"
    fi
    
    # Show completion message
    show_completion
}

# Error handling
trap 'log "ERROR: Script failed on line $LINENO. Exit code: $?"' ERR

# Run main function
main "$@"


# compose
sudo apt update && sudo apt install -y docker-compose-plugin && sudo mkdir -p /usr/local/bin && sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose && sudo chmod +x /usr/local/bin/docker-compose && sudo ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose && docker compose version && docker-compose -v
