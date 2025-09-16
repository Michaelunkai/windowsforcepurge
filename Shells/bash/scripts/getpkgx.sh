#!/usr/bin/env bash
# getpkgx.sh – “type anything & it runs” powered by pkgx
set -euo pipefail

#──────────────────────────────────────────────────────────────────────────────
# 0.  pkgx bootstrap
#──────────────────────────────────────────────────────────────────────────────
export PKGX_DIR="${PKGX_DIR:-$HOME/.pkgx}"
export PATH="$PKGX_DIR/bin:$PATH"

if ! command -v pkgx >/dev/null 2>&1; then
  echo "[+] Installing pkgx …"
  curl -fsSL https://pkgx.sh | bash
  export PATH="$PKGX_DIR/bin:$PATH"
fi

#──────────────────────────────────────────────────────────────────────────────
# 1.  Friendly-name → candidate pkgx IDs
#──────────────────────────────────────────────────────────────────────────────
declare -A alias=(
  [chrome]="google-chrome google.com/chrome chromium"
  [firefox]="firefox"
  [docker]="docker"
  [kubernetes]="minikube docker kubectl"
  [helm]="kubernetes-helm"
  [mongodb]="mongodb mongodb.com mongodb-community mongodb.com/server"
  [mongosh]="mongosh"
)

#──────────────────────────────────────────────────────────────────────────────
# 2.  Probe which names actually exist
#──────────────────────────────────────────────────────────────────────────────
declare -a wanted=("$@")
declare -A good bad                 # key = original arg

echo "[+] Probing packages …"
for arg in "${wanted[@]}"; do
  match=""
  for cand in ${alias[$arg]:-"$arg"}; do
    if pkgx -Q "$cand" >/dev/null 2>&1; then
      match="$cand"; break
    fi
  done
  if [[ -n $match ]]; then
    good["$arg"]="$match"
    printf '    ✔︎  %s  →  %s\n' "$arg" "$match"
  else
    bad["$arg"]="no matching pkgx package"
    printf '    ⚠︎  %s  →  NOT found (skipped)\n' "$arg"
  fi
done

#──────────────────────────────────────────────────────────────────────────────
# 3.  Abort early if nothing usable
#──────────────────────────────────────────────────────────────────────────────
if ((${#good[@]}==0)); then
  echo "[-] Nothing to do – every name was unknown to pkgx."
  exit 1
fi

#──────────────────────────────────────────────────────────────────────────────
# 4.  Pre-fetch everything once
#──────────────────────────────────────────────────────────────────────────────
echo "[+] Pre-fetching …"
prefetch=(pkgx)
for key in "${!good[@]}"; do prefetch+=("+${good[$key]}"); done
prefetch+=(-- true)
"${prefetch[@]}"

#──────────────────────────────────────────────────────────────────────────────
# 5.  Sequential run loop
#──────────────────────────────────────────────────────────────────────────────
for arg in "${wanted[@]}"; do
  [[ -z ${good[$arg]:-} ]] && {                      # skipped earlier
    echo
    echo "[-] Skipping $arg – ${bad[$arg]}"
    continue
  }

  echo
  echo "══════════════════════════════════════════════"
  echo "[+] Running $arg …"
  echo "══════════════════════════════════════════════"

  case "$arg" in
    chrome)
      pkgx "${good[$arg]}" bash -c '
        BIN=$(command -v google-chrome-stable || command -v google-chrome || command -v chromium || true)
        [[ -z "$BIN" ]] && { echo "Chrome executable not found"; exit 1; }
        [[ $(id -u) -eq 0 ]] && EXTRA="--no-sandbox" || EXTRA=""
        exec "$BIN" $EXTRA
      '
      ;;
    docker)
      echo "    (sub-shell with Docker CLI; exit to continue)"
      pkgx "${good[$arg]}" bash
      ;;
    kubernetes)
      if ! pgrep -x dockerd >/dev/null 2>&1; then
        echo "[-] Docker daemon not running – Minikube needs Docker. Skipping."
      else
        pkgx +docker +kubectl "${good[$arg]}" minikube start --driver=docker --force
      fi
      ;;
    mongodb)
      DATA="$HOME/mongo-data"; mkdir -p "$DATA"
      pkgx "${good[$arg]}" mongod --dbpath "$DATA" --bind_ip 127.0.0.1 --port 27017
      ;;
    mongosh)
      pkgx "${good[$arg]}" mongosh
      ;;
    helm)
      pkgx "${good[$arg]}" helm
      ;;
    *)
      pkgx "${good[$arg]}" "$arg"
      ;;
  esac
done

#──────────────────────────────────────────────────────────────────────────────
# 6.  Summary of skipped names
#──────────────────────────────────────────────────────────────────────────────
if ((${#bad[@]})); then
  echo
  echo "⚠︎  Skipped:"
  for k in "${!bad[@]}"; do printf '   • %s — %s\n' "$k" "${bad[$k]}"; done
fi
