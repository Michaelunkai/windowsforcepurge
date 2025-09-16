import os
import pickle
import json
import time
from googleapiclient.discovery import build
from google_auth_oauthlib.flow import InstalledAppFlow
from google.auth.transport.requests import Request
from datetime import datetime, timedelta

# YouTube API configuration
SCOPES = ['https://www.googleapis.com/auth/youtube']
CLIENT_SECRET_FILE = 'client_secret.json'
TOKEN_PICKLE_FILE = 'token.pickle'

# API quota management
QUOTA_LIMIT = 9000  # Leave some buffer under 10,000 daily limit
quota_used = 0

# Target channel
TARGET_CHANNEL = "videogamedunkey"

def authenticate_youtube():
    """Authenticate and return YouTube API service object"""
    creds = None

    # Load existing token if available
    if os.path.exists(TOKEN_PICKLE_FILE):
        with open(TOKEN_PICKLE_FILE, 'rb') as token:
            creds = pickle.load(token)

    # If there are no valid credentials, request authorization
    if not creds or not creds.valid:
        if creds and creds.expired and creds.refresh_token:
            try:
                print("Refreshing existing credentials...")
                creds.refresh(Request())
            except Exception as e:
                print(f"Failed to refresh credentials: {e}")
                print("Will request new authorization...")
                creds = None
        
        if not creds:
            try:
                print("Starting manual authentication flow...")
                flow = InstalledAppFlow.YOUR_CLIENT_SECRET_HERE(
                    CLIENT_SECRET_FILE, SCOPES)
                
                # Use manual flow instead of local server
                flow.redirect_uri = 'urn:ietf:wg:oauth:2.0:oob'
                
                # Get the authorization URL
                auth_url, _ = flow.authorization_url(prompt='consent')
                
                print("\n" + "="*50)
                print("MANUAL AUTHENTICATION REQUIRED")
                print("="*50)
                print("1. Open this URL in your browser:")
                print(f"\n{auth_url}\n")
                print("2. Complete the authorization")
                print("3. Copy the authorization code that appears")
                print("4. Paste it below")
                print("="*50)
                
                # Get the authorization code from user
                auth_code = input("\nEnter the authorization code: ").strip()
                
                # Exchange the code for credentials
                flow.fetch_token(code=auth_code)
                creds = flow.credentials
                
                print("✅ Authentication successful!")
                    
            except Exception as e:
                print(f"Authentication failed: {e}")
                print("\nMake sure you:")
                print("1. Opened the URL in your browser")
                print("2. Completed the Google authorization")
                print("3. Copied the FULL authorization code")
                print("4. Have the correct client_secret.json file")
                raise

        # Save credentials for next run
        with open(TOKEN_PICKLE_FILE, 'wb') as token:
            pickle.dump(creds, token)

    return build('youtube', 'v3', credentials=creds)

def track_quota_usage(operation_cost):
    """Track API quota usage"""
    global quota_used
    quota_used += operation_cost
    print(f"Quota used: {quota_used}/{QUOTA_LIMIT}")
    
    if quota_used >= QUOTA_LIMIT:
        print("Approaching quota limit. Stopping to avoid exceeding daily limit.")
        return False
    return True

def get_channel_id(youtube, channel_name):
    """Get channel ID from channel name/username"""
    if not track_quota_usage(1):  # search costs 1 unit
        return None
    
    try:
        # First try searching by channel name
        search_response = youtube.search().list(
            q=channel_name,
            part='id,snippet',
            type='channel',
            maxResults=5
        ).execute()
        
        # Look for exact match
        for item in search_response['items']:
            if item['snippet']['title'].lower() == channel_name.lower():
                return item['id']['channelId']
        
        # If no exact match, try the first result
        if search_response['items']:
            channel_id = search_response['items'][0]['id']['channelId']
            channel_title = search_response['items'][0]['snippet']['title']
            print(f"Found channel: {channel_title}")
            return channel_id
        
        return None
        
    except Exception as e:
        print(f"Error searching for channel: {e}")
        return None

