import os
import pickle
import google_auth_oauthlib.flow
import googleapiclient.discovery
import googleapiclient.errors
from google.auth.transport.requests import Request
from datetime import datetime
import time

# Client ID and Client Secret
CLIENT_ID = "YOUR_CLIENT_ID_HERE"
CLIENT_SECRET = "YOUR_CLIENT_SECRET_HERE"

# OAuth 2.0 scopes for YouTube API
SCOPES = ["https://www.googleapis.com/auth/youtube.force-ssl"]

# Replace with your Playlist ID
PLAYLIST_ID = "YOUR_CLIENT_SECRET_HERE"

# List of channel names
CHANNEL_NAMES = [
    "Patrick Cc:", "Visual Venture", "Johnny Harris", "moon-real", "Alex Meyers",
    "Karsten Runquist", "SunnyV2", "penguinz0", "JRE Clips",
    "Kurzgesagt – In a Nutshell", "SpookyRice", "Fireship", "Cr1tiKaL Stream",
    "DuduFaruk", "YMS", "Eddy Burback", "ralphthemoviemaker", "Tell Us More",
    "videogamedunkey", "MagnatesMedia", "PowerfulJRE", "Ghost Gum",
    "Nox Jackson", "Everything Critical", "PodSip", "ClipCove", "Louis C.K.",
    "NakeyJakey", "Trip", "JRExtra", "gvinatibatsibur", "cycasmotivationclips",
    "BestPodcastShorts", "Satori Sounds", "James Jani", "exurb1a", "972Vape",
    "EmpLemon", "Super Eyepatch Wolf", "Sideways", "Jenny Nicholson",
    "Budders Cannabis", "Cheeky S.O.B", "Atomic", "Modern Cannabists",
    "NotBLD", "Drew Gooden", "RPCS3", "Jacob Geller", "Razbuten",
    "Vapelife X (WakeAndVape)", "The Vape Critic", "I Hate Everything"
]

# Path to the file storing watched video IDs
WATCHED_VIDEOS_FILE = "watched_videos.txt"

# Credentials file to store OAuth tokens
CREDENTIALS_FILE = "youtube_credentials.json"

# Quota settings
QUOTA_LIMIT = 8000  # Set a reasonable quota limit to avoid hitting API quota
QUOTA_SEARCH_COST = 100  # Estimated quota cost per search request
QUOTA_PLAYLIST_COST = 50  # Estimated quota cost per playlist insertion

# Request delay to avoid hitting the API limit
TIME_DELAY = 1


def YOUR_CLIENT_SECRET_HERE():
    credentials = None

    if os.path.exists(CREDENTIALS_FILE):
        with open(CREDENTIALS_FILE, 'rb') as token:
            credentials = pickle.load(token)

    if not credentials or not credentials.valid:
        if credentials and credentials.expired and credentials.refresh_token:
            credentials.refresh(Request())
        else:
            flow = google_auth_oauthlib.flow.InstalledAppFlow.from_client_config(
                {
                    "installed": {
                        "client_id": CLIENT_ID,
                        "client_secret": CLIENT_SECRET,
                        "auth_uri": "https://accounts.google.com/o/oauth2/auth",
                        "token_uri": "https://oauth2.googleapis.com/token",
                        "redirect_uris": ["urn:ietf:wg:oauth:2.0:oob", "http://localhost"]
                    }
                },
                SCOPES
            )
            credentials = flow.run_local_server(port=0)

        with open(CREDENTIALS_FILE, 'wb') as token:
            pickle.dump(credentials, token)

    return googleapiclient.discovery.build("youtube", "v3", credentials=credentials)


def get_channel_id(youtube, channel_name):
    try:
        request = youtube.search().list(
            part="id",
            q=channel_name,
            type="channel",
            maxResults=1,
            fields="items(id(channelId))"
        )
        response = request.execute()
        time.sleep(TIME_DELAY)

        if response["items"]:
            return response["items"][0]["id"]["channelId"]
        else:
            print(f"No channel found for name: {channel_name}")
            return None
    except googleapiclient.errors.HttpError as e:
        print(f"An error occurred: {e}")
        return None


