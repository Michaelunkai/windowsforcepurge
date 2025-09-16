#!/usr/bin/env python3
"""
YouTube Channel Video Downloader and Manager

This script provides comprehensive functionality to:
1. Authenticate with YouTube API using OAuth2
2. List all videos from your channel with detailed information
3. Download videos with customizable quality and format options
4. Create backups of video metadata
5. Optionally delete videos from your channel (with safety confirmations)

Features:
- Robust error handling and retry mechanisms
- Progress tracking for downloads
- Metadata backup (JSON format)
- Configurable download settings
- Safety confirmations before destructive operations
- Detailed logging and status reporting

Dependencies:
pip install google-auth google-auth-oauthlib YOUR_CLIENT_SECRET_HERE yt-dlp tqdm
"""

import os
import sys
import json
import time
import pickle
import logging
from datetime import datetime
from pathlib import Path
from typing import List, Dict, Optional, Tuple
from dataclasses import dataclass

# Set UTF-8 encoding for Windows
if sys.platform == "win32":
    import io
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')
    sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding='utf-8')

# Third-party imports
try:
    from googleapiclient.discovery import build
    from googleapiclient.errors import HttpError
    from google.oauth2.credentials import Credentials
    from google.auth.transport.requests import Request
    from google_auth_oauthlib.flow import InstalledAppFlow
    import yt_dlp
    from tqdm import tqdm
except ImportError as e:
    print(f"Error: Missing required dependency: {e}")
    print("Please install required packages: pip install google-auth google-auth-oauthlib YOUR_CLIENT_SECRET_HERE yt-dlp tqdm")
    sys.exit(1)

# Configuration
@dataclass
class Config:
    scopes: List[str] = None
    client_secret_file: str = "client_secret.json"
    token_pickle_file: str = "token.pickle"
    download_folder: str = r"F:\Downloads\MyVideos"
    backup_folder: str = r"F:\Downloads\MyVideos\backups"
    log_level: str = "INFO"
    max_retries: int = 3
    retry_delay: int = 2
    
    def __post_init__(self):
        if self.scopes is None:
            self.scopes = ["https://www.googleapis.com/auth/youtube.force-ssl"]

config = Config()

# Setup logging
def setup_logging():
    """Configure logging with both file and console output."""
    log_dir = Path(config.download_folder) / "logs"
    log_dir.mkdir(parents=True, exist_ok=True)
    
    log_filename = f"youtube_downloader_{datetime.now().strftime('%Y%m%d_%H%M%S')}.log"
    log_path = log_dir / log_filename
    
    logging.basicConfig(
        level=getattr(logging, config.log_level),
        format='%(asctime)s - %(levelname)s - %(message)s',
        handlers=[
            logging.FileHandler(log_path, encoding='utf-8'),
            logging.StreamHandler(sys.stdout)
        ]
    )
    return logging.getLogger(__name__)

logger = setup_logging()

class YouTubeError(Exception):
    """Custom exception for YouTube-related errors."""
    pass

