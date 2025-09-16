import os
import pickle
import json
import time
from googleapiclient.discovery import build
from google_auth_oauthlib.flow import InstalledAppFlow
from google.auth.transport.requests import Request
from datetime import datetime, timedelta, timezone
import re

# YouTube API configuration
SCOPES = ['https://www.googleapis.com/auth/youtube.readonly', 'https://www.googleapis.com/auth/youtube']
CLIENT_SECRET_FILE = 'client_secret.json'
TOKEN_PICKLE_FILE = 'token.pickle'

# API quota management
QUOTA_LIMIT = 9000
quota_used = 0

# Target channel and playlist (FIXED - no more prompting)
TARGET_CHANNEL = "videogamedunkey"
PLAYLIST_URL = "https://www.youtube.com/playlist?list=YOUR_CLIENT_SECRET_HERE"
PLAYLIST_ID = "YOUR_CLIENT_SECRET_HERE"

# Date filtering - last 6 years (FIXED)
YEARS_BACK = 6
# Create timezone-aware cutoff date to fix datetime comparison error
cutoff_date = datetime.now(timezone.utc) - timedelta(days=YEARS_BACK * 365)

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

def load_watched_video_ids(filename='watched_videos.txt'):
    """Load watched video IDs from file"""
    watched_ids = set()
    if os.path.exists(filename):
        try:
            with open(filename, 'r') as f:
                for line in f:
                    line = line.strip()
                    if line:
                        # Handle full URLs or just video IDs
                        if 'watch?v=' in line:
                            video_id = line.split('watch?v=')[1].split('&')[0]
                        elif 'youtu.be/' in line:
                            video_id = line.split('youtu.be/')[1].split('?')[0]
                        else:
                            video_id = line
                        watched_ids.add(video_id)
            print(f"📋 Loaded {len(watched_ids)} watched video IDs from {filename}")
        except Exception as e:
            print(f"Error loading watched videos: {e}")
    else:
        print(f"📋 No watched videos file found ({filename})")
    return watched_ids

def get_liked_videos(youtube):
    """Get user's liked videos to infer watched status"""
    liked_videos = set()
    next_page_token = None
    
    print("💖 Checking liked videos...")
    
    while True:
        if not track_quota_usage(1):
            break
            
        try:
            response = youtube.videos().list(
                part='id',
                myRating='like',
                maxResults=50,
                pageToken=next_page_token
            ).execute()
            
            for item in response['items']:
                liked_videos.add(item['id'])
            
            next_page_token = response.get('nextPageToken')
            if not next_page_token:
                break
                
        except Exception as e:
            print(f"Error getting liked videos: {e}")
            break
    
    print(f"💖 Found {len(liked_videos)} liked videos")
    return liked_videos

def get_watch_later_videos(youtube):
    """Get videos from Watch Later playlist"""
    watch_later_videos = set()
    
    print("⏰ Checking Watch Later playlist...")
    
    try:
        # Watch Later has a special playlist ID
        watch_later_id = "WL"
        next_page_token = None
        
        while True:
            if not track_quota_usage(1):
                break
                
            response = youtube.playlistItems().list(
                part='snippet',
                playlistId=watch_later_id,
                maxResults=50,
                pageToken=next_page_token
            ).execute()
            
            for item in response['items']:
                watch_later_videos.add(item['snippet']['resourceId']['videoId'])
            
            next_page_token = response.get('nextPageToken')
            if not next_page_token:
                break
                
    except Exception as e:
        print(f"Error getting Watch Later videos: {e}")
    
    print(f"⏰ Found {len(watch_later_videos)} videos in Watch Later")
    return watch_later_videos

