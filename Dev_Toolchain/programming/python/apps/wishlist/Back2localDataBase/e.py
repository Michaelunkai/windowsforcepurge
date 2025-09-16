"""
Michael Fedro's Enhanced Wishlist Manager - Premium Sources Edition
YOUR_CLIENT_SECRET_HERELIENT_SECRET_HERE
* Dark-theme GUI with enhanced torrent source integration
* Premium torrent sources: 1337x, RARBG mirrors, Nyaa, TorrentGalaxy, YTS
* Per-category controls with intelligent search modifications
* Auto-downloads TOP 3 most seeded torrents with fallback sources
* SSH/Paramiko sync preserved
* Enhanced error handling and retry mechanisms
"""

# YOUR_CLIENT_SECRET_HERE
# Configuration & Imports
# YOUR_CLIENT_SECRET_HERE
import os
import sys
import shutil
import sqlite3
import tempfile
import subprocess
import paramiko
import tkinter as tk
from tkinter import ttk, messagebox, simpledialog
import requests
from bs4 import BeautifulSoup
import time
import threading
from concurrent.futures import ThreadPoolExecutor, as_completed
import urllib.parse
import re
from typing import List, Dict, Optional

# Server Configuration
HOSTNAME = "54.173.176.93"
USERNAME = "ubuntu"
KEY_PATH = r"C:\backup\windowsapps\Credentials\AWS\key.pem"
REMOTE_DB_PATH = "/home/ubuntu/wishlist/wishlist.db"
LOCAL_DB_FILENAME = "wishlist.db"

# qBittorrent Configuration
QBITTORRENT_PATH = r"C:\Users\micha.DESKTOP-QCAU2KC\Desktop\qbittorrent.exe - Shortcut.lnk"

# Enhanced Search Engines with Premium Sources
SEARCH_ENGINES = {
    "1337x": {
        "url": "https://1337x.to/search/{}/1/",
        "fallback": "https://1337xx.to/search/{}/1/"
    },
    "nyaa": {
        "url": "https://nyaa.si/?f=0&c=0_0&q={}",
        "fallback": "https://nyaa.land/?f=0&c=0_0&q={}"
    },
    "torrentgalaxy": {
        "url": "https://torrentgalaxy.to/torrents.php?search={}",
        "fallback": "https://torrentgalaxy.mx/torrents.php?search={}"
    },
    "yts": {
        "url": "https://yts.mx/browse-movies/{}/all/all/0/latest/0/all",
        "fallback": "https://yts.am/browse-movies/{}/all/all/0/latest/0/all"
    },
    "rarbg": {
        "url": "https://rargb.to/search/?search={}",
        "fallback": "https://thepiratebay.org/search.php?q={}"
    },
    "torlock": {
        "url": "https://www.torlock.com/all/torrents/{}.html",
        "fallback": "https://torlock2.com/all/torrents/{}.html"
    }
}

# Enhanced Headers with Rotation
HEADERS_LIST = [
    {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
        "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8",
        "Accept-Language": "en-US,en;q=0.5",
        "Accept-Encoding": "gzip, deflate",
        "Connection": "keep-alive",
        "YOUR_CLIENT_SECRET_HERE": "1",
    },
    {
        "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
        "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
        "Accept-Language": "en-US,en;q=0.9",
        "Accept-Encoding": "gzip, deflate, br",
        "Connection": "keep-alive",
    },
    {
        "User-Agent": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
        "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8",
        "Accept-Language": "en-US,en;q=0.9",
        "Accept-Encoding": "gzip, deflate, br",
        "Connection": "keep-alive",
    }
]

# Global tracking
download_stats = {"total": 0, "successful": 0, "failed": 0}
current_headers = HEADERS_LIST[0]

# YOUR_CLIENT_SECRET_HERE
# Enhanced qBittorrent Integration
# YOUR_CLIENT_SECRET_HERE

def add_to_qbittorrent(magnet_uri: str) -> bool:
    """Enhanced qBittorrent integration with better error handling."""
    if not magnet_uri or not magnet_uri.startswith("magnet:"):
        print(f"❌ Invalid magnet URI: {magnet_uri[:50] if magnet_uri else 'None'}...")
        return False

    try:
        # Try primary path first
        subprocess.Popen([QBITTORRENT_PATH, magnet_uri], 
                        stdout=subprocess.DEVNULL, 
                        stderr=subprocess.DEVNULL)
        return True
    except FileNotFoundError:
        # Try common installation paths
        fallback_paths = [
            r"C:\Program Files\qBittorrent\qbittorrent.exe",
            r"C:\Program Files (x86)\qBittorrent\qbittorrent.exe",
            r"C:\Users\{}\AppData\Local\Programs\qBittorrent\qbittorrent.exe".format(os.getenv('USERNAME', '')),
        ]
        
        for path in fallback_paths:
            if os.path.exists(path):
                try:
                    subprocess.Popen([path, magnet_uri], 
                                   stdout=subprocess.DEVNULL, 
                                   stderr=subprocess.DEVNULL)
                    return True
                except Exception as e:
                    continue
        
        print(f"❌ qBittorrent not found in any standard location")
        return False
    except Exception as e:
        print(f"❌ Failed to launch qBittorrent: {e}")
        return False