class YouTubeDownloader:
    """Main class for handling YouTube channel downloads."""
    
    def __init__(self, config: Config):
        self.config = config
        self.youtube = None
        self.channel_id = None
        
    def authenticate_youtube(self) -> bool:
        """Authenticate with YouTube Data API v3."""
        try:
            creds = None
            
            if not os.path.exists(self.config.client_secret_file):
                raise YouTubeError(
                    f"OAuth client secrets file '{self.config.client_secret_file}' not found. "
                    "Download it from Google Cloud Console and place it in this directory."
                )
            
            # Load existing credentials
            if os.path.exists(self.config.token_pickle_file):
                try:
                    with open(self.config.token_pickle_file, "rb") as fp:
                        creds = pickle.load(fp)
                    logger.info("Loaded existing credentials")
                except Exception as e:
                    logger.warning(f"Failed to load existing credentials: {e}")
            
            # Refresh or get new credentials
            if not creds or not creds.valid:
                if creds and creds.expired and creds.refresh_token:
                    logger.info("Refreshing expired OAuth token...")
                    try:
                        creds.refresh(Request())
                        logger.info("Token refreshed successfully")
                    except Exception as e:
                        logger.error(f"Token refresh failed: {e}")
                        creds = None
                
                if not creds:
                    logger.info("Starting OAuth flow...")
                    try:
                        flow = InstalledAppFlow.YOUR_CLIENT_SECRET_HERE(
                            self.config.client_secret_file, 
                            self.config.scopes
                        )
                        creds = flow.run_local_server(port=0)
                        logger.info("OAuth flow completed successfully")
                    except Exception as e:
                        raise YouTubeError(f"OAuth flow failed: {e}")
                
                # Save credentials
                try:
                    with open(self.config.token_pickle_file, "wb") as fp:
                        pickle.dump(creds, fp)
                    logger.info("Credentials saved successfully")
                except Exception as e:
                    logger.warning(f"Failed to save credentials: {e}")
            
            # Build YouTube service
            self.youtube = build("youtube", "v3", credentials=creds)
            logger.info("[OK] Successfully authenticated with YouTube Data API v3")
            return True
            
        except Exception as e:
            logger.error(f"Authentication failed: {e}")
            raise YouTubeError(f"Authentication failed: {e}")
    
    def get_channel_id(self) -> str:
        """Get the authenticated user's channel ID."""
        try:
            response = self.youtube.channels().list(part="id", mine=True).execute()
            
            if not response.get("items"):
                raise YouTubeError("No channel found for the authenticated user")
            
            self.channel_id = response["items"][0]["id"]
            logger.info(f"Channel ID: {self.channel_id}")
            return self.channel_id
            
        except HttpError as e:
            raise YouTubeError(f"Failed to get channel ID: {e}")
        except Exception as e:
            raise YouTubeError(f"Unexpected error getting channel ID: {e}")
    
    def get_all_videos(self) -> List[Dict]:
        """Fetch all videos from the channel with detailed information."""
        if not self.channel_id:
            raise YouTubeError("Channel ID not found. Call get_channel_id() first.")
        
        videos = []
        page_token = None
        
        try:
            # Get uploads playlist ID
            channel_response = self.youtube.channels().list(
                part="contentDetails,statistics,snippet",
                id=self.channel_id
            ).execute()
            
            if not channel_response.get("items"):
                raise YouTubeError("Channel details not found")
            
            channel_info = channel_response["items"][0]
            uploads_playlist_id = channel_info["contentDetails"]["relatedPlaylists"]["uploads"]
            total_videos = int(channel_info["statistics"].get("videoCount", 0))
            
            logger.info(f"Channel: {channel_info['snippet']['title']}")
            logger.info(f"Total videos to fetch: {total_videos}")
            
            # Progress bar for fetching videos
            pbar = tqdm(total=total_videos, desc="Fetching videos", unit="video")
            
            while True:
                try:
                    # Get videos from uploads playlist
                    playlist_response = self.youtube.playlistItems().list(
                        part="snippet,status",
                        playlistId=uploads_playlist_id,
                        maxResults=50,
                        pageToken=page_token
                    ).execute()
                    
                    video_ids = [
                        item["snippet"]["resourceId"]["videoId"] 
                        for item in playlist_response.get("items", [])
                    ]
                    
                    if video_ids:
                        # Get detailed video information
                        videos_response = self.youtube.videos().list(
                            part="snippet,status,statistics,contentDetails",
                            id=",".join(video_ids)
                        ).execute()
                        
                        for video in videos_response.get("items", []):
                            video_data = {
                                "video_id": video["id"],
                                "title": video["snippet"]["title"],
                                "description": video["snippet"]["description"],
                                "published_at": video["snippet"]["publishedAt"],
                                "privacy_status": video["status"]["privacyStatus"],
                                "view_count": int(video["statistics"].get("viewCount", 0)),
                                "like_count": int(video["statistics"].get("likeCount", 0)),
                                "comment_count": int(video["statistics"].get("commentCount", 0)),
                                "duration": video["contentDetails"]["duration"],
                                "tags": video["snippet"].get("tags", []),
                                "category_id": video["snippet"]["categoryId"]
                            }
                            videos.append(video_data)
                            pbar.update(1)
                    
                    page_token = playlist_response.get("nextPageToken")
                    if not page_token:
                        break
                        
                except HttpError as e:
                    logger.error(f"HTTP error while fetching videos: {e}")
                    break
                except Exception as e:
                    logger.error(f"Error fetching videos: {e}")
                    break
            
            pbar.close()
            logger.info(f"Successfully fetched {len(videos)} videos")
            return videos
            
        except Exception as e:
            raise YouTubeError(f"Failed to fetch videos: {e}")
    
    def backup_metadata(self, videos: List[Dict]) -> str:
        """Create a backup of video metadata."""
        try:
            backup_dir = Path(self.config.backup_folder)
            backup_dir.mkdir(parents=True, exist_ok=True)
            
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            backup_file = backup_dir / f"video_metadata_{timestamp}.json"
            
            backup_data = {
                "channel_id": self.channel_id,
                "backup_timestamp": timestamp,
                "total_videos": len(videos),
                "videos": videos
            }
            
            with open(backup_file, 'w', encoding='utf-8') as f:
                json.dump(backup_data, f, ensure_ascii=False, indent=2)
            
            logger.info(f"[OK] Metadata backed up to: {backup_file}")
            return str(backup_file)
            
        except Exception as e:
            logger.error(f"Failed to backup metadata: {e}")
            return ""
    
    def download_video(self, video_data: Dict, download_path: str) -> Tuple[bool, str]:
        """Download a single video with retry mechanism."""
        video_id = video_data["video_id"]
        title = video_data["title"]
        privacy_status = video_data.get("privacy_status", "unknown")
        
        # Check if video is private - skip if it is since we can't download private videos
        if privacy_status.lower() == "private":
            logger.warning(f"[SKIP] Private video cannot be downloaded: {title}")
            return False, "private_video_skipped"
        
        for attempt in range(self.config.max_retries):
            try:
                # Clean filename
                safe_title = "".join(c for c in title if c.isalnum() or c in (' ', '-', '_', '.'))
                safe_title = safe_title.strip()[:100]  # Limit length
                
                # Configure yt-dlp options with better error handling
                ydl_opts = {
                    'outtmpl': os.path.join(download_path, f'{safe_title} - {video_id}.%(ext)s'),
                    'format': 'best[height<=1080]/best[height<=720]/best',  # Try multiple quality options
                    'writeinfojson': True,  # Save metadata
                    'writesubtitles': False,  # Disable subtitles to avoid rate limits
                    'writeautomaticsub': False,  # Disable auto-subtitles to avoid rate limits
                    'ignoreerrors': False,
                    'no_warnings': True,  # Reduce output noise
                    'extract_flat': False,
                    'retries': 3,  # Retry on failure
                    'fragment_retries': 3,  # Retry fragments
                    'sleep_interval': 1,  # Wait between downloads
                    'max_sleep_interval': 5,  # Max wait time
                }
                
                with yt_dlp.YoutubeDL(ydl_opts) as ydl:
                    video_url = f"https://www.youtube.com/watch?v={video_id}"
                    ydl.download([video_url])
                
                # Find the downloaded file
                downloaded_files = list(Path(download_path).glob(f'{safe_title} - {video_id}.*'))
                video_file = next((f for f in downloaded_files if f.suffix.lower() in ['.mp4', '.mkv', '.webm']), None)
                
                if video_file:
                    logger.info(f"[OK] Downloaded: {video_file.name}")
                    return True, str(video_file)
                else:
                    logger.warning(f"Download completed but video file not found for: {title}")
                    return True, ""
                
            except Exception as e:
                error_str = str(e)
                
                # Handle specific errors
                if "Private video" in error_str:
                    logger.warning(f"[SKIP] Private video cannot be downloaded: {title}")
                    return False, "private_video_skipped"
                elif "Video unavailable" in error_str:
                    logger.warning(f"[SKIP] Video unavailable: {title}")
                    return False, "video_unavailable"
                elif "Sign in" in error_str and "cookies" in error_str:
                    logger.warning(f"[SKIP] Authentication required for: {title}")
                    return False, "auth_required"
                
                if attempt < self.config.max_retries - 1:
                    logger.warning(f"Download attempt {attempt + 1} failed for '{title}': {e}")
                    logger.info(f"Retrying in {self.config.retry_delay} seconds...")
                    time.sleep(self.config.retry_delay)
                else:
                    logger.error(f"[FAIL] Failed to download '{title}' after {self.config.max_retries} attempts: {e}")
                    return False, ""
        
        return False, ""
    
    def delete_video(self, video_id: str, title: str) -> bool:
        """Delete a video from the YouTube channel."""
        try:
            self.youtube.videos().delete(id=video_id).execute()
            logger.info(f"[OK] Deleted from channel: {title}")
            return True
        except HttpError as e:
            logger.error(f"[FAIL] Failed to delete '{title}': {e}")
            return False
        except Exception as e:
            logger.error(f"[FAIL] Unexpected error deleting '{title}': {e}")
            return False
    
    def display_videos_summary(self, videos: List[Dict]):
        """Display a summary of all videos."""
        print(f"\n{'='*80}")
        print(f"CHANNEL VIDEOS SUMMARY")
        print(f"{'='*80}")
        print(f"Total videos found: {len(videos)}")
        
        if not videos:
            print("No videos found in your channel.")
            return
        
        # Group by privacy status
        privacy_counts = {}
        for video in videos:
            status = video["privacy_status"]
            privacy_counts[status] = privacy_counts.get(status, 0) + 1
        
        print(f"\nVideos by privacy status:")
        for status, count in privacy_counts.items():
            print(f"  {status.title()}: {count}")
        
        # Show first 10 videos
        print(f"\nFirst 10 videos:")
        print(f"{'No.':<4} {'Title':<50} {'Views':<10} {'Published':<12}")
        print(f"{'-'*80}")
        
        for i, video in enumerate(videos[:10], 1):
            dt = datetime.fromisoformat(video["published_at"].replace("Z", "+00:00"))
            title_short = video["title"][:47] + "..." if len(video["title"]) > 50 else video["title"]
            views = f"{video['view_count']:,}"
            print(f"{i:<4} {title_short:<50} {views:<10} {dt.date()}")
        
        if len(videos) > 10:
            print(f"... and {len(videos) - 10} more videos")
        print(f"{'-'*80}\n")

