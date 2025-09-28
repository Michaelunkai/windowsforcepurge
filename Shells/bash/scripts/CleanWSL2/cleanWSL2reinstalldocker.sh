#!/usr/bin/env bash
###############################################################################
# fix_docker_wsl2.sh
#  - Phase 0: nuclear purge of ALL Docker artefacts
#  - Phase 1: deep WSL2 cleanup  (user-supplied)
#  - Phase 2: clean, conflict-free install (≤3 attempts)
# 2025-06-30
###############################################################################
set -euo pipefail
IFS=$'\n\t'
green(){ printf "\033[0;32m%s\033[0m\n" "$*"; }
yellow(){ printf "\033[1;33m%s\033[0m\n" "$*"; }
red(){ printf "\033[0;31m%s\033[0m\n" "$*"; }
die(){ red "[FAIL] $*"; exit 1; }
msg(){ green "[INFO] $*"; }
wrn(){ yellow "[WARN] $*"; }
retry(){ local n=0; until "$@"; do ((n++>3))&&return 1; sleep 2; wrn "retry $n/3: $*"; done; }

[[ $EUID -eq 0 ]] || die "Run with sudo."
grep -qi microsoft /proc/version || die "Not running in WSL2."

DISTRO=$(lsb_release -sc)              # jammy / noble …
ARCH=$(dpkg --print-architecture)      # amd64 / arm64 …
TARGET_USER=${SUDO_USER:-$(logname 2>/dev/null || echo root)}

