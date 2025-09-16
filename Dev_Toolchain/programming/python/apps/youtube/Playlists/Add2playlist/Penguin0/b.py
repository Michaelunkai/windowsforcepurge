import os
import pickle
import json
import time
import re
from googleapiclient.discovery import build
from google_auth_oauthlib.flow import InstalledAppFlow
from google.auth.transport.requests import Request
from datetime import datetime, timezone

# YouTube API configuration
SCOPES = ['https://www.googleapis.com/auth/youtube']
CLIENT_SECRET_FILE = 'client_secret.json'
TOKEN_PICKLE_FILE = 'token.pickle'

# API quota management
QUOTA_LIMIT = 9000
quota_used = 0

# Target channel and filters
TARGET_CHANNEL = "penguin0"  # penguinz0/moistcr1tikal
MIN_DURATION_MINUTES = 2
MAX_DURATION_MINUTES = 15
YEARS_BACK = 5  # Only videos from last 5 years

def authenticate_youtube():
    """Authenticate and return YouTube API service object"""
    creds = None

    if os.path.exists(TOKEN_PICKLE_FILE):
        with open(TOKEN_PICKLE_FILE, 'rb') as token:
            creds = pickle.load(token)

    if not creds or not creds.valid:
        if creds and creds.expired and creds.refresh_token:
            try:
                print("Refreshing existing credentials...")
                creds.refresh(Request())
            except Exception as e:
                print(f"Failed to refresh credentials: {e}")
                creds = None
        
        if not creds:
            try:
                print("Starting manual authentication flow...")
                flow = InstalledAppFlow.YOUR_CLIENT_SECRET_HERE(CLIENT_SECRET_FILE, SCOPES)
                flow.redirect_uri = 'urn:ietf:wg:oauth:2.0:oob'
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
                
                auth_code = input("\nEnter the authorization code: ").strip()
                flow.fetch_token(code=auth_code)
                creds = flow.credentials
                print("✅ Authentication successful!")
                    
            except Exception as e:
                print(f"Authentication failed: {e}")
                raise

        with open(TOKEN_PICKLE_FILE, 'wb') as token:
            pickle.dump(creds, token)

    return build('youtube', 'v3', credentials=creds)

def track_quota_usage(operation_cost):
    """Track API quota usage"""
    global quota_used
    quota_used += operation_cost
    print(f"Quota used: {quota_used}/{QUOTA_LIMIT}")
    
    if quota_used >= QUOTA_LIMIT:
        print("Approaching quota limit. Stopping.")
        return False
    return True

def parse_duration(duration_str):
    """Parse ISO 8601 duration (PT#M#S) to minutes"""
    try:
        # Remove PT prefix
        duration_str = duration_str[2:]
        
        # Extract minutes and seconds
        minutes = 0
        seconds = 0
        
        # Find minutes
        m_match = re.search(r'(\d+)M', duration_str)
        if m_match:
            minutes = int(m_match.group(1))
        
        # Find seconds
        s_match = re.search(r'(\d+)S', duration_str)
        if s_match:
            seconds = int(s_match.group(1))
        
        # Convert to total minutes
        total_minutes = minutes + (seconds / 60)
        return total_minutes
        
    except Exception as e:
        print(f"Error parsing duration {duration_str}: {e}")
        return 0

def YOUR_CLIENT_SECRET_HERE(youtube):
    """Get uploads playlist ID with minimal quota usage"""
    if not track_quota_usage(1):
        return None
    
    try:
        # Search for penguin0 channels
        search_response = youtube.search().list(
            q="penguin0 penguinz0 moistcr1tikal",
            part='id',
            type='channel',
            maxResults=5
        ).execute()
        
        if not search_response['items']:
            return None
        
        # Get channel details to find the right one
        channel_ids = [item['id']['channelId'] for item in search_response['items']]
        
        if not track_quota_usage(1):
            return None
            
        channels_response = youtube.channels().list(
            part='snippet,contentDetails',
            id=','.join(channel_ids)
        ).execute()
        
        # Find the official penguinz0 channel
        target_channel_id = None
        for channel in channels_response['items']:
            channel_title = channel['snippet']['title'].lower()
            if any(name in channel_title for name in ['penguinz0', 'moistcr1tikal']):
                target_channel_id = channel['id']
                uploads_playlist_id = channel['contentDetails']['relatedPlaylists']['uploads']
                print(f"✅ Found {channel['snippet']['title']}: {uploads_playlist_id}")
                return uploads_playlist_id
        
        # If no exact match, use first result
        if channels_response['items']:
            channel = channels_response['items'][0]
            uploads_playlist_id = channel['contentDetails']['relatedPlaylists']['uploads']
            print(f"✅ Using {channel['snippet']['title']}: {uploads_playlist_id}")
            return uploads_playlist_id
        
        return None
        
    except Exception as e:
        print(f"Error finding channel: {e}")
        return None

