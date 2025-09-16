#!/usr/bin/env bash
# getsnap.sh — install & run chrome | kubernetes | mongodb | plex via snap
# USAGE: sudo ./getsnap.sh chrome kubernetes mongodb plex

set -Eeuo pipefail
trap 'echo "❌ Error on line $LINENO: $BASH_COMMAND" >&2; exit 1' ERR

# 0) Show usage when no arguments provided
if [[ $# -eq 0 ]]; then
  cat << 'EOF'
Usage: sudo ./getsnap.sh [tools...]
Supported tools:
  chrome      - launches Chromium via Snap
  kubernetes  - launches microk8s and kubectl shell
  mongodb     - (no snap; skipped)
  plex        - launches Plex Media Server web UI
Example:
  sudo ./getsnap.sh chrome kubernetes plex
EOF
  exit 1
fi

echo "════════════════════════════════════════════════"
echo " getsnap.sh — installer/runner (SNAP edition)"
echo "════════════════════════════════════════════════"

# 1) Ensure snapd is installed & running
if ! command -v snap &>/dev/null; then
  echo "[+] Installing snapd…"
  apt-get update -qq
  apt-get install -y snapd
fi
systemctl enable --now snapd.socket

# 2) Map friendly → snap names
declare -A snapmap=(
  [chrome]=chromium
  [kubernetes]=microk8s
  [mongodb]=mongodb
  [plex]=plexmediaserver
)

declare -A skipped=()

# 3) Install any missing snaps, but skip if not found
for arg in "$@"; do
  pkg=${snapmap[$arg]:-$arg}
  echo "[*] Checking snap: $pkg"
  if ! snap find "$pkg" | grep -qE "^$pkg\s"; then
    echo "    ⚠︎  Snap '$pkg' not found in store. Skipping $arg."
    skipped[$arg]=1
    continue
  fi
  if ! snap list "$pkg" &>/dev/null; then
    echo "[+] Installing snap: $pkg"
    case "$pkg" in
      microk8s)        snap install microk8s --classic ;;
      plexmediaserver) snap install plexmediaserver ;;
      *)               snap install "$pkg" ;;
    esac
  else
    echo "    ✔︎  $pkg already installed"
  fi
done

# 4) Run each in sequence, skipping those we couldn’t install
for arg in "$@"; do
  echo -e "
══════════════════════════════════════════════"
  echo "[+] Running $arg…"
  echo "══════════════════════════════════════════════"
  if [[ -n ${skipped[$arg]:-} ]]; then
    echo "    ⚠︎  Skipped: no snap available for '$arg'"
    continue
  fi

  case "$arg" in
    chrome)
      if [[ "$(id -u)" -eq 0 ]]; then
        CHROME_DIR=/root/snap/chromium/common/chrome-data
        mkdir -p "$CHROME_DIR"
        chromium --no-sandbox --user-data-dir="$CHROME_DIR" || true
      else
        chromium || true
      fi
      ;;

    kubernetes)
      echo "    ▶️  Starting microk8s…"
      microk8s start
      echo "    🟢 Waiting for microk8s to be ready…"
      microk8s status --wait-ready
      echo "    🛠  Dropping into microk8s.kubectl shell (exit to continue)"
      microk8s kubectl
      ;;

    mongodb)
      echo "    ⚠︎  No official 'mongodb' snap—please install MongoDB some other way."
      ;;

    plex)
      echo "    ▶️  Starting Plex Media Server…"
      systemctl enable --now snap.plexmediaserver.plexmediaserver
      IP=$(hostname -I | awk '{print $1}')
      echo "    📺 Plex UI: http://${IP}:32400/web  (Ctrl+C to continue)"
      sleep infinity & wait $!
      ;;

    *)
      echo "    ⚠︎  Unknown target: $arg (skipped)"
      ;;
  esac
done

# 5) Summary of skips
if (( ${#skipped[@]} )); then
  echo -e "
⚠︎  The following were skipped because no snap was found:"
  for k in "${!skipped[@]}"; do
    echo "   • $k"
  done
fi
