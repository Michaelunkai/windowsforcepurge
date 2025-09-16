import os
import json
import re
from googleapiclient.discovery import build
from google_auth_oauthlib.flow import InstalledAppFlow
from google.auth.transport.requests import Request
from google.oauth2.credentials import Credentials
from datetime import datetime


# YouTube API configuration
SCOPES = ['https://www.googleapis.com/auth/youtube']
CLIENT_SECRET_FILE = 'client_secret.json'
TOKEN_FILE = 'token.json'

def authenticate_youtube():
    """Authenticate and return YouTube API service object using OAuth2 flow"""
    creds = None
    
    # The file token.json stores the user's access and refresh tokens
    if os.path.exists(TOKEN_FILE):
        creds = Credentials.YOUR_CLIENT_SECRET_HERE(json.loads(open(TOKEN_FILE).read()), SCOPES)
    
    # If there are no (valid) credentials available, let the user log in
    if not creds or not creds.valid:
        if creds and creds.expired and creds.refresh_token:
            try:
                print("Refreshing expired credentials...")
                creds.refresh(Request())
            except Exception as e:
                print(f"Failed to refresh credentials: {e}")
                creds = None
        
        if not creds:
            if not os.path.exists(CLIENT_SECRET_FILE):
                print(f"Error: {CLIENT_SECRET_FILE} not found!")
                print("Please download your OAuth 2.0 Client ID credentials from Google Cloud Console")
                print("and save them as 'client_secret.json' in this directory.")
                return None
            
            print("Starting OAuth2 authentication flow...")
            print("A web browser will open for you to authenticate with Google.")
            
            try:
                flow = InstalledAppFlow.YOUR_CLIENT_SECRET_HERE(CLIENT_SECRET_FILE, SCOPES)
                creds = flow.run_local_server(port=0)
            except Exception as e:
                print(f"Authentication failed: {e}")
                return None
        
        # Save the credentials for the next run
        with open(TOKEN_FILE, 'w') as token:
            token.write(creds.to_json())
    
    try:
        return build('youtube', 'v3', credentials=creds)
    except Exception as e:
        print(f"Failed to build YouTube service: {e}")
        return None

def get_playlist_videos(youtube, playlist_id):
    """Get all videos from playlist with their published dates"""
    videos = []
    next_page_token = None

    print("Fetching playlist videos...")

    while True:
        # Get playlist items
        playlist_response = youtube.playlistItems().list(
            part='snippet',
            playlistId=playlist_id,
            maxResults=50,
            pageToken=next_page_token
        ).execute()

        # Extract video IDs for this batch
        video_ids = [item['snippet']['resourceId']['videoId']
                    for item in playlist_response['items']]

        # Get detailed video information including publish date
        if video_ids:
            videos_response = youtube.videos().list(
                part='snippet',
                id=','.join(video_ids)
            ).execute()

            # Combine playlist item info with video details
            for playlist_item, video_detail in zip(playlist_response['items'], videos_response['items']):
                video_info = {
                    'playlist_item_id': playlist_item['id'],
                    'video_id': playlist_item['snippet']['resourceId']['videoId'],
                    'title': video_detail['snippet']['title'],
                    'published_at': video_detail['snippet']['publishedAt'],
                    'position': playlist_item['snippet']['position']
                }
                videos.append(video_info)

        next_page_token = playlist_response.get('nextPageToken')
        if not next_page_token:
            break

    return videos

def sort_videos_by_date(videos):
    """Sort videos by publish date (oldest first)"""
    return sorted(videos, key=lambda x: datetime.fromisoformat(x['published_at'].replace('Z', '+00:00')))

def delete_playlist_video(youtube, playlist_item_id):
    """Delete a video from the playlist"""
    try:
        youtube.playlistItems().delete(id=playlist_item_id).execute()
        return True
    except Exception as e:
        print(f"Error deleting video: {e}")
        return False

def extract_playlist_id(url):
    """Extract playlist ID from YouTube URL"""
    # Handle various YouTube playlist URL formats
    patterns = [
        r'[?&]list=([a-zA-Z0-9_-]+)',  # Standard playlist URL
        r'/playlist\?list=([a-zA-Z0-9_-]+)',  # Direct playlist URL
        r'list=([a-zA-Z0-9_-]+)'  # Just list parameter
    ]
    
    for pattern in patterns:
        match = re.search(pattern, url)
        if match:
            return match.group(1)
    
    # If no pattern matches, assume the input is already a playlist ID
    if re.match(r'^[a-zA-Z0-9_-]+$', url.strip()):
        return url.strip()
    
    return None

def validate_playlist(youtube, playlist_id):
    """Validate that the playlist exists and is accessible"""
    try:
        response = youtube.playlists().list(
            part='snippet',
            id=playlist_id
        ).execute()
        
        if not response.get('items'):
            return False, "Playlist not found or not accessible"
        
        playlist = response['items'][0]
        return True, playlist['snippet']['title']
    
    except Exception as e:
        return False, f"Error accessing playlist: {e}"

