import dearpygui.dearpygui as dpg
import os
import hashlib
import threading
import time
import json
import shutil
import sqlite3
from datetime import datetime, timedelta
from pathlib import Path
from collections import defaultdict, Counter
import re
import mimetypes
from watchdog.observers import Observer
from watchdog.events import FileSystemEventHandler
import math
import random

class FileAnalyzer:
    """Analyzes files for various properties and metadata"""
    
    def __init__(self):
        self.supported_types = {
            'images': ['.jpg', '.jpeg', '.png', '.gif', '.bmp', '.tiff', '.webp'],
            'videos': ['.mp4', '.avi', '.mkv', '.mov', '.wmv', '.flv', '.webm'],
            'documents': ['.pdf', '.doc', '.docx', '.txt', '.rtf', '.odt'],
            'spreadsheets': ['.xls', '.xlsx', '.csv', '.ods'],
            'presentations': ['.ppt', '.pptx', '.odp'],
            'audio': ['.mp3', '.wav', '.flac', '.aac', '.ogg', '.wma'],
            'archives': ['.zip', '.rar', '.7z', '.tar', '.gz', '.bz2'],
            'code': ['.py', '.js', '.html', '.css', '.cpp', '.java', '.c'],
            'executables': ['.exe', '.msi', '.deb', '.rpm', '.dmg', '.app']
        }
    
    def get_file_category(self, file_path):
        """Categorize file based on extension"""
        ext = Path(file_path).suffix.lower()
        for category, extensions in self.supported_types.items():
            if ext in extensions:
                return category
        return 'other'
    
    def get_file_hash(self, file_path, chunk_size=8192):
        """Calculate MD5 hash of file"""
        try:
            hash_md5 = hashlib.md5()
            with open(file_path, "rb") as f:
                for chunk in iter(lambda: f.read(chunk_size), b""):
                    hash_md5.update(chunk)
            return hash_md5.hexdigest()
        except:
            return None
    
    def analyze_file(self, file_path):
        """Comprehensive file analysis"""
        try:
            stat = os.stat(file_path)
            return {
                'path': file_path,
                'name': os.path.basename(file_path),
                'size': stat.st_size,
                'modified': datetime.fromtimestamp(stat.st_mtime),
                'created': datetime.fromtimestamp(stat.st_ctime),
                'category': self.get_file_category(file_path),
                'extension': Path(file_path).suffix.lower(),
                'hash': None  # Calculate on demand
            }
        except:
            return None

class DuplicateDetector:
    """Advanced duplicate detection using multiple algorithms"""
    
    def __init__(self):
        self.analyzer = FileAnalyzer()
        self.duplicates = []
    
    def find_duplicates_by_hash(self, files, progress_callback=None):
        """Find exact duplicates using file hashes"""
        hash_map = defaultdict(list)
        total_files = len(files)
        
        for i, file_info in enumerate(files):
            if progress_callback:
                progress_callback(i / total_files, f"Hashing: {file_info['name']}")
            
            file_hash = self.analyzer.get_file_hash(file_info['path'])
            if file_hash:
                file_info['hash'] = file_hash
                hash_map[file_hash].append(file_info)
        
        duplicates = [group for group in hash_map.values() if len(group) > 1]
        return duplicates
    
    def find_similar_files(self, files, similarity_threshold=0.8):
        """Find similar files based on name and size"""
        similar_groups = []
        processed = set()
        
        for i, file1 in enumerate(files):
            if i in processed:
                continue
                
            similar_group = [file1]
            processed.add(i)
            
            for j, file2 in enumerate(files[i+1:], i+1):
                if j in processed:
                    continue
                
                # Name similarity
                name_sim = self.YOUR_CLIENT_SECRET_HERE(file1['name'], file2['name'])
                # Size similarity
                size_sim = self.YOUR_CLIENT_SECRET_HERE(file1['size'], file2['size'])
                
                overall_similarity = (name_sim + size_sim) / 2
                
                if overall_similarity >= similarity_threshold:
                    similar_group.append(file2)
                    processed.add(j)
            
            if len(similar_group) > 1:
                similar_groups.append(similar_group)
        
        return similar_groups
    
    def YOUR_CLIENT_SECRET_HERE(self, name1, name2):
        """Calculate similarity between file names"""
        # Simple Levenshtein distance ratio
        def levenshtein_ratio(s1, s2):
            len1, len2 = len(s1), len(s2)
            if len1 == 0 or len2 == 0:
                return 0
            
            distance = [[0] * (len2 + 1) for _ in range(len1 + 1)]
            
            for i in range(len1 + 1):
                distance[i][0] = i
            for j in range(len2 + 1):
                distance[0][j] = j
            
            for i in range(1, len1 + 1):
                for j in range(1, len2 + 1):
                    cost = 0 if s1[i-1] == s2[j-1] else 1
                    distance[i][j] = min(
                        distance[i-1][j] + 1,
                        distance[i][j-1] + 1,
                        distance[i-1][j-1] + cost
                    )
            
            return 1 - (distance[len1][len2] / max(len1, len2))
        
        return levenshtein_ratio(name1.lower(), name2.lower())
    
    def YOUR_CLIENT_SECRET_HERE(self, size1, size2):
        """Calculate similarity based on file sizes"""
        if size1 == 0 and size2 == 0:
            return 1.0
        if size1 == 0 or size2 == 0:
            return 0.0
        
        ratio = min(size1, size2) / max(size1, size2)
        return ratio

