#!/usr/bin/env bash
# getapt.sh – one-shot installer/runner for kubernetes | mongodb | plex | chrome
# USAGE: sudo ./getapt.sh kubernetes mongodb plex

set -Eeuo pipefail
trap 'echo -e "\n❌  Failure on line $LINENO: $BASH_COMMAND"; exit 1' ERR
export DEBIAN_FRONTEND=noninteractive

echo "════════════════════════════════════════════════════════════"
echo " getapt.sh – zero-prompt installer/runner (APT edition)"
echo "════════════════════════════════════════════════════════════"

##############################################################################
# 0.  Heal dpkg database (missing *.list)  – unchanged, but safe increment
##############################################################################
heal_dpkg() {
  echo "[*] Healing dpkg database …"
  mapfile -t pkgs < <(dpkg-query -W -f='${Package}\n' 2>/dev/null || true)

  declare -i missing=0
  for p in "${pkgs[@]}"; do
    [[ -z $p ]] && continue
    f="/var/lib/dpkg/info/${p}.list"
    if [[ ! -e $f ]]; then
      touch "$f"
      missing=$(( missing + 1 ))
    fi
  done
  ((missing)) && echo "    ➜  created $missing placeholder *.list files"

  dpkg --configure -a || true
  dpkg --clear-avail
  apt-get -qq update
  apt-get -qq --fix-broken install -y
}
heal_dpkg

##############################################################################
# 1.  Helpers
##############################################################################
add_repo_key() { [[ -f $2 ]] || curl -fsSL "$1" | gpg --dearmor -o "$2"; }

#  apt_quiet <pkg> [...]   – retries once with --fix-broken after clearing holds
apt_quiet() {
  local pkgs=("$@")
  local try=1
  while :; do
    echo "[*] Installing: ${pkgs[*]}  (attempt $try)"
    if apt-get -qq update && \
       apt-get -y --allow-downgrades \
                 --allow-remove-essential \
                 --allow-change-held-packages \
                 install "${pkgs[@]}"; then
      return 0
    fi
    echo "    ↳ apt failed. Running fix-broken …"
    apt-get -f -y install || true
    (( try == 2 )) && { echo "🚫  Giving up after two attempts."; return 1; }
    try=2
  done
}

#  unhold anything that would block upgrades
if holds=$(apt-mark showhold) && [[ -n $holds ]]; then
  echo "[*] Clearing held packages:"
  echo "$holds" | sed 's/^/    • /'
  apt-mark unhold $holds
fi

already()  { dpkg -s "$1" &>/dev/null; }

##############################################################################
# 2.  Base prerequisites
##############################################################################
apt_quiet ca-certificates curl gnupg lsb-release apt-transport-https

##############################################################################
# 3.  Parse requested targets
##############################################################################
declare -A want
for a in "$@"; do want["$a"]=1; done

##############################################################################
# 4.  MongoDB 6 Community
##############################################################################
if [[ -n ${want[mongodb]:-} ]] && ! already mongodb-org; then
  echo "[+] Enabling MongoDB repo"
  ub=$(lsb_release -cs)
  add_repo_key https://pgp.mongodb.com/server-6.0.asc /usr/share/keyrings/mongodb.gpg
  echo "deb [arch=amd64 signed-by=/usr/share/keyrings/mongodb.gpg] \
https://repo.mongodb.org/apt/ubuntu $ub/mongodb-org/6.0 multiverse" \
    >/etc/apt/sources.list.d/mongodb-org.list
  apt_quiet mongodb-org
  systemctl enable --now mongod
fi

##############################################################################
# 5.  Kubernetes stack
##############################################################################
if [[ -n ${want[kubernetes]:-} ]]; then
  apt_quiet docker.io
  systemctl enable --now docker
  if ! already kubectl; then
    add_repo_key https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key \
      /usr/share/keyrings/kubernetes.gpg
    echo "deb [signed-by=/usr/share/keyrings/kubernetes.gpg] \
https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /" \
      >/etc/apt/sources.list.d/kubernetes.list
    apt_quiet kubectl
  fi
  if ! command -v minikube &>/dev/null; then
    curl -fsSL -o /tmp/minikube.deb \
      https://storage.googleapis.com/minikube/releases/latest/minikube_latest_amd64.deb
    dpkg -i /tmp/minikube.deb && rm /tmp/minikube.deb
  fi
fi

##############################################################################
# 6.  Plex Media Server
##############################################################################
if [[ -n ${want[plex]:-} ]] && ! already plexmediaserver; then
  add_repo_key https://downloads.plex.tv/plex-keys/PlexSign.key /usr/share/keyrings/plex.gpg
  echo "deb [arch=amd64 signed-by=/usr/share/keyrings/plex.gpg] \
https://downloads.plex.tv/repo/deb public main" \
    >/etc/apt/sources.list.d/plexmediaserver.list
  apt_quiet plexmediaserver
  systemctl enable --now plexmediaserver
fi

##############################################################################
# 7.  Run phase (sequential)
##############################################################################
for arg in "$@"; do
  echo -e "\n══════════════════════════════════════════════"
  echo   "[+] Running $arg …"
  echo   "══════════════════════════════════════════════"
  case "$arg" in
    kubernetes) minikube start --driver=docker --force ;;
    mongodb)    echo "    MongoDB ready → localhost:27017  (Ctrl+C to continue)"; sleep infinity & wait $! ;;
    plex)       ip=$(hostname -I | awk '{print $1}'); echo "    Plex UI → http://${ip}:32400/web (Ctrl+C)"; sleep infinity & wait $! ;;
    *)          echo "[-] Unknown option: $arg (ignored)" ;;
  esac
done
