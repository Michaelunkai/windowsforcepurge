#!/usr/bin/env bash
# getnix.sh — install Nix once, pre-fetch each requested tool, then run them in order.
# Usage:   ./getnix.sh chrome docker firefox kubernetes mongodb …

set -euo pipefail

###############################################################################
# 1. Install Nix (multi-user daemon) if missing
###############################################################################
if ! command -v nix-shell >/dev/null 2>&1; then
  echo "[+] Installing Nix package manager …"
  yes | sh <(curl -L https://nixos.org/nix/install) --daemon
  . /etc/profile
fi

###############################################################################
# 2. Always allow unfree packages (Chrome, MongoDB, etc.)
###############################################################################
export NIXPKGS_ALLOW_UNFREE=1

###############################################################################
# 3. Build package list & alias mapping
###############################################################################
declare -a wanted=("$@")   # original order for execution loop
declare -a pkgs=()         # nix-pkg attribute names
declare -A alias=(         # friendly → nix-pkg
  [chrome]=google-chrome
  [firefox]=firefox
  [docker]=docker
  [kubernetes]="minikube docker kubectl"
  [helm]=kubernetes-helm
  [mongodb]=mongodb
  [mongosh]=mongosh
)

for arg in "${wanted[@]}"; do
  if [[ -n "${alias[$arg]:-}" ]]; then
    # may expand to >1 pkg (e.g. kubernetes)
    pkgs+=(${alias[$arg]})
  else
    pkgs+=("$arg")   # hope it’s a real nix attribute
  fi
done

###############################################################################
# 4. Pre-fetch each pkg individually (so one typo can’t break all)
###############################################################################
declare -a valid_pkgs=()
declare -a bad_pkgs=()

echo "[+] Pre-fetching packages …"
for pkg in "${pkgs[@]}"; do
  if nix-shell -p "$pkg" --run true >/dev/null 2>&1; then
    valid_pkgs+=("$pkg")
  else
    bad_pkgs+=("$pkg")
    echo "    ⚠︎  Package not found: $pkg (skipped)"
  fi
done
echo "[+] Packages ready: ${valid_pkgs[*]}"

###############################################################################
# 5. Run each ORIGINAL argument sequentially
###############################################################################
for arg in "${wanted[@]}"; do
  echo
  echo "══════════════════════════════════════════════"
  echo "[+] Running $arg …"
  echo "══════════════════════════════════════════════"

  case "$arg" in
    #────────────────── Chrome ──────────────────#
    chrome)
      nix-shell -p google-chrome --run '
        BIN=$(command -v google-chrome-stable || command -v google-chrome || true)
        if [[ -z "$BIN" ]]; then echo "Chrome executable missing inside nix-shell"; exit 1; fi
        [[ $(id -u) -eq 0 ]] && EXTRA="--no-sandbox" || EXTRA=""
        exec "$BIN" $EXTRA
      '
      ;;

    #────────────────── Firefox ─────────────────#
    firefox)
      nix-shell -p firefox --run firefox
      ;;

    #────────────────── Docker CLI ──────────────#
    docker)
      nix-shell -p docker --run bash     # drops you in a subshell with docker client
      ;;

    #────────────────── Kubernetes (Minikube) ──#
    kubernetes)
      if ! pgrep -x dockerd >/dev/null 2>&1; then
        echo "[-] Docker daemon not running; Minikube needs it. Start Docker first."
        continue
      fi
      nix-shell -p minikube docker kubectl --run "minikube start --driver=docker"
      ;;

    #────────────────── Helm ────────────────────#
    helm)
      nix-shell -p kubernetes-helm --run helm
      ;;

    #────────────────── MongoDB server ──────────#
    mongodb)
      DATA="$HOME/mongo-data"
      mkdir -p "$DATA"
      nix-shell -p mongodb --run "mongod --dbpath \"$DATA\" --bind_ip 127.0.0.1 --port 27017"
      ;;

    #────────────────── MongoDB shell ───────────#
    mongosh)
      nix-shell -p mongosh --run mongosh
      ;;

    #────────────────── Anything else ───────────#
    *)
      if [[ " ${bad_pkgs[*]} " == *" $arg "* ]]; then
        echo "[-] Skipping: ‘$arg’ is not a known Nix package."
      else
        nix-shell -p "$arg" --run "$arg"
      fi
      ;;
  esac
done

###############################################################################
# 6. Summary of skipped items (if any)
###############################################################################
if ((${#bad_pkgs[@]})); then
  echo
  echo "⚠︎  These names were skipped because Nix has no such package:"
  printf '   • %s\n' "${bad_pkgs[@]}"
fi
