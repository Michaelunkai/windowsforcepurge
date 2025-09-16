#!/usr/bin/env python3
"""
Delete the N oldest videos from a specific YouTube playlist.

• Authenticates with OAuth 2.0 (desktop flow); caches the token in *token.pickle*.
• Lists every video in the playlist with its published date.
• Prompts for how many of the oldest videos to remove.
• Removes them and prints a summary.

Dependencies
------------
pip install google-auth google-auth-oauthlib """
from __future__ import annotations

import os
import pickle
import sys
from datetime import datetime
from urllib.parse import parse_qs, urlparse

# Set UTF-8 encoding for Windows console
if sys.platform == "win32":
    import codecs
    sys.stdout = codecs.getwriter("utf-8")(sys.stdout.detach())
    sys.stderr = codecs.getwriter("utf-8")(sys.stderr.detach())

from googleapiclient.discovery import build
from google.oauth2.credentials import Credentials
from google.auth.transport.requests import Request
from google_auth_oauthlib.flow import InstalledAppFlow

# ─────────────────────────── Configuration ────────────────────────────
SCOPES = ["https://www.googleapis.com/auth/youtube"]
CLIENT_SECRET_FILE = "client_secret.json"       # OAuth client secrets
TOKEN_PICKLE_FILE = "token.pickle"              # Cached user token
PLAYLIST_URL = "https://www.youtube.com/playlist?list=YOUR_CLIENT_SECRET_HEREnGmAse-tBl"
# ───────────────────────────────────────────────────────────────────────


def authenticate_youtube():
    """Return an authenticated YouTube Data API service object."""
    creds: Credentials | None = None

    # Check if client secrets file exists
    if not os.path.exists(CLIENT_SECRET_FILE):
        raise FileNotFoundError(
            f"OAuth client secrets file '{CLIENT_SECRET_FILE}' not found. "
            "Download it from Google Cloud Console and place it in this directory."
        )

    # Load cached credentials if present
    if os.path.exists(TOKEN_PICKLE_FILE):
        with open(TOKEN_PICKLE_FILE, "rb") as fp:
            creds = pickle.load(fp)

    # Refresh or obtain new credentials if needed
    if not creds or not creds.valid:
        if creds and creds.expired and creds.refresh_token:
            print("Refreshing OAuth token…")
            creds.refresh(Request())
        else:
            print("Launching browser for OAuth consent…")
            try:
                flow = InstalledAppFlow.YOUR_CLIENT_SECRET_HERE(CLIENT_SECRET_FILE, SCOPES)
                creds = flow.run_local_server(port=0)
            except Exception as e:
                raise RuntimeError(
                    f"OAuth flow failed: {e}. "
                    "Ensure your client_secret.json file is valid and contains proper OAuth credentials."
                ) from e

        # Cache credentials for next run
        with open(TOKEN_PICKLE_FILE, "wb") as fp:
            pickle.dump(creds, fp)

    return build("youtube", "v3", credentials=creds)


def extract_playlist_id(url_or_id: str) -> str:
    """Accept a full playlist URL **or** just the ID and return the canonical ID."""
    if url_or_id.startswith(("http://", "https://")):
        qs = parse_qs(urlparse(url_or_id).query)
        if "list" not in qs or not qs["list"]:
            raise ValueError("URL does not contain a playlist ID (list=…).")
        playlist_id = qs["list"][0]
    else:
        playlist_id = url_or_id.strip()
    
    # Validate playlist ID format (YouTube playlist IDs are typically 34 characters)
    if not playlist_id or len(playlist_id) < 20:
        raise ValueError(f"Invalid playlist ID: '{playlist_id}'. Playlist IDs should be 20+ characters long.")
    
    return playlist_id


def get_playlist_videos(youtube, playlist_id: str):
    """Retrieve all videos (with publish dates & playlist‑item IDs) in a playlist."""
    items = []
    page_token = None

    print("Fetching playlist items…")
    while True:
        try:
            resp = (
                youtube.playlistItems()
                .list(
                    part="snippet",
                    playlistId=playlist_id,
                    maxResults=50,
                    pageToken=page_token,
                )
                .execute()
            )
        except Exception as e:
            if "Invalid Value" in str(e) or "invalid" in str(e).lower():
                raise ValueError(
                    f"Invalid playlist ID: '{playlist_id}'. "
                    "Please check the playlist URL and ensure it's public and accessible."
                ) from e
            raise

        video_ids = [i["snippet"]["resourceId"]["videoId"] for i in resp["items"]]
        if video_ids:
            vids = (
                youtube.videos()
                .list(part="snippet", id=",".join(video_ids))
                .execute()
            )["items"]

            for pl_item, vid in zip(resp["items"], vids, strict=True):
                items.append(
                    {
                        "playlist_item_id": pl_item["id"],
                        "video_id": vid["id"],
                        "title": vid["snippet"]["title"],
                        "published_at": vid["snippet"]["publishedAt"],
                        "position": pl_item["snippet"]["position"],
                    }
                )

        page_token = resp.get("nextPageToken")
        if not page_token:
            break

    return items


