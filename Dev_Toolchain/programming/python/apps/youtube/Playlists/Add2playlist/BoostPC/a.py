import os
import pickle
import json
import time
import re
from googleapiclient.discovery import build
from google_auth_oauthlib.flow import InstalledAppFlow
from google.auth.transport.requests import Request
from datetime import datetime, timedelta, timezone

# YouTube API configuration
SCOPES = ['https://www.googleapis.com/auth/youtube']
CLIENT_SECRET_FILE = 'client_secret.json'
TOKEN_PICKLE_FILE = 'token.pickle'

# API quota management
QUOTA_LIMIT = 8500  # Conservative limit
quota_used = 0

# Search configuration
YEARS_BACK = 3  # Last 3 years only
PLAYLIST_ID = "YOUR_CLIENT_SECRET_HERE"  # Your tech tutorial playlist

# Windows 11/ASUS/Network speed tutorial search terms
TUTORIAL_SEARCH_TERMS = [
    "Windows 11 speed optimization",
    "Windows 11 performance boost",
    "Windows 11 faster tutorial",
    "speed up Windows 11",
    "Windows 11 optimization guide",
    "Windows 11 performance tips",
    "ASUS laptop optimization",
    "ASUS laptop speed boost",
    "ASUS laptop performance",
    "ASUS Windows 11 optimization",
    "ASUS gaming laptop optimization",
    "network speed boost Windows",
    "internet speed optimization",
    "WiFi speed boost Windows 11",
    "network performance Windows 11",
    "faster internet Windows 11",
    "network optimization tutorial",
    "DNS optimization Windows 11",
    "Windows 11 network settings",
    "laptop performance optimization",
    "SSD optimization Windows 11",
    "RAM optimization Windows 11",
    "startup optimization Windows 11",
    "Windows 11 debloat tutorial"
]

def authenticate_youtube():
    """Authenticate using saved token or manual flow"""
    creds = None

    # Load existing token if available
    if os.path.exists(TOKEN_PICKLE_FILE):
        with open(TOKEN_PICKLE_FILE, 'rb') as token:
            creds = pickle.load(token)
            print("✅ Using saved authentication credentials")

    # If no valid credentials, request authorization
    if not creds or not creds.valid:
        if creds and creds.expired and creds.refresh_token:
            try:
                print("🔄 Refreshing expired credentials...")
                creds.refresh(Request())
                print("✅ Credentials refreshed successfully")
            except Exception as e:
                print(f"❌ Failed to refresh credentials: {e}")
                creds = None
        
        if not creds:
            if not os.path.exists(CLIENT_SECRET_FILE):
                print(f"❌ Error: {CLIENT_SECRET_FILE} not found in current directory")
                print("Please download your OAuth credentials and save as client_secret.json")
                return None
            
            try:
                print("🔐 Starting authentication flow...")
                flow = InstalledAppFlow.YOUR_CLIENT_SECRET_HERE(CLIENT_SECRET_FILE, SCOPES)
                
                # Try local server first, fallback to manual
                try:
                    print("🌐 Attempting local server authentication...")
                    creds = flow.run_local_server(port=8080, open_browser=True)
                    print("✅ Local server authentication successful!")
                except Exception as local_error:
                    print(f"⚠️ Local server failed: {local_error}")
                    print("🔄 Falling back to manual authentication...")
                    
                    flow.redirect_uri = 'urn:ietf:wg:oauth:2.0:oob'
                    auth_url, _ = flow.authorization_url(
                        prompt='select_account',
                        login_hint='michaelovsky22@gmail.com'
                    )
                    
                    print("\n" + "="*60)
                    print("💻 WINDOWS 11/ASUS TUTORIAL FINDER")
                    print("="*60)
                    print("1. Open this URL in your browser:")
                    print(f"\n{auth_url}\n")
                    print("2. Sign in with michaelovsky22@gmail.com")
                    print("3. Grant YouTube permissions")
                    print("4. Copy the authorization code")
                    print("5. Paste it below")
                    print("="*60)
                    
                    auth_code = input("\nEnter authorization code: ").strip()
                    flow.fetch_token(code=auth_code)
                    creds = flow.credentials
                    print("✅ Manual authentication successful!")
                    
            except Exception as e:
                print(f"❌ Authentication failed: {e}")
                print("\n🔧 TROUBLESHOOTING STEPS:")
                print("1. Check that client_secret.json is valid")
                print("2. Ensure YouTube Data API v3 is enabled")
                print("3. Add your email as test user in OAuth consent screen")
                return None

        # Save credentials for next run
        with open(TOKEN_PICKLE_FILE, 'wb') as token:
            pickle.dump(creds, token)
            print("💾 Credentials saved for future use")

    return build('youtube', 'v3', credentials=creds)