def YOUR_CLIENT_SECRET_HERE(youtube):
    """Get uploads playlist ID with minimal quota usage"""
    if not track_quota_usage(1):
        return None

    try:
        # Direct search for the channel
        search_response = youtube.search().list(
            q=TARGET_CHANNEL,
            part='id',
            type='channel',
            maxResults=1
        ).execute()

        if not search_response['items']:
            return None

        channel_id = search_response['items'][0]['id']['channelId']

        # Get uploads playlist
        if not track_quota_usage(1):
            return None

        channel_response = youtube.channels().list(
            part='contentDetails',
            id=channel_id
        ).execute()

        uploads_playlist_id = channel_response['items'][0]['contentDetails']['relatedPlaylists']['uploads']
        print(f"✅ Found uploads playlist: {uploads_playlist_id}")
        return uploads_playlist_id

    except Exception as e:
        print(f"Error finding channel: {e}")
        return None

def get_all_recent_videos(youtube, uploads_playlist_id, years_back=6):
    """Get ALL videos from the last N years - COMPREHENSIVE SEARCH"""
    recent_videos = []
    next_page_token = None
    page_count = 0
    videos_found = 0
    
    print(f"📅 COMPREHENSIVE SEARCH: Fetching ALL videos from {TARGET_CHANNEL} since {cutoff_date.strftime('%Y-%m-%d')}")
    print("🔍 This will get EVERY SINGLE video, guaranteed!")

    while True:
        if not track_quota_usage(1):
            break

        try:
            playlist_response = youtube.playlistItems().list(
                part='snippet',
                playlistId=uploads_playlist_id,
                maxResults=50,
                pageToken=next_page_token
            ).execute()

            page_count += 1
            videos_this_page = 0
            oldest_video_date = None

            for item in playlist_response['items']:
                try:
                    # Parse publish date - FIXED datetime comparison
                    published_at_str = item['snippet']['publishedAt']
                    # Convert to timezone-aware datetime
                    if published_at_str.endswith('Z'):
                        published_at = datetime.fromisoformat(published_at_str.replace('Z', '+00:00'))
                    else:
                        published_at = datetime.fromisoformat(published_at_str)
                    
                    # Make sure it's timezone-aware
                    if published_at.tzinfo is None:
                        published_at = published_at.replace(tzinfo=timezone.utc)
                    
                    oldest_video_date = published_at
                    
                    # Only include videos from the last N years
                    if published_at >= cutoff_date:
                        video_info = {
                            'video_id': item['snippet']['resourceId']['videoId'],
                            'title': item['snippet']['title'],
                            'published_at': published_at_str,
                            'published_date': published_at
                        }
                        recent_videos.append(video_info)
                        videos_this_page += 1
                        videos_found += 1
                        
                except Exception as e:
                    print(f"Error parsing video: {e}")
                    continue

            print(f"📄 Page {page_count}: +{videos_this_page} recent videos (Total: {videos_found})")
            
            # Check if we've gone past our date range
            if oldest_video_date and oldest_video_date < cutoff_date:
                print(f"📅 Reached videos older than {years_back} years ({oldest_video_date.strftime('%Y-%m-%d')})")
                break

            next_page_token = playlist_response.get('nextPageToken')
            if not next_page_token:
                print("📄 Reached end of channel uploads")
                break

        except Exception as e:
            print(f"Error fetching page {page_count}: {e}")
            break

    print(f"✅ COMPREHENSIVE SEARCH COMPLETE: Found {len(recent_videos)} videos from last {years_back} years")
    return recent_videos

def filter_unwatched_videos(videos, watched_ids, liked_videos, watch_later_videos):
    """Filter out videos that have been watched - STRICT FILTERING"""
    unwatched_videos = []
    watched_count = 0
    
    print("🔍 Filtering out watched videos...")
    
    for video in videos:
        video_id = video['video_id']
        
        # Check if video has been watched through any method
        is_watched = (
            video_id in watched_ids or           # Explicitly in watched file
            video_id in liked_videos or          # Liked videos (implies watched)
            video_id in watch_later_videos       # Watch Later (may be watched)
        )
        
        if is_watched:
            watched_count += 1
        else:
            unwatched_videos.append(video)
    
    print(f"🔍 Filtered out {watched_count} watched videos")
    return unwatched_videos

