#!/bin/bash

set -e
set -u
set -o pipefail

echo "Starting SAFE maximal system cleanup. Essential components will not be removed."

# 1. Update and Upgrade System
echo "Updating and upgrading system..."
export DEBIAN_FRONTEND=noninteractive
sudo apt update -y && sudo apt upgrade -y || true

# 2. Remove Unnecessary Packages and Dependencies
echo "Removing unused packages and dependencies..."
sudo apt autoremove --purge -y
sudo apt autoclean -y
sudo apt clean -y

# 3. Purge Residual Configurations
echo "Purging residual configurations..."
export DEBIAN_FRONTEND=noninteractive
sudo dpkg --configure -a || true
sudo dpkg -l | grep '^rc' | awk '{print $2}' | xargs -r sudo apt purge -y || true

# 4. Remove Logs, Cache, and Temporary Files
echo "Cleaning logs, caches, and temporary files..."
sudo find /var/log -type f -exec truncate -s 0 {} + 2>/dev/null || true
sudo find /var/log -name "*.gz" -exec rm -f {} + 2>/dev/null || true
sudo find /var/log -regex ".*\.[0-9]+" -exec rm -f {} + 2>/dev/null || true
sudo rm -rf /var/cache/* 2>/dev/null || true
sudo rm -rf ~/.cache/* 2>/dev/null || true
sudo rm -rf ~/.local/share/Trash/* 2>/dev/null || true
sudo rm -rf ~/.cache/thumbnails/* 2>/dev/null || true
sudo rm -rf /tmp/* /var/tmp/* 2>/dev/null || true

# 5. Remove Documentation, Manuals, and Info
echo "Removing documentation and manuals (optional)..."
sudo rm -rf /usr/share/man/* 2>/dev/null || true
sudo rm -rf /usr/share/doc/* 2>/dev/null || true
sudo rm -rf /usr/share/info/* 2>/dev/null || true
sudo rm -rf /usr/share/lintian/* 2>/dev/null || true
sudo rm -rf /usr/share/linda/* 2>/dev/null || true

# 6. Remove Python Bytecode and Cache
echo "Removing Python caches and bytecode..."
sudo find / -xdev -type f -name "*.pyc" -delete 2>/dev/null || true
sudo find / -xdev -type f -name "*.pyo" -delete 2>/dev/null || true
sudo find / -xdev -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true

# 7. Handle Broken Symbolic Links
echo "Removing broken symbolic links..."
sudo find / -xdev -xtype l -delete 2>/dev/null || true

# 8. Identify and Delete Large Files (Auto-delete without prompt)
echo "Removing files larger than 50MB to free up space..."
sudo find / -xdev -type f -size +50M ! -path "/proc/*" ! -path "/sys/*" ! -path "/dev/*" -exec rm -f {} + 2>/dev/null || true

# 9. Remove Snap Completely
echo "Removing Snap and its associated files..."
sudo systemctl stop snapd || true
sudo apt-get remove --purge -y snapd 2>/dev/null || true
sudo rm -rf /var/cache/snapd /var/snap /snap /root/snap /home/*/snap 2>/dev/null || true

# 10. Remove Docker Data (Optional)
if command -v docker &> /dev/null; then
    echo "Removing unused Docker data..."
    sudo docker system prune -a --volumes -f 2>/dev/null || echo "No Docker resources to clean."
fi

# 11. Zero-Fill Disk for WSL2 Compaction
echo "Zero-filling disk space for compaction..."
if [ -w / ]; then
  sudo dd if=/dev/zero of=/EMPTY bs=1M 2>/dev/null || true
  sudo rm -f /EMPTY 2>/dev/null || true
fi

# 12. Optimize Filesystem
if command -v e4defrag &> /dev/null; then
    echo "Defragmenting filesystem..."
    sudo e4defrag / 2>/dev/null || true
fi

# 13. Final Disk Usage
echo "Final disk usage:"
df -h

# Clean up additional system files
sudo rm -rf /var/lib/dpkg/info/* /var/lib/apt/lists/* /var/lib/polkit-1/* 2>/dev/null || true
sudo rm -rf /var/log/alternatives.log /usr/lib/x86_64-linux-gnu/dri/* \
           /usr/share/python-wheels/* /var/cache/apt/pkgcache.bin /var/cache/apt/srcpkgcache.bin 2>/dev/null || true

echo "Safe maximal cleanup completed. Essential components remain untouched."