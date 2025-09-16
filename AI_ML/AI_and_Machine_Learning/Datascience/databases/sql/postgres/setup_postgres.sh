#!/bin/bash
set -e

echo "Stopping and disabling PackageKit..."
systemctl stop packagekit.service || true
systemctl disable packagekit.service || true
systemctl mask packagekit.service || true

echo "Cleaning up problematic packages..."
# Remove problematic packages and their configs, allowing failures
apt-get -y remove --purge postgresql postgresql-* sysstat || true
apt-get -y autoremove --purge || true
apt-get -y clean || true

# Ensure apt lists are updated before any install attempts
echo "Updating apt package lists..."
apt-get update -o Acquire::Check-Valid-Until=false -o Acquire::Check-Date=false

# Reconfigure any remaining broken packages, forcing new config files
echo "Attempting to fix broken packages with --force-confnew..."
DEBIAN_FRONTEND=noninteractive apt-get -o Dpkg::Options::="--force-confnew" -f install -y || true

# Now, try the main PostgreSQL installation, forcing new config files
echo "Installing PostgreSQL with --force-confnew..."
DEBIAN_FRONTEND=noninteractive apt-get -o Dpkg::Options::="--force-confnew" install -yq postgresql postgresql-contrib

echo "Starting and enabling PostgreSQL service..."
# Start the PostgreSQL service
systemctl start postgresql

# Enable the PostgreSQL service to start on boot
systemctl enable postgresql

echo "PostgreSQL installation completed. Checking status..."
# Check the status of the PostgreSQL service
systemctl status postgresql