###############################################################################
### Phase-0 : wipe EVERY Docker trace
###############################################################################
msg "Phase-0: purging all Docker artefacts"
{
  systemctl stop docker.service docker.socket containerd.service 2>/dev/null || true
  pkill -f dockerd-wsl2-wrapper 2>/dev/null || true
  pkill -f dockerd 2>/dev/null || true

  retry apt-get remove --purge -y docker\* containerd.io runc || true

  rm -rf /var/lib/docker /var/lib/containerd /run/containerd \
         /var/run/docker.sock /etc/docker /etc/containerd \
         /usr/libexec/docker /usr/lib/docker /var/log/dockerd-wsl2.log

  rm -f /etc/systemd/system/docker.service.d/override.conf
  rm -f /etc/systemd/system/docker.service /lib/systemd/system/docker.service
  rm -f /etc/systemd/system/docker.socket  /lib/systemd/system/docker.socket
  rm -f /etc/systemd/system/containerd.service /lib/systemd/system/containerd.service

  rm -f /usr/local/bin/dockerd-wsl2-wrapper
  sed -i '/dockerd-wsl2-wrapper/d' /etc/wsl.conf 2>/dev/null || true

  rm -f /etc/apt/sources.list.d/docker.list /etc/apt/keyrings/docker.gpg
  getent group docker &>/dev/null && groupdel docker || true
  rm -rf /home/*/.docker /root/.docker
} || true
msg "Docker artefacts purged."

###############################################################################
### Phase-1 : deep system cleanup (verbatim)
###############################################################################
echo "Starting deep system cleanup for Ubuntu WSL2…"
export DEBIAN_FRONTEND=noninteractive
# First fix network resolution by regenerating resolv.conf
echo "nameserver 8.8.8.8" | tee /etc/resolv.conf > /dev/null
echo "nameserver 8.8.4.4" | tee -a /etc/resolv.conf > /dev/null

# Update package lists with retry in case of network issues
retry apt update -y || true
retry apt upgrade -y || true

# Install deborphan if it's available, otherwise skip
if apt-cache search deborphan | grep -q deborphan; then
    apt install -y deborphan
    DEBORPHAN_AVAILABLE=1
else
    echo "deborphan not available, will skip later usage"
    DEBORPHAN_AVAILABLE=0
fi

apt autoremove --purge -y
apt autoclean -y
apt clean -y
dpkg --configure -a
dpkg -l | awk '/^rc/{print $2}' | xargs -r apt purge -y
find /var/log -type f -exec truncate -s0 {} +
find /var/log -name "*.gz" -delete
find /var/log -regextype posix-extended -regex '.*/[0-9]+' -delete
rm -rf /var/cache/* ~/.cache/* ~/.local/share/Trash/* ~/.cache/thumbnails/*
rm -rf /tmp/* /var/tmp/*
apt remove --purge -y $(dpkg -l | awk '/^ii  linux-image-[0-9]/{print $2}'|grep -v $(uname -r)) 2>/dev/null || true
if [ $DEBORPHAN_AVAILABLE -eq 1 ]; then
    deborphan | xargs -r apt-get -y remove --purge
fi
systemctl disable --now apport.service whoopsie motd-news.timer unattended-upgrades || true
apt remove --purge -y fonts-* language-pack-* 2>/dev/null || true
rm -rf /usr/share/man /usr/share/doc /usr/share/info /usr/share/lintian /usr/share/linda 2>/dev/null || true
systemctl stop snapd || true && apt remove --purge -y snapd whoopsie 2>/dev/null || true
rm -rf /var/crash/* /var/lib/systemd/coredump/* /var/lib/apport/coredump/* ~/.xsession-errors* || true
journalctl --vacuum-time=1d || true
rm -rf /etc/ssh/ssh_host_* 2>/dev/null || true
find / -xdev -xtype l -delete 2>/dev/null || true
rm -rf ~/.thumbnails ~/.cache/thumbnails 2>/dev/null || true
locale-gen --purge en_US.UTF-8 2>/dev/null || true
find / -xdev -type f -size +50M ! -path "/proc/*" ! -path "/sys/*" ! -path "/dev/*" -delete 2>/dev/null || true
rm -rf ~/.icons ~/.local/share/icons ~/.cache/icon-cache.kcache 2>/dev/null || true
rm -rf /var/lib/snapshots/* || true
command -v e4defrag &>/dev/null && e4defrag / || true
rm -rf /var/lib/apt/lists/*
retry apt update -y
df -h
rm -rf /var/lib/dpkg/info/* /var/lib/apt/lists/* /var/lib/polkit-1/* 2>/dev/null || true
rm -rf /var/log/alternatives.log /usr/lib/x86_64-linux-gnu/dri/* \
            /usr/share/python-wheels/* /var/cache/apt/pkgcache.bin /var/cache/apt/srcpkgcache.bin 2>/dev/null || true
if [ $DEBORPHAN_AVAILABLE -eq 1 ]; then
    apt purge -y deborphan
fi
echo "✅ Deep WSL2 cleanup completed!"

###############################################################################
### Phase-2 : install Docker, avoid hosts conflict, verify
###############################################################################
install_once() {
  local attempt=$1
  msg "▶️  Install attempt $attempt / 3"

  dpkg --configure -a >/dev/null || true
  retry apt-get -f install -y || true
  retry apt-get update -y || true  # Added || true to prevent failure
  retry apt-get install -y --no-install-recommends \
        ca-certificates curl gnupg iproute2 iptables util-linux net-tools lsb-release || true
  
  # Set iptables alternatives non-interactively
  update-alternatives --set iptables  /usr/sbin/iptables-legacy  2>/dev/null || true
  update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy 2>/dev/null || true

  install -m0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
        gpg --dearmor -o /etc/apt/keyrings/docker.gpg 2>/dev/null || die "Failed to download Docker GPG key"
  chmod a+r /etc/apt/keyrings/docker.gpg
  echo "deb [arch=${ARCH} signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/ubuntu ${DISTRO} stable" \
      > /etc/apt/sources.list.d/docker.list
  retry apt-get update -y || die "Failed to update package lists after adding Docker repository"

  retry apt-get install -y docker-ce docker-ce-cli containerd.io \
        docker-buildx-plugin docker-compose-plugin || die "Failed to install Docker packages"

  # choose cgroup driver
  SYSTEMD=$(ps -p1 -o comm=)
  if [[ $SYSTEMD == systemd ]]; then
      CGROUP=systemd; CTD=true
  else
      CGROUP=cgroupfs; CTD=false
  fi

  # containerd config
  mkdir -p /etc/containerd
  if command -v containerd &>/dev/null; then
    containerd config default | sed "s/SystemdCgroup =.*/SystemdCgroup = ${CTD}/" \
        > /etc/containerd/config.toml
  else
    # Create default config if containerd command is not available
    cat > /etc/containerd/config.toml <<EOF
version = 2
[plugins]
  [plugins."io.containerd.grpc.v1.cri"]
    systemd_cgroup = ${CTD}
EOF
  fi

  # daemon.json WITHOUT "hosts"
  mkdir -p /etc/docker
  cat >/etc/docker/daemon.json <<JSON
{
  "storage-driver": "overlay2",
  "exec-opts": ["native.cgroupdriver=${CGROUP}"],
  "dns": ["8.8.8.8","8.8.4.4"],
  "features": { "buildkit": true }
}
JSON

  # explicit ExecStart override (removes default -H fd:// flag & adds our sockets)
  install -d /etc/systemd/system/docker.service.d
  cat >/etc/systemd/system/docker.service.d/override.conf <<EOF
[Service]
ExecStart=
ExecStart=/usr/bin/dockerd --host=unix:///var/run/docker.sock --host=tcp://0.0.0.0:2375 --containerd=/run/containerd/containerd.sock
EOF

  # wsl.conf
  cat >/etc/wsl.conf <<'CONF'
[network]
generateResolvConf = false

[boot]
systemd=true
CONF
  echo -e "nameserver 8.8.8.8\nnameserver 8.8.4.4" >/etc/resolv.conf

  need_wrapper=false
  if [[ $SYSTEMD == systemd ]]; then
      systemctl daemon-reload
      systemctl enable containerd.service docker.service docker.socket
      systemctl restart containerd.service
      systemctl restart docker.service || need_wrapper=true
  else
      need_wrapper=true
  fi

  if $need_wrapper; then
      wrn "Using wrapper (systemd will take over after wsl --shutdown)"
      cat >/usr/local/bin/dockerd-wsl2-wrapper <<WRAP
#!/usr/bin/env bash
set -euo pipefail
LOG=/var/log/dockerd-wsl2.log
while true; do
  /usr/bin/dockerd --exec-opt native.cgroupdriver=cgroupfs \
    --host=unix:///var/run/docker.sock --host=tcp://0.0.0.0:2375 \
    --containerd=/usr/bin/containerd >>"\$LOG" 2>&1
  sleep 2
done
WRAP
      chmod +x /usr/local/bin/dockerd-wsl2-wrapper
      nohup /usr/local/bin/dockerd-wsl2-wrapper >/dev/null 2>&1 &
      grep -q dockerd-wsl2-wrapper /etc/wsl.conf || \
        sed -i '/^\[boot\]/a command="bash -c '\''nohup /usr/local/bin/dockerd-wsl2-wrapper >/dev/null 2>&1 &'\''"' /etc/wsl.conf
  fi

  # wait up to 90 s for Docker to be ready
  for i in {1..90}; do
    if [[ -S /var/run/docker.sock ]]; then
      if docker info &>/dev/null; then
        break
      fi
    fi
    sleep 1
  done
  
  # Verify Docker is running
  if ! docker info &>/dev/null; then
    return 1
  fi
}

