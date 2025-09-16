#!/usr/bin/env python3
"""
COMPLETE Game Manager Application - ENHANCED TERMINAL VERSION
michael fedro's backup & restore tool - Full Featured Terminal Interface with Enhanced Tab Navigation
"""

# ===== IMPORTS =====
import sys
import os
import json
import time
import subprocess
import requests
import re
import threading
import random
import concurrent.futures
import urllib.parse
from pathlib import Path
from datetime import datetime
from io import BytesIO
from functools import partial
import shutil
import tempfile
import hashlib
from concurrent.futures import ThreadPoolExecutor

# Terminal interface imports
try:
    import colorama
    colorama.init(autoreset=True)
    Fore = colorama.Fore  # type: ignore
    Back = colorama.Back  # type: ignore
    Style = colorama.Style  # type: ignore
    HAS_COLORAMA = True
except ImportError:
    HAS_COLORAMA = False
    # Fallback ANSI codes
    class Fore:
        RED = '\033[31m'
        GREEN = '\033[32m'
        YELLOW = '\033[33m'
        BLUE = '\033[34m'
        MAGENTA = '\033[35m'
        CYAN = '\033[36m'
        WHITE = '\033[37m'
        RESET = '\033[0m'
    
    class Back:
        BLACK = '\033[40m'
        RED = '\033[41m'
        GREEN = '\033[42m'
        YELLOW = '\033[43m'
        BLUE = '\033[44m'
        MAGENTA = '\033[45m'
        CYAN = '\033[46m'
        WHITE = '\033[47m'
        RESET = '\033[0m'
    
    class Style:
        BRIGHT = '\033[1m'
        DIM = '\033[2m'
        NORMAL = '\033[22m'
        RESET_ALL = '\033[0m'

# Optional imports with fallbacks
try:
    from requests.adapters import HTTPAdapter, Retry
    session = requests.Session()
    retries = Retry(total=3, backoff_factor=1, status_forcelist=[429, 500, 502, 503, 504])
    adapter = HTTPAdapter(max_retries=retries)
    session.mount("http://", adapter)
    session.mount("https://", adapter)
except ImportError:
    session = requests.Session()

try:
    from howlongtobeatpy import HowLongToBeat
except ImportError:
    HowLongToBeat = None

try:
    import wordninja
except ImportError:
    wordninja = None

try:
    from bs4 import BeautifulSoup
except ImportError:
    BeautifulSoup = None

try:
    from PIL import Image, ImageDraw, ImageFont
except ImportError:
    Image = ImageDraw = ImageFont = None

# ===== CONSTANTS AND HEADERS =====
HEADERS = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
    'Accept-Language': 'en-US,en;q=0.5',
    'DNT': '1',
    'Connection': 'keep-alive',
    'YOUR_CLIENT_SECRET_HERE': '1',
}

# File paths for persistence
SESSION_FILE = "user_session.json"
SETTINGS_FILE = "tag_settings.json"
TABS_CONFIG_FILE = "tabs_config.json"
BANNED_USERS_FILE = "banned_users.json"
ACTIVE_USERS_FILE = "active_users.json"
CUSTOM_BUTTONS_FILE = "custom_buttons.json"
YOUR_CLIENT_SECRET_HERE = "game_destinations.json"
TAGS_CACHE_FILE = "tags_cache.json"
TAGS_CACHE_MAX_AGE = 600  # 10 minutes in seconds
TIME_CACHE_FILE = "time_cache.json"

# ===== JSON DATA EMBEDDED =====
ACTIVE_USERS_DATA = {
    "michadockermisha": {"login_time": 1744754216.7948096}, 
    "misha": {"login_time": 1750355042.7735698}
}

GAMES_DATA = {
    "all_games": [
        "13SentinelsAegisRim", "advancedwars", "alanwake", "anothercrabstreasure", "Ashen",
        "YOUR_CLIENT_SECRET_HERE", "AtelierYumia", "Battletoads", "BrightMemoryInfinite",
        "YOUR_CLIENT_SECRET_HERE", "CrimeBossRockayCity", "DeusExInvisibleWar", "EnderalForgottenStories",
        "EternalStrands", "YOUR_CLIENT_SECRET_HERE", "GardenPaws", "Hellpoint", "inZOI",
        "JurassicWorldEvolution2", "KingdomComeDeliverance", "legoBatman2", "LEGOHarryPotter57",
        "YOUR_CLIENT_SECRET_HERE", "MySummerCar", "MyTimeatSandrock", "Obduction",
        "Omensight", "YOUR_CLIENT_SECRET_HERE", "PHOGS", "YOUR_CLIENT_SECRET_HERE",
        "RajiAnAncientEpic", "YOUR_CLIENT_SECRET_HERE", "rivals2", "SamuraiGunn2",
        "ScarletHollow", "ScheduleI", "YOUR_CLIENT_SECRET_HERE", "SixDaysinFallujah",
        "Skullgirls2ndEncore", "Somerville", "SpeedRunners", "SpellForce3Reforced",
        "SpintiresMudRunner", "Steep", "SunlessSea", "SunlessSkies", "SyberiaTheWorldBefore",
        "TDPAHouseofAshes", "YOUR_CLIENT_SECRET_HERE", "YOUR_CLIENT_SECRET_HERE",
        "YOUR_CLIENT_SECRET_HERE", "TheEscapists2", "YOUR_CLIENT_SECRET_HERE",
        "ThreeMinutesToEight", "TransportFever2", "Unrailed", "Wanderstop", "WobblyLife",
        "Wreckfest", "YokusIslandExpress", "ZooTycoon", "Resistance3", "rimword", "Roboquest",
        "sims4", "StrayBlade", "TailsofIron", "TailsofIron2", "TalosPrinciple", "ThankGoodnessYoureHere",
        "batmantts", "tloh", "witcher3", "thexpanse", "planetcoaster", "sleepingdogs", "gtviv",
        "goodbyevolcanohigh", "fallout4", "oblivion", "citieskylines2", "kingdomofamalur", "wolfenstein2"
    ],
    "category_games": {
        "interactive": ["batmantts", "thexpanse", "beyond2soul", "games27", "continue"],
        "mouse": ["hackersimulator", "baldursgate3"],
        "shooter": ["sniperelite3", "deeprockgalactic"],
        "chill": ["lostinplay", "powerwashsimulator"],
        "action": ["firemblem3houses", "firemblemengage"],
        "platform": ["sable", "octopathtraveler2"]
    }
}

DEFAULT_TABS_CONFIG = [
    {"id": "all", "name": "All", "color": Fore.WHITE},
    {"id": "finished", "name": "Finished", "color": Fore.GREEN},
    {"id": "mybackup", "name": "MyBackup", "color": Fore.BLUE},
    {"id": "not_for_me", "name": "meh", "color": Fore.RED},
    {"id": "soulslike", "name": "SoulsLike", "color": Fore.MAGENTA},
    {"id": "localcoop", "name": "LocalCoop", "color": Fore.YELLOW},
    {"id": "oporationsystems", "name": "OporationSystems", "color": Fore.CYAN},
    {"id": "music", "name": "music", "color": Fore.GREEN},
    {"id": "simulators", "name": "simulators", "color": Fore.BLUE},
    {"id": "tvshows", "name": "repeat", "color": Fore.MAGENTA},
    {"id": "bulkgames", "name": "BulkGames", "color": Fore.YELLOW},
    {"id": "nintendo/switch", "name": "Nintendo/Switch", "color": Fore.RED},
    {"id": "shooters", "name": "shooters", "color": Fore.CYAN},
    {"id": "openworld", "name": "OpenWorld", "color": Fore.GREEN},
    {"id": "hacknslash", "name": "HackNslash", "color": Fore.BLUE},
    {"id": "chill", "name": "Chill", "color": Fore.MAGENTA},
    {"id": "storydriven", "name": "StoryDriven", "color": Fore.YELLOW},
    {"id": "platformers", "name": "platformers", "color": Fore.CYAN}
]

CUSTOM_BUTTONS_DATA = [
    ["BackItUp", "wsl --distribution ubuntu --user root -- bash -lic 'backitup'"],
    ["BigiTGo", "wsl --distribution ubuntu --user root -- bash -lic 'bigitgo'"],
    ["gg", "wsl --distribution ubuntu --user root -- bash -lic 'gg'"],
    ["dcreds", "wsl --distribution ubuntu --user root -- bash -lic 'dcreds'"],
    ["savegames", "wsl --distribution ubuntu --user root -- bash -lic 'savegames'"],
    ["GameSaveRestore", "wsl --distribution ubuntu --user root -- bash -lic 'gamedg'"],
    ["Clear Terminal", "powershell -NoProfile -Command \"Clear-Host; [System.Console]::Clear(); cls\""],
    ["dkill", "wsl --distribution ubuntu --user root -- bash -lic 'dkill'"],
    ["saveweb", "wsl --distribution ubuntu --user root -- bash -lic 'saveweb'"]
]

# Game completion times data
GAME_TIMES_DATA = {
    "aithesomniumfiles": "~27.5 hrs", "americanarcedia": "~7.5 hrs", "ancestorshumankind": "~39 hrs",
    "artfulescape": "~4.5 hrs", "asduskfalls": "~8.5 hrs", "aspacefortheunbound": "~10.5 hrs",
    "atdeadofnight": "~8 hrs", "atlasfallen": "~18 hrs", "banishers": "~46 hrs", "binarydomain": "~11 hrs",
    "blackskylands": "~15 hrs", "blacktail": "~20 hrs", "brotherstaleoftwosons": "~3 hrs",
    "cocoon": "~5 hrs", "cultofthelamb": "~24 hrs", "gtviv": "~40.5 hrs", "highonlife": "~12 hrs",
    "lostinplay": "~5 hrs", "mirage": "~25 hrs", "octopathtraveler2": "~100 hrs", "prisonsimulator": "~15 hrs",
    "reddeadredemption": "~30 hrs", "riftapart": "~15 hrs", "slaytheprincess": "~4 hrs",
    "sleepingdogs": "~25 hrs", "stray": "~7 hrs", "tendates": "~4 hrs", "thepluckysquire": "~6 hrs",
    "transistor": "~8 hrs", "xmen": "~10 hrs", "eldenring": "~100 hrs", "eldenrings": "~100 hrs",
    "liesofp": "~45 hrs", "lordsofthefallen": "~30 hrs", "sekiro": "~40 hrs", "sekiroshadowsdietwice": "~40 hrs",
    "witcher3": "~105 hrs", "fallout4": "~110 hrs", "baldursgate3": "~130 hrs", "oblivion": "~100 hrs"
}

DEFAULT_DESTINATION = os.path.expanduser("~\\Games")

# ===== TERMINAL UTILITY FUNCTIONS =====
def clear_screen():
    """Clear terminal screen"""
    os.system('cls' if os.name == 'nt' else 'clear')

def print_header(title):
    """Print a formatted header"""
    width = 80
    print(f"\n{Fore.CYAN}{Style.BRIGHT}{'=' * width}")
    print(f"{title:^{width}}")
    print(f"{'=' * width}{Style.RESET_ALL}\n")

def print_menu_option(number, text, color=Fore.WHITE):
    """Print a formatted menu option"""
    print(f"{Fore.YELLOW}[{number}]{color} {text}")

def print_tab_button(number, text, color=Fore.WHITE, is_active=False):
    """Print a formatted tab button"""
    marker = "►" if is_active else " "
    print(f"{color}[{number}]{marker} {text}{Style.RESET_ALL}")

def print_error(message):
    """Print an error message"""
    print(f"{Fore.RED}{Style.BRIGHT}❌ Error: {message}{Style.RESET_ALL}")

def print_success(message):
    """Print a success message"""
    print(f"{Fore.GREEN}{Style.BRIGHT}✅ {message}{Style.RESET_ALL}")

def print_warning(message):
    """Print a warning message"""
    print(f"{Fore.YELLOW}{Style.BRIGHT}⚠️  {message}{Style.RESET_ALL}")

def print_info(message):
    """Print an info message"""
    print(f"{Fore.CYAN}ℹ️  {message}{Style.RESET_ALL}")

def get_user_input(prompt, color=Fore.WHITE):
    """Get user input with colored prompt"""
    return input(f"{color}{prompt}{Style.RESET_ALL}")

def get_user_choice(prompt, valid_choices):
    """Get user choice with validation"""
    while True:
        choice = get_user_input(f"{prompt} ({'/'.join(valid_choices)}): ").lower().strip()
        if choice in valid_choices:
            return choice
        print_error(f"Invalid choice. Please enter one of: {', '.join(valid_choices)}")

def pause():
    """Pause and wait for user input"""
    get_user_input(f"\n{Fore.MAGENTA}Press Enter to continue...{Style.RESET_ALL}")

def confirm_action(message):
    """Ask for confirmation"""
    choice = get_user_choice(f"{message} (y/n)", ['y', 'yes', 'n', 'no'])
    return choice in ['y', 'yes']

def parse_time_to_hours(time_str):
    """Parse time string to hours for sorting"""
    if time_str == 'N/A':
        return 0
    try:
        time_str = time_str.replace('~', '').replace('hrs', '').replace('hours', '').replace('hr', '').strip()
        time_str = time_str.replace('(est.)', '').replace('(est)', '').strip()
        
        # Handle ranges like "10-15 hrs" - take the average
        if '-' in time_str or '–' in time_str:
            time_str = time_str.replace('–', '-')
            parts = time_str.split('-')
            if len(parts) == 2:
                try:
                    start = float(parts[0].strip())
                    end = float(parts[1].strip())
                    return (start + end) / 2  # Return average
                except:
                    return float(parts[1].strip())  # Return end value if start fails
        
        # Handle single values
        return float(time_str)
    except:
        return 0

def display_games_in_grid(games, title="Games", games_per_row=3, show_selection=True, selected_tags=None, app_instance=None, clear_screen_first=True):
    """Display games in a grid format with size and completion time - all on one page"""
    if not games:
        print_warning("No games to display.")
        return None
    
    if selected_tags is None:
        selected_tags = set()
    
    if clear_screen_first:
        clear_screen()
    
    print_header(title)
    
    # Display all games in grid (no pagination)
    print(f"{Fore.CYAN}Showing all {len(games)} games\n")
    
    for row_start in range(0, len(games), games_per_row):
        row_games = games[row_start:row_start + games_per_row]
        
        for i, game in enumerate(row_games):
            game_idx = row_start + i + 1
            is_selected = game['docker_name'] in selected_tags if show_selection else False
            selection_marker = "●" if is_selected else "○"
            
            # Get size in GB
            size_bytes = game.get('full_size', 0)
            size_gb = size_bytes / (1024**3) if size_bytes > 0 else 0
            size_str = f"{size_gb:.1f}GB" if size_gb > 0 else "N/A"
            
            # Get completion time
            completion_time = game.get('approx_time', 'N/A')
            
            # Show full tag name without truncation
            display_name = game['alias']
            
            color = Fore.GREEN if is_selected else Fore.WHITE
            print(f"{Fore.YELLOW}[{game_idx:3d}]{color} {selection_marker} {display_name:<30} {Fore.CYAN}{size_str:<8} {Fore.MAGENTA}{completion_time:<12}", end="  ")
        
        print()  # New line after each row
    
    print(f"\n{Fore.MAGENTA}Legend: ● Selected | ○ Not Selected | Size in GB | Completion Time")
    
    # Navigation options (no pagination needed)
    nav_options = ["#=Select", "t#=Toggle", "r=Run Selected", "a=Add Game", "b=Back", "sa=Select All", "da=Deselect All", "s1=Sort:Heaviest", "s2=Sort:Lightest", "s3=Sort:Longest", "s4=Sort:Shortest", "s5=Sort:Newest", "s6=Sort:Oldest"]
    
    # Add quick sync option if app instance is provided
    if app_instance and not app_instance.is_guest:
        nav_options.append("qs=Quick Sync by Tags")
    
    choice = get_user_input(f"Navigation ({', '.join(nav_options)}): ").lower().strip()
    
    # Check if input is a tag name for quick syncing
    if handle_tag_name_input(choice, app_instance):
        return None
    
    # Check for quick sync by tags (e.g., "witcher3 eldenring fallout4")
    if app_instance and not app_instance.is_guest and ' ' in choice and not choice.startswith(('t', 'r', 'a', 'b', 's', 'd', 'q')):
        # This looks like tag names separated by spaces
        tag_names = choice.split()
        print_info(f"Quick syncing tags: {', '.join(tag_names)}")
        success = app_instance.quick_sync_by_tags(tag_names)
        if success:
            print_success("Quick sync completed!")
        else:
            print_warning("Quick sync failed or was cancelled.")
        pause()
        return None
    
    if choice == 'r':
        return ("run_selected", None)
    elif choice == 'a':
        return ("add_game", None)
    elif choice == 'b':
        return None
    elif choice.startswith('t') and len(choice) > 1:
        try:
            selection = int(choice[1:]) - 1
            if 0 <= selection < len(games):
                return ("toggle", games[selection])
            else:
                print_error("Invalid game number.")
        except ValueError:
            print_error("Please enter a valid number after 't'.")
    elif choice.isdigit():
        try:
            selection = int(choice) - 1
            if 0 <= selection < len(games):
                return games[selection]
            else:
                print_error("Invalid game number.")
        except ValueError:
            print_error("Please enter a valid number.")
    elif choice == 'sa':
        return ("select_all", None)
    elif choice == 'da':
        return ("deselect_all", None)
    elif choice == 'qs' and app_instance and not app_instance.is_guest:
        # Quick sync by entering tag names
        tag_input = get_user_input("Enter tag names separated by spaces: ").strip()
        if tag_input:
            tag_names = tag_input.split()
            print_info(f"Quick syncing tags: {', '.join(tag_names)}")
            success = app_instance.quick_sync_by_tags(tag_names)
            if success:
                print_success("Quick sync completed!")
            else:
                print_warning("Quick sync failed or was cancelled.")
            pause()
            return None
    elif choice == 's1':
        # Sort by size (heaviest first)
        clear_screen()
        games.sort(key=lambda x: x.get('full_size', 0), reverse=True)
        print_success("Sorted by size (heaviest first)")
        time.sleep(0.5)
        return display_games_in_grid(games, title, games_per_row, show_selection, selected_tags, app_instance)
    elif choice == 's2':
        # Sort by size (lightest first)
        clear_screen()
        games.sort(key=lambda x: x.get('full_size', 0), reverse=False)
        print_success("Sorted by size (lightest first)")
        time.sleep(0.5)
        return display_games_in_grid(games, title, games_per_row, show_selection, selected_tags, app_instance)
    elif choice == 's3':
        # Sort by time (longest first)
        clear_screen()
        games.sort(key=lambda x: parse_time_to_hours(x.get('approx_time', 'N/A')), reverse=True)
        print_success("Sorted by completion time (longest first)")
        time.sleep(0.5)
        return display_games_in_grid(games, title, games_per_row, show_selection, selected_tags, app_instance)
    elif choice == 's4':
        # Sort by time (shortest first)
        clear_screen()
        games.sort(key=lambda x: parse_time_to_hours(x.get('approx_time', 'N/A')), reverse=False)
        print_success("Sorted by completion time (shortest first)")
        time.sleep(0.5)
        return display_games_in_grid(games, title, games_per_row, show_selection, selected_tags, app_instance)
    elif choice == 's5':
        # Sort by date (newest first)
        clear_screen()
        games.sort(key=lambda x: parse_date(x.get('last_updated', '')), reverse=True)
        print_success("Sorted by date (newest first)")
        time.sleep(0.5)
        return display_games_in_grid(games, title, games_per_row, show_selection, selected_tags, app_instance)
    elif choice == 's6':
        # Sort by date (oldest first)
        clear_screen()
        games.sort(key=lambda x: parse_date(x.get('last_updated', '')), reverse=False)
        print_success("Sorted by date (oldest first)")
        time.sleep(0.5)
        return display_games_in_grid(games, title, games_per_row, show_selection, selected_tags, app_instance)
    else:
        print_error("Invalid choice. Please try again.")
        time.sleep(1)

# ===== UTILITY FUNCTIONS =====
def format_size(size):
    """Format size in bytes to human readable format"""
    try:
        size = int(size)
        for unit in ["B", "KB", "MB", "GB", "TB"]:
            if size < 1024:
                return f"{size:.1f}{unit}"
            size /= 1024
        return f"{size:.1f}PB"
    except (ValueError, TypeError):
        return "Unknown"

def sanitize_filename(name):
    """Convert game name to filename without spaces"""
    clean_name = re.sub(r'[^\w\s-]', '', name.lower())
    clean_name = clean_name.replace(' ', '')
    return clean_name

def normalize_game_title(tag):
    """Normalize game title for better matching"""
    if " " in tag:
        return tag
    if any(c.isupper() for c in tag[1:]):
        return re.sub(r'(?<!^)(?=[A-Z])', ' ', tag).strip()
    if wordninja is not None:
        return " ".join(wordninja.split(tag))
    return tag.title()

def find_game_by_tag_name(tag_name, all_tags):
    """Find a game by tag name (docker_name or alias)"""
    tag_name_lower = tag_name.lower().strip()
    
    # First try exact match with docker_name
    for game in all_tags:
        if game['docker_name'].lower() == tag_name_lower:
            return game
    
    # Then try exact match with alias
    for game in all_tags:
        if game['alias'].lower() == tag_name_lower:
            return game
    
    # Then try partial match with docker_name
    for game in all_tags:
        if tag_name_lower in game['docker_name'].lower():
            return game
    
    # Finally try partial match with alias
    for game in all_tags:
        if tag_name_lower in game['alias'].lower():
            return game
    
    return None

