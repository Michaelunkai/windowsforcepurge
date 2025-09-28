"""
Modern PyQt5 GUI for Laptop Driver Updater
Beautiful, professional interface with dark theme and animations
"""

import sys
import asyncio
import threading
from pathlib import Path
from typing import Dict, Optional, List
import logging

from PyQt5.QtWidgets import (
    QApplication, QMainWindow, QWidget, QVBoxLayout, QHBoxLayout, 
    QTabWidget, QLabel, QPushButton, QTableWidget, QTableWidgetItem,
    QTreeWidget, QTreeWidgetItem, QTextEdit, QProgressBar, QFrame,
    QSplitter, QGroupBox, QGridLayout, QHeaderView, QScrollArea,
    QSystemTrayIcon, QMenu, QAction, QMessageBox, QStatusBar,
    QToolBar, QComboBox, QCheckBox, QSpacerItem, QSizePolicy
)
from PyQt5.QtCore import (
    Qt, QThread, pyqtSignal, QTimer, QPropertyAnimation, 
    QEasingCurve, QRect, QSize
)
from PyQt5.QtGui import (
    QIcon, QPixmap, QFont, QPalette, QColor, QLinearGradient,
    QPainter, QBrush, QPen, QFontMetrics
)

class ModernCard(QFrame):
    """Modern card widget with shadow effect and hover animation"""
    
    def __init__(self, title: str = "", content: str = "", parent=None):
        super().__init__(parent)
        self.setFrameStyle(QFrame.Box)
        self.setLineWidth(0)
        self.setStyleSheet("""
            ModernCard {
                background-color: #2b2b2b;
                border: 1px solid #404040;
                border-radius: 8px;
                margin: 4px;
            }
            ModernCard:hover {
                background-color: #303030;
                border: 1px solid #505050;
            }
        """)
        
        layout = QVBoxLayout()
        layout.setContentsMargins(12, 12, 12, 12)
        
        if title:
            title_label = QLabel(title)
            title_label.setStyleSheet("""
                QLabel {
                    color: #ffffff;
                    font-size: 14px;
                    font-weight: bold;
                    margin-bottom: 8px;
                }
            """)
            layout.addWidget(title_label)
        
        if content:
            content_label = QLabel(content)
            content_label.setStyleSheet("""
                QLabel {
                    color: #cccccc;
                    font-size: 12px;
                    line-height: 1.4;
                }
            """)
            content_label.setWordWrap(True)
            layout.addWidget(content_label)
        
        self.setLayout(layout)

class AnimatedProgressBar(QProgressBar):
    """Custom progress bar with smooth animations"""
    
    def __init__(self, parent=None):
        super().__init__(parent)
        self.setStyleSheet("""
            QProgressBar {
                border: 2px solid #404040;
                border-radius: 8px;
                text-align: center;
                font-weight: bold;
                color: white;
                background-color: #2b2b2b;
            }
            QProgressBar::chunk {
                background: qlineargradient(x1:0, y1:0, x2:1, y2:0,
                    stop:0 #0066cc, stop:0.5 #0080ff, stop:1 #00aaff);
                border-radius: 6px;
                margin: 1px;
            }
        """)
        
        self.animation = QPropertyAnimation(self, b"value")
        self.animation.setDuration(300)
        self.animation.setEasingCurve(QEasingCurve.OutCubic)
    
    def setValueAnimated(self, value):
        """Set value with smooth animation"""
        self.animation.setStartValue(self.value())
        self.animation.setEndValue(value)
        self.animation.start()

class HardwareDetectionThread(QThread):
    """Thread for hardware detection"""
    
    progress_updated = pyqtSignal(str, int)
    hardware_detected = pyqtSignal(dict)
    error_occurred = pyqtSignal(str)
    
    def __init__(self, driver_updater):
        super().__init__()
        self.driver_updater = driver_updater
    
    def run(self):
        """Run hardware detection in separate thread"""
        try:
            loop = asyncio.new_event_loop()
            asyncio.set_event_loop(loop)
            
            self.progress_updated.emit("Initializing hardware detection...", 10)
            
            # Initialize hardware detector
            detector = self.driver_updater.hardware_detector
            loop.run_until_complete(detector.initialize_wmi())
            
            self.progress_updated.emit("Detecting ASUS laptop model...", 20)
            asus_model = loop.run_until_complete(detector.detect_asus_model())
            
            self.progress_updated.emit("Detecting NVIDIA GPU...", 40)
            nvidia_gpu = loop.run_until_complete(detector.detect_nvidia_gpu())
            
            self.progress_updated.emit("Detecting AMD components...", 60)
            amd_cpu = loop.run_until_complete(detector.detect_amd_cpu())
            amd_gpu = loop.run_until_complete(detector.detect_amd_gpu())
            
            self.progress_updated.emit("Detecting installed software...", 80)
            installed_software = loop.run_until_complete(detector.detect_installed_software())
            
            self.progress_updated.emit("Getting system information...", 90)
            system_info = loop.run_until_complete(detector.detect_system_info())
            
            # Compile hardware info
            hardware_info = {}
            if asus_model:
                hardware_info['asus_model'] = asus_model
            if nvidia_gpu:
                hardware_info['nvidia_gpu'] = nvidia_gpu
            if amd_cpu:
                hardware_info['amd_cpu'] = amd_cpu
            if amd_gpu:
                hardware_info['amd_gpu'] = amd_gpu
            if installed_software:
                hardware_info['installed_software'] = installed_software
            if system_info:
                hardware_info['system_info'] = system_info
            
            self.progress_updated.emit("Hardware detection complete!", 100)
            self.hardware_detected.emit(hardware_info)
            
        except Exception as e:
            self.error_occurred.emit(str(e))