attempt=0
until install_once $((++attempt)); do
  [[ $attempt -ge 3 ]] && die "Docker failed after 3 attempts – check logs."
  wrn "Attempt $attempt failed – purging and retrying."
  # Simplified purge for retry
  systemctl stop docker.service docker.socket containerd.service 2>/dev/null || true
  pkill -f dockerd-wsl2-wrapper 2>/dev/null || true
  pkill -f dockerd 2>/dev/null || true
  retry apt-get remove --purge -y docker-ce docker-ce-cli containerd.io \
        docker-buildx-plugin docker-compose-plugin 2>/dev/null || true
done

# docker group
if [[ $TARGET_USER != root ]] && ! id "$TARGET_USER" 2>/dev/null | grep -q "(docker)"; then
  msg "Adding $TARGET_USER to docker group"
  groupadd -f docker 2>/dev/null || true
  usermod -aG docker "$TARGET_USER" 2>/dev/null || true
  wrn "Log out/in so group membership applies."
fi

# buildx (run with sudo if needed)
docker buildx ls >/dev/null 2>&1 || true
if ! docker buildx ls 2>/dev/null | grep -q wslbuilder; then
  docker buildx create --name wslbuilder --use 2>/dev/null || true
fi

# hello-world test
if docker run --rm hello-world >/dev/null 2>&1; then
  msg "🎉 Docker Engine is running & no host-conflict."
else
  wrn "Docker installed but hello-world test failed"
fi

[[ $(ps -p1 -o comm=) != systemd ]] && wrn "Run 'wsl.exe --shutdown' once; Docker will then run under systemd without the wrapper."
exit 0