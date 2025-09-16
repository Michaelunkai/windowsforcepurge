import yt_dlp
import sys

def download_video(url):
    try:
        # Define download options
        ydl_opts = {
            'format': 'bestvideo+bestaudio/best',
            'outtmpl': '%(title)s.%(ext)s',
        }
        
        # Download the video
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            print(f"Downloading video from: {url}")
            ydl.download([url])
            print("Download completed!")
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python download_video_ytdlp.py <video_url>")
        sys.exit(1)
    
    video_url = sys.argv[1]
    download_video(video_url)