def track_quota_usage(operation_cost, operation_name=""):
    """Track API quota usage with detailed logging"""
    global quota_used
    quota_used += operation_cost
    
    if operation_name:
        print(f"📊 {operation_name}: +{operation_cost} quota (Total: {quota_used}/{QUOTA_LIMIT})")
    
    if quota_used >= QUOTA_LIMIT:
        print("⚠️ Approaching quota limit. Stopping to avoid exceeding daily limit.")
        return False
    return True

def parse_duration(duration_str):
    """Parse ISO 8601 duration (PT#M#S) to minutes"""
    try:
        duration_str = duration_str[2:]  # Remove PT prefix
        minutes = 0
        seconds = 0
        
        # Extract minutes and seconds
        m_match = re.search(r'(\d+)M', duration_str)
        if m_match:
            minutes = int(m_match.group(1))
        
        s_match = re.search(r'(\d+)S', duration_str)
        if s_match:
            seconds = int(s_match.group(1))
        
        # Extract hours if present
        h_match = re.search(r'(\d+)H', duration_str)
        if h_match:
            minutes += int(h_match.group(1)) * 60
        
        total_minutes = minutes + (seconds / 60)
        return total_minutes
        
    except Exception as e:
        print(f"Error parsing duration {duration_str}: {e}")
        return 999  # Return large number to filter out problematic videos

def is_tutorial_content(title, description):
    """Check if video appears to be a tutorial based on title and description"""
    tutorial_keywords = [
        'tutorial', 'how to', 'guide', 'step by step', 'optimization', 'boost', 
        'speed up', 'improve', 'fix', 'setup', 'configure', 'tips', 'tricks',
        'performance', 'faster', 'optimize', 'tweak', 'settings', 'increase'
    ]
    
    text_to_check = (title + " " + description).lower()
    
    # Must contain at least 2 tutorial keywords for quality
    keyword_count = sum(1 for keyword in tutorial_keywords if keyword in text_to_check)
    return keyword_count >= 2

def search_tech_tutorials(youtube, search_term, max_results=25):
    """Search for Windows 11/ASUS/network speed tutorials"""
    if not track_quota_usage(100, f"Search: '{search_term}'"):
        return []
    
    try:
        # Calculate date 3 years ago
        published_after = (datetime.now() - timedelta(days=365*YEARS_BACK)).isoformat() + 'Z'
        
        search_response = youtube.search().list(
            q=search_term,
            part='id,snippet',
            type='video',
            order='relevance',
            maxResults=max_results,
            publishedAfter=published_after,
            videoCategoryId='26'  # Science & Technology category
        ).execute()
        
        if not search_response['items']:
            print(f"   No results for '{search_term}'")
            return []
        
        video_ids = [item['id']['videoId'] for item in search_response['items']]
        
        # Get video details including duration
        if not track_quota_usage(1, f"Video details for {len(video_ids)} videos"):
            return []
            
        videos_response = youtube.videos().list(
            part='snippet,contentDetails,statistics',
            id=','.join(video_ids)
        ).execute()
        
        qualified_videos = []
        for video in videos_response['items']:
            try:
                duration_minutes = parse_duration(video['contentDetails']['duration'])
                view_count = int(video['statistics'].get('viewCount', 0))
                like_count = int(video['statistics'].get('likeCount', 0))
                
                title = video['snippet']['title']
                description = video['snippet'].get('description', '')
                
                # Quality filters for tutorials
                is_good_tutorial = (
                    duration_minutes >= 2 and  # At least 2 minutes (substantial content)
                    duration_minutes <= 60 and  # Max 1 hour (not too long)
                    view_count >= 500 and  # Decent viewership
                    is_tutorial_content(title, description)  # Actually tutorial content
                )
                
                if is_good_tutorial:
                    video_info = {
                        'video_id': video['id'],
                        'title': title,
                        'channel': video['snippet']['channelTitle'],
                        'published_at': video['snippet']['publishedAt'],
                        'duration_minutes': round(duration_minutes, 1),
                        'view_count': view_count,
                        'like_count': like_count,
                        'search_term': search_term,
                        'description': description[:200] + '...' if len(description) > 200 else description
                    }
                    qualified_videos.append(video_info)
            except Exception as e:
                continue  # Skip problematic videos
        
        print(f"   Found {len(qualified_videos)} qualifying tutorials")
        return qualified_videos
        
    except Exception as e:
        print(f"   Error searching '{search_term}': {e}")
        return []

