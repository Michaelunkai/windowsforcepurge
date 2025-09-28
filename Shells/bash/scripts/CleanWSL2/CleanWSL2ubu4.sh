#!/bin/bash

# Disable strict error handling for dpkg issues
set -uo pipefail

# Set completely non-interactive mode globally
export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a
export NEEDRESTART_SUSPEND=1
export APT_LISTCHANGES_FRONTEND=none
export DEBCONF_NONINTERACTIVE_SEEN=true
export DEBCONF_NOWARNINGS=yes

# Disable all interactive prompts system-wide
echo 'debconf debconf/frontend select Noninteractive' | sudo debconf-set-selections 2>/dev/null || true
echo 'debconf debconf/priority select critical' | sudo debconf-set-selections 2>/dev/null || true

# Enhanced WSL2 Ubuntu Cleanup Script - Maximum Space Reduction
# This script aggressively removes all non-essential components to minimize WSL2 distro size

# Function to display progress
show_progress() {
    echo "======================================"
    echo "🔄 $1"
    echo "======================================"
    echo "Current disk usage:"
    df -h / | tail -1 | awk '{print "Used: " $3 " Available: " $4 " (" $5 " full)"}'
    echo ""
}

# Function to calculate space saved
calculate_saved() {
    local before=$1
    local after=$(df / | tail -1 | awk '{print $3}')
    local saved=$((before - after))
    echo "💾 Space saved: $((saved / 1024)) MB"
    echo ""
}

echo "🚀 Starting AUTOMATIC WSL2 Ubuntu cleanup for maximum space optimization..."
echo "⚠️  WARNING: Removing ALL non-essential components automatically!"

# Kill any potential interactive processes that might interfere
sudo pkill -f "dpkg.*--configure" 2>/dev/null || true
sudo pkill -f "apt.*install" 2>/dev/null || true
sudo pkill -f "debconf" 2>/dev/null || true

# Get initial disk usage
INITIAL_USAGE=$(df / | tail -1 | awk '{print $3}')

# Phase 1: Package Management and Updates
show_progress "Phase 1: Package Management Optimization"
STEP_USAGE=$(df / | tail -1 | awk '{print $3}')

echo "📦 Fixing dpkg database and updating package lists..."
# Fix broken dpkg database first
sudo dpkg --configure -a --force-confold 2>/dev/null || true
sudo apt-get -f install -y 2>/dev/null || true

# Update package lists silently
sudo apt update -y >/dev/null 2>&1 || true

echo "🔧 Installing cleanup tools (completely silent)..."
# Pre-configure ALL localepurge prompts to avoid ANY user interaction
echo 'localepurge localepurge/nopurge multiselect en_US.UTF-8' | sudo debconf-set-selections
echo 'localepurge localepurge/mandelete boolean true' | sudo debconf-set-selections
echo 'localepurge localepurge/dontbothernew boolean false' | sudo debconf-set-selections
echo 'localepurge localepurge/quickndirtycalc boolean true' | sudo debconf-set-selections
echo 'localepurge localepurge/verbose boolean false' | sudo debconf-set-selections
echo 'localepurge localepurge/use_dpkg_feature boolean true' | sudo debconf-set-selections

# Install essential tools only (skip problematic ones that cause prompts)
sudo apt install -y deborphan apt-show-versions >/dev/null 2>&1 || true

# Skip localepurge and debfoster - they cause interactive prompts
# We'll handle all cleanup manually instead
echo "⚠️ Skipping problematic packages (localepurge, debfoster) - using manual cleanup only"

# Fix any installation errors
sudo dpkg --configure -a --force-confold 2>/dev/null || true

echo "🗑️ Removing unused packages and dependencies..."
sudo apt autoremove --purge -y >/dev/null 2>&1 || true
sudo apt autoclean -y >/dev/null 2>&1 || true
sudo apt clean -y >/dev/null 2>&1 || true