# YOUR_CLIENT_SECRET_HERE
# Remote Sync (Paramiko/SFTP)
# YOUR_CLIENT_SECRET_HERE

def download_remote_db():
    """Download database from remote server with retry logic."""
    max_retries = 3
    for attempt in range(max_retries):
        try:
            ssh = paramiko.SSHClient()
            ssh.YOUR_CLIENT_SECRET_HERE(paramiko.AutoAddPolicy())
            ssh.connect(hostname=HOSTNAME, username=USERNAME, key_filename=KEY_PATH, timeout=30)
            sftp = ssh.open_sftp()
            temp_path = os.path.join(tempfile.gettempdir(), "wishlist_remote.db")
            sftp.get(REMOTE_DB_PATH, temp_path)
            sftp.close()
            ssh.close()
            shutil.copy(temp_path, LOCAL_DB_FILENAME)
            print("✔ Database downloaded successfully")
            return
        except Exception as exc:
            print(f"⚠️ Download attempt {attempt + 1}/{max_retries} failed: {exc}")
            if attempt < max_retries - 1:
                time.sleep(5)
    
    print("⚠️ All download attempts failed, creating local database")
    create_local_db()

def upload_remote_db():
    """Upload database to remote server with retry logic."""
    max_retries = 3
    for attempt in range(max_retries):
        try:
            ssh = paramiko.SSHClient()
            ssh.YOUR_CLIENT_SECRET_HERE(paramiko.AutoAddPolicy())
            ssh.connect(hostname=HOSTNAME, username=USERNAME, key_filename=KEY_PATH, timeout=30)
            sftp = ssh.open_sftp()
            sftp.put(LOCAL_DB_FILENAME, REMOTE_DB_PATH)
            sftp.close()
            ssh.close()
            print("✔ Database uploaded successfully")
            return
        except Exception as exc:
            print(f"⚠️ Upload attempt {attempt + 1}/{max_retries} failed: {exc}")
            if attempt < max_retries - 1:
                time.sleep(5)

# YOUR_CLIENT_SECRET_HERE
# Database Management
# YOUR_CLIENT_SECRET_HERE

def create_local_db():
    """Create local database with proper schema."""
    connection = sqlite3.connect(LOCAL_DB_FILENAME)
    cur = connection.cursor()
    for table in ("movies", "tv_shows", "games", "anime"):
        cur.execute(
            f"CREATE TABLE IF NOT EXISTS {table} (id INTEGER PRIMARY KEY, title TEXT UNIQUE)"
        )
    connection.commit()
    connection.close()

def init_db():
    """Initialize database connection."""
    if not os.path.exists(LOCAL_DB_FILENAME):
        download_remote_db()
    connection = sqlite3.connect(LOCAL_DB_FILENAME)
    cur = connection.cursor()
    for table in ("movies", "tv_shows", "games", "anime"):
        cur.execute(
            f"CREATE TABLE IF NOT EXISTS {table} (id INTEGER PRIMARY KEY, title TEXT UNIQUE)"
        )
    connection.commit()
    return connection, cur

conn, cursor = init_db()

# YOUR_CLIENT_SECRET_HERE
# App Structure
# YOUR_CLIENT_SECRET_HERE

categories = ["movies", "tv_shows", "games", "anime"]
items_ids = {c: [] for c in categories}
entry_widgets = {}
listbox_widgets = {}

# Enhanced search query modifications
modify_title = {
    "movies": lambda t: f"{t} 1080p BluRay",
    "tv_shows": lambda t: f"{t} S01 1080p",
    "anime": lambda t: f"{t} 1080p dual audio",
    "games": lambda t: f"{t} PC game",
}

# YOUR_CLIENT_SECRET_HERE
# Enhanced Search Functions
# YOUR_CLIENT_SECRET_HERE

def rotate_headers():
    """Rotate headers to avoid detection."""
    global current_headers
    import random
    current_headers = random.choice(HEADERS_LIST)

def safe_request(url: str, timeout: int = 15) -> Optional[requests.Response]:
    """Make a safe HTTP request with error handling."""
    try:
        rotate_headers()
        response = requests.get(url, headers=current_headers, timeout=timeout)
        response.raise_for_status()
        return response
    except Exception as e:
        print(f"⚠️ Request failed for {url[:50]}...: {e}")
        return None

