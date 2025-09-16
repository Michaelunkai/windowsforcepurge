#!/usr/bin/env python3
"""
Test script to verify the YouTube playlist deletion functionality
"""

import sys
import os
from d import authenticate_youtube, extract_playlist_id, validate_playlist, get_playlist_videos

def test_script():
    """Test the main functionality without user interaction"""
    print("Testing YouTube Playlist Video Deletion Tool")
    print("=" * 50)
    
    # Test playlist ID extraction
    test_url = "https://www.youtube.com/playlist?list=YOUR_CLIENT_SECRET_HEREmhTsf2"
    playlist_id = extract_playlist_id(test_url)
    print(f"[OK] Playlist ID extraction test: {playlist_id}")
    
    if playlist_id != "YOUR_CLIENT_SECRET_HEREmhTsf2":
        print("[FAIL] Playlist ID extraction failed!")
        return False
    
    # Test authentication
    print("\nTesting YouTube API authentication...")
    try:
        youtube = authenticate_youtube()
        if not youtube:
            print("[FAIL] Authentication failed - this is expected if credentials aren't set up")
            print("  To use the script, you need to:")
            print("  1. Create a Google Cloud project")
            print("  2. Enable YouTube Data API v3")
            print("  3. Download OAuth2 credentials as client_secret.json")
            return False
        
        print("[OK] Authentication successful!")
        
        # Test playlist validation
        print(f"\nTesting playlist validation for: {playlist_id}")
        is_valid, result = validate_playlist(youtube, playlist_id)
        
        if is_valid:
            print(f"[OK] Playlist validation successful: '{result}'")
            
            # Test getting playlist videos (just get info, don't delete)
            print("\nTesting playlist video retrieval...")
            videos = get_playlist_videos(youtube, playlist_id)
            print(f"[OK] Found {len(videos)} videos in the playlist")
            
            if videos:
                print("\nFirst few videos:")
                for i, video in enumerate(videos[:3], 1):
                    print(f"  {i}. {video['title']}")
                    print(f"     Published: {video['published_at']}")
            
            print("\n[OK] All tests passed! The script is ready to use.")
            return True
            
        else:
            print(f"[FAIL] Playlist validation failed: {result}")
            print("  Make sure:")
            print("  1. The playlist exists and is public")
            print("  2. You have permission to access it")
            print("  3. You own the playlist (required for deletion)")
            return False
            
    except Exception as e:
        print(f"[FAIL] Error during testing: {e}")
        return False

if __name__ == "__main__":
    success = test_script()
    if success:
        print("\n" + "=" * 50)
        print("SUCCESS: The script is working correctly!")
        print("You can now run 'python d.py' to use the full deletion tool.")
    else:
        print("\n" + "=" * 50)
        print("The script has some issues that need to be resolved.")
        print("Please check the error messages above.")