def YOUR_CLIENT_SECRET_HERE(youtube):
    """Get videos already in the playlist to avoid duplicates"""
    existing_videos = set()
    next_page_token = None
    
    print("🔍 Checking existing playlist videos...")
    
    while True:
        if not track_quota_usage(1, "Check playlist"):
            break
            
        try:
            playlist_response = youtube.playlistItems().list(
                part='snippet',
                playlistId=PLAYLIST_ID,
                maxResults=50,
                pageToken=next_page_token
            ).execute()
            
            for item in playlist_response['items']:
                existing_videos.add(item['snippet']['resourceId']['videoId'])
            
            next_page_token = playlist_response.get('nextPageToken')
            if not next_page_token:
                break
                
        except Exception as e:
            print(f"Error checking playlist: {e}")
            break
    
    print(f"✅ Found {len(existing_videos)} existing videos in playlist")
    return existing_videos

def add_video_to_playlist(youtube, video_id, video_title):
    """Add a single video to the playlist"""
    if not track_quota_usage(50, f"Add: {video_title[:30]}..."):
        return False
        
    try:
        youtube.playlistItems().insert(
            part='snippet',
            body={
                'snippet': {
                    'playlistId': PLAYLIST_ID,
                    'resourceId': {
                        'kind': 'youtube#video',
                        'videoId': video_id
                    }
                }
            }
        ).execute()
        return True
    except Exception as e:
        print(f"   ❌ Failed to add: {e}")
        return False

def save_results(videos_found, videos_added, filename='tech_tutorials_results.json'):
    """Save results for analysis"""
    results = {
        'timestamp': datetime.now().isoformat(),
        'quota_used': quota_used,
        'years_back': YEARS_BACK,
        'videos_found': len(videos_found),
        'videos_added': len(videos_added),
        'search_terms_used': TUTORIAL_SEARCH_TERMS,
        'videos_found_details': videos_found,
        'videos_added_details': videos_added
    }
    
    with open(filename, 'w') as f:
        json.dump(results, f, indent=2)
    
    print(f"💾 Results saved to {filename}")