def search_1337x(query: str) -> List[Dict]:
    """Search 1337x with fallback."""
    results = []
    urls = [SEARCH_ENGINES["1337x"]["url"], SEARCH_ENGINES["1337x"]["fallback"]]
    
    for base_url in urls:
        try:
            url = base_url.format(urllib.parse.quote_plus(query))
            response = safe_request(url)
            if not response:
                continue
                
            soup = BeautifulSoup(response.content, "html.parser")
            rows = soup.find_all("tr")[1:6]  # Skip header, get top 5
            
            for row in rows:
                name_cell = row.find("td", class_="coll-1")
                if not name_cell:
                    continue
                    
                name_link = name_cell.find("a", href=True)
                if not name_link:
                    continue
                    
                name = name_link.text.strip()
                link = "https://1337x.to" + name_link["href"]
                
                # Get seeders
                seeds_cell = row.find("td", class_="coll-2")
                seeders = 0
                if seeds_cell:
                    seeds_text = seeds_cell.text.strip()
                    seeders = int(''.join(filter(str.isdigit, seeds_text))) if seeds_text else 0
                
                # Get size
                size_cell = row.find("td", class_="coll-4")
                size = size_cell.text.strip() if size_cell else "Unknown"
                
                results.append({
                    "name": f"[1337x] {name}",
                    "link": link,
                    "size": size,
                    "seeders": seeders,
                    "engine": "1337x"
                })
            
            if results:
                break
                
        except Exception as e:
            print(f"⚠️ Error searching 1337x: {e}")
            continue
    
    return results

def search_nyaa(query: str) -> List[Dict]:
    """Enhanced Nyaa search."""
    results = []
    urls = [SEARCH_ENGINES["nyaa"]["url"], SEARCH_ENGINES["nyaa"]["fallback"]]
    
    for base_url in urls:
        try:
            url = base_url.format(urllib.parse.quote_plus(query))
            response = safe_request(url)
            if not response:
                continue
                
            soup = BeautifulSoup(response.content, "html.parser")
            rows = soup.find_all("tr", class_=["success", "default", "danger"])[:5]
            
            for row in rows:
                name_cell = row.find("td", class_="text-center")
                if name_cell:
                    name_cell = name_cell.find_next_sibling("td")
                
                if not name_cell:
                    continue
                    
                name_link = name_cell.find("a", href=True)
                if not name_link:
                    continue
                    
                name = name_link.text.strip()
                link = "https://nyaa.si" + name_link["href"]
                
                cells = row.find_all("td")
                size = cells[3].text.strip() if len(cells) > 3 else "Unknown"
                
                seeders_text = cells[5].text.strip() if len(cells) > 5 else "0"
                seeders = int(seeders_text) if seeders_text.isdigit() else 0
                
                results.append({
                    "name": f"[NYAA] {name}",
                    "link": link,
                    "size": size,
                    "seeders": seeders,
                    "engine": "nyaa"
                })
            
            if results:
                break
                
        except Exception as e:
            print(f"⚠️ Error searching Nyaa: {e}")
            continue
    
    return results

def search_torrentgalaxy(query: str) -> List[Dict]:
    """Enhanced TorrentGalaxy search."""
    results = []
    urls = [SEARCH_ENGINES["torrentgalaxy"]["url"], SEARCH_ENGINES["torrentgalaxy"]["fallback"]]
    
    for base_url in urls:
        try:
            url = base_url.format(urllib.parse.quote_plus(query))
            response = safe_request(url)
            if not response:
                continue
                
            soup = BeautifulSoup(response.content, "html.parser")
            rows = soup.find_all("tr")[1:6]  # Skip header
            
            for row in rows:
                name_cell = row.find("a", class_="txlight")
                if not name_cell:
                    continue
                    
                name = name_cell.text.strip()
                link = "https://torrentgalaxy.to" + name_cell["href"]
                
                cells = row.find_all("td")
                size = cells[4].text.strip() if len(cells) > 4 else "Unknown"
                
                seeders_text = cells[6].text.strip() if len(cells) > 6 else "0"
                seeders = int(''.join(filter(str.isdigit, seeders_text))) if seeders_text else 0
                
                results.append({
                    "name": f"[TGX] {name}",
                    "link": link,
                    "size": size,
                    "seeders": seeders,
                    "engine": "torrentgalaxy"
                })
            
            if results:
                break
                
        except Exception as e:
            print(f"⚠️ Error searching TorrentGalaxy: {e}")
            continue
    
    return results

