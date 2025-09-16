#!/usr/bin/env python3
"""
Everything CLI - Terminal-based file search utility
Similar to Windows 'Everything' app but runs in terminal
"""

import argparse
import os
import sys
import time
from pathlib import Path
from typing import List, Optional, Tuple
import sqlite3
import re
import fnmatch
from datetime import datetime, timedelta
import threading
import signal
from dataclasses import dataclass
from collections import defaultdict

# Color codes for terminal output
class Colors:
    HEADER = '\033[95m'
    OKBLUE = '\033[94m'
    OKCYAN = '\033[96m'
    OKGREEN = '\033[92m'
    WARNING = '\033[93m'
    FAIL = '\033[91m'
    ENDC = '\033[0m'
    BOLD = '\033[1m'
    UNDERLINE = '\033[4m'

@dataclass
class FileEntry:
    """Represents a file or directory entry"""
    path: str
    name: str
    size: int
    modified_time: float
    is_directory: bool
    extension: str

class DatabaseManager:
    """Manages SQLite database for file indexing"""
    
    def __init__(self, db_path: str = "everything_cli.db"):
        self.db_path = db_path
        self.init_database()
    
    def init_database(self):
        """Initialize the database with required tables"""
        with sqlite3.connect(self.db_path) as conn:
            conn.execute("""
                CREATE TABLE IF NOT EXISTS files (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    path TEXT UNIQUE NOT NULL,
                    name TEXT NOT NULL,
                    size INTEGER NOT NULL,
                    modified_time REAL NOT NULL,
                    is_directory BOOLEAN NOT NULL,
                    extension TEXT,
                    indexed_time REAL NOT NULL
                )
            """)
            conn.execute("CREATE INDEX IF NOT EXISTS idx_name ON files(name)")
            conn.execute("CREATE INDEX IF NOT EXISTS idx_path ON files(path)")
            conn.execute("CREATE INDEX IF NOT EXISTS idx_extension ON files(extension)")
            conn.execute("CREATE INDEX IF NOT EXISTS idx_size ON files(size)")
            conn.execute("CREATE INDEX IF NOT EXISTS idx_modified ON files(modified_time)")
    
    def add_file(self, file_entry: FileEntry):
        """Add or update a file entry in the database"""
        with sqlite3.connect(self.db_path) as conn:
            conn.execute("""
                INSERT OR REPLACE INTO files 
                (path, name, size, modified_time, is_directory, extension, indexed_time)
                VALUES (?, ?, ?, ?, ?, ?, ?)
            """, (
                file_entry.path,
                file_entry.name,
                file_entry.size,
                file_entry.modified_time,
                file_entry.is_directory,
                file_entry.extension,
                time.time()
            ))
    
    def search_files(self, query: str, limit: int = 100, **filters) -> List[FileEntry]:
        """Search for files matching the query with optional filters"""
        sql = """
            SELECT path, name, size, modified_time, is_directory, extension
            FROM files
            WHERE name LIKE ?
        """
        params = [f"%{query}%"]
        
        # Add filters
        if filters.get('extension'):
            sql += " AND extension = ?"
            params.append(filters['extension'].lower())
        
        if filters.get('min_size') is not None:
            sql += " AND size >= ?"
            params.append(filters['min_size'])
        
        if filters.get('max_size') is not None:
            sql += " AND size <= ?"
            params.append(filters['max_size'])
        
        if filters.get('directories_only'):
            sql += " AND is_directory = 1"
        elif filters.get('files_only'):
            sql += " AND is_directory = 0"
        
        if filters.get('modified_after'):
            sql += " AND modified_time > ?"
            params.append(filters['modified_after'])
        
        if filters.get('modified_before'):
            sql += " AND modified_time < ?"
            params.append(filters['modified_before'])
        
        # Handle ordering
        order_by = "name"
        if filters.get('order_by_size'):
            order_by = "size DESC, name"
        elif filters.get('order_by_date'):
            order_by = "modified_time DESC, name"
        
        sql += f" ORDER BY {order_by} LIMIT {limit}"
        
        with sqlite3.connect(self.db_path) as conn:
            cursor = conn.execute(sql, params)
            results = []
            for row in cursor.fetchall():
                results.append(FileEntry(*row))
            return results
    
    def list_all_files(self, limit: int = 1000, **filters) -> List[FileEntry]:
        """List all files in the database with optional filters"""
        sql = """
            SELECT path, name, size, modified_time, is_directory, extension
            FROM files
            WHERE 1=1
        """
        params = []
        
        # Add filters
        if filters.get('extension'):
            sql += " AND extension = ?"
            params.append(filters['extension'].lower())
        
        if filters.get('min_size') is not None:
            sql += " AND size >= ?"
            params.append(filters['min_size'])
        
        if filters.get('max_size') is not None:
            sql += " AND size <= ?"
            params.append(filters['max_size'])
        
        if filters.get('directories_only'):
            sql += " AND is_directory = 1"
        elif filters.get('files_only'):
            sql += " AND is_directory = 0"
        
        if filters.get('modified_after'):
            sql += " AND modified_time > ?"
            params.append(filters['modified_after'])
        
        if filters.get('modified_before'):
            sql += " AND modified_time < ?"
            params.append(filters['modified_before'])
        
        # Handle ordering
        order_by = "name"
        if filters.get('order_by_size'):
            order_by = "size DESC, name"
        elif filters.get('order_by_date'):
            order_by = "modified_time DESC, name"
        
        sql += f" ORDER BY {order_by} LIMIT {limit}"
        
        with sqlite3.connect(self.db_path) as conn:
            cursor = conn.execute(sql, params)
            results = []
            for row in cursor.fetchall():
                results.append(FileEntry(*row))
            return results
    
    def get_stats(self) -> dict:
        """Get database statistics"""
        with sqlite3.connect(self.db_path) as conn:
            cursor = conn.execute("SELECT COUNT(*) FROM files")
            total_files = cursor.fetchone()[0]
            
            cursor = conn.execute("SELECT COUNT(*) FROM files WHERE is_directory = 1")
            total_dirs = cursor.fetchone()[0]
            
            cursor = conn.execute("SELECT SUM(size) FROM files WHERE is_directory = 0")
            total_size = cursor.fetchone()[0] or 0
            
            return {
                'total_files': total_files - total_dirs,
                'total_directories': total_dirs,
                'total_size': total_size,
                'total_entries': total_files
            }
    
    def is_c_drive_indexed(self) -> bool:
        """Check if C drive has been indexed"""
        with sqlite3.connect(self.db_path) as conn:
            cursor = conn.execute("SELECT COUNT(*) FROM files WHERE path LIKE 'C:\\%' OR path LIKE 'C:/%'")
            c_drive_files = cursor.fetchone()[0]
            return c_drive_files > 100  # Assume indexed if more than 100 C drive files found
    
    def clear_database(self):
        """Clear all entries from the database"""
        with sqlite3.connect(self.db_path) as conn:
            conn.execute("DELETE FROM files")