class StorageAnalyzer:
    """Analyzes storage usage and generates statistics"""
    
    def __init__(self):
        self.analyzer = FileAnalyzer()
    
    def analyze_directory(self, directory, progress_callback=None):
        """Comprehensive directory analysis"""
        files = []
        total_size = 0
        category_stats = defaultdict(lambda: {'count': 0, 'size': 0})
        extension_stats = defaultdict(lambda: {'count': 0, 'size': 0})
        size_distribution = {'< 1MB': 0, '1-10MB': 0, '10-100MB': 0, '100MB-1GB': 0, '> 1GB': 0}
        
        # Walk through directory
        for root, dirs, filenames in os.walk(directory):
            for filename in filenames:
                file_path = os.path.join(root, filename)
                
                if progress_callback:
                    progress_callback(0.5, f"Analyzing: {filename}")
                
                file_info = self.analyzer.analyze_file(file_path)
                if file_info:
                    files.append(file_info)
                    
                    # Update statistics
                    total_size += file_info['size']
                    category = file_info['category']
                    extension = file_info['extension']
                    
                    category_stats[category]['count'] += 1
                    category_stats[category]['size'] += file_info['size']
                    
                    extension_stats[extension]['count'] += 1
                    extension_stats[extension]['size'] += file_info['size']
                    
                    # Size distribution
                    size_mb = file_info['size'] / (1024 * 1024)
                    if size_mb < 1:
                        size_distribution['< 1MB'] += 1
                    elif size_mb < 10:
                        size_distribution['1-10MB'] += 1
                    elif size_mb < 100:
                        size_distribution['10-100MB'] += 1
                    elif size_mb < 1024:
                        size_distribution['100MB-1GB'] += 1
                    else:
                        size_distribution['> 1GB'] += 1
        
        return {
            'files': files,
            'total_size': total_size,
            'total_files': len(files),
            'category_stats': dict(category_stats),
            'extension_stats': dict(extension_stats),
            'size_distribution': size_distribution
        }

class FileOrganizer:
    """Intelligent file organization with custom rules"""
    
    def __init__(self):
        self.rules = []
        self.operation_history = []
    
    def add_rule(self, rule):
        """Add organization rule"""
        self.rules.append(rule)
    
    def organize_files(self, files, base_directory, progress_callback=None):
        """Organize files based on rules"""
        operations = []
        
        for i, file_info in enumerate(files):
            if progress_callback:
                progress_callback(i / len(files), f"Organizing: {file_info['name']}")
            
            new_location = self._apply_rules(file_info, base_directory)
            if new_location and new_location != file_info['path']:
                operations.append({
                    'action': 'move',
                    'source': file_info['path'],
                    'destination': new_location,
                    'timestamp': datetime.now()
                })
        
        return operations
    
    def _apply_rules(self, file_info, base_directory):
        """Apply organization rules to determine new file location"""
        for rule in self.rules:
            if self._matches_rule(file_info, rule):
                return self._generate_path(file_info, rule, base_directory)
        return None
    
    def _matches_rule(self, file_info, rule):
        """Check if file matches rule criteria"""
        if 'category' in rule and file_info['category'] not in rule['category']:
            return False
        if 'extension' in rule and file_info['extension'] not in rule['extension']:
            return False
        if 'size_min' in rule and file_info['size'] < rule['size_min']:
            return False
        if 'size_max' in rule and file_info['size'] > rule['size_max']:
            return False
        if 'age_days' in rule:
            age = (datetime.now() - file_info['modified']).days
            if age < rule['age_days']:
                return False
        return True
    
    def _generate_path(self, file_info, rule, base_directory):
        """Generate new file path based on rule"""
        folder_pattern = rule.get('folder_pattern', '{category}')
        
        # Replace placeholders
        folder_pattern = folder_pattern.replace('{category}', file_info['category'])
        folder_pattern = folder_pattern.replace('{year}', str(file_info['modified'].year))
        folder_pattern = folder_pattern.replace('{month}', f"{file_info['modified'].month:02d}")
        folder_pattern = folder_pattern.replace('{extension}', file_info['extension'][1:])
        
        new_directory = os.path.join(base_directory, folder_pattern)
        return os.path.join(new_directory, file_info['name'])