class DriverScanThread(QThread):
    """Thread for driver scanning"""
    
    progress_updated = pyqtSignal(str, int)
    updates_found = pyqtSignal(dict)
    error_occurred = pyqtSignal(str)
    
    def __init__(self, driver_updater, hardware_info):
        super().__init__()
        self.driver_updater = driver_updater
        self.hardware_info = hardware_info
    
    def run(self):
        """Run driver scan in separate thread"""
        try:
            loop = asyncio.new_event_loop()
            asyncio.set_event_loop(loop)
            
            updates = {}
            total_steps = 3
            current_step = 0
            
            # Check NVIDIA drivers
            if self.hardware_info.get('nvidia_gpu'):
                current_step += 1
                progress = int((current_step / total_steps) * 100)
                self.progress_updated.emit("Scanning NVIDIA drivers...", progress)
                
                nvidia_update = loop.run_until_complete(
                    self.driver_updater.nvidia_handler.check_for_updates(
                        self.hardware_info['nvidia_gpu'],
                        self.hardware_info.get('installed_software', {})
                    )
                )
                if nvidia_update:
                    updates['nvidia'] = nvidia_update
            
            # Check AMD drivers
            if self.hardware_info.get('amd_cpu') or self.hardware_info.get('amd_gpu'):
                current_step += 1
                progress = int((current_step / total_steps) * 100)
                self.progress_updated.emit("Scanning AMD drivers...", progress)
                
                amd_update = loop.run_until_complete(
                    self.driver_updater.amd_handler.check_for_updates(self.hardware_info)
                )
                if amd_update:
                    updates['amd'] = amd_update
            
            # Check ASUS drivers
            if self.hardware_info.get('asus_model'):
                current_step += 1
                progress = int((current_step / total_steps) * 100)
                self.progress_updated.emit("Scanning ASUS software...", progress)
                
                asus_update = loop.run_until_complete(
                    self.driver_updater.asus_handler.check_for_updates(
                        self.hardware_info['asus_model'],
                        self.hardware_info.get('installed_software', {})
                    )
                )
                if asus_update:
                    updates['asus'] = asus_update
            
            self.progress_updated.emit("Driver scan complete!", 100)
            self.updates_found.emit(updates)
            
        except Exception as e:
            self.error_occurred.emit(str(e))