class FileIndexer:
    """Indexes files and directories"""
    
    def __init__(self, db_manager: DatabaseManager):
        self.db_manager = db_manager
        self.should_stop = False
        self.indexed_count = 0
        self.start_time = None
    
    def stop(self):
        """Stop the indexing process"""
        self.should_stop = True
    
    def index_directory(self, directory: str, show_progress: bool = True):
        """Index all files in a directory recursively"""
        self.should_stop = False
        self.indexed_count = 0
        self.start_time = time.time()
        
        directory = os.path.abspath(directory)
        
        if show_progress:
            print(f"{Colors.OKBLUE}Indexing directory: {directory}{Colors.ENDC}")
        
        try:
            for root, dirs, files in os.walk(directory):
                if self.should_stop:
                    break
                
                # Index directories
                for dir_name in dirs:
                    if self.should_stop:
                        break
                    
                    dir_path = os.path.join(root, dir_name)
                    try:
                        stat = os.stat(dir_path)
                        file_entry = FileEntry(
                            path=dir_path,
                            name=dir_name,
                            size=0,
                            modified_time=stat.st_mtime,
                            is_directory=True,
                            extension=""
                        )
                        self.db_manager.add_file(file_entry)
                        self.indexed_count += 1
                        
                        if show_progress and self.indexed_count % 1000 == 0:
                            print(f"\rIndexed {self.indexed_count} items...", end="", flush=True)
                    
                    except (OSError, PermissionError):
                        continue
                
                # Index files
                for file_name in files:
                    if self.should_stop:
                        break
                    
                    file_path = os.path.join(root, file_name)
                    try:
                        stat = os.stat(file_path)
                        extension = os.path.splitext(file_name)[1].lower()
                        
                        file_entry = FileEntry(
                            path=file_path,
                            name=file_name,
                            size=stat.st_size,
                            modified_time=stat.st_mtime,
                            is_directory=False,
                            extension=extension
                        )
                        self.db_manager.add_file(file_entry)
                        self.indexed_count += 1
                        
                        if show_progress and self.indexed_count % 1000 == 0:
                            print(f"\rIndexed {self.indexed_count} items...", end="", flush=True)
                    
                    except (OSError, PermissionError):
                        continue
        
        except KeyboardInterrupt:
            print(f"\n{Colors.WARNING}Indexing interrupted by user{Colors.ENDC}")
            return
        
        elapsed_time = time.time() - self.start_time
        if show_progress:
            print(f"\n{Colors.OKGREEN}Indexing completed!{Colors.ENDC}")
            print(f"Indexed {self.indexed_count:,} items in {elapsed_time:.2f} seconds")