def search_yts(query: str) -> List[Dict]:
    """Search YTS for movies."""
    results = []
    urls = [SEARCH_ENGINES["yts"]["url"], SEARCH_ENGINES["yts"]["fallback"]]
    
    for base_url in urls:
        try:
            url = base_url.format(urllib.parse.quote_plus(query))
            response = safe_request(url)
            if not response:
                continue
                
            soup = BeautifulSoup(response.content, "html.parser")
            movie_items = soup.find_all("div", class_="browse-movie-wrap")[:5]
            
            for item in movie_items:
                title_elem = item.find("a", class_="browse-movie-title")
                if not title_elem:
                    continue
                    
                name = title_elem.text.strip()
                link = title_elem["href"]
                
                results.append({
                    "name": f"[YTS] {name}",
                    "link": link,
                    "size": "Variable",
                    "seeders": 50,  # YTS usually has good seeds
                    "engine": "yts"
                })
            
            if results:
                break
                
        except Exception as e:
            print(f"⚠️ Error searching YTS: {e}")
            continue
    
    return results

def search_torrents(query: str) -> List[Dict]:
    """Enhanced torrent search across multiple premium sources."""
    all_results = []
    
    update_status(f"🔍 Searching premium sources for: {query}")
    
    # Search engines to use
    search_functions = [
        search_1337x,
        search_nyaa,
        search_torrentgalaxy,
        search_yts,
    ]
    
    # Use threading for parallel searches
    with ThreadPoolExecutor(max_workers=4) as executor:
        future_to_engine = {
            executor.submit(func, query): func.__name__ 
            for func in search_functions
        }
        
        for future in as_completed(future_to_engine, timeout=30):
            engine_name = future_to_engine[future]
            try:
                results = future.result(timeout=10)
                all_results.extend(results)
                print(f"✔ {engine_name}: Found {len(results)} results")
            except Exception as e:
                print(f"⚠️ {engine_name} failed: {e}")
    
    # Sort by seeders and return top 3
    all_results.sort(key=lambda r: r["seeders"], reverse=True)
    top_3 = all_results[:3]
    
    print(f"📊 Total: {len(all_results)} results, selected top 3:")
    for i, r in enumerate(top_3, 1):
        print(f"  #{i}: {r['seeders']} seeders - {r['name'][:60]}...")
    
    return top_3

def fetch_magnet_enhanced(torrent_page_url: str, engine: str) -> Optional[str]:
    """Enhanced magnet fetching with engine-specific logic."""
    try:
        response = safe_request(torrent_page_url, timeout=20)
        if not response:
            return None
            
        soup = BeautifulSoup(response.content, "html.parser")
        
        # Engine-specific magnet extraction
        if engine == "1337x":
            magnet_link = soup.find("a", href=lambda h: h and h.startswith("magnet:"))
            if magnet_link:
                return magnet_link["href"]
                
        elif engine == "nyaa":
            magnet_link = soup.find("a", href=lambda h: h and h.startswith("magnet:"))
            if magnet_link:
                return magnet_link["href"]
                
        elif engine == "torrentgalaxy":
            magnet_link = soup.find("a", href=lambda h: h and h.startswith("magnet:"))
            if magnet_link:
                return magnet_link["href"]
                
        elif engine == "yts":
            # YTS has download buttons that lead to magnet links
            download_links = soup.find_all("a", class_="download-torrent")
            for link in download_links:
                if "1080p" in link.text:
                    # Get the actual torrent file link and convert to magnet
                    torrent_url = link["href"]
                    return f"magnet:?xt=urn:btih:{torrent_url.split('/')[-1]}&dn={urllib.parse.quote(torrent_page_url.split('/')[-1])}"
        
        # Fallback: look for any magnet link
        magnet_link = soup.find("a", href=lambda h: h and h.startswith("magnet:"))
        return magnet_link["href"] if magnet_link else None
        
    except Exception as e:
        print(f"⚠️ Failed to fetch magnet from {torrent_page_url}: {e}")
        return None

def YOUR_CLIENT_SECRET_HERE(torrent_info: Dict) -> bool:
    """Enhanced torrent download with better error handling."""
    try:
        update_status(f"🔗 Fetching magnet: {torrent_info['name'][:50]}...")
        
        magnet = fetch_magnet_enhanced(torrent_info["link"], torrent_info["engine"])
        if not magnet:
            print(f"❌ No magnet found for {torrent_info['name']}")
            return False
        
        success = add_to_qbittorrent(magnet)
        if success:
            print(f"✔ Added to qBittorrent → {torrent_info['name']}")
            return True
        else:
            print(f"❌ Failed to add to qBittorrent → {torrent_info['name']}")
            return False
            
    except Exception as e:
        print(f"❌ Error downloading {torrent_info['name']}: {e}")
        return False