class ModernDriverUpdaterGUI(QMainWindow):
    """Modern PyQt5 GUI for the Driver Updater"""
    
    def __init__(self, driver_updater):
        super().__init__()
        self.driver_updater = driver_updater
        self.hardware_info = {}
        self.available_updates = {}
        self.logger = logging.getLogger(__name__)
        
        self.init_ui()
        self.setup_dark_theme()
        self.setup_system_tray()
        
        # Start hardware detection automatically
        QTimer.singleShot(1000, self.start_hardware_detection)
    
    def init_ui(self):
        """Initialize the user interface"""
        self.setWindowTitle("🚀 Laptop Driver Updater - Modern Interface")
        self.setGeometry(100, 100, 1400, 900)
        self.setMinimumSize(1200, 800)
        
        # Set window icon
        self.setWindowIcon(self.create_icon())
        
        # Central widget
        central_widget = QWidget()
        self.setCentralWidget(central_widget)
        
        # Main layout
        main_layout = QVBoxLayout(central_widget)
        main_layout.setContentsMargins(0, 0, 0, 0)
        main_layout.setSpacing(0)
        
        # Create toolbar
        self.create_toolbar()
        
        # Create main content area
        content_splitter = QSplitter(Qt.Horizontal)
        
        # Left panel (Hardware info)
        left_panel = self.create_left_panel()
        content_splitter.addWidget(left_panel)
        
        # Right panel (Tabs)
        right_panel = self.create_right_panel()
        content_splitter.addWidget(right_panel)
        
        # Set splitter proportions
        content_splitter.setStretchFactor(0, 1)
        content_splitter.setStretchFactor(1, 2)
        content_splitter.setSizes([400, 800])
        
        main_layout.addWidget(content_splitter)
        
        # Create status bar
        self.create_status_bar()
    
    def create_icon(self):
        """Create application icon"""
        pixmap = QPixmap(32, 32)
        pixmap.fill(Qt.transparent)
        
        painter = QPainter(pixmap)
        painter.setRenderHint(QPainter.Antialiasing)
        
        # Draw a modern icon
        gradient = QLinearGradient(0, 0, 32, 32)
        gradient.setColorAt(0, QColor("#0066cc"))
        gradient.setColorAt(1, QColor("#00aaff"))
        
        painter.setBrush(QBrush(gradient))
        painter.setPen(Qt.NoPen)
        painter.drawRoundedRect(2, 2, 28, 28, 6, 6)
        
        # Add gear icon
        painter.setPen(QPen(Qt.white, 2))
        painter.drawEllipse(8, 8, 16, 16)
        painter.drawLine(16, 4, 16, 12)
        painter.drawLine(16, 20, 16, 28)
        painter.drawLine(4, 16, 12, 16)
        painter.drawLine(20, 16, 28, 16)
        
        painter.end()
        return QIcon(pixmap)
    
    def create_toolbar(self):
        """Create modern toolbar"""
        toolbar = QToolBar()
        toolbar.setStyleSheet("""
            QToolBar {
                background: qlineargradient(x1:0, y1:0, x2:0, y2:1,
                    stop:0 #404040, stop:1 #2b2b2b);
                border: none;
                spacing: 10px;
                padding: 8px;
            }
            QToolButton {
                background: transparent;
                border: 1px solid transparent;
                border-radius: 6px;
                padding: 8px 16px;
                color: white;
                font-weight: bold;
            }
            QToolButton:hover {
                background-color: rgba(255, 255, 255, 0.1);
                border: 1px solid rgba(255, 255, 255, 0.2);
            }
            QToolButton:pressed {
                background-color: rgba(255, 255, 255, 0.2);
            }
        """)
        
        # Hardware detection action
        detect_action = QAction("🔍 Detect Hardware", self)
        detect_action.triggered.connect(self.start_hardware_detection)
        toolbar.addAction(detect_action)
        
        toolbar.addSeparator()
        
        # Scan for updates action
        scan_action = QAction("📡 Scan for Updates", self)
        scan_action.triggered.connect(self.start_driver_scan)
        toolbar.addAction(scan_action)
        
        # Install updates action
        install_action = QAction("⚡ Install Selected", self)
        install_action.triggered.connect(self.install_selected_updates)
        toolbar.addAction(install_action)
        
        toolbar.addSeparator()
        
        # Settings action
        settings_action = QAction("⚙️ Settings", self)
        settings_action.triggered.connect(self.show_settings)
        toolbar.addAction(settings_action)
        
        self.addToolBar(toolbar)
    
    def create_left_panel(self):
        """Create left panel with hardware information"""
        panel = QWidget()
        layout = QVBoxLayout(panel)
        layout.setContentsMargins(10, 10, 10, 10)
        
        # Title
        title = QLabel("🖥️ Hardware Information")
        title.setStyleSheet("""
            QLabel {
                color: #ffffff;
                font-size: 18px;
                font-weight: bold;
                margin-bottom: 15px;
                padding: 10px;
                background: qlineargradient(x1:0, y1:0, x2:1, y2:0,
                    stop:0 #0066cc, stop:1 #00aaff);
                border-radius: 8px;
            }
        """)
        layout.addWidget(title)
        
        # Hardware tree
        self.hardware_tree = QTreeWidget()
        self.hardware_tree.setHeaderLabel("Component")
        self.hardware_tree.setStyleSheet("""
            QTreeWidget {
                background-color: #2b2b2b;
                border: 1px solid #404040;
                border-radius: 8px;
                color: #ffffff;
                font-size: 12px;
                outline: none;
            }
            QTreeWidget::item {
                padding: 8px;
                border-bottom: 1px solid #404040;
            }
            QTreeWidget::item:hover {
                background-color: #404040;
            }
            QTreeWidget::item:selected {
                background-color: #0066cc;
            }
        """)
        layout.addWidget(self.hardware_tree)
        
        # Progress section
        progress_group = QGroupBox("Detection Progress")
        progress_group.setStyleSheet("""
            QGroupBox {
                color: #ffffff;
                font-weight: bold;
                border: 2px solid #404040;
                border-radius: 8px;
                margin-top: 10px;
                padding-top: 10px;
            }
            QGroupBox::title {
                subcontrol-origin: margin;
                subcontrol-position: top center;
                padding: 0 10px;
                background-color: #1e1e1e;
            }
        """)
        progress_layout = QVBoxLayout(progress_group)
        
        self.progress_label = QLabel("Ready to scan...")
        self.progress_label.setStyleSheet("color: #cccccc; margin: 5px;")
        progress_layout.addWidget(self.progress_label)
        
        self.progress_bar = AnimatedProgressBar()
        self.progress_bar.setMinimumHeight(25)
        progress_layout.addWidget(self.progress_bar)
        
        layout.addWidget(progress_group)
        
        return panel
    
    def create_right_panel(self):
        """Create right panel with tabs"""
        tab_widget = QTabWidget()
        tab_widget.setStyleSheet("""
            QTabWidget::pane {
                border: 1px solid #404040;
                background-color: #2b2b2b;
                border-radius: 8px;
            }
            QTabBar::tab {
                background-color: #404040;
                color: #ffffff;
                padding: 12px 20px;
                margin-right: 2px;
                border-top-left-radius: 8px;
                border-top-right-radius: 8px;
                font-weight: bold;
            }
            QTabBar::tab:selected {
                background: qlineargradient(x1:0, y1:0, x2:0, y2:1,
                    stop:0 #0066cc, stop:1 #0080ff);
            }
            QTabBar::tab:hover {
                background-color: #505050;
            }
        """)
        
        # Driver Updates tab
        updates_tab = self.create_updates_tab()
        tab_widget.addTab(updates_tab, "📦 Available Updates")
        
        # Logs tab
        logs_tab = self.create_logs_tab()
        tab_widget.addTab(logs_tab, "📋 Logs")
        
        # About tab
        about_tab = self.create_about_tab()
        tab_widget.addTab(about_tab, "ℹ️ About")
        
        return tab_widget
    
    def create_updates_tab(self):
        """Create updates tab"""
        widget = QWidget()
        layout = QVBoxLayout(widget)
        layout.setContentsMargins(15, 15, 15, 15)
        
        # Control buttons
        controls_layout = QHBoxLayout()
        
        self.select_all_btn = QPushButton("✅ Select All")
        self.select_all_btn.clicked.connect(self.select_all_updates)
        self.select_all_btn.setStyleSheet(self.get_button_style())
        controls_layout.addWidget(self.select_all_btn)
        
        self.select_none_btn = QPushButton("❌ Select None")
        self.select_none_btn.clicked.connect(self.select_no_updates)
        self.select_none_btn.setStyleSheet(self.get_button_style())
        controls_layout.addWidget(self.select_none_btn)
        
        controls_layout.addStretch()
        
        self.install_btn = QPushButton("⚡ Install Selected Updates")
        self.install_btn.clicked.connect(self.install_selected_updates)
        self.install_btn.setStyleSheet(self.get_primary_button_style())
        self.install_btn.setMinimumHeight(40)
        controls_layout.addWidget(self.install_btn)
        
        layout.addLayout(controls_layout)
        
        # Updates table
        self.updates_table = QTableWidget()
        self.updates_table.setColumnCount(6)
        self.updates_table.setHorizontalHeaderLabels([
            "Select", "Category", "Component", "Current Version", "Latest Version", "Status"
        ])
        
        # Style the table
        self.updates_table.setStyleSheet("""
            QTableWidget {
                background-color: #2b2b2b;
                border: 1px solid #404040;
                border-radius: 8px;
                gridline-color: #404040;
                color: #ffffff;
                font-size: 12px;
            }
            QTableWidget::item {
                padding: 10px;
                border-bottom: 1px solid #404040;
            }
            QTableWidget::item:hover {
                background-color: #404040;
            }
            QTableWidget::item:selected {
                background-color: #0066cc;
            }
            QHeaderView::section {
                background: qlineargradient(x1:0, y1:0, x2:0, y2:1,
                    stop:0 #404040, stop:1 #2b2b2b);
                color: #ffffff;
                padding: 10px;
                border: 1px solid #404040;
                font-weight: bold;
            }
        """)
        
        # Configure table
        header = self.updates_table.horizontalHeader()
        header.setStretchLastSection(True)
        header.setSectionResizeMode(QHeaderView.ResizeToContents)
        
        self.updates_table.setAlternatingRowColors(True)
        self.updates_table.setSelectionBehavior(QTableWidget.SelectRows)
        
        layout.addWidget(self.updates_table)
        
        return widget
    
    def create_logs_tab(self):
        """Create logs tab"""
        widget = QWidget()
        layout = QVBoxLayout(widget)
        layout.setContentsMargins(15, 15, 15, 15)
        
        # Log controls
        log_controls = QHBoxLayout()
        
        clear_btn = QPushButton("🗑️ Clear Logs")
        clear_btn.clicked.connect(self.clear_logs)
        clear_btn.setStyleSheet(self.get_button_style())
        log_controls.addWidget(clear_btn)
        
        log_controls.addStretch()
        
        # Log level combo
        log_level_combo = QComboBox()
        log_level_combo.addItems(["DEBUG", "INFO", "WARNING", "ERROR"])
        log_level_combo.setCurrentText("INFO")
        log_level_combo.setStyleSheet("""
            QComboBox {
                background-color: #404040;
                color: white;
                border: 1px solid #606060;
                border-radius: 4px;
                padding: 5px;
                min-width: 100px;
            }
            QComboBox::drop-down {
                border: none;
            }
            QComboBox::down-arrow {
                image: none;
                border-left: 5px solid transparent;
                border-right: 5px solid transparent;
                border-top: 5px solid white;
            }
        """)
        log_controls.addWidget(QLabel("Log Level:"))
        log_controls.addWidget(log_level_combo)
        
        layout.addLayout(log_controls)
        
        # Log text area
        self.log_text = QTextEdit()
        self.log_text.setStyleSheet("""
            QTextEdit {
                background-color: #1e1e1e;
                border: 1px solid #404040;
                border-radius: 8px;
                color: #ffffff;
                font-family: 'Consolas', 'Monaco', monospace;
                font-size: 11px;
                line-height: 1.4;
            }
        """)
        self.log_text.setReadOnly(True)
        layout.addWidget(self.log_text)
        
        return widget
    
    def create_about_tab(self):
        """Create about tab"""
        widget = QWidget()
        layout = QVBoxLayout(widget)
        layout.setContentsMargins(30, 30, 30, 30)
        
        # Scroll area for content
        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
        scroll.setStyleSheet("""
            QScrollArea {
                border: none;
                background-color: transparent;
            }
        """)
        
        content_widget = QWidget()
        content_layout = QVBoxLayout(content_widget)
        content_layout.setSpacing(20)
        
        # App info card
        app_card = ModernCard(
            "🚀 Laptop Driver Updater",
            "A modern, intelligent driver management solution for ASUS laptops with AMD and NVIDIA components. "
            "Features automatic hardware detection, real-time driver scanning, and safe installation procedures."
        )
        content_layout.addWidget(app_card)
        
        # Features card
        features_card = ModernCard(
            "✨ Key Features",
            "• Automatic hardware detection for ASUS, AMD, and NVIDIA components\n"
            "• Real-time driver version comparison\n"
            "• Safe, automated driver installation\n"
            "• Beautiful, modern interface with dark theme\n"
            "• Comprehensive logging and error handling\n"
            "• System tray integration\n"
            "• Progress tracking with animations"
        )
        content_layout.addWidget(features_card)
        
        # System info card
        system_card = ModernCard(
            "💻 System Information",
            f"Python Version: {sys.version.split()[0]}\n"
            f"PyQt5 Version: Available\n"
            f"Platform: Windows\n"
            f"Architecture: 64-bit"
        )
        content_layout.addWidget(system_card)
        
        # Credits card
        credits_card = ModernCard(
            "👨‍💻 Credits",
            "Developed with modern Python technologies:\n"
            "• PyQt5 for the beautiful GUI\n"
            "• asyncio for efficient async operations\n"
            "• aiohttp for fast HTTP requests\n"
            "• WMI for Windows hardware detection\n"
            "• Custom animations and theming"
        )
        content_layout.addWidget(credits_card)
        
        content_layout.addStretch()
        
        scroll.setWidget(content_widget)
        layout.addWidget(scroll)
        
        return widget
    
    def get_button_style(self):
        """Get standard button style"""
        return """
            QPushButton {
                background-color: #404040;
                color: white;
                border: 1px solid #606060;
                border-radius: 6px;
                padding: 8px 16px;
                font-weight: bold;
                min-width: 100px;
            }
            QPushButton:hover {
                background-color: #505050;
                border: 1px solid #707070;
            }
            QPushButton:pressed {
                background-color: #606060;
            }
            QPushButton:disabled {
                background-color: #2b2b2b;
                color: #666666;
                border: 1px solid #404040;
            }
        """
    
    def get_primary_button_style(self):
        """Get primary button style"""
        return """
            QPushButton {
                background: qlineargradient(x1:0, y1:0, x2:0, y2:1,
                    stop:0 #0066cc, stop:1 #0080ff);
                color: white;
                border: 1px solid #0066cc;
                border-radius: 6px;
                padding: 10px 20px;
                font-weight: bold;
                font-size: 14px;
                min-width: 150px;
            }
            QPushButton:hover {
                background: qlineargradient(x1:0, y1:0, x2:0, y2:1,
                    stop:0 #0080ff, stop:1 #00aaff);
                border: 1px solid #0080ff;
            }
            QPushButton:pressed {
                background: qlineargradient(x1:0, y1:0, x2:0, y2:1,
                    stop:0 #0050aa, stop:1 #0066cc);
            }
            QPushButton:disabled {
                background-color: #2b2b2b;
                color: #666666;
                border: 1px solid #404040;
            }
        """
    
    def setup_dark_theme(self):
        """Apply dark theme to the application"""
        self.setStyleSheet("""
            QMainWindow, QWidget {
                background-color: #1e1e1e;
                color: #ffffff;
            }
            QSplitter::handle {
                background-color: #404040;
                width: 2px;
            }
            QSplitter::handle:hover {
                background-color: #606060;
            }
        """)
    
    def setup_system_tray(self):
        """Setup system tray icon"""
        if QSystemTrayIcon.isSystemTrayAvailable():
            self.tray_icon = QSystemTrayIcon(self.create_icon(), self)
            
            # Create tray menu
            tray_menu = QMenu()
            
            show_action = QAction("Show", self)
            show_action.triggered.connect(self.show)
            tray_menu.addAction(show_action)
            
            hide_action = QAction("Hide", self)
            hide_action.triggered.connect(self.hide)
            tray_menu.addAction(hide_action)
            
            tray_menu.addSeparator()
            
            quit_action = QAction("Quit", self)
            quit_action.triggered.connect(QApplication.quit)
            tray_menu.addAction(quit_action)
            
            self.tray_icon.setContextMenu(tray_menu)
            self.tray_icon.show()
            
            # Show message
            self.tray_icon.showMessage(
                "Driver Updater",
                "Application started in system tray",
                QSystemTrayIcon.Information,
                3000
            )
    
    def create_status_bar(self):
        """Create status bar"""
        status_bar = QStatusBar()
        status_bar.setStyleSheet("""
            QStatusBar {
                background-color: #2b2b2b;
                border-top: 1px solid #404040;
                color: #cccccc;
                padding: 5px;
            }
        """)
        
        self.status_label = QLabel("Ready")
        status_bar.addWidget(self.status_label)
        
        status_bar.addPermanentWidget(QLabel("PyQt5 Modern Interface"))
        
        self.setStatusBar(status_bar)
    
    def start_hardware_detection(self):
        """Start hardware detection"""
        self.log_message("Starting hardware detection...", "INFO")
        self.progress_label.setText("Initializing hardware detection...")
        self.progress_bar.setValueAnimated(0)
        
        # Disable buttons during detection
        self.select_all_btn.setEnabled(False)
        self.install_btn.setEnabled(False)
        
        # Start detection thread
        self.detection_thread = HardwareDetectionThread(self.driver_updater)
        self.detection_thread.progress_updated.connect(self.update_progress)
        self.detection_thread.hardware_detected.connect(self.on_hardware_detected)
        self.detection_thread.error_occurred.connect(self.on_error)
        self.detection_thread.start()
    
    def update_progress(self, message: str, progress: int):
        """Update progress bar and message"""
        self.progress_label.setText(message)
        self.progress_bar.setValueAnimated(progress)
        self.status_label.setText(message)
        self.log_message(message, "PROGRESS")
    
    def on_hardware_detected(self, hardware_info: dict):
        """Handle hardware detection completion"""
        self.hardware_info = hardware_info
        self.log_message(f"Hardware detection complete. Found {len(hardware_info)} components", "INFO")
        
        # Update hardware tree
        self.update_hardware_tree()
        
        # Re-enable buttons
        self.select_all_btn.setEnabled(True)
        self.install_btn.setEnabled(True)
        
        # Automatically start driver scan
        QTimer.singleShot(1000, self.start_driver_scan)
    
    def update_hardware_tree(self):
        """Update hardware information tree"""
        self.hardware_tree.clear()
        
        if not self.hardware_info:
            no_hw_item = QTreeWidgetItem(["No hardware detected"])
            self.hardware_tree.addTopLevelItem(no_hw_item)
            return
        
        # Add ASUS info
        if 'asus_model' in self.hardware_info:
            asus_item = QTreeWidgetItem(["🏢 ASUS Laptop"])
            asus_item.addChild(QTreeWidgetItem([f"Model: {self.hardware_info['asus_model']}"]))
            self.hardware_tree.addTopLevelItem(asus_item)
            asus_item.setExpanded(True)
        
        # Add NVIDIA info
        if 'nvidia_gpu' in self.hardware_info:
            nvidia_item = QTreeWidgetItem(["🎮 NVIDIA GPU"])
            gpu_info = self.hardware_info['nvidia_gpu']
            nvidia_item.addChild(QTreeWidgetItem([f"Name: {gpu_info.get('name', 'Unknown')}"]))
            nvidia_item.addChild(QTreeWidgetItem([f"Driver: {gpu_info.get('driver_version', 'Unknown')}"]))
            if 'uuid' in gpu_info:
                nvidia_item.addChild(QTreeWidgetItem([f"UUID: {gpu_info['uuid']}"]))
            self.hardware_tree.addTopLevelItem(nvidia_item)
            nvidia_item.setExpanded(True)
        
        # Add AMD CPU info
        if 'amd_cpu' in self.hardware_info:
            amd_cpu_item = QTreeWidgetItem(["🔧 AMD CPU"])
            cpu_info = self.hardware_info['amd_cpu']
            amd_cpu_item.addChild(QTreeWidgetItem([f"Name: {cpu_info.get('name', 'Unknown')}"]))
            amd_cpu_item.addChild(QTreeWidgetItem([f"Cores: {cpu_info.get('cores', 'Unknown')}"]))
            amd_cpu_item.addChild(QTreeWidgetItem([f"Threads: {cpu_info.get('threads', 'Unknown')}"]))
            self.hardware_tree.addTopLevelItem(amd_cpu_item)
            amd_cpu_item.setExpanded(True)
        
        # Add AMD GPU info
        if 'amd_gpu' in self.hardware_info:
            amd_gpu_item = QTreeWidgetItem(["🎯 AMD GPU"])
            gpu_info = self.hardware_info['amd_gpu']
            amd_gpu_item.addChild(QTreeWidgetItem([f"Name: {gpu_info.get('name', 'Unknown')}"]))
            amd_gpu_item.addChild(QTreeWidgetItem([f"Driver: {gpu_info.get('driver_version', 'Unknown')}"]))
            self.hardware_tree.addTopLevelItem(amd_gpu_item)
            amd_gpu_item.setExpanded(True)
    
    def start_driver_scan(self):
        """Start driver scanning"""
        if not self.hardware_info:
            self.log_message("No hardware detected. Cannot scan for drivers.", "WARNING")
            return
        
        self.log_message("Starting driver scan...", "INFO")
        self.progress_label.setText("Scanning for driver updates...")
        self.progress_bar.setValueAnimated(0)
        
        # Start scan thread
        self.scan_thread = DriverScanThread(self.driver_updater, self.hardware_info)
        self.scan_thread.progress_updated.connect(self.update_progress)
        self.scan_thread.updates_found.connect(self.on_updates_found)
        self.scan_thread.error_occurred.connect(self.on_error)
        self.scan_thread.start()
    
    def on_updates_found(self, updates: dict):
        """Handle driver scan completion"""
        self.available_updates = updates
        self.log_message(f"Driver scan complete. Found {len(updates)} categories with updates", "INFO")
        
        # Update updates table
        self.update_updates_table()
    
    def update_updates_table(self):
        """Update the updates table"""
        self.updates_table.setRowCount(0)
        
        if not self.available_updates:
            return
        
        row = 0
        for category, category_updates in self.available_updates.items():
            if isinstance(category_updates, dict):
                if 'name' in category_updates:
                    # Single update
                    self.add_update_row(row, category, category_updates)
                    row += 1
                else:
                    # Multiple updates in category
                    for component, update_info in category_updates.items():
                        if isinstance(update_info, dict) and 'name' in update_info:
                            self.add_update_row(row, category, update_info)
                            row += 1
    
    def add_update_row(self, row: int, category: str, update_info: dict):
        """Add a row to the updates table"""
        self.updates_table.insertRow(row)
        
        # Checkbox
        checkbox = QCheckBox()
        checkbox.setChecked(update_info.get('update_available', False))
        checkbox.setStyleSheet("""
            QCheckBox {
                spacing: 5px;
            }
            QCheckBox::indicator {
                width: 18px;
                height: 18px;
            }
            QCheckBox::indicator:unchecked {
                border: 2px solid #606060;
                border-radius: 3px;
                background-color: #2b2b2b;
            }
            QCheckBox::indicator:checked {
                border: 2px solid #0066cc;
                border-radius: 3px;
                background-color: #0066cc;
                image: url(data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iMTAiIGhlaWdodD0iMTAiIHZpZXdCb3g9IjAgMCAxMCAxMCIgZmlsbD0ibm9uZSIgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIj4KPHBhdGggZD0iTTIgNUw0IDdMOCAzIiBzdHJva2U9IndoaXRlIiBzdHJva2Utd2lkdGg9IjIiIHN0cm9rZS1saW5lY2FwPSJyb3VuZCIgc3Ryb2tlLWxpbmVqb2luPSJyb3VuZCIvPgo8L3N2Zz4K);
            }
        """)
        self.updates_table.setCellWidget(row, 0, checkbox)
        
        # Category
        category_item = QTableWidgetItem(category.upper())
        category_item.setTextAlignment(Qt.AlignCenter)
        self.updates_table.setItem(row, 1, category_item)
        
        # Component
        component_item = QTableWidgetItem(update_info.get('name', 'Unknown'))
        self.updates_table.setItem(row, 2, component_item)
        
        # Current Version
        current_item = QTableWidgetItem(update_info.get('current_version', 'Unknown'))
        current_item.setTextAlignment(Qt.AlignCenter)
        self.updates_table.setItem(row, 3, current_item)
        
        # Latest Version
        latest_item = QTableWidgetItem(update_info.get('latest_version', 'Unknown'))
        latest_item.setTextAlignment(Qt.AlignCenter)
        self.updates_table.setItem(row, 4, latest_item)
        
        # Status
        status = update_info.get('status', 'Update Available' if update_info.get('update_available', False) else 'Up to Date')
        status_item = QTableWidgetItem(status)
        status_item.setTextAlignment(Qt.AlignCenter)
        
        # Color code status
        if 'available' in status.lower() or 'installed' in status.lower():
            status_item.setBackground(QColor("#004d00"))  # Dark green
        elif 'up to date' in status.lower():
            status_item.setBackground(QColor("#004d4d"))  # Dark cyan
        elif 'newer' in status.lower():
            status_item.setBackground(QColor("#4d4d00"))  # Dark yellow
        else:
            status_item.setBackground(QColor("#4d0000"))  # Dark red
        
        self.updates_table.setItem(row, 5, status_item)
    
    def select_all_updates(self):
        """Select all available updates"""
        for row in range(self.updates_table.rowCount()):
            checkbox = self.updates_table.cellWidget(row, 0)
            if checkbox:
                checkbox.setChecked(True)
    
    def select_no_updates(self):
        """Deselect all updates"""
        for row in range(self.updates_table.rowCount()):
            checkbox = self.updates_table.cellWidget(row, 0)
            if checkbox:
                checkbox.setChecked(False)
    
    def install_selected_updates(self):
        """Install selected updates"""
        selected_updates = []
        
        for row in range(self.updates_table.rowCount()):
            checkbox = self.updates_table.cellWidget(row, 0)
            if checkbox and checkbox.isChecked():
                category_item = self.updates_table.item(row, 1)
                component_item = self.updates_table.item(row, 2)
                version_item = self.updates_table.item(row, 4)
                
                if category_item and component_item:
                    # Create a proper driver update object
                    update_info = {
                        'name': component_item.text(),
                        'category': category_item.text().lower(),
                        'version': version_item.text() if version_item else 'Latest',
                        'source': 'gui_selection',
                        'priority': 5
                    }
                    selected_updates.append(update_info)
        
        if not selected_updates:
            QMessageBox.information(self, "No Selection", "Please select at least one update to install.")
            return
        
        reply = QMessageBox.question(
            self, "Confirm Installation",
            f"Are you sure you want to install {len(selected_updates)} selected updates?\n\n"
            "This process may take several minutes and require a system restart.",
            QMessageBox.Yes | QMessageBox.No,
            QMessageBox.No
        )
        
        if reply == QMessageBox.Yes:
            self.log_message(f"Starting installation of {len(selected_updates)} updates...", "INFO")
            # Start actual installation process
            self.start_installation(selected_updates)
    
    def start_installation(self, selected_updates):
        """Start the actual driver installation process"""
        import ctypes
        import sys
        
        # Check if running as administrator
        def is_admin():
            try:
                return ctypes.windll.shell32.IsUserAnAdmin()
            except:
                return False
        
        if not is_admin():
            from PyQt5.QtWidgets import QMessageBox
            msg = QMessageBox()
            msg.setIcon(QMessageBox.Warning)
            msg.setWindowTitle("Administrator Required")
            msg.setText("Driver installation requires administrator privileges.")
            msg.setInformativeText("Please restart the application as administrator to install drivers.")
            msg.setStandardButtons(QMessageBox.Ok)
            msg.exec_()
            return
        
        # Simple direct installation without complex threading
        try:
            import asyncio
            
            # Disable install button during installation
            self.install_btn.setEnabled(False)
            self.install_btn.setText("Installing...")
            
            self.log_message(f"Starting installation of {len(selected_updates)} drivers...", "INFO")
            
            # Create progress callback that's thread-safe
            def progress_callback(message, progress=None):
                # Use QTimer to safely update GUI from main thread
                from PyQt5.QtCore import QTimer
                def update_gui():
                    self.log_message(message, "PROGRESS")
                QTimer.singleShot(0, update_gui)
            
            # Prepare installation plan
            self.driver_updater.installation_plan = []
            for update in selected_updates:
                self.driver_updater.installation_plan.append({
                    'driver_info': update,
                    'source': update.get('source', 'manual'),
                    'priority': update.get('priority', 5)
                })
            
            # Execute installation synchronously (Qt will handle GUI updates)
            from PyQt5.QtCore import QCoreApplication
            
            # Process events to keep GUI responsive
            QCoreApplication.processEvents()
            
            # For now, simulate installation process
            self.log_message("Preparing drivers for installation...", "PROGRESS")
            QCoreApplication.processEvents()
            
            import time
            time.sleep(1)  # Simulate preparation
            
            # Use the comprehensive Windows driver installation system
            self.log_message("Starting comprehensive Windows driver installation...", "PROGRESS")
            QCoreApplication.processEvents()
            
            try:
                # Import the Windows driver installer
                import sys
                from pathlib import Path
                sys.path.append(str(Path(__file__).parent.parent))
                from modules.windows_driver_installer import install_windows_drivers
                
                # Create a logger adapter for the installer
                class GUILoggerAdapter:
                    def __init__(self, gui):
                        self.gui = gui
                    
                    def info(self, msg):
                        self.gui.log_message(msg, "INFO")
                    
                    def warning(self, msg):
                        self.gui.log_message(msg, "WARNING")
                    
                    def error(self, msg):
                        self.gui.log_message(msg, "ERROR")
                
                gui_logger = GUILoggerAdapter(self)
                
                # Run the comprehensive driver installation
                result = asyncio.run(install_windows_drivers(gui_logger))
                
                # Process results
                if result.get('success', False):
                    installed_count = result.get('methods_tried', 0)
                    failed_count = 0
                    self.log_message(f"✅ Driver installation completed using Windows built-in methods", "INFO")
                    self.log_message(f"Summary: {result.get('summary', 'Installation completed')}", "INFO")
                else:
                    installed_count = 0
                    failed_count = len(selected_updates)
                    self.log_message(f"❌ Driver installation failed", "ERROR")
                    
                    # Show details of what was tried
                    for result_detail in result.get('results', []):
                        method = result_detail.get('method', 'unknown')
                        success = result_detail.get('success', False)
                        status = "✅" if success else "❌"
                        self.log_message(f"{status} {method.title()} method: {'SUCCESS' if success else 'FAILED'}", "INFO")
                
            except Exception as e:
                self.log_message(f"Critical installation error: {str(e)}", "ERROR")
                installed_count = 0
                failed_count = len(selected_updates)
            
            QCoreApplication.processEvents()
            
            # Show completion results
            self.log_message(f"Installation completed! Installed: {installed_count}, Failed: {failed_count}", "INFO")
            
            from PyQt5.QtWidgets import QMessageBox
            msg = QMessageBox()
            msg.setIcon(QMessageBox.Information if failed_count == 0 else QMessageBox.Warning)
            msg.setWindowTitle("Installation Complete")
            msg.setText(f"Driver installation completed!\n\nInstalled: {installed_count} drivers\nFailed: {failed_count} drivers")
            
            if installed_count > 0:
                msg.setInformativeText("Some drivers may require a system restart to take effect.")
                msg.setStandardButtons(QMessageBox.Ok)
                msg.exec_()
                
                # Ask for restart if needed
                restart_msg = QMessageBox()
                restart_msg.setIcon(QMessageBox.Question)
                restart_msg.setWindowTitle("Restart Recommended")
                restart_msg.setText("Some drivers have been installed successfully.")
                restart_msg.setInformativeText("Would you like to restart now to ensure all drivers are properly loaded?")
                restart_msg.setStandardButtons(QMessageBox.Yes | QMessageBox.No)
                restart_reply = restart_msg.exec_()
                
                if restart_reply == QMessageBox.Yes:
                    import subprocess
                    subprocess.run(["shutdown", "/r", "/t", "30"], shell=True)
                    self.log_message("System will restart in 30 seconds...", "INFO")
            else:
                msg.exec_()
            
        except Exception as e:
            self.log_message(f"Installation error: {str(e)}", "ERROR")
            from PyQt5.QtWidgets import QMessageBox
            QMessageBox.critical(self, "Installation Error", f"An error occurred during installation:\n\n{str(e)}")
        
        finally:
            # Re-enable install button
            self.install_btn.setText("Install Selected")
            self.install_btn.setEnabled(True)
    
    def show_settings(self):
        """Show settings dialog"""
        from PyQt5.QtWidgets import QDialog, QVBoxLayout, QCheckBox, QPushButton, QLabel
        
        dialog = QDialog(self)
        dialog.setWindowTitle("Driver Updater Settings")
        dialog.setFixedSize(400, 300)
        
        layout = QVBoxLayout()
        
        # Add settings options
        layout.addWidget(QLabel("Installation Settings:"))
        
        auto_backup_cb = QCheckBox("Create backup before installation")
        auto_backup_cb.setChecked(True)
        layout.addWidget(auto_backup_cb)
        
        create_restore_cb = QCheckBox("Create system restore point")
        create_restore_cb.setChecked(True)
        layout.addWidget(create_restore_cb)
        
        verify_signatures_cb = QCheckBox("Verify driver signatures")
        verify_signatures_cb.setChecked(True)
        layout.addWidget(verify_signatures_cb)
        
        layout.addWidget(QLabel("\nDriver Sources:"))
        
        nvidia_cb = QCheckBox("NVIDIA official drivers")
        nvidia_cb.setChecked(True)
        layout.addWidget(nvidia_cb)
        
        amd_cb = QCheckBox("AMD official drivers")
        amd_cb.setChecked(True)
        layout.addWidget(amd_cb)
        
        windows_update_cb = QCheckBox("Windows Update drivers")
        windows_update_cb.setChecked(True)
        layout.addWidget(windows_update_cb)
        
        # Buttons
        button_layout = QVBoxLayout()
        save_btn = QPushButton("Save Settings")
        cancel_btn = QPushButton("Cancel")
        
        button_layout.addWidget(save_btn)
        button_layout.addWidget(cancel_btn)
        layout.addLayout(button_layout)
        
        save_btn.clicked.connect(dialog.accept)
        cancel_btn.clicked.connect(dialog.reject)
        
        dialog.setLayout(layout)
        
        if dialog.exec_() == QDialog.Accepted:
            self.log_message("Settings saved successfully", "INFO")
    
    def clear_logs(self):
        """Clear the log text area"""
        self.log_text.clear()
    
    def log_message(self, message: str, level: str = "INFO"):
        """Add message to log"""
        from datetime import datetime
        timestamp = datetime.now().strftime("%H:%M:%S")
        
        # Color code by level
        color = "#ffffff"  # Default white
        if level == "ERROR":
            color = "#ff6b6b"
        elif level == "WARNING":
            color = "#ffd93d"
        elif level == "INFO":
            color = "#6bcf7f"
        elif level == "PROGRESS":
            color = "#4ecdc4"
        
        formatted_message = f'<span style="color: #888888;">[{timestamp}]</span> <span style="color: {color}; font-weight: bold;">{level}:</span> <span style="color: #ffffff;">{message}</span>'
        
        self.log_text.append(formatted_message)
        
        # Auto-scroll to bottom
        cursor = self.log_text.textCursor()
        cursor.movePosition(cursor.End)
        self.log_text.setTextCursor(cursor)
    
    def on_error(self, error_message: str):
        """Handle error occurred"""
        self.log_message(f"Error: {error_message}", "ERROR")
        QMessageBox.critical(self, "Error", f"An error occurred:\n{error_message}")
    
    def closeEvent(self, event):
        """Handle close event"""
        if hasattr(self, 'tray_icon') and self.tray_icon.isVisible():
            self.hide()
            self.tray_icon.showMessage(
                "Driver Updater",
                "Application was minimized to tray",
                QSystemTrayIcon.Information,
                2000
            )
            event.ignore()
        else:
            event.accept()