def get_all_channel_videos(youtube, channel_id):
    """Get all videos from a channel"""
    videos = []
    
    # First, get the channel's uploads playlist
    if not track_quota_usage(1):  # channels.list costs 1 unit
        return videos
    
    try:
        channel_response = youtube.channels().list(
            part='contentDetails',
            id=channel_id
        ).execute()
        
        uploads_playlist_id = channel_response['items'][0]['contentDetails']['relatedPlaylists']['uploads']
        
    except Exception as e:
        print(f"Error getting uploads playlist: {e}")
        return videos
    
    # Get all videos from the uploads playlist
    next_page_token = None
    page_count = 0
    
    print(f"Fetching all videos from {TARGET_CHANNEL}...")
    
    while True:
        if not track_quota_usage(1):  # playlistItems.list costs 1 unit
            break
        
        try:
            playlist_response = youtube.playlistItems().list(
                part='snippet',
                playlistId=uploads_playlist_id,
                maxResults=50,
                pageToken=next_page_token
            ).execute()
            
            page_count += 1
            print(f"Fetched page {page_count}, found {len(playlist_response['items'])} videos")
            
            # Process videos in batches to get detailed info
            video_ids = []
            for item in playlist_response['items']:
                video_ids.append(item['snippet']['resourceId']['videoId'])
            
            # Get detailed video information
            if video_ids and track_quota_usage(1):  # videos.list costs 1 unit
                videos_response = youtube.videos().list(
                    part='snippet,statistics',
                    id=','.join(video_ids)
                ).execute()
                
                for video_detail in videos_response['items']:
                    video_info = {
                        'video_id': video_detail['id'],
                        'title': video_detail['snippet']['title'],
                        'published_at': video_detail['snippet']['publishedAt'],
                        'view_count': int(video_detail['statistics'].get('viewCount', 0)),
                        'like_count': int(video_detail['statistics'].get('likeCount', 0)),
                        'description': video_detail['snippet'].get('description', '')[:100] + '...'
                    }
                    videos.append(video_info)
            
            next_page_token = playlist_response.get('nextPageToken')
            if not next_page_token:
                break
                
        except Exception as e:
            print(f"Error fetching videos: {e}")
            break
    
    return videos

def YOUR_CLIENT_SECRET_HERE(youtube, playlist_id):
    """Get all video IDs already in the playlist to avoid duplicates"""
    existing_videos = set()
    next_page_token = None
    
    print("Checking existing videos in playlist...")
    
    while True:
        if not track_quota_usage(1):  # playlistItems.list costs 1 unit
            break
            
        try:
            playlist_response = youtube.playlistItems().list(
                part='snippet',
                playlistId=playlist_id,
                maxResults=50,
                pageToken=next_page_token
            ).execute()
            
            for item in playlist_response['items']:
                video_id = item['snippet']['resourceId']['videoId']
                existing_videos.add(video_id)
            
            next_page_token = playlist_response.get('nextPageToken')
            if not next_page_token:
                break
                
        except Exception as e:
            print(f"Error fetching existing playlist videos: {e}")
            break
    
    print(f"Found {len(existing_videos)} existing videos in playlist")
    return existing_videos

def add_video_to_playlist(youtube, playlist_id, video_id):
    """Add a video to the playlist"""
    if not track_quota_usage(50):  # playlistItems.insert costs 50 units
        return False
        
    try:
        youtube.playlistItems().insert(
            part='snippet',
            body={
                'snippet': {
                    'playlistId': playlist_id,
                    'resourceId': {
                        'kind': 'youtube#video',
                        'videoId': video_id
                    }
                }
            }
        ).execute()
        return True
    except Exception as e:
        print(f"Error adding video to playlist: {e}")
        return False

def save_progress(videos_added, channel_videos, filename='YOUR_CLIENT_SECRET_HERE.json'):
    """Save progress to resume later if needed"""
    progress_data = {
        'videos_added': videos_added,
        'total_channel_videos': len(channel_videos),
        'timestamp': datetime.now().isoformat(),
        'quota_used': quota_used
    }
    
    with open(filename, 'w') as f:
        json.dump(progress_data, f, indent=2)

def load_progress(filename='YOUR_CLIENT_SECRET_HERE.json'):
    """Load previous progress"""
    global quota_used
    
    if os.path.exists(filename):
        try:
            with open(filename, 'r') as f:
                progress_data = json.load(f)
            
            # Check if progress is from today
            progress_time = datetime.fromisoformat(progress_data['timestamp'])
            if progress_time.date() == datetime.now().date():
                quota_used = progress_data.get('quota_used', 0)
                return progress_data.get('videos_added', [])
        except Exception as e:
            print(f"Error loading progress: {e}")
    
    return []