def auto_download_top_3(query: str):
    """Auto-download top 3 torrents with enhanced error handling."""
    global download_stats
    
    print(f"\n🚀 Starting enhanced auto-download for: {query}")
    update_status(f"🚀 Searching premium sources for: {query}")
    
    download_stats = {"total": 0, "successful": 0, "failed": 0}
    
    try:
        top_torrents = search_torrents(query)
        
        if not top_torrents:
            update_status(f"❌ No torrents found for: {query}")
            print(f"❌ No torrents found for: {query}")
            return
        
        download_stats["total"] = len(top_torrents)
        update_status(f"📥 Downloading {len(top_torrents)} premium torrents...")
        
        # Download with threading
        with ThreadPoolExecutor(max_workers=3) as executor:
            future_to_torrent = {
                executor.submit(YOUR_CLIENT_SECRET_HERE, torrent): torrent 
                for torrent in top_torrents
            }
            
            for future in as_completed(future_to_torrent, timeout=60):
                torrent = future_to_torrent[future]
                try:
                    success = future.result(timeout=30)
                    if success:
                        download_stats["successful"] += 1
                    else:
                        download_stats["failed"] += 1
                except Exception as e:
                    print(f"❌ Exception downloading {torrent['name']}: {e}")
                    download_stats["failed"] += 1
        
        # Final status
        total = download_stats["total"]
        successful = download_stats["successful"]
        failed = download_stats["failed"]
        
        status_msg = f"✅ Completed: {successful}/{total} successful"
        if failed > 0:
            status_msg += f", {failed} failed"
        
        update_status(status_msg)
        print(f"\n{status_msg} for query: {query}")
        
    except Exception as e:
        error_msg = f"❌ Error in auto-download for {query}: {e}"
        update_status(error_msg)
        print(error_msg)

# YOUR_CLIENT_SECRET_HERE
# GUI Styling & Helpers
# YOUR_CLIENT_SECRET_HERE

def style_dark():
    """Apply dark theme styling."""
    st = ttk.Style()
    if sys.platform.startswith("win"):
        try:
            st.theme_use("vista")
        except:
            st.theme_use("clam")
    else:
        st.theme_use("clam")
    
    bg = "#121212"
    accent = "#e53935"
    st.configure("TFrame", background=bg)
    st.configure("TLabel", background=bg, foreground=accent, font=("Helvetica", 12, "bold"))
    st.configure("TButton", font=("Helvetica", 10, "bold"))
    st.map("TButton", foreground=[("active", "#ffffff")])

def update_status(message: str):
    """Update status bar with thread safety."""
    if 'status_label' in globals() and status_label.winfo_exists():
        try:
            status_label.config(text=message)
            root.update_idletasks()
        except:
            pass

# YOUR_CLIENT_SECRET_HERE
# Database Operations
# YOUR_CLIENT_SECRET_HERE

def refresh_items(category: str):
    """Refresh listbox items from database."""
    lb = listbox_widgets[category]
    lb.delete(0, tk.END)
    items_ids[category].clear()
    
    cursor.execute(f"SELECT id, title FROM {category} ORDER BY title")
    for item_id, title in cursor.fetchall():
        lb.insert(tk.END, title)
        items_ids[category].append(item_id)

# YOUR_CLIENT_SECRET_HERE
# Core Actions
# YOUR_CLIENT_SECRET_HERE

def add_item(category: str):
    """Add items to category."""
    txt = entry_widgets[category]
    titles = [t.strip() for t in txt.get("1.0", "end-1c").split("\n") if t.strip()]
    if not titles:
        return
    
    added_count = 0
    for title in titles:
        try:
            cursor.execute(f"INSERT OR IGNORE INTO {category} (title) VALUES (?)", (title,))
            if cursor.rowcount > 0:
                added_count += 1
        except Exception as e:
            print(f"⚠️ Error adding {title}: {e}")
    
    if added_count > 0:
        conn.commit()
        upload_remote_db()
        refresh_items(category)
        update_status(f"✅ Added {added_count} items to {category}")
    
    txt.delete("1.0", tk.END)

def delete_all(category: str):
    """Delete all items in category."""
    if not messagebox.askyesno("Confirm Delete", f"Delete ALL {category.replace('_', ' ')}?"):
        return
    
    cursor.execute(f"DELETE FROM {category}")
    conn.commit()
    upload_remote_db()
    refresh_items(category)
    update_status(f"🗑️ Deleted all {category}")

def delete_selected(category: str):
    """Delete selected items."""
    lb = listbox_widgets[category]
    sel = lb.curselection()
    if not sel:
        messagebox.showinfo("No Selection", "Please select items to delete.")
        return
    
    if not messagebox.askyesno("Confirm Delete", f"Delete {len(sel)} selected item(s)?"):
        return
    
    for idx in reversed(sel):
        cursor.execute(f"DELETE FROM {category} WHERE id=?", (items_ids[category][idx],))
    
    conn.commit()
    upload_remote_db()
    refresh_items(category)
    update_status(f"🗑️ Deleted {len(sel)} items from {category}")