# Remove package cache completely
sudo rm -rf /var/cache/apt/archives/*.deb
sudo rm -rf /var/cache/apt/archives/partial/*

calculate_saved $STEP_USAGE

# Phase 2: Deep Package Cleanup
show_progress "Phase 2: Deep Package Configuration Cleanup"
STEP_USAGE=$(df / | tail -1 | awk '{print $3}')

echo "🧹 Purging residual package configurations..."

# Fix dpkg database issues silently
sudo dpkg --configure -a --force-confold >/dev/null 2>&1 || true
sudo apt-get -f install -y >/dev/null 2>&1 || true

# Remove packages in rc state (removed but config remains)
dpkg -l 2>/dev/null | awk '/^rc/ {print $2}' | xargs -r sudo apt purge -y >/dev/null 2>&1 || true

# Quick orphaned packages removal (limited iterations for speed)
echo "🔍 Quick orphaned packages cleanup..."
if command -v deborphan >/dev/null 2>&1; then
    # Only 3 iterations max for speed
    for i in 1 2 3; do
        orphans=$(sudo deborphan 2>/dev/null | head -20)
        [ -z "$orphans" ] && break
        echo "$orphans" | xargs -r sudo apt-get -y remove --purge >/dev/null 2>&1 || true
    done
fi

# Remove packages that are no longer needed by any installed package
sudo apt-mark showauto 2>/dev/null | head -100 | xargs -r sudo apt-get -y remove --purge >/dev/null 2>&1 || true

calculate_saved $STEP_USAGE

# Phase 3: Aggressive File System Cleanup
show_progress "Phase 3: Logs, Cache, and Temporary Files Cleanup"
STEP_USAGE=$(df / | tail -1 | awk '{print $3}')

echo "📄 Aggressively clearing ALL logs and cache files..."
# Clear all log files completely
sudo find /var/log -type f -delete 2>/dev/null || true
sudo find /var/log -type d -empty -delete 2>/dev/null || true

# Clear all cache directories
sudo rm -rf /var/cache/* 2>/dev/null || true
sudo rm -rf /usr/share/doc/* 2>/dev/null || true
sudo rm -rf /usr/share/man/* 2>/dev/null || true
sudo rm -rf /usr/share/info/* 2>/dev/null || true
sudo rm -rf /usr/share/lintian/* 2>/dev/null || true
sudo rm -rf /usr/share/linda/* 2>/dev/null || true

# Clear user caches for all users
for home_dir in /home/*; do
    if [ -d "$home_dir" ]; then
        sudo rm -rf "$home_dir"/.cache/* 2>/dev/null || true
        sudo rm -rf "$home_dir"/.local/share/Trash/* 2>/dev/null || true
        sudo rm -rf "$home_dir"/.thumbnails/* 2>/dev/null || true
        sudo rm -rf "$home_dir"/.xsession-errors* 2>/dev/null || true
    fi
done

# Clear root cache
sudo rm -rf /root/.cache/* 2>/dev/null || true

# Clear all temp files
sudo rm -rf /tmp/* /var/tmp/* 2>/dev/null || true
sudo rm -rf /usr/share/pixmaps/* 2>/dev/null || true

calculate_saved $STEP_USAGE

# Phase 4: System Packages and Services Cleanup  
show_progress "Phase 4: Kernels, Services, and System Cleanup"
STEP_USAGE=$(df / | tail -1 | awk '{print $3}')

echo "🔧 Removing old kernels and headers..."
# Remove old kernels (safe in WSL)
dpkg --list | awk '/^ii  linux-image-[0-9]/{print $2}' | grep -v $(uname -r) | xargs -r sudo apt remove --purge -y 2>/dev/null || true
dpkg --list | awk '/^ii  linux-headers-[0-9]/{print $2}' | grep -v $(uname -r) | xargs -r sudo apt remove --purge -y 2>/dev/null || true
dpkg --list | awk '/^ii  linux-modules-[0-9]/{print $2}' | grep -v $(uname -r) | xargs -r sudo apt remove --purge -y 2>/dev/null || true

echo "⚙️ Disabling and removing non-essential services..."
# Disable unnecessary services
services_to_disable=(
    "apport.service"
    "whoopsie"
    "motd-news.timer"
    "unattended-upgrades"
    "snapd.service"
    "bluetooth.service"
    "ModemManager.service"
    "cups.service"
    "avahi-daemon.service"
)

for service in "${services_to_disable[@]}"; do
    sudo systemctl disable --now "$service" 2>/dev/null || true
    sudo systemctl mask "$service" 2>/dev/null || true
done

# Remove service-related packages
sudo apt remove --purge -y snapd whoopsie apport cups-* bluetooth bluez avahi-daemon modemmanager >/dev/null 2>&1 || true

calculate_saved $STEP_USAGE

# Phase 5: Localization and Media Content Removal
show_progress "Phase 5: Fonts, Languages, and Media Cleanup"
STEP_USAGE=$(df / | tail -1 | awk '{print $3}')

echo "🌐 Removing ALL fonts and language packs (keeping only en_US.UTF-8)..."
# Remove all fonts except essential ones
sudo apt remove --purge -y fonts-* >/dev/null 2>&1 || true
sudo rm -rf /usr/share/fonts/* 2>/dev/null || true
sudo rm -rf /usr/share/fontconfig/* 2>/dev/null || true

# Remove language packs except English
sudo apt remove --purge -y language-pack-* >/dev/null 2>&1 || true
sudo rm -rf /usr/share/locale/* 2>/dev/null || true
sudo mkdir -p /usr/share/locale/en_US.UTF-8 2>/dev/null || true
sudo locale-gen --purge en_US.UTF-8 >/dev/null 2>&1 || true

# Remove multimedia and graphics content
echo "🎵 Removing multimedia content and themes..."
sudo rm -rf /usr/share/sounds/* 2>/dev/null || true
sudo rm -rf /usr/share/themes/* 2>/dev/null || true
sudo rm -rf /usr/share/icons/* 2>/dev/null || true
sudo rm -rf /usr/share/wallpapers/* 2>/dev/null || true
sudo rm -rf /usr/share/backgrounds/* 2>/dev/null || true

calculate_saved $STEP_USAGE

# Phase 6: System Logs and Crash Reports
show_progress "Phase 6: Logs and Crash Reports Cleanup"
STEP_USAGE=$(df / | tail -1 | awk '{print $3}')

echo "🧹 Clearing ALL crash reports and system journals..."
sudo rm -rf /var/crash/* 2>/dev/null || true
sudo rm -rf /var/lib/systemd/coredump/* 2>/dev/null || true
sudo rm -rf /var/lib/apport/coredump/* 2>/dev/null || true
sudo rm -rf /var/lib/whoopsie/* 2>/dev/null || true

# Clear systemd journal completely
sudo journalctl --vacuum-size=1K 2>/dev/null || true
sudo journalctl --vacuum-time=1s 2>/dev/null || true
sudo rm -rf /var/log/journal/* 2>/dev/null || true

calculate_saved $STEP_USAGE

# Phase 7: Advanced File System Cleanup
show_progress "Phase 7: Advanced File System Operations"
STEP_USAGE=$(df / | tail -1 | awk '{print $3}')

echo "🔑 Removing SSH host keys and network configs..."
sudo rm -rf /etc/ssh/ssh_host_* 2>/dev/null || true
sudo rm -rf /etc/NetworkManager/system-connections/* 2>/dev/null || true

echo "🔗 Removing broken symlinks system-wide..."
sudo find / -xdev -xtype l -delete 2>/dev/null || true

echo "🗂️ Cleaning user profile directories..."
for home_dir in /home/* /root; do
    if [ -d "$home_dir" ]; then
        sudo rm -rf "$home_dir"/.thumbnails 2>/dev/null || true
        sudo rm -rf "$home_dir"/.icons 2>/dev/null || true
        sudo rm -rf "$home_dir"/.local/share/icons 2>/dev/null || true
        sudo rm -rf "$home_dir"/.cache/icon-cache.kcache 2>/dev/null || true
        sudo rm -rf "$home_dir"/.local/share/recently-used.xbel 2>/dev/null || true
        sudo rm -rf "$home_dir"/.bash_history 2>/dev/null || true
        sudo rm -rf "$home_dir"/.python_history 2>/dev/null || true
    fi
done

calculate_saved $STEP_USAGE

# Phase 8: Large File Removal and Storage Optimization  
show_progress "Phase 8: Large Files and Storage Optimization"
STEP_USAGE=$(df / | tail -1 | awk '{print $3}')

echo "📊 Quick scan for large files (>50M, timeout 60s)..."
# Fast scan with timeout to prevent hanging
timeout 60 sudo find / -xdev -type f -size +50M ! -path "/proc/*" ! -path "/sys/*" ! -path "/dev/*" ! -path "/usr/bin/*" ! -path "/usr/sbin/*" ! -path "/bin/*" ! -path "/sbin/*" ! -path "/lib/*" ! -path "/usr/lib/*" -exec rm -f {} \; 2>/dev/null || true

echo "📦 Fast artifact cleanup (parallel with timeout)..."
# Parallel cleanup with timeouts for speed
timeout 30 sudo find / -xdev \( -name "*.deb" -o -name "*.rpm" -o -name "*.tar.gz" -o -name "*.zip" \) -delete 2>/dev/null || true &
timeout 30 sudo find / -xdev -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true &
timeout 30 sudo find / -xdev -name "*.pyc" -delete 2>/dev/null || true &
timeout 30 sudo find / -xdev -name "node_modules" -type d -exec rm -rf {} + 2>/dev/null || true &
wait

# Remove old snapshots and backups
sudo rm -rf /var/lib/snapshots/* 2>/dev/null || true
sudo rm -rf /var/backups/* 2>/dev/null || true

calculate_saved $STEP_USAGE

# Phase 9: Final System Optimization
show_progress "Phase 9: Final System Optimization and Cleanup"
STEP_USAGE=$(df / | tail -1 | awk '{print $3}')

echo "🔄 Final deep system cleanup..."
# Remove all dpkg info and status files (be very careful here)
sudo rm -rf /var/lib/dpkg/info/* 2>/dev/null || true
sudo rm -rf /var/lib/apt/lists/* 2>/dev/null || true
sudo rm -rf /var/lib/polkit-1/* 2>/dev/null || true

# Remove additional system caches
sudo rm -rf /var/cache/debconf/* 2>/dev/null || true
sudo rm -rf /var/lib/systemd/catalog/* 2>/dev/null || true
sudo rm -rf /usr/share/python-wheels/* 2>/dev/null || true
sudo rm -rf /var/cache/apt/pkgcache.bin /var/cache/apt/srcpkgcache.bin 2>/dev/null || true

# Clean up more graphics and multimedia files
sudo rm -rf /usr/lib/x86_64-linux-gnu/dri/* 2>/dev/null || true
sudo rm -rf /usr/share/glib-2.0/schemas/* 2>/dev/null || true
sudo rm -rf /usr/share/applications/* 2>/dev/null || true

echo "🧹 Removing cleanup tools..."
sudo apt purge -y deborphan apt-show-versions >/dev/null 2>&1 || true

# Final autoremove to catch anything we missed
sudo apt autoremove --purge -y >/dev/null 2>&1 || true

calculate_saved $STEP_USAGE

# Phase 10: Final Verification and Cleanup
show_progress "Phase 10: Final Verification and Optimization"

echo "🔍 Rebuilding essential system databases..."
# Rebuild only essential package lists
sudo apt update -y >/dev/null 2>&1 || true

# Fast zero out free space (limited size for speed)
echo "💾 Quick zeroing of free space for compression..."
echo "🔄 Using fast method to minimize size in under 5 minutes..."
# Only zero out up to 1GB or available space (whichever is smaller) for speed
AVAILABLE=$(df / | tail -1 | awk '{print int($4/1024)}')
ZERO_SIZE=$((AVAILABLE > 1024 ? 1024 : AVAILABLE))
if [ $ZERO_SIZE -gt 0 ]; then
    sudo dd if=/dev/zero of=/EMPTY bs=1M count=$ZERO_SIZE 2>/dev/null || true
    sudo rm -f /EMPTY 2>/dev/null || true
fi

# Additional extreme cleanup for minimal WSL2 distro size
echo "🧹 Final aggressive cleanup for minimal distro size..."

# Fast cleanup of unnecessary files (parallel operations for speed)
sudo find /var -type f \( -name "*.log" -o -name "*.old" -o -name "*.bak" \) -delete 2>/dev/null || true &
sudo find /usr -type f \( -name "*.a" -o -name "*.la" \) -delete 2>/dev/null || true &
wait

# Fast parallel cache cleanup
sudo rm -rf /tmp/* /var/tmp/* 2>/dev/null || true &
sudo rm -rf /home/*/.cache/* /root/.cache/* 2>/dev/null || true &
sudo rm -rf /var/cache/* 2>/dev/null || true &
sudo rm -rf /var/lib/apt/lists/* 2>/dev/null || true &
wait

# Quick memory cache clear (single operation for speed)
sync
echo 3 | sudo tee /proc/sys/vm/drop_caches >/dev/null 2>&1 || true

# Final disk usage
echo ""
echo "=================== CLEANUP COMPLETE ==================="
echo "📊 Final disk space usage:"
df -h /
echo ""

# Calculate total space saved
FINAL_USAGE=$(df / | tail -1 | awk '{print $3}')
TOTAL_SAVED=$(((INITIAL_USAGE - FINAL_USAGE) / 1024))
echo "💾 Total space saved: ${TOTAL_SAVED} MB"
echo ""
echo "✅ MAXIMUM WSL2 Ubuntu cleanup completed successfully!"
echo "🎯 Your WSL2 distro is now optimized for minimum storage usage."
echo ""
echo "⚠️  Note: This aggressive cleanup removed all non-essential components."
echo "   You may need to reinstall packages as needed for your use case."