def main():
    # Your playlist URL
    playlist_url = "https://www.youtube.com/playlist?list=YOUR_CLIENT_SECRET_HERE"
    
    try:
        playlist_id = playlist_url.split('list=')[1]
    except IndexError:
        print("Invalid playlist URL.")
        return

    print(f"Target Playlist ID: {playlist_id}")
    print(f"Target Channel: {TARGET_CHANNEL}")
    print("Authenticating with YouTube API...")

    try:
        # Initialize YouTube API
        youtube = authenticate_youtube()
        print("Authentication successful!")
        
        # Load previous progress
        previously_added = load_progress()
        if previously_added:
            print(f"Resuming from previous session. {len(previously_added)} videos already processed today.")
        
        # Get channel ID
        print(f"\nFinding {TARGET_CHANNEL}'s channel...")
        channel_id = get_channel_id(youtube, TARGET_CHANNEL)
        
        if not channel_id:
            print(f"Could not find channel '{TARGET_CHANNEL}'. Please check the channel name.")
            return
        
        print(f"✅ Found channel ID: {channel_id}")
        
        # Get all videos from the channel
        print(f"\nFetching all videos from {TARGET_CHANNEL}...")
        channel_videos = get_all_channel_videos(youtube, channel_id)
        
        if not channel_videos:
            print("No videos found in the channel.")
            return
        
        print(f"✅ Found {len(channel_videos)} total videos from {TARGET_CHANNEL}")
        
        # Get existing videos in playlist to avoid duplicates
        existing_videos = YOUR_CLIENT_SECRET_HERE(youtube, playlist_id)
        
        # Filter out videos already in playlist
        new_videos = []
        for video in channel_videos:
            if video['video_id'] not in existing_videos:
                new_videos.append(video)
        
        print(f"📋 {len(new_videos)} videos not yet in your playlist")
        
        if not new_videos:
            print("All videos from this channel are already in your playlist!")
            return
        
        # Sort videos by publish date (oldest first, so you watch in order)
        new_videos.sort(key=lambda x: x['published_at'])
        
        print(f"\n📺 Preview of videos to add (showing first 10):")
        for i, video in enumerate(new_videos[:10], 1):
            publish_date = datetime.fromisoformat(video['published_at'].replace('Z', '+00:00'))
            print(f"{i}. {video['title']} ({publish_date.strftime('%Y-%m-%d')}) - {video['view_count']:,} views")
        
        if len(new_videos) > 10:
            print(f"... and {len(new_videos) - 10} more videos")
        
        # Calculate how many videos we can add with remaining quota
        remaining_quota = QUOTA_LIMIT - quota_used
        max_videos_to_add = min(len(new_videos), remaining_quota // 50)
        
        if max_videos_to_add == 0:
            print("Insufficient quota remaining to add videos.")
            return
        
        print(f"\n⚡ Can add up to {max_videos_to_add} videos with remaining quota.")
        
        # Ask user how many to add
        print(f"\n🎯 IMPORTANT NOTE: YouTube API doesn't provide access to watch history.")
        print("This will add ALL videos from the channel. You'll need to manually remove")
        print("any videos you've already watched from the playlist afterwards.")
        
        while True:
            try:
                user_input = input(f"\nHow many videos to add? (1-{max_videos_to_add}) or 'all': ")
                if user_input.lower() == 'all':
                    num_to_add = max_videos_to_add
                    break
                else:
                    num_to_add = int(user_input)
                    if 1 <= num_to_add <= max_videos_to_add:
                        break
                    else:
                        print(f"Please enter a number between 1 and {max_videos_to_add}")
            except ValueError:
                print("Please enter a valid number or 'all'")
        
        # Confirm before adding
        confirm = input(f"\nAdd {num_to_add} videos from {TARGET_CHANNEL} to your playlist? (yes/no): ")
        if confirm.lower() not in ['yes', 'y']:
            print("Cancelled.")
            return
        
        # Add videos to playlist
        print(f"\n🚀 Adding {num_to_add} videos to playlist...")
        added_videos = []
        
        for i in range(num_to_add):
            if quota_used >= QUOTA_LIMIT:
                print("Quota limit reached. Stopping.")
                break
                
            video = new_videos[i]
            print(f"Adding {i+1}/{num_to_add}: {video['title']}")
            
            if add_video_to_playlist(youtube, playlist_id, video['video_id']):
                added_videos.append(video)
                print(f"✅ Successfully added ({video['view_count']:,} views)")
            else:
                print(f"❌ Failed to add")
            
            # Save progress every 5 videos
            if len(added_videos) % 5 == 0:
                save_progress(previously_added + added_videos, channel_videos)
            
            # Small delay between additions
            time.sleep(0.5)
        
        # Final progress save
        save_progress(previously_added + added_videos, channel_videos)
        
        print(f"\n🎉 Process complete!")
        print(f"Successfully added {len(added_videos)} videos to your playlist")
        print(f"Total quota used: {quota_used}/{QUOTA_LIMIT}")
        
        if len(added_videos) > 0:
            avg_views = sum(v['view_count'] for v in added_videos) // len(added_videos)
            print(f"Average views of added videos: {avg_views:,}")
            
            print(f"\n📝 Next steps:")
            print("1. Check your playlist for the new videos")
            print("2. Manually remove any videos you've already watched")
            print("3. Enjoy watching dunkey's content in chronological order!")

    except FileNotFoundError:
        print(f"Error: {CLIENT_SECRET_FILE} not found in the current directory.")
        print("Please make sure your client_secret.json file is in the same directory as this script.")
    except Exception as e:
        print(f"An error occurred: {e}")

if __name__ == "__main__":
    main()
