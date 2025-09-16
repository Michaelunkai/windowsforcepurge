#!/usr/bin/env python3
"""
Everything CLI - A command-line file manager similar to Everything for Windows
Shows all files and folders sorted by size with interactive delete functionality
"""

import os
import sys
import time
import shutil
import threading
import concurrent.futures
from pathlib import Path
from typing import List, Tuple, Optional
import argparse
from collections import defaultdict

try:
    import keyboard
    KEYBOARD_AVAILABLE = True
except ImportError:
    KEYBOARD_AVAILABLE = False
    print("Warning: 'keyboard' module not found. Install with: pip install keyboard")

class FileEntry:
    def __init__(self, path: str, size: int, is_dir: bool = False, size_calculated: bool = True):
        self.path = path
        self.size = size
        self.is_dir = is_dir
        self.size_calculated = size_calculated
        self.name = os.path.basename(path) if path != "/" else "/"
    
    def __str__(self):
        size_str = self.format_size(self.size) if self.size_calculated else "CALC..."
        type_str = "DIR" if self.is_dir else "FILE"
        return f"[{type_str:4}] {size_str:>10} | {self.path}"
    
    def is_safe_to_delete(self) -> bool:
        """Determine if a file/directory is safe to delete"""
        # Common system directories that shouldn't be deleted
        unsafe_paths = [
            "C:\\Windows",
            "C:\\Program Files",
            "C:\\Program Files (x86)",
            "C:\\System Volume Information",
            "$Recycle.Bin",
            "C:\\bootmgr",
            "C:\\BOOTNXT",
            "C:\\pagefile.sys",
            "C:\\hiberfil.sys",
            "C:\\swapfile.sys"
        ]
        
        # Check if path matches any unsafe paths
        for unsafe_path in unsafe_paths:
            if self.path.lower().startswith(unsafe_path.lower()):
                return False
                
        # Check for system files
        system_files = [
            ".dll", ".sys", ".drv", ".exe",  # System file extensions
        ]
        
        # If it's in Windows directory or System32, it's likely unsafe
        if "windows" in self.path.lower() and ("system32" in self.path.lower() or 
                                              "syswow64" in self.path.lower()):
            return False
            
        # Check file extensions for system files
        if not self.is_dir:
            for ext in system_files:
                if self.path.lower().endswith(ext):
                    # Additional check - if in system directories, definitely unsafe
                    if "windows" in self.path.lower() or "program files" in self.path.lower():
                        return False
        
        # Additional check for specific system files
        unsafe_files = [
            "pagefile.sys", "hiberfil.sys", "swapfile.sys", "bootmgr", "BOOTNXT"
        ]
        
        filename = os.path.basename(self.path).lower()
        for unsafe_file in unsafe_files:
            if filename == unsafe_file.lower():
                return False
        
        return True
    
    @staticmethod
    def format_size(size: int) -> str:
        """Format file size in human readable format"""
        if size == 0:
            return "     0B"
        for unit in ['B', 'KB', 'MB', 'GB', 'TB']:
            if size < 1024.0:
                return f"{size:6.1f}{unit}"
            size /= 1024.0
        return f"{size:6.1f}PB"

