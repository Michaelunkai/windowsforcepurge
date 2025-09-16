import sys
import os
import shutil
import threading
import ctypes
import string
from datetime import datetime
from pathlib import Path
from PyQt5.QtWidgets import (QApplication, QWidget, QVBoxLayout, QHBoxLayout,
                             QPushButton, QTableWidget, QTableWidgetItem,
                             QMessageBox, QLabel, QHeaderView, QAbstractItemView,
                             QProgressBar, QStatusBar, QMainWindow, QSplitter,
                             QCheckBox, QFrame, QFileDialog, QButtonGroup, QRadioButton)
from PyQt5.QtCore import Qt, QThread, pyqtSignal, QTimer
from PyQt5.QtGui import QFont, QIcon, QPalette, QClipboard, QLinearGradient, QBrush, QColor


def get_available_drives():
    """Get all available drive letters on the system."""
    available_drives = []
    for letter in string.ascii_uppercase:
        drive_path = f"{letter}:\\"
        if os.path.exists(drive_path):
            try:
                # Try to access the drive to make sure it's readable
                os.listdir(drive_path)
                available_drives.append(letter)
            except (PermissionError, FileNotFoundError, OSError):
                # Drive exists but not accessible, still add it
                available_drives.append(letter)
    return available_drives


def force_delete_on_reboot(file_path):
    """Schedule a file for deletion on next reboot using Windows API."""
    try:
        # Use MoveFileEx with YOUR_CLIENT_SECRET_HERE flag
        YOUR_CLIENT_SECRET_HERE = 0x4
        ctypes.windll.kernel32.MoveFileExW(
            ctypes.c_wchar_p(file_path),
            None,
            ctypes.c_ulong(YOUR_CLIENT_SECRET_HERE)
        )
        return True
    except Exception:
        return False


class FileScannerThread(QThread):
    """Background thread for scanning files to keep GUI responsive."""
    
    progress_updated = pyqtSignal(str)  # Status message
    scan_completed = pyqtSignal(list)  # List of (path, size_mb, is_safe_to_delete) tuples
    error_occurred = pyqtSignal(str)   # Error message
    
    def __init__(self, scan_path='C:\\', scan_type='drive', scan_mode='safe_only'):
        super().__init__()
        self.stop_requested = False
        self.scan_path = scan_path
        self.scan_type = scan_type  # 'drive' or 'folder'
        self.scan_mode = scan_mode  # 'safe_only' or 'show_all'
        
    def request_stop(self):
        """Request the thread to stop scanning."""
        self.stop_requested = True
        
    def run(self):
        """Main scanning logic running in background thread."""
        try:
            scan_display = self.scan_path if self.scan_type == 'folder' else f"{self.scan_path[0]}: drive"
            self.progress_updated.emit(f"Starting scan of {scan_display}...")
            
            # Keywords to filter out (case-insensitive)
            exclusion_keywords = [
                'microsoft', 'asus', 'nvidia', 'amd', 'python', 'pip', 
                'docker', 'wsl 2', 'wemod', 'cursor', 'chrome', 
                'firefox', 'mozilla', 'drivers', 'driver'
            ]
            
            files_data = []
            scanned_count = 0
            
            # Define safe-to-delete file patterns and folders
            safe_extensions = {
                '.tmp', '.temp', '.log', '.bak', '.backup', '.old', '.dmp',
                '.cache', '.crdownload', '.partial', '.prefetch', '.chk',
                '.etl', '.evtx', '.wer', '.cab', '.dmp', '.mdmp', '.hdmp',
                '.trace', '.blf', '.regtrans-ms', '.dat.old', '.bak~'
            }
            
            safe_folders = {
                'temp', 'tmp', 'cache', 'logs', 'backup', 'backups',
                'recycle.bin', '$recycle.bin', 'system volume information',
                'windows.old', 'prefetch', 'recent', 'temporary internet files',
                'downloaded program files', 'internet cache', 'webcache',
                'windows error reporting', 'minidump', 'memory dumps',
                'thumbnail cache', 'icon cache', 'crash dumps'
            }
            
            # Scan the specified path recursively
            for root, dirs, files in os.walk(self.scan_path):
                if self.stop_requested:
                    self.progress_updated.emit("Scan cancelled by user.")
                    return
                    
                # Skip directories that match exclusion keywords
                dirs[:] = [d for d in dirs if not any(keyword in d.lower() for keyword in exclusion_keywords)]
                
                for file in files:
                    if self.stop_requested:
                        return
                        
                    try:
                        file_path = os.path.join(root, file)
                        
                        # Check if path contains any exclusion keywords
                        if any(keyword in file_path.lower() for keyword in exclusion_keywords):
                            continue
                            
                        # Get file size
                        size_bytes = os.path.getsize(file_path)
                        size_mb = size_bytes / (1024 * 1024)  # Convert to MB
                        
                        # Check if file is safe to delete
                        is_safe_to_delete = self.is_safe_to_delete(file_path, safe_extensions, safe_folders)
                        
                        # Include files based on scan mode
                        if self.scan_mode == 'show_all' or (self.scan_mode == 'safe_only' and is_safe_to_delete):
                            files_data.append((file_path, size_mb, is_safe_to_delete))
                            scanned_count += 1
                        
                        # Update progress every 1000 files
                        if scanned_count % 1000 == 0:
                            self.progress_updated.emit(f"Scanned {scanned_count} files...")
                            
                    except (PermissionError, FileNotFoundError, OSError) as e:
                        # Silently continue on permission errors or file access issues
                        continue
                        
            if self.stop_requested:
                return
                
            self.progress_updated.emit("Processing results...")
            
            # Sort by size descending and take top 1000
            files_data.sort(key=lambda x: x[1], reverse=True)
            top_files = files_data[:1000]
            
            if self.scan_mode == 'safe_only':
                self.progress_updated.emit(f"Scan complete! Found {len(top_files)} safe-to-delete files.")
            else:
                safe_count = sum(1 for _, _, is_safe in top_files if is_safe)
                self.progress_updated.emit(f"Scan complete! Found {len(top_files)} files ({safe_count} safe, {len(top_files) - safe_count} risky).")
            self.scan_completed.emit(top_files)
            
        except Exception as e:
            self.error_occurred.emit(f"Scan error: {str(e)}")
    
    def is_safe_to_delete(self, file_path, safe_extensions, safe_folders):
        """Determine if a file is generally safe to delete for freeing space."""
        file_path_lower = file_path.lower()
        file_name = os.path.basename(file_path_lower)
        dir_name = os.path.dirname(file_path_lower)
        
        # Check file extension
        file_ext = os.path.splitext(file_name)[1]
        if file_ext in safe_extensions:
            return True
        
        # Check if file is in a safe folder
        for safe_folder in safe_folders:
            if safe_folder in dir_name:
                return True
        
        # Check specific safe file patterns
        safe_patterns = [
            'thumbs.db', 'desktop.ini', '.ds_store', 'hiberfil.sys',
            'pagefile.sys', 'swapfile.sys', 'memory.dmp', 'error.log',
            'crash', 'dump', 'minidump', 'temp_', '_temp', 'temporary',
            'cache_', '_cache', 'backup_', '_backup', 'old_', '_old'
        ]
        
        for pattern in safe_patterns:
            if pattern in file_name:
                return True
        
        # Check Windows and application temporary directories
        temp_paths = [
            '\\\\windows\\\\temp\\\\', '\\\\temp\\\\', '\\\\tmp\\\\',
            '\\\\appdata\\\\local\\\\temp\\\\', '\\\\appdata\\\\roaming\\\\temp\\\\',
            '\\\\windows\\\\prefetch\\\\', '\\\\windows\\\\logs\\\\',
            '\\\\windows\\\\winsxs\\\\backup\\\\', '\\\\windows\\\\softwaredistribution\\\\',
            '\\\\programdata\\\\microsoft\\\\windows\\\\wer\\\\',
            '\\\\users\\\\.*\\\\appdata\\\\local\\\\crashdumps\\\\',
            '\\\\windows\\\\system32\\\\logfiles\\\\',
            '\\\\windows\\\\memory.dmp', '\\\\windows\\\\minidump\\\\',
            '\\\\windows\\\\temp\\\\', '\\\\windows\\\\logs\\\\cbs\\\\',
            '\\\\windows\\\\logs\\\\dism\\\\', '\\\\windows\\\\panther\\\\',
            '\\\\windows\\\\inf\\\\setupapi\\\\'
        ]
        
        for temp_path in temp_paths:
            if temp_path in file_path_lower:
                return True
        
        # Check for files larger than 100MB in temp/cache locations
        if any(folder in dir_name for folder in ['temp', 'cache', 'log']):
            if os.path.exists(file_path):
                try:
                    size_bytes = os.path.getsize(file_path)
                    size_mb = size_bytes / (1024 * 1024)
                    if size_mb >= 100:  # Large temp/cache files are usually safe to delete
                        return True
                except:
                    pass
        
        return False


