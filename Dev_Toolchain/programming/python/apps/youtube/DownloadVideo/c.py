# a.py — clone any YouTube / Shorts URL to *your* channel
# deps: yt-dlp ffmpeg YOUR_CLIENT_SECRET_HERE google-auth-oauthlib
# usage: python a.py [youtube_url]  OR  python a.py (interactive mode)

import os
import sys
import re
from pathlib import Path
from yt_dlp import YoutubeDL
from googleapiclient.discovery import build
from google_auth_oauthlib.flow import InstalledAppFlow
from googleapiclient.http import MediaFileUpload

# ────────────────────── helpers ──────────────────────────────────────────────
SAFE_CHARS = r'[\\/*?:"<>|]'

def win_safe(s: str) -> str:
    """Strip characters Windows can't store in filenames."""
    return re.sub(SAFE_CHARS, "", s)

def find_secrets_file():
    """Find client_secrets.json in various locations."""
    # Possible locations to look for the secrets file
    locations = [
        "client_secrets.json",  # Current directory
        os.path.join(os.path.expanduser("~"), "Downloads", "client_secrets.json"),  # User Downloads
        os.path.join("Downloads", "client_secrets.json"),  # Local Downloads folder
        os.path.join(os.getcwd(), "Downloads", "client_secrets.json"),  # Current dir + Downloads
        os.path.join(os.path.dirname(__file__), "client_secrets.json"),  # Script directory
    ]
    
    for location in locations:
        if os.path.isfile(location):
            print(f"📁 Found secrets file: {location}")
            return location
    
    # If not found, show where we looked
    print("❌ client_secrets.json not found in any of these locations:")
    for location in locations:
        print(f"   - {location}")
    print("\n💡 Please ensure client_secrets.json is in one of these locations:")
    print("   1. Same directory as this script")
    print("   2. Your Downloads folder")
    print("   3. A 'Downloads' subfolder next to this script")
    
    return None

def _find_output_file(info: dict, ydl: YoutubeDL) -> str:
    """
    Robustly locate the final .mp4 written by yt-dlp/ffmpeg, even if keys vary.
    """
    # 1️⃣ 'filepath' (present since yt-dlp 2024.07)
    if info.get("filepath") and os.path.isfile(info["filepath"]):
        return info["filepath"]

    # 2️⃣ per-format entry under 'requested_downloads'
    for req in info.get("requested_downloads", []):
        fp = req.get("filepath")
        if fp and os.path.isfile(fp):
            return fp

    # 3️⃣ '_filename' → adjust ext to .mp4 (merge_output_format)
    if info.get("_filename"):
        guess = os.path.splitext(info["_filename"])[0] + ".mp4"
        if os.path.isfile(guess):
            return guess

    # 4️⃣ fallback: ydl.prepare_filename(info) + .mp4
    guess = os.path.splitext(ydl.prepare_filename(info))[0] + ".mp4"
    if os.path.isfile(guess):
        return guess

    raise FileNotFoundError("Could not locate merged .mp4 — check yt-dlp/ffmpeg")

def download(url: str, download_dir: str = None) -> tuple[str, str, str]:
    """
    Download & merge best video+audio → MP4.
    Returns (path, title, description)
    """
    if download_dir is None:
        download_dir = os.getcwd()
    
    # Ensure download directory exists
    os.makedirs(download_dir, exist_ok=True)
    
    opts = {
        "format": "bestvideo*+bestaudio/best",
        "merge_output_format": "mp4",
        "restrictfilenames": True,                # ensures OS-safe paths
        "outtmpl": os.path.join(download_dir, "%(title)s [%(id)s].%(ext)s"),
        "noplaylist": True,
        "quiet": False,
    }
    
    with YoutubeDL(opts) as ydl:
        info = ydl.extract_info(url, download=True)
        path = _find_output_file(info, ydl)

    title = win_safe(info["title"])
    desc = info.get("description", "")
    return path, title, desc

def yt_auth(secrets_file_path: str):
    """Authenticate with YouTube API using the secrets file."""
    scopes = ["https://www.googleapis.com/auth/youtube.upload"]
    flow = InstalledAppFlow.YOUR_CLIENT_SECRET_HERE(secrets_file_path, scopes)
    creds = flow.run_local_server(port=0)
    return build("youtube", "v3", credentials=creds)

def upload(youtube, path: str, title: str, desc: str) -> str:
    """Upload video to YouTube channel."""
    body = {
        "snippet": {
            "title": title, 
            "description": desc, 
            "categoryId": "22"  # People & Blogs
        },
        "status": {"privacyStatus": "private"}     # change to "public" if you wish
    }
    
    media = MediaFileUpload(path, resumable=True)
    resp = youtube.videos().insert(
        part="snippet,status", 
        body=body, 
        media_body=media
    ).execute()
    
    return resp["id"]

def validate_youtube_url(url: str) -> bool:
    """Check if the URL is a valid YouTube URL."""
    youtube_patterns = [
        r'(?:https?://)?(?:www\.)?youtube\.com/watch\?v=[\w-]+',
        r'(?:https?://)?(?:www\.)?youtu\.be/[\w-]+',
        r'(?:https?://)?(?:www\.)?youtube\.com/shorts/[\w-]+',
    ]
    
    return any(re.match(pattern, url) for pattern in youtube_patterns)

def get_url_input():
    """Get URL from command line args or interactive input."""
    # Check if URL provided as command line argument
    if len(sys.argv) > 1:
        url = sys.argv[1].strip()
        print(f"Paste YouTube (or Shorts) URL 👉 {url}")
        return url
    
    # Interactive mode - ask for input
    url = input("Paste YouTube (or Shorts) URL 👉 ").strip()
    return url

def process_youtube_video():
    """Main function to process YouTube video download and upload."""
    try:
        # Get URL (from args or interactive input)
        url = get_url_input()
        
        if not url:
            print("❌ No URL provided — exiting.")
            return False
        
        # Validate URL
        if not validate_youtube_url(url):
            print("❌ Invalid YouTube URL. Please provide a valid YouTube video URL.")
            print("Examples:")
            print("  - https://www.youtube.com/watch?v=VIDEO_ID")
            print("  - https://youtu.be/VIDEO_ID")
            print("  - https://www.youtube.com/shorts/VIDEO_ID")
            return False
        
        # Find secrets file
        secrets_file = find_secrets_file()
        if not secrets_file:
            return False
        
        # Set download directory (same as where secrets file is located)
        download_dir = os.path.dirname(os.path.abspath(secrets_file))
        
        print("⬇  Downloading …")
        fpath, title, desc = download(url, download_dir)
        print("✔  Saved:", fpath)

        print("🔑  Google OAuth …")
        yt = yt_auth(secrets_file)

        print("⬆  Uploading to your channel …")
        vid_id = upload(yt, fpath, title, desc)
        print("🎉 Uploaded → https://youtu.be/" + vid_id)

        # Clean up local file
        os.remove(fpath)
        print("🗑  Local file deleted")
        
        print("✅ Process completed successfully!")
        return True
        
    except KeyboardInterrupt:
        print("\n❌ Process interrupted by user")
        return False
    except Exception as err:
        print(f"❌ Error: {err}")
        return False

# ────────────────────── main ──────────────────────────────────────────────────
if __name__ == "__main__":
    success = process_youtube_video()
    sys.exit(0 if success else 1)