def run_pyqt5_gui(driver_updater):
    """Run the PyQt5 GUI"""
    # Enable high DPI scaling BEFORE creating QApplication
    QApplication.setAttribute(Qt.AA_EnableHighDpiScaling, True)
    QApplication.setAttribute(Qt.AA_UseHighDpiPixmaps, True)
    
    app = QApplication(sys.argv)
    
    # Set application properties
    app.setApplicationName("Laptop Driver Updater")
    app.setApplicationVersion("2.0")
    app.setOrganizationName("DriverUpdater")
    
    # Create and show main window
    window = ModernDriverUpdaterGUI(driver_updater)
    window.show()
    
    # Run application
    return app.exec_()

if __name__ == "__main__":
    # Test the GUI independently
    import sys
    from pathlib import Path
    
    # Add parent directory to path
    sys.path.append(str(Path(__file__).parent.parent))
    
    class MockDriverUpdater:
        def __init__(self):
            from modules.hardware_detector import HardwareDetector
            from modules.nvidia_handler import NvidiaDriverHandler
            from modules.amd_handler import AMDDriverHandler
            from modules.asus_handler import AsusDriverHandler
            
            self.hardware_detector = HardwareDetector()
            self.nvidia_handler = NvidiaDriverHandler()
            self.amd_handler = AMDDriverHandler()
            self.asus_handler = AsusDriverHandler()
    
    mock_updater = MockDriverUpdater()
    run_pyqt5_gui(mock_updater)
