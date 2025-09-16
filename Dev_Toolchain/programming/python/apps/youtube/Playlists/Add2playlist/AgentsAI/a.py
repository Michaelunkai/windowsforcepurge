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
QUOTA_LIMIT = 8500  # Stay well under 10,000 limit
quota_used = 0

# Configuration
TARGET_COUNT = 150  # Minimum 150 videos
YEARS_BACK = 1  # Last 1 year only
PLAYLIST_ID = "YOUR_CLIENT_SECRET_HERE"  # Same playlist

# AI Agent focused search terms
AI_AGENT_SEARCH_TERMS = [
    "AI agents",
    "AI agent",
    "artificial intelligence agents",
    "autonomous AI agents",
    "AI agent tutorial",
    "building AI agents",
    "AI agent development",
    "multi agent systems",
    "AI agent framework",
    "langchain agents",
    "autogen agents",
    "crewai agents",
    "AI agent workflow",
    "intelligent agents",
    "AI assistant agents",
    "conversational AI agents",
    "AI agent automation",
    "AI agent tools",
    "AI agent coding",
    "AI agent programming",
    "OpenAI agents",
    "ChatGPT agents",
    "AI agent deployment",
    "AI agent architecture",
    "AI agent examples",
    "AI agent projects",
    "AI agent use cases",
    "AI swarm agents",
    "collaborative AI agents",
    "AI agent coordination"
]

def authenticate_youtube():
    """Authenticate using saved token or manual flow"""
    creds = None

    if os.path.exists(TOKEN_PICKLE_FILE):
        with open(TOKEN_PICKLE_FILE, 'rb') as token:
            creds = pickle.load(token)
            print("✅ Using saved authentication credentials")

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
                return None
            
            try:
                print("🔐 Starting authentication flow...")
                flow = InstalledAppFlow.YOUR_CLIENT_SECRET_HERE(CLIENT_SECRET_FILE, SCOPES)
                
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
                    print("🤖 AI AGENTS PLAYLIST BUILDER")
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
                print("2. Ensure YouTube Data API v3 is enabled in Google Cloud Console")
                print("3. Add michaelovsky22@gmail.com as a test user in OAuth consent screen")
                return None

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

def search_ai_agent_videos(youtube, search_term, max_results=30):
    """Search for AI agent videos with higher result count"""
    if not track_quota_usage(100, f"Search: '{search_term}'"):
        return []
    
    try:
        # Calculate date 1 year ago
        published_after = (datetime.now() - timedelta(days=365*YEARS_BACK)).isoformat() + 'Z'
        
        search_response = youtube.search().list(
            q=search_term,
            part='id,snippet',
            type='video',
            order='relevance',
            maxResults=max_results,  # Higher count for more results
            publishedAfter=published_after,
            videoCategoryId='28'  # Science & Technology category
        ).execute()
        
        if not search_response['items']:
            print(f"   No results for '{search_term}'")
            return []
        
        video_ids = [item['id']['videoId'] for item in search_response['items']]
        
        # Get video details including statistics
        if not track_quota_usage(1, f"Video details for {len(video_ids)} videos"):
            return []
            
        videos_response = youtube.videos().list(
            part='snippet,statistics',
            id=','.join(video_ids)
        ).execute()
        
        qualified_videos = []
        for video in videos_response['items']:
            try:
                view_count = int(video['statistics'].get('viewCount', 0))
                like_count = int(video['statistics'].get('likeCount', 0))
                
                # Lower threshold for AI content (newer field, smaller audience)
                if view_count >= 300:
                    video_info = {
                        'video_id': video['id'],
                        'title': video['snippet']['title'],
                        'channel': video['snippet']['channelTitle'],
                        'published_at': video['snippet']['publishedAt'],
                        'view_count': view_count,
                        'like_count': like_count,
                        'search_term': search_term,
                        'description': video['snippet'].get('description', '')[:300] + '...'
                    }
                    qualified_videos.append(video_info)
            except Exception as e:
                continue  # Skip problematic videos
        
        print(f"   Found {len(qualified_videos)} qualifying videos")
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

def save_results(videos_found, videos_added, filename='ai_agents_results.json'):
    """Save results for analysis"""
    results = {
        'timestamp': datetime.now().isoformat(),
        'quota_used': quota_used,
        'target_count': TARGET_COUNT,
        'years_back': YEARS_BACK,
        'videos_found': len(videos_found),
        'videos_added': len(videos_added),
        'search_terms_used': AI_AGENT_SEARCH_TERMS,
        'videos_found_details': videos_found,
        'videos_added_details': videos_added
    }
    
    with open(filename, 'w') as f:
        json.dump(results, f, indent=2)
    
    print(f"💾 Results saved to {filename}")