def main():
    """Main function to orchestrate the download process."""
    try:
        print("[YouTube Channel Video Downloader]")
        print("=" * 50)
        
        # Initialize downloader
        downloader = YouTubeDownloader(config)
        
        # Create download directory
        download_dir = Path(config.download_folder)
        download_dir.mkdir(parents=True, exist_ok=True)
        logger.info(f"Download folder: {download_dir}")
        
        # Step 1: Authenticate
        print("\n[Step 1] Authenticating with YouTube...")
        if not downloader.authenticate_youtube():
            raise YouTubeError("Authentication failed")
        
        # Step 2: Get channel ID
        print("\n[Step 2] Getting channel information...")
        downloader.get_channel_id()
        
        # Step 3: Fetch all videos
        print("\n[Step 3] Fetching all videos from channel...")
        videos = downloader.get_all_videos()
        
        if not videos:
            print("\n[OK] No videos found in your channel.")
            return
        
        # Step 4: Display summary
        downloader.display_videos_summary(videos)
        
        # Step 5: Create metadata backup
        print("\n[Step 4] Creating metadata backup...")
        backup_file = downloader.backup_metadata(videos)
        
        # Step 6: Get user preferences
        print("\n[Step 5] Configuration")
        print(f"Found {len(videos)} videos to process")
        print(f"Download location: {config.download_folder}")
        
        # Ask what to do
        print("\nWhat would you like to do?")
        print("1. Download videos only (safe)")
        print("2. Download videos and DELETE from channel (DESTRUCTIVE)")
        print("3. List videos only (no downloads)")
        print("0. Exit")
        
        # Check for non-interactive mode (for testing/automation)
        if len(sys.argv) > 1:
            choice = sys.argv[1]
            print(f"\nNon-interactive mode: Selected option {choice}")
            if choice not in ['0', '1', '2', '3']:
                print("Invalid choice provided. Exiting...")
                return
        else:
            while True:
                try:
                    choice = input("\nEnter your choice (0-3): ").strip()
                    if choice in ['0', '1', '2', '3']:
                        break
                    print("Please enter a valid choice (0-3)")
                except (KeyboardInterrupt, EOFError):
                    print("\n\nOperation cancelled by user.")
                    return
        
        if choice == '0':
            print("Exiting...")
            return
        elif choice == '3':
            print("[OK] Video listing complete.")
            return
        
        # Step 7: Download videos
        print(f"\n[Step 6] Downloading {len(videos)} videos...")
        downloaded_count = 0
        deleted_count = 0
        skipped_count = 0
        private_count = 0
        
        # Progress bar for downloads
        pbar = tqdm(total=len(videos), desc="Processing videos", unit="video")
        
        for i, video in enumerate(videos, 1):
            pbar.set_description(f"Processing: {video['title'][:30]}...")
            
            # Download video
            success, file_path = downloader.download_video(video, str(download_dir))
            
            if success:
                downloaded_count += 1
                
                # Delete if requested and download successful
                if choice == '2':
                    if downloader.delete_video(video["video_id"], video["title"]):
                        deleted_count += 1
            else:
                # Handle different skip reasons
                if file_path == "private_video_skipped":
                    private_count += 1
                    # Still delete private videos from channel if requested
                    if choice == '2':
                        if downloader.delete_video(video["video_id"], video["title"]):
                            deleted_count += 1
                            logger.info(f"[OK] Deleted private video from channel: {video['title']}")
                elif file_path in ["video_unavailable", "auth_required"]:
                    skipped_count += 1
                    # Don't delete unavailable videos - they might be temporarily unavailable
                else:
                    skipped_count += 1
            
            pbar.update(1)
            
            # Add a small delay between videos to avoid rate limits
            if i < len(videos):  # Don't sleep after the last video
                time.sleep(2)
        
        pbar.close()
        
        # Final summary
        print(f"\n{'='*80}")
        print(f"OPERATION COMPLETE")
        print(f"{'='*80}")
        print(f"Videos found: {len(videos)}")
        print(f"Videos downloaded: {downloaded_count}")
        print(f"Private videos (skipped download): {private_count}")
        print(f"Other videos skipped: {skipped_count}")
        if choice == '2':
            print(f"Videos deleted from channel: {deleted_count}")
            if private_count > 0:
                print(f"Note: Private videos were deleted from channel even though they couldn't be downloaded")
        print(f"Download location: {config.download_folder}")
        if backup_file:
            print(f"Metadata backup: {backup_file}")
        print(f"Log files: {Path(config.download_folder) / 'logs'}")
        print("[SUCCESS] All operations completed successfully!")
        
    except KeyboardInterrupt:
        print("\n\nOperation cancelled by user.")
        logger.info("Operation cancelled by user")
    except YouTubeError as e:
        print(f"\n[ERROR] YouTube Error: {e}")
        logger.error(f"YouTube Error: {e}")
    except Exception as e:
        print(f"\n[ERROR] Unexpected Error: {e}")
        logger.error(f"Unexpected Error: {e}", exc_info=True)

if __name__ == "__main__":
    main()