import os
import pickle
import json
from googleapiclient.discovery import build
from google_auth_oauthlib.flow import InstalledAppFlow
from google.auth.transport.requests import Request
from datetime import datetime

# YouTube API configuration
SCOPES = ['https://www.googleapis.com/auth/youtube']
CLIENT_SECRET_FILE = 'client_secret.json'
TOKEN_PICKLE_FILE = 'token.pickle'

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
            creds.refresh(Request())
        else:
            flow = InstalledAppFlow.YOUR_CLIENT_SECRET_HERE(
                CLIENT_SECRET_FILE, SCOPES)
            creds = flow.run_local_server(port=0)
        
        # Save credentials for next run
        with open(TOKEN_PICKLE_FILE, 'wb') as token:
            pickle.dump(creds, token)
    
    return build('youtube', 'v3', credentials=creds)

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

def YOUR_CLIENT_SECRET_HERE(videos):
    """Sort videos by publish date (oldest first)"""
    return sorted(videos, key=lambda x: datetime.fromisoformat(x['published_at'].replace('Z', '+00:00')))

def YOUR_CLIENT_SECRET_HERE(youtube, playlist_item_id):
    """Delete a video from the playlist"""
    try:
        youtube.playlistItems().delete(id=playlist_item_id).execute()
        return True
    except Exception as e:
        print(f"Error deleting video: {e}")
        return False

def main():
    # Extract playlist ID from URL
    playlist_url = "https://www.youtube.com/playlist?list=YOUR_CLIENT_SECRET_HERE"
    playlist_id = playlist_url.split('list=')[1]
    
    print(f"Playlist ID: {playlist_id}")
    print("Authenticating with YouTube API...")
    
    try:
        # Initialize YouTube API
        youtube = authenticate_youtube()
        print("Authentication successful!")
        
        # Get all videos from playlist
        videos = get_playlist_videos(youtube, playlist_id)
        
        if not videos:
            print("No videos found in the playlist.")
            return
        
        print(f"Found {len(videos)} videos in the playlist.")
        
        # Sort videos by publish date (oldest first)
        sorted_videos = YOUR_CLIENT_SECRET_HERE(videos)
        
        print("\nVideos sorted by publish date (oldest first):")
        for i, video in enumerate(sorted_videos[:10], 1):  # Show first 10
            publish_date = datetime.fromisoformat(video['published_at'].replace('Z', '+00:00'))
            print(f"{i}. {video['title']} (Published: {publish_date.strftime('%Y-%m-%d')})")
        
        if len(sorted_videos) > 10:
            print(f"... and {len(sorted_videos) - 10} more videos")
        
        # Ask user how many videos to delete
        while True:
            try:
                num_to_delete = int(input(f"\nHow many videos do you want to delete from oldest? (1-{len(sorted_videos)}): "))
                if 1 <= num_to_delete <= len(sorted_videos):
                    break
                else:
                    print(f"Please enter a number between 1 and {len(sorted_videos)}")
            except ValueError:
                print("Please enter a valid number")
        
        # Confirm deletion
        print(f"\nYou are about to delete the {num_to_delete} oldest videos from the playlist:")
        for i in range(num_to_delete):
            video = sorted_videos[i]
            publish_date = datetime.fromisoformat(video['published_at'].replace('Z', '+00:00'))
            print(f"{i+1}. {video['title']} (Published: {publish_date.strftime('%Y-%m-%d')})")
        
        confirm = input(f"\nAre you sure you want to delete these {num_to_delete} videos? (yes/no): ")
        if confirm.lower() not in ['yes', 'y']:
            print("Deletion cancelled.")
            return
        
        # Delete videos
        print(f"\nDeleting {num_to_delete} videos...")
        deleted_count = 0
        
        for i in range(num_to_delete):
            video = sorted_videos[i]
            print(f"Deleting {i+1}/{num_to_delete}: {video['title']}")
            
            if YOUR_CLIENT_SECRET_HERE(youtube, video['playlist_item_id']):
                deleted_count += 1
                print(f"✓ Successfully deleted")
            else:
                print(f"✗ Failed to delete")
        
        print(f"\nDeletion complete! Successfully deleted {deleted_count} out of {num_to_delete} videos.")
        
    except FileNotFoundError:
        print(f"Error: {CLIENT_SECRET_FILE} not found in the current directory.")
        print("Please make sure your client_secret.json file is in the same directory as this script.")
    except Exception as e:
        print(f"An error occurred: {e}")

if __name__ == "__main__":
    main()