def sort_by_publish_date(videos):
    """Return videos sorted from oldest → newest."""
    return sorted(
        videos,
        key=lambda v: datetime.fromisoformat(v["published_at"].replace("Z", "+00:00")),
    )


def delete_playlist_item(youtube, playlist_item_id: str) -> bool:
    """Remove a single playlist item by its playlist‑item ID."""
    try:
        youtube.playlistItems().delete(id=playlist_item_id).execute()
        return True
    except Exception as exc:  # noqa: BLE001
        print(f"  → API error: {exc}")
        return False


def main():
    try:
        # Ask for playlist URL if the default one fails
        playlist_url = PLAYLIST_URL
        try:
            playlist_id = extract_playlist_id(playlist_url)
        except ValueError:
            print("Default playlist URL is invalid.")
            playlist_url = input("Please enter a valid YouTube playlist URL: ").strip()
            playlist_id = extract_playlist_id(playlist_url)
        
        print(f"Target playlist ID: {playlist_id}\n")

        youtube = authenticate_youtube()
        print("[OK] Authenticated with YouTube Data API v3\n")

        videos = get_playlist_videos(youtube, playlist_id)
        if not videos:
            print("[WARNING] No videos found in the playlist.")
            return

        print(f"Playlist contains {len(videos)} videos.")
        videos_sorted = sort_by_publish_date(videos)

        # Show ALL videos sorted by date (oldest first)
        print(f"\nAll {len(videos_sorted)} videos (sorted by publish date - oldest first):")
        print("=" * 100)
        for i, v in enumerate(videos_sorted, 1):
            dt = datetime.fromisoformat(v["published_at"].replace("Z", "+00:00"))
            # Handle unicode characters safely
            title = v['title'][:80].encode('ascii', errors='ignore').decode('ascii')
            print(f"{i:>3}. {title:<80} (published {dt.date()})")
        print("=" * 100)

        # Ask user what they want to do
        print("\nOptions:")
        print("1. Just list videos (no deletion)")
        print("2. Delete oldest videos")
        
        while True:
            try:
                choice = input("\nChoose an option (1 or 2): ").strip()
                if choice in ["1", "2"]:
                    break
                print("Please enter 1 or 2.")
            except (EOFError, KeyboardInterrupt):
                print("\nDefaulting to option 1 (list only)...")
                choice = "1"
                break
        
        if choice == "1":
            print(f"\nListing complete! Found {len(videos_sorted)} videos in the playlist.")
            return

        # Ask how many to delete
        while True:
            try:
                n = int(
                    input(
                        f"\nHow many **oldest** videos do you want to delete? (1‑{len(videos_sorted)}): "
                    )
                )
                if 1 <= n <= len(videos_sorted):
                    break
            except ValueError:
                pass
            print("Please enter a valid number within range.")

        # Confirm
        print("\nYou are about to delete:")
        for i in range(n):
            v = videos_sorted[i]
            dt = datetime.fromisoformat(v["published_at"].replace("Z", "+00:00"))
            print(f"{i+1:>2}. {v['title']}  (published {dt.date()})")

        if input("\nType YES to confirm deletion: ").strip().lower() not in {"yes", "y"}:
            print("Cancelled.")
            return

        # Delete items
        print("\nDeleting videos…")
        deleted = 0
        for idx in range(n):
            v = videos_sorted[idx]
            print(f"[{idx+1}/{n}] Removing: {v['title']}")
            if delete_playlist_item(youtube, v["playlist_item_id"]):
                deleted += 1

        print(f"\nFinished! Successfully removed {deleted} of {n} requested item(s).")

    except FileNotFoundError as err:
        print(f"[ERROR] {err}")
    except Exception as err:  # noqa: BLE001
        print(f"[WARNING] Unexpected error: {err}")


if __name__ == "__main__":
    main()

