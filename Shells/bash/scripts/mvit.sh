#!/usr/bin/env bash
# mvit – Move-it & image-it
set -euo pipefail

###############################################################################
# 0. sanity checks
###############################################################################
[ $# -ge 1 ] || { echo "Usage: mvit \"<folder with spaces>\""; exit 1; }

src="$1"                       # original path (quoted by the caller!)
[ -d "$src" ] || { echo "❌  No such directory: $src"; exit 1; }

abs_src="$(realpath "$src")"
parent="$(dirname  "$abs_src")"
base="$(basename "$abs_src")"

###############################################################################
# 1. derive the new one-word name (remove spaces)
###############################################################################
newbase="${base// /}"          # strip ALL spaces
dest="$parent/$newbase"

if [ "$base" != "$newbase" ]; then
    mv -v "$abs_src" "$dest"
else
    dest="$abs_src"            # folder already has no spaces
fi

###############################################################################
# 2. enter the *new* directory BEFORE touching Docker stuff   <───────── you asked!
###############################################################################
cd "$dest"
echo "📂  Now working inside $(pwd)"

###############################################################################
# 3. copy the new name to clipboard
###############################################################################
if   command -v xclip   &>/dev/null; then printf "%s" "$newbase" | xclip   -selection clipboard
elif command -v wl-copy &>/dev/null; then printf "%s" "$newbase" | wl-copy
elif command -v clip.exe &>/dev/null; then printf "%s" "$newbase" | clip.exe        # WSL/Windows
else echo "⚠️  Clipboard utility not found (xclip / wl-copy / clip.exe)."; fi

###############################################################################
# 4. create Dockerfile inside *this* folder
###############################################################################
cat > Dockerfile <<'EOF'
# Use a base image
FROM alpine:latest
RUN apk --no-cache add rsync
WORKDIR /app
COPY . /home/
CMD ["rsync", "-aP", "/home/", "/home/"]
EOF
echo "📄  Dockerfile created."

###############################################################################
# 5. build + push image (still inside the folder)
###############################################################################
tag="$(echo "$newbase" | tr '[:upper:]' '[:lower:]')"   # Docker tags must be lower-case
image="michadockermisha/backup:${tag}"

docker build -t "$image" .
docker push     "$image"

echo "✅  Image pushed:  $image"
