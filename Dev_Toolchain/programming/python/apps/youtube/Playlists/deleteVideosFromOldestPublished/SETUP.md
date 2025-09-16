# YouTube Playlist Video Deletion Tool - Setup Instructions

This application allows you to delete the oldest videos from a YouTube playlist using the YouTube Data API v3.

## Prerequisites

1. **Python 3.7 or higher**
2. **Google Cloud Console Account**
3. **YouTube API v3 enabled**

## Setup Steps

### 1. Enable YouTube Data API v3

1. Go to the [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select an existing one
3. Navigate to "APIs & Services" > "Library"
4. Search for "YouTube Data API v3" and enable it
5. Go to "APIs & Services" > "Credentials"
6. Click "Create Credentials" > "OAuth 2.0 Client IDs"
7. Choose "Desktop application" as the application type
8. Download the credentials JSON file
9. Rename it to `client_secret.json` and place it in this directory

### 2. Install Dependencies

```bash
pip install -r requirements.txt
```

### 3. Run the Application

```bash
python d.py
```

## First Run Authentication

1. The application will open a web browser for OAuth2 authentication
2. Sign in with the Google account that owns the playlist you want to modify
3. Grant the requested permissions
4. The application will save your credentials in `token.json` for future use

## Usage

1. **Enter Playlist URL or ID**: When prompted, provide either:
   - Full YouTube playlist URL: `https://www.youtube.com/playlist?list=PLxxxxxx`
   - Just the playlist ID: `PLxxxxxx`

2. **Review Videos**: The application will show you the 10 oldest videos in the playlist

3. **Choose Number to Delete**: Enter how many of the oldest videos you want to delete

4. **Confirm Deletion**: Type 'yes' to confirm the deletion

## Important Notes

### Permissions Required

- You must own the playlist to delete videos from it
- The application requires YouTube API access scope
- Only playlist items are deleted, not the actual videos from YouTube

### Rate Limits

- YouTube API has rate limits (10,000 units per day by default)
- Each playlist item deletion costs 50 units
- Each video fetch costs 1 unit
- Monitor your quota in Google Cloud Console

### Safety Features

- Shows you exactly which videos will be deleted before proceeding
- Requires explicit 'yes' confirmation
- Only deletes videos from playlists, not from YouTube entirely
- Videos remain on your channel, just removed from the playlist

## Troubleshooting

### "Playlist not found or not accessible"
- Ensure the playlist ID is correct
- Make sure you own the playlist
- Check that the playlist is not private if accessing with different account

### "Authentication failed"
- Ensure `client_secret.json` is in the correct directory
- Check that YouTube Data API v3 is enabled in Google Cloud Console
- Verify OAuth2 client is configured for "Desktop application"

### "Failed to refresh credentials"
- Delete `token.json` file and re-authenticate
- Check internet connection
- Verify API credentials haven't been revoked

### Rate limit exceeded
- Wait for quota to reset (daily)
- Request quota increase in Google Cloud Console
- Reduce batch sizes if processing large playlists

## File Structure

```
├── d.py                    # Main application
├── requirements.txt        # Python dependencies
├── client_secret.json     # OAuth2 credentials (you provide)
├── token.json             # Saved user tokens (auto-generated)
└── SETUP.md              # This file
```

## Security Notes

- Keep `client_secret.json` secure and don't share it
- The `token.json` file contains your access tokens - keep it private
- Regularly review API access in your Google Account settings
- Consider revoking access when done using the application

## Support

If you encounter issues:
1. Check the troubleshooting section above
2. Verify all setup steps are completed correctly
3. Check YouTube API quotas in Google Cloud Console
4. Ensure you have the required permissions for the playlist