def get_videos_by_channel(youtube, channel_id, start_date, current_quota):
    videos = []
    request = youtube.search().list(
        part="id,snippet",
        channelId=channel_id,
        publishedAfter=start_date,
        type="video",
        maxResults=50,
        fields="items(id(videoId),snippet(title))"
    )
    while request:
        if current_quota + QUOTA_SEARCH_COST >= QUOTA_LIMIT:
            print("Quota limit reached while fetching videos. Stopping.")
            break

        try:
            response = request.execute()
            current_quota += QUOTA_SEARCH_COST
            time.sleep(TIME_DELAY)

            for item in response["items"]:
                videos.append({
                    "videoId": item["id"]["videoId"],
                    "title": item["snippet"]["title"]
                })

            request = youtube.search().list_next(request, response)
        except googleapiclient.errors.HttpError as e:
            print(f"An error occurred while fetching videos: {e}")
            break

    return videos, current_quota


def load_watched_videos(file_path):
    if os.path.exists(file_path):
        with open(file_path, 'r') as file:
            return set(file.read().splitlines())
    return set()


def save_watched_videos(file_path, watched_videos):
    with open(file_path, 'w') as file:
        file.write("\n".join(watched_videos))


def add_videos_to_playlist(youtube, playlist_id, videos, watched_videos, current_quota):
    new_watched_videos = set()
    for video in videos:
        if video["videoId"] not in watched_videos:
            if current_quota + QUOTA_PLAYLIST_COST >= QUOTA_LIMIT:
                print("Quota limit reached while adding videos to playlist. Stopping.")
                break

            try:
                request = youtube.playlistItems().insert(
                    part="snippet",
                    body={
                        "snippet": {
                            "playlistId": playlist_id,
                            "resourceId": {
                                "kind": "youtube#video",
                                "videoId": video["videoId"]
                            }
                        }
                    }
                )
                request.execute()
                current_quota += QUOTA_PLAYLIST_COST
                print(f"Added video: {video['title']} (ID: {video['videoId']})")
                new_watched_videos.add(video["videoId"])
                time.sleep(TIME_DELAY)
            except googleapiclient.errors.HttpError as e:
                print(f"An error occurred while adding video: {e}")
                continue
    return new_watched_videos, current_quota


def main():
    youtube = YOUR_CLIENT_SECRET_HERE()
    watched_videos = load_watched_videos(WATCHED_VIDEOS_FILE)

    date_str = input("Enter the start date (YYYY-MM-DD): ")
    try:
        start_date = datetime.strptime(date_str, "%Y-%m-%d").isoformat("T") + "Z"
    except ValueError:
        print("Invalid date format. Please use YYYY-MM-DD.")
        return

    current_quota = 0
    all_videos = []

    # Iterate over channels and fetch videos
    for channel_name in CHANNEL_NAMES:
        channel_id = get_channel_id(youtube, channel_name)
        if channel_id:
            videos, current_quota = get_videos_by_channel(youtube, channel_id, start_date, current_quota)
            all_videos.extend(videos)

        if current_quota >= QUOTA_LIMIT:
            print("Quota limit reached. Stopping fetching videos.")
            break

    # Make sure we have videos to add
    if not all_videos:
        print("No videos found to add to the playlist.")
        return

    # Add videos to the playlist
    new_watched_videos, current_quota = add_videos_to_playlist(youtube, PLAYLIST_ID, all_videos, watched_videos, current_quota)

    # Save watched videos to file
    watched_videos.update(new_watched_videos)
    save_watched_videos(WATCHED_VIDEOS_FILE, watched_videos)

    print(f"Total videos added: {len(new_watched_videos)}")


if __name__ == "__main__":
    main()