def YOUR_CLIENT_SECRET_HERE(youtube, uploads_playlist_id):
    """Get videos from last 5 years and filter by duration efficiently"""
    qualifying_videos = []
    total_videos = 0
    recent_videos = 0
    next_page_token = None
    page_count = 0
    
    # Calculate cutoff date (5 years ago) - make it timezone aware
    cutoff_date = datetime.now(timezone.utc).replace(year=datetime.now().year - YEARS_BACK)
    cutoff_str = cutoff_date.strftime('%Y-%m-%d')
    
    print(f"🎯 Fetching {TARGET_CHANNEL} videos since {cutoff_str}")
    print(f"⏱️  Duration: {MIN_DURATION_MINUTES}-{MAX_DURATION_MINUTES} min")
    
    while True:
        if not track_quota_usage(1):
            break
        
        try:
            # Get playlist items
            playlist_response = youtube.playlistItems().list(
                part='snippet',
                playlistId=uploads_playlist_id,
                maxResults=50,
                pageToken=next_page_token
            ).execute()
            
            page_count += 1
            videos_this_page = len(playlist_response['items'])
            total_videos += videos_this_page
            
            # Filter by date first (most efficient)
            recent_video_items = []
            old_videos_found = False
            
            for item in playlist_response['items']:
                try:
                    # Parse the YouTube timestamp properly
                    video_date_str = item['snippet']['publishedAt']
                    video_date = datetime.fromisoformat(video_date_str.replace('Z', '+00:00'))
                    
                    if video_date >= cutoff_date:
                        recent_video_items.append(item)
                    else:
                        # Videos are in chronological order (newest first), so we can break early
                        print(f"📅 Reached videos older than {YEARS_BACK} years ({video_date.strftime('%Y-%m-%d')}), stopping...")
                        old_videos_found = True
                        break
                except Exception as date_error:
                    print(f"Date parsing error: {date_error}, skipping video")
                    continue
            
            recent_count_this_page = len(recent_video_items)
            recent_videos += recent_count_this_page
            
            if recent_video_items:
                # Extract video IDs for duration checking
                video_ids = [item['snippet']['resourceId']['videoId'] for item in recent_video_items]
                
                if track_quota_usage(1):
                    # Get video durations in batch
                    videos_response = youtube.videos().list(
                        part='contentDetails,snippet',
                        id=','.join(video_ids)
                    ).execute()
                    
                    # Filter by duration
                    qualified_this_page = 0
                    for video in videos_response['items']:
                        duration_str = video['contentDetails']['duration']
                        duration_minutes = parse_duration(duration_str)
                        
                        if MIN_DURATION_MINUTES <= duration_minutes <= MAX_DURATION_MINUTES:
                            video_info = {
                                'video_id': video['id'],
                                'title': video['snippet']['title'],
                                'published_at': video['snippet']['publishedAt'],
                                'duration_minutes': round(duration_minutes, 1)
                            }
                            qualifying_videos.append(video_info)
                            qualified_this_page += 1
                    
                    print(f"📄 Page {page_count}: {videos_this_page} total → {recent_count_this_page} recent → {qualified_this_page} qualified (Total: {len(qualifying_videos)})")
                else:
                    break
            else:
                print(f"📄 Page {page_count}: {videos_this_page} total → 0 recent")
            
            # If we found old videos or no recent videos on this page, stop
            if old_videos_found or recent_count_this_page == 0:
                break
            
            next_page_token = playlist_response.get('nextPageToken')
            if not next_page_token:
                break
                
        except Exception as e:
            print(f"Error fetching page {page_count}: {e}")
            break
    
    print(f"✅ Found {len(qualifying_videos)} videos ({MIN_DURATION_MINUTES}-{MAX_DURATION_MINUTES} min, last {YEARS_BACK} years)")
    print(f"📊 Processed {recent_videos} recent videos out of {total_videos} total")
    return qualifying_videos