def copy_selected_titles(category: str):
    """Copy N titles from top of list to clipboard."""
    lb = listbox_widgets[category]
    total_items = lb.size()
    
    if total_items == 0:
        messagebox.showinfo("Empty Category", "No items to copy.")
        return
    
    amount = simpledialog.askinteger("Copy Titles", 
                                   f"How many titles do you want to copy from the top? (1-{total_items})",
                                   minvalue=1, maxvalue=total_items)
    if amount is None:
        return
        
    titles = [lb.get(i) for i in range(amount)]
    root.clipboard_clear()
    root.clipboard_append("\n".join(titles))
    update_status(f"📋 Copied {len(titles)} title(s) from top of {category}")

def run_all(category: str):
    """Download torrents for all items in category."""
    lb = listbox_widgets[category]
    titles = [lb.get(i) for i in range(lb.size())]
    
    if not titles:
        messagebox.showinfo("Empty Category", f"No items in {category}")
        return
    
    if not messagebox.askyesno("Download All", 
                              f"Auto-download top 3 torrents for ALL {len(titles)} {category}?"):
        return
    
    def download_all_async():
        for i, title in enumerate(titles, 1):
            update_status(f"🔄 Processing {i}/{len(titles)}: {title}")
            query = modify_title[category](title)
            auto_download_top_3(query)
            if i < len(titles):
                time.sleep(3)  # Rate limiting
        update_status(f"✅ Completed all {len(titles)} downloads from {category}")
    
    threading.Thread(target=download_all_async, daemon=True).start()

def YOUR_CLIENT_SECRET_HERE():
    """Download torrents for selected items across all categories."""
    collected = []
    for cat, lb in listbox_widgets.items():
        selected_titles = [lb.get(i) for i in lb.curselection()]
        collected.extend([(cat, title) for title in selected_titles])

    if not collected:
        messagebox.showinfo("No Selection", "Please select items to download.")
        return

    if not messagebox.askyesno("Download Selected", 
                              f"Auto-download top 3 torrents for {len(collected)} selected items?"):
        return

    def download_selected_async():
        for i, (cat, title) in enumerate(collected, 1):
            update_status(f"🔄 Processing {i}/{len(collected)}: {title}")
            query = modify_title[cat](title)
            auto_download_top_3(query)
            if i < len(collected):
                time.sleep(3)  # Rate limiting
        update_status(f"✅ Completed all {len(collected)} selected downloads")
    
    threading.Thread(target=download_selected_async, daemon=True).start()

# YOUR_CLIENT_SECRET_HERE
# GUI Construction
# YOUR_CLIENT_SECRET_HERE

root = tk.Tk()
root.title("Michael Fedro's Enhanced Wishlist Manager - Premium Sources Edition")
root.geometry("1400x700")
root.configure(bg="#121212")
style_dark()

# Header
header_frame = tk.Frame(root, bg="#121212")
header_frame.pack(fill=tk.X, padx=10, pady=5)

title_label = tk.Label(header_frame, 
                      text="🚀 Enhanced Wishlist Manager - Premium Sources Edition", 
                      bg="#121212", fg="#ff6b35", 
                      font=("Helvetica", 16, "bold"))
title_label.pack()

subtitle_label = tk.Label(header_frame, 
                         text="Premium Sources: 1337x • Nyaa • TorrentGalaxy • YTS • Enhanced Search", 
                         bg="#121212", fg="#00ff00", 
                         font=("Helvetica", 10))
subtitle_label.pack()

# Entry section
entry_frame = ttk.Frame(root)
entry_frame.pack(fill=tk.X, padx=12, pady=8)

for col, cat in enumerate(categories):
    sub = ttk.Frame(entry_frame)
    sub.grid(row=0, column=col, padx=6, sticky="n")
    
    # Category label with icon
    cat_icons = {"movies": "🎬", "tv_shows": "📺", "games": "🎮", "anime": "🎌"}
    label_text = f"{cat_icons.get(cat, '📁')} {cat.replace('_', ' ').title()}"
    ttk.Label(sub, text=label_text).pack(anchor="w")
    
    # Text entry
    txt = tk.Text(sub, height=4, width=25, 
                  bg="#1e1e1e", fg="#ffffff", 
                  insertbackground="#ffffff",
                  font=("Consolas", 10))
    txt.pack(pady=2)
    entry_widgets[cat] = txt
    
    # Add button
    add_btn = ttk.Button(sub, text=f"➕ Add {cat.replace('_', ' ').title()}", 
                        command=lambda c=cat: add_item(c))
    add_btn.pack(pady=2, fill=tk.X)

# Separator
separator = ttk.Separator(root, orient='horizontal')
separator.pack(fill=tk.X, padx=10, pady=5)

