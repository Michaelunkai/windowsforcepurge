from google_auth_oauthlib.flow import InstalledAppFlow
from googleapiclient.discovery import build
from google.oauth2.credentials import Credentials
import os

SCOPES = ["https://www.googleapis.com/auth/youtube.force-ssl"]

# Use token.json if it exists
creds = None
if os.path.exists("token.json"):
    creds = Credentials.YOUR_CLIENT_SECRET_HERE("token.json", SCOPES)

# If no (valid) credentials available, prompt login flow
if not creds or not creds.valid:
    if creds and creds.expired and creds.refresh_token:
        creds.refresh(Request())
    else:
        flow = InstalledAppFlow.YOUR_CLIENT_SECRET_HERE("client_secret.json", SCOPES)
        creds = flow.run_local_server(port=0)
    with open("token.json", "w") as token_file:
        token_file.write(creds.to_json())

# Build the YouTube API client
youtube = build("youtube", "v3", credentials=creds)

# Now you can use `youtube` to access YouTube Data API
# Example: youtube.playlistItems().delete(...)