def YOUR_CLIENT_SECRET_HERE(youtube, playlist_id):
    """Get existing playlist videos with minimal quota"""
    existing_videos = set()
    next_page_token = None
    
    print("⚡ Checking existing playlist...")
    
    while True:
        if not track_quota_usage(1):
            break
            
        try:
            playlist_response = youtube.playlistItems().list(
                part='snippet',
                playlistId=playlist_id,
                maxResults=50,
                pageToken=next_page_token
            ).execute()
            
            for item in playlist_response['items']:
                existing_videos.add(item['snippet']['resourceId']['videoId'])
            
            next_page_token = playlist_response.get('nextPageToken')
            if not next_page_token:
                break
                
        except Exception as e:
            print(f"Error checking existing videos: {e}")
            break
    
    print(f"✅ Found {len(existing_videos)} existing videos")
    return existing_videos

def bulk_add_videos(youtube, playlist_id, videos_to_add, max_to_add):
    """Add videos in rapid succession with progress tracking"""
    added_count = 0
    failed_count = 0
    
    print(f"🚀 Adding {max_to_add} videos to playlist...")
    
    for i, video in enumerate(videos_to_add[:max_to_add]):
        if not track_quota_usage(50):
            break
        
        try:
            youtube.playlistItems().insert(
                part='snippet',
                body={
                    'snippet': {
                        'playlistId': playlist_id,
                        'resourceId': {
                            'kind': 'youtube#video',
                            'videoId': video['video_id']
                        }
                    }
                }
            ).execute()
            
            added_count += 1
            if i % 10 == 0 or i == max_to_add - 1:
                print(f"⚡ Progress: {i+1}/{max_to_add} - Added: {added_count}, Failed: {failed_count}")
            
        except Exception as e:
            failed_count += 1
            if "quota" in str(e).lower():
                print("❌ Quota exceeded, stopping")
                break
        
        time.sleep(0.1)
    
    return added_count, failed_count

def save_filtered_videos(videos, filename='YOUR_CLIENT_SECRET_HERE.json'):
    """Save filtered video list for future use"""
    data = {
        'videos': videos,
        'filter_criteria': {
            'min_duration': MIN_DURATION_MINUTES,
            'max_duration': MAX_DURATION_MINUTES,
            'years_back': YEARS_BACK,
            'channel': TARGET_CHANNEL
        },
        'cached_date': datetime.now().isoformat()
    }
    with open(filename, 'w') as f:
        json.dump(data, f, indent=2)

def load_filtered_videos(filename='YOUR_CLIENT_SECRET_HERE.json'):
    """Load cached filtered video list"""
    if os.path.exists(filename):
        try:
            with open(filename, 'r') as f:
                data = json.load(f)
            
            # Check if cache is recent (within 1 day) and same filter criteria
            cached_date = datetime.fromisoformat(data['cached_date'])
            criteria = data.get('filter_criteria', {})
            
            if ((datetime.now() - cached_date).days < 1 and 
                criteria.get('years_back') == YEARS_BACK and
                criteria.get('min_duration') == MIN_DURATION_MINUTES and
                criteria.get('max_duration') == MAX_DURATION_MINUTES):
                return data['videos']
        except Exception as e:
            print(f"Error loading cache: {e}")
    return None