def parse_date(date_str):
    """Parse date string to datetime object"""
    try:
        return datetime.fromisoformat(date_str.replace("Z", ""))
    except Exception:
        return datetime.min

def format_game_name(game_name):
    """Format game names to be more readable for searching"""
    name = re.sub(r'([a-z])([A-Z])', r'\1 \2', game_name)
    
    replacements = {
        'liesofp': 'Lies of P', 'redout2': 'Redout 2', 'rimword': 'RimWorld',
        'sims4': 'The Sims 4', 'ftl': 'FTL: Faster Than Light',
        'codmw': 'Call of Duty: Modern Warfare', 'codmw3': 'Call of Duty: Modern Warfare 3',
        'batmantts': 'Batman: The Telltale Series', 'batmantew': 'Batman: The Enemy Within',
        'gtviv': 'Grand Theft Auto IV'
    }
    
    if game_name.lower() in replacements:
        return replacements[game_name.lower()]
    
    name = re.sub(r'(\d+)([a-zA-Z])', r'\1 \2', name)
    name = re.sub(r'([a-zA-Z])(\d+)', r'\1 \2', name)
    
    abbr_prefixes = ['cod', 'lego', 'tdp', 'gta']
    for prefix in abbr_prefixes:
        if name.lower().startswith(prefix) and len(name) > len(prefix):
            rest = name[len(prefix):]
            if rest[0].isupper() or rest[0].isdigit():
                name = prefix.upper() + " " + rest
    
    return name

def is_valid_menu_choice(choice, valid_choices):
    """Check if input is a valid menu choice or a tag name"""
    choice_upper = choice.upper().strip()
    
    # Check if it's a valid menu choice
    if choice_upper in valid_choices:
        return True
    
    # Check if it's a number (for tab selection)
    if choice.isdigit():
        return True
    
    # Check if it's a single letter command
    if len(choice) == 1 and choice_upper in ['G', 'R', 'S', 'O', 'M', 'T', 'Y', 'A', 'P', 'X', 'B', 'C', 'D', 'E', '8', '9', 'J', 'DC', '0', 'Q']:
        return True
    
    # Check if it's a multi-letter command
    if choice_upper in ['TD', 'TR', 'NT', 'ET', 'DT', 'VT', 'BM']:
        return True
    
    # If it's longer than 1 character and not a valid command, it might be a tag name
    return False

def handle_tag_name_input(choice, app_instance):
    """Handle tag name input for quick syncing"""
    if not app_instance or app_instance.is_guest:
        return False
    
    choice_upper = choice.upper().strip()
    
    # Don't interfere with valid menu choices
    valid_menu_choices = ['G', 'R', 'S', 'O', 'M', 'T', 'Y', 'A', 'P', 'X', 'B', 'C', 'D', 'E', '8', '9', 'J', 'DC', '0', 'Q', 'TD', 'TR', 'NT', 'ET', 'DT', 'VT', 'BM', 'MT', 'UT', 'S1', 'S2', 'S3', 'S4', 'S5', 'S6']
    if choice_upper in valid_menu_choices:
        return False
    
    # Check if it looks like a tag name (not a menu choice)
    if (len(choice) > 1 and not choice.isdigit() and 
        not is_valid_menu_choice(choice, [])):
        
        # Check for multiple tag names separated by spaces
        if ' ' in choice:
            tag_names = choice.split()
            print_info(f"Quick syncing tags: {', '.join(tag_names)}")
            success = app_instance.quick_sync_by_tags(tag_names)
        else:
            # Single tag name
            print_info(f"Quick syncing tag: {choice}")
            success = app_instance.quick_sync_by_tag_name(choice)
        
        if success:
            print_success("Quick sync completed!")
        else:
            print_warning("Quick sync failed or was cancelled.")
        pause()
        return True
    
    return False

# ===== FILE PERSISTENCE FUNCTIONS =====
def load_session():
    if os.path.exists(SESSION_FILE):
        try:
            with open(SESSION_FILE, "r") as f:
                return json.load(f)
        except Exception as e:
            print_error(f"Error loading session file: {e}")
    return None

def save_session(session_data):
    try:
        with open(SESSION_FILE, "w") as f:
            json.dump(session_data, f)
    except Exception as e:
        print_error(f"Error saving session file: {e}")

def clear_session():
    if os.path.exists(SESSION_FILE):
        os.remove(SESSION_FILE)

def load_settings():
    """Load settings using enhanced JSON system"""
    return YOUR_CLIENT_SECRET_HERE('tag_settings.json', {})

def save_settings(settings):
    """Save settings using enhanced JSON system"""
    return auto_save_data('settings', settings)

def load_tabs_config():
    """Load tabs config using enhanced JSON system"""
    return YOUR_CLIENT_SECRET_HERE('tabs_config.json', DEFAULT_TABS_CONFIG)

def save_tabs_config(config):
    """Save tabs config using enhanced JSON system"""
    return auto_save_data('tabs', config)

def load_banned_users():
    """Load banned users using enhanced JSON system"""
    return YOUR_CLIENT_SECRET_HERE('banned_users.json', [])

def save_banned_users(banned):
    """Save banned users using enhanced JSON system"""
    return auto_save_data('banned_users', banned)

def load_active_users():
    """Load active users using enhanced JSON system"""
    return YOUR_CLIENT_SECRET_HERE('active_users.json', ACTIVE_USERS_DATA)

def save_active_users(users):
    """Save active users using enhanced JSON system"""
    return auto_save_data('active_users', users)

def load_custom_buttons():
    """Load custom buttons using enhanced JSON system"""
    return YOUR_CLIENT_SECRET_HERE('custom_buttons.json', CUSTOM_BUTTONS_DATA)

def save_custom_buttons(buttons):
    """Save custom buttons using enhanced JSON system"""
    return auto_save_data('custom_buttons', buttons)

def load_game_categories():
    """Load game categories using enhanced JSON system"""
    return YOUR_CLIENT_SECRET_HERE('game_categories.json', GAME_CATEGORIES_DATA)

def save_game_categories(categories):
    """Save game categories using enhanced JSON system"""
    return auto_save_data('game_categories', categories)

def load_user_preferences():
    """Load user preferences using enhanced JSON system"""
    return YOUR_CLIENT_SECRET_HERE('user_preferences.json', USER_PREFERENCES_DATA)

def save_user_preferences(preferences):
    """Save user preferences using enhanced JSON system"""
    return auto_save_data('user_preferences', preferences)

def load_sync_history():
    """Load sync history using enhanced JSON system"""
    return YOUR_CLIENT_SECRET_HERE('sync_history.json', SYNC_HISTORY_DATA)

def save_sync_history(history):
    """Save sync history using enhanced JSON system"""
    return auto_save_data('sync_history', history)

def load_game_metadata():
    """Load game metadata using enhanced JSON system"""
    return YOUR_CLIENT_SECRET_HERE('game_metadata.json', GAME_METADATA_DATA)

def save_game_metadata(metadata):
    """Save game metadata using enhanced JSON system"""
    return auto_save_data('game_metadata', metadata)

def load_time_data(file_path):
    """Load game time data from file or use embedded data, with caching for speed."""
    import json, os, time
    # Check if cache exists and is valid
    if os.path.exists(file_path) and os.path.exists(TIME_CACHE_FILE):
        try:
            file_mtime = os.path.getmtime(file_path)
            with open(TIME_CACHE_FILE, "r", encoding="utf-8") as f:
                cache = json.load(f)
            if cache.get("mtime") == file_mtime and "data" in cache:
                return cache["data"]
        except Exception as e:
            print_warning(f"Could not load time cache: {e}")
    # Parse time.txt as before
    time_data = {}
    if os.path.exists(file_path):
        try:
            with open(file_path, "r", encoding='utf-8') as f:
                for line in f:
                    line = line.strip()
                    if not line or line in ["Games", "Finished", "Meh", "SoulsLike", "LocalCoop", "OporationSystems", "music", "simulators", "tvshows", "bulkgames", "nintendo/switch", "shooters", "openworld", "hacknslash", "chill", "storydriven", "platformers"]:
                        continue
                    if "–" in line:
                        parts = line.split("–")
                    elif "-" in line:
                        parts = line.split("-")
                    elif ":" in line:
                        parts = line.split(":")
                    else:
                        continue
                    if len(parts) >= 2:
                        tag = parts[0].strip().lower()
                        time_val = parts[1].strip()
                        time_data[tag] = time_val
                        time_data[tag.upper()] = time_val
                        time_data[tag.title()] = time_val
        except Exception as e:
            print_error(f"Error loading time data from file: {e}")
    if not time_data:
        time_data = GAME_TIMES_DATA
    # Save cache
    if os.path.exists(file_path):
        try:
            file_mtime = os.path.getmtime(file_path)
            with open(TIME_CACHE_FILE, "w", encoding="utf-8") as f:
                json.dump({"mtime": file_mtime, "data": time_data}, f)
        except Exception as e:
            print_warning(f"Could not save time cache: {e}")
    return time_data

# ===== DOCKER AND SYSTEM FUNCTIONS =====
def check_docker_engine():
    try:
        cmd = 'wsl --distribution ubuntu --user root -- bash -lic "docker info"'
        subprocess.check_output(cmd, shell=True, stderr=subprocess.STDOUT)
        return True
    except subprocess.CalledProcessError:
        return False

def start_docker_engine():
    if not check_docker_engine():
        print_warning("Docker Engine is not running in WSL.")