class EverythingCLI:
    def __init__(self, root_path: str = None):
        self.root_path = root_path or "C:\\"
        self.files: List[FileEntry] = []
        self.current_index = 0
        self.display_offset = 0
        self.lines_per_page = 1000  # Show up to 1000 items
        self.scanning = False
        self.scan_thread = None
        self.max_workers = min(32, os.cpu_count() + 4)  # Optimized thread count
        self.min_file_size = 0  # Filter files smaller than this (bytes)
        self.file_extensions = None  # Filter by extensions if set
        
    def get_directory_size_fast(self, path: str) -> int:
        """Fast directory size calculation using scandir"""
        total = 0
        try:
            with os.scandir(path) as entries:
                for entry in entries:
                    try:
                        if entry.is_file(follow_symlinks=False):
                            total += entry.stat().st_size
                        elif entry.is_dir(follow_symlinks=False):
                            total += self.get_directory_size_fast(entry.path)
                    except (OSError, IOError):
                        continue
        except (OSError, IOError):
            pass
        return total
    
    def scan_directory_chunk(self, scan_path: str) -> List[FileEntry]:
        """Scan a directory chunk and return FileEntry objects"""
        entries = []
        try:
            with os.scandir(scan_path) as dir_entries:
                for entry in dir_entries:
                    try:
                        if entry.is_file(follow_symlinks=False):
                            stat_info = entry.stat()
                            file_size = stat_info.st_size
                            
                            # Apply size filter
                            if file_size < self.min_file_size:
                                continue
                                
                            # Apply extension filter
                            if self.file_extensions:
                                _, ext = os.path.splitext(entry.name)
                                if ext.lower() not in self.file_extensions:
                                    continue
                            
                            entries.append(FileEntry(entry.path, file_size, False))
                            
                        elif entry.is_dir(follow_symlinks=False):
                            # For directories, add with lazy size calculation
                            entries.append(FileEntry(entry.path, 0, True, False))
                            
                    except (OSError, IOError):
                        continue
                        
        except (OSError, IOError, PermissionError):
            pass
            
        return entries
    
    def calculate_dir_size_lazy(self, file_entry: FileEntry) -> None:
        """Calculate directory size on demand"""
        if file_entry.is_dir and not file_entry.size_calculated:
            file_entry.size = self.get_directory_size_fast(file_entry.path)
            file_entry.size_calculated = True
    
    def scan_files(self, path: str = None) -> None:
        """Fast multi-threaded file scanning"""
        if path is None:
            # Limit to C drive only
            path = "C:\\" if os.name == 'nt' else "/"
            
        self.scanning = True
        self.files.clear()
        
        print(f"Fast scanning from: {path}")
        print("Using multithreaded scanning for better performance...")
        
        directories_to_scan = []
        scanned_count = 0
        
        try:
            # Only scan C drive
            scan_paths = [path]
            
            # Build directory list for parallel processing
            for scan_path in scan_paths:
                for root, dirs, files in os.walk(scan_path):
                    directories_to_scan.append(root)
                    if len(directories_to_scan) % 1000 == 0:
                        print(f"\rMapping directories: {len(directories_to_scan)}", end='', flush=True)
            
            print(f"\rFound {len(directories_to_scan)} directories to scan")
            
            # Process directories in parallel
            with concurrent.futures.ThreadPoolExecutor(max_workers=self.max_workers) as executor:
                # Submit all tasks
                future_to_dir = {
                    executor.submit(self.scan_directory_chunk, dir_path): dir_path 
                    for dir_path in directories_to_scan
                }
                
                # Collect results as they complete
                for future in concurrent.futures.as_completed(future_to_dir):
                    try:
                        entries = future.result()
                        self.files.extend(entries)
                        scanned_count += len(entries)
                        
                        if scanned_count % 500 == 0:
                            print(f"\rProcessed {scanned_count} items...", end='', flush=True)
                            
                    except Exception as e:
                        # Skip problematic directories
                        continue
                        
        except KeyboardInterrupt:
            print("\nScan interrupted by user")
        except Exception as e:
            print(f"\nError during scanning: {e}")
        
        print(f"\nProcessing results...")
        
        # Sort files by size (files with calculated sizes first, then by size)
        def sort_key(x):
            if x.size_calculated:
                return (0, -x.size)  # Calculated sizes first, largest first
            else:
                return (1, 0)  # Uncalculated sizes last
        
        self.files.sort(key=sort_key)
        self.scanning = False
        
        print(f"Fast scan complete! Found {len(self.files)} items.")
        print("Directory sizes will be calculated on-demand for better performance")
        print("Navigation: Up/Down arrows, 'd'=delete, 'q'=quit, 'r'=rescan")

    def display_files(self) -> None:
        """Display current page of files with lazy size calculation"""
        os.system('cls' if os.name == 'nt' else 'clear')
        
        print("=" * 80)
        print("EVERYTHING CLI - File Manager (Sorted by Size)")
        print("=" * 80)
        print(f"Total items: {len(self.files)} | Current: {self.current_index + 1}")
        print(f"Threads: {self.max_workers} | Min size: {FileEntry.format_size(self.min_file_size)}")
        print("Navigation: Up/Down arrows, 'd'=delete, 'q'=quit, 'r'=rescan, 'c'=calc dir")
        print("NOTE: Files shown in GREEN are safe to delete")
        print("-" * 80)
        
        if not self.files:
            print("No files found. Press 'r' to rescan or 'q' to quit.")
            return
        
        # Display up to 1000 heaviest files/folders
        display_count = min(1000, len(self.files))
        
        for i in range(display_count):
            marker = ">" if i == self.current_index else " "
            delete_btn = "[DEL]" if i == self.current_index else "     "
            
            # Check if file is safe to delete
            file_entry = self.files[i]
            
            # Calculate directory size on demand for visible entries
            if (file_entry.is_dir and not file_entry.size_calculated and 
                i == self.current_index):
                # Check if file is safe to delete
                is_safe = file_entry.is_safe_to_delete()
                
                # Display in green if safe
                if is_safe:
                    # ANSI escape code for green text
                    print(f"{marker} {delete_btn} \033[92m[DIR ]  CALC...  | {file_entry.path} (calculating...)\033[0m")
                else:
                    print(f"{marker} {delete_btn} [DIR ]  CALC...  | {file_entry.path} (calculating...)")
                threading.Thread(target=self.calculate_dir_size_lazy, 
                               args=(file_entry,), daemon=True).start()
            else:
                # Check if file is safe to delete
                is_safe = file_entry.is_safe_to_delete()
                
                # Display in green if safe
                if is_safe:
                    # ANSI escape code for green text
                    print(f"{marker} {delete_btn} \033[92m{file_entry}\033[0m")
                else:
                    print(f"{marker} {delete_btn} {file_entry}")
        
        if display_count < len(self.files):
            print(f"\n... and {len(self.files) - display_count} more items (showing top 1000) ...")

    def navigate_up(self) -> None:
        """Move selection up"""
        if self.current_index > 0:
            self.current_index -= 1
            if self.current_index < self.display_offset:
                self.display_offset = max(0, self.display_offset - self.lines_per_page)
    
    def navigate_down(self) -> None:
        """Move selection down"""
        if self.current_index < len(self.files) - 1:
            self.current_index += 1
            if self.current_index >= self.display_offset + self.lines_per_page:
                self.display_offset = min(len(self.files) - self.lines_per_page, 
                                        self.display_offset + self.lines_per_page)
    
    def YOUR_CLIENT_SECRET_HEREe(self) -> None:
        """Calculate size of currently selected directory"""
        if (self.files and self.current_index < len(self.files) and 
            self.files[self.current_index].is_dir):
            
            selected = self.files[self.current_index]
            if not selected.size_calculated:
                print("\nCalculating directory size...")
                self.calculate_dir_size_lazy(selected)
                # Re-sort after size calculation
                self.resort_files()
                print("Directory size calculated!")
                input("Press Enter to continue...")
    
    def resort_files(self) -> None:
        """Re-sort files after size calculations"""
        def sort_key(x):
            if x.size_calculated:
                return (0, -x.size)
            else:
                return (1, 0)
        
        self.files.sort(key=sort_key)
    
    def force_delete_current(self) -> None:
        """Force delete currently selected file/folder"""
        if not self.files or self.current_index >= len(self.files):
            return
        
        selected_file = self.files[self.current_index]
        
        # Calculate size if not done yet
        if selected_file.is_dir and not selected_file.size_calculated:
            print("Calculating directory size for deletion confirmation...")
            self.calculate_dir_size_lazy(selected_file)
        
        print(f"\n{'='*60}")
        print(f"DELETE CONFIRMATION")
        print(f"{'='*60}")
        print(f"Path: {selected_file.path}")
        print(f"Type: {'Directory' if selected_file.is_dir else 'File'}")
        print(f"Size: {FileEntry.format_size(selected_file.size)}")
        print(f"Safe to delete: {'Yes' if selected_file.is_safe_to_delete() else 'No'}")
        print(f"{'='*60}")
        
        confirm = input("Are you sure you want to DELETE this item? (type 'DELETE' to confirm): ")
        
        if confirm != "DELETE":
            print("Deletion cancelled.")
            input("Press Enter to continue...")
            return
        
        try:
            if selected_file.is_dir:
                shutil.rmtree(selected_file.path, ignore_errors=True)
                print(f"Directory deleted: {selected_file.path}")
            else:
                os.remove(selected_file.path)
                print(f"File deleted: {selected_file.path}")
            
            # Remove from list
            del self.files[self.current_index]
            
            # Adjust current index
            if self.current_index >= len(self.files) and len(self.files) > 0:
                self.current_index = len(self.files) - 1
            
            # Adjust display offset
            if self.current_index < self.display_offset:
                self.display_offset = max(0, self.current_index)
                
            print("Item successfully deleted!")
            
        except Exception as e:
            print(f"Error deleting item: {e}")
        
        input("Press Enter to continue...")

    def run_simple(self) -> None:
        """Run without keyboard library (basic version)"""
        print("Running in simple mode")
        
        while True:
            self.display_files()
            
            if not self.files:
                action = input("\nAction (r=rescan, q=quit): ").lower().strip()
            else:
                action = input(f"\nAction (u=up, d=down, del=delete, c=calc dir, r=rescan, q=quit): ").lower().strip()
            
            if action == 'q':
                break
            elif action == 'r':
                self.scan_files()
            elif action == 'u' and self.files:
                self.navigate_up()
            elif action == 'd' and self.files:
                self.navigate_down()
            elif action == 'del' and self.files:
                self.force_delete_current()
            elif action == 'c' and self.files:
                self.YOUR_CLIENT_SECRET_HEREe()

    def run_interactive(self) -> None:
        """Run with live keyboard input"""
        print("Running in interactive mode")
        
        while True:
            self.display_files()
            
            try:
                event = keyboard.read_event()
                if event.event_type == keyboard.KEY_DOWN:
                    key = event.name
                    
                    if key == 'q':
                        break
                    elif key == 'up':
                        self.navigate_up()
                    elif key == 'down':
                        self.navigate_down()
                    elif key == 'd' and self.files:
                        self.force_delete_current()
                    elif key == 'r':
                        self.scan_files()
                    elif key == 'c' and self.files:
                        self.YOUR_CLIENT_SECRET_HEREe()
                        
            except KeyboardInterrupt:
                break

    def run(self) -> None:
        """Main run method"""
        print("Everything CLI - Starting up...")
        
        # Initial scan
        self.scan_files()
        
        # Choose interface
        if KEYBOARD_AVAILABLE:
            try:
                self.run_interactive()
            except Exception as e:
                print(f"Interactive mode failed: {e}")
                print("Falling back to simple mode...")
                self.run_simple()
        else:
            self.run_simple()
        
        print("\nGoodbye!")

