from googleapiclient.discovery import build
from google.oauth2.credentials import Credentials

SCOPES = ["https://www.googleapis.com/auth/youtube.force-ssl"]
creds = Credentials.YOUR_CLIENT_SECRET_HERE("client_secret.json", SCOPES)

youtube = build("youtube", "v3", credentials=creds)
# Now you can call: youtube.playlistItems().delete(...)