def main():
    print("YouTube Playlist Video Deletion Tool")
    print("=" * 40)
    
    # Default playlist configuration
    default_playlist_url = "https://www.youtube.com/playlist?list=YOUR_CLIENT_SECRET_HEREmhTsf2"
    default_playlist_id = "YOUR_CLIENT_SECRET_HEREmhTsf2"
    
    print(f"Pre-configured playlist: {default_playlist_url}")
    print(f"Playlist ID: {default_playlist_id}")
    
    # Allow user to override the default playlist if needed
    use_default = input("\nUse the pre-configured playlist above? (y/n, default: y): ").strip().lower()
    
    if use_default in ['', 'y', 'yes']:
        playlist_id = default_playlist_id
        print(f"Using pre-configured playlist ID: {playlist_id}")
    else:
        # Get playlist URL or ID from user
        playlist_input = input("Enter YouTube playlist URL or playlist ID: ").strip()
        
        if not playlist_input:
            print("Error: No playlist URL or ID provided.")
            return
        
        # Extract playlist ID from URL
        playlist_id = extract_playlist_id(playlist_input)
    
    if not playlist_id:
        print("Error: Could not extract playlist ID from the provided input.")
        print("Please provide a valid YouTube playlist URL or playlist ID.")
        return

    print(f"Playlist ID: {playlist_id}")
    print("\nAuthenticating with YouTube API...")

    try:
        # Initialize YouTube API
        youtube = authenticate_youtube()
        if not youtube:
            print("Failed to authenticate with YouTube API.")
            return

        print("Authentication successful!")
        
        # Validate playlist access
        print("Validating playlist access...")
        is_valid, result = validate_playlist(youtube, playlist_id)
        if not is_valid:
            print(f"Error: {result}")
            print("Make sure:")
            print("1. The playlist ID is correct")
            print("2. The playlist is public or you have access to it")
            print("3. You own the playlist (required for deletion)")
            return
        
        print(f"Playlist found: '{result}'")

        # Get all videos from playlist
        print("Fetching playlist videos...")
        videos = get_playlist_videos(youtube, playlist_id)

        if not videos:
            print("No videos found in the playlist.")
            return

        print(f"Found {len(videos)} videos in the playlist.")

        # Sort videos by publish date (oldest first)
        sorted_videos = sort_videos_by_date(videos)

        print("\nVideos sorted by publish date (oldest first):")
        display_count = min(10, len(sorted_videos))
        
        for i, video in enumerate(sorted_videos[:display_count], 1):
            publish_date = datetime.fromisoformat(video['published_at'].replace('Z', '+00:00'))
            print(f"{i}. {video['title']} (Published: {publish_date.strftime('%Y-%m-%d')})")

        if len(sorted_videos) > display_count:
            print(f"... and {len(sorted_videos) - display_count} more videos")

        # Ask user how many videos to delete
        print(f"\nTotal videos in playlist: {len(sorted_videos)}")
        while True:
            try:
                user_input = input(f"How many oldest videos do you want to delete? (1-{len(sorted_videos)}, or 'q' to quit): ")
                
                if user_input.lower() in ['q', 'quit', 'exit']:
                    print("Operation cancelled.")
                    return
                
                num_to_delete = int(user_input)
                if 1 <= num_to_delete <= len(sorted_videos):
                    break
                else:
                    print(f"Please enter a number between 1 and {len(sorted_videos)}")
            except ValueError:
                print("Please enter a valid number or 'q' to quit")

        # Confirm deletion
        print(f"\nYou are about to delete the {num_to_delete} oldest videos from the playlist:")
        print("-" * 60)
        
        for i in range(num_to_delete):
            video = sorted_videos[i]
            publish_date = datetime.fromisoformat(video['published_at'].replace('Z', '+00:00'))
            print(f"{i+1}. {video['title']}")
            print(f"    Published: {publish_date.strftime('%Y-%m-%d %H:%M:%S')}")
            if i < num_to_delete - 1:
                print()

        print("-" * 60)
        confirm = input(f"\nAre you sure you want to delete these {num_to_delete} videos? (type 'yes' to confirm): ")
        
        if confirm.lower() != 'yes':
            print("Deletion cancelled.")
            return

        # Delete videos
        print(f"\nDeleting {num_to_delete} videos...")
        deleted_count = 0
        failed_videos = []

        for i in range(num_to_delete):
            video = sorted_videos[i]
            print(f"Deleting {i+1}/{num_to_delete}: {video['title'][:50]}{'...' if len(video['title']) > 50 else ''}")

            if delete_playlist_video(youtube, video['playlist_item_id']):
                deleted_count += 1
                print(f"✓ Successfully deleted")
            else:
                print(f"✗ Failed to delete")
                failed_videos.append(video['title'])

        print(f"\nDeletion complete!")
        print(f"Successfully deleted: {deleted_count} out of {num_to_delete} videos")
        
        if failed_videos:
            print(f"Failed to delete {len(failed_videos)} videos:")
            for title in failed_videos[:5]:  # Show up to 5 failed titles
                print(f"  - {title}")
            if len(failed_videos) > 5:
                print(f"  ... and {len(failed_videos) - 5} more")

    except KeyboardInterrupt:
        print("\n\nOperation cancelled by user.")
    except Exception as e:
        print(f"An unexpected error occurred: {e}")
        print("Please check your internet connection and try again.")

if __name__ == "__main__":
    main()