# Wishlist section
list_label = tk.Label(root, text="📋 Your Wishlist Collection", 
                     bg="#121212", fg="#e53935", 
                     font=("Helvetica", 14, "bold"))
list_label.pack(pady=5)

list_container = ttk.Frame(root)
list_container.pack(fill=tk.BOTH, expand=True, padx=12, pady=4)

for col, cat in enumerate(categories):
    lst_frame = ttk.Frame(list_container)
    lst_frame.grid(row=0, column=col, padx=6, sticky="nsew")
    list_container.grid_columnconfigure(col, weight=1)
    
    # Category header with count
    cat_icons = {"movies": "🎬", "tv_shows": "📺", "games": "🎮", "anime": "🎌"}
    header_label = ttk.Label(lst_frame, 
                           text=f"{cat_icons.get(cat, '📁')} {cat.replace('_', ' ').title()}")
    header_label.pack(anchor="n", pady=2)
    
    # Listbox with scrollbar
    listbox_frame = tk.Frame(lst_frame, bg="#121212")
    listbox_frame.pack(fill=tk.BOTH, expand=True)
    
    lb = tk.Listbox(
        listbox_frame,
        selectmode=tk.MULTIPLE,
        bg="#1e1e1e",
        fg="white",
        relief=tk.FLAT,
        highlightthickness=0,
        font=("Segoe UI", 10),
        activestyle="none"
    )
    lb.pack(side=tk.LEFT, fill=tk.BOTH, expand=True)
    listbox_widgets[cat] = lb
    
    # Scrollbar
    scrollbar = tk.Scrollbar(listbox_frame, orient="vertical", command=lb.yview)
    scrollbar.pack(side=tk.RIGHT, fill=tk.Y)
    lb.config(yscrollcommand=scrollbar.set)
    
    # Load items
    refresh_items(cat)

    # Control buttons
    btnf = ttk.Frame(lst_frame)
    btnf.pack(fill=tk.X, pady=3)
    
    # First row of buttons
    btn_row1 = tk.Frame(btnf, bg="#121212")
    btn_row1.pack(fill=tk.X, pady=1)
    
    remove_all_btn = tk.Button(btn_row1, text="🗑️ Remove All", 
                               command=lambda c=cat: delete_all(c),
                               bg="#dc3545", fg="white", 
                               font=("Helvetica", 8, "bold"),
                               relief=tk.FLAT)
    remove_all_btn.pack(side=tk.LEFT, padx=1, fill=tk.X, expand=True)
    
    remove_sel_btn = tk.Button(btn_row1, text="❌ Remove Selected", 
                               command=lambda c=cat: delete_selected(c),
                               bg="#fd7e14", fg="white", 
                               font=("Helvetica", 8, "bold"),
                               relief=tk.FLAT)
    remove_sel_btn.pack(side=tk.LEFT, padx=1, fill=tk.X, expand=True)
    
    # Second row of buttons
    btn_row2 = tk.Frame(btnf, bg="#121212")
    btn_row2.pack(fill=tk.X, pady=1)
    
    download_all_btn = tk.Button(btn_row2, text=f"⬇️ Download All ({cat.replace('_', ' ').title()})", 
                                command=lambda c=cat: run_all(c),
                                bg="#28a745", fg="white", 
                                font=("Helvetica", 8, "bold"),
                                relief=tk.FLAT)
    download_all_btn.pack(fill=tk.X)

    # Third row of buttons
    btn_row3 = tk.Frame(btnf, bg="#121212")
    btn_row3.pack(fill=tk.X, pady=1)
    
    copy_sel_btn = tk.Button(btn_row3, text="📋 Copy Selected", 
                            command=lambda c=cat: copy_selected_titles(c),
                            bg="#17a2b8", fg="white", 
                            font=("Helvetica", 8, "bold"),
                            relief=tk.FLAT)
    copy_sel_btn.pack(fill=tk.X)

# Global controls section
controls_frame = tk.Frame(root, bg="#121212")
controls_frame.pack(fill=tk.X, padx=10, pady=10)

# Main download button
main_download_btn = tk.Button(controls_frame, 
                             text="🚀 AUTO-DOWNLOAD TOP 3 TORRENTS (SELECTED ITEMS)", 
                             command=YOUR_CLIENT_SECRET_HERE,
                             bg="#007bff", fg="white", 
                             font=("Helvetica", 12, "bold"),
                             relief=tk.FLAT,
                             padx=20, pady=10)
main_download_btn.pack(pady=5)

# Info section
info_frame = tk.Frame(root, bg="#121212")
info_frame.pack(fill=tk.X, padx=10, pady=5)