class FolderMonitor(FileSystemEventHandler):
    """Real-time folder monitoring"""
    
    def __init__(self, callback):
        self.callback = callback
        self.organizer = FileOrganizer()
    
    def on_created(self, event):
        if not event.is_directory:
            self.callback('created', event.src_path)
    
    def on_modified(self, event):
        if not event.is_directory:
            self.callback('modified', event.src_path)
    
    def on_deleted(self, event):
        if not event.is_directory:
            self.callback('deleted', event.src_path)

class FileManagerApp:
    """Main application class"""
    
    def __init__(self):
        self.analyzer = FileAnalyzer()
        self.duplicate_detector = DuplicateDetector()
        self.storage_analyzer = StorageAnalyzer()
        self.organizer = FileOrganizer()
        
        self.current_directory = ""
        self.scanned_files = []
        self.duplicates = []
        self.analysis_results = {}
        self.monitoring = False
        self.observer = None
        
        # UI state
        self.selected_files = set()
        self.operation_in_progress = False
        
        # Setup default organization rules
        self._setup_default_rules()
        
        # Setup database for operation history
        self._setup_database()
    
    def _setup_default_rules(self):
        """Setup default organization rules"""
        self.organizer.add_rule({
            'name': 'Images by Date',
            'category': ['images'],
            'folder_pattern': 'Pictures/{year}/{month}'
        })
        
        self.organizer.add_rule({
            'name': 'Documents by Type',
            'category': ['documents', 'spreadsheets', 'presentations'],
            'folder_pattern': 'Documents/{category}'
        })
        
        self.organizer.add_rule({
            'name': 'Large Files',
            'size_min': 100 * 1024 * 1024,  # 100MB
            'folder_pattern': 'Large Files'
        })
    
    def _setup_database(self):
        """Setup SQLite database for operation history"""
        self.db_path = "file_manager_history.db"
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS operations (
                id INTEGER PRIMARY KEY,
                action TEXT,
                source_path TEXT,
                destination_path TEXT,
                timestamp TEXT,
                success BOOLEAN,
                error_message TEXT
            )
        ''')
        
        conn.commit()
        conn.close()
    
    def setup_ui(self):
        """Setup the user interface"""
        dpg.create_context()
        
        # Setup theme
        self._setup_theme()
        
        # Main window
        with dpg.window(label="Advanced File Manager", tag="main_window"):
            
            # Menu bar
            with dpg.menu_bar():
                with dpg.menu(label="File"):
                    dpg.add_menu_item(label="Select Directory", callback=self._select_directory)
                    dpg.add_menu_item(label="Refresh", callback=self._refresh_analysis)
                    dpg.add_separator()
                    dpg.add_menu_item(label="Exit", callback=lambda: dpg.stop_dearpygui())
                
                with dpg.menu(label="Tools"):
                    dpg.add_menu_item(label="Find Duplicates", callback=self._find_duplicates)
                    dpg.add_menu_item(label="Bulk Rename", callback=self._show_bulk_rename)
                    dpg.add_menu_item(label="Monitor Folder", callback=self._toggle_monitoring)
                
                with dpg.menu(label="View"):
                    dpg.add_menu_item(label="Dark Theme", callback=lambda: self._apply_theme("dark"))
                    dpg.add_menu_item(label="Light Theme", callback=lambda: self._apply_theme("light"))
            
            # Toolbar
            with dpg.group(horizontal=True):
                dpg.add_button(label="📁 Select Folder", callback=self._select_directory)
                dpg.add_button(label="🔍 Analyze", callback=self._analyze_directory)
                dpg.add_button(label="📊 Statistics", callback=self._show_statistics)
                dpg.add_button(label="🔧 Organize", callback=self._organize_files)
                dpg.add_button(label="👥 Duplicates", callback=self._find_duplicates)
            
            dpg.add_separator()
            
            # Progress bar
            dpg.add_progress_bar(label="Progress", tag="progress_bar", width=-1)
            dpg.add_text("Ready", tag="status_text")
            
            dpg.add_separator()
            
            # Tab bar for different views
            with dpg.tab_bar():
                
                # File Browser Tab
                with dpg.tab(label="📂 File Browser"):
                    with dpg.child_window(height=400):
                        dpg.add_table(label="Files", tag="file_table", 
                                    headers=["Name", "Size", "Type", "Modified", "Path"],
                                    policy=dpg.mvTable_SizingFixedFit)
                
                # Storage Analysis Tab
                with dpg.tab(label="📊 Storage Analysis"):
                    with dpg.group(horizontal=True):
                        with dpg.child_window(width=400, height=300):
                            dpg.add_text("File Type Distribution")
                            dpg.add_simple_plot(label="Category Distribution", tag="category_plot",
                                              default_value=[0], height=200)
                        
                        with dpg.child_window(width=400, height=300):
                            dpg.add_text("Size Distribution")
                            dpg.add_simple_plot(label="Size Distribution", tag="size_plot",
                                              default_value=[0], height=200)
                    
                    with dpg.child_window(height=200):
                        dpg.add_text("Storage Statistics", tag="storage_stats")
                
                # Duplicates Tab
                with dpg.tab(label="👥 Duplicates"):
                    with dpg.group(horizontal=True):
                        dpg.add_button(label="🔍 Find Exact Duplicates", callback=self._find_exact_duplicates)
                        dpg.add_button(label="🔗 Find Similar Files", callback=self._find_similar_files)
                        dpg.add_button(label="🗑️ Delete Selected", callback=self.YOUR_CLIENT_SECRET_HERE)
                    
                    with dpg.child_window(height=400):
                        dpg.add_table(label="Duplicates", tag="duplicates_table",
                                    headers=["Group", "Name", "Size", "Path", "Hash"],
                                    policy=dpg.mvTable_SizingFixedFit)
                
                # Organization Tab
                with dpg.tab(label="🔧 Organization"):
                    with dpg.group(horizontal=True):
                        with dpg.child_window(width=300):
                            dpg.add_text("Organization Rules")
                            dpg.add_listbox([], tag="rules_list", num_items=8)
                            
                            with dpg.group(horizontal=True):
                                dpg.add_button(label="Add Rule", callback=self._show_add_rule_dialog)
                                dpg.add_button(label="Edit Rule", callback=self._edit_selected_rule)
                                dpg.add_button(label="Delete Rule", callback=self._delete_selected_rule)
                        
                        with dpg.child_window():
                            dpg.add_text("Organization Preview")
                            dpg.add_table(label="Organization Preview", tag="organization_preview",
                                        headers=["File", "Current Location", "New Location"],
                                        policy=dpg.mvTable_SizingFixedFit)
                
                # Monitoring Tab
                with dpg.tab(label="👁️ Monitoring"):
                    with dpg.group(horizontal=True):
                        dpg.add_button(label="Start Monitoring", tag="monitor_button", 
                                     callback=self._toggle_monitoring)
                        dpg.add_text("Status: Stopped", tag="monitor_status")
                    
                    dpg.add_separator()
                    dpg.add_text("Recent File Events:")
                    with dpg.child_window(height=300):
                        dpg.add_text("No events yet", tag="monitor_events")
                
                # Operations Log Tab
                with dpg.tab(label="📝 Operations Log"):
                    with dpg.child_window(height=400):
                        dpg.add_table(label="Operations", tag="operations_table",
                                    headers=["Time", "Action", "Source", "Destination", "Status"],
                                    policy=dpg.mvTable_SizingFixedFit)
        
        # File selection dialog
        with dpg.file_dialog(directory_selector=True, show=False, 
                           callback=self._directory_selected, tag="directory_dialog",
                           width=700, height=400):
            dpg.add_file_extension(".*")
        
        # Add rule dialog
        with dpg.window(label="Add Organization Rule", modal=True, show=False, 
                       tag="add_rule_dialog", width=500, height=400):
            dpg.add_input_text(label="Rule Name", tag="rule_name_input")
            
            dpg.add_text("File Categories (check all that apply):")
            with dpg.group():
                for category in self.analyzer.supported_types.keys():
                    dpg.add_checkbox(label=category.title(), tag=f"category_{category}")
            
            dpg.add_input_text(label="Folder Pattern", tag="folder_pattern_input",
                             hint="{category}/{year}/{month}")
            
            dpg.add_text("Size Constraints (optional):")
            dpg.add_input_int(label="Min Size (MB)", tag="min_size_input", default_value=0)
            dpg.add_input_int(label="Max Size (MB)", tag="max_size_input", default_value=0)
            
            dpg.add_separator()
            with dpg.group(horizontal=True):
                dpg.add_button(label="Add Rule", callback=self._add_rule)
                dpg.add_button(label="Cancel", callback=lambda: dpg.hide_item("add_rule_dialog"))
        
        # Bulk rename dialog
        with dpg.window(label="Bulk Rename Files", modal=True, show=False,
                       tag="bulk_rename_dialog", width=600, height=300):
            dpg.add_text("Rename Pattern:")
            dpg.add_input_text(label="Pattern", tag="rename_pattern",
                             hint="e.g., 'Photo_{counter:03d}' or '{name}_backup'")
            
            dpg.add_text("Preview:")
            with dpg.child_window(height=150, tag="rename_preview"):
                dpg.add_text("Select files and enter pattern to see preview")
            
            dpg.add_separator()
            with dpg.group(horizontal=True):
                dpg.add_button(label="Apply Rename", callback=self._apply_bulk_rename)
                dpg.add_button(label="Cancel", callback=lambda: dpg.hide_item("bulk_rename_dialog"))
        
        dpg.setup_dearpygui()
        dpg.show_viewport()
        dpg.set_primary_window("main_window", True)
    
    def _setup_theme(self):
        """Setup application theme"""
        with dpg.theme(tag="app_theme"):
            with dpg.theme_component(dpg.mvAll):
                dpg.add_theme_color(dpg.mvThemeCol_WindowBg, (15, 15, 15))
                dpg.add_theme_color(dpg.mvThemeCol_ChildBg, (25, 25, 25))
                dpg.add_theme_color(dpg.mvThemeCol_PopupBg, (35, 35, 35))
                dpg.add_theme_color(dpg.mvThemeCol_Border, (70, 70, 70))
                dpg.add_theme_color(dpg.mvThemeCol_Text, (255, 255, 255))
                dpg.add_theme_color(dpg.mvThemeCol_Button, (45, 45, 45))
                dpg.add_theme_color(dpg.YOUR_CLIENT_SECRET_HERE, (65, 65, 65))
                dpg.add_theme_color(dpg.mvThemeCol_ButtonActive, (85, 85, 85))
                dpg.add_theme_color(dpg.mvThemeCol_Header, (60, 60, 60))
                dpg.add_theme_color(dpg.YOUR_CLIENT_SECRET_HERE, (80, 80, 80))
                dpg.add_theme_color(dpg.mvThemeCol_HeaderActive, (100, 100, 100))
                
                dpg.add_theme_style(dpg.YOUR_CLIENT_SECRET_HERE, 5)
                dpg.add_theme_style(dpg.YOUR_CLIENT_SECRET_HERE, 5)
                dpg.add_theme_style(dpg.YOUR_CLIENT_SECRET_HERE, 3)
                dpg.add_theme_style(dpg.mvStyleVar_GrabRounding, 3)
                dpg.add_theme_style(dpg.mvStyleVar_TabRounding, 3)
        
        dpg.bind_theme("app_theme")
    
    def _apply_theme(self, theme_name):
        """Apply different themes"""
        if theme_name == "dark":
            self._setup_theme()
        elif theme_name == "light":
            with dpg.theme(tag="light_theme"):
                with dpg.theme_component(dpg.mvAll):
                    dpg.add_theme_color(dpg.mvThemeCol_WindowBg, (240, 240, 240))
                    dpg.add_theme_color(dpg.mvThemeCol_ChildBg, (250, 250, 250))
                    dpg.add_theme_color(dpg.mvThemeCol_Text, (0, 0, 0))
                    dpg.add_theme_color(dpg.mvThemeCol_Button, (200, 200, 200))
            dpg.bind_theme("light_theme")
    
    def _select_directory(self):
        """Show directory selection dialog"""
        dpg.show_item("directory_dialog")
    
    def _directory_selected(self, sender, app_data):
        """Handle directory selection"""
        self.current_directory = app_data['file_path_name']
        dpg.set_value("status_text", f"Selected: {self.current_directory}")
        self._analyze_directory()
    
    def _analyze_directory(self):
        """Analyze selected directory"""
        if not self.current_directory:
            dpg.set_value("status_text", "Please select a directory first")
            return
        
        def analyze_thread():
            def progress_callback(progress, message):
                dpg.set_value("progress_bar", progress)
                dpg.set_value("status_text", message)
            
            try:
                dpg.set_value("status_text", "Analyzing directory...")
                self.analysis_results = self.storage_analyzer.analyze_directory(
                    self.current_directory, progress_callback)
                self.scanned_files = self.analysis_results['files']
                
                # Update UI
                self._update_file_table()
                self._update_statistics()
                
                dpg.set_value("progress_bar", 1.0)
                dpg.set_value("status_text", 
                    f"Analysis complete: {len(self.scanned_files)} files, "
                    f"{self._format_size(self.analysis_results['total_size'])}")
                
            except Exception as e:
                dpg.set_value("status_text", f"Error: {str(e)}")
        
        threading.Thread(target=analyze_thread, daemon=True).start()
    
    def _update_file_table(self):
        """Update the file table with scanned files"""
        if dpg.does_item_exist("file_table"):
            dpg.delete_item("file_table", children_only=True)
        
        for file_info in self.scanned_files[:100]:  # Limit for performance
            with dpg.table_row(parent="file_table"):
                dpg.add_selectable(label=file_info['name'])
                dpg.add_text(self._format_size(file_info['size']))
                dpg.add_text(file_info['category'].title())
                dpg.add_text(file_info['modified'].strftime("%Y-%m-%d %H:%M"))
                dpg.add_text(file_info['path'])
    
    def _update_statistics(self):
        """Update storage statistics display"""
        if not self.analysis_results:
            return
        
        # Category distribution plot
        categories = list(self.analysis_results['category_stats'].keys())
        sizes = [self.analysis_results['category_stats'][cat]['size'] for cat in categories]
        
        if dpg.does_item_exist("category_plot"):
            dpg.set_value("category_plot", sizes)
        
        # Size distribution plot
        size_dist = self.analysis_results['size_distribution']
        size_values = list(size_dist.values())
        
        if dpg.does_item_exist("size_plot"):
            dpg.set_value("size_plot", size_values)
        
        # Statistics text
        stats_text = f"""Total Files: {self.analysis_results['total_files']:,}
Total Size: {self._format_size(self.analysis_results['total_size'])}

File Types:
"""
        for category, stats in self.analysis_results['category_stats'].items():
            percentage = (stats['size'] / self.analysis_results['total_size']) * 100
            stats_text += f"  {category.title()}: {stats['count']} files, "
            stats_text += f"{self._format_size(stats['size'])} ({percentage:.1f}%)\n"
        
        if dpg.does_item_exist("storage_stats"):
            dpg.set_value("storage_stats", stats_text)
    
    def _find_duplicates(self):
        """Find duplicate files"""
        if not self.scanned_files:
            dpg.set_value("status_text", "Please analyze a directory first")
            return
        
        def find_thread():
            def progress_callback(progress, message):
                dpg.set_value("progress_bar", progress)
                dpg.set_value("status_text", message)
            
            try:
                dpg.set_value("status_text", "Finding duplicates...")
                self.duplicates = self.duplicate_detector.find_duplicates_by_hash(
                    self.scanned_files, progress_callback)
                
                self.YOUR_CLIENT_SECRET_HERE()
                
                duplicate_count = sum(len(group) for group in self.duplicates)
                dpg.set_value("status_text", 
                    f"Found {len(self.duplicates)} duplicate groups with {duplicate_count} files")
                
            except Exception as e:
                dpg.set_value("status_text", f"Error finding duplicates: {str(e)}")
        
        threading.Thread(target=find_thread, daemon=True).start()
    
    def _find_exact_duplicates(self):
        """Find exact duplicate files"""
        self._find_duplicates()
    
    def _find_similar_files(self):
        """Find similar files"""
        if not self.scanned_files:
            dpg.set_value("status_text", "Please analyze a directory first")
            return
        
        def find_thread():
            try:
                dpg.set_value("status_text", "Finding similar files...")
                similar_groups = self.duplicate_detector.find_similar_files(self.scanned_files)
                
                # Convert to duplicate format for display
                self.duplicates = similar_groups
                self.YOUR_CLIENT_SECRET_HERE()
                
                similar_count = sum(len(group) for group in similar_groups)
                dpg.set_value("status_text", 
                    f"Found {len(similar_groups)} similar groups with {similar_count} files")
                
            except Exception as e:
                dpg.set_value("status_text", f"Error finding similar files: {str(e)}")
        
        threading.Thread(target=find_thread, daemon=True).start()
    
    def YOUR_CLIENT_SECRET_HERE(self):
        """Update duplicates table"""
        if dpg.does_item_exist("duplicates_table"):
            dpg.delete_item("duplicates_table", children_only=True)
        
        for group_idx, group in enumerate(self.duplicates):
            for file_info in group:
                with dpg.table_row(parent="duplicates_table"):
                    dpg.add_selectable(label=f"Group {group_idx + 1}")
                    dpg.add_text(file_info['name'])
                    dpg.add_text(self._format_size(file_info['size']))
                    dpg.add_text(file_info['path'])
                    dpg.add_text(file_info.get('hash', 'N/A')[:10] + '...')
    
    def _organize_files(self):
        """Organize files based on rules"""
        if not self.scanned_files:
            dpg.set_value("status_text", "Please analyze a directory first")
            return
        
        def organize_thread():
            def progress_callback(progress, message):
                dpg.set_value("progress_bar", progress)
                dpg.set_value("status_text", message)
            
            try:
                operations = self.organizer.organize_files(
                    self.scanned_files, self.current_directory, progress_callback)
                
                # Execute operations
                successful = 0
                for operation in operations:
                    try:
                        # Create destination directory if needed
                        dest_dir = os.path.dirname(operation['destination'])
                        os.makedirs(dest_dir, exist_ok=True)
                        
                        # Move file
                        shutil.move(operation['source'], operation['destination'])
                        successful += 1
                        
                        # Log operation
                        self._log_operation(operation, True, None)
                        
                    except Exception as e:
                        self._log_operation(operation, False, str(e))
                
                dpg.set_value("status_text", 
                    f"Organization complete: {successful}/{len(operations)} files moved")
                
                # Refresh analysis
                self._analyze_directory()
                
            except Exception as e:
                dpg.set_value("status_text", f"Error organizing files: {str(e)}")
        
        threading.Thread(target=organize_thread, daemon=True).start()
    
    def _toggle_monitoring(self):
        """Toggle folder monitoring"""
        if not self.monitoring:
            if not self.current_directory:
                dpg.set_value("status_text", "Please select a directory first")
                return
            
            self.monitor_handler = FolderMonitor(self._on_file_event)
            self.observer = Observer()
            self.observer.schedule(self.monitor_handler, self.current_directory, recursive=True)
            self.observer.start()
            
            self.monitoring = True
            dpg.set_value("monitor_button", "Stop Monitoring")
            dpg.set_value("monitor_status", "Status: Monitoring")
            dpg.set_value("status_text", f"Monitoring: {self.current_directory}")
        else:
            if self.observer:
                self.observer.stop()
                self.observer.join()
            
            self.monitoring = False
            dpg.set_value("monitor_button", "Start Monitoring")
            dpg.set_value("monitor_status", "Status: Stopped")
            dpg.set_value("status_text", "Monitoring stopped")
    
    def _on_file_event(self, event_type, file_path):
        """Handle file system events"""
        timestamp = datetime.now().strftime("%H:%M:%S")
        event_text = f"[{timestamp}] {event_type.upper()}: {os.path.basename(file_path)}"
        
        # Update events display (simplified - in real app you'd maintain a list)
        if dpg.does_item_exist("monitor_events"):
            current_text = dpg.get_value("monitor_events")
            new_text = event_text + "\n" + current_text
            # Keep only last 20 events
            lines = new_text.split('\n')[:20]
            dpg.set_value("monitor_events", '\n'.join(lines))
    
    def _show_add_rule_dialog(self):
        """Show add rule dialog"""
        dpg.show_item("add_rule_dialog")
    
    def _add_rule(self):
        """Add new organization rule"""
        name = dpg.get_value("rule_name_input")
        folder_pattern = dpg.get_value("folder_pattern_input")
        
        if not name or not folder_pattern:
            return
        
        # Get selected categories
        categories = []
        for category in self.analyzer.supported_types.keys():
            if dpg.get_value(f"category_{category}"):
                categories.append(category)
        
        rule = {
            'name': name,
            'category': categories,
            'folder_pattern': folder_pattern
        }
        
        # Add size constraints if specified
        min_size = dpg.get_value("min_size_input")
        max_size = dpg.get_value("max_size_input")
        
        if min_size > 0:
            rule['size_min'] = min_size * 1024 * 1024
        if max_size > 0:
            rule['size_max'] = max_size * 1024 * 1024
        
        self.organizer.add_rule(rule)
        self._update_rules_list()
        dpg.hide_item("add_rule_dialog")
    
    def _update_rules_list(self):
        """Update organization rules list"""
        rule_names = [rule.get('name', 'Unnamed Rule') for rule in self.organizer.rules]
        if dpg.does_item_exist("rules_list"):
            dpg.configure_item("rules_list", items=rule_names)
    
    def _show_bulk_rename(self):
        """Show bulk rename dialog"""
        dpg.show_item("bulk_rename_dialog")
    
    def _apply_bulk_rename(self):
        """Apply bulk rename to selected files"""
        pattern = dpg.get_value("rename_pattern")
        if not pattern:
            return
        
        # This is a simplified implementation
        # In a real app, you'd track selected files and apply the pattern
        dpg.set_value("status_text", "Bulk rename feature would be implemented here")
        dpg.hide_item("bulk_rename_dialog")
    
    def YOUR_CLIENT_SECRET_HERE(self):
        """Delete selected duplicate files"""
        # This is a placeholder - in a real app you'd track selections
        dpg.set_value("status_text", "Duplicate deletion feature would be implemented here")
    
    def _log_operation(self, operation, success, error_message):
        """Log operation to database"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        cursor.execute('''
            INSERT INTO operations (action, source_path, destination_path, timestamp, success, error_message)
            VALUES (?, ?, ?, ?, ?, ?)
        ''', (
            operation['action'],
            operation['source'],
            operation['destination'],
            operation['timestamp'].isoformat(),
            success,
            error_message
        ))
        
        conn.commit()
        conn.close()
    
    def _format_size(self, size_bytes):
        """Format file size in human readable format"""
        if size_bytes == 0:
            return "0 B"
        
        size_names = ["B", "KB", "MB", "GB", "TB"]
        i = int(math.floor(math.log(size_bytes, 1024)))
        p = math.pow(1024, i)
        s = round(size_bytes / p, 2)
        
        return f"{s} {size_names[i]}"
    
    def _refresh_analysis(self):
        """Refresh directory analysis"""
        if self.current_directory:
            self._analyze_directory()
    
    def _show_statistics(self):
        """Show detailed statistics"""
        if not self.analysis_results:
            dpg.set_value("status_text", "Please analyze a directory first")
            return
        
        # This would open a detailed statistics window
        dpg.set_value("status_text", "Detailed statistics feature would be implemented here")
    
    def _edit_selected_rule(self):
        """Edit selected organization rule"""
        # Placeholder for rule editing
        dpg.set_value("status_text", "Rule editing feature would be implemented here")
    
    def _delete_selected_rule(self):
        """Delete selected organization rule"""
        # Placeholder for rule deletion
        dpg.set_value("status_text", "Rule deletion feature would be implemented here")
    
    def run(self):
        """Run the application"""
        dpg.create_viewport(title="Advanced File Manager", width=1200, height=800)
        self.setup_ui()
        
        # Setup initial rules list
        self._update_rules_list()
        
        dpg.start_dearpygui()
        
        # Cleanup
        if self.monitoring and self.observer:
            self.observer.stop()
            self.observer.join()
        
        dpg.destroy_context()

if __name__ == "__main__":
    # Install required packages if not available
    try:
        import dearpygui.dearpygui as dpg
        from watchdog.observers import Observer
        from watchdog.events import FileSystemEventHandler
    except ImportError as e:
        print(f"Missing required package: {e}")
        print("Please install required packages:")
        print("pip install dearpygui watchdog")
        exit(1)
    
    app = FileManagerApp()
    app.run()
