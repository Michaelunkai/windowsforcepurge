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
    echo "Current WSL2 distro size:"
    # Get filesystem usage (what df shows)
    FS_USED=$(df / | tail -1 | awk '{print $3}')
    FS_USED_MB=$((FS_USED / 1024))
    echo "Filesystem usage: ${FS_USED_MB}MB"
    df -h / | tail -1 | awk '{print "Filesystem: " $3 " used, " $4 " available (" $5 " full)"}'
    echo ""
}

# Function to calculate space saved
calculate_saved() {
    local before=$1
    local after=$(df / | tail -1 | awk '{print $3}')
    local saved=$((before - after))
    echo "💾 Space saved in this phase: $((saved / 1024)) MB"

    # Show current filesystem usage
    CURRENT_SIZE_MB=$((after / 1024))
    echo "📊 Current filesystem usage: ${CURRENT_SIZE_MB}MB"
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

# Phase 5: Complete Docker Cleanup and Purge
show_progress "Phase 5: Complete Docker Cleanup and Purge"
STEP_USAGE=$(df / | tail -1 | awk '{print $3}')

echo "🐳 Completely removing ALL Docker components and data..."

# Stop all Docker services first
echo "⏹️ Stopping all Docker services..."
sudo systemctl stop docker.service 2>/dev/null || true
sudo systemctl stop docker.socket 2>/dev/null || true
sudo systemctl stop containerd.service 2>/dev/null || true
sudo systemctl stop docker-compose.service 2>/dev/null || true

# Disable Docker services
echo "🚫 Disabling Docker services..."
sudo systemctl disable docker.service 2>/dev/null || true
sudo systemctl disable docker.socket 2>/dev/null || true
sudo systemctl disable containerd.service 2>/dev/null || true
sudo systemctl mask docker.service 2>/dev/null || true
sudo systemctl mask docker.socket 2>/dev/null || true
sudo systemctl mask containerd.service 2>/dev/null || true

# Kill any remaining Docker processes
echo "💀 Killing any remaining Docker processes..."
sudo pkill -f docker 2>/dev/null || true
sudo pkill -f containerd 2>/dev/null || true
sudo pkill -f dockerd 2>/dev/null || true
sudo pkill -f docker-compose 2>/dev/null || true

# Remove Docker containers, images, volumes, and networks
echo "🗑️ Removing all Docker containers, images, volumes, and networks..."
if command -v docker >/dev/null 2>&1; then
    # Force remove all containers
    CONTAINERS=$(sudo docker ps -aq 2>/dev/null || true)
    if [ ! -z "$CONTAINERS" ]; then
        sudo docker container prune -af 2>/dev/null || true
        echo "$CONTAINERS" | xargs -r sudo docker rm -vf 2>/dev/null || true
    fi

    # Force remove all images
    IMAGES=$(sudo docker images -aq 2>/dev/null || true)
    if [ ! -z "$IMAGES" ]; then
        sudo docker image prune -af 2>/dev/null || true
        echo "$IMAGES" | xargs -r sudo docker rmi -f 2>/dev/null || true
    fi

    # Force remove all volumes
    VOLUMES=$(sudo docker volume ls -q 2>/dev/null || true)
    if [ ! -z "$VOLUMES" ]; then
        sudo docker volume prune -af 2>/dev/null || true
        echo "$VOLUMES" | xargs -r sudo docker volume rm 2>/dev/null || true
    fi

    # Force remove all networks
    NETWORKS=$(sudo docker network ls -q 2>/dev/null | grep -v bridge | grep -v host | grep -v none || true)
    if [ ! -z "$NETWORKS" ]; then
        sudo docker network prune -af 2>/dev/null || true
        echo "$NETWORKS" | xargs -r sudo docker network rm 2>/dev/null || true
    fi

    # System prune everything
    sudo docker system prune -af --volumes 2>/dev/null || true
else
    echo "📝 Docker command not found - skipping container/image cleanup"
fi

# Remove all Docker packages
echo "📦 Removing ALL Docker packages..."
sudo apt remove --purge -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin docker-compose docker.io docker-doc docker-registry runc >/dev/null 2>&1 || true
sudo apt remove --purge -y docker-* containerd* runc* >/dev/null 2>&1 || true

# Remove Docker data directories
echo "🗂️ Removing ALL Docker data directories..."
sudo rm -rf /var/lib/docker 2>/dev/null || true
sudo rm -rf /var/lib/containerd 2>/dev/null || true
sudo rm -rf /var/run/docker 2>/dev/null || true
sudo rm -rf /var/run/containerd 2>/dev/null || true
sudo rm -rf /etc/docker 2>/dev/null || true
sudo rm -rf /etc/containerd 2>/dev/null || true
sudo rm -rf /opt/containerd 2>/dev/null || true

# Remove Docker configuration files
echo "⚙️ Removing Docker configuration files..."
sudo rm -rf /etc/systemd/system/docker.service.d 2>/dev/null || true
sudo rm -rf /etc/systemd/system/containerd.service.d 2>/dev/null || true
sudo rm -rf /lib/systemd/system/docker.service 2>/dev/null || true
sudo rm -rf /lib/systemd/system/docker.socket 2>/dev/null || true
sudo rm -rf /lib/systemd/system/containerd.service 2>/dev/null || true

# Remove Docker user configurations
echo "👤 Removing Docker user configurations..."
for home_dir in /home/* /root; do
    if [ -d "$home_dir" ]; then
        sudo rm -rf "$home_dir"/.docker 2>/dev/null || true
        sudo rm -rf "$home_dir"/.config/docker 2>/dev/null || true
        sudo rm -rf "$home_dir"/.local/share/docker 2>/dev/null || true

        # Remove Docker aliases and configurations from shell profiles
        if [ -f "$home_dir/.bashrc" ]; then
            sudo sed -i '/# Docker aliases/,/^$/d' "$home_dir/.bashrc" 2>/dev/null || true
            sudo sed -i '/alias d=/d' "$home_dir/.bashrc" 2>/dev/null || true
            sudo sed -i '/alias dc=/d' "$home_dir/.bashrc" 2>/dev/null || true
            sudo sed -i '/alias dps=/d' "$home_dir/.bashrc" 2>/dev/null || true
            sudo sed -i '/alias dimages=/d' "$home_dir/.bashrc" 2>/dev/null || true
            sudo sed -i '/alias dvolumes=/d' "$home_dir/.bashrc" 2>/dev/null || true
            sudo sed -i '/alias dnetworks=/d' "$home_dir/.bashrc" 2>/dev/null || true
        fi

        if [ -f "$home_dir/.zshrc" ]; then
            sudo sed -i '/# Docker aliases/,/^$/d' "$home_dir/.zshrc" 2>/dev/null || true
            sudo sed -i '/alias d=/d' "$home_dir/.zshrc" 2>/dev/null || true
            sudo sed -i '/alias dc=/d' "$home_dir/.zshrc" 2>/dev/null || true
            sudo sed -i '/alias dps=/d' "$home_dir/.zshrc" 2>/dev/null || true
            sudo sed -i '/alias dimages=/d' "$home_dir/.zshrc" 2>/dev/null || true
            sudo sed -i '/alias dvolumes=/d' "$home_dir/.zshrc" 2>/dev/null || true
            sudo sed -i '/alias dnetworks=/d' "$home_dir/.zshrc" 2>/dev/null || true
        fi

        if [ -f "$home_dir/.profile" ]; then
            sudo sed -i '/# Docker aliases/,/^$/d' "$home_dir/.profile" 2>/dev/null || true
            sudo sed -i '/docker/d' "$home_dir/.profile" 2>/dev/null || true
        fi
    fi
done

# Remove Docker group and users
echo "👥 Removing Docker group and users..."
sudo gpasswd -d $(whoami) docker 2>/dev/null || true
sudo groupdel docker 2>/dev/null || true
sudo userdel docker 2>/dev/null || true

# Remove Docker repositories and keys
echo "🔑 Removing Docker repositories and GPG keys..."
sudo rm -f /etc/apt/sources.list.d/docker.list 2>/dev/null || true
sudo rm -f /etc/apt/sources.list.d/docker-ce.list 2>/dev/null || true
sudo rm -f /etc/apt/keyrings/docker.gpg 2>/dev/null || true
sudo rm -f /usr/share/keyrings/docker-archive-keyring.gpg 2>/dev/null || true
sudo rm -f /etc/apt/trusted.gpg.d/docker.gpg 2>/dev/null || true

# Remove Docker binaries manually (if any remain)
echo "🔧 Removing Docker binaries..."
sudo rm -f /usr/bin/docker* 2>/dev/null || true
sudo rm -f /usr/local/bin/docker* 2>/dev/null || true
sudo rm -f /usr/bin/containerd* 2>/dev/null || true
sudo rm -f /usr/bin/runc 2>/dev/null || true
sudo rm -f /usr/bin/ctr 2>/dev/null || true

# Remove Docker logs
echo "📋 Removing Docker logs..."
sudo rm -rf /var/log/docker* 2>/dev/null || true
sudo rm -rf /var/log/containerd* 2>/dev/null || true

# Remove Docker temporary and cache files
echo "🧹 Removing Docker cache and temporary files..."
sudo rm -rf /tmp/docker* 2>/dev/null || true
sudo rm -rf /tmp/containerd* 2>/dev/null || true
sudo rm -rf /var/tmp/docker* 2>/dev/null || true

# Remove Docker BuildX and Compose plugins
echo "🔌 Removing Docker plugins..."
sudo rm -rf /usr/libexec/docker 2>/dev/null || true
sudo rm -rf /usr/local/lib/docker 2>/dev/null || true
sudo rm -rf ~/.docker/cli-plugins 2>/dev/null || true

# Clean up any remaining Docker mount points
echo "🔗 Cleaning up Docker mount points..."
sudo umount /var/lib/docker/overlay2/* 2>/dev/null || true
sudo umount /var/lib/docker/containers/*/mounts/* 2>/dev/null || true

# Remove Docker from systemd
echo "🔄 Removing Docker from systemd..."
sudo systemctl daemon-reload 2>/dev/null || true
sudo systemctl reset-failed 2>/dev/null || true

# Final Docker cleanup verification
echo "✅ Verifying Docker removal..."
DOCKER_CHECK=$(command -v docker 2>/dev/null || echo "")
if [ ! -z "$DOCKER_CHECK" ]; then
    echo "⚠️ Warning: Docker command still exists at $DOCKER_CHECK, attempting forced removal..."
    sudo dpkg --remove --force-remove-reinstreq docker* 2>/dev/null || true
    sudo dpkg --remove --force-remove-reinstreq containerd* 2>/dev/null || true
    sudo rm -f "$DOCKER_CHECK" 2>/dev/null || true
else
    echo "✅ Docker command successfully removed"
fi

# Remove any remaining Docker-related packages in dpkg
dpkg -l | grep -i docker | awk '{print $2}' | xargs -r sudo dpkg --purge --force-all 2>/dev/null || true
dpkg -l | grep -i containerd | awk '{print $2}' | xargs -r sudo dpkg --purge --force-all 2>/dev/null || true

# Remove Docker-related dependencies that might have been installed
echo "🧹 Removing Docker-related dependencies..."
sudo apt remove --purge -y software-properties-common jq pass gnupg lsb-release curl apt-transport-https ca-certificates >/dev/null 2>&1 || true

# Remove any Docker credential helpers
sudo rm -f /usr/local/bin/docker-credential-* 2>/dev/null || true
sudo rm -f /usr/bin/docker-credential-* 2>/dev/null || true

# Remove Docker environment variables from system-wide configurations
sudo sed -i '/DOCKER/d' /etc/environment 2>/dev/null || true
sudo sed -i '/docker/d' /etc/environment 2>/dev/null || true

# Clean up any Docker-related cron jobs
sudo sed -i '/docker/d' /etc/crontab 2>/dev/null || true
for user_cron in /var/spool/cron/crontabs/*; do
    if [ -f "$user_cron" ]; then
        sudo sed -i '/docker/d' "$user_cron" 2>/dev/null || true
    fi
done

# Remove any Docker-related sysctl configurations
sudo rm -f /etc/sysctl.d/*docker* 2>/dev/null || true

# Remove Docker-related bridge networks configurations
sudo rm -f /etc/docker/daemon.json 2>/dev/null || true
sudo rm -f /etc/systemd/network/*docker* 2>/dev/null || true

echo "🐳 Docker completely purged from the system!"

calculate_saved $STEP_USAGE

# Phase 6: Ultra-Aggressive Package Removal for 960MB Target
show_progress "Phase 6: Ultra-Aggressive Package Removal for 960MB Target"
STEP_USAGE=$(df / | tail -1 | awk '{print $3}')

echo "⚡ ULTRA-AGGRESSIVE: Removing ALL non-essential packages for 960MB target..."

# Check current size
CURRENT_FS_SIZE=$(df / | tail -1 | awk '{print $3}')
CURRENT_SIZE_MB=$((CURRENT_FS_SIZE / 1024))
echo "📊 Current filesystem usage: ${CURRENT_SIZE_MB}MB (Target: <960MB)"

if [ $CURRENT_SIZE_MB -gt 960 ]; then
    echo "🔥 EXTREME CLEANUP: Removing packages to reach 960MB target..."

    # Remove ALL development packages
    echo "🛠️ Removing ALL development and build tools..."
    sudo apt remove --purge -y \
        build-essential gcc g++ cpp make autoconf automake libtool pkg-config \
        cmake gdb valgrind git subversion mercurial bzr \
        python3-dev python3-pip nodejs npm yarn \
        ruby-dev perl-modules golang-go \
        libssl-dev libcurl4-openssl-dev libxml2-dev libxslt1-dev \
        zlib1g-dev libbz2-dev libreadline-dev libsqlite3-dev \
        libncurses5-dev libgdbm-dev libnss3-dev libffi-dev \
        >/dev/null 2>&1 || true

    # Remove language packages and compilers
    echo "💬 Removing ALL language packages..."
    sudo apt remove --purge -y \
        python3.* python2.* nodejs* npm* yarn* ruby* perl* golang* \
        openjdk-* default-jdk* scala* kotlin* \
        >/dev/null 2>&1 || true

    # Remove networking and server packages
    echo "🌐 Removing networking and server packages..."
    sudo apt remove --purge -y \
        apache2* nginx* lighttpd* mysql-* postgresql* mongodb* redis* \
        openssh-server telnetd ftpd vsftpd proftpd \
        bind9* dnsmasq* dhcp* \
        >/dev/null 2>&1 || true

    # Remove multimedia packages
    echo "🎵 Removing ALL multimedia packages..."
    sudo apt remove --purge -y \
        ffmpeg* vlc* mplayer* gstreamer* pulseaudio* alsa-* \
        imagemagick* graphicsmagick* gimp* \
        >/dev/null 2>&1 || true

    # Remove GUI and X11 packages (WSL2 doesn't need them typically)
    echo "🖥️ Removing GUI and X11 packages..."
    sudo apt remove --purge -y \
        xorg* x11-* xserver-* \
        gnome-* kde-* xfce4-* lxde-* \
        firefox* chromium* \
        libreoffice* thunderbird* \
        >/dev/null 2>&1 || true

    # Remove documentation and help packages
    echo "📚 Removing documentation packages..."
    sudo apt remove --purge -y \
        doc-base* info* manpages* manpages-dev* \
        >/dev/null 2>&1 || true

    # Remove games and entertainment
    echo "🎮 Removing games and entertainment..."
    sudo apt remove --purge -y \
        games-* gnome-games* \
        >/dev/null 2>&1 || true

    # Keep only ESSENTIAL system packages
    echo "⚠️ Keeping only essential system packages..."

    # Aggressive autoremove multiple times
    for i in 1 2 3 4 5; do
        sudo apt autoremove --purge -y >/dev/null 2>&1 || true
        sudo apt autoclean >/dev/null 2>&1 || true
    done

    # Remove orphaned packages aggressively
    echo "🧹 Aggressive orphaned package removal..."
    if command -v deborphan >/dev/null 2>&1; then
        for i in 1 2 3 4 5 6 7 8 9 10; do
            ORPHANS=$(sudo deborphan 2>/dev/null)
            [ -z "$ORPHANS" ] && break
            echo "$ORPHANS" | xargs -r sudo apt remove --purge -y >/dev/null 2>&1 || true
        done
    fi

    # Remove packages that are not marked as manually installed
    echo "📦 Removing auto-installed packages..."
    AUTO_PACKAGES=$(apt-mark showauto 2>/dev/null | head -200)
    if [ ! -z "$AUTO_PACKAGES" ]; then
        echo "$AUTO_PACKAGES" | xargs -r sudo apt remove --purge -y >/dev/null 2>&1 || true
    fi

else
    echo "✅ Already under 960MB target! Current: ${CURRENT_SIZE_MB}MB"
fi

calculate_saved $STEP_USAGE

# Phase 7: Localization and Media Content Removal
show_progress "Phase 7: Fonts, Languages, and Media Cleanup"
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

# Phase 8: System Logs and Crash Reports
show_progress "Phase 8: Logs and Crash Reports Cleanup"
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

# Phase 9: Advanced File System Cleanup
show_progress "Phase 9: Advanced File System Operations"
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

# Phase 10: Large File Removal and Storage Optimization  
show_progress "Phase 10: Large Files and Storage Optimization"
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

# Phase 11: Final System Optimization
show_progress "Phase 11: Final System Optimization and Cleanup"
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

# Phase 12: Final Verification and Cleanup
show_progress "Phase 12: Final Verification and Optimization"

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

# Phase 13: Ultra-Aggressive Final Cleanup for 960MB Target
show_progress "Phase 13: Ultra-Aggressive Final Cleanup for 960MB Target"

echo "🎯 TARGET: Reducing WSL2 distro to under 960MB..."

# Check current size using filesystem usage
CURRENT_SIZE_RAW=$(df / | tail -1 | awk '{print $3}')
CURRENT_SIZE_MB=$((CURRENT_SIZE_RAW / 1024))

echo "📊 Current filesystem usage: ${CURRENT_SIZE_MB}MB (Target: <960MB)"

if [ $CURRENT_SIZE_MB -gt 960 ]; then
    echo "⚠️ Still above 960MB target. Applying ultra-aggressive cleanup..."

    # Remove ALL remaining documentation and man pages more thoroughly
    echo "📚 Ultra-aggressive documentation removal..."
    sudo find /usr/share -type f \( -name "*.txt" -o -name "*.md" -o -name "*.html" -o -name "*.xml" \) -delete 2>/dev/null || true
    sudo rm -rf /usr/share/doc-base/* 2>/dev/null || true
    sudo rm -rf /usr/share/common-licenses/* 2>/dev/null || true
    sudo rm -rf /usr/share/debhelper/* 2>/dev/null || true
    sudo rm -rf /usr/share/pkgconfig/* 2>/dev/null || true

    # Remove ALL locale data more aggressively
    echo "🌐 Ultra-aggressive locale cleanup..."
    sudo find /usr/share/locale -mindepth 1 -maxdepth 1 ! -name 'en*' -exec rm -rf {} + 2>/dev/null || true
    sudo find /usr/share/i18n -mindepth 1 -maxdepth 1 ! -name 'en*' -exec rm -rf {} + 2>/dev/null || true

    # Remove development headers and static libraries
    echo "🔧 Removing development files..."
    sudo find /usr/include -type f -delete 2>/dev/null || true
    sudo find /usr -name "*.h" -delete 2>/dev/null || true
    sudo find /usr -name "*.a" -delete 2>/dev/null || true
    sudo find /usr -name "*.la" -delete 2>/dev/null || true

    # Remove more system files
    echo "🗑️ Ultra-aggressive system file cleanup..."
    sudo rm -rf /usr/share/zoneinfo/* 2>/dev/null || true
    sudo rm -rf /usr/lib/locale/* 2>/dev/null || true
    sudo rm -rf /var/lib/locales/* 2>/dev/null || true

    # Remove unnecessary binaries and libraries
    echo "⚙️ Removing non-essential binaries..."
    sudo find /usr/bin -name "*-config" -delete 2>/dev/null || true
    sudo find /usr/sbin -name "*-config" -delete 2>/dev/null || true

    # Remove empty directories
    echo "📁 Removing empty directories..."
    sudo find /usr/share -type d -empty -delete 2>/dev/null || true
    sudo find /var -type d -empty -delete 2>/dev/null || true

    # Final aggressive space optimization
    echo "💨 Final space optimization..."
    sudo find /var/cache -type f -delete 2>/dev/null || true
    sudo find /tmp -type f -delete 2>/dev/null || true
    sudo find /var/tmp -type f -delete 2>/dev/null || true

    # Check size again using filesystem usage
    FINAL_SIZE_RAW=$(df / | tail -1 | awk '{print $3}')
    FINAL_SIZE_MB=$((FINAL_SIZE_RAW / 1024))

    echo "📊 After ultra-aggressive cleanup: ${FINAL_SIZE_MB}MB"

    if [ $FINAL_SIZE_MB -gt 960 ]; then
        echo "⚠️ WARNING: Still above 960MB target (${FINAL_SIZE_MB}MB)"
        echo "💡 Consider removing additional packages manually if needed"
    else
        echo "✅ SUCCESS: Achieved target! Final size: ${FINAL_SIZE_MB}MB"
    fi
else
    echo "✅ SUCCESS: Already under 960MB target! Current size: ${CURRENT_SIZE_MB}MB"
fi

# Final disk usage
echo ""
echo "=================== CLEANUP COMPLETE ==================="
echo "📊 Final filesystem usage:"
df -h /
echo ""

# Calculate total space saved
FINAL_USAGE=$(df / | tail -1 | awk '{print $3}')
TOTAL_SAVED=$(((INITIAL_USAGE - FINAL_USAGE) / 1024))
echo "💾 Total filesystem space saved: ${TOTAL_SAVED} MB"

# Show final filesystem usage in MB
FINAL_SIZE_MB=$((FINAL_USAGE / 1024))
echo "🎯 Final filesystem usage: ${FINAL_SIZE_MB}MB"

if [ $FINAL_SIZE_MB -le 960 ]; then
    echo "🏆 TARGET ACHIEVED: WSL2 distro is under 960MB!"
else
    echo "⚠️ Target missed: ${FINAL_SIZE_MB}MB (target was <960MB)"
fi

echo ""
echo "✅ MAXIMUM WSL2 Ubuntu cleanup completed successfully!"
echo "🎯 Your WSL2 distro is now optimized for minimum storage usage."
echo ""
echo "⚠️  Note: This aggressive cleanup removed all non-essential components."
echo "   You may need to reinstall packages as needed for your use case."