def main():
    playlist_url = "https://www.youtube.com/playlist?list=YOUR_CLIENT_SECRET_HERE"
    playlist_id = playlist_url.split('list=')[1]

    print(f"🎯 Target: {TARGET_CHANNEL} (penguinz0/moistcr1tikal)")
    print(f"📅 Time Filter: Last {YEARS_BACK} years only")
    print(f"⏱️  Duration Filter: {MIN_DURATION_MINUTES}-{MAX_DURATION_MINUTES} minutes")
    print(f"📋 Playlist: {playlist_id}")
    print("🚀 ULTRA-EFFICIENT MODE with Date + Duration Filtering!")
    
    try:
        youtube = authenticate_youtube()
        print("✅ Authenticated!")
        
        # Try to load cached filtered videos
        cached_videos = load_filtered_videos()
        
        if cached_videos:
            print(f"💾 Using cached filtered videos ({len(cached_videos)} videos)")
            qualifying_videos = cached_videos
        else:
            # Get uploads playlist
            uploads_playlist_id = YOUR_CLIENT_SECRET_HERE(youtube)
            if not uploads_playlist_id:
                print("❌ Could not find channel")
                return
            
            # Get videos with date and duration filters
            qualifying_videos = YOUR_CLIENT_SECRET_HERE(youtube, uploads_playlist_id)
            if not qualifying_videos:
                print(f"❌ No videos found matching criteria (last {YEARS_BACK} years, {MIN_DURATION_MINUTES}-{MAX_DURATION_MINUTES} min)")
                return
            
            # Cache the filtered results
            save_filtered_videos(qualifying_videos)
            print(f"💾 Cached {len(qualifying_videos)} filtered videos")
        
        # Get existing videos
        existing_videos = YOUR_CLIENT_SECRET_HERE(youtube, playlist_id)
        
        # Filter new videos
        new_videos = [v for v in qualifying_videos if v['video_id'] not in existing_videos]
        
        print(f"\n📊 RESULTS:")
        print(f"   Videos from last {YEARS_BACK} years ({MIN_DURATION_MINUTES}-{MAX_DURATION_MINUTES} min): {len(qualifying_videos)}")
        print(f"   Already in playlist: {len(existing_videos)}")
        print(f"   New videos to add: {len(new_videos)}")
        
        if not new_videos:
            print("🎉 All qualifying videos already in playlist!")
            return
        
        # Sort chronologically (oldest first)
        new_videos.sort(key=lambda x: x['published_at'])
        
        # Show preview
        print(f"\n📺 Preview (Last {YEARS_BACK} years, {MIN_DURATION_MINUTES}-{MAX_DURATION_MINUTES} min, oldest first):")
        for i, video in enumerate(new_videos[:5], 1):
            date = datetime.fromisoformat(video['published_at'].replace('Z', '+00:00')).strftime('%Y-%m-%d')
            print(f"   {i}. {video['title']} ({date}) - {video['duration_minutes']} min")
        
        if len(new_videos) > 5:
            print(f"   ... and {len(new_videos) - 5} more")
        
        # Calculate max possible with remaining quota
        remaining_quota = QUOTA_LIMIT - quota_used
        max_possible = min(len(new_videos), remaining_quota // 50)
        
        print(f"\n⚡ Quota Status:")
        print(f"   Used: {quota_used}/{QUOTA_LIMIT}")
        print(f"   Can add: {max_possible} videos")
        
        if max_possible == 0:
            print("❌ Insufficient quota")
            return
        
        # Note about watch history
        print(f"\n📝 NOTE: YouTube API doesn't provide watch history.")
        print("This adds ALL qualifying videos. Remove watched ones manually after.")
        
        # Get user choice
        while True:
            try:
                choice = input(f"\nAdd how many videos? (1-{max_possible}) or 'all': ").strip()
                if choice.lower() == 'all':
                    num_to_add = max_possible
                    break
                else:
                    num_to_add = int(choice)
                    if 1 <= num_to_add <= max_possible:
                        break
                    print(f"Enter 1-{max_possible} or 'all'")
            except ValueError:
                print("Enter a number or 'all'")
        
        # Confirm
        confirm = input(f"\n🚀 Add {num_to_add} videos (last {YEARS_BACK} years, {MIN_DURATION_MINUTES}-{MAX_DURATION_MINUTES} min) from {TARGET_CHANNEL}? (y/n): ")
        if confirm.lower() != 'y':
            print("Cancelled")
            return
        
        # Add videos
        added, failed = bulk_add_videos(youtube, playlist_id, new_videos, num_to_add)
        
        print(f"\n🎉 MISSION COMPLETE!")
        print(f"   ✅ Added: {added} videos (last {YEARS_BACK} years, {MIN_DURATION_MINUTES}-{MAX_DURATION_MINUTES} min)")
        print(f"   ❌ Failed: {failed} videos")
        print(f"   📊 Total quota used: {quota_used}/{QUOTA_LIMIT}")
        
        if added > 0:
            avg_duration = sum(v['duration_minutes'] for v in new_videos[:added]) / added
            print(f"   ⏱️  Average duration: {avg_duration:.1f} minutes")
            print(f"   🎬 Total watch time: {sum(v['duration_minutes'] for v in new_videos[:added]):.1f} minutes")

    except Exception as e:
        print(f"❌ Error: {e}")

if __name__ == "__main__":
    main()