def main():
    print("💻" * 20)
    print("💻 WINDOWS 11 / ASUS / NETWORK SPEED TUTORIAL FINDER")
    print("💻" * 20)
    print(f"🎯 Target: Windows 11, ASUS laptop, network speed tutorials")
    print(f"📅 Time Range: Last {YEARS_BACK} years")
    print(f"📋 Playlist: {PLAYLIST_ID}")
    print(f"⚡ Quota Limit: {QUOTA_LIMIT}")
    print("💻" * 20)
    
    try:
        # Authenticate
        youtube = authenticate_youtube()
        if not youtube:
            return
        
        # Get existing playlist videos
        existing_videos = YOUR_CLIENT_SECRET_HERE(youtube)
        
        # Search for tech tutorials
        all_found_videos = []
        print(f"\n🔍 Searching for tech optimization tutorials...")
        
        for i, search_term in enumerate(TUTORIAL_SEARCH_TERMS, 1):
            if quota_used >= QUOTA_LIMIT:
                print("⚠️ Quota limit reached, stopping search")
                break
                
            print(f"\n💻 Search {i}/{len(TUTORIAL_SEARCH_TERMS)}: '{search_term}'")
            videos = search_tech_tutorials(youtube, search_term, max_results=20)
            all_found_videos.extend(videos)
            
            # Small delay to be respectful
            time.sleep(0.5)
        
        if not all_found_videos:
            print("❌ No qualifying tutorials found")
            return
        
        # Remove duplicates and filter out existing
        unique_videos = {}
        for video in all_found_videos:
            video_id = video['video_id']
            if video_id not in existing_videos and video_id not in unique_videos:
                unique_videos[video_id] = video
        
        new_videos = list(unique_videos.values())
        
        # Sort by relevance (view count + like ratio)
        def tutorial_score(video):
            like_ratio = video['like_count'] / max(video['view_count'], 1)
            return video['view_count'] * (1 + like_ratio * 10)
        
        new_videos.sort(key=tutorial_score, reverse=True)
        
        print(f"\n📊 SEARCH RESULTS:")
        print(f"   Total tutorials found: {len(all_found_videos)}")
        print(f"   Unique new tutorials: {len(new_videos)}")
        print(f"   Already in playlist: {len(all_found_videos) - len(new_videos)}")
        
        if not new_videos:
            print("🎉 All qualifying tutorials are already in your playlist!")
            return
        
        # Show preview of top tutorials
        print(f"\n💻 TOP TECH TUTORIALS PREVIEW:")
        for i, video in enumerate(new_videos[:8], 1):
            date = datetime.fromisoformat(video['published_at'].replace('Z', '+00:00')).strftime('%Y-%m-%d')
            print(f"   {i}. {video['title']}")
            print(f"      👀 {video['view_count']:,} views | 👍 {video['like_count']:,} likes | ⏱️ {video['duration_minutes']} min")
            print(f"      📅 {date} | 📺 {video['channel']}")
            print(f"      🔍 Found via: '{video['search_term']}'")
            print(f"      📝 {video['description'][:100]}...")
            print()
        
        if len(new_videos) > 8:
            print(f"   ... and {len(new_videos) - 8} more tutorials")
        
        # Calculate how many we can add
        remaining_quota = QUOTA_LIMIT - quota_used
        max_addable = min(len(new_videos), remaining_quota // 50)
        
        print(f"\n⚡ QUOTA STATUS:")
        print(f"   Used: {quota_used}/{QUOTA_LIMIT}")
        print(f"   Remaining: {remaining_quota}")
        print(f"   Can add: {max_addable} tutorials")
        
        if max_addable == 0:
            print("❌ Insufficient quota to add tutorials")
            save_results(all_found_videos, [])
            return
        
        # Get user input
        print(f"\n📝 NOTE: YouTube API cannot determine which tutorials you've watched.")
        print("All qualifying tutorials will be added. You can remove any you've")
        print("already seen after they're added to the playlist.")
        
        while True:
            try:
                choice = input(f"\nHow many tutorials to add? (1-{max_addable}) or 'all': ").strip()
                if choice.lower() == 'all':
                    num_to_add = max_addable
                    break
                else:
                    num_to_add = int(choice)
                    if 1 <= num_to_add <= max_addable:
                        break
                    print(f"Please enter 1-{max_addable} or 'all'")
            except ValueError:
                print("Please enter a number or 'all'")
        
        # Confirm
        confirm = input(f"\n🚀 Add {num_to_add} tech tutorials to playlist? (y/n): ")
        if confirm.lower() != 'y':
            print("❌ Cancelled")
            return
        
        # Add videos to playlist
        print(f"\n💻 Adding {num_to_add} tutorials to playlist...")
        added_videos = []
        
        for i, video in enumerate(new_videos[:num_to_add], 1):
            if quota_used >= QUOTA_LIMIT:
                print("⚠️ Quota limit reached, stopping")
                break
            
            print(f"\n🎯 Adding {i}/{num_to_add}:")
            print(f"   💻 {video['title']}")
            print(f"   📺 {video['channel']} | ⏱️ {video['duration_minutes']} min")
            
            if add_video_to_playlist(youtube, video['video_id'], video['title']):
                added_videos.append(video)
                print(f"   ✅ Added successfully!")
            else:
                print(f"   ❌ Failed to add")
            
            # Save progress every 5 videos
            if len(added_videos) % 5 == 0:
                save_results(all_found_videos, added_videos)
            
            # Small delay
            time.sleep(0.3)
        
        # Final results
        save_results(all_found_videos, added_videos)
        
        print(f"\n🎉 MISSION COMPLETE!")
        print(f"   ✅ Successfully added: {len(added_videos)} tutorials")
        print(f"   📊 Total quota used: {quota_used}/{QUOTA_LIMIT}")
        print(f"   ⏱️ Average tutorial length: {sum(v['duration_minutes'] for v in added_videos) / len(added_videos):.1f} min")
        print(f"   👀 Average views: {sum(v['view_count'] for v in added_videos) // len(added_videos):,}")
        
        # Categorize added tutorials
        categories = {}
        for video in added_videos:
            search_term = video['search_term']
            if 'Windows 11' in search_term:
                category = 'Windows 11 Optimization'
            elif 'ASUS' in search_term:
                category = 'ASUS Laptop Optimization'
            elif 'network' in search_term or 'internet' in search_term:
                category = 'Network Speed Optimization'
            else:
                category = 'General Performance'
            
            categories[category] = categories.get(category, 0) + 1
        
        print(f"\n📂 TUTORIAL CATEGORIES ADDED:")
        for category, count in categories.items():
            print(f"   💻 {category}: {count} tutorials")
        
        print(f"\n🚀 Next Steps:")
        print("1. Check your playlist for the new tutorials")
        print("2. Remove any tutorials you've already watched")
        print("3. Enjoy optimizing your Windows 11/ASUS system!")
        
    except Exception as e:
        print(f"❌ An error occurred: {e}")

if __name__ == "__main__":
    main()