class MainAppWindow(QMainWindow):
    """Main application window for the C: Drive Cleaner."""
    
    def __init__(self):
        super().__init__()
        self.scanner_thread = None
        self.files_data = []
        self.current_drive = 'C'
        self.scan_type = 'drive'  # 'drive' or 'folder'
        self.scan_mode = 'safe_only'  # 'safe_only' or 'show_all'
        self.selected_folder = ''
        self.disk_space_timer = QTimer()
        self.disk_space_timer.timeout.connect(self.update_disk_space)
        self.init_ui()
        self.update_disk_space()
        self.disk_space_timer.start(2000)  # Update every 2 seconds
        
    def init_ui(self):
        """Initialize the user interface."""
        self.setWindowTitle("Smart Drive Cleaner - Safe & Advanced Scanning")
        self.setGeometry(100, 100, 1200, 800)
        
        # Create central widget and main layout
        central_widget = QWidget()
        central_widget.setStyleSheet("""
            QWidget {
                background: qlineargradient(x1:0, y1:0, x2:1, y2:1,
                    stop:0 #f8f9fa, stop:0.3 #e9ecef, stop:0.7 #dee2e6, stop:1 #ced4da);
            }
        """)
        self.setCentralWidget(central_widget)
        main_layout = QVBoxLayout(central_widget)
        
        # Mode info label
        warning_label = QLabel(
            "🎯 SMART SCANNER: Choose between Safe Mode (recommended - only temp/cache files) "
            "or Show All Mode (advanced - displays everything with color-coded safety indicators). "
            "AMD, drivers, Chrome, Firefox and other critical software are always excluded."
        )
        warning_label.setStyleSheet("""
            QLabel {
                background-color: #e8f5e8;
                color: #2e7d32;
                border: 2px solid #4caf50;
                border-radius: 5px;
                padding: 10px;
                font-weight: bold;
            }
        """)
        warning_label.setWordWrap(True)
        main_layout.addWidget(warning_label)
        
        # Admin privileges note
        admin_note = QLabel(
            "📋 Note: This application may require administrator privileges to scan the entire C: drive "
            "effectively and delete protected files. Run as administrator if needed."
        )
        admin_note.setStyleSheet("""
            QLabel {
                background-color: #e3f2fd;
                color: #1565c0;
                border: 1px solid #42a5f5;
                border-radius: 3px;
                padding: 8px;
            }
        """)
        admin_note.setWordWrap(True)
        main_layout.addWidget(admin_note)
        
        # Scan type selection
        self.YOUR_CLIENT_SECRET_HERE()
        main_layout.addWidget(self.scan_type_frame)
        
        # Scan mode selection
        self.YOUR_CLIENT_SECRET_HERE()
        main_layout.addWidget(self.scan_mode_frame)
        
        # Drive selection
        self.create_drive_selection()
        main_layout.addWidget(self.drive_selection_frame)
        
        # Disk space display
        self.YOUR_CLIENT_SECRET_HERE()
        main_layout.addWidget(self.disk_space_frame)
        
        # Control buttons layout
        controls_layout = QHBoxLayout()
        
        self.scan_button = QPushButton("🔍 Start Scan")
        self.update_scan_button_text()
        self.scan_button.setMinimumHeight(40)
        self.scan_button.setStyleSheet("""
            QPushButton {
                background-color: #2e7d32;
                color: white;
                border: none;
                border-radius: 5px;
                font-size: 14px;
                font-weight: bold;
            }
            QPushButton:hover {
                background-color: #388e3c;
            }
            QPushButton:disabled {
                background-color: #757575;
            }
        """)
        self.scan_button.clicked.connect(self.start_scan)
        controls_layout.addWidget(self.scan_button)
        
        self.stop_button = QPushButton("⏹️ Stop Scan")
        self.stop_button.setMinimumHeight(40)
        self.stop_button.setEnabled(False)
        self.stop_button.setStyleSheet("""
            QPushButton {
                background-color: #d32f2f;
                color: white;
                border: none;
                border-radius: 5px;
                font-size: 14px;
                font-weight: bold;
            }
            QPushButton:hover {
                background-color: #f44336;
            }
            QPushButton:disabled {
                background-color: #757575;
            }
        """)
        self.stop_button.clicked.connect(self.stop_scan)
        controls_layout.addWidget(self.stop_button)
        
        # Bulk operations
        self.select_all_button = QPushButton("☑️ Select All")
        self.select_all_button.setMinimumHeight(40)
        self.select_all_button.setStyleSheet("""
            QPushButton {
                background-color: #1976d2;
                color: white;
                border: none;
                border-radius: 5px;
                font-size: 14px;
                font-weight: bold;
            }
            QPushButton:hover {
                background-color: #2196f3;
            }
        """)
        self.select_all_button.clicked.connect(self.select_all_files)
        controls_layout.addWidget(self.select_all_button)
        
        self.clear_selection_button = QPushButton("☐ Clear Selection")
        self.clear_selection_button.setMinimumHeight(40)
        self.clear_selection_button.setStyleSheet("""
            QPushButton {
                background-color: #757575;
                color: white;
                border: none;
                border-radius: 5px;
                font-size: 14px;
                font-weight: bold;
            }
            QPushButton:hover {
                background-color: #9e9e9e;
            }
        """)
        self.clear_selection_button.clicked.connect(self.clear_selection)
        controls_layout.addWidget(self.clear_selection_button)
        
        self.bulk_delete_button = QPushButton("🗑️ Delete Selected")
        self.bulk_delete_button.setMinimumHeight(40)
        self.bulk_delete_button.setStyleSheet("""
            QPushButton {
                background-color: #d32f2f;
                color: white;
                border: none;
                border-radius: 5px;
                font-size: 14px;
                font-weight: bold;
            }
            QPushButton:hover {
                background-color: #f44336;
            }
        """)
        self.bulk_delete_button.clicked.connect(self.bulk_delete_files)
        controls_layout.addWidget(self.bulk_delete_button)
        
        self.copy_selected_button = QPushButton("📋 Copy Selected")
        self.copy_selected_button.setMinimumHeight(40)
        self.copy_selected_button.setStyleSheet("""
            QPushButton {
                background-color: #ff9800;
                color: white;
                border: none;
                border-radius: 5px;
                font-size: 14px;
                font-weight: bold;
            }
            QPushButton:hover {
                background-color: #ffa726;
            }
        """)
        self.copy_selected_button.clicked.connect(self.copy_selected_files)
        controls_layout.addWidget(self.copy_selected_button)
        
        self.purge_all_temps_button = QPushButton("🚀 Purge All Temps")
        self.purge_all_temps_button.setMinimumHeight(40)
        self.purge_all_temps_button.setStyleSheet("""
            QPushButton {
                background: qlineargradient(x1:0, y1:0, x2:0, y2:1,
                    stop:0 #e91e63, stop:1 #c2185b);
                color: white;
                border: none;
                border-radius: 5px;
                font-size: 14px;
                font-weight: bold;
            }
            QPushButton:hover {
                background: qlineargradient(x1:0, y1:0, x2:0, y2:1,
                    stop:0 #f06292, stop:1 #e91e63);
            }
        """)
        self.purge_all_temps_button.clicked.connect(self.purge_all_temps)
        controls_layout.addWidget(self.purge_all_temps_button)
        
        controls_layout.addStretch()
        main_layout.addLayout(controls_layout)
        
        # Progress bar
        self.progress_bar = QProgressBar()
        self.progress_bar.setVisible(False)
        self.progress_bar.setRange(0, 0)  # Indeterminate progress
        main_layout.addWidget(self.progress_bar)
        
        # Results table
        self.create_results_table()
        main_layout.addWidget(self.results_table)
        
        # Status bar
        self.status_bar = QStatusBar()
        self.setStatusBar(self.status_bar)
        self.status_bar.showMessage(f"Ready to scan {self.current_drive}: drive for safe-to-delete files")
        
    def create_results_table(self):
        """Create and configure the results table."""
        self.results_table = QTableWidget()
        self.results_table.setColumnCount(3)
        self.results_table.YOUR_CLIENT_SECRET_HERE(["File Path", "Size (MB)", "Action"])
        
        # Configure table appearance
        self.results_table.setAlternatingRowColors(True)
        self.results_table.setSelectionBehavior(QAbstractItemView.SelectRows)
        self.results_table.setSelectionMode(QAbstractItemView.ExtendedSelection)  # Enable multi-selection
        self.results_table.setSortingEnabled(True)
        
        # Set column widths
        header = self.results_table.horizontalHeader()
        header.setSectionResizeMode(0, QHeaderView.Stretch)  # File path column stretches
        header.setSectionResizeMode(1, QHeaderView.Fixed)    # Size column fixed
        header.setSectionResizeMode(2, QHeaderView.Fixed)    # Action column fixed
        self.results_table.setColumnWidth(1, 120)
        self.results_table.setColumnWidth(2, 100)
        
        # Style the table
        self.results_table.setStyleSheet("""
            QTableWidget {
                gridline-color: #e0e0e0;
                background-color: white;
            }
            QTableWidget::item {
                padding: 8px;
                border-bottom: 1px solid #e0e0e0;
            }
            QTableWidget::item:selected {
                background-color: #e3f2fd;
            }
            QHeaderView::section {
                background-color: #f5f5f5;
                padding: 10px;
                border: none;
                border-right: 1px solid #e0e0e0;
                font-weight: bold;
            }
        """)
    
    def YOUR_CLIENT_SECRET_HERE(self):
        """Create the scan type selection widget."""
        self.scan_type_frame = QFrame()
        self.scan_type_frame.setFrameStyle(QFrame.StyledPanel | QFrame.Raised)
        self.scan_type_frame.setStyleSheet("""
            QFrame {
                background: qlineargradient(x1:0, y1:0, x2:1, y2:0,
                    stop:0 #fff3e0, stop:0.5 #ffcc80, stop:1 #ffb74d);
                border: 3px solid qlineargradient(x1:0, y1:0, x2:1, y2:0,
                    stop:0 #ff9800, stop:1 #ffa726);
                border-radius: 12px;
                padding: 15px;
                margin: 8px;
            }
        """)
        
        layout = QHBoxLayout(self.scan_type_frame)
        
        # Title
        title_label = QLabel("📂 Select Scan Type:")
        title_label.setStyleSheet("font-weight: bold; font-size: 14px; color: #333;")
        layout.addWidget(title_label)
        
        # Radio buttons for scan type
        self.scan_type_group = QButtonGroup()
        
        self.drive_radio = QRadioButton("Scan Entire Drive")
        self.drive_radio.setChecked(True)
        self.drive_radio.setStyleSheet("font-size: 12px; margin: 5px;")
        self.drive_radio.toggled.connect(self.on_scan_type_changed)
        self.scan_type_group.addButton(self.drive_radio)
        layout.addWidget(self.drive_radio)
        
        self.folder_radio = QRadioButton("Scan Specific Folder")
        self.folder_radio.setStyleSheet("font-size: 12px; margin: 5px;")
        self.folder_radio.toggled.connect(self.on_scan_type_changed)
        self.scan_type_group.addButton(self.folder_radio)
        layout.addWidget(self.folder_radio)
        
        # Folder selection button
        self.folder_button = QPushButton("📁 Browse Folder")
        self.folder_button.setEnabled(False)
        self.folder_button.setMinimumHeight(30)
        self.folder_button.setStyleSheet("""
            QPushButton {
                background-color: #ff9800;
                color: white;
                border: none;
                border-radius: 5px;
                font-size: 12px;
                font-weight: bold;
                padding: 5px 15px;
            }
            QPushButton:hover {
                background-color: #ffa726;
            }
            QPushButton:disabled {
                background-color: #bdbdbd;
            }
        """)
        self.folder_button.clicked.connect(self.browse_folder)
        layout.addWidget(self.folder_button)
        
        # Selected folder label
        self.selected_folder_label = QLabel("No folder selected")
        self.selected_folder_label.setStyleSheet("font-size: 11px; color: #666; font-style: italic;")
        layout.addWidget(self.selected_folder_label)
        
        layout.addStretch()
    
    def on_scan_type_changed(self):
        """Handle scan type radio button changes."""
        if self.drive_radio.isChecked():
            self.scan_type = 'drive'
            self.folder_button.setEnabled(False)
            self.selected_folder_label.setText("No folder selected")
        else:
            self.scan_type = 'folder'
            self.folder_button.setEnabled(True)
            if not self.selected_folder:
                self.selected_folder_label.setText("Click 'Browse Folder' to select")
        
        self.update_scan_button_text()
    
    def browse_folder(self):
        """Open folder browser dialog."""
        folder = QFileDialog.getExistingDirectory(
            self, 
            "Select Folder to Scan",
            "",
            QFileDialog.ShowDirsOnly
        )
        
        if folder:
            self.selected_folder = folder
            # Truncate path if too long for display
            display_path = folder
            if len(display_path) > 50:
                display_path = "..." + display_path[-47:]
            self.selected_folder_label.setText(f"Selected: {display_path}")
            self.update_scan_button_text()
    
    def YOUR_CLIENT_SECRET_HERE(self):
        """Create the scan mode selection widget."""
        self.scan_mode_frame = QFrame()
        self.scan_mode_frame.setFrameStyle(QFrame.StyledPanel | QFrame.Raised)
        self.scan_mode_frame.setStyleSheet("""
            QFrame {
                background: qlineargradient(x1:0, y1:0, x2:1, y2:0,
                    stop:0 #f3e5f5, stop:0.5 #e1bee7, stop:1 #ce93d8);
                border: 3px solid qlineargradient(x1:0, y1:0, x2:1, y2:0,
                    stop:0 #9c27b0, stop:1 #ab47bc);
                border-radius: 12px;
                padding: 15px;
                margin: 8px;
            }
        """)
        
        layout = QHBoxLayout(self.scan_mode_frame)
        
        # Title
        title_label = QLabel("🎯 Scan Mode:")
        title_label.setStyleSheet("font-weight: bold; font-size: 14px; color: #333;")
        layout.addWidget(title_label)
        
        # Radio buttons for scan mode
        self.scan_mode_group = QButtonGroup()
        
        self.safe_only_radio = QRadioButton("Safe Files Only (Recommended)")
        self.safe_only_radio.setChecked(True)
        self.safe_only_radio.setStyleSheet("font-size: 12px; margin: 5px; color: #2e7d32;")
        self.safe_only_radio.setToolTip("Only shows temporary files, cache, logs and other files safe to delete")
        self.safe_only_radio.toggled.connect(self.on_scan_mode_changed)
        self.scan_mode_group.addButton(self.safe_only_radio)
        layout.addWidget(self.safe_only_radio)
        
        self.show_all_radio = QRadioButton("Show Everything")
        self.show_all_radio.setStyleSheet("font-size: 12px; margin: 5px; color: #d32f2f;")
        self.show_all_radio.setToolTip("Shows ALL files in the location - use with extreme caution!")
        self.show_all_radio.toggled.connect(self.on_scan_mode_changed)
        self.scan_mode_group.addButton(self.show_all_radio)
        layout.addWidget(self.show_all_radio)
        
        # Info label
        self.scan_mode_info = QLabel("✅ Safe mode: Only temporary and cache files")
        self.scan_mode_info.setStyleSheet("font-size: 11px; color: #2e7d32; font-style: italic;")
        layout.addWidget(self.scan_mode_info)
        
        layout.addStretch()
    
    def on_scan_mode_changed(self):
        """Handle scan mode radio button changes."""
        if self.safe_only_radio.isChecked():
            self.scan_mode = 'safe_only'
            self.scan_mode_info.setText("✅ Safe mode: Only temporary and cache files")
            self.scan_mode_info.setStyleSheet("font-size: 11px; color: #2e7d32; font-style: italic;")
        else:
            self.scan_mode = 'show_all'
            self.scan_mode_info.setText("⚠️ Show All mode: ALL files will be displayed!")
            self.scan_mode_info.setStyleSheet("font-size: 11px; color: #d32f2f; font-style: italic; font-weight: bold;")
    
    def update_scan_button_text(self):
        """Update the scan button text based on current selection."""
        if self.scan_type == 'drive':
            self.scan_button.setText(f"🔍 Start {self.current_drive}: Drive Scan")
        else:
            if self.selected_folder:
                folder_name = os.path.basename(self.selected_folder)
                if not folder_name:
                    folder_name = self.selected_folder
                self.scan_button.setText(f"🔍 Scan Folder: {folder_name}")
            else:
                self.scan_button.setText("🔍 Select Folder to Scan")
        
    def start_scan(self):
        """Start the file scanning process."""
        if self.scanner_thread and self.scanner_thread.isRunning():
            return
        
        # Validate scan selection
        if self.scan_type == 'folder' and not self.selected_folder:
            QMessageBox.warning(self, "No Folder Selected", 
                              "Please select a folder to scan first.")
            return
        
        # Determine scan path
        if self.scan_type == 'drive':
            scan_path = f'{self.current_drive}:\\'
        else:
            scan_path = self.selected_folder
            
        # Clear previous results
        self.results_table.setRowCount(0)
        self.files_data.clear()
        
        # Update UI for scanning state
        self.scan_button.setEnabled(False)
        self.stop_button.setEnabled(True)
        self.progress_bar.setVisible(True)
        
        # Create and start scanner thread
        self.scanner_thread = FileScannerThread(scan_path, self.scan_type, self.scan_mode)
        self.scanner_thread.progress_updated.connect(self.update_status)
        self.scanner_thread.scan_completed.connect(self.on_scan_completed)
        self.scanner_thread.error_occurred.connect(self.on_scan_error)
        self.scanner_thread.finished.connect(self.on_scan_finished)
        self.scanner_thread.start()
        
    def stop_scan(self):
        """Stop the current scan."""
        if self.scanner_thread and self.scanner_thread.isRunning():
            self.scanner_thread.request_stop()
            self.update_status("Stopping scan...")
            
    def update_status(self, message):
        """Update the status bar with a message."""
        self.status_bar.showMessage(message)
        
    def on_scan_completed(self, files_data):
        """Handle completion of file scan."""
        self.files_data = files_data
        self.populate_results_table()
        
    def on_scan_error(self, error_message):
        """Handle scan errors."""
        QMessageBox.critical(self, "Scan Error", error_message)
        
    def on_scan_finished(self):
        """Handle scan thread completion."""
        self.scan_button.setEnabled(True)
        self.stop_button.setEnabled(False)
        self.progress_bar.setVisible(False)
        
    def populate_results_table(self):
        """Populate the results table with scanned files."""
        self.results_table.setRowCount(len(self.files_data))
        safe_count = 0
        
        for row, (file_path, size_mb, is_safe_to_delete) in enumerate(self.files_data):            
            # File path
            path_item = QTableWidgetItem(file_path)
            path_item.setFlags(path_item.flags() & ~Qt.ItemIsEditable)
            
            # File size
            size_item = QTableWidgetItem(f"{size_mb:.2f}")
            size_item.setFlags(size_item.flags() & ~Qt.ItemIsEditable)
            size_item.setTextAlignment(Qt.AlignRight | Qt.AlignVCenter)
            
            # Color coding and button styling based on safety
            if is_safe_to_delete:
                safe_count += 1
                # Green background for safe files
                path_item.setBackground(Qt.green)
                path_item.setToolTip("✅ Safe to delete - temporary/cache file for freeing space")
                size_item.setBackground(Qt.green)
                
                # Safe delete button styling
                delete_button = QPushButton("🗑️ Safe Delete")
                delete_button.setStyleSheet("""
                    QPushButton {
                        background-color: #4caf50;
                        color: white;
                        border: none;
                        border-radius: 3px;
                        padding: 5px 10px;
                        font-size: 12px;
                        font-weight: bold;
                    }
                    QPushButton:hover {
                        background-color: #66bb6a;
                    }
                """)
            else:
                # White/default background for potentially risky files
                path_item.setToolTip("⚠️ CAUTION: Verify this file before deleting - may be important system/program file")
                
                # Warning delete button styling
                delete_button = QPushButton("⚠️ Delete")
                delete_button.setStyleSheet("""
                    QPushButton {
                        background-color: #d32f2f;
                        color: white;
                        border: none;
                        border-radius: 3px;
                        padding: 5px 10px;
                        font-size: 12px;
                        font-weight: bold;
                    }
                    QPushButton:hover {
                        background-color: #f44336;
                    }
                """)
            
            self.results_table.setItem(row, 0, path_item)
            self.results_table.setItem(row, 1, size_item)
            delete_button.clicked.connect(lambda checked, r=row: self.delete_file(r))
            self.results_table.setCellWidget(row, 2, delete_button)
            
        # Status message based on scan mode
        total_mb = sum(size_mb for _, size_mb, _ in self.files_data)
        if self.scan_mode == 'safe_only':
            status_msg = f"Found {len(self.files_data)} safe-to-delete files ({total_mb:.2f} MB / {total_mb/1024:.2f} GB potential space savings)"
        else:
            status_msg = f"Found {len(self.files_data)} files ({safe_count} safe in GREEN, {len(self.files_data) - safe_count} risky in WHITE) - {total_mb:.2f} MB total"
        self.update_status(status_msg)
        
    def delete_file(self, row):
        """Delete a file immediately without confirmation."""
        if row >= len(self.files_data):
            return
            
        file_path, size_mb, is_safe_to_delete = self.files_data[row]
        
        try:
            # Attempt to delete the file immediately
            os.remove(file_path)
            
            # Remove from data and table
            self.files_data.pop(row)
            self.results_table.removeRow(row)
            
            # Update row indices for remaining delete buttons
            self.refresh_delete_buttons()
            
            # Show success message
            self.update_status(f"✓ Deleted: {os.path.basename(file_path)} ({size_mb:.2f} MB)")
            
            # Update disk space display
            self.update_disk_space()
            
        except PermissionError:
            # Try to schedule for deletion on reboot
            if force_delete_on_reboot(file_path):
                # Remove from table as it will be deleted on reboot
                self.files_data.pop(row)
                self.results_table.removeRow(row)
                self.refresh_delete_buttons()
                self.update_status(f"🔄 Scheduled for deletion on reboot: {os.path.basename(file_path)} ({size_mb:.2f} MB)")
                self.update_disk_space()
            else:
                self.update_status(f"❌ Permission denied: {os.path.basename(file_path)}")
        except FileNotFoundError:
            # File no longer exists, remove from table anyway
            self.files_data.pop(row)
            self.results_table.removeRow(row)
            self.refresh_delete_buttons()
            self.update_status(f"⚠️ File not found: {os.path.basename(file_path)}")
        except Exception as e:
            # Try to schedule for deletion on reboot as last resort
            if force_delete_on_reboot(file_path):
                self.files_data.pop(row)
                self.results_table.removeRow(row)
                self.refresh_delete_buttons()
                self.update_status(f"🔄 Scheduled for deletion on reboot: {os.path.basename(file_path)} ({size_mb:.2f} MB)")
                self.update_disk_space()
            else:
                self.update_status(f"❌ Error deleting {os.path.basename(file_path)}: {str(e)}")
                
    def refresh_delete_buttons(self):
        """Refresh delete button connections after row removal."""
        for row in range(self.results_table.rowCount()):
            button = self.results_table.cellWidget(row, 2)
            if button:
                # Disconnect old connections and connect with correct row index
                button.clicked.disconnect()
                button.clicked.connect(lambda checked, r=row: self.delete_file(r))
    
    def create_drive_selection(self):
        """Create the drive selection widget."""
        self.drive_selection_frame = QFrame()
        self.drive_selection_frame.setFrameStyle(QFrame.StyledPanel | QFrame.Raised)
        self.drive_selection_frame.setStyleSheet("""
            QFrame {
                background: qlineargradient(x1:0, y1:0, x2:1, y2:0,
                    stop:0 #e8f5e8, stop:0.5 #c8e6c8, stop:1 #a5d6a7);
                border: 3px solid qlineargradient(x1:0, y1:0, x2:1, y2:0,
                    stop:0 #4caf50, stop:1 #66bb6a);
                border-radius: 12px;
                padding: 15px;
                margin: 8px;
            }
        """)
        
        layout = QHBoxLayout(self.drive_selection_frame)
        
        # Title
        title_label = QLabel("🖥️ Select Drive to Scan:")
        title_label.setStyleSheet("font-weight: bold; font-size: 14px; color: #333;")
        layout.addWidget(title_label)
        
        # Drive buttons - dynamically detect available drives
        drives = get_available_drives()
        self.drive_buttons = {}
        
        if not drives:
            drives = ['C']  # Fallback to C: if detection fails
        
        for drive in drives:
            button = QPushButton(f"{drive}:")
            button.setMinimumHeight(35)
            button.setMinimumWidth(50)
            button.setCheckable(True)
            button.setStyleSheet(f"""
                QPushButton {{
                    background-color: {'#4caf50' if drive == self.current_drive else '#e0e0e0'};
                    color: {'white' if drive == self.current_drive else 'black'};
                    border: none;
                    border-radius: 5px;
                    font-size: 14px;
                    font-weight: bold;
                    margin: 2px;
                }}
                QPushButton:hover {{
                    background-color: {'#66bb6a' if drive == self.current_drive else '#f5f5f5'};
                }}
                QPushButton:checked {{
                    background-color: #4caf50;
                    color: white;
                }}
            """)
            button.setChecked(drive == self.current_drive)
            button.clicked.connect(lambda checked, d=drive: self.select_drive(d))
            
            self.drive_buttons[drive] = button
            layout.addWidget(button)
        
        layout.addStretch()
    
    def select_drive(self, drive_letter):
        """Select a new drive for scanning."""
        # Update current drive
        old_drive = self.current_drive
        self.current_drive = drive_letter
        
        # Update button states
        for drive, button in self.drive_buttons.items():
            button.setChecked(drive == drive_letter)
            button.setStyleSheet(f"""
                QPushButton {{
                    background-color: {'#4caf50' if drive == drive_letter else '#e0e0e0'};
                    color: {'white' if drive == drive_letter else 'black'};
                    border: none;
                    border-radius: 5px;
                    font-size: 14px;
                    font-weight: bold;
                    margin: 2px;
                }}
                QPushButton:hover {{
                    background-color: {'#66bb6a' if drive == drive_letter else '#f5f5f5'};
                }}
                QPushButton:checked {{
                    background-color: #4caf50;
                    color: white;
                }}
            """)
        
        # Update UI text elements
        self.update_scan_button_text()
        self.drive_title_label.setText(f"💾 {drive_letter}: Drive Space:")
        
        # Update disk space display
        self.update_disk_space()
        
        # Clear current results
        self.results_table.setRowCount(0)
        self.files_data.clear()
        
        self.update_status(f"Selected {drive_letter}: drive - ready to scan for safe-to-delete files")
    
    def YOUR_CLIENT_SECRET_HERE(self):
        """Create the disk space display widget."""
        self.disk_space_frame = QFrame()
        self.disk_space_frame.setFrameStyle(QFrame.StyledPanel | QFrame.Raised)
        self.disk_space_frame.setStyleSheet("""
            QFrame {
                background: qlineargradient(x1:0, y1:0, x2:1, y2:0,
                    stop:0 #f8f9fa, stop:0.5 #e9ecef, stop:1 #dee2e6);
                border: 3px solid qlineargradient(x1:0, y1:0, x2:1, y2:0,
                    stop:0 #6c757d, stop:1 #adb5bd);
                border-radius: 12px;
                padding: 15px;
                margin: 8px;
            }
        """)
        
        layout = QHBoxLayout(self.disk_space_frame)
        
        # Title
        self.drive_title_label = QLabel(f"💾 {self.current_drive}: Drive Space:")
        self.drive_title_label.setStyleSheet("font-weight: bold; font-size: 14px; color: #333;")
        layout.addWidget(self.drive_title_label)
        
        # Free space
        self.free_space_label = QLabel("Free: Calculating...")
        self.free_space_label.setStyleSheet("font-size: 14px; color: #28a745; font-weight: bold;")
        layout.addWidget(self.free_space_label)
        
        # Used space
        self.used_space_label = QLabel("Used: Calculating...")
        self.used_space_label.setStyleSheet("font-size: 14px; color: #dc3545; font-weight: bold;")
        layout.addWidget(self.used_space_label)
        
        # Total space
        self.total_space_label = QLabel("Total: Calculating...")
        self.total_space_label.setStyleSheet("font-size: 14px; color: #6c757d; font-weight: bold;")
        layout.addWidget(self.total_space_label)
        
        layout.addStretch()
    
    def update_disk_space(self):
        """Update the disk space display with current drive information."""
        try:
            drive_path = f'{self.current_drive}:\\'
            disk_usage = shutil.disk_usage(drive_path)
            total_bytes = disk_usage.total
            free_bytes = disk_usage.free
            used_bytes = total_bytes - free_bytes
            
            # Convert to GB for better readability
            total_gb = total_bytes / (1024**3)
            free_gb = free_bytes / (1024**3)
            used_gb = used_bytes / (1024**3)
            
            self.free_space_label.setText(f"Free: {free_gb:.1f} GB")
            self.used_space_label.setText(f"Used: {used_gb:.1f} GB")
            self.total_space_label.setText(f"Total: {total_gb:.1f} GB")
            
        except Exception as e:
            self.free_space_label.setText("Free: Error")
            self.used_space_label.setText("Used: Error")
            self.total_space_label.setText("Total: Error")
    
    def select_all_files(self):
        """Select all files in the table."""
        self.results_table.selectAll()
        self.update_status("Selected all files")
    
    def clear_selection(self):
        """Clear all file selections."""
        self.results_table.clearSelection()
        self.update_status("Cleared all selections")
    
    def bulk_delete_files(self):
        """Delete all selected files immediately."""
        selected_items = self.results_table.selectedItems()
        
        # Get unique row numbers from selected items
        selected_rows = list(set(item.row() for item in selected_items))
        
        if not selected_rows:
            self.update_status("No files selected for deletion")
            return
        
        deleted_count = 0
        error_count = 0
        total_size_deleted = 0.0
        
        # Delete in reverse order to maintain row indices
        for row in reversed(selected_rows):
            if row < len(self.files_data):
                file_path, size_mb, is_safe_to_delete = self.files_data[row]
                
                try:
                    # Attempt to delete the file
                    os.remove(file_path)
                    
                    # Remove from data and table
                    self.files_data.pop(row)
                    self.results_table.removeRow(row)
                    
                    deleted_count += 1
                    total_size_deleted += size_mb
                    
                except PermissionError:
                    # Try to schedule for deletion on reboot
                    if force_delete_on_reboot(file_path):
                        self.files_data.pop(row)
                        self.results_table.removeRow(row)
                        deleted_count += 1
                        total_size_deleted += size_mb
                    else:
                        error_count += 1
                except FileNotFoundError:
                    # File doesn't exist, remove from table anyway
                    self.files_data.pop(row)
                    self.results_table.removeRow(row)
                    deleted_count += 1
                except Exception:
                    # Try to schedule for deletion on reboot as last resort
                    if force_delete_on_reboot(file_path):
                        self.files_data.pop(row)
                        self.results_table.removeRow(row)
                        deleted_count += 1
                        total_size_deleted += size_mb
                    else:
                        error_count += 1
        
        # Refresh button connections
        self.refresh_delete_buttons()
        
        # Update disk space
        self.update_disk_space()
        
        # Update status
        if error_count == 0:
            self.update_status(f"✓ Successfully deleted {deleted_count} files ({total_size_deleted:.2f} MB freed)")
        else:
            self.update_status(f"✓ Deleted {deleted_count} files, {error_count} errors ({total_size_deleted:.2f} MB freed)")
    
    def purge_all_temps(self):
        """Delete all safe-to-delete files at once."""
        if not self.files_data:
            self.update_status("No files to purge. Run a scan first.")
            return
        
        # Count safe files
        safe_files = [(i, file_path, size_mb) for i, (file_path, size_mb, is_safe) in enumerate(self.files_data) if is_safe]
        
        if not safe_files:
            self.update_status("No safe files found to purge.")
            return
        
        # Confirm action
        reply = QMessageBox.question(
            self, 
            "Purge All Temporary Files", 
            f"This will delete {len(safe_files)} temporary/cache files.\n"
            f"Total size: {sum(size for _, _, size in safe_files):.2f} MB\n\n"
            f"Are you sure you want to continue?",
            QMessageBox.Yes | QMessageBox.No,
            QMessageBox.Yes
        )
        
        if reply != QMessageBox.Yes:
            return
        
        deleted_count = 0
        reboot_count = 0
        error_count = 0
        total_size_deleted = 0.0
        
        # Delete safe files in reverse order to maintain indices
        for row, file_path, size_mb in reversed(safe_files):
            try:
                # Attempt to delete the file
                os.remove(file_path)
                deleted_count += 1
                total_size_deleted += size_mb
                
            except PermissionError:
                # Try to schedule for deletion on reboot
                if force_delete_on_reboot(file_path):
                    reboot_count += 1
                    total_size_deleted += size_mb
                else:
                    error_count += 1
                    
            except FileNotFoundError:
                # File doesn't exist anymore
                deleted_count += 1
                
            except Exception:
                # Try to schedule for deletion on reboot as last resort
                if force_delete_on_reboot(file_path):
                    reboot_count += 1
                    total_size_deleted += size_mb
                else:
                    error_count += 1
            
            # Remove from table regardless of delete method
            if row < len(self.files_data):
                self.files_data.pop(row)
                self.results_table.removeRow(row)
        
        # Refresh button connections
        self.refresh_delete_buttons()
        
        # Update disk space
        self.update_disk_space()
        
        # Show comprehensive status
        status_parts = []
        if deleted_count > 0:
            status_parts.append(f"✓ Deleted {deleted_count} files")
        if reboot_count > 0:
            status_parts.append(f"🔄 {reboot_count} scheduled for reboot")
        if error_count > 0:
            status_parts.append(f"❌ {error_count} errors")
        
        status_msg = " | ".join(status_parts)
        status_msg += f" | 💾 {total_size_deleted:.2f} MB freed"
        
        self.update_status(f"🚀 PURGE COMPLETE: {status_msg}")
        
        # Show summary dialog
        summary = f"Purge Summary:\n\n"
        summary += f"• Successfully deleted: {deleted_count} files\n"
        if reboot_count > 0:
            summary += f"• Scheduled for reboot: {reboot_count} files\n"
        if error_count > 0:
            summary += f"• Failed to delete: {error_count} files\n"
        summary += f"\n💾 Total space freed: {total_size_deleted:.2f} MB ({total_size_deleted/1024:.2f} GB)"
        
        if reboot_count > 0:
            summary += f"\n\n🔄 Note: {reboot_count} files will be deleted on next system reboot."
        
        QMessageBox.information(self, "Purge Complete", summary)
    
    def copy_selected_files(self):
        """Copy all selected file entries to clipboard."""
        selected_items = self.results_table.selectedItems()
        
        # Get unique row numbers from selected items
        selected_rows = list(set(item.row() for item in selected_items))
        selected_files = []
        
        # Get file data for selected rows
        for row in selected_rows:
            if row < len(self.files_data):
                file_path, size_mb, is_safe_to_delete = self.files_data[row]
                selected_files.append((file_path, size_mb, is_safe_to_delete))
        
        if not selected_files:
            self.update_status("No files selected to copy")
            return
        
        # Create formatted text for clipboard
        clipboard_text = []
        clipboard_text.append(f"Safe Drive Cleaner - Safe-to-Delete Files List")
        clipboard_text.append("=" * 50)
        clipboard_text.append(f"Total Files: {len(selected_files)}")
        
        # Calculate total size and safe count
        total_size = sum(size_mb for _, size_mb, _ in selected_files)
        safe_count = sum(1 for _, _, is_safe in selected_files if is_safe)
        clipboard_text.append(f"Total Size: {total_size:.2f} MB ({total_size/1024:.2f} GB)")
        clipboard_text.append(f"Safe to Delete: {safe_count}/{len(selected_files)} files")
        clipboard_text.append("")
        clipboard_text.append("File Path | Size (MB) | Safe")
        clipboard_text.append("-" * 90)
        
        # Add each file
        for file_path, size_mb, is_safe_to_delete in selected_files:
            safe_status = "✅ SAFE" if is_safe_to_delete else "⚠️ VERIFY"
            clipboard_text.append(f"{file_path} | {size_mb:.2f} | {safe_status}")
        
        # Add footer
        clipboard_text.append("")
        current_time = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        clipboard_text.append(f"Generated on: {current_time}")
        
        # Copy to clipboard
        clipboard = QApplication.clipboard()
        clipboard.setText("\n".join(clipboard_text))
        
        self.update_status(f"📋 Copied {len(selected_files)} file entries to clipboard ({total_size:.2f} MB total)")
                
    def closeEvent(self, event):
        """Handle application close event."""
        if self.scanner_thread and self.scanner_thread.isRunning():
            reply = QMessageBox.question(
                self, 
                "Confirm Exit", 
                "A scan is currently in progress. Do you want to stop it and exit?",
                QMessageBox.Yes | QMessageBox.No,
                QMessageBox.No
            )
            
            if reply == QMessageBox.Yes:
                self.scanner_thread.request_stop()
                self.scanner_thread.wait(3000)  # Wait up to 3 seconds
                event.accept()
            else:
                event.ignore()
        else:
            event.accept()


def main():
    """Main application entry point."""
    app = QApplication(sys.argv)
    
    # Set application properties
    app.setApplicationName("C: Drive Cleaner")
    app.setApplicationVersion("1.0")
    app.setOrganizationName("File Management Tools")
    
    # Apply a modern style
    app.setStyle('Fusion')
    
    # Create and show main window
    window = MainAppWindow()
    window.show()
    
    # Run the application
    sys.exit(app.exec_())


if __name__ == "__main__":
    main()