def YOUR_CLIENT_SECRET_HERE(youtube, playlist_id):
    """Get existing playlist videos - COMPREHENSIVE CHECK"""
    existing_videos = set()
    next_page_token = None
    page_count = 0

    print("📋 Checking ALL existing videos in target playlist...")

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

            page_count += 1
            videos_this_page = 0
            
            for item in playlist_response['items']:
                existing_videos.add(item['snippet']['resourceId']['videoId'])
                videos_this_page += 1

            print(f"📄 Page {page_count}: +{videos_this_page} existing videos (Total: {len(existing_videos)})")

            next_page_token = playlist_response.get('nextPageToken')
            if not next_page_token:
                break

        except Exception as e:
            print(f"Error checking existing videos: {e}")
            break

    print(f"📋 Found {len(existing_videos)} existing videos in playlist")
    return existing_videos

def bulk_add_videos(youtube, playlist_id, videos_to_add, max_to_add):
    """Add videos to playlist - RAPID FIRE MODE"""
    added_count = 0
    failed_count = 0
    failed_videos = []

    print(f"🚀 RAPID FIRE: Adding {max_to_add} unwatched videos to playlist...")

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
            if i % 5 == 0 or i == max_to_add - 1:
                print(f"📈 Progress: {i+1}/{max_to_add} | Added: {added_count} | Failed: {failed_count}")

        except Exception as e:
            failed_count += 1
            failed_videos.append(video['title'])
            if "quota" in str(e).lower():
                print("❌ Quota exceeded, stopping")
                break

        time.sleep(0.05)  # Slightly faster

    if failed_videos:
        print(f"❌ Failed to add {failed_count} videos:")
        for title in failed_videos[:5]:  # Show first 5 failures
            print(f"   - {title}")
        if len(failed_videos) > 5:
            print(f"   ... and {len(failed_videos) - 5} more")

    return added_count, failed_count

def save_video_list(videos, filename='recent_videos.json'):
    """Save video list for future use"""
    serializable_videos = []
    for video in videos:
        video_copy = video.copy()
        if 'published_date' in video_copy:
            video_copy['published_date'] = video_copy['published_date'].isoformat()
        serializable_videos.append(video_copy)
    
    with open(filename, 'w') as f:
        json.dump(serializable_videos, f, indent=2)

def load_video_list(filename='recent_videos.json'):
    """Load cached video list"""
    if os.path.exists(filename):
        try:
            with open(filename, 'r') as f:
                videos = json.load(f)
                for video in videos:
                    if 'published_date' in video:
                        video['published_date'] = datetime.fromisoformat(video['published_date'])
                return videos
        except:
            pass
    return None

