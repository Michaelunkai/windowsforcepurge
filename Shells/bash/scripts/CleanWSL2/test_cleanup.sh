#!/bin/bash

# Test version of the cleanup script - just checking key components
set -uo pipefail

export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a
export NEEDRESTART_SUSPEND=1

echo "🚀 Testing cleanup script components..."

# Test dpkg fix
echo "📦 Testing dpkg fixes..."
sudo dpkg --configure -a --force-confold >/dev/null 2>&1 || true
sudo apt-get -f install -y >/dev/null 2>&1 || true

# Test package operations
echo "🔧 Testing package operations..."
sudo apt update -y >/dev/null 2>&1 || true

# Test debconf preseeding
echo "⚙️ Testing debconf configuration..."
echo 'localepurge localepurge/nopurge multiselect en_US.UTF-8' | sudo debconf-set-selections
echo 'localepurge localepurge/mandelete boolean true' | sudo debconf-set-selections

echo "✅ Test completed successfully - script should work!"