def dkill():
    cmds = [
        'docker stop $(docker ps -aq)',
        'docker rm $(docker ps -aq)',
        'docker rmi $(docker images -q)',
        'docker system prune -a --volumes --force',
        'docker network prune --force'
    ]
    for cmd in cmds:
        try:
            wsl_cmd = f'wsl --distribution ubuntu --user root -- bash -lic "{cmd}"'
            subprocess.call(wsl_cmd, shell=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        except Exception:
            pass

def perform_docker_login(password):
    try:
        docker_login_cmd = f"docker login -u michadockermisha -p {password}"
        login_cmd = f'wsl --distribution ubuntu --user root -- bash -lic "{docker_login_cmd}"'
        result = subprocess.run(login_cmd, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        return result.returncode == 0
    except Exception as e:
        print_error(f"Docker login error: {e}")
        return False

def get_docker_token(password):
    login_url = "https://hub.docker.com/v2/users/login/"
    login_data = {"username": "michadockermisha", "password": password}
    try:
        response = requests.post(login_url, json=login_data)
        if response.status_code == 200 and response.json().get("token"):
            return response.json().get("token")
    except Exception:
        pass
    return None

def delete_docker_tag(token, tag):
    username = "michadockermisha"
    repo = "backup"
    headers = {"Authorization": f"JWT {token}"}
    delete_url = f"https://hub.docker.com/v2/repositories/{username}/{repo}/tags/{tag}/"
    try:
        response = requests.delete(delete_url, headers=headers)
        return response.status_code == 204
    except Exception:
        return False

def fetch_tags():
    """Fetch tags from Docker Hub, using a local cache for speed."""
    import json, time, os
    now = time.time()
    # Try to load from cache
    if os.path.exists(TAGS_CACHE_FILE):
        try:
            with open(TAGS_CACHE_FILE, "r", encoding="utf-8") as f:
                cache = json.load(f)
            cache_time = cache.get("timestamp", 0)
            if now - cache_time < TAGS_CACHE_MAX_AGE and "tags" in cache:
                print_success(f"Loaded {len(cache['tags'])} tags from cache.")
                return cache["tags"]
        except Exception as e:
            print_warning(f"Could not load tag cache: {e}")
    # If cache is missing or expired, fetch from Docker Hub
    print_info("Fetching tags from Docker Hub...")
    url = "https://hub.docker.com/v2/repositories/michadockermisha/backup/tags?page_size=100"
    tag_list = []
    while url:
        try:
            response = requests.get(url)
            data = response.json()
            for item in data.get("results", []):
                tag_list.append({
                    "name": item["name"],
                    "full_size": item.get("full_size", 0),
                    "last_updated": item.get("last_updated", "")
                })
            url = data.get("next")
        except Exception as e:
            print_error(f"Error fetching tags: {e}")
            break
    tag_list.sort(key=lambda x: x["name"].lower())
    print_success(f"Fetched {len(tag_list)} tags from Docker Hub")
    # Save to cache
    try:
        with open(TAGS_CACHE_FILE, "w", encoding="utf-8") as f:
            json.dump({"timestamp": now, "tags": tag_list}, f)
    except Exception as e:
        print_warning(f"Could not save tag cache: {e}")
    return tag_list

def run_docker_command(tag, destination_path, progress_callback=None):
    """Run a Docker command to sync the game data to the specified destination path."""
    try:
        os.makedirs(destination_path, exist_ok=True)
        
        cleanup_cmd = f'wsl --distribution ubuntu --user root -- bash -lic "docker stop {tag} 2>/dev/null; docker rm {tag} 2>/dev/null"'
        subprocess.run(cleanup_cmd, shell=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        
        docker_cmd = (
            f"docker run -d --pull=always --rm --cpus=8 --memory=32g --memory-swap=40g "
            f"-v '{destination_path}':/games -e DISPLAY=\\$DISPLAY -v /tmp/.X11-unix:/tmp/.X11-unix "
            f"--name '{tag}' michadockermisha/backup:'{tag}' "
            f"sh -c 'apk add --no-cache rsync pigz && mkdir -p /games/{tag} && "
            f"rsync -aPW --omit-dir-times --no-perms --no-owner --no-group --no-times --no-acls --no-xattrs --ignore-errors --size-only --inplace --no-i-r --no-specials --no-devices --no-sparse --no-links --no-hard-links --no-blocking-io --bwlimit=0 /home/ /games/{tag}'"
        )
        
        run_cmd = f'wsl --distribution ubuntu --user root -- bash -lic "{docker_cmd}"'
        
        process = subprocess.Popen(
            run_cmd, shell=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
            universal_newlines=True, bufsize=1
        )
        
        return process
        
    except Exception as e:
        print_error(f"Error in run_docker_command: {e}")
        return None

def YOUR_CLIENT_SECRET_HERE(command, shell=True):
    """Execute a command and display the output in real-time in the terminal."""
    print_info(f"Executing command: {command}")
    
    process = subprocess.Popen(
        command, shell=shell, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
        text=True, bufsize=0, universal_newlines=True
    )
    
    if process.stdout is not None:
        for line in iter(process.stdout.readline, ''):
            print(line, end='')
            sys.stdout.flush()
        process.stdout.close()
    return process.wait()

def clear_terminal():
    clear_screen()

def fetch_game_time(alias):
    """Fetch game completion time from HowLongToBeat"""
    normalized = normalize_game_title(alias)
    try:
        if HowLongToBeat:
            results = HowLongToBeat().search(normalized)
            if results:
                main_time = getattr(results[0], 'gameplay_main', None) or getattr(results[0], 'main_story', None)
                if main_time:
                    return (alias, f"{main_time} hours")
                extra_time = getattr(results[0], 'gameplay_main_extra', None) or getattr(results[0], 'main_extra', None)
                if extra_time:
                    return (alias, f"{extra_time} hours")
    except Exception as e:
        print_error(f"Error searching HowLongToBeat for '{normalized}': {e}")
    
    time_val = GAME_TIMES_DATA.get(alias.lower(), "N/A")
    return (alias, time_val)

# ===== ENHANCED TERMINAL APP CLASS =====
class YOUR_CLIENT_SECRET_HERE:
    def __init__(self, login_password, is_admin, username):
        self.login_password = login_password
        self.is_admin = is_admin
        self.username = username
        self.is_guest = False  # Will be set by main entrypoint
        self.docker_token = None
        self.all_tags = []
        
        # Background sync tracking
        self.background_syncs = {}  # Track running sync processes
        self.sync_logs = {}  # Store logs for each sync
        
        print_info("Loading all JSON data in parallel...")
        with ThreadPoolExecutor(max_workers=6) as executor:
            f_settings = executor.submit(load_settings)
            f_tabs = executor.submit(load_tabs_config)
            f_categories = executor.submit(load_game_categories)
            f_prefs = executor.submit(load_user_preferences)
            f_history = executor.submit(load_sync_history)
            f_metadata = executor.submit(load_game_metadata)
            self.persistent_settings = f_settings.result()
            self.tabs_config = f_tabs.result()
            self.game_categories = f_categories.result()
            self.user_preferences = f_prefs.result()
            self.sync_history = f_history.result()
            self.game_metadata = f_metadata.result()
        
        self.time_data = load_time_data(os.path.join(os.path.dirname(__file__), "time.txt"))
        self.game_times_cache = {}
        self.selected_tag_names = set()
        self.current_tab = "all"
        self.running = True
        
        # Initialize
        self.initialize_app()
        self.tab_lookup = {tab['id']: tab for tab in self.tabs_config}

    def initialize_app(self):
        """Initialize the application"""
        print_header("MICHAEL FEDRO'S BACKUP & RESTORE TOOL - ENHANCED EDITION")
        print_info("Initializing enhanced application...")
        # Start Docker engine in background
        threading.Thread(target=self._check_docker_engine_bg, daemon=True).start()
        self.refresh_tags()
        self.refresh_time_data()
        self.add_active_user()
        self.start_banned_monitoring()
        threading.Thread(target=self._post_init_background, daemon=True).start()
        print_success("Enhanced application initialized successfully!")

    def _check_docker_engine_bg(self):
        if not check_docker_engine():
            print_warning("Docker Engine is not running in WSL.")

    def _post_init_background(self):
        try:
            self.show_time_data_stats()
            self.auto_save_all_data()
        except Exception as e:
            print_warning(f"Background stats/auto-save error: {e}")

    def show_time_data_stats(self):
        """Show statistics about time data loading"""
        total_tags = len(self.all_tags)
        tags_with_time = sum(1 for tag in self.all_tags if tag.get('approx_time', 'N/A') != 'N/A')
        tags_without_time = total_tags - tags_with_time
        
        print_info(f"Time data statistics:")
        print_info(f"  Total tags: {total_tags}")
        print_info(f"  Tags with time data: {tags_with_time}")
        print_info(f"  Tags without time data: {tags_without_time}")
        print_info(f"  Time data coverage: {(tags_with_time/total_tags*100):.1f}%" if total_tags > 0 else "0%")
        
        # Show some examples of tags with and without time data
        if tags_with_time > 0:
            examples_with_time = [tag['docker_name'] for tag in self.all_tags if tag.get('approx_time', 'N/A') != 'N/A'][:5]
            print_info(f"  Examples with time: {', '.join(examples_with_time)}")
        
        if tags_without_time > 0:
            examples_without_time = [tag['docker_name'] for tag in self.all_tags if tag.get('approx_time', 'N/A') == 'N/A'][:5]
            print_info(f"  Examples without time: {', '.join(examples_without_time)}")

    def auto_save_all_data(self):
        """Auto-save all data to JSON files"""
        if self.user_preferences.get('auto_save', True):
            print_info("Auto-saving all data...")
            save_settings(self.persistent_settings)
            save_tabs_config(self.tabs_config)
            save_game_categories(self.game_categories)
            save_user_preferences(self.user_preferences)
            save_sync_history(self.sync_history)
            save_game_metadata(self.game_metadata)
            print_success("All data auto-saved!")

    def refresh_tags(self):
        """Refresh tags from Docker Hub"""
        self.all_tags = fetch_tags()
        for tag in self.all_tags:
            tag["docker_name"] = tag["name"]
            tag["alias"] = self.persistent_settings.get(tag["docker_name"], {}).get("alias", tag["docker_name"])
            stored_cat = self.persistent_settings.get(tag["docker_name"], {}).get("category", "all")
            # Ensure the category exists in tabs_config, otherwise default to "all"
            valid_categories = [tab["id"] for tab in self.tabs_config]
            tag["category"] = stored_cat if stored_cat in valid_categories else "all"
            
            # Try multiple ways to match time data from time.txt
            docker_name_lower = tag["docker_name"].lower()
            alias_lower = tag["alias"].lower()
            
            # Try to find time data using different keys
            time_val = None
            if docker_name_lower in self.time_data:
                time_val = self.time_data[docker_name_lower]
            elif alias_lower in self.time_data:
                time_val = self.time_data[alias_lower]
            elif tag["docker_name"] in self.time_data:
                time_val = self.time_data[tag["docker_name"]]
            elif tag["alias"] in self.time_data:
                time_val = self.time_data[tag["alias"]]
            else:
                time_val = "N/A"
            
            tag["approx_time"] = time_val
        
        # Update game metadata
        self.game_metadata["last_updated"] = datetime.now().isoformat()
        self.game_metadata["total_games"] = len(self.all_tags)
        
        # Auto-save after refresh
        self.auto_save_all_data()

    def add_active_user(self):
        """Add user to active users list"""
        users = load_active_users()
        users[self.username] = {"login_time": time.time()}
        save_active_users(users)

    def remove_active_user(self):
        """Remove user from active users list"""
        users = load_active_users()
        if self.username in users:
            del users[self.username]
            save_active_users(users)

    def start_banned_monitoring(self):
        """Start monitoring for banned users"""
        def check_banned():
            while self.running:
                banned = load_banned_users()
                if self.username in banned:
                    print_error("You have been kicked from the app by the admin.")
                    self.running = False
                    return
                time.sleep(3)
        
        thread = threading.Thread(target=check_banned, daemon=True)
        thread.start()

    def get_tab_name(self, tab_id):
        return self.tab_lookup.get(tab_id, {}).get('name', 'Unknown Tab')

    def get_tab_color(self, tab_id):
        return self.tab_lookup.get(tab_id, {}).get('color', Fore.WHITE)

    def filter_games_by_tab(self, tab_id):
        """Filter games by tab category"""
        if tab_id == "all":
            # Exclude games from specific tabs in the 'All' tab
            excluded_categories = ["mybackup", "not_for_me", "localcoop", "oporationsystems", "bulkgames", "music"]
            return [tag for tag in self.all_tags if tag.get("category", "all") not in excluded_categories]
        else:
            return [tag for tag in self.all_tags if tag.get("category", "all") == tab_id]

    def show_tab_buttons(self):
        """Display all tabs as buttons - one tab per line"""
        print(f"\n{Fore.CYAN}{Style.BRIGHT}╔══════════════════════════════════════════════════════════════════════════════╗")
        print(f"{Fore.CYAN}{Style.BRIGHT}║                              🎮 TAB NAVIGATION 🎮                              ║")
        print(f"{Fore.CYAN}{Style.BRIGHT}╚══════════════════════════════════════════════════════════════════════════════╝")
        
        # Display each tab on its own line
        for i, tab in enumerate(self.tabs_config, 1):
            games_count = len(self.filter_games_by_tab(tab['id']))
            is_active = tab['id'] == self.current_tab
            tab_color = tab.get('color', Fore.WHITE)
            
            # Build the tab display
            tab_display = f"╔═══[{i:2d}]═══╗"
            if is_active:
                tab_display += f"  ► {tab['name']:<20} ◄  ║{games_count:3d}║"
            else:
                tab_display += f"  {tab['name']:<20}  ║{games_count:3d}║"
            
            # Apply color and print
            print(f"{tab_color}{tab_display}{Style.RESET_ALL}")

    def YOUR_CLIENT_SECRET_HERE(self):
        """Run all selected games with Docker commands in background"""
        if not self.selected_tag_names:
            print_warning("No games selected. Please select games first.")
            pause()
            return
        
        clear_screen()
        print_header("🚀 RUN SELECTED GAMES (BACKGROUND)")
        
        selected_games = [game for game in self.all_tags if game['docker_name'] in self.selected_tag_names]
        
        print(f"{Fore.CYAN}Selected games ({len(selected_games)}):")
        total_size = 0
        for i, game in enumerate(selected_games, 1):
            size = game.get('full_size', 0)
            total_size += size
            print(f"{Fore.YELLOW}[{i:3d}]{Fore.WHITE} {game['alias']:<30} {Fore.CYAN}({format_size(size)})")
        
        print(f"\n{Fore.MAGENTA}Total size: {format_size(total_size)}")
        print(f"{Fore.MAGENTA}Estimated time: {len(selected_games) * 5} - {len(selected_games) * 15} minutes")
        
        # Get destination path from user preferences
        sync_path = self.user_preferences.get('sync_destination', DEFAULT_DESTINATION)
        print(f"\n{Fore.BLUE}📁 Using configured sync path: {sync_path}")
        
        # Ask if user wants to change the path
        print(f"\n{Fore.YELLOW}Destination Path Options:")
        print_menu_option("1", f"Use configured path: {sync_path}")
        print_menu_option("2", "Change sync path")
        print_menu_option("3", "Use F: Drive (F:\\Games)")
        print_menu_option("B", "Back")
        
        path_choice = get_user_input(f"\n{Fore.YELLOW}Choose destination: ").strip()
        
        if path_choice.upper() == "B":
            return
        elif path_choice == "1":
            destination = sync_path
        elif path_choice == "2":
            destination = get_user_input("Enter custom destination path: ").strip()
            if not destination:
                print_warning("No path entered, using configured path.")
                destination = sync_path
            else:
                # Update user preferences with new path
                self.user_preferences['sync_destination'] = destination
                save_user_preferences(self.user_preferences)
                print_success(f"Sync path updated to: {destination}")
        elif path_choice == "3":
            destination = "F:\\Games"
            # Update user preferences with F: drive
            self.user_preferences['sync_destination'] = destination
            save_user_preferences(self.user_preferences)
            print_success("Sync path set to F: Drive")
        else:
            print_warning("Invalid choice, using configured path.")
            destination = sync_path
        
        # Convert Windows path to WSL path if needed
        if destination.startswith('F:') or destination.startswith('f:'):
            wsl_path = destination.replace('\\', '/').replace('F:', '/mnt/f').replace('f:', '/mnt/f')
        elif destination.startswith('C:') or destination.startswith('c:'):
            wsl_path = destination.replace('\\', '/').replace('C:', '/mnt/c').replace('c:', '/mnt/c')
        else:
            wsl_path = destination.replace('\\', '/')
        
        print(f"\n{Fore.CYAN}Destination: {destination}")
        print(f"{Fore.CYAN}WSL Path: {wsl_path}")
        
        if not confirm_action(f"Run Docker sync for {len(selected_games)} games to {destination} in BACKGROUND?"):
            return
        
        print_header("🚀 STARTING BACKGROUND SYNC OPERATIONS")
        print(f"{Fore.GREEN}✅ Sync operations will run in background!")
        print(f"{Fore.YELLOW}⚠️  You can return to main menu and monitor progress with [Y] Sync Operations")
        print(f"{Fore.CYAN}📁 Destination: {destination}")
        print(f"{Fore.MAGENTA}⏱️  Total games to sync: {len(selected_games)}")
        
        # Start background sync for each selected game
        sync_id = f"sync_{int(time.time())}"
        self.background_syncs[sync_id] = {
            "games": selected_games,
            "destination": destination,
            "wsl_path": wsl_path,
            "start_time": datetime.now(),
            "status": "running",
            "completed": 0,
            "failed": 0,
            "logs": []
        }
        
        # Start background thread for each game
        for i, game in enumerate(selected_games):
            thread = threading.Thread(
                target=self.YOUR_CLIENT_SECRET_HERE,
                args=(sync_id, game, wsl_path, i + 1, len(selected_games)),
                daemon=True
            )
            thread.start()
        
        # Remove games from selection since they're now running in background
        for game in selected_games:
            self.selected_tag_names.discard(game['docker_name'])
        
        print(f"\n{Fore.GREEN}🎉 Background sync started! Sync ID: {sync_id}")
        print(f"{Fore.CYAN}Returning to main menu...")
        time.sleep(2)

    def YOUR_CLIENT_SECRET_HERE(self, sync_id, game, wsl_path, game_num, total_games):
        """Run a single game sync in background"""
        if sync_id not in self.background_syncs:
            return
        
        sync_info = self.background_syncs[sync_id]
        log_entry = {
            "timestamp": datetime.now().isoformat(),
            "game": game['alias'],
            "docker_name": game['docker_name'],
            "status": "starting",
            "message": f"Starting sync {game_num}/{total_games}: {game['alias']}"
        }
        sync_info["logs"].append(log_entry)
        
        try:
            import time as _time
            start_time = _time.time()
            # Create the full Docker command
            docker_command = (
                f"wsl -d Ubuntu docker run --pull=always --rm --cpus=8 --memory=32g --memory-swap=40g "
                f"-v {wsl_path}:/games "
                f"-e DISPLAY=$DISPLAY "
                f"-v /tmp/.X11-unix:/tmp/.X11-unix "
                f"--name {game['docker_name']} "
                f"michadockermisha/backup:{game['docker_name']} "
                f"sh -c \"apk add --no-cache rsync pigz && rsync -aPW --omit-dir-times --no-perms --no-owner --no-group --no-times --no-acls --no-xattrs --ignore-errors --size-only --inplace --no-i-r --no-specials --no-devices --no-sparse --no-links --no-hard-links --no-blocking-io --bwlimit=0 /home /games && cd /games && mv home {game['docker_name']} && exit\""
            )
            
            log_entry = {
                "timestamp": datetime.now().isoformat(),
                "game": game['alias'],
                "docker_name": game['docker_name'],
                "status": "running",
                "message": f"Executing Docker command for {game['alias']}"
            }
            sync_info["logs"].append(log_entry)
            
            # Run the command
            process = subprocess.Popen(
                docker_command, shell=True, stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT, bufsize=1, universal_newlines=True
            )
            
            # Capture output in real-time
            output_lines = []
            if process.stdout is not None:
                for line in iter(process.stdout.readline, ''):
                    output_lines.append(line.strip())
                    # Keep only last 50 lines to avoid memory issues
                    if len(output_lines) > 50:
                        output_lines = output_lines[-50:]
            process.wait()
            elapsed = _time.time() - start_time
            elapsed_min = elapsed / 60
            if process.returncode == 0:
                log_entry = {
                    "timestamp": datetime.now().isoformat(),
                    "game": game['alias'],
                    "docker_name": game['docker_name'],
                    "status": "completed",
                    "message": f"✅ Successfully synced {game['alias']} (⏱️ {elapsed_min:.1f} min)",
                    "output": output_lines[-10:] if output_lines else []  # Keep last 10 lines
                }
                sync_info["completed"] += 1
            else:
                log_entry = {
                    "timestamp": datetime.now().isoformat(),
                    "game": game['alias'],
                    "docker_name": game['docker_name'],
                    "status": "failed",
                    "message": f"❌ Failed to sync {game['alias']} (Exit code: {process.returncode}) (⏱️ {elapsed_min:.1f} min)",
                    "output": output_lines[-10:] if output_lines else []
                }
                sync_info["failed"] += 1
            
            sync_info["logs"].append(log_entry)
            
        except Exception as e:
            log_entry = {
                "timestamp": datetime.now().isoformat(),
                "game": game['alias'],
                "docker_name": game['docker_name'],
                "status": "error",
                "message": f"❌ Error syncing {game['alias']}: {e}",
                "output": []
            }
            sync_info["failed"] += 1
            sync_info["logs"].append(log_entry)
        
        # Cleanup any running containers
        try:
            cleanup_cmd = f'wsl -d Ubuntu docker rm -f {game["docker_name"]} 2>/dev/null'
            subprocess.run(cleanup_cmd, shell=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        except:
            pass
        
        # Check if all games are done
        if sync_info["completed"] + sync_info["failed"] == total_games:
            sync_info["status"] = "completed"
            sync_info["end_time"] = datetime.now()
            
            # Record sync history
            sync_record = {
                "timestamp": datetime.now().isoformat(),
                "user": self.username,
                "destination": sync_info["destination"],
                "total_games": total_games,
                "successful_syncs": sync_info["completed"],
                "failed_syncs": sync_info["failed"],
                "sync_id": sync_id,
                "background": True
            }
            
            self.sync_history["syncs"].append(sync_record)
            self.sync_history["statistics"]["total_syncs"] += 1
            self.sync_history["statistics"]["successful_syncs"] += sync_info["completed"]
            self.sync_history["statistics"]["failed_syncs"] += sync_info["failed"]
            
            # Auto-save sync history
            save_sync_history(self.sync_history)

    def show_enhanced_main_menu(self):
        """Show the enhanced main menu with tab buttons"""
        while self.running:
            clear_screen()
            print_header("MICHAEL FEDRO'S BACKUP & RESTORE TOOL - ENHANCED EDITION")
            
            # Show user status
            if self.is_guest:
                print(f"{Fore.YELLOW}Logged in as: {self.username} (Guest Mode - Docker sync disabled)")
            else:
                print(f"{Fore.GREEN}Logged in as: {self.username} {'(Admin)' if self.is_admin else '(User)'}")
            
            print(f"{Fore.CYAN}Current tab: {self.get_tab_name(self.current_tab)}")
            print(f"{Fore.YELLOW}Total games: {len(self.all_tags)} | Current tab games: {len(self.filter_games_by_tab(self.current_tab))}")
            if self.selected_tag_names:
                print(f"{Fore.MAGENTA}Selected games: {len(self.selected_tag_names)}")
            
            # Show background sync status
            running_syncs = [sync_id for sync_id, sync_info in self.background_syncs.items() if sync_info["status"] == "running"]
            if running_syncs:
                print(f"{Fore.GREEN}🔄 Background syncs running: {len(running_syncs)}")
            
            # Show configured sync path
            sync_path = self.user_preferences.get('sync_destination', DEFAULT_DESTINATION)
            print(f"{Fore.BLUE}📁 Sync Path: {sync_path}")
            
            # Show tab buttons
            self.show_tab_buttons()
            
            print(f"\n{Fore.WHITE}{Style.BRIGHT}MAIN ACTIONS:")
            print_menu_option("G", "Browse Current Tab Games (Grid View)", Fore.GREEN)
            
            print_menu_option("S", "Search Games")
            print_menu_option("O", "Sort Games")
            print_menu_option("TM", "⏱️ Time Menu", Fore.MAGENTA)
            
            if self.is_guest:
                print_menu_option("Y", "Sync Operations (Disabled in Guest Mode)", Fore.RED)
            else:
                print_menu_option("Y", "Sync Operations")
            
            print(f"\n{Fore.CYAN}{Style.BRIGHT}TAB MANAGEMENT:")
            print_menu_option("MT", "📦 Move Tags to Tab", Fore.MAGENTA)
            print_menu_option("NT", "➕ Create New Tab", Fore.GREEN)
            print_menu_option("ET", "✏️ Edit Tab", Fore.YELLOW)
            print_menu_option("DT", "🗑️ Delete Tab", Fore.RED)
            print_menu_option("VT", "📊 View All Tabs", Fore.CYAN)
            print_menu_option("BM", "📦 Bulk Move to Tab", Fore.MAGENTA)
            print_menu_option("UT", "🔍 Show Uncategorized Tags", Fore.RED)
            
            if self.is_admin and not self.is_guest:
                print(f"\n{Fore.RED}{Style.BRIGHT}ADMIN MENU:")
                print_menu_option("X", "Tag Management", Fore.RED)
                print_menu_option("B", "Tab Management", Fore.RED)
                print_menu_option("C", "User Management", Fore.RED)
                print_menu_option("D", "Custom Commands (myLiners)", Fore.RED)
                print_menu_option("E", "Export/Import", Fore.RED)
            
            print(f"\n{Fore.MAGENTA}{Style.BRIGHT}SYSTEM:")
            print_menu_option("P", "📁 Configure Sync Path", Fore.CYAN)
            print_menu_option("9", "Clear Terminal")
            print_menu_option("J", "JSON Data Status", Fore.CYAN)
            print_menu_option("DC", "🔌 Disconnect User", Fore.RED)
            print_menu_option("0", "Logout")
            print_menu_option("Q", "Quit", Fore.RED)
            
            choice = get_user_input(f"\n{Fore.YELLOW}Enter your choice (number for tab, letter for action): ").upper().strip()
            
            # Check if input is a tag name for quick syncing
            if handle_tag_name_input(choice, self):
                continue
            
            # Handle tab selection (1-18 for tabs)
            if choice.isdigit():
                tab_index = int(choice) - 1
                if 0 <= tab_index < len(self.tabs_config):
                    self.current_tab = self.tabs_config[tab_index]['id']
                    print_success(f"Switched to {self.tabs_config[tab_index]['name']} tab")
                    
                    # Show games in the selected tab
                    self.YOUR_CLIENT_SECRET_HERE()
                else:
                    print_error("Invalid tab number.")
                    pause()
            elif choice == "G":
                self.YOUR_CLIENT_SECRET_HERE()
            elif choice == "S":
                self.search_games()
            elif choice == "O":
                self.sort_games()
            elif choice == "TM":
                self.time_menu()
            elif choice == "Y":
                if self.is_guest:
                    print_warning("Sync operations are disabled in Guest Mode. Please login with credentials to sync games.")
                    pause()
                else:
                    self.sync_operations()
            elif choice == "MT":
                self.move_tags_to_tab()
            elif choice == "NT":
                self.create_new_tab()
            elif choice == "ET":
                self.edit_tab()
            elif choice == "DT":
                self.delete_tab()
            elif choice == "VT":
                self.view_all_tabs()
            elif choice == "BM":
                self.bulk_move_to_tab()
            elif choice == "UT":
                self.show_uncategorized_tags()
            elif choice == "P":
                self.configure_sync_path()
            elif choice == "X" and self.is_admin and not self.is_guest:
                self.tag_management()
            elif choice == "B" and self.is_admin and not self.is_guest:
                self.tab_management()
            elif choice == "C" and self.is_admin and not self.is_guest:
                self.user_management()
            elif choice == "D" and self.is_admin and not self.is_guest:
                self.custom_commands()
            elif choice == "E" and self.is_admin and not self.is_guest:
                self.export_import()
            elif choice == "9":
                clear_screen()
                print_success("Terminal cleared!")
                pause()
            elif choice == "J":
                self.show_json_data_status()
            elif choice == "DC":
                self.disconnect_user()
            elif choice == "0":
                self.logout()
                break
            elif choice == "Q":
                sys.exit(0)
            else:
                print_error("Invalid choice. Please try again.")
                pause()

    def time_menu(self):
        """Show the time menu with time-related options"""
        while True:
            clear_screen()
            print_header("⏱️ TIME MENU")
            
            print_menu_option("1", "Time Statistics", Fore.MAGENTA)
            print_menu_option("2", "Time Data Debug", Fore.CYAN)
            print_menu_option("3", "Refresh Time Data", Fore.BLUE)
            print_menu_option("B", "Back to Main Menu")
            
            choice = get_user_input(f"\n{Fore.YELLOW}Enter your choice: ").upper().strip()
            
            if choice == "1":
                self.show_time_statistics()
            elif choice == "2":
                self.show_missing_time_data()
            elif choice == "3":
                self.refresh_time_data()
                print_success("Time data refreshed.")
                pause()
            elif choice.upper() == "B":
                break
            else:
                print_error("Invalid choice.")
                pause()

    def YOUR_CLIENT_SECRET_HERE(self):
        """Browse games in current tab with grid view"""
        while True:
            clear_screen()
            
            # Get games in current tab
            tab_games = self.filter_games_by_tab(self.current_tab)
            
            if not tab_games:
                print_warning(f"No games in {self.get_tab_name(self.current_tab)} tab.")
                pause()
                break
            
            result = display_games_in_grid(
                tab_games, 
                f"{self.get_tab_name(self.current_tab)} Tab - {len(tab_games)} Games",
                games_per_row=3,  # Reduced from 5 to accommodate full names
                show_selection=True,
                selected_tags=self.selected_tag_names,
                app_instance=self
            )
            
            if result is None:
                break
            elif isinstance(result, tuple):
                action, game = result
                if action == "toggle" and game:
                    self.toggle_game_selection(game)
                    print_success(f"Toggled selection for {game['alias']}")
                    time.sleep(0.5)
                elif action == "run_selected":
                    if self.is_guest:
                        print_warning("Docker sync is disabled in Guest Mode. Please login with credentials to sync games.")
                        pause()
                    elif self.selected_tag_names:
                        self.run_selected_games()
                    else:
                        print_warning("No games selected. Select games first.")
                        pause()
                elif action == "add_game":
                    self.add_game_to_current_tab()
                elif action == "select_all":
                    for g in tab_games:
                        self.selected_tag_names.add(g['docker_name'])
                    print_success(f"Selected all {len(tab_games)} games in this tab.")
                    time.sleep(0.5)
                elif action == "deselect_all":
                    for g in tab_games:
                        self.selected_tag_names.discard(g['docker_name'])
                    print_success(f"Deselected all games in this tab.")
                    time.sleep(0.5)
            else:
                # Single game selected, show details
                self.show_game_details(result)

    def add_game_to_current_tab(self):
        """Add a game to the current tab"""
        clear_screen()
        print_header(f"ADD GAME TO {self.get_tab_name(self.current_tab).upper()} TAB")
        
        game_name = get_user_input("Enter game name/alias: ").strip()
        if not game_name:
            print_warning("Game name cannot be empty.")
            pause()
            return
        
        docker_name = get_user_input("Enter Docker tag name (or press Enter to use alias): ").strip()
        if not docker_name:
            docker_name = sanitize_filename(game_name)
        
        # Create a new game entry
        new_game = {
            "name": docker_name,
            "docker_name": docker_name,
            "alias": game_name,
            "category": self.current_tab,
            "full_size": 0,  # Unknown size
            "last_updated": datetime.now().isoformat(),
            "approx_time": "N/A"
        }
        
        # Show preview
        print(f"\n{Fore.CYAN}Game Preview:")
        print(f"  Name: {Fore.WHITE}{game_name}")
        print(f"  Docker Tag: {Fore.WHITE}{docker_name}")
        print(f"  Category: {Fore.WHITE}{self.get_tab_name(self.current_tab)}")
        print(f"  Size: {Fore.WHITE}Unknown (will be fetched if exists)")
        
        if confirm_action("Add this game?"):
            # Add to all_tags list
            self.all_tags.append(new_game)
            
            # Save to persistent settings
            persistent = self.persistent_settings.get(docker_name, {})
            persistent['alias'] = game_name
            persistent['category'] = self.current_tab
            self.persistent_settings[docker_name] = persistent
            
            # Update game metadata
            self.game_metadata["recent_additions"].append({
                "docker_name": docker_name,
                "alias": game_name,
                "category": self.current_tab,
                "added_at": datetime.now().isoformat()
            })
            
            # Auto-save all data
            self.auto_save_all_data()
            
            print_success(f"Added '{game_name}' to {self.get_tab_name(self.current_tab)} tab")
            print_info("Note: The game will sync only if the Docker image exists on Docker Hub")
        
        pause()

    def run_selected_games(self):
        """Run all selected games with Docker commands"""
        if not self.selected_tag_names:
            print_warning("No games selected. Please select games first.")
            pause()
            return
        
        clear_screen()
        print_header("🚀 RUN SELECTED GAMES")
        
        selected_games = [game for game in self.all_tags if game['docker_name'] in self.selected_tag_names]
        
        print(f"{Fore.CYAN}Selected games ({len(selected_games)}):")
        total_size = 0
        for i, game in enumerate(selected_games, 1):
            size = game.get('full_size', 0)
            total_size += size
            print(f"{Fore.YELLOW}[{i:3d}]{Fore.WHITE} {game['alias']:<30} {Fore.CYAN}({format_size(size)})")
        
        print(f"\n{Fore.MAGENTA}Total size: {format_size(total_size)}")
        print(f"{Fore.MAGENTA}Estimated time: {len(selected_games) * 5} - {len(selected_games) * 15} minutes")
        
        # Get destination path from user preferences
        sync_path = self.user_preferences.get('sync_destination', DEFAULT_DESTINATION)
        print(f"\n{Fore.BLUE}📁 Using configured sync path: {sync_path}")
        
        # Ask if user wants to change the path
        print(f"\n{Fore.YELLOW}Destination Path Options:")
        print_menu_option("1", f"Use configured path: {sync_path}")
        print_menu_option("2", "Change sync path")
        print_menu_option("3", "Use F: Drive (F:\\Games)")
        print_menu_option("B", "Back")
        
        path_choice = get_user_input(f"\n{Fore.YELLOW}Choose destination: ").strip()
        
        if path_choice.upper() == "B":
            return
        elif path_choice == "1":
            destination = sync_path
        elif path_choice == "2":
            destination = get_user_input("Enter custom destination path: ").strip()
            if not destination:
                print_warning("No path entered, using configured path.")
                destination = sync_path
            else:
                # Update user preferences with new path
                self.user_preferences['sync_destination'] = destination
                save_user_preferences(self.user_preferences)
                print_success(f"Sync path updated to: {destination}")
        elif path_choice == "3":
            destination = "F:\\Games"
            # Update user preferences with F: drive
            self.user_preferences['sync_destination'] = destination
            save_user_preferences(self.user_preferences)
            print_success("Sync path set to F: Drive")
        else:
            print_warning("Invalid choice, using configured path.")
            destination = sync_path
        
        # Convert Windows path to WSL path if needed
        if destination.startswith('F:') or destination.startswith('f:'):
            wsl_path = destination.replace('\\', '/').replace('F:', '/mnt/f').replace('f:', '/mnt/f')
        elif destination.startswith('C:') or destination.startswith('c:'):
            wsl_path = destination.replace('\\', '/').replace('C:', '/mnt/c').replace('c:', '/mnt/c')
        else:
            wsl_path = destination.replace('\\', '/')
        
        print(f"\n{Fore.CYAN}Destination: {destination}")
        print(f"{Fore.CYAN}WSL Path: {wsl_path}")
        
        if not confirm_action(f"Run Docker sync for {len(selected_games)} games to {destination}?"):
            return
        
        print_header("EXECUTING DOCKER SYNC OPERATIONS")
        
        # Run sync for each selected game
        successful_syncs = 0
        failed_syncs = 0
        
        for i, game in enumerate(selected_games, 1):
            print(f"\n{Fore.YELLOW}{'='*60}")
            print(f"{Fore.CYAN}Syncing {i}/{len(selected_games)}: {game['alias']}")
            print(f"{Fore.CYAN}Docker Tag: {game['docker_name']}")
            print(f"{Fore.CYAN}Size: {format_size(game.get('full_size', 0))}")
            print(f"{Fore.YELLOW}{'='*60}")
            
            try:
                import time as _time
                start_time = _time.time()
                # Create the full Docker command
                docker_command = (
                    f"wsl -d Ubuntu docker run --pull=always --rm --cpus=8 --memory=32g --memory-swap=40g "
                    f"-v {wsl_path}:/games "
                    f"-e DISPLAY=$DISPLAY "
                    f"-v /tmp/.X11-unix:/tmp/.X11-unix "
                    f"--name {game['docker_name']} "
                    f"michadockermisha/backup:{game['docker_name']} "
                    f"sh -c \"apk add --no-cache rsync pigz && rsync -aPW --omit-dir-times --no-perms --no-owner --no-group --no-times --no-acls --no-xattrs --ignore-errors --size-only --inplace --no-i-r --no-specials --no-devices --no-sparse --no-links --no-hard-links --no-blocking-io --bwlimit=0 /home /games && cd /games && mv home {game['docker_name']} && exit\""
                )
                
                print(f"\n{Fore.GREEN}Executing: {docker_command[:100]}...")
                
                # Run the command with real-time output
                process = subprocess.Popen(
                    docker_command, shell=True, stdout=subprocess.PIPE,
                    stderr=subprocess.STDOUT, bufsize=1, universal_newlines=True
                )
                
                # Display output in real-time
                if process.stdout is not None:
                    for line in iter(process.stdout.readline, ''):
                        print(line, end='', flush=True)
                process.wait()
                elapsed = _time.time() - start_time
                elapsed_min = elapsed / 60
                if process.returncode == 0:
                    print(f"\n{Fore.GREEN}✅ Successfully synced {game['alias']}")
                    print(f"{Fore.CYAN}⏱️  Sync time: {elapsed_min:.1f} minutes")
                    successful_syncs += 1
                    # Remove from selection after successful sync
                    self.selected_tag_names.discard(game['docker_name'])
                else:
                    print(f"\n{Fore.RED}❌ Failed to sync {game['alias']} (Exit code: {process.returncode})")
                    print(f"{Fore.CYAN}⏱️  Sync time: {elapsed_min:.1f} minutes")
                    failed_syncs += 1
                    
            except Exception as e:
                print(f"\n{Fore.RED}❌ Error syncing {game['alias']}: {e}")
                failed_syncs += 1
            
            # Cleanup any running containers
            try:
                cleanup_cmd = f'wsl -d Ubuntu docker rm -f {game["docker_name"]} 2>/dev/null'
                subprocess.run(cleanup_cmd, shell=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            except:
                pass
        
        # Final summary
        print(f"\n{Fore.CYAN}{'='*60}")
        print_header("SYNC OPERATION COMPLETE")
        print(f"{Fore.GREEN}✅ Successful syncs: {successful_syncs}")
        print(f"{Fore.RED}❌ Failed syncs: {failed_syncs}")
        print(f"{Fore.CYAN}📁 Destination: {destination}")
        print(f"{Fore.MAGENTA}⏱️  Total games processed: {len(selected_games)}")
        
        # Record sync history
        sync_record = {
            "timestamp": datetime.now().isoformat(),
            "user": self.username,
            "destination": destination,
            "total_games": len(selected_games),
            "successful_syncs": successful_syncs,
            "failed_syncs": failed_syncs,
            "games_synced": [game['docker_name'] for game in selected_games if game['docker_name'] not in self.selected_tag_names],
            "games_failed": [game['docker_name'] for game in selected_games if game['docker_name'] in self.selected_tag_names]
        }
        
        self.sync_history["syncs"].append(sync_record)
        self.sync_history["statistics"]["total_syncs"] += 1
        self.sync_history["statistics"]["successful_syncs"] += successful_syncs
        self.sync_history["statistics"]["failed_syncs"] += failed_syncs
        
        # Auto-save sync history
        save_sync_history(self.sync_history)
        
        if successful_syncs > 0:
            print(f"\n{Fore.GREEN}🎉 Games are now available at: {destination}")
        
        if self.selected_tag_names:
            print(f"\n{Fore.YELLOW}⚠️  {len(self.selected_tag_names)} games remain selected (failed syncs)")
        else:
            print(f"\n{Fore.GREEN}✨ All selected games have been processed!")
        
        print(f"{Fore.CYAN}{'='*60}")
        pause()

    def toggle_game_selection(self, game):
        """Toggle game selection"""
        if game['docker_name'] in self.selected_tag_names:
            self.selected_tag_names.remove(game['docker_name'])
            return f"Removed {game['alias']} from selection"
        else:
            self.selected_tag_names.add(game['docker_name'])
            return f"Added {game['alias']} to selection"

    def show_game_details(self, game):
        """Show detailed information about a game"""
        clear_screen()
        print_header(f"GAME DETAILS: {game['alias']}")
        
        print(f"{Fore.CYAN}Docker Name: {Fore.WHITE}{game['docker_name']}")
        print(f"{Fore.CYAN}Alias: {Fore.WHITE}{game['alias']}")
        print(f"{Fore.CYAN}Size: {Fore.WHITE}{format_size(game['full_size'])}")
        print(f"{Fore.CYAN}Category: {Fore.WHITE}{self.get_tab_name(game.get('category', 'all'))}")
        
        # Enhanced completion time display
        completion_time = game.get('approx_time', 'N/A')
        if completion_time != 'N/A':
            print(f"{Fore.MAGENTA}⏱️  Completion Time: {Fore.WHITE}{completion_time}")
            
            # Add estimated sync time based on size
            size_gb = game.get('full_size', 0) / (1024**3) if game.get('full_size', 0) > 0 else 0
            if size_gb > 0:
                # Rough estimate: 1GB = ~2-3 minutes sync time
                estimated_sync_minutes = int(size_gb * 2.5)
                print(f"{Fore.YELLOW}🔄 Estimated Sync Time: {Fore.WHITE}~{estimated_sync_minutes} minutes")
        else:
            print(f"{Fore.MAGENTA}⏱️  Completion Time: {Fore.RED}Unknown")
        
        print(f"{Fore.CYAN}Last Updated: {Fore.WHITE}{game.get('last_updated', 'Unknown')}")
        
        is_selected = game['docker_name'] in self.selected_tag_names
        print(f"{Fore.CYAN}Selected: {Fore.GREEN if is_selected else Fore.RED}{'Yes' if is_selected else 'No'}")
        
        print(f"\n{Fore.WHITE}{Style.BRIGHT}ACTIONS:")
        print_menu_option("1", "Toggle Selection")
        if not self.is_guest:
            print_menu_option("2", "Sync This Game")
        else:
            print_menu_option("2", "Sync This Game (Disabled in Guest Mode)", Fore.RED)
        print_menu_option("3", "Change Alias" if self.is_admin else "View Game Info")
        print_menu_option("4", "Move to Tab" if self.is_admin else "Back")
        if self.is_admin and not self.is_guest:
            print_menu_option("5", "Delete Tag", Fore.RED)
            print_menu_option("B", "Back")
        else:
            print_menu_option("B", "Back")
        
        choice = get_user_input(f"\n{Fore.YELLOW}Enter your choice: ").upper().strip()
        
        if choice == "1":
            message = self.toggle_game_selection(game)
            print_success(message)
            pause()
            self.show_game_details(game)  # Refresh
        elif choice == "2":
            if self.is_guest:
                print_warning("Docker sync is disabled in Guest Mode. Please login with credentials to sync games.")
                pause()
            else:
                self.sync_single_game(game)
        elif choice == "3":
            if self.is_admin:
                self.change_game_alias(game)
            else:
                print_info(f"Game: {game['alias']} ({game['docker_name']})")
                pause()
        elif choice == "4":
            if self.is_admin:
                self.move_game_to_tab(game)
            else:
                return
        elif choice == "5" and self.is_admin and not self.is_guest:
            self.delete_game_tag(game)
        elif choice == "B":
            return
        else:
            print_error("Invalid choice.")
            pause()
            self.show_game_details(game)

    def sync_single_game(self, game):
        """Sync a single game"""
        print_header(f"SYNC GAME: {game['alias']}")
        
        # Get destination path
        destination = get_user_input("Enter destination path (or press Enter for default): ").strip()
        if not destination:
            destination = DEFAULT_DESTINATION
        
        # Convert Windows path to WSL path if needed
        if destination.startswith('F:') or destination.startswith('f:'):
            wsl_path = destination.replace('\\', '/').replace('F:', '/mnt/f').replace('f:', '/mnt/f')
        else:
            wsl_path = destination.replace('\\', '/')
        
        print_info(f"Destination: {destination}")
        print_info(f"WSL Path: {wsl_path}")
        
        if confirm_action(f"Sync {game['alias']} to {destination}?"):
            self.execute_sync_command(game['docker_name'], wsl_path)

    def execute_sync_command(self, docker_name, wsl_path):
        """Execute the actual sync command"""
        print_info(f"Starting sync for {docker_name}...")
        
        docker_command = (
            f"wsl -d Ubuntu docker run --pull=always --rm --cpus=8 --memory=32g --memory-swap=40g "
            f"-v {wsl_path}:/games "
            f"-e DISPLAY=$DISPLAY "
            f"-v /tmp/.X11-unix:/tmp/.X11-unix "
            f"--name {docker_name} "
            f"michadockermisha/backup:{docker_name} "
            f"sh -c \"apk add --no-cache rsync pigz && rsync -aPW --omit-dir-times --no-perms --no-owner --no-group --no-times --no-acls --no-xattrs --ignore-errors --size-only --inplace --no-i-r --no-specials --no-devices --no-sparse --no-links --no-hard-links --no-blocking-io --bwlimit=0 /home /games && cd /games && mv home {docker_name} && exit\""
        )
        
        print(f"\n{Fore.CYAN}Executing: {docker_command}\n")
        
        try:
            import time as _time
            start_time = _time.time()
            process = subprocess.Popen(
                docker_command, shell=True, stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT, bufsize=1, universal_newlines=True
            )
            
            if process.stdout is not None:
                for line in iter(process.stdout.readline, ''):
                    print(line, end='', flush=True)
            process.wait()
            elapsed = _time.time() - start_time
            elapsed_min = elapsed / 60
            print(f"\n{Fore.CYAN}{'=' * 50}")
            if process.returncode == 0:
                print_success("Sync completed successfully!")
                print(f"{Fore.CYAN}⏱️  Sync time: {elapsed_min:.1f} minutes")
            else:
                print_error("Sync completed with errors.")
                print(f"{Fore.CYAN}⏱️  Sync time: {elapsed_min:.1f} minutes")
            print(f"{Fore.CYAN}{'=' * 50}")
            
        except Exception as e:
            print_error(f"Error during sync: {e}")
        
        pause()

    def search_games(self):
        """Search for games"""
        clear_screen()
        print_header("SEARCH GAMES")
        
        search_term = get_user_input("Enter search term: ").strip().lower()
        if not search_term:
            return
        
        # Search in all games, not just current tab
        matching_games = [game for game in self.all_tags if search_term in game['alias'].lower()]
        
        if not matching_games:
            print_warning(f"No games found matching '{search_term}'.")
            pause()
            return
        
        # Use grid display for search results
        while True:
            result = display_games_in_grid(
                matching_games, 
                f"Search Results: '{search_term}' ({len(matching_games)} matches)",
                games_per_row=3,  # Reduced to accommodate full names
                show_selection=True,
                selected_tags=self.selected_tag_names,
                app_instance=self
            )
            
            if result is None:
                break
            elif isinstance(result, tuple):
                action, game = result
                if action == "toggle" and game:
                    message = self.toggle_game_selection(game)
                    print_success(message)
                    time.sleep(0.5)
                elif action == "run_selected":
                    if self.selected_tag_names:
                        self.run_selected_games()
                    else:
                        print_warning("No games selected.")
                        pause()
                elif action == "add_game":
                    self.add_game_to_current_tab()
            else:
                self.show_game_details(result)

    def sort_games(self):
        """Sort games menu"""
        clear_screen()
        print_header("SORT GAMES")
        
        print_menu_option("1", "By Size (Largest first)")
        print_menu_option("2", "By Size (Smallest first)")
        print_menu_option("3", "By Completion Time (Longest first)")
        print_menu_option("4", "By Completion Time (Shortest first)")
        print_menu_option("5", "By Date (Newest first)")
        print_menu_option("6", "By Date (Oldest first)")
        print_menu_option("7", "By Name (A-Z)")
        print_menu_option("8", "By Name (Z-A)")
        print_menu_option("B", "Back")
        
        choice = get_user_input(f"\n{Fore.YELLOW}Enter your choice: ").strip()
        
        # Check if input is a tag name for quick syncing
        if handle_tag_name_input(choice, self):
            return
        
        if choice == "1":
            self.all_tags.sort(key=lambda x: x["full_size"], reverse=True)
            print_success("Sorted by size (largest first)")
        elif choice == "2":
            self.all_tags.sort(key=lambda x: x["full_size"], reverse=False)
            print_success("Sorted by size (smallest first)")
        elif choice == "3":
            self.sort_by_time(reverse=True)
            print_success("Sorted by completion time (longest first)")
        elif choice == "4":
            self.sort_by_time(reverse=False)
            print_success("Sorted by completion time (shortest first)")
        elif choice == "5":
            self.all_tags.sort(key=lambda x: parse_date(x.get("last_updated", "")), reverse=True)
            print_success("Sorted by date (newest first)")
        elif choice == "6":
            self.all_tags.sort(key=lambda x: parse_date(x.get("last_updated", "")), reverse=False)
            print_success("Sorted by date (oldest first)")
        elif choice == "7":
            self.all_tags.sort(key=lambda x: x["alias"].lower())
            print_success("Sorted by name (A-Z)")
        elif choice == "8":
            self.all_tags.sort(key=lambda x: x["alias"].lower(), reverse=True)
            print_success("Sorted by name (Z-A)")
        elif choice.upper() == "B":
            return
        else:
            print_error("Invalid choice.")
        
        pause()

    def sort_by_time(self, reverse=True):
        """Sort games by completion time"""
        def parse_time(time_str):
            try:
                time_str = time_str.lower().replace("approx time: ", "").replace("hours", "").replace("~", "").strip()
                if "-" in time_str or "–" in time_str:
                    time_str = time_str.replace("–", "-").split("-")[1].strip()
                return float(time_str)
            except:
                return 0.0
        
        self.all_tags.sort(key=lambda x: parse_time(x.get("approx_time", "0")), reverse=reverse)

    def manage_selected_games(self):
        """Manage selected games"""
        clear_screen()
        print_header("SELECTED GAMES MANAGEMENT")
        
        if not self.selected_tag_names:
            print_warning("No games selected.")
            pause()
            return
        
        selected_games = [game for game in self.all_tags if game['docker_name'] in self.selected_tag_names]
        
        print(f"{Fore.CYAN}Selected games ({len(selected_games)}):")
        total_size = 0
        for i, game in enumerate(selected_games, 1):
            size = game.get('full_size', 0)
            total_size += size
            tab_color = self.get_tab_color(game.get('category', 'all'))
            tab_name = self.get_tab_name(game.get('category', 'all'))
            print(f"{Fore.YELLOW}[{i:3d}]{Fore.WHITE} {game['alias']:<25} {Fore.CYAN}({format_size(size):<8}) {tab_color}[{tab_name}]")
        
        print(f"\n{Fore.MAGENTA}Total size: {format_size(total_size)}")
        
        print(f"\n{Fore.WHITE}{Style.BRIGHT}ACTIONS:")
        print_menu_option("1", "🚀 RUN ALL SELECTED", Fore.RED)
        print_menu_option("2", "Clear Selection")
        print_menu_option("3", "Remove Specific Game")
        print_menu_option("4", "Export Selection to File")
        print_menu_option("5", "Select All Games in Current Tab")
        print_menu_option("6", "Select Games by Category")
        print_menu_option("B", "Back")
        
        choice = get_user_input(f"\n{Fore.YELLOW}Enter your choice: ").upper().strip()
        
        # Check if input is a tag name for quick syncing
        if handle_tag_name_input(choice, self):
            return
        
        if choice == "1":
            self.run_selected_games()
        elif choice == "2":
            if confirm_action("Clear all selected games?"):
                self.selected_tag_names.clear()
                print_success("Selection cleared.")
        elif choice == "3":
            self.remove_from_selection(selected_games)
        elif choice == "4":
            self.export_selection()
        elif choice == "5":
            self.YOUR_CLIENT_SECRET_HERE()
        elif choice == "6":
            self.select_by_category()
        elif choice == "B":
            return
        else:
            print_error("Invalid choice.")
        
        pause()

    def YOUR_CLIENT_SECRET_HERE(self):
        """Select all games in current tab"""
        games_in_tab = self.filter_games_by_tab(self.current_tab)
        
        if not games_in_tab:
            print_warning(f"No games in {self.get_tab_name(self.current_tab)} tab.")
            return
        
        if confirm_action(f"Select all {len(games_in_tab)} games in {self.get_tab_name(self.current_tab)} tab?"):
            for game in games_in_tab:
                self.selected_tag_names.add(game['docker_name'])
            
            print_success(f"Selected {len(games_in_tab)} games from {self.get_tab_name(self.current_tab)} tab.")

    def select_by_category(self):
        """Select games by category"""
        clear_screen()
        print_header("SELECT GAMES BY CATEGORY")
        
        for i, tab in enumerate(self.tabs_config, 1):
            games_count = len(self.filter_games_by_tab(tab['id']))
            tab_color = tab.get('color', Fore.WHITE)
            print(f"{tab_color}[{i:2d}] {tab['name']:<20} ({games_count} games)")
        
        print_menu_option("B", "Back")
        
        choice = get_user_input(f"\n{Fore.YELLOW}Enter category number: ").strip()
        
        if choice.upper() == "B":
            return
        
        try:
            tab_index = int(choice) - 1
            if 0 <= tab_index < len(self.tabs_config):
                tab = self.tabs_config[tab_index]
                games = self.filter_games_by_tab(tab['id'])
                
                if not games:
                    print_warning(f"No games in {tab['name']} category.")
                    pause()
                    return
                
                if confirm_action(f"Select all {len(games)} games from {tab['name']}?"):
                    for game in games:
                        self.selected_tag_names.add(game['docker_name'])
                    
                    print_success(f"Selected {len(games)} games from {tab['name']}.")
            else:
                print_error("Invalid category number.")
        except ValueError:
            print_error("Please enter a valid number.")

    def remove_from_selection(self, selected_games):
        """Remove specific game from selection"""
        clear_screen()
        print_header("REMOVE FROM SELECTION")
        
        for i, game in enumerate(selected_games, 1):
            print_menu_option(str(i), game['alias'])
        
        print_menu_option("B", "Back")
        
        choice = get_user_input(f"\n{Fore.YELLOW}Enter game number to remove: ").strip()
        
        if choice.upper() == "B":
            return
        
        try:
            game_index = int(choice) - 1
            if 0 <= game_index < len(selected_games):
                game_to_remove = selected_games[game_index]
                
                if confirm_action(f"Remove {game_to_remove['alias']} from selection?"):
                    self.selected_tag_names.discard(game_to_remove['docker_name'])
                    print_success(f"Removed {game_to_remove['alias']} from selection.")
            else:
                print_error("Invalid game number.")
        except ValueError:
            print_error("Please enter a valid number.")

    def sync_operations(self):
        """Sync operations menu with enhanced real-time monitoring"""
        while True:
            clear_screen()
            print_header("SYNC OPERATIONS")
            
            # Show background sync status
            running_syncs = [sync_id for sync_id, sync_info in self.background_syncs.items() if sync_info["status"] == "running"]
            completed_syncs = [sync_id for sync_id, sync_info in self.background_syncs.items() if sync_info["status"] == "completed"]
            
            if running_syncs:
                print(f"{Fore.GREEN}🔄 Active Background Syncs: {len(running_syncs)}")
                for sync_id in running_syncs:
                    sync_info = self.background_syncs[sync_id]
                    total_games = len(sync_info["games"])
                    completed = sync_info["completed"] + sync_info["failed"]
                    print(f"{Fore.CYAN}  • {sync_id}: {completed}/{total_games} games completed")
            
            if completed_syncs:
                print(f"{Fore.YELLOW}✅ Completed Background Syncs: {len(completed_syncs)}")
            
            print()
            
            print_menu_option("1", "🚀 Run Selected Games (Background)" + (f" ({len(self.selected_tag_names)})" if self.selected_tag_names else " (None)"), Fore.GREEN)
            print_menu_option("2", "🚀 Run Selected Games (Foreground)" + (f" ({len(self.selected_tag_names)})" if self.selected_tag_names else " (None)"), Fore.RED)
            print_menu_option("3", "Quick Sync Single Game")
            print_menu_option("4", "Bulk Sync by Category")
            print_menu_option("5", "📊 Monitor Active Background Syncs", Fore.CYAN)
            print_menu_option("6", "📋 View Sync History", Fore.MAGENTA)
            print_menu_option("7", "🧹 Cleanup Completed Syncs", Fore.YELLOW)
            print_menu_option("B", "Back")
            
            choice = get_user_input(f"\n{Fore.YELLOW}Enter your choice: ").strip()
            
            if choice == "1":
                if self.selected_tag_names:
                    self.YOUR_CLIENT_SECRET_HERE()
                else:
                    print_warning("No games selected. Select games first from the main menu.")
                    pause()
            elif choice == "2":
                if self.selected_tag_names:
                    self.run_selected_games()
                else:
                    print_warning("No games selected. Select games first from the main menu.")
                    pause()
            elif choice == "3":
                self.quick_sync()
            elif choice == "4":
                self.bulk_sync_by_category()
            elif choice == "5":
                self.YOUR_CLIENT_SECRET_HERE()
            elif choice == "6":
                self.view_sync_history()
            elif choice == "7":
                self.cleanup_completed_syncs()
            elif choice.upper() == "B":
                break
            else:
                print_error("Invalid choice.")
                pause()

    def YOUR_CLIENT_SECRET_HERE(self):
        """Enhanced monitoring of active sync operations with real-time updates"""
        while True:
            clear_screen()
            print_header("📊 ACTIVE SYNC MONITOR")
            
            running_syncs = [sync_id for sync_id, sync_info in self.background_syncs.items() if sync_info["status"] == "running"]
            
            if not running_syncs:
                print_info("No active background syncs found.")
                print_menu_option("B", "Back")
                choice = get_user_input(f"\n{Fore.YELLOW}Enter your choice: ").strip()
                if choice.upper() == "B":
                    break
                continue
            
            print(f"{Fore.GREEN}🔄 Active Background Syncs: {len(running_syncs)}")
            print()
            
            for i, sync_id in enumerate(running_syncs, 1):
                sync_info = self.background_syncs[sync_id]
                total_games = len(sync_info["games"])
                completed = sync_info["completed"] + sync_info["failed"]
                progress = (completed / total_games) * 100 if total_games > 0 else 0
                
                # Calculate elapsed time
                elapsed = datetime.now() - sync_info["start_time"]
                elapsed_str = str(elapsed).split('.')[0]  # Remove microseconds
                
                print(f"{Fore.CYAN}[{i}] Sync ID: {sync_id}")
                print(f"{Fore.WHITE}   Progress: {completed}/{total_games} games ({progress:.1f}%)")
                print(f"{Fore.WHITE}   Completed: {sync_info['completed']} | Failed: {sync_info['failed']}")
                print(f"{Fore.WHITE}   Elapsed Time: {elapsed_str}")
                print(f"{Fore.WHITE}   Destination: {sync_info['destination']}")
                
                # Show recent logs
                recent_logs = sync_info["logs"][-3:]  # Last 3 log entries
                if recent_logs:
                    print(f"{Fore.YELLOW}   Recent Activity:")
                    for log in recent_logs:
                        timestamp = log["timestamp"].split("T")[1].split(".")[0]  # Just time part
                        status_color = Fore.GREEN if log["status"] == "completed" else Fore.RED if log["status"] in ["failed", "error"] else Fore.YELLOW
                        print(f"{Fore.WHITE}     [{timestamp}] {status_color}{log['message']}")
                
                print()
            
            print_menu_option("1", "View Detailed Logs")
            print_menu_option("2", "Refresh Status")
            print_menu_option("3", "Stop All Syncs", Fore.RED)
            print_menu_option("B", "Back")
            
            choice = get_user_input(f"\n{Fore.YELLOW}Enter your choice: ").strip()
            
            if choice == "1":
                self.view_detailed_sync_logs(running_syncs)
            elif choice == "2":
                # Just refresh the display
                continue
            elif choice == "3":
                if confirm_action("Stop all running background syncs?"):
                    self.YOUR_CLIENT_SECRET_HERE()
                    print_success("All background syncs stopped.")
                    pause()
            elif choice.upper() == "B":
                break
            else:
                print_error("Invalid choice.")
                pause()

    def view_detailed_sync_logs(self, sync_ids):
        """View detailed logs for specific sync operations"""
        if not sync_ids:
            print_warning("No syncs to view.")
            pause()
            return
        
        clear_screen()
        print_header("📋 DETAILED SYNC LOGS")
        
        for sync_id in sync_ids:
            if sync_id not in self.background_syncs:
                continue
            
            sync_info = self.background_syncs[sync_id]
            print(f"{Fore.CYAN}{'='*60}")
            print(f"{Fore.CYAN}Sync ID: {sync_id}")
            print(f"{Fore.CYAN}Status: {sync_info['status']}")
            print(f"{Fore.CYAN}Destination: {sync_info['destination']}")
            print(f"{Fore.CYAN}Start Time: {sync_info['start_time']}")
            print(f"{Fore.CYAN}{'='*60}")
            
            for log in sync_info["logs"]:
                timestamp = log["timestamp"].split("T")[1].split(".")[0]
                status_color = Fore.GREEN if log["status"] == "completed" else Fore.RED if log["status"] in ["failed", "error"] else Fore.YELLOW
                
                print(f"{Fore.WHITE}[{timestamp}] {status_color}{log['message']}")
                
                # Show output if available
                if log.get("output"):
                    print(f"{Fore.CYAN}   Output:")
                    for line in log["output"][-5:]:  # Last 5 lines
                        print(f"{Fore.WHITE}     {line}")
            
            print()
        
        pause()

    def view_sync_history(self):
        """View sync history"""
        clear_screen()
        print_header("📋 SYNC HISTORY")
        
        if not self.sync_history["syncs"]:
            print_info("No sync history found.")
            pause()
            return
        
        # Show recent syncs (last 10)
        recent_syncs = self.sync_history["syncs"][-10:]
        
        print(f"{Fore.CYAN}Recent Sync Operations:")
        for i, sync in enumerate(reversed(recent_syncs), 1):
            timestamp = sync["timestamp"].split("T")[0] + " " + sync["timestamp"].split("T")[1].split(".")[0]
            background_marker = "🔄" if sync.get("background") else "⚡"
            status_color = Fore.GREEN if sync["successful_syncs"] > 0 else Fore.RED
            
            print(f"{Fore.YELLOW}[{i}] {background_marker} {timestamp}")
            print(f"{Fore.WHITE}   User: {sync['user']} | Games: {sync['total_games']}")
            print(f"{Fore.WHITE}   Success: {status_color}{sync['successful_syncs']} | Failed: {Fore.RED}{sync['failed_syncs']}")
            print(f"{Fore.WHITE}   Destination: {sync['destination']}")
            print()
        
        print_menu_option("B", "Back")
        choice = get_user_input(f"\n{Fore.YELLOW}Enter your choice: ").strip()
        if choice.upper() == "B":
            return

    def cleanup_completed_syncs(self):
        """Clean up completed sync operations"""
        completed_syncs = [sync_id for sync_id, sync_info in self.background_syncs.items() if sync_info["status"] == "completed"]
        
        if not completed_syncs:
            print_info("No completed syncs to clean up.")
            pause()
            return
        
        print(f"{Fore.CYAN}Found {len(completed_syncs)} completed sync operations to clean up.")
        
        if confirm_action("Remove all completed sync operations from memory?"):
            for sync_id in completed_syncs:
                del self.background_syncs[sync_id]
            print_success(f"Cleaned up {len(completed_syncs)} completed sync operations.")
        
        pause()

    def YOUR_CLIENT_SECRET_HERE(self):
        """Stop all running background syncs"""
        running_syncs = [sync_id for sync_id, sync_info in self.background_syncs.items() if sync_info["status"] == "running"]
        
        for sync_id in running_syncs:
            sync_info = self.background_syncs[sync_id]
            sync_info["status"] = "stopped"
            
            # Try to stop Docker containers
            for game in sync_info["games"]:
                try:
                    cleanup_cmd = f'wsl -d Ubuntu docker rm -f {game["docker_name"]} 2>/dev/null'
                    subprocess.run(cleanup_cmd, shell=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                except:
                    pass
            
            # Add stop log entry
            log_entry = {
                "timestamp": datetime.now().isoformat(),
                "game": "SYSTEM",
                "docker_name": "SYSTEM",
                "status": "stopped",
                "message": f"🛑 Background sync stopped by user",
                "output": []
            }
            sync_info["logs"].append(log_entry)

    def quick_sync(self):
        """Quick sync a single game"""
        clear_screen()
        print_header("QUICK SYNC")
        
        search_term = get_user_input("Enter game name or part of name: ").strip().lower()
        if not search_term:
            return
        
        matching_games = [game for game in self.all_tags if search_term in game['alias'].lower()]
        
        if not matching_games:
            print_warning(f"No games found matching '{search_term}'.")
            pause()
            return
        elif len(matching_games) == 1:
            self.sync_single_game(matching_games[0])
        else:
            # Use grid display for selection
            while True:
                result = display_games_in_grid(
                    matching_games, 
                    f"Multiple matches for '{search_term}'",
                    games_per_row=3,  # Reduced to accommodate full names
                    show_selection=True,
                    selected_tags=self.selected_tag_names,
                    app_instance=self
                )
                
                if result is None:
                    break
                elif isinstance(result, tuple):
                    action, game = result
                    if action == "toggle" and game:
                        message = self.toggle_game_selection(game)
                        print_success(message)
                        time.sleep(0.5)
                    elif action == "run_selected":
                        if self.selected_tag_names:
                            self.run_selected_games()
                        else:
                            print_warning("No games selected.")
                            pause()
                    elif action == "add_game":
                        self.add_game_to_current_tab()
                else:
                    self.sync_single_game(result)
                    break

    def bulk_sync_by_category(self):
        """Bulk sync all games in a category"""
        clear_screen()
        print_header("BULK SYNC BY CATEGORY")
        
        for i, tab in enumerate(self.tabs_config, 1):
            games_count = len(self.filter_games_by_tab(tab['id']))
            tab_color = tab.get('color', Fore.WHITE)
            print(f"{tab_color}[{i:2d}] {tab['name']:<20} ({games_count} games)")
        
        print_menu_option("B", "Back")
        
        choice = get_user_input(f"\n{Fore.YELLOW}Enter category number: ").strip()
        
        if choice.upper() == "B":
            return
        
        try:
            tab_index = int(choice) - 1
            if 0 <= tab_index < len(self.tabs_config):
                tab = self.tabs_config[tab_index]
                games = self.filter_games_by_tab(tab['id'])
                
                if not games:
                    print_warning(f"No games in {tab['name']} category.")
                    pause()
                    return
                
                print_info(f"Found {len(games)} games in {tab['name']} category")
                
                if confirm_action(f"Sync all {len(games)} games from {tab['name']}?"):
                    # Add all games to selection temporarily
                    original_selection = self.selected_tag_names.copy()
                    for game in games:
                        self.selected_tag_names.add(game['docker_name'])
                    
                    # Run selected games
                    self.run_selected_games()
                    
                    # Restore original selection (in case some failed)
                    remaining_games = [g['docker_name'] for g in games if g['docker_name'] in self.selected_tag_names]
                    self.selected_tag_names = original_selection.union(set(remaining_games))
            else:
                print_error("Invalid category number.")
        except ValueError:
            print_error("Please enter a valid number.")
        
        pause()

    def monitor_active_syncs(self):
        """Monitor active sync operations"""
        clear_screen()
        print_header("ACTIVE SYNC MONITOR")
        
        print_info("Checking for active Docker containers...")
        
        try:
            # Check for running containers
            check_cmd = 'wsl --distribution ubuntu --user root -- bash -lic "docker ps --format \'table {{.Names}}\\t{{.Status}}\\t{{.Image}}\'"'
            result = subprocess.run(check_cmd, shell=True, capture_output=True, text=True)
            
            if result.returncode == 0:
                output_lines = result.stdout.strip().split('\n')
                if len(output_lines) > 1:  # More than just header
                    print_success("Active containers found:")
                    for line in output_lines:
                        print(f"{Fore.WHITE}  {line}")
                else:
                    print_info("No active sync operations found.")
            else:
                print_error("Could not check for active containers.")
        except Exception as e:
            print_error(f"Error checking active syncs: {e}")
        
        pause()

    # Admin-only methods (keeping all original admin functionality)
    def tag_management(self):
        """Tag management menu (admin only)"""
        if not self.is_admin:
            print_error("Admin privileges required.")
            return
        
        while True:
            clear_screen()
            print_header("TAG MANAGEMENT (ADMIN)")
            
            print_menu_option("1", "Rename Tag Alias")
            print_menu_option("2", "Move Tag to Different Category")
            print_menu_option("3", "Delete Tag from Docker Hub", Fore.RED)
            print_menu_option("4", "Bulk Move Tags")
            print_menu_option("5", "Show Missing Images")
            print_menu_option("6", "Refresh Tags from Docker Hub")
            print_menu_option("B", "Back")
            
            choice = get_user_input(f"\n{Fore.YELLOW}Enter your choice: ").upper().strip()
            
            if choice == "1":
                self.rename_tag_interface()
            elif choice == "2":
                self.move_tag_interface()
            elif choice == "3":
                self.delete_tag_interface()
            elif choice == "4":
                self.bulk_move_tags()
            elif choice == "5":
                self.manage_tab_exclusions()
            elif choice == "6":
                self.refresh_tags()
                print_success("Tags refreshed from Docker Hub")
                pause()
            elif choice == "B":
                break
            else:
                print_error("Invalid choice.")
                pause()

    def rename_tag_interface(self):
        """Interface to rename a tag alias"""
        clear_screen()
        print_header("RENAME TAG ALIAS")
        
        search_term = get_user_input("Enter game name to rename: ").strip().lower()
        if not search_term:
            return
        
        matching_games = [game for game in self.all_tags if search_term in game['alias'].lower()]
        
        if not matching_games:
            print_warning(f"No games found matching '{search_term}'.")
            pause()
            return
        elif len(matching_games) == 1:
            self.change_game_alias(matching_games[0])
        else:
            # Use grid display for selection
            while True:
                result = display_games_in_grid(
                    matching_games, 
                    f"Select game to rename",
                    games_per_row=3,  # Reduced to accommodate full names
                    show_selection=False,
                    app_instance=self
                )
                
                if result is None:
                    break
                elif isinstance(result, tuple):
                    action, game = result
                    if action == "add_game":
                        self.add_game_to_current_tab()
                else:
                    self.change_game_alias(result)
                    break

    def change_game_alias(self, game):
        """Change a game's alias"""
        current_alias = game['alias']
        print_info(f"Current alias: {current_alias}")
        
        new_alias = get_user_input("Enter new alias: ").strip()
        if not new_alias:
            print_warning("Alias cannot be empty.")
            pause()
            return
        
        if confirm_action(f"Change alias from '{current_alias}' to '{new_alias}'?"):
            # Update the game object
            game['alias'] = new_alias
            
            # Update persistent settings
            persistent = self.persistent_settings.get(game['docker_name'], {})
            persistent['alias'] = new_alias
            self.persistent_settings[game['docker_name']] = persistent
            
            # Auto-save all data
            self.auto_save_all_data()
            
            print_success(f"Alias changed to '{new_alias}'")
        
        pause()

    def move_tag_interface(self):
        """Interface to move a tag to different category"""
        clear_screen()
        print_header("MOVE TAG TO CATEGORY")
        
        search_term = get_user_input("Enter game name to move: ").strip().lower()
        if not search_term:
            return
        
        matching_games = [game for game in self.all_tags if search_term in game['alias'].lower()]
        
        if not matching_games:
            print_warning(f"No games found matching '{search_term}'.")
            pause()
            return
        elif len(matching_games) == 1:
            self.move_game_to_tab(matching_games[0])
        else:
            # Use grid display for selection
            while True:
                result = display_games_in_grid(
                    matching_games, 
                    f"Select game to move",
                    games_per_row=3,  # Reduced to accommodate full names
                    show_selection=False,
                    app_instance=self
                )
                
                if result is None:
                    break
                elif isinstance(result, tuple):
                    action, game = result
                    if action == "add_game":
                        self.add_game_to_current_tab()
                else:
                    self.move_game_to_tab(result)
                    break

    def move_game_to_tab(self, game):
        """Move a game to a different tab"""
        clear_screen()
        print_header(f"MOVE GAME: {game['alias']}")
        
        print(f"{Fore.CYAN}Current category: {self.get_tab_name(game.get('category', 'all'))}\n")
        
        for i, tab in enumerate(self.tabs_config, 1):
            if tab['id'] != game.get('category', 'all'):
                tab_color = tab.get('color', Fore.WHITE)
                print(f"{tab_color}[{i:2d}] {tab['name']}")
        
        print_menu_option("B", "Back")
        
        choice = get_user_input(f"\n{Fore.YELLOW}Enter category number: ").strip()
        
        if choice.upper() == "B":
            return
        
        try:
            tab_index = int(choice) - 1
            if 0 <= tab_index < len(self.tabs_config):
                new_category = self.tabs_config[tab_index]['id']
                
                if confirm_action(f"Move {game['alias']} to {self.tabs_config[tab_index]['name']}?"):
                    # Update the game object
                    game['category'] = new_category
                    
                    # Update persistent settings
                    persistent = self.persistent_settings.get(game['docker_name'], {})
                    persistent['category'] = new_category
                    self.persistent_settings[game['docker_name']] = persistent
                    
                    # Auto-save all data
                    self.auto_save_all_data()
                    
                    print_success(f"Moved {game['alias']} to {self.tabs_config[tab_index]['name']}")
            else:
                print_error("Invalid category number.")
        except ValueError:
            print_error("Please enter a valid number.")
        
        pause()

    def delete_tag_interface(self):
        """Interface to delete a tag from Docker Hub"""
        clear_screen()
        print_header("DELETE TAG FROM DOCKER HUB")
        
        search_term = get_user_input("Enter game name to DELETE: ").strip().lower()
        if not search_term:
            return
        
        matching_games = [game for game in self.all_tags if search_term in game['alias'].lower()]
        
        if not matching_games:
            print_warning(f"No games found matching '{search_term}'.")
            pause()
            return
        elif len(matching_games) == 1:
            self.delete_game_tag(matching_games[0])
        else:
            # Use grid display for selection
            while True:
                result = display_games_in_grid(
                    matching_games, 
                    f"Select game to DELETE",
                    games_per_row=3,  # Reduced to accommodate full names
                    show_selection=False,
                    app_instance=self
                )
                
                if result is None:
                    break
                elif isinstance(result, tuple):
                    action, game = result
                    if action == "toggle" and game:
                        self.toggle_game_selection(game)
                        print_success(f"Toggled selection for {game['alias']}")
                        time.sleep(0.5)
                    elif action == "run_selected":
                        if self.is_guest:
                            print_warning("Docker sync is disabled in Guest Mode.")
                            pause()
                        elif self.selected_tag_names:
                            self.run_selected_games()
                        else:
                            print_warning("No games selected.")
                            pause()
                    elif action == "add_game":
                        self.add_game_to_current_tab()
                    elif action == "select_all":
                        for g in matching_games:
                            self.selected_tag_names.add(g['docker_name'])
                        print_success(f"Selected all {len(matching_games)} games.")
                        time.sleep(0.5)
                    elif action == "deselect_all":
                        for g in matching_games:
                            self.selected_tag_names.discard(g['docker_name'])
                        print_success(f"Deselected all games.")
                        time.sleep(0.5)
                else:
                    self.show_game_details(result)

    def show_missing_time_data(self):
        """Show tags that are missing time data"""
        clear_screen()
        print_header("MISSING TIME DATA")
        
        tags_without_time = [tag for tag in self.all_tags if tag.get('approx_time', 'N/A') == 'N/A']
        
        if not tags_without_time:
            print_success("All tags have time data!")
            pause()
            return
        
        print(f"{Fore.YELLOW}Tags missing time data ({len(tags_without_time)}):")
        for i, tag in enumerate(tags_without_time, 1):
            print(f"{Fore.WHITE}[{i:3d}] {tag['docker_name']:<30} {Fore.CYAN}({tag['alias']})")
        
        print(f"\n{Fore.CYAN}Available time data keys in time.txt:")
        time_keys = list(self.time_data.keys())[:20]  # Show first 20 keys
        for key in time_keys:
            print(f"{Fore.WHITE}  • {key}")
        
        if len(self.time_data) > 20:
            print(f"{Fore.CYAN}  ... and {len(self.time_data) - 20} more")
        
        pause()

    def refresh_time_data(self):
        """Force refresh time data from time.txt file"""
        print_info("Refreshing time data from time.txt...")
        self.time_data = load_time_data(os.path.join(os.path.dirname(__file__), "time.txt"))
        
        # Update all tags with new time data
        for tag in self.all_tags:
            docker_name_lower = tag["docker_name"].lower()
            alias_lower = tag["alias"].lower()
            
            # Try to find time data using different keys
            time_val = None
            if docker_name_lower in self.time_data:
                time_val = self.time_data[docker_name_lower]
            elif alias_lower in self.time_data:
                time_val = self.time_data[alias_lower]
            elif tag["docker_name"] in self.time_data:
                time_val = self.time_data[tag["docker_name"]]
            elif tag["alias"] in self.time_data:
                time_val = self.time_data[tag["alias"]]
            else:
                time_val = "N/A"
            
            tag["approx_time"] = time_val
        
        print_success(f"Time data refreshed for {len(self.all_tags)} games")

    def view_all_tabs(self):
        """View all tabs and their game counts"""
        clear_screen()
        print_header("ALL TABS")
        
        for i, tab in enumerate(self.tabs_config, 1):
            print(f"{Fore.CYAN}[{i:2d}] {tab['name']:<20} ({len(self.filter_games_by_tab(tab['id']))} games)")
        
        print_menu_option("B", "Back")
        
        choice = get_user_input(f"\n{Fore.YELLOW}Enter tab number to view: ").strip()
        
        if choice.upper() == "B":
            return
        
        try:
            tab_index = int(choice) - 1
            if 0 <= tab_index < len(self.tabs_config):
                self.browse_games_list(self.filter_games_by_tab(self.tabs_config[tab_index]['id']), self.tabs_config[tab_index]['name'])
            else:
                print_error("Invalid tab number.")
                pause()
        except ValueError:
            print_error("Please enter a valid number.")
            pause()

    def bulk_move_to_tab(self):
        """Bulk move selected games to a different tab"""
        clear_screen()
        print_header("BULK MOVE TO TAB")
        
        if not self.selected_tag_names:
            print_warning("No games selected. Please select games first.")
            pause()
            return
        
        print(f"{Fore.CYAN}Selected games ({len(self.selected_tag_names)}):")
        for i, game in enumerate(self.all_tags, 1):
            if game['docker_name'] in self.selected_tag_names:
                print(f"{Fore.YELLOW}[{i:3d}] {game['alias']:<30} {Fore.CYAN}({format_size(game['full_size'])})")
        
        print(f"\n{Fore.YELLOW}Select destination tab:")
        for i, tab in enumerate(self.tabs_config, 1):
            tab_color = tab.get('color', Fore.WHITE)
            print(f"{tab_color}[{i:2d}] {tab['name']}")
        
        print_menu_option("B", "Back")
        
        choice = get_user_input(f"\n{Fore.YELLOW}Enter tab number: ").strip()
        
        if choice.upper() == "B":
            return
        
        try:
            tab_index = int(choice) - 1
            if 0 <= tab_index < len(self.tabs_config):
                new_tab = self.tabs_config[tab_index]
                for game in self.all_tags:
                    if game['docker_name'] in self.selected_tag_names:
                        game['category'] = new_tab['id']
                        # Update persistent settings
                        persistent = self.persistent_settings.get(game['docker_name'], {})
                        persistent['category'] = new_tab['id']
                        self.persistent_settings[game['docker_name']] = persistent
                
                # Auto-save all data
                self.auto_save_all_data()
                
                print_success(f"Moved {len(self.selected_tag_names)} games to {new_tab['name']}")
            else:
                print_error("Invalid tab number.")
        except ValueError:
            print_error("Please enter a valid number.")
        
        pause()

    def disconnect_user(self):
        """Disconnect current user and restart application"""
        clear_screen()
        print_header("DISCONNECT USER")
        
        print(f"{Fore.CYAN}Current user: {self.username}")
        print(f"{Fore.YELLOW}This will disconnect you and restart the application.")
        
        if confirm_action("Are you sure you want to disconnect?"):
            print_info("Disconnecting user...")
            self.remove_active_user()
            print_success("User disconnected successfully.")
            print_info("Restarting application...")
            pause()
            
            # Restart the application
            python = sys.executable
            os.execl(python, python, *sys.argv)
        else:
            print_info("Disconnection cancelled.")
            pause()

    def configure_sync_path(self):
        """Configure sync path menu"""
        clear_screen()
        print_header("CONFIGURE SYNC PATH")
        
        current_path = self.user_preferences.get('sync_destination', DEFAULT_DESTINATION)
        print(f"{Fore.CYAN}Current sync path: {current_path}")
        
        print(f"\n{Fore.YELLOW}Available options:")
        print_menu_option("1", "Set custom sync path")
        print_menu_option("2", "Use default sync path")
        print_menu_option("3", "Use F: Drive (F:\\Games)")
        print_menu_option("B", "Back")
        
        choice = get_user_input(f"\n{Fore.YELLOW}Enter your choice: ").strip()
        
        if choice == "1":
            custom_path = get_user_input("Enter custom sync path: ").strip()
            if custom_path:
                self.user_preferences['sync_destination'] = custom_path
                save_user_preferences(self.user_preferences)
                print_success(f"Sync path set to: {custom_path}")
            else:
                print_warning("Sync path cannot be empty.")
        elif choice == "2":
            self.user_preferences['sync_destination'] = DEFAULT_DESTINATION
            save_user_preferences(self.user_preferences)
            print_success("Sync path reset to default")
        elif choice == "3":
            self.user_preferences['sync_destination'] = "F:\\Games"
            save_user_preferences(self.user_preferences)
            print_success("Sync path set to F: Drive")
        elif choice.upper() == "B":
            return
        else:
            print_error("Invalid choice.")
        
        pause()

    def quick_sync_by_tags(self, tag_names):
        """Quick sync games by tag names (immediate execution)"""
        if self.is_guest:
            print_warning("Docker sync is disabled in Guest Mode. Please login with credentials to sync games.")
            return False
        
        # Find games by tag names
        games_to_sync = []
        for tag_name in tag_names:
            # Try to find by docker_name first, then by alias
            found_game = None
            for game in self.all_tags:
                if game['docker_name'].lower() == tag_name.lower():
                    found_game = game
                    break
                elif game['alias'].lower() == tag_name.lower():
                    found_game = game
                    break
            
            if found_game:
                games_to_sync.append(found_game)
            else:
                print_warning(f"Game '{tag_name}' not found")
        
        if not games_to_sync:
            print_warning("No valid games found to sync")
            return False
        
        # Get sync destination
        sync_path = self.user_preferences.get('sync_destination', DEFAULT_DESTINATION)
        
        # Convert Windows path to WSL path if needed
        if sync_path.startswith('F:') or sync_path.startswith('f:'):
            wsl_path = sync_path.replace('\\', '/').replace('F:', '/mnt/f').replace('f:', '/mnt/f')
        elif sync_path.startswith('C:') or sync_path.startswith('c:'):
            wsl_path = sync_path.replace('\\', '/').replace('C:', '/mnt/c').replace('c:', '/mnt/c')
        else:
            wsl_path = sync_path.replace('\\', '/')
        
        print_header("🚀 QUICK SYNC BY TAGS")
        print(f"{Fore.CYAN}Games to sync: {len(games_to_sync)}")
        print(f"{Fore.CYAN}Destination: {sync_path}")
        print(f"{Fore.CYAN}WSL Path: {wsl_path}")
        
        for i, game in enumerate(games_to_sync, 1):
            print(f"{Fore.YELLOW}[{i}] {game['alias']} ({game['docker_name']})")
        
        if not confirm_action(f"Start syncing {len(games_to_sync)} games to {sync_path}?"):
            return False
        
        # Execute sync for each game
        successful_syncs = 0
        failed_syncs = 0
        
        for i, game in enumerate(games_to_sync, 1):
            print(f"\n{Fore.YELLOW}{'='*60}")
            print(f"{Fore.CYAN}Syncing {i}/{len(games_to_sync)}: {game['alias']}")
            print(f"{Fore.CYAN}Docker Tag: {game['docker_name']}")
            print(f"{Fore.YELLOW}{'='*60}")
            
            try:
                import time as _time
                start_time = _time.time()
                # Create the full Docker command
                docker_command = (
                    f"wsl -d Ubuntu docker run --pull=always --rm --cpus=8 --memory=32g --memory-swap=40g "
                    f"-v {wsl_path}:/games "
                    f"-e DISPLAY=$DISPLAY "
                    f"-v /tmp/.X11-unix:/tmp/.X11-unix "
                    f"--name {game['docker_name']} "
                    f"michadockermisha/backup:{game['docker_name']} "
                    f"sh -c \"apk add --no-cache rsync pigz && rsync -aPW --omit-dir-times --no-perms --no-owner --no-group --no-times --no-acls --no-xattrs --ignore-errors --size-only --inplace --no-i-r --no-specials --no-devices --no-sparse --no-links --no-hard-links --no-blocking-io --bwlimit=0 /home /games && cd /games && mv home {game['docker_name']} && exit\""
                )
                
                print(f"\n{Fore.GREEN}Executing: {docker_command[:100]}...")
                
                # Run the command with real-time output
                process = subprocess.Popen(
                    docker_command, shell=True, stdout=subprocess.PIPE,
                    stderr=subprocess.STDOUT, bufsize=1, universal_newlines=True
                )
                
                # Display output in real-time
                if process.stdout is not None:
                    for line in iter(process.stdout.readline, ''):
                        print(line, end='', flush=True)
                process.wait()
                elapsed = _time.time() - start_time
                elapsed_min = elapsed / 60
                if process.returncode == 0:
                    print(f"\n{Fore.GREEN}✅ Successfully synced {game['alias']}")
                    print(f"{Fore.CYAN}⏱️  Sync time: {elapsed_min:.1f} minutes")
                    successful_syncs += 1
                else:
                    print(f"\n{Fore.RED}❌ Failed to sync {game['alias']} (Exit code: {process.returncode})")
                    print(f"{Fore.CYAN}⏱️  Sync time: {elapsed_min:.1f} minutes")
                    failed_syncs += 1
                    
            except Exception as e:
                print(f"\n{Fore.RED}❌ Error syncing {game['alias']}: {e}")
                failed_syncs += 1
            
            # Cleanup any running containers
            try:
                cleanup_cmd = f'wsl -d Ubuntu docker rm -f {game["docker_name"]} 2>/dev/null'
                subprocess.run(cleanup_cmd, shell=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            except:
                pass
        
        # Final summary
        print(f"\n{Fore.CYAN}{'='*60}")
        print_header("QUICK SYNC COMPLETE")
        print(f"{Fore.GREEN}✅ Successful syncs: {successful_syncs}")
        print(f"{Fore.RED}❌ Failed syncs: {failed_syncs}")
        print(f"{Fore.CYAN}📁 Destination: {sync_path}")
        
        if successful_syncs > 0:
            print(f"\n{Fore.GREEN}🎉 Games are now available at: {sync_path}")
        
        print(f"{Fore.CYAN}{'='*60}")
        return successful_syncs > 0

    def quick_sync_by_tag_name(self, tag_name):
        """Quick sync a single game by tag name"""
        if self.is_guest:
            print_warning("Docker sync is disabled in Guest Mode. Please login with credentials to sync games.")
            return False
        
        # Find the game by tag name
        game = find_game_by_tag_name(tag_name, self.all_tags)
        
        if not game:
            print_warning(f"Game '{tag_name}' not found")
            return False
        
        # Get sync destination
        sync_path = self.user_preferences.get('sync_destination', DEFAULT_DESTINATION)
        
        # Convert Windows path to WSL path if needed
        if sync_path.startswith('F:') or sync_path.startswith('f:'):
            wsl_path = sync_path.replace('\\', '/').replace('F:', '/mnt/f').replace('f:', '/mnt/f')
        elif sync_path.startswith('C:') or sync_path.startswith('c:'):
            wsl_path = sync_path.replace('\\', '/').replace('C:', '/mnt/c').replace('c:', '/mnt/c')
        else:
            wsl_path = sync_path.replace('\\', '/')
        
        print_header(f"🚀 QUICK SYNC: {game['alias']}")
        print(f"{Fore.CYAN}Docker Tag: {game['docker_name']}")
        print(f"{Fore.CYAN}Size: {format_size(game.get('full_size', 0))}")
        print(f"{Fore.CYAN}Destination: {sync_path}")
        print(f"{Fore.CYAN}WSL Path: {wsl_path}")
        
        if not confirm_action(f"Start syncing {game['alias']} to {sync_path}?"):
            return False
        
        try:
            import time as _time
            start_time = _time.time()
            # Create the full Docker command
            docker_command = (
                f"wsl -d Ubuntu docker run --pull=always --rm --cpus=8 --memory=32g --memory-swap=40g "
                f"-v {wsl_path}:/games "
                f"-e DISPLAY=$DISPLAY "
                f"-v /tmp/.X11-unix:/tmp/.X11-unix "
                f"--name {game['docker_name']} "
                f"michadockermisha/backup:{game['docker_name']} "
                f"sh -c \"apk add --no-cache rsync pigz && rsync -aPW --omit-dir-times --no-perms --no-owner --no-group --no-times --no-acls --no-xattrs --ignore-errors --size-only --inplace --no-i-r --no-specials --no-devices --no-sparse --no-links --no-hard-links --no-blocking-io --bwlimit=0 /home /games && cd /games && mv home {game['docker_name']} && exit\""
            )
            
            print(f"\n{Fore.GREEN}Executing: {docker_command[:100]}...")
            
            # Run the command with real-time output
            process = subprocess.Popen(
                docker_command, shell=True, stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT, bufsize=1, universal_newlines=True
            )
            
            # Display output in real-time
            if process.stdout is not None:
                for line in iter(process.stdout.readline, ''):
                    print(line, end='', flush=True)
            process.wait()
            elapsed = _time.time() - start_time
            elapsed_min = elapsed / 60
            if process.returncode == 0:
                print(f"\n{Fore.GREEN}✅ Successfully synced {game['alias']}")
                print(f"{Fore.GREEN}🎉 Game is now available at: {sync_path}")
                print(f"{Fore.CYAN}⏱️  Sync time: {elapsed_min:.1f} minutes")
                return True
            else:
                print(f"\n{Fore.RED}❌ Failed to sync {game['alias']} (Exit code: {process.returncode})")
                print(f"{Fore.CYAN}⏱️  Sync time: {elapsed_min:.1f} minutes")
                return False
                
        except Exception as e:
            print(f"\n{Fore.RED}❌ Error syncing {game['alias']}: {e}")
            return False
        finally:
            # Cleanup any running containers
            try:
                cleanup_cmd = f'wsl -d Ubuntu docker rm -f {game["docker_name"]} 2>/dev/null'
                subprocess.run(cleanup_cmd, shell=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            except:
                pass

    def delete_game_tag(self, game):
        """Delete a game tag from Docker Hub"""
        if not self.is_admin:
            print_error("Admin privileges required.")
            return
        
        print_warning(f"This will PERMANENTLY DELETE {game['alias']} from Docker Hub!")
        print_info(f"Docker name: {game['docker_name']}")
        print_info(f"Size: {format_size(game['full_size'])}")
        
        if not confirm_action(f"Are you ABSOLUTELY SURE you want to delete {game['alias']}?"):
            print_info("Deletion cancelled.")
            pause()
            return
        
        # Get Docker token
        token = get_docker_token(self.login_password)
        if not token:
            print_error("Failed to authenticate with Docker Hub.")
            pause()
            return
        
        print_info("Deleting tag from Docker Hub...")
        
        if delete_docker_tag(token, game['docker_name']):
            print_success(f"Successfully deleted {game['alias']} from Docker Hub")
            
            # Remove from local list
            self.all_tags = [tag for tag in self.all_tags if tag['docker_name'] != game['docker_name']]
            
            # Remove from selection if selected
            self.selected_tag_names.discard(game['docker_name'])
        else:
            print_error(f"Failed to delete {game['alias']} from Docker Hub")
        
        pause()

    def bulk_move_tags(self):
        """Bulk move multiple tags to a category"""
        clear_screen()
        print_header("BULK MOVE TAGS")
        
        if not self.selected_tag_names:
            print_warning("No games selected. Please select games first.")
            pause()
            return
        
        selected_games = [game for game in self.all_tags if game['docker_name'] in self.selected_tag_names]
        
        print(f"{Fore.CYAN}Selected games to move ({len(selected_games)}):")
        for game in selected_games:
            current_tab = self.get_tab_name(game.get('category', 'all'))
            print(f"{Fore.WHITE}  • {game['alias']:<25} {Fore.CYAN}[{current_tab}]")
        
        print(f"\n{Fore.YELLOW}Select destination category:")
        for i, tab in enumerate(self.tabs_config, 1):
            tab_color = tab.get('color', Fore.WHITE)
            print(f"{tab_color}[{i:2d}] {tab['name']}")
        
        print_menu_option("B", "Back")
        
        choice = get_user_input(f"\n{Fore.YELLOW}Enter category number: ").strip()
        
        if choice.upper() == "B":
            return
        
        try:
            tab_index = int(choice) - 1
            if 0 <= tab_index < len(self.tabs_config):
                new_category = self.tabs_config[tab_index]['id']
                new_category_name = self.tabs_config[tab_index]['name']
                
                if confirm_action(f"Move {len(selected_games)} games to {new_category_name}?"):
                    for game in selected_games:
                        # Update the game object
                        game['category'] = new_category
                        
                        # Update persistent settings
                        persistent = self.persistent_settings.get(game['docker_name'], {})
                        persistent['category'] = new_category
                        self.persistent_settings[game['docker_name']] = persistent
                    
                    # Auto-save all data
                    self.auto_save_all_data()
                    
                    print_success(f"Moved {len(selected_games)} games to {new_category_name}")
            else:
                print_error("Invalid category number.")
        except ValueError:
            print_error("Please enter a valid number.")
        
        pause()

    def manage_tab_exclusions(self):
        """Manage tab exclusions from 'All' tab"""
        clear_screen()
        print_header("MANAGE TAB EXCLUSIONS")
        
        settings = load_settings()
        excluded_tabs = settings.get('excluded_tabs', [])
        
        print(f"{Fore.CYAN}Currently excluded tabs from 'All' view:")
        if excluded_tabs:
            for tab_id in excluded_tabs:
                tab_name = self.get_tab_name(tab_id)
                print(f"{Fore.RED}  • {tab_name} ({tab_id})")
        else:
            print(f"{Fore.GREEN}  No tabs are excluded")
        
        print(f"\n{Fore.YELLOW}Available tabs to exclude/include:")
        for i, tab in enumerate(self.tabs_config, 1):
            if tab["id"] != "all":
                status = "EXCLUDED" if tab["id"] in excluded_tabs else "included"
                color = Fore.RED if tab["id"] in excluded_tabs else Fore.GREEN
                tab_color = tab.get('color', Fore.WHITE)
                print(f"{tab_color}[{i:2d}] {tab['name']:<20} {color}({status})")
        
        print_menu_option("T", "Toggle Exclusion")
        print_menu_option("C", "Clear All Exclusions")
        print_menu_option("B", "Back")
        
        choice = get_user_input(f"\n{Fore.YELLOW}Enter your choice: ").upper().strip()
        
        if choice == "T":
            tab_choice = get_user_input("Enter tab number to toggle: ").strip()
            try:
                tab_index = int(tab_choice) - 1
                if 0 <= tab_index < len(self.tabs_config):
                    tab = self.tabs_config[tab_index]
                    if tab["id"] == "all":
                        print_error("Cannot exclude the 'All' tab.")
                    else:
                        if tab["id"] in excluded_tabs:
                            excluded_tabs.remove(tab["id"])
                            print_success(f"'{tab['name']}' is now included in 'All' view")
                        else:
                            excluded_tabs.append(tab["id"])
                            print_success(f"'{tab['name']}' is now excluded from 'All' view")
                        
                        settings['excluded_tabs'] = excluded_tabs
                        save_settings(settings)
                else:
                    print_error("Invalid tab number.")
            except ValueError:
                print_error("Please enter a valid number.")
        elif choice == "C":
            if confirm_action("Clear all tab exclusions?"):
                settings['excluded_tabs'] = []
                save_settings(settings)
                print_success("All tab exclusions cleared")

    def tab_management(self):
        """Tab management menu (admin only)"""
        if not self.is_admin:
            print_error("Admin privileges required.")
            return
        
        while True:
            clear_screen()
            print_header("TAB MANAGEMENT (ADMIN)")
            
            print(f"{Fore.CYAN}Current tabs ({len(self.tabs_config)}):")
            for i, tab in enumerate(self.tabs_config, 1):
                games_count = len(self.filter_games_by_tab(tab['id']))
                tab_color = tab.get('color', Fore.WHITE)
                print(f"{tab_color}[{i:2d}] {tab['name']:<20} ({tab['id']:<15}) {games_count:3d} games")
            
            print(f"\n{Fore.WHITE}{Style.BRIGHT}ACTIONS:")
            print_menu_option("1", "➕ Create New Tab", Fore.GREEN)
            print_menu_option("2", "✏️ Edit Tab", Fore.YELLOW)
            print_menu_option("3", "🗑️ Delete Tab", Fore.RED)
            print_menu_option("4", "🔄 Refresh Tab Counts")
            print_menu_option("B", "Back")
            
            choice = get_user_input(f"\n{Fore.YELLOW}Enter your choice: ").upper().strip()
            
            if choice == "1":
                self.create_new_tab()
            elif choice == "2":
                self.edit_tab()
            elif choice == "3":
                self.delete_tab()
            elif choice == "4":
                print_success("Tab counts refreshed")
                pause()
            elif choice == "B":
                break
            else:
                print_error("Invalid choice.")
                pause()

    def create_new_tab(self):
        """Create a new tab"""
        clear_screen()
        print_header("CREATE NEW TAB")
        
        tab_name = get_user_input("Enter tab name: ").strip()
        if not tab_name:
            print_warning("Tab name cannot be empty.")
            pause()
            return
        
        tab_id = get_user_input("Enter tab ID (lowercase, no spaces): ").strip().lower()
        if not tab_id:
            print_warning("Tab ID cannot be empty.")
            pause()
            return
        
        # Check if ID already exists
        if any(tab['id'] == tab_id for tab in self.tabs_config):
            print_error(f"Tab ID '{tab_id}' already exists.")
            pause()
            return
        
        # Choose color
        colors = [
            (Fore.WHITE, "White"),
            (Fore.RED, "Red"),
            (Fore.GREEN, "Green"),
            (Fore.BLUE, "Blue"),
            (Fore.YELLOW, "Yellow"),
            (Fore.MAGENTA, "Magenta"),
            (Fore.CYAN, "Cyan")
        ]
        
        print(f"\n{Fore.CYAN}Choose tab color:")
        for i, (color, name) in enumerate(colors, 1):
            print(f"{color}[{i}] {name}")
        
        color_choice = get_user_input(f"\n{Fore.YELLOW}Enter color number: ").strip()
        try:
            color_index = int(color_choice) - 1
            if 0 <= color_index < len(colors):
                selected_color = colors[color_index][0]
            else:
                selected_color = Fore.WHITE
        except ValueError:
            selected_color = Fore.WHITE
        
        # Create new tab
        new_tab = {
            "id": tab_id,
            "name": tab_name,
            "color": selected_color
        }
        
        # Find the color name for display
        color_name = "White"  # Default
        for color, name in colors:
            if color == selected_color:
                color_name = name
                break
        
        print(f"\n{Fore.CYAN}New tab preview:")
        print(f"  Name: {Fore.WHITE}{tab_name}")
        print(f"  ID: {Fore.WHITE}{tab_id}")
        print(f"  Color: {selected_color}{color_name}")
        
        if confirm_action("Create this tab?"):
            self.tabs_config.append(new_tab)
            save_tabs_config(self.tabs_config)
            print_success(f"Created new tab: {tab_name}")
        
        pause()

    def edit_tab(self):
        """Edit an existing tab"""
        clear_screen()
        print_header("EDIT TAB")
        
        if len(self.tabs_config) == 0:
            print_warning("No tabs to edit.")
            pause()
            return
        
        print(f"{Fore.CYAN}Select tab to edit:")
        for i, tab in enumerate(self.tabs_config, 1):
            games_count = len(self.filter_games_by_tab(tab['id']))
            tab_color = tab.get('color', Fore.WHITE)
            print(f"{tab_color}[{i:2d}] {tab['name']:<20} ({tab['id']:<15}) {games_count:3d} games")
        
        print_menu_option("B", "Back")
        
        choice = get_user_input(f"\n{Fore.YELLOW}Enter tab number: ").strip()
        
        if choice.upper() == "B":
            return
        
        try:
            tab_index = int(choice) - 1
            if 0 <= tab_index < len(self.tabs_config):
                self.edit_specific_tab(tab_index)
            else:
                print_error("Invalid tab number.")
                pause()
        except ValueError:
            print_error("Please enter a valid number.")
            pause()

    def edit_specific_tab(self, tab_index):
        """Edit a specific tab"""
        tab = self.tabs_config[tab_index]
        
        clear_screen()
        print_header(f"EDIT TAB: {tab['name']}")
        
        print(f"{Fore.CYAN}Current settings:")
        print(f"  Name: {Fore.WHITE}{tab['name']}")
        print(f"  ID: {Fore.WHITE}{tab['id']}")
        
        # Find the color name for display
        colors = [
            (Fore.WHITE, "White"),
            (Fore.RED, "Red"),
            (Fore.GREEN, "Green"),
            (Fore.BLUE, "Blue"),
            (Fore.YELLOW, "Yellow"),
            (Fore.MAGENTA, "Magenta"),
            (Fore.CYAN, "Cyan")
        ]
        color_name = "White"  # Default
        for color, name in colors:
            if color == tab.get('color', Fore.WHITE):
                color_name = name
                break
        
        print(f"  Color: {tab.get('color', Fore.WHITE)}{color_name}")
        
        print(f"\n{Fore.WHITE}{Style.BRIGHT}EDIT OPTIONS:")
        print_menu_option("1", "Change Name")
        print_menu_option("2", "Change Color")
        print_menu_option("B", "Back")
        
        choice = get_user_input(f"\n{Fore.YELLOW}Enter your choice: ").strip()
        
        if choice == "1":
            new_name = get_user_input("Enter new name: ").strip()
            if new_name:
                tab['name'] = new_name
                save_tabs_config(self.tabs_config)
                print_success(f"Tab name changed to: {new_name}")
            else:
                print_warning("Name cannot be empty.")
        elif choice == "2":
            colors = [
                (Fore.WHITE, "White"),
                (Fore.RED, "Red"),
                (Fore.GREEN, "Green"),
                (Fore.BLUE, "Blue"),
                (Fore.YELLOW, "Yellow"),
                (Fore.MAGENTA, "Magenta"),
                (Fore.CYAN, "Cyan")
            ]
            
            print(f"\n{Fore.CYAN}Choose new color:")
            for i, (color, name) in enumerate(colors, 1):
                print(f"{color}[{i}] {name}")
            
            color_choice = get_user_input(f"\n{Fore.YELLOW}Enter color number: ").strip()
            try:
                color_index = int(color_choice) - 1
                if 0 <= color_index < len(colors):
                    tab['color'] = colors[color_index][0]
                    save_tabs_config(self.tabs_config)
                    print_success("Tab color changed")
                else:
                    print_error("Invalid color number.")
            except ValueError:
                print_error("Please enter a valid number.")
        elif choice.upper() == "B":
            return
        else:
            print_error("Invalid choice.")
        
        pause()

    def delete_tab(self):
        """Delete a tab"""
        clear_screen()
        print_header("DELETE TAB")
        
        if len(self.tabs_config) == 0:
            print_warning("No tabs to delete.")
            pause()
            return
        
        print(f"{Fore.RED}⚠️  WARNING: This will permanently delete the tab and move all games to 'All' category!")
        print(f"{Fore.CYAN}Select tab to delete:")
        
        for i, tab in enumerate(self.tabs_config, 1):
            games_count = len(self.filter_games_by_tab(tab['id']))
            tab_color = tab.get('color', Fore.WHITE)
            print(f"{tab_color}[{i:2d}] {tab['name']:<20} ({tab['id']:<15}) {games_count:3d} games")
        
        print_menu_option("B", "Back")
        
        choice = get_user_input(f"\n{Fore.YELLOW}Enter tab number: ").strip()
        
        if choice.upper() == "B":
            return
        
        try:
            tab_index = int(choice) - 1
            if 0 <= tab_index < len(self.tabs_config):
                tab_to_delete = self.tabs_config[tab_index]
                
                if tab_to_delete['id'] == 'all':
                    print_error("Cannot delete the 'All' tab.")
                    pause()
                    return
                
                games_count = len(self.filter_games_by_tab(tab_to_delete['id']))
                
                print(f"\n{Fore.RED}⚠️  CONFIRM DELETION:")
                print(f"  Tab: {Fore.WHITE}{tab_to_delete['name']} ({tab_to_delete['id']})")
                print(f"  Games affected: {Fore.WHITE}{games_count}")
                print(f"  Action: {Fore.YELLOW}All games will be moved to 'All' category")
                
                if confirm_action(f"Are you SURE you want to delete '{tab_to_delete['name']}'?"):
                    # Move all games from this tab to 'all' category
                    moved_count = 0
                    for game in self.all_tags:
                        if game.get('category', 'all') == tab_to_delete['id']:
                            game['category'] = 'all'
                            # Update persistent settings
                            persistent = self.persistent_settings.get(game['docker_name'], {})
                            persistent['category'] = 'all'
                            self.persistent_settings[game['docker_name']] = persistent
                            moved_count += 1
                    
                    # Remove the tab
                    del self.tabs_config[tab_index]
                    save_tabs_config(self.tabs_config)
                    self.auto_save_all_data()
                    
                    print_success(f"Deleted tab '{tab_to_delete['name']}' and moved {moved_count} games to 'All' category")
                else:
                    print_info("Deletion cancelled.")
            else:
                print_error("Invalid tab number.")
                pause()
        except ValueError:
            print_error("Please enter a valid number.")
            pause()

    def user_management(self):
        print_warning('User management is not implemented yet.')
        pause()

    def custom_commands(self):
        print_warning('Custom commands (myLiners) is not implemented yet.')
        pause()

    def export_import(self):
        print_warning('Export/Import is not implemented yet.')
        pause()

    def settings_menu(self):
        print_warning('Settings menu is not implemented yet.')
        pause()

    def logout(self):
        print_success('Logged out successfully.')
        self.remove_active_user()
        self.running = False

    def export_selection(self):
        print_warning('Export selection is not implemented yet.')
        pause()

    def show_json_data_status(self):
        """Show status of all JSON data files"""
        clear_screen()
        print_header("JSON DATA STATUS")
        
        json_files = discover_json_files()
        
        print(f"{Fore.CYAN}Script Directory: {get_script_directory()}")
        print(f"{Fore.CYAN}Total JSON files found: {len(json_files)}\n")
        
        for filename, file_path in json_files.items():
            try:
                file_size = os.path.getsize(file_path)
                with open(file_path, 'r', encoding='utf-8') as f:
                    data = json.load(f)
                    if isinstance(data, dict):
                        item_count = len(data)
                    elif isinstance(data, list):
                        item_count = len(data)
                    else:
                        item_count = "data"
                
                print(f"{Fore.GREEN}✅ {filename:<25} {Fore.CYAN}({format_size(file_size)}) {Fore.WHITE}{item_count} items")
            except Exception as e:
                print(f"{Fore.RED}❌ {filename:<25} {Fore.RED}Error: {e}")
        
        print(f"\n{Fore.YELLOW}Auto-save: {'Enabled' if self.user_preferences.get('auto_save', True) else 'Disabled'}")
        print(f"{Fore.YELLOW}Last auto-save: {self.game_metadata.get('last_updated', 'Never')}")
        
        print(f"\n{Fore.WHITE}{Style.BRIGHT}ACTIONS:")
        print_menu_option("1", "Force Save All Data")
        print_menu_option("2", "Reload All Data")
        print_menu_option("3", "Export All Data")
        print_menu_option("B", "Back")
        
        choice = get_user_input(f"\n{Fore.YELLOW}Enter your choice: ").strip()
        
        if choice == "1":
            self.auto_save_all_data()
            print_success("All data saved!")
            pause()
        elif choice == "2":
            print_info("Reloading all data...")
            self.persistent_settings = load_settings()
            self.tabs_config = load_tabs_config()
            self.game_categories = load_game_categories()
            self.user_preferences = load_user_preferences()
            self.sync_history = load_sync_history()
            self.game_metadata = load_game_metadata()
            print_success("All data reloaded!")
            pause()
        elif choice == "3":
            self.export_all_data()
        elif choice.upper() == "B":
            return
        else:
            print_error("Invalid choice.")
            pause()

    def export_all_data(self):
        """Export all data to a backup file"""
        clear_screen()
        print_header("EXPORT ALL DATA")
        
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        backup_filename = f"backup_data_{timestamp}.json"
        
        all_data = {
            "export_timestamp": datetime.now().isoformat(),
            "user": self.username,
            "persistent_settings": self.persistent_settings,
            "tabs_config": self.tabs_config,
            "game_categories": self.game_categories,
            "user_preferences": self.user_preferences,
            "sync_history": self.sync_history,
            "game_metadata": self.game_metadata
        }
        
        if save_json_data(backup_filename, all_data):
            print_success(f"All data exported to {backup_filename}")
        else:
            print_error("Failed to export data")
        
        pause()

    def show_time_statistics(self):
        """Show time statistics for the current tab"""
        clear_screen()
        print_header(f"TIME STATISTICS: {self.get_tab_name(self.current_tab)}")
        
        tab_games = self.filter_games_by_tab(self.current_tab)
        
        if not tab_games:
            print_warning(f"No games in {self.get_tab_name(self.current_tab)} tab.")
            pause()
            return
        
        # Parse completion times
        total_hours = 0
        games_with_time = 0
        time_distribution = {
            "Short (< 10h)": 0,
            "Medium (10-30h)": 0,
            "Long (30-60h)": 0,
            "Very Long (> 60h)": 0,
            "Unknown": 0
        }
        
        for game in tab_games:
            time_str = game.get('approx_time', 'N/A')
            if time_str != 'N/A':
                try:
                    # Parse time string (e.g., "~27.5 hrs", "100 hrs")
                    time_str = time_str.replace('~', '').replace('hrs', '').replace('hours', '').strip()
                    if '-' in time_str:
                        time_str = time_str.split('-')[1].strip()
                    hours = float(time_str)
                    total_hours += hours
                    games_with_time += 1
                    
                    # Categorize by length
                    if hours < 10:
                        time_distribution["Short (< 10h)"] += 1
                    elif hours < 30:
                        time_distribution["Medium (10-30h)"] += 1
                    elif hours < 60:
                        time_distribution["Long (30-60h)"] += 1
                    else:
                        time_distribution["Very Long (> 60h)"] += 1
                except:
                    time_distribution["Unknown"] += 1
            else:
                time_distribution["Unknown"] += 1
        
        # Display statistics
        print(f"{Fore.CYAN}Total Games: {Fore.WHITE}{len(tab_games)}")
        print(f"{Fore.CYAN}Games with Time Data: {Fore.WHITE}{games_with_time}")
        print(f"{Fore.CYAN}Games without Time Data: {Fore.WHITE}{len(tab_games) - games_with_time}")
        
        if games_with_time > 0:
            avg_hours = total_hours / games_with_time
            print(f"{Fore.MAGENTA}Total Completion Time: {Fore.WHITE}{total_hours:.1f} hours")
            print(f"{Fore.MAGENTA}Average Time per Game: {Fore.WHITE}{avg_hours:.1f} hours")
            
            # Convert to days for long games
            total_days = total_hours / 24
            if total_days > 1:
                print(f"{Fore.MAGENTA}Total Time in Days: {Fore.WHITE}{total_days:.1f} days")
        
        print(f"\n{Fore.YELLOW}Time Distribution:")
        for category, count in time_distribution.items():
            if count > 0:
                percentage = (count / len(tab_games)) * 100
                color = Fore.GREEN if "Short" in category else Fore.YELLOW if "Medium" in category else Fore.RED if "Long" in category else Fore.CYAN
                print(f"  {color}{category}: {Fore.WHITE}{count} games ({percentage:.1f}%)")
        
        # Show selected games time if any
        if self.selected_tag_names:
            selected_games = [g for g in tab_games if g['docker_name'] in self.selected_tag_names]
            selected_hours = 0
            selected_with_time = 0
            
            for game in selected_games:
                time_str = game.get('approx_time', 'N/A')
                if time_str != 'N/A':
                    try:
                        time_str = time_str.replace('~', '').replace('hrs', '').replace('hours', '').strip()
                        if '-' in time_str:
                            time_str = time_str.split('-')[1].strip()
                        hours = float(time_str)
                        selected_hours += hours
                        selected_with_time += 1
                    except:
                        pass
            
            if selected_with_time > 0:
                print(f"\n{Fore.GREEN}Selected Games Time: {Fore.WHITE}{selected_hours:.1f} hours ({selected_with_time} games)")
        
        print(f"\n{Fore.WHITE}{Style.BRIGHT}ACTIONS:")
        print_menu_option("1", "Sort by Completion Time")
        print_menu_option("2", "Show Short Games (< 10h)")
        print_menu_option("3", "Show Long Games (> 30h)")
        print_menu_option("B", "Back")
        
        choice = get_user_input(f"\n{Fore.YELLOW}Enter your choice: ").strip()
        
        if choice == "1":
            self.sort_by_time(reverse=False)
            print_success("Sorted by completion time (shortest first)")
            pause()
        elif choice == "2":
            short_games = [g for g in tab_games if self.parse_time_hours(g.get('approx_time', 'N/A')) < 10]
            if short_games:
                self.browse_games_list(short_games, "Short Games (< 10h)")
            else:
                print_warning("No short games found.")
                pause()
        elif choice == "3":
            long_games = [g for g in tab_games if self.parse_time_hours(g.get('approx_time', 'N/A')) > 30]
            if long_games:
                self.browse_games_list(long_games, "Long Games (> 30h)")
            else:
                print_warning("No long games found.")
                pause()
        elif choice.upper() == "B":
            return
        else:
            print_error("Invalid choice.")
            pause()

    def parse_time_hours(self, time_str):
        """Parse time string to hours"""
        if time_str == 'N/A':
            return 0
        try:
            time_str = time_str.replace('~', '').replace('hrs', '').replace('hours', '').replace('hr', '').strip()
            time_str = time_str.replace('(est.)', '').replace('(est)', '').strip()
            
            # Handle ranges like "10-15 hrs" - take the average
            if '-' in time_str or '–' in time_str:
                time_str = time_str.replace('–', '-')
                parts = time_str.split('-')
                if len(parts) == 2:
                    try:
                        start = float(parts[0].strip())
                        end = float(parts[1].strip())
                        return (start + end) / 2  # Return average
                    except:
                        return float(parts[1].strip())  # Return end value if start fails
            
            # Handle single values
            return float(time_str)
        except:
            return 0

    def browse_games_list(self, games, title):
        """Browse a specific list of games"""
        while True:
            result = display_games_in_grid(
                games, 
                title,
                games_per_row=3,
                show_selection=True,
                selected_tags=self.selected_tag_names,
                app_instance=self
            )
            
            if result is None:
                break
            elif isinstance(result, tuple):
                action, game = result
                if action == "toggle" and game:
                    self.toggle_game_selection(game)
                    print_success(f"Toggled selection for {game['alias']}")
                    time.sleep(0.5)
                elif action == "run_selected":
                    if self.is_guest:
                        print_warning("Docker sync is disabled in Guest Mode.")
                        pause()
                    elif self.selected_tag_names:
                        self.run_selected_games()
                    else:
                        print_warning("No games selected.")
                        pause()
                elif action == "add_game":
                    self.add_game_to_current_tab()
                elif action == "select_all":
                    for g in games:
                        self.selected_tag_names.add(g['docker_name'])
                    print_success(f"Selected all {len(games)} games.")
                    time.sleep(0.5)
                elif action == "deselect_all":
                    for g in games:
                        self.selected_tag_names.discard(g['docker_name'])
                    print_success(f"Deselected all games.")
                    time.sleep(0.5)
            else:
                self.show_game_details(result)

    def move_tags_to_tab(self):
        """Move selected tags to a specific tab"""
        clear_screen()
        print_header("MOVE TAGS TO TAB")
        
        # Get all games and sort by oldest first (by last_updated date)
        all_games = self.all_tags.copy()
        
        # Custom sorting: games with category "all" go to bottom, then sort by date
        def custom_sort_key(game):
            category = game.get('category', 'all')
            date_obj = parse_date(game.get('last_updated', ''))
            # If category is "all", give it a very high date value to push it to bottom
            if category == 'all':
                return (1, date_obj)  # 1 means "all" category goes last
            else:
                return (0, date_obj)  # 0 means specific category goes first
        
        all_games.sort(key=custom_sort_key, reverse=False)  # Oldest first within each group
        
        if not all_games:
            print_warning("No games available.")
            pause()
            return
        
        print(f"{Fore.CYAN}All games ({len(all_games)} total) - ordered by oldest first, uncategorized games at bottom:")
        print()
        
        # Show all games with their current tab names
        for i, game in enumerate(all_games, 1):
            last_updated = game.get('last_updated', 'Unknown')
            current_tab_name = self.get_tab_name(game.get('category', 'all'))
            current_tab_color = self.get_tab_color(game.get('category', 'all'))
            
            # Format the date for display
            try:
                date_obj = parse_date(last_updated)
                if date_obj != datetime.min:
                    formatted_date = date_obj.strftime("%Y-%m-%d")
                else:
                    formatted_date = "Unknown"
            except:
                formatted_date = "Unknown"
            
            print(f"{Fore.YELLOW}[{i:3d}]{Fore.WHITE} {game['alias']:<30} {Fore.CYAN}({game['docker_name']}) {current_tab_color}[{current_tab_name}] {Fore.MAGENTA}{formatted_date}")
        
        print()
        print(f"{Fore.GREEN}Instructions:")
        print(f"{Fore.WHITE}  • Type tag names separated by spaces (e.g., 'witcher3 eldenring fallout4')")
        print(f"{Fore.WHITE}  • Or type game numbers separated by spaces (e.g., '1 5 10')")
        print(f"{Fore.WHITE}  • Or type 'all' to select all games")
        print()
        
        tag_input = get_user_input(f"{Fore.YELLOW}Enter tag names or numbers: ").strip()
        
        if not tag_input:
            print_warning("No input provided.")
            pause()
            return
        
        # Parse the input to find selected games
        selected_games = []
        
        if tag_input.lower() == 'all':
            selected_games = all_games
        else:
            # Split by spaces
            input_parts = tag_input.split()
            
            for part in input_parts:
                part = part.strip()
                if not part:
                    continue
                
                # Check if it's a number
                if part.isdigit():
                    try:
                        game_index = int(part) - 1
                        if 0 <= game_index < len(all_games):
                            selected_games.append(all_games[game_index])
                        else:
                            print_warning(f"Invalid game number: {part}")
                    except ValueError:
                        print_warning(f"Invalid number: {part}")
                else:
                    # Search for game by name
                    found_game = None
                    for game in all_games:
                        if (part.lower() == game['docker_name'].lower() or 
                            part.lower() == game['alias'].lower() or
                            part.lower() in game['docker_name'].lower() or
                            part.lower() in game['alias'].lower()):
                            found_game = game
                            break
                    
                    if found_game:
                        selected_games.append(found_game)
                    else:
                        print_warning(f"Game not found: {part}")
        
        if not selected_games:
            print_warning("No valid games selected.")
            pause()
            return
        
        # Remove duplicates while preserving order
        seen = set()
        unique_selected_games = []
        for game in selected_games:
            if game['docker_name'] not in seen:
                seen.add(game['docker_name'])
                unique_selected_games.append(game)
        
        selected_games = unique_selected_games
        
        # Show selected games with their current tabs
        print(f"\n{Fore.CYAN}Selected games ({len(selected_games)}):")
        for i, game in enumerate(selected_games, 1):
            current_tab_name = self.get_tab_name(game.get('category', 'all'))
            current_tab_color = self.get_tab_color(game.get('category', 'all'))
            print(f"{Fore.YELLOW}[{i:2d}]{Fore.WHITE} {game['alias']:<30} {Fore.CYAN}({game['docker_name']}) {current_tab_color}[{current_tab_name}]")
        
        # Show available destination tabs
        print(f"\n{Fore.YELLOW}Select destination tab:")
        for i, tab in enumerate(self.tabs_config, 1):
            tab_color = tab.get('color', Fore.WHITE)
            games_count = len(self.filter_games_by_tab(tab['id']))
            print(f"{tab_color}[{i:2d}] {tab['name']:<20} ({games_count} games)")
        
        print_menu_option("B", "Back")
        
        tab_choice = get_user_input(f"\n{Fore.YELLOW}Enter tab number: ").strip()
        
        if tab_choice.upper() == "B":
            return
        
        try:
            tab_index = int(tab_choice) - 1
            if 0 <= tab_index < len(self.tabs_config):
                new_tab = self.tabs_config[tab_index]
                
                if confirm_action(f"Move {len(selected_games)} games to {new_tab['name']}?"):
                    moved_count = 0
                    for game in selected_games:
                        old_category = game.get('category', 'all')
                        if old_category != new_tab['id']:
                            game['category'] = new_tab['id']
                            # Update persistent settings
                            persistent = self.persistent_settings.get(game['docker_name'], {})
                            persistent['category'] = new_tab['id']
                            self.persistent_settings[game['docker_name']] = persistent
                            moved_count += 1
                    
                    # Auto-save all data
                    self.auto_save_all_data()
                    
                    print_success(f"Successfully moved {moved_count} games to {new_tab['name']}")
                    if moved_count < len(selected_games):
                        print_info(f"{len(selected_games) - moved_count} games were already in {new_tab['name']}")
                    
                    # Remove moved games from current selection if they were selected
                    for game in selected_games:
                        self.selected_tag_names.discard(game['docker_name'])
                    
                    print_info("Changes have been saved for next run!")
                else:
                    print_info("Operation cancelled.")
            else:
                print_error("Invalid tab number.")
        except ValueError:
            print_error("Please enter a valid number.")
        
        pause()

    def search_and_select_games(self):
        """Search for games and return selected ones"""
        clear_screen()
        print_header("SEARCH AND SELECT GAMES")
        
        search_term = get_user_input("Enter search term: ").strip().lower()
        if not search_term:
            return []
        
        matching_games = [game for game in self.all_tags if search_term in game['alias'].lower() or search_term in game['docker_name'].lower()]
        
        if not matching_games:
            print_warning(f"No games found matching '{search_term}'.")
            pause()
            return []
        
        print(f"\n{Fore.CYAN}Found {len(matching_games)} matching games:")
        for i, game in enumerate(matching_games, 1):
            current_tab = self.get_tab_name(game.get('category', 'all'))
            print(f"{Fore.YELLOW}[{i:2d}]{Fore.WHITE} {game['alias']:<25} {Fore.CYAN}[{current_tab}]")
        
        print_menu_option("A", "Select All")
        print_menu_option("B", "Back")
        
        choice = get_user_input(f"\n{Fore.YELLOW}Enter game numbers separated by spaces: ").strip()
        
        if choice.upper() == "B":
            return []
        elif choice.upper() == "A":
            return matching_games
        
        try:
            game_indices = [int(num) - 1 for num in choice.split()]
            selected_games = [matching_games[i] for i in game_indices if 0 <= i < len(matching_games)]
            return selected_games
        except ValueError:
            print_error("Invalid game numbers entered.")
            pause()
            return []

    def select_from_all_games(self):
        """Select from all games"""
        clear_screen()
        print_header("SELECT FROM ALL GAMES")
        
        print(f"{Fore.CYAN}All games ({len(self.all_tags)}):")
        for i, game in enumerate(self.all_tags, 1):
            current_tab = self.get_tab_name(game.get('category', 'all'))
            print(f"{Fore.YELLOW}[{i:3d}]{Fore.WHITE} {game['alias']:<25} {Fore.CYAN}[{current_tab}]")
        
        print_menu_option("A", "Select All")
        print_menu_option("B", "Back")
        
        choice = get_user_input(f"\n{Fore.YELLOW}Enter game numbers separated by spaces: ").strip()
        
        if choice.upper() == "B":
            return []
        elif choice.upper() == "A":
            return self.all_tags
        
        try:
            game_indices = [int(num) - 1 for num in choice.split()]
            selected_games = [self.all_tags[i] for i in game_indices if 0 <= i < len(self.all_tags)]
            return selected_games
        except ValueError:
            print_error("Invalid game numbers entered.")
            pause()
            return []

    def show_uncategorized_tags(self):
        """Show tags that are not in any specific tab (only in 'all') in red, and available tabs in blue"""
        clear_screen()
        print_header("🔍 SHOW UNCATEGORIZED TAGS")
        
        # Find tags that are only in 'all' category (uncategorized)
        uncategorized_tags = []
        for tag in self.all_tags:
            category = tag.get('category', 'all')
            if category == 'all':
                # Check if this tag is actually in any other specific tab
                found_in_other_tabs = False
                for tab in self.tabs_config:
                    if tab['id'] != 'all':
                        # Check if this tag is assigned to this tab
                        if category == tab['id']:
                            found_in_other_tabs = True
                            break
                
                if not found_in_other_tabs:
                    uncategorized_tags.append(tag)
        
        print(f"{Fore.RED}Uncategorized tags (only in 'all' tab) - {len(uncategorized_tags)} found:")
        print(f"{Fore.RED}{'='*60}")
        
        if uncategorized_tags:
            for i, tag in enumerate(uncategorized_tags, 1):
                size = format_size(tag.get('full_size', 0))
                completion_time = tag.get('approx_time', 'N/A')
                print(f"{Fore.RED}[{i:3d}] {tag['alias']:<30} {Fore.CYAN}({tag['docker_name']}) {Fore.YELLOW}{size:<8} {Fore.MAGENTA}{completion_time}")
        else:
            print(f"{Fore.GREEN}✅ All tags are properly categorized!")
        
        print(f"\n{Fore.BLUE}Available tabs (categories):")
        print(f"{Fore.BLUE}{'='*40}")
        
        for i, tab in enumerate(self.tabs_config, 1):
            if tab['id'] != 'all':  # Don't show 'all' as a category option
                games_count = len(self.filter_games_by_tab(tab['id']))
                tab_color = tab.get('color', Fore.WHITE)
                print(f"{Fore.BLUE}[{i:2d}] {tab_color}{tab['name']:<20} {Fore.CYAN}({games_count} games)")
        
        print(f"\n{Fore.WHITE}{Style.BRIGHT}ACTIONS:")
        print_menu_option("1", "Move Uncategorized Tags to Tab")
        print_menu_option("2", "Select All Uncategorized Tags")
        print_menu_option("3", "Show Tags by Category")
        print_menu_option("B", "Back")
        
        choice = get_user_input(f"\n{Fore.YELLOW}Enter your choice: ").strip()
        
        if choice == "1":
            self.YOUR_CLIENT_SECRET_HERE(uncategorized_tags)
        elif choice == "2":
            if uncategorized_tags:
                for tag in uncategorized_tags:
                    self.selected_tag_names.add(tag['docker_name'])
                print_success(f"Selected {len(uncategorized_tags)} uncategorized tags.")
            else:
                print_warning("No uncategorized tags to select.")
        elif choice == "3":
            self.show_tags_by_category()
        elif choice.upper() == "B":
            return
        else:
            print_error("Invalid choice.")
        
        pause()

    def YOUR_CLIENT_SECRET_HERE(self, uncategorized_tags):
        """Move uncategorized tags to a specific tab"""
        if not uncategorized_tags:
            print_warning("No uncategorized tags to move.")
            return
        
        print(f"\n{Fore.CYAN}Select destination tab for {len(uncategorized_tags)} uncategorized tags:")
        
        # Show available tabs (excluding 'all')
        available_tabs = [tab for tab in self.tabs_config if tab['id'] != 'all']
        
        for i, tab in enumerate(available_tabs, 1):
            tab_color = tab.get('color', Fore.WHITE)
            print(f"{tab_color}[{i:2d}] {tab['name']}")
        
        print_menu_option("B", "Back")
        
        choice = get_user_input(f"\n{Fore.YELLOW}Enter tab number: ").strip()
        
        if choice.upper() == "B":
            return
        
        try:
            tab_index = int(choice) - 1
            if 0 <= tab_index < len(available_tabs):
                selected_tab = available_tabs[tab_index]
                
                if confirm_action(f"Move {len(uncategorized_tags)} uncategorized tags to '{selected_tab['name']}'?"):
                    moved_count = 0
                    for tag in uncategorized_tags:
                        tag['category'] = selected_tab['id']
                        # Update persistent settings
                        persistent = self.persistent_settings.get(tag['docker_name'], {})
                        persistent['category'] = selected_tab['id']
                        self.persistent_settings[tag['docker_name']] = persistent
                        moved_count += 1
                    
                    # Auto-save all data
                    self.auto_save_all_data()
                    
                    print_success(f"Moved {moved_count} uncategorized tags to {selected_tab['name']}")
                else:
                    print_info("Operation cancelled.")
            else:
                print_error("Invalid tab number.")
        except ValueError:
            print_error("Please enter a valid number.")

    def show_tags_by_category(self):
        """Show all tags organized by their categories"""
        clear_screen()
        print_header("📊 TAGS BY CATEGORY")
        
        for tab in self.tabs_config:
            games = self.filter_games_by_tab(tab['id'])
            tab_color = tab.get('color', Fore.WHITE)
            
            print(f"\n{tab_color}{Style.BRIGHT}{tab['name']} ({len(games)} games):")
            print(f"{tab_color}{'─' * (len(tab['name']) + 10)}")
            
            if games:
                for i, game in enumerate(games[:10], 1):  # Show first 10 games
                    print(f"{Fore.WHITE}  [{i:2d}] {game['alias']:<25} {Fore.CYAN}({game['docker_name']})")
                
                if len(games) > 10:
                    print(f"{Fore.YELLOW}  ... and {len(games) - 10} more games")
            else:
                print(f"{Fore.RED}  No games in this category")
        
        pause()

# ===== ENHANCED JSON DATA MANAGEMENT =====
def get_script_directory():
    """Get the directory where the script is located"""
    return os.path.dirname(os.path.abspath(__file__))

def discover_json_files():
    """Discover all JSON files in the script directory"""
    script_dir = get_script_directory()
    json_files = {}
    
    for filename in os.listdir(script_dir):
        if filename.endswith('.json'):
            file_path = os.path.join(script_dir, filename)
            json_files[filename] = file_path
    
    return json_files

def load_all_json_data():
    """Load all JSON data from files in the script directory"""
    json_files = discover_json_files()
    all_data = {}
    
    print_info(f"Discovering JSON files in {get_script_directory()}")
    
    for filename, file_path in json_files.items():
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                data = json.load(f)
                all_data[filename] = data
                print_success(f"Loaded {filename}: {len(data) if isinstance(data, (list, dict)) else 'data'} items")
        except Exception as e:
            print_error(f"Error loading {filename}: {e}")
            all_data[filename] = {}
    
    return all_data

def save_json_data(filename, data):
    """Save data to a JSON file in the script directory"""
    script_dir = get_script_directory()
    file_path = os.path.join(script_dir, filename)
    
    try:
        with open(file_path, 'w', encoding='utf-8') as f:
            json.dump(data, f, indent=2, ensure_ascii=False)
        print_success(f"Saved {filename}")
        return True
    except Exception as e:
        print_error(f"Error saving {filename}: {e}")
        return False

def auto_save_data(data_type, data):
    """Automatically save data with proper filename"""
    filename_mapping = {
        'settings': 'tag_settings.json',
        'tabs': 'tabs_config.json',
        'banned_users': 'banned_users.json',
        'active_users': 'active_users.json',
        'custom_buttons': 'custom_buttons.json',
        'game_categories': 'game_categories.json',
        'user_preferences': 'user_preferences.json',
        'sync_history': 'sync_history.json',
        'game_metadata': 'game_metadata.json'
    }
    
    filename = filename_mapping.get(data_type, f'{data_type}.json')
    return save_json_data(filename, data)

def YOUR_CLIENT_SECRET_HERE(filename, default_data):
    """Load JSON data or create with default if file doesn't exist"""
    script_dir = get_script_directory()
    file_path = os.path.join(script_dir, filename)
    
    if os.path.exists(file_path):
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                return json.load(f)
        except Exception as e:
            print_error(f"Error loading {filename}: {e}")
    
    # Create file with default data
    save_json_data(filename, default_data)
    return default_data

# Enhanced data structures
GAME_CATEGORIES_DATA = {
    "categories": {
        "all": {"name": "All", "description": "All games", "color": "white"},
        "finished": {"name": "Finished", "description": "Completed games", "color": "green"},
        "mybackup": {"name": "MyBackup", "description": "Personal backups", "color": "blue"},
        "not_for_me": {"name": "meh", "description": "Not interested", "color": "red"},
        "soulslike": {"name": "SoulsLike", "description": "Souls-like games", "color": "magenta"},
        "localcoop": {"name": "LocalCoop", "description": "Local co-op games", "color": "yellow"},
        "oporationsystems": {"name": "OporationSystems", "description": "Operating system games", "color": "cyan"},
        "music": {"name": "music", "description": "Music games", "color": "green"},
        "simulators": {"name": "simulators", "description": "Simulation games", "color": "blue"},
        "tvshows": {"name": "repeat", "description": "TV show games", "color": "magenta"},
        "bulkgames": {"name": "BulkGames", "description": "Bulk game collections", "color": "yellow"},
        "nintendo/switch": {"name": "Nintendo/Switch", "description": "Nintendo Switch games", "color": "red"},
        "shooters": {"name": "shooters", "description": "Shooter games", "color": "cyan"},
        "openworld": {"name": "OpenWorld", "description": "Open world games", "color": "green"},
        "hacknslash": {"name": "HackNslash", "description": "Hack and slash games", "color": "blue"},
        "chill": {"name": "Chill", "description": "Chill/relaxing games", "color": "magenta"},
        "storydriven": {"name": "StoryDriven", "description": "Story-driven games", "color": "yellow"},
        "platformers": {"name": "platformers", "description": "Platformer games", "color": "cyan"}
    },
    "game_assignments": {}
}

USER_PREFERENCES_DATA = {
    "default_destination": "~/Games",
    "auto_save": True,
    "show_sizes": True,
    "games_per_row": 4,
    "theme": "default",
    "notifications": True,
    "auto_refresh": True
}

SYNC_HISTORY_DATA = {
    "syncs": [],
    "statistics": {
        "total_syncs": 0,
        "successful_syncs": 0,
        "failed_syncs": 0,
        "total_data_synced": 0
    }
}

GAME_METADATA_DATA = {
    "last_updated": "",
    "total_games": 0,
    "categories": {},
    "popular_tags": [],
    "recent_additions": []
}

# ===== ENHANCED FILE PERSISTENCE FUNCTIONS =====

if __name__ == "__main__":
    print("\n==== MICHAEL FEDRO'S BACKUP & RESTORE TOOL ====")
    
    # Check if user is already logged in
    active_users = load_active_users()
    current_time = time.time()
    session_timeout = 3600  # 1 hour timeout
    
    # Check for active sessions
    active_session = None
    for username, session_data in active_users.items():
        login_time = session_data.get('login_time', 0)
        if current_time - login_time < session_timeout:
            active_session = username
            break
    
    if active_session:
        print(f"\n{Fore.GREEN}Welcome back, {active_session}!")
        print(f"{Fore.CYAN}You are already logged in from a previous session.")
        
        # Automatically continue with existing session
        username = active_session
        password = ""  # No password needed for existing session
        is_admin = username.lower() in ["michadockermisha", "misha"]
        is_guest = False
        
        print_success(f"Continuing session as {username}")
    else:
        # Load saved username if exists
        saved_username = None
        try:
            if os.path.exists('user_credentials.json'):
                with open('user_credentials.json', 'r') as f:
                    creds = json.load(f)
                    saved_username = creds.get('username')
        except:
            pass
        
        print(f"\n{Fore.CYAN}Login Options:")
        if saved_username:
            print_menu_option("1", f"Login as {saved_username} (saved)")
            print_menu_option("2", "Login with different username")
            print_menu_option("3", "Run as Guest (no Docker sync)")
            print_menu_option("Q", "Quit")
            
            choice = get_user_input(f"\n{Fore.YELLOW}Enter your choice: ").strip()
            
            if choice == "1":
                username = saved_username
                password = input("Enter your Docker password: ").strip()
                is_admin = username.lower() == "michadockermisha"
                is_guest = False
            elif choice == "2":
                username = input("Enter your username: ").strip()
                password = input("Enter your Docker password: ").strip()
                is_admin = username.lower() in ["michadockermisha", "misha"]
                is_guest = False
            elif choice == "3":
                username = "guest_user"
                password = ""
                is_admin = False
                is_guest = True
            elif choice.upper() == "Q":
                print("Goodbye!")
                exit(0)
            else:
                print_error("Invalid choice.")
                exit(1)
        else:
            print_menu_option("1", "Login with username")
            print_menu_option("2", "Run as Guest (no Docker sync)")
            print_menu_option("Q", "Quit")
            
            choice = get_user_input(f"\n{Fore.YELLOW}Enter your choice: ").strip()
            
            if choice == "1":
                username = input("Enter your username: ").strip()
                password = input("Enter your Docker password: ").strip()
                is_admin = username.lower() in ["michadockermisha", "misha"]
                is_guest = False
            elif choice == "2":
                username = "guest_user"
                password = ""
                is_admin = False
                is_guest = True
            elif choice.upper() == "Q":
                print("Goodbye!")
                exit(0)
            else:
                print_error("Invalid choice.")
                exit(1)
        
        # Save username for next run (if not guest)
        if not is_guest and username != "guest_user":
            try:
                creds = {"username": username}
                with open('user_credentials.json', 'w') as f:
                    json.dump(creds, f)
            except:
                pass
    
    if is_guest:
        print(f"\n{Fore.YELLOW}Running in Guest Mode - Docker sync features will be disabled")
        print(f"{Fore.CYAN}You can browse games and manage selections, but cannot sync to Docker")
    
    app = YOUR_CLIENT_SECRET_HERE(login_password=password, is_admin=is_admin, username=username)
    app.is_guest = is_guest  # Add guest flag to app
    app.show_enhanced_main_menu()
    