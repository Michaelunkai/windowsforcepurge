import spotipy
from spotipy.oauth2 import SpotifyOAuth
import os

# Provided credentials
CLIENT_ID = 'YOUR_CLIENT_ID_HERE"songs.txt"):
    lines = []
    for idx, track in enumerate(tracks, start=1):
        track_name = track.get('name', 'Unknown')
        artist_names = ", ".join(artist.get('name', 'Unknown') for artist in track.get('artists', []))
        # Create a line with rank, track name, and artists.
        line = f"{idx}: {track_name} by {artist_names}"
        lines.append(line)
    
    with open(filename, 'w', encoding='utf-8') as f:
        f.write("\n".join(lines))
    print(f"Saved {len(tracks)} top tracks to '{filename}'")

def main():
    print("Fetching top tracks...")
    top_tracks = get_top_tracks(total_limit=2000, time_range='long_term')
    print(f"Retrieved {len(top_tracks)} tracks.")
    
    save_tracks_to_txt(top_tracks)

if __name__ == "__main__":
    main()