def main():
    print(f"🎯 Target: {TARGET_CHANNEL}")
    print(f"📅 Time range: Last {YEARS_BACK} years")
    print(f"📝 Playlist: {PLAYLIST_ID}")
    print("🔍 COMPREHENSIVE SEARCH: Finding EVERY SINGLE unwatched video!")
    print("=" * 60)

    try:
        youtube = authenticate_youtube()
        print("✅ Authenticated!")

        # Load all watched indicators
        watched_ids = load_watched_video_ids()
        liked_videos = get_liked_videos(youtube)
        watch_later_videos = get_watch_later_videos(youtube)
        
        YOUR_CLIENT_SECRET_HERE = len(watched_ids) + len(liked_videos) + len(watch_later_videos)
        print(f"📊 Total watched indicators: {YOUR_CLIENT_SECRET_HERE}")

        # Try to load cached video list first
        cached_videos = load_video_list()
        
        if cached_videos:
            print(f"💾 Using cached video list ({len(cached_videos)} videos)")
            print("💡 Delete 'recent_videos.json' to refresh cache")
            recent_videos = cached_videos
        else:
            # Get uploads playlist
            uploads_playlist_id = YOUR_CLIENT_SECRET_HERE(youtube)
            if not uploads_playlist_id:
                print("❌ Could not find channel uploads playlist")
                return

            # Get ALL recent videos - COMPREHENSIVE SEARCH
            recent_videos = get_all_recent_videos(youtube, uploads_playlist_id, YEARS_BACK)
            if not recent_videos:
                print("❌ No recent videos found")
                return

            # Cache the results
            save_video_list(recent_videos)
            print(f"💾 Cached {len(recent_videos)} recent videos")

        # Filter out watched videos
        unwatched_videos = filter_unwatched_videos(
            recent_videos, watched_ids, liked_videos, watch_later_videos
        )

        # Get existing videos in target playlist
        existing_videos = YOUR_CLIENT_SECRET_HERE(youtube, PLAYLIST_ID)

        # Filter out videos already in playlist
        new_unwatched_videos = [
            v for v in unwatched_videos 
            if v['video_id'] not in existing_videos
        ]

        print(f"\n📊 COMPREHENSIVE RESULTS:")
        print(f"   📹 Total videos in last {YEARS_BACK} years: {len(recent_videos)}")
        print(f"   👁️ Likely watched: {len(recent_videos) - len(unwatched_videos)}")
        print(f"   🎯 Unwatched: {len(unwatched_videos)}")
        print(f"   📝 Already in playlist: {len(existing_videos)}")
        print(f"   🆕 NEW unwatched videos to add: {len(new_unwatched_videos)}")

        if not new_unwatched_videos:
            print("🎉 ALL unwatched videos are already in your playlist!")
            print("🏆 You're completely up to date!")
            return

        # Sort chronologically (oldest first for better viewing experience)
        new_unwatched_videos.sort(key=lambda x: x['published_date'])

        # Show preview of what we'll add
        print(f"\n🎬 Preview of NEW unwatched videos (oldest first):")
        for i, video in enumerate(new_unwatched_videos[:15], 1):
            date = video['published_date'].strftime('%Y-%m-%d')
            print(f"   {i:2d}. {video['title']} ({date})")

        if len(new_unwatched_videos) > 15:
            print(f"   ... and {len(new_unwatched_videos) - 15} more videos")

        # Calculate max possible with remaining quota
        remaining_quota = QUOTA_LIMIT - quota_used
        max_possible = min(len(new_unwatched_videos), remaining_quota // 50)

        print(f"\n📊 Quota Status:")
        print(f"   Used: {quota_used}/{QUOTA_LIMIT}")
        print(f"   Can add: {max_possible} videos")

        if max_possible == 0:
            print("❌ Insufficient quota remaining")
            return

        # Auto-select all videos if possible
        if max_possible >= len(new_unwatched_videos):
            num_to_add = len(new_unwatched_videos)
            print(f"🚀 Adding ALL {num_to_add} unwatched videos!")
        else:
            # Ask user how many to add
            while True:
                try:
                    choice = input(f"\nAdd how many unwatched videos? (1-{max_possible}) or 'all': ").strip()
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

        # Final confirmation
        confirm = input(f"\n🚀 Add {num_to_add} unwatched videos to playlist? (y/n): ")
        if confirm.lower() != 'y':
            print("❌ Cancelled")
            return

        # Add videos to playlist
        added, failed = bulk_add_videos(youtube, PLAYLIST_ID, new_unwatched_videos, num_to_add)

        print(f"\n🎉 MISSION COMPLETE!")
        print(f"   ✅ Successfully added: {added} unwatched videos")
        print(f"   ❌ Failed to add: {failed} videos")
        print(f"   📊 Total quota used: {quota_used}/{QUOTA_LIMIT}")
        print(f"   🏆 Your playlist now has {added} more unwatched {TARGET_CHANNEL} videos!")

    except Exception as e:
        print(f"❌ Error: {e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    print("🎬 COMPREHENSIVE YouTube Unwatched Videos Finder")
    print("=" * 60)
    print(f"Target: {TARGET_CHANNEL} | Last {YEARS_BACK} years | EVERY SINGLE VIDEO")
    print()
    main()