class EverythingCLI:
    """Main CLI application class"""
    
    def __init__(self):
        self.db_manager = DatabaseManager()
        self.indexer = FileIndexer(self.db_manager)
        self.setup_signal_handlers()
    
    def setup_signal_handlers(self):
        """Setup signal handlers for graceful shutdown"""
        def signal_handler(signum, frame):
            print(f"\n{Colors.WARNING}Stopping...{Colors.ENDC}")
            self.indexer.stop()
            sys.exit(0)
        
        signal.signal(signal.SIGINT, signal_handler)
        if hasattr(signal, 'SIGTERM'):
            signal.signal(signal.SIGTERM, signal_handler)
    
    def format_size(self, size: int) -> str:
        """Format file size in human readable format"""
        for unit in ['B', 'KB', 'MB', 'GB', 'TB']:
            if size < 1024.0:
                return f"{size:3.1f} {unit}"
            size /= 1024.0
        return f"{size:.1f} PB"
    
    def format_time(self, timestamp: float) -> str:
        """Format timestamp in readable format"""
        dt = datetime.fromtimestamp(timestamp)
        return dt.strftime("%Y-%m-%d %H:%M:%S")
    
    def print_results(self, results: List[FileEntry], query: str = None, show_details: bool = False, show_size_ranking: bool = False):
        """Print search results"""
        if not results:
            if query:
                print(f"{Colors.WARNING}No results found for '{query}'{Colors.ENDC}")
            else:
                print(f"{Colors.WARNING}No files found{Colors.ENDC}")
            return
        
        if query:
            print(f"\n{Colors.OKGREEN}Found {len(results)} results for '{query}':{Colors.ENDC}\n")
        else:
            print(f"\n{Colors.OKGREEN}Showing {len(results)} files:{Colors.ENDC}\n")
        
        # If showing size ranking, display header
        if show_size_ranking and show_details:
            print(f"{Colors.HEADER}{'Size':>12} {'Type':>4} {'Name':<50} {'Path'}{Colors.ENDC}")
            print("-" * 120)
        
        for i, entry in enumerate(results, 1):
            # Color code based on file type
            if entry.is_directory:
                color = Colors.OKBLUE
                icon = "📁"
            else:
                color = Colors.ENDC
                icon = "📄"
            
            if show_details:
                size_str = "DIR" if entry.is_directory else self.format_size(entry.size)
                time_str = self.format_time(entry.modified_time)
                
                if show_size_ranking:
                    # Compact format for size ranking
                    print(f"{size_str:>12} {icon} {color}{entry.name:<50}{Colors.ENDC} {entry.path}")
                else:
                    print(f"{icon} {color}{entry.name}{Colors.ENDC}")
                    print(f"   Path: {entry.path}")
                    print(f"   Size: {size_str:>10} | Modified: {time_str}")
                    print()
            else:
                if show_size_ranking and not entry.is_directory:
                    size_str = self.format_size(entry.size)
                    print(f"{size_str:>12} {icon} {color}{entry.name}{Colors.ENDC} - {entry.path}")
                else:
                    print(f"{icon} {color}{entry.name}{Colors.ENDC} - {entry.path}")
    
    def interactive_search(self):
        """Interactive search mode"""
        print(f"{Colors.HEADER}Everything CLI - Interactive Search Mode{Colors.ENDC}")
        print("Type your search query (or 'quit' to exit):")
        print("Commands: :stats, :clear, :index <path>, :list-by-size, :list-all, :help")
        print()
        
        while True:
            try:
                query = input(f"{Colors.OKCYAN}Search> {Colors.ENDC}").strip()
                
                if query.lower() in ['quit', 'exit', 'q']:
                    break
                
                if query.startswith(':'):
                    self.handle_command(query[1:])
                    continue
                
                if not query:
                    continue
                
                start_time = time.time()
                results = self.db_manager.search_files(query, limit=50)
                search_time = time.time() - start_time
                
                self.print_results(results, query)
                print(f"\n{Colors.OKBLUE}Search completed in {search_time*1000:.1f}ms{Colors.ENDC}")
                
            except KeyboardInterrupt:
                print(f"\n{Colors.WARNING}Exiting...{Colors.ENDC}")
                break
            except EOFError:
                break
    
    def handle_command(self, command: str):
        """Handle special commands"""
        parts = command.split()
        cmd = parts[0].lower()
        
        if cmd == 'stats':
            stats = self.db_manager.get_stats()
            print(f"\n{Colors.HEADER}Database Statistics:{Colors.ENDC}")
            print(f"Files: {stats['total_files']:,}")
            print(f"Directories: {stats['total_directories']:,}")
            print(f"Total entries: {stats['total_entries']:,}")
            print(f"Total size: {self.format_size(stats['total_size'])}")
        
        elif cmd == 'clear':
            confirm = input("Are you sure you want to clear the database? (y/N): ")
            if confirm.lower() == 'y':
                self.db_manager.clear_database()
                print(f"{Colors.OKGREEN}Database cleared{Colors.ENDC}")
        
        elif cmd == 'index':
            if len(parts) > 1:
                path = ' '.join(parts[1:])
                if os.path.exists(path):
                    self.indexer.index_directory(path)
                else:
                    print(f"{Colors.FAIL}Path does not exist: {path}{Colors.ENDC}")
            else:
                print(f"{Colors.WARNING}Usage: :index <path>{Colors.ENDC}")
        
        elif cmd == 'list-by-size' or cmd == 'listbysize':
            limit = 100
            if len(parts) > 1:
                try:
                    limit = int(parts[1])
                except ValueError:
                    print(f"{Colors.WARNING}Invalid limit: {parts[1]}. Using default 100{Colors.ENDC}")
            
            print(f"{Colors.OKBLUE}Listing top {limit} largest files...{Colors.ENDC}")
            start_time = time.time()
            results = self.db_manager.list_all_files(limit=limit, files_only=True, order_by_size=True)
            search_time = time.time() - start_time
            
            self.print_results(results, show_details=True, show_size_ranking=True)
            print(f"\n{Colors.OKBLUE}Listed {len(results)} files in {search_time*1000:.1f}ms{Colors.ENDC}")
        
        elif cmd == 'list-all' or cmd == 'listall':
            limit = 50
            if len(parts) > 1:
                try:
                    limit = int(parts[1])
                except ValueError:
                    print(f"{Colors.WARNING}Invalid limit: {parts[1]}. Using default 50{Colors.ENDC}")
            
            print(f"{Colors.OKBLUE}Listing all files (limit: {limit})...{Colors.ENDC}")
            start_time = time.time()
            results = self.db_manager.list_all_files(limit=limit)
            search_time = time.time() - start_time
            
            self.print_results(results, show_details=True)
            print(f"\n{Colors.OKBLUE}Listed {len(results)} items in {search_time*1000:.1f}ms{Colors.ENDC}")
        
        elif cmd == 'index-c' or cmd == 'indexc':
            confirm = input("Index entire C drive? This may take a long time (y/N): ")
            if confirm.lower() == 'y':
                print(f"{Colors.WARNING}Starting C drive indexing. This may take several minutes...{Colors.ENDC}")
                self.indexer.index_directory("C:\\")
        
        elif cmd == 'help':
            print(f"\n{Colors.HEADER}Available Commands:{Colors.ENDC}")
            print(":stats - Show database statistics")
            print(":clear - Clear the database")
            print(":index <path> - Index a directory")
            print(":index-c - Index entire C drive")
            print(":list-by-size [limit] - List largest files (default: 100)")
            print(":list-all [limit] - List all files (default: 50)")
            print(":help - Show this help")
            print("quit/exit/q - Exit the program")
        
        else:
            print(f"{Colors.WARNING}Unknown command: {cmd}{Colors.ENDC}")
    
    def parse_size(self, size_str: str) -> int:
        """Parse size string (e.g., '10MB', '1GB') to bytes"""
        size_str = size_str.upper()
        multipliers = {'B': 1, 'KB': 1024, 'MB': 1024**2, 'GB': 1024**3, 'TB': 1024**4}
        
        for unit, mult in multipliers.items():
            if size_str.endswith(unit):
                try:
                    return int(float(size_str[:-len(unit)]) * mult)
                except ValueError:
                    break
        
        try:
            return int(size_str)
        except ValueError:
            raise ValueError(f"Invalid size format: {size_str}")
    
    def parse_time_filter(self, time_str: str) -> float:
        """Parse time filter (e.g., '1d', '2w', '3m') to timestamp"""
        time_str = time_str.lower()
        now = datetime.now()
        
        if time_str.endswith('d'):
            days = int(time_str[:-1])
            return (now - timedelta(days=days)).timestamp()
        elif time_str.endswith('w'):
            weeks = int(time_str[:-1])
            return (now - timedelta(weeks=weeks)).timestamp()
        elif time_str.endswith('m'):
            months = int(time_str[:-1])
            return (now - timedelta(days=months*30)).timestamp()
        elif time_str.endswith('y'):
            years = int(time_str[:-1])
            return (now - timedelta(days=years*365)).timestamp()
        else:
            raise ValueError(f"Invalid time format: {time_str}")