def main():
    parser = argparse.ArgumentParser(description='Everything CLI - File Manager')
    parser.add_argument('path', nargs='?', default=None, 
                      help='Root path to scan (default: C:\\ on Windows)')
    parser.add_argument('--simple', action='store_true', 
                      help='Force simple mode (no live keyboard input)')
    parser.add_argument('--min-size', type=int, default=0,
                      help='Minimum file size in bytes (default: 0)')
    parser.add_argument('--threads', type=int, default=None,
                      help='Number of threads for scanning (default: auto)')
    parser.add_argument('--extensions', nargs='+', default=None,
                      help='Filter by file extensions (e.g., --extensions .txt .log)')
    
    args = parser.parse_args()
    
    # Determine root path - always use C drive for safety
    root_path = "C:\\"
    
    app = EverythingCLI(root_path)
    
    # Apply filters and settings
    app.min_file_size = args.min_size
    if args.threads:
        app.max_workers = args.threads
    if args.extensions:
        app.file_extensions = set(ext.lower() if ext.startswith('.') else f'.{ext.lower()}' 
                                for ext in args.extensions)
    
    if args.simple:
        global KEYBOARD_AVAILABLE
        KEYBOARD_AVAILABLE = False
    
    try:
        app.run()
    except KeyboardInterrupt:
        print("\nProgram interrupted by user")
    except Exception as e:
        print(f"Unexpected error: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()