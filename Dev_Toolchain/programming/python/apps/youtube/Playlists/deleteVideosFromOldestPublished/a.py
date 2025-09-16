#!/usr/bin/env python3
"""
Delete the N oldest videos from a specific YouTube playlist.

• Authenticates with OAuth 2.0 (desktop flow).
• Lists every video in the playlist with its published date.
• Prompts you for how many of the oldest videos to remove.
• Removes them and prints a summary.
"""

import os
import pickle
import json
from datetime import datetime, timezone
from urllib.parse import urlparse, parse_qs

from googleapiclient.discovery import build
from google.oauth2.credentials import Credentials
from google.auth.transport.requests import Request

# ──────────────────────────────────────────────────────────────────────────────
# Configuration
# ──────────────────────────────────────────────────────────────────────────────
SCOPES = ["https://www.googleapis.com/auth/youtube"]
CLIENT_SECRET_FILE = "client_secret.json"
TOKEN_PICKLE_FILE = "token.pickle"

# Playlist URL/ID to operate on
PLAYLIST_URL = (
    "https://www.youtube.com/playlist?list=YOUR_CLIENT_SECRET_HEREGseAmhTsf2"
)
# ──────────────────────────────────────────────────────────────────────────────


def authenticate_youtube():
    """Authenticate the user and return a YouTube API service object."""
    creds = None

    # Load cached credentials if they exist
    if os.path.exists(TOKEN_PICKLE_FILE):
        with open(TOKEN_PICKLE_FILE, "rb") as token_file:
            creds = pickle.load(token_file)

    # If the credentials are invalid or expired, start the OAuth flow
    if not creds or not creds.valid:
        if creds and creds.expired and creds.refresh_token:
            print("Refreshing OAuth token…")
            creds.refresh(Request())
        else:
            print("Launching browser for OAuth consent…")
            flow = Credentials.YOUR_CLIENT_SECRET_HERE("client_secret.json", ["https://www.googleapis.com/auth/youtube.force-ssl"])
creds = Credentials.YOUR_CLIENT_SECRET_HERE("client_secret.json", ["https://www.googleapis.com/auth/youtube.force-ssl"])

        # Cache the credentials for the next run
        with open(TOKEN_PICKLE_FILE, "wb") as token_file:
            pickle.dump(creds, token_file)

    return build("youtube", "v3", credentials=creds)


def extract_playlist_id(url_or_id: str) -> str:
    """
    Accept a full playlist URL OR just the ID and return the canonical ID.
    """
    if url_or_id.startswith(("http://", "https://")):
        qs = parse_qs(urlparse(url_or_id).query)
        if "list" not in qs or not qs["list"]:
            raise ValueError("URL does not contain a playlist ID (list=…).")
        return qs["list"][0]
    return url_or_id.strip()


def get_playlist_videos(youtube, playlist_id: str):
    """
    Retrieve all videos (with publish dates & playlist-item IDs) in a playlist.
    Returns a list of dicts ready for further processing.
    """
    videos = []
    page_token = None

    print("Fetching playlist items…")
    while True:
        pl_items = (
            youtube.playlistItems()
            .list(
                part="snippet",
                playlistId=playlist_id,
                maxResults=50,
                pageToken=page_token,
            )
            .execute()
        )

        # Extract video IDs for this batch
        video_ids = [
            item["snippet"]["resourceId"]["videoId"] for item in pl_items["items"]
        ]

        # Pull publish dates for each video
        if video_ids:
            vid_details = (
                youtube.videos()
                .list(part="snippet", id=",".join(video_ids))
                .execute()
            )

            # Combine data: playlist-item & video snippet
            for pl_item, vid in zip(pl_items["items"], vid_details["items"]):
                videos.append(
                    {
                        "playlist_item_id": pl_item["id"],
                        "video_id": vid["id"],
                        "title": vid["snippet"]["title"],
                        "published_at": vid["snippet"]["publishedAt"],
                        "position": pl_item["snippet"]["position"],
                    }
                )

        page_token = pl_items.get("nextPageToken")
        if not page_token:
            break

    return videos


def sort_by_publish_date(videos):
    """
    Return the list sorted by the original publish date (oldest → newest).
    """
    return sorted(
        videos,
        key=lambda v: datetime.fromisoformat(v["published_at"].replace("Z", "+00:00")),
    )


def delete_playlist_item(youtube, playlist_item_id: str) -> bool:
    """Remove a single playlist item by its playlist-item ID."""
    try:
        youtube.playlistItems().delete(id=playlist_item_id).execute()
        return True
    except Exception as exc:  # noqa: BLE001
        print(f"  → API error: {exc}")
        return False


# ──────────────────────────────────────────────────────────────────────────────
# Main routine
# ──────────────────────────────────────────────────────────────────────────────
def main():
    try:
        playlist_id = extract_playlist_id(PLAYLIST_URL)
        print(f"Target playlist ID: {playlist_id}\n")

        youtube = authenticate_youtube()
        print("✓ Authenticated with YouTube Data API v3\n")

        videos = get_playlist_videos(youtube, playlist_id)
        if not videos:
            print("⚠ No videos found in the playlist.")
            return

        print(f"Playlist contains {len(videos)} videos.")

        videos_sorted = sort_by_publish_date(videos)

        # Preview the oldest 10
        print("\nOldest videos:")
        for i, vid in enumerate(videos_sorted[:10], start=1):
            dt = datetime.fromisoformat(vid["published_at"].replace("Z", "+00:00"))
            print(f"{i:>2}. {vid['title']}  (published {dt.date()})")

        # Ask how many to delete
        while True:
            try:
                n = int(
                    input(
                        f"\nHow many OLDEST videos do you want to delete? (1-{len(videos_sorted)}): "
                    )
                )
                if 1 <= n <= len(videos_sorted):
                    break
            except ValueError:
                pass
            print("Please enter a valid number within range.")

        # Confirm
        print("\nYou are about to delete these videos:")
        for i in range(n):
            v = videos_sorted[i]
            dt = datetime.fromisoformat(v["published_at"].replace("Z", "+00:00"))
            print(f"{i+1:>2}. {v['title']}  (published {dt.date()})")

        confirm = input("\nType YES to confirm deletion: ").strip().lower()
        if confirm not in ("yes", "y"):
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

        print(
            f"\nFinished! Successfully removed {deleted} out of {n} requested item(s)."
        )

    except FileNotFoundError:
        print(
            f"❌ {CLIENT_SECRET_FILE} not found. Place your OAuth credentials JSON next to this script."
        )
    except Exception as err:  # noqa: BLE001
        print(f"❌ Unexpected error: {err}")


if __name__ == "__main__":
    main()