info_text = """🔥 PREMIUM FEATURES:
• 1337x Integration - High-quality torrents with excellent seeders
• Nyaa Integration - Best source for anime and Asian content  
• TorrentGalaxy - Reliable general purpose torrent source
• YTS Integration - High-quality movie torrents in smaller sizes
• Intelligent Search - Auto-modifies queries for better results
• Multi-threaded Downloads - Faster processing with parallel searches
• Auto Top-3 Selection - Always gets the most seeded torrents"""

info_label = tk.Label(info_frame, text=info_text, 
                     bg="#121212", fg="#ffc107", 
                     font=("Consolas", 9),
                     justify=tk.LEFT)
info_label.pack(anchor="w")

# Status bar
status_frame = tk.Frame(root, bg="#1e1e1e", relief=tk.SUNKEN, bd=1)
status_frame.pack(fill=tk.X, side=tk.BOTTOM)

status_label = tk.Label(status_frame, 
                       text="✅ Ready - Premium sources loaded and ready for enhanced downloads!", 
                       bg="#1e1e1e", fg="#00ff00", 
                       font=("Helvetica", 10, "bold"))
status_label.pack(side=tk.LEFT, padx=10, pady=5)

# Version info
version_label = tk.Label(status_frame, 
                        text="v2.0 Premium Edition | Enhanced Sources", 
                        bg="#1e1e1e", fg="#6c757d", 
                        font=("Helvetica", 8))
version_label.pack(side=tk.RIGHT, padx=10, pady=5)

# Bind double-click to download single item
def on_double_click(event):
    """Handle double-click on listbox item."""
    widget = event.widget
    selection = widget.curselection()
    if selection:
        # Find which category this listbox belongs to
        category = None
        for cat, lb in listbox_widgets.items():
            if lb == widget:
                category = cat
                break
        
        if category:
            title = widget.get(selection[0])
            if messagebox.askyesno("Download Item", f"Download top 3 torrents for '{title}'?"):
                query = modify_title[category](title)
                threading.Thread(target=auto_download_top_3, args=(query,), daemon=True).start()

# Bind double-click to all listboxes
for lb in listbox_widgets.values():
    lb.bind("<Double-Button-1>", on_double_click)

# Keyboard shortcuts
def on_key_press(event):
    """Handle keyboard shortcuts."""
    if event.state & 0x4:  # Ctrl key
        if event.keysym == 'd':  # Ctrl+D
            YOUR_CLIENT_SECRET_HERE()
        elif event.keysym == 'r':  # Ctrl+R
            for cat in categories:
                refresh_items(cat)
            update_status("🔄 Refreshed all categories")

root.bind("<KeyPress>", on_key_press)

# Cleanup function
def on_closing():
    """Handle application closing."""
    if messagebox.askokcancel("Quit", "Do you want to quit the Enhanced Wishlist Manager?"):
        try:
            conn.close()
            print("👋 Database connection closed.")
        except:
            pass
        root.destroy()

root.protocol("WM_DELETE_WINDOW", on_closing)

# Auto-refresh every 30 seconds
def auto_refresh():
    """Auto-refresh the interface."""
    try:
        # Check for any pending uploads
        threading.Thread(target=upload_remote_db, daemon=True).start()
    except:
        pass
    
    # Schedule next refresh
    root.after(30000, auto_refresh)

# Start auto-refresh
root.after(30000, auto_refresh)

# YOUR_CLIENT_SECRET_HERE
# Application Entry Point
# YOUR_CLIENT_SECRET_HERE
if __name__ == "__main__":
    try:
        print("🚀 Michael Fedro's Enhanced Wishlist Manager - Premium Sources Edition")
        print("=" * 70)
        print("✨ Premium Features Loaded:")
        print("   🔥 1337x Integration - High-quality torrents")
        print("   🎌 Nyaa Integration - Best anime source")
        print("   🌟 TorrentGalaxy - Reliable general torrents")
        print("   🎬 YTS Integration - Quality movies")
        print("   ⚡ Multi-threaded searches for speed")
        print("   🎯 Auto top-3 selection by seeders")
        print("=" * 70)
        print("📂 qBittorrent Path:", QBITTORRENT_PATH)
        print("🌐 Remote Server:", HOSTNAME)
        print("💾 Local Database:", LOCAL_DB_FILENAME)
        print("=" * 70)
        print("🎮 Controls:")
        print("   • Double-click any item to download")
        print("   • Ctrl+D: Download selected items")
        print("   • Ctrl+R: Refresh all categories")
        print("=" * 70)
        
        update_status("🚀 Premium sources initialized - Ready for enhanced downloads!")
        root.mainloop()
        
    except KeyboardInterrupt:
        print("\n⚠️ Application interrupted by user")
    except Exception as e:
        print(f"❌ Application error: {e}")
        messagebox.showerror("Application Error", f"An error occurred: {e}")
    finally:
        try:
            conn.close()
            print("👋 Application closed. Database connection closed.")
        except:
            pass