def main():
    """Main entry point"""
    parser = argparse.ArgumentParser(
        description="Everything CLI - Fast file search utility (like Windows Everything app)\n\nDEFAULT: Running without arguments shows all files by size (largest first)",
        formatter_class=argparse.YOUR_CLIENT_SECRET_HERE,
        epilog="""
Examples:
  everything_cli.py                               # DEFAULT: Show all files by size (Everything app style)
  everything_cli.py --interactive                 # Interactive search mode (recommended)
  everything_cli.py --search "filename"          # Search for specific files
  everything_cli.py --search "*.py"              # Search for Python files
  everything_cli.py --search "large" --min-size 1GB --order-by-size  # Find large files ordered by size
  everything_cli.py --index-c-drive              # Index entire C drive (Windows) - one time setup
  everything_cli.py --list-by-size --limit 50    # Show 50 largest files
        """
    )
    
    parser.add_argument('--index', '-i', metavar='PATH', 
                       help='Index files in the specified directory')
    parser.add_argument('--index-c-drive', action='store_true',
                       help='Index entire C drive (Windows)')
    parser.add_argument('--search', '-s', metavar='QUERY',
                       help='Search for files matching the query')
    parser.add_argument('--list-by-size', action='store_true',
                       help='List all files ordered by size (largest first)')
    parser.add_argument('--list-all', action='store_true',
                       help='List all files in the database')
    parser.add_argument('--interactive', '-I', action='store_true',
                       help='Start interactive search mode')
    parser.add_argument('--ext', metavar='EXTENSION',
                       help='Filter by file extension (e.g., .txt, .py)')
    parser.add_argument('--min-size', metavar='SIZE',
                       help='Minimum file size (e.g., 1MB, 500KB)')
    parser.add_argument('--max-size', metavar='SIZE',
                       help='Maximum file size (e.g., 1GB, 100MB)')
    parser.add_argument('--dirs-only', action='store_true',
                       help='Show only directories')
    parser.add_argument('--files-only', action='store_true',
                       help='Show only files')
    parser.add_argument('--modified-after', metavar='TIME',
                       help='Modified after (e.g., 1d, 2w, 3m)')
    parser.add_argument('--modified-before', metavar='TIME',
                       help='Modified before (e.g., 1d, 2w, 3m)')
    parser.add_argument('--order-by-size', action='store_true',
                       help='Order results by file size (largest first)')
    parser.add_argument('--order-by-date', action='store_true',
                       help='Order results by modification date (newest first)')
    parser.add_argument('--limit', '-l', type=int, default=100,
                       help='Maximum number of results (default: 100)')
    parser.add_argument('--details', '-d', action='store_true',
                       help='Show detailed information')
    parser.add_argument('--stats', action='store_true',
                       help='Show database statistics')
    parser.add_argument('--clear', action='store_true',
                       help='Clear the database')
    
    args = parser.parse_args()
    
    app = EverythingCLI()
    
    # Handle stats command
    if args.stats:
        stats = app.db_manager.get_stats()
        print(f"{Colors.HEADER}Database Statistics:{Colors.ENDC}")
        print(f"Files: {stats['total_files']:,}")
        print(f"Directories: {stats['total_directories']:,}")
        print(f"Total entries: {stats['total_entries']:,}")
        print(f"Total size: {app.format_size(stats['total_size'])}")
        return
    
    # Handle clear command
    if args.clear:
        confirm = input("Are you sure you want to clear the database? (y/N): ")
        if confirm.lower() == 'y':
            app.db_manager.clear_database()
            print(f"{Colors.OKGREEN}Database cleared{Colors.ENDC}")
        return
    
    # Handle indexing
    if args.index:
        if not os.path.exists(args.index):
            print(f"{Colors.FAIL}Error: Path does not exist: {args.index}{Colors.ENDC}")
            return
        
        app.indexer.index_directory(args.index)
        return
    
    # Handle C drive indexing
    if args.index_c_drive:
        if os.name == 'nt':  # Windows
            confirm = input("Index entire C drive? This may take a very long time and use significant resources (y/N): ")
            if confirm.lower() == 'y':
                print(f"{Colors.WARNING}Starting C drive indexing. This may take 30+ minutes depending on your system...{Colors.ENDC}")
                app.indexer.index_directory("C:\\")
            else:
                print("C drive indexing cancelled.")
        else:
            print(f"{Colors.FAIL}C drive indexing is only available on Windows systems{Colors.ENDC}")
        return
    
    # Handle list by size
    if args.list_by_size:
        print(f"{Colors.OKBLUE}Listing top {args.limit} largest files...{Colors.ENDC}")
        start_time = time.time()
        results = app.db_manager.list_all_files(limit=args.limit, files_only=True, order_by_size=True)
        search_time = time.time() - start_time
        
        app.print_results(results, show_details=args.details, show_size_ranking=True)
        print(f"\n{Colors.OKBLUE}Listed {len(results)} files in {search_time*1000:.1f}ms{Colors.ENDC}")
        return
    
    # Handle list all
    if args.list_all:
        print(f"{Colors.OKBLUE}Listing all files (limit: {args.limit})...{Colors.ENDC}")
        start_time = time.time()
        results = app.db_manager.list_all_files(limit=args.limit)
        search_time = time.time() - start_time
        
        app.print_results(results, show_details=args.details)
        print(f"\n{Colors.OKBLUE}Listed {len(results)} items in {search_time*1000:.1f}ms{Colors.ENDC}")
        return
    
    # Handle interactive mode
    if args.interactive:
        app.interactive_search()
        return
    
    # Handle search
    if args.search:
        # Build filters
        filters = {}
        
        if args.ext:
            filters['extension'] = args.ext
        
        if args.min_size:
            try:
                filters['min_size'] = app.parse_size(args.min_size)
            except ValueError as e:
                print(f"{Colors.FAIL}Error: {e}{Colors.ENDC}")
                return
        
        if args.max_size:
            try:
                filters['max_size'] = app.parse_size(args.max_size)
            except ValueError as e:
                print(f"{Colors.FAIL}Error: {e}{Colors.ENDC}")
                return
        
        if args.dirs_only:
            filters['directories_only'] = True
        elif args.files_only:
            filters['files_only'] = True
        
        if args.modified_after:
            try:
                filters['modified_after'] = app.parse_time_filter(args.modified_after)
            except ValueError as e:
                print(f"{Colors.FAIL}Error: {e}{Colors.ENDC}")
                return
        
        if args.modified_before:
            try:
                filters['modified_before'] = app.parse_time_filter(args.modified_before)
            except ValueError as e:
                print(f"{Colors.FAIL}Error: {e}{Colors.ENDC}")
                return
        
        # Handle ordering
        if args.order_by_size:
            filters['order_by_size'] = True
        elif args.order_by_date:
            filters['order_by_date'] = True
        
        # Perform search
        start_time = time.time()
        results = app.db_manager.search_files(args.search, limit=args.limit, **filters)
        search_time = time.time() - start_time
        
        # Show size ranking format if ordered by size
        show_size_ranking = args.order_by_size
        app.print_results(results, args.search, show_details=args.details, show_size_ranking=show_size_ranking)
        print(f"\n{Colors.OKBLUE}Search completed in {search_time*1000:.1f}ms{Colors.ENDC}")
        return
    
    # If no specific command, show all files by size (default Everything app behavior)
    print(f"{Colors.HEADER}Everything CLI - Showing all files by size{Colors.ENDC}")
    
    # Check if C drive is indexed (Windows only)
    if os.name == 'nt' and not app.db_manager.is_c_drive_indexed():
        print(f"{Colors.WARNING}C drive not indexed yet. This is required for the Everything-like experience.{Colors.ENDC}")
        confirm = input("Index C drive now? This may take 30+ minutes but only needs to be done once (Y/n): ")
        if confirm.lower() in ['', 'y', 'yes']:
            print(f"{Colors.OKBLUE}Starting C drive indexing... This will run in the background.{Colors.ENDC}")
            print(f"{Colors.OKBLUE}You can press Ctrl+C to stop and use existing data.{Colors.ENDC}")
            try:
                app.indexer.index_directory("C:\\")
            except KeyboardInterrupt:
                print(f"\n{Colors.WARNING}Indexing interrupted. Using existing data...{Colors.ENDC}")
        else:
            print(f"{Colors.WARNING}Using existing database (limited results)...{Colors.ENDC}")
    
    # Show all files by size (largest first) - default Everything behavior
    print(f"\n{Colors.OKBLUE}Listing largest files across all indexed drives...{Colors.ENDC}")
    start_time = time.time()
    results = app.db_manager.list_all_files(limit=1000, files_only=True, order_by_size=True)
    search_time = time.time() - start_time
    
    if results:
        app.print_results(results, show_details=True, show_size_ranking=True)
        print(f"\n{Colors.OKGREEN}Showing top {len(results)} largest files{Colors.ENDC}")
        print(f"{Colors.OKBLUE}Search completed in {search_time*1000:.1f}ms{Colors.ENDC}")
        
        stats = app.db_manager.get_stats()
        print(f"\n{Colors.HEADER}Database: {stats['total_files']:,} files, {stats['total_directories']:,} directories, {app.format_size(stats['total_size'])} total{Colors.ENDC}")
        print(f"{Colors.OKCYAN}Use --interactive for search mode, --help for all options{Colors.ENDC}")
    else:
        print(f"{Colors.WARNING}No files found. Use --index <path> to index directories first.{Colors.ENDC}")
        print(f"{Colors.OKCYAN}Example: python everything_cli.py --index C:\\ (to index C drive){Colors.ENDC}")
        print(f"{Colors.OKCYAN}Or use: python everything_cli.py --help for all options{Colors.ENDC}")

if __name__ == "__main__":
    main()