def filter_ai_agent_content(videos):
    """Filter videos to ensure they're actually about AI agents"""
    ai_keywords = [
        'agent', 'agents', 'ai', 'artificial intelligence', 'autonomous', 'multi-agent',
        'langchain', 'autogen', 'crewai', 'openai', 'chatgpt', 'assistant', 'bot',
        'automation', 'workflow', 'intelligent', 'conversational', 'framework',
        'deployment', 'architecture', 'coordination', 'swarm', 'collaborative'
    ]
    
    filtered_videos = []
    for video in videos:
        title_lower = video['title'].lower()
        desc_lower = video['description'].lower()
        
        # Check if video mentions AI agent-related terms
        has_ai_keywords = any(keyword in title_lower or keyword in desc_lower 
                            for keyword in ai_keywords)
        
        # Additional check for "agent" specifically in title or description
        has_agent_term = 'agent' in title_lower or 'agent' in desc_lower
        
        if has_ai_keywords and (has_agent_term or 'ai' in title_lower):
            filtered_videos.append(video)
    
    return filtered_videos

def main():
    print("🤖" * 25)
    print("🤖 AI AGENTS PLAYLIST BUILDER")
    print("🤖" * 25)
    print(f"🎯 Target: At least {TARGET_COUNT} AI agent videos")
    print(f"📅 Time Range: Last {YEARS_BACK} year")
    print(f"📋 Playlist: {PLAYLIST_ID}")
    print(f"⚡ Quota Limit: {QUOTA_LIMIT}")
    print("🤖" * 25)
    
    try:
        # Authenticate
        youtube = authenticate_youtube()
        if not youtube:
            return
        
        # Get existing playlist videos
        existing_videos = YOUR_CLIENT_SECRET_HERE(youtube)
        
        # Search for AI agent videos with aggressive approach
        all_found_videos = []
        print(f"\n🔍 Searching for AI agent videos (targeting {TARGET_COUNT}+ videos)...")
        
        for i, search_term in enumerate(AI_AGENT_SEARCH_TERMS, 1):
            if quota_used >= QUOTA_LIMIT:
                print("⚠️ Quota limit reached, stopping search")
                break
                
            print(f"\n🤖 Search {i}/{len(AI_AGENT_SEARCH_TERMS)}: '{search_term}'")
            videos = search_ai_agent_videos(youtube, search_term, max_results=30)
            all_found_videos.extend(videos)
            
            # Check if we have enough unique videos
            unique_check = set()
            for v in all_found_videos:
                if v['video_id'] not in existing_videos:
                    unique_check.add(v['video_id'])
            
            print(f"   📊 Progress: {len(unique_check)} unique new videos found so far")
            
            # Small delay to be respectful
            time.sleep(0.5)
        
        if not all_found_videos:
            print("❌ No qualifying videos found")
            return
        
        # Filter to ensure AI agent relevancy
        print(f"\n🔍 Filtering for AI agent-related content...")
        ai_agent_videos = filter_ai_agent_content(all_found_videos)
        print(f"   📊 Filtered: {len(ai_agent_videos)} AI agent videos from {len(all_found_videos)} total")
        
        # Remove duplicates and filter out existing
        unique_videos = {}
        for video in ai_agent_videos:
            video_id = video['video_id']
            if video_id not in existing_videos and video_id not in unique_videos:
                unique_videos[video_id] = video
        
        new_videos = list(unique_videos.values())
        
        # Sort by combined score (views + weighted likes for quality)
        def calculate_score(video):
            return video['view_count'] + (video['like_count'] * 5)  # Weight likes for engagement
        
        new_videos.sort(key=calculate_score, reverse=True)
        
        print(f"\n📊 SEARCH RESULTS:")
        print(f"   Total videos found: {len(all_found_videos)}")
        print(f"   AI agent-relevant videos: {len(ai_agent_videos)}")
        print(f"   Unique new videos: {len(new_videos)}")
        print(f"   Already in playlist: {len(all_found_videos) - len(new_videos)}")
        
        if not new_videos:
            print("🎉 All qualifying videos are already in your playlist!")
            return
        
        # Check if we have enough videos
        if len(new_videos) < TARGET_COUNT:
            print(f"⚠️ Found {len(new_videos)} new videos, target was {TARGET_COUNT}")
            print("💡 Consider running script multiple times or adjusting search terms for more results")
        else:
            print(f"✅ Found {len(new_videos)} new videos, exceeding target of {TARGET_COUNT}!")
        
        # Show preview
        print(f"\n🤖 TOP AI AGENT VIDEOS PREVIEW:")
        for i, video in enumerate(new_videos[:10], 1):
            date = datetime.fromisoformat(video['published_at'].replace('Z', '+00:00')).strftime('%Y-%m-%d')
            print(f"   {i:2d}. {video['title']}")
            print(f"       👀 {video['view_count']:,} views | 👍 {video['like_count']:,} likes | 📅 {date}")
            print(f"       📺 {video['channel']} | 🔍 Found via: '{video['search_term']}'")
            print(f"       📝 {video['description'][:80]}...")
            print()
        
        if len(new_videos) > 10:
            print(f"   ... and {len(new_videos) - 10} more AI agent videos")
        
        # Calculate how many we can add
        remaining_quota = QUOTA_LIMIT - quota_used
        max_addable = min(len(new_videos), remaining_quota // 50)
        
        print(f"\n⚡ QUOTA STATUS:")
        print(f"   Used: {quota_used}/{QUOTA_LIMIT}")
        print(f"   Remaining: {remaining_quota}")
        print(f"   Can add: {max_addable} videos")
        
        if max_addable == 0:
            print("❌ Insufficient quota to add videos")
            save_results(all_found_videos, [])
            return
        
        # Default to adding all available videos (up to quota limit)
        num_to_add = max_addable
        
        # Get user input only if they want to add fewer
        choice = input(f"\nAdd all {max_addable} AI agent videos? (y/n) or enter number (1-{max_addable}): ").strip()
        
        if choice.lower() == 'n':
            while True:
                try:
                    num_input = input(f"How many AI agent videos to add? (1-{max_addable}): ")
                    num_to_add = int(num_input)
                    if 1 <= num_to_add <= max_addable:
                        break
                    print(f"Please enter 1-{max_addable}")
                except ValueError:
                    print("Please enter a number")
        elif choice.isdigit():
            num_choice = int(choice)
            if 1 <= num_choice <= max_addable:
                num_to_add = num_choice
        
        # Add videos to playlist
        print(f"\n🤖 Adding {num_to_add} AI agent videos to playlist...")
        added_videos = []
        
        for i, video in enumerate(new_videos[:num_to_add], 1):
            if quota_used >= QUOTA_LIMIT:
                print("⚠️ Quota limit reached, stopping")
                break
            
            print(f"\n🎯 Adding {i}/{num_to_add}:")
            print(f"   🤖 {video['title']}")
            print(f"   📺 {video['channel']} | 👀 {video['view_count']:,} views")
            
            if add_video_to_playlist(youtube, video['video_id'], video['title']):
                added_videos.append(video)
                print(f"   ✅ Added successfully!")
            else:
                print(f"   ❌ Failed to add")
            
            # Save progress every 10 videos
            if len(added_videos) % 10 == 0:
                save_results(all_found_videos, added_videos)
            
            # Small delay
            time.sleep(0.3)
        
        # Final results
        save_results(all_found_videos, added_videos)
        
        print(f"\n🏆 MISSION COMPLETE!")
        print(f"   ✅ Successfully added: {len(added_videos)} AI agent videos")
        print(f"   🎯 Target achieved: {'✅ YES' if len(added_videos) >= TARGET_COUNT else f'⚠️ {len(added_videos)}/{TARGET_COUNT}'}")
        print(f"   📊 Total quota used: {quota_used}/{QUOTA_LIMIT}")
        
        if added_videos:
            avg_views = sum(v['view_count'] for v in added_videos) // len(added_videos)
            total_views = sum(v['view_count'] for v in added_videos)
            print(f"   👀 Average views: {avg_views:,}")
            print(f"   🎯 Total views of added videos: {total_views:,}")
            
            # Show search term breakdown
            search_breakdown = {}
            for video in added_videos:
                term = video['search_term']
                search_breakdown[term] = search_breakdown.get(term, 0) + 1
            
            print(f"\n📊 TOP SEARCH SOURCES:")
            for term, count in sorted(search_breakdown.items(), key=lambda x: x[1], reverse=True)[:5]:
                print(f"   '{term}': {count} videos")
            
            # Show recent vs older content
            recent_videos = [v for v in added_videos if 
                           (datetime.now() - datetime.fromisoformat(v['published_at'].replace('Z', '+00:00'))).days <= 180]
            print(f"\n📅 RECENCY ANALYSIS:")
            print(f"   Videos from last 6 months: {len(recent_videos)}")
            print(f"   Videos from 6-12 months ago: {len(added_videos) - len(recent_videos)}")
        
        print(f"\n🤖 Next Steps:")
        print("1. Check your playlist for the new AI agent videos")
        print("2. Learn about cutting-edge AI agent frameworks and tools")
        print("3. Build your own AI agents using the techniques shown")
        print("4. Stay updated with the rapidly evolving AI agent ecosystem!")
        
        if len(added_videos) < TARGET_COUNT:
            print(f"\n💡 To reach {TARGET_COUNT}+ videos:")
            print("- Run the script again (new videos are uploaded daily)")
            print("- Lower the view threshold for more niche content")
            print("- Add more specific search terms for your interests")
        
    except Exception as e:
        print(f"❌ An error occurred: {e}")

if __name__ == "__main__":
    main()
