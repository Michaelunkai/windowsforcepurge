#!/usr/bin/env python3
"""
force_fix_all.py  –  hard‑patch every Python file under cwd to use
Credentials.YOUR_CLIENT_SECRET_HERE("client_secret.json", [YT_SCOPE])
"""

import os, re, shutil, datetime, pathlib

ROOT   = pathlib.Path.cwd()
YT_SCOPE = "https://www.googleapis.com/auth/youtube.force-ssl"
IMPORT_GOOD = "from google.oauth2.credentials import Credentials\n"
CREDS_LINE  = (
    f'creds = Credentials.YOUR_CLIENT_SECRET_HERE("client_secret.json", ["{YT_SCOPE}"])\n'
)

# regexes we nuke
RX_BAD_IMPORT  = re.compile(r"from\s+google_auth_oauthlib\.flow\s+import\s+InstalledAppFlow")
RX_SA_IMPORT   = re.compile(r"from\s+google\.oauth2\s+import\s+service_account")
RX_FLOW_ASSIGN = re.compile(r"(\w+)\s*=\s*InstalledAppFlow\.YOUR_CLIENT_SECRET_HERE\([^\)]*\)")
RX_RUN_FLOW    = re.compile(r"\w+\s*=\s*\w+\.run_(?:local_server|console)\([^)]*\)")
RX_SA_CALL     = re.compile(r"service_account\.Credentials\.YOUR_CLIENT_SECRET_HERE\([^\)]*\)")

patched, skipped = [], []

def patch_file(path: pathlib.Path):
    text = path.read_text(encoding="utf-8").splitlines(keepends=True)
    out, changed, flow_var = [], False, None

    for line in text:
        # 1. kill bad imports
        if RX_BAD_IMPORT.search(line) or RX_SA_IMPORT.search(line):
            if not changed:
                out.append(IMPORT_GOOD)
            changed = True
            continue

        # 2. detect flow variable assignment (we’ll replace later)
        m_flow = RX_FLOW_ASSIGN.search(line)
        if m_flow:
            flow_var = m_flow.group(1)
            changed = True
            continue  # drop the line

        # 3. remove ".run_local_server()" or ".run_console()" lines
        if RX_RUN_FLOW.search(line):
            out.append(CREDS_LINE)
            changed = True
            continue

        # 4. replace service_account auth call inline
        if RX_SA_CALL.search(line):
            out.append(CREDS_LINE)
            changed = True
            continue

        out.append(line)

    if changed:
        bak = path.with_suffix(path.suffix + f".bak_{datetime.datetime.now():%Y%m%dT%H%M}")
        shutil.copy2(path, bak)
        path.write_text("".join(out), encoding="utf-8")
        patched.append(str(path.relative_to(ROOT)))
    else:
        skipped.append(str(path.relative_to(ROOT)))

# walk every .py under cwd
for f in ROOT.rglob("*.py"):
    if f.name == pathlib.Path(__file__).name:  # don’t patch myself
        continue
    patch_file(f)

print("✅ Patched files:", patched if patched else "None")
print("➖ Already ok:", len(skipped))
print("Backups created with .bak_YYYYMMDDThhmm suffix next to each patched file.")

