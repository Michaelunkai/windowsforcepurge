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

# Search terms for cigar-related content
CIGAR_SEARCH_TERMS = [
    "cigar review",
    "cigar smoking", 
    "premium cigars",
    "cigar tasting",
    "cigar unboxing",
    "cigar collection",
    "Cuban cigars",
    "cigar lounge",
    "cigar pairing",
    "cigar tutorial"
]

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

def search_cigar_videos(youtube, search_term, min_views=10000, max_results=50):
    """Search for cigar-related videos with minimum view count"""
    if not track_quota_usage(100):  # search costs 100 units
        return []
    
    try:
        # Search for videos published in the last 2 years for better relevance
        published_after = (datetime.now() - timedelta(days=730)).isoformat() + 'Z'
        
        search_response = youtube.search().list(
            q=search_term,
            part='id,snippet',
            type='video',
            order='relevance',
            maxResults=max_results,
            publishedAfter=published_after,
            videoCategoryId='24'  # Entertainment category
        ).execute()
        
        video_ids = []
        for item in search_response['items']:
            video_ids.append(item['id']['videoId'])
        
        if not video_ids:
            return []
        
        # Get video statistics to check view counts
        if not track_quota_usage(1):  # videos.list costs 1 unit per request
            return []
            
        videos_response = youtube.videos().list(
            part='statistics,snippet',
            id=','.join(video_ids)
        ).execute()
        
        qualified_videos = []
        for video in videos_response['items']:
            view_count = int(video['statistics'].get('viewCount', 0))
            if view_count >= min_views:
                video_info = {
                    'video_id': video['id'],
                    'title': video['snippet']['title'],
                    'channel_title': video['snippet']['channelTitle'],
                    'view_count': view_count,
                    'published_at': video['snippet']['publishedAt']
                }
                qualified_videos.append(video_info)
        
        return qualified_videos
        
    except Exception as e:
        print(f"Error searching for videos with term '{search_term}': {e}")
        return []

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

def save_progress(videos_added, filename='cigar_playlist_progress.json'):
    """Save progress to resume later if needed"""
    progress_data = {
        'videos_added': videos_added,
        'timestamp': datetime.now().isoformat(),
        'quota_used': quota_used
    }
    
    with open(filename, 'w') as f:
        json.dump(progress_data, f, indent=2)

def load_progress(filename='cigar_playlist_progress.json'):
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
        print("Invalid playlist URL. Please provide a valid YouTube playlist URL.")
        return

    print(f"Target Playlist ID: {playlist_id}")
    print("Authenticating with YouTube API...")

    try:
        # Initialize YouTube API
        youtube = authenticate_youtube()
        print("Authentication successful!")
        
        # Load previous progress
        previously_added = load_progress()
        if previously_added:
            print(f"Resuming from previous session. {len(previously_added)} videos already processed today.")
        
        # Get existing videos in playlist to avoid duplicates
        existing_videos = YOUR_CLIENT_SECRET_HERE(youtube, playlist_id)
        
        all_qualified_videos = []
        videos_added_today = 0
        
        print(f"\nStarting search for cigar videos with 10k+ views...")
        print(f"Current quota usage: {quota_used}/{QUOTA_LIMIT}")
        
        # Search using different terms to get variety
        for search_term in CIGAR_SEARCH_TERMS:
            if quota_used >= QUOTA_LIMIT:
                print("Quota limit reached. Stopping search.")
                break
                
            print(f"\nSearching for: '{search_term}'")
            videos = search_cigar_videos(youtube, search_term, min_views=10000, max_results=25)
            
            for video in videos:
                # Skip if already in playlist or already processed today
                if (video['video_id'] not in existing_videos and 
                    video['video_id'] not in [v['video_id'] for v in previously_added]):
                    all_qualified_videos.append(video)
            
            # Small delay to be respectful to the API
            time.sleep(1)
        
        if not all_qualified_videos:
            print("No new qualified videos found.")
            return
        
        # Remove duplicates and sort by view count (highest first)
        unique_videos = {}
        for video in all_qualified_videos:
            video_id = video['video_id']
            if video_id not in unique_videos:
                unique_videos[video_id] = video
        
        sorted_videos = sorted(unique_videos.values(), 
                             key=lambda x: x['view_count'], reverse=True)
        
        print(f"\nFound {len(sorted_videos)} unique qualified videos")
        print("Top 10 videos by view count:")
        for i, video in enumerate(sorted_videos[:10], 1):
            print(f"{i}. {video['title']} ({video['view_count']:,} views) - {video['channel_title']}")
        
        # Calculate how many videos we can add with remaining quota
        remaining_quota = QUOTA_LIMIT - quota_used
        max_videos_to_add = min(len(sorted_videos), remaining_quota // 50)
        
        if max_videos_to_add == 0:
            print("Insufficient quota remaining to add videos.")
            return
        
        print(f"\nCan add up to {max_videos_to_add} videos with remaining quota.")
        
        # Ask user how many to add
        while True:
            try:
                num_to_add = input(f"How many videos to add? (1-{max_videos_to_add}) or 'all': ")
                if num_to_add.lower() == 'all':
                    num_to_add = max_videos_to_add
                    break
                else:
                    num_to_add = int(num_to_add)
                    if 1 <= num_to_add <= max_videos_to_add:
                        break
                    else:
                        print(f"Please enter a number between 1 and {max_videos_to_add}")
            except ValueError:
                print("Please enter a valid number or 'all'")
        
        # Add videos to playlist
        print(f"\nAdding {num_to_add} videos to playlist...")
        added_videos = []
        
        for i in range(num_to_add):
            if quota_used >= QUOTA_LIMIT:
                print("Quota limit reached. Stopping.")
                break
                
            video = sorted_videos[i]
            print(f"Adding {i+1}/{num_to_add}: {video['title']}")
            
            if add_video_to_playlist(youtube, playlist_id, video['video_id']):
                added_videos.append(video)
                videos_added_today += 1
                print(f"✅ Successfully added ({video['view_count']:,} views)")
            else:
                print(f"❌ Failed to add")
            
            # Save progress every 5 videos
            if len(added_videos) % 5 == 0:
                save_progress(previously_added + added_videos)
            
            # Small delay between additions
            time.sleep(0.5)
        
        # Final progress save
        save_progress(previously_added + added_videos)
        
        print(f"\n🎉 Process complete!")
        print(f"Successfully added {len(added_videos)} videos to the playlist")
        print(f"Total quota used: {quota_used}/{QUOTA_LIMIT}")
        print(f"Remaining quota: {QUOTA_LIMIT - quota_used}")
        
        if len(added_videos) > 0:
            avg_views = sum(v['view_count'] for v in added_videos) // len(added_videos)
            print(f"Average views of added videos: {avg_views:,}")

    except FileNotFoundError:
        print(f"Error: {CLIENT_SECRET_FILE} not found in the current directory.")
        print("Please make sure your client_secret.json file is in the same directory as this script.")
    except Exception as e:
        print(f"An error occurred: {e}")

if __name__ == "__main__":
    main()
