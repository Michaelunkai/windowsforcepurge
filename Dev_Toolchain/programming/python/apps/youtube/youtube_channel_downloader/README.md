# YouTube Channel Video Downloader and Manager

A comprehensive tool for downloading and managing your YouTube channel videos with robust error handling, progress tracking, and safety features.

## Features

- **Safe Authentication**: OAuth2 flow with credential caching
- **Comprehensive Video Listing**: Fetches all videos with detailed metadata
- **Flexible Download Options**: Download-only or download-and-delete modes
- **Progress Tracking**: Real-time progress bars for all operations
- **Metadata Backup**: Automatic JSON backup of all video information
- **Robust Error Handling**: Retry mechanisms and detailed logging
- **Safety Features**: Multiple confirmation prompts for destructive operations
- **Non-Interactive Mode**: Support for automation and testing

## Setup

1. **Install required packages:**
```bash
pip install -r requirements.txt
```

2. **Set up Google API credentials:**
   - Go to [Google Cloud Console](https://console.cloud.google.com/)
   - Create a new project or select existing one
   - Enable YouTube Data API v3
   - Create OAuth 2.0 credentials (Desktop application)
   - Download the `client_secret.json` file to this directory

3. **Run the application:**
```bash
python youtube_channel_downloader.py
```

## Usage Options

### Interactive Mode
```bash
python youtube_channel_downloader.py
```
The script will prompt you to choose:
- **Option 1**: Download videos only (safe)
- **Option 2**: Download videos and DELETE from channel (destructive)
- **Option 3**: List videos only (no downloads)
- **Option 0**: Exit

### Non-Interactive Mode
```bash
python youtube_channel_downloader.py [option]
```
Where option is 0, 1, 2, or 3 (same as interactive mode).

### Testing
```bash
python test_downloader.py
```
Runs comprehensive tests of all functionality.

## What it does

1. **Authenticates** with YouTube API using OAuth2
2. **Discovers** your channel and retrieves channel information
3. **Fetches** all videos from your channel with detailed metadata
4. **Creates backup** of video metadata in JSON format
5. **Downloads** videos with optimal quality settings (up to 1080p)
6. **Includes subtitles** and metadata files with each download
7. **Optionally deletes** videos from channel (only if download succeeds)
8. **Logs everything** with detailed status reporting

## File Structure

After running, you'll have:
```
F:\Downloads\MyVideos\
├── logs/                    # Detailed log files
├── backups/                 # JSON metadata backups
├── test/                    # Test downloads (auto-cleaned)
├── [Video Name] - [ID].mp4  # Downloaded videos
├── [Video Name] - [ID].info.json    # Video metadata
└── [Video Name] - [ID].vtt  # Subtitles (if available)
```

## Safety Features

- **Multiple confirmations** before any destructive operations
- **Download verification** before attempting deletion
- **Automatic metadata backup** before processing
- **Detailed logging** of all operations
- **Error recovery** with retry mechanisms
- **Test mode** for validation

## Configuration

You can modify the `Config` class in the script to customize:
- Download folder location
- Backup folder location
- Video quality preferences
- Retry attempts and delays
- Log levels

## Requirements

- Python 3.7+
- Valid Google Cloud Project with YouTube Data API v3 enabled
- OAuth 2.0 credentials (`client_secret.json`)
- Internet connection

## Important Notes

- **BACKUP WARNING**: The delete option will permanently remove videos from your YouTube channel
- **API Limits**: Google has daily quotas for API usage
- **Download Size**: Videos are downloaded in best available quality (up to 1080p)
- **Subtitles**: Automatic and manual subtitles are downloaded when available
- **Metadata**: Complete video information is saved for each video

## Troubleshooting

1. **Authentication issues**: Delete `token.pickle` and re-authenticate
2. **API quota exceeded**: Wait 24 hours or request quota increase
3. **Download failures**: Check internet connection and disk space
4. **Unicode errors**: The script handles Windows console encoding automatically

## License

This tool is for personal use. Ensure compliance with YouTube Terms of Service and applicable laws.