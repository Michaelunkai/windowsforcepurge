#!/usr/bin/env bash
###############################################################################
#  trakt_to_watch.sh
#  Bulk-add every IMDb ID in a.csv to a custom Trakt list.
#  • First run will guide you through PIN auth.
#  • Subsequent runs skip auth and only add new movies.
###############################################################################
set -euo pipefail

# ── CONFIG ────────────────────────────────────────────────────────────────────
LIST_SLUG="to-watch"                          # slug of the target Trakt list
CLIENT_ID="<YOUR_TRAKT_CLIENT_ID>"            # ✏️ replace
CLIENT_SECRET="<YOUR_TRAKT_CLIENT_SECRET>"    # ✏️ replace
REDIRECT_URI="urn:ietf:wg:oauth:2.0:oob"      # leave as-is

# ── 0 · prerequisites ─────────────────────────────────────────────────────────
sudo apt-get update -qq
sudo apt-get install -y wslu git python3-pip
pip install --quiet requests

# ── 1 · helper repo ───────────────────────────────────────────────────────────
REPO="$HOME/trakt"
rm -rf "$REPO"
git clone --depth 1 https://github.com/xbgmsharp/trakt.git "$REPO"
cd "$REPO"

# ── 2 · sample CSV (edit or replace later) ────────────────────────────────────
if [[ ! -f a.csv ]]; then
cat > a.csv <<'CSV'
imdb
tt0133093   # The Matrix
tt1375666   # Inception
tt6751668   # Parasite
tt0468569   # The Dark Knight
tt0816692   # Interstellar
CSV
echo "✅  a.csv created with 5 sample movies"
fi

# ── 3 · create or update config.ini ───────────────────────────────────────────
cat > config.ini <<EOF
[TRAKT]
client_id     = ${CLIENT_ID}
client_secret = ${CLIENT_SECRET}
redirect_uri  = ${REDIRECT_URI}
EOF

# ── 4 · one-time PIN flow (only if tokens missing) ────────────────────────────
if ! grep -q '^access_token *= *[^[:space:]]' config.ini 2>/dev/null; then
  echo -e "\n🔑  First-time authorisation – follow these steps:\n"
  python3 export_trakt.py -c config.ini || true   # prints URL, waits for PIN
  if ! grep -q '^access_token *= *[^[:space:]]' config.ini; then
    echo "❌  PIN not saved – aborting"; exit 1
  fi
fi

# ── 5 · add movies in a.csv to the chosen list ────────────────────────────────
python3 - <<PY
import csv, re, sys, json, configparser, pathlib, requests

csv_path     = pathlib.Path("a.csv")
cfg          = configparser.ConfigParser()
cfg.read("config.ini")
cid          = cfg["TRAKT"]["client_id"].strip()
token        = cfg["TRAKT"]["access_token"].strip()
slug         = "${LIST_SLUG}"

HEAD = {"trakt-api-version":"2",
        "trakt-api-key":cid,
        "Authorization":f"Bearer {token}",
        "Content-Type":"application/json"}

# get username
user = requests.get("https://api.trakt.tv/users/me", headers=HEAD).json()["username"]

# create list if needed
resp = requests.get(f"https://api.trakt.tv/users/{user}/lists/{slug}", headers=HEAD)
if resp.status_code == 404:
    body = {"name": slug.replace('-', ' ').title(),
            "description": "Auto-imported list",
            "privacy": "private"}
    requests.post(f"https://api.trakt.tv/users/{user}/lists",
                  headers=HEAD, json=body).raise_for_status()

# build payload from CSV
with csv_path.open(newline='') as f:
    movies = [{"ids":{"imdb":row[0].strip()}} for row in csv.reader(f)
              if re.fullmatch(r"tt\d{7,}", row[0].strip())]

if not movies:
    print("⚠️  No valid IMDb IDs found in a.csv"); sys.exit()

payload = {"movies": movies}
r = requests.post(f"https://api.trakt.tv/users/{user}/lists/{slug}/items",
                  headers=HEAD, json=payload)
r.raise_for_status()
added = r.json().get("added", {}).get("movies", 0)
print(f"✅  Added {added} movies to list “{slug}”.")
PY

echo -e "\n🎉  Finished!  In Stremio:  Import from Trakt ➜ list “${LIST_SLUG}”."
