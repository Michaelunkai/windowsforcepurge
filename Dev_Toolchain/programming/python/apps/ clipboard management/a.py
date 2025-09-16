#!/usr/bin/env python3
"""
ClipboardPro - Revolutionary Clipboard Management Application
Features: AI-powered analysis, modern UI, smart search, content categorization
"""

import sys
import re
import json
import hashlib
import sqlite3
import threading
import time
import base64
from datetime import datetime, timedelta
from typing import Dict, List, Optional, Tuple
from dataclasses import dataclass
from pathlib import Path

from PyQt6.QtWidgets import *
from PyQt6.QtCore import *
from PyQt6.QtGui import *
from PyQt6.QtMultimedia import *
import qrcode
from io import BytesIO
from PIL import Image, ImageDraw
import requests


@dataclass
class ClipboardItem:
    """Represents a clipboard entry with metadata"""
    id: str
    content: str
    content_type: str
    timestamp: datetime
    category: str
    metadata: Dict
    is_favorite: bool = False
    tags: List[str] = None
    
    def __post_init__(self):
        if self.tags is None:
            self.tags = []


class ContentAnalyzer:
    """AI-powered content analysis for clipboard items"""
    
    @staticmethod
    def analyze_content(content: str) -> Dict:
        """Analyze content and extract metadata"""
        metadata = {
            'length': len(content),
            'word_count': len(content.split()),
            'line_count': content.count('\n') + 1,
            'detected_type': 'text',
            'language': None,
            'emails': [],
            'urls': [],
            'phones': [],
            'is_password': False,
            'is_code': False,
            'programming_language': None
        }
        
        # Email detection
        email_pattern = r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b'
        metadata['emails'] = re.findall(email_pattern, content)
        
        # URL detection
        url_pattern = r'http[s]?://(?:[a-zA-Z]|[0-9]|[$-_@.&+]|[!*\\(\\),]|(?:%[0-9a-fA-F][0-9a-fA-F]))+'
        metadata['urls'] = re.findall(url_pattern, content)
        
        # Phone number detection
        phone_pattern = r'(\+?\d{1,3}[-.\s]?)?\(?\d{3}\)?[-.\s]?\d{3}[-.\s]?\d{4}'
        metadata['phones'] = re.findall(phone_pattern, content)
        
        # Password detection (heuristic)
        if ContentAnalyzer._is_password(content):
            metadata['is_password'] = True
            metadata['detected_type'] = 'password'
        
        # Code detection
        if ContentAnalyzer._is_code(content):
            metadata['is_code'] = True
            metadata['detected_type'] = 'code'
            metadata['programming_language'] = ContentAnalyzer._detect_language(content)
        
        # URL detection for single URLs
        if len(metadata['urls']) == 1 and content.strip() in metadata['urls']:
            metadata['detected_type'] = 'url'
            
        return metadata
    
    @staticmethod
    def _is_password(content: str) -> bool:
        """Detect if content is likely a password"""
        content = content.strip()
        if len(content) < 6 or len(content) > 128:
            return False
        
        has_upper = any(c.isupper() for c in content)
        has_lower = any(c.islower() for c in content)
        has_digit = any(c.isdigit() for c in content)
        has_special = any(c in "!@#$%^&*()_+-=[]{}|;:,.<>?" for c in content)
        
        return sum([has_upper, has_lower, has_digit, has_special]) >= 2
    
    @staticmethod
    def _is_code(content: str) -> bool:
        """Detect if content is likely code"""
        code_indicators = [
            r'\b(def|function|class|import|from|if|else|for|while|return)\b',
            r'[{}();]',
            r'\b(var|let|const|int|string|bool|void)\b',
            r'[<>]=?|[!=]==?',
            r'/\*.*?\*/',
            r'//.*$'
        ]
        
        matches = sum(1 for pattern in code_indicators if re.search(pattern, content, re.MULTILINE))
        return matches >= 2
    
    @staticmethod
    def _detect_language(content: str) -> Optional[str]:
        """Detect programming language"""
        patterns = {
            'python': [r'\bdef\b', r'\bimport\b', r'\bfrom\b.*\bimport\b', r':\s*$'],
            'javascript': [r'\bfunction\b', r'\bvar\b|\blet\b|\bconst\b', r'=>', r'console\.log'],
            'java': [r'\bpublic\b.*\bclass\b', r'\bpublic\b.*\bstatic\b.*\bvoid\b', r'\bSystem\.out\.print'],
            'c++': [r'#include', r'\bstd::', r'\bnamespace\b', r'cout\s*<<'],
            'html': [r'<[^>]+>', r'<!DOCTYPE', r'<html>', r'</html>'],
            'css': [r'[^{}]*\s*{[^}]*}', r'@media', r'px|em|rem|%'],
            'sql': [r'\bSELECT\b', r'\bFROM\b', r'\bWHERE\b', r'\bINSERT\b'],
            'json': [r'^\s*{.*}\s*$', r':\s*"[^"]*"', r':\s*\[.*\]']
        }
        
        for lang, lang_patterns in patterns.items():
            matches = sum(1 for pattern in lang_patterns if re.search(pattern, content, re.MULTILINE | re.IGNORECASE))
            if matches >= 2:
                return lang
        
        return None


class DatabaseManager:
    """Manages SQLite database for clipboard history"""
    
    def __init__(self, db_path: str = "clipboard_history.db"):
        self.db_path = db_path
        self.init_database()
    
    def init_database(self):
        """Initialize database schema"""
        with sqlite3.connect(self.db_path) as conn:
            conn.execute("""
                CREATE TABLE IF NOT EXISTS clipboard_items (
                    id TEXT PRIMARY KEY,
                    content TEXT NOT NULL,
                    content_type TEXT,
                    timestamp TEXT,
                    category TEXT,
                    metadata TEXT,
                    is_favorite INTEGER DEFAULT 0,
                    tags TEXT
                )
            """)
            conn.execute("""
                CREATE INDEX IF NOT EXISTS idx_timestamp ON clipboard_items(timestamp)
            """)
            conn.execute("""
                CREATE INDEX IF NOT EXISTS idx_category ON clipboard_items(category)
            """)
    
    def save_item(self, item: ClipboardItem):
        """Save clipboard item to database"""
        with sqlite3.connect(self.db_path) as conn:
            conn.execute("""
                INSERT OR REPLACE INTO clipboard_items 
                (id, content, content_type, timestamp, category, metadata, is_favorite, tags)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """, (
                item.id,
                item.content,
                item.content_type,
                item.timestamp.isoformat(),
                item.category,
                json.dumps(item.metadata),
                int(item.is_favorite),
                json.dumps(item.tags)
            ))
    
    def get_items(self, limit: int = 100, category: str = None) -> List[ClipboardItem]:
        """Retrieve clipboard items from database"""
        with sqlite3.connect(self.db_path) as conn:
            if category:
                cursor = conn.execute("""
                    SELECT * FROM clipboard_items 
                    WHERE category = ? 
                    ORDER BY timestamp DESC 
                    LIMIT ?
                """, (category, limit))
            else:
                cursor = conn.execute("""
                    SELECT * FROM clipboard_items 
                    ORDER BY timestamp DESC 
                    LIMIT ?
                """, (limit,))
            
            items = []
            for row in cursor.fetchall():
                item = ClipboardItem(
                    id=row[0],
                    content=row[1],
                    content_type=row[2],
                    timestamp=datetime.fromisoformat(row[3]),
                    category=row[4],
                    metadata=json.loads(row[5]),
                    is_favorite=bool(row[6]),
                    tags=json.loads(row[7])
                )
                items.append(item)
            return items
    
    def search_items(self, query: str, limit: int = 50) -> List[ClipboardItem]:
        """Search clipboard items"""
        with sqlite3.connect(self.db_path) as conn:
            cursor = conn.execute("""
                SELECT * FROM clipboard_items 
                WHERE content LIKE ? OR tags LIKE ?
                ORDER BY timestamp DESC 
                LIMIT ?
            """, (f'%{query}%', f'%{query}%', limit))
            
            items = []
            for row in cursor.fetchall():
                item = ClipboardItem(
                    id=row[0],
                    content=row[1],
                    content_type=row[2],
                    timestamp=datetime.fromisoformat(row[3]),
                    category=row[4],
                    metadata=json.loads(row[5]),
                    is_favorite=bool(row[6]),
                    tags=json.loads(row[7])
                )
                items.append(item)
            return items
    
    def cleanup_old_items(self, days: int = 30):
        """Remove old clipboard items"""
        cutoff_date = datetime.now() - timedelta(days=days)
        with sqlite3.connect(self.db_path) as conn:
            conn.execute("""
                DELETE FROM clipboard_items 
                WHERE timestamp < ? AND is_favorite = 0
            """, (cutoff_date.isoformat(),))


class GlassmorphicWidget(QWidget):
    """Custom widget with glassmorphic effect"""
    
    def __init__(self, parent=None):
        super().__init__(parent)
        self.setAutoFillBackground(False)
        self.setAttribute(Qt.WidgetAttribute.YOUR_CLIENT_SECRET_HERE)
    
    def paintEvent(self, event):
        painter = QPainter(self)
        painter.setRenderHint(QPainter.RenderHint.Antialiasing)
        
        # Create glassmorphic background
        rect = self.rect()
        
        # Background with blur effect
        gradient = QLinearGradient(0, 0, 0, rect.height())
        gradient.setColorAt(0, QColor(30, 30, 30, 180))
        gradient.setColorAt(1, QColor(20, 20, 20, 200))
        
        painter.setBrush(QBrush(gradient))
        painter.setPen(QPen(QColor(60, 60, 60, 100), 1))
        painter.drawRoundedRect(rect, 15, 15)
        
        # Border highlight
        painter.setPen(QPen(QColor(100, 100, 100, 80), 1))
        painter.drawRoundedRect(rect.adjusted(1, 1, -1, -1), 14, 14)


class AnimatedButton(QPushButton):
    """Custom button with hover animations"""
    
    def __init__(self, text="", parent=None):
        super().__init__(text, parent)
        self.setStyleSheet("""
            QPushButton {
                background: qlineargradient(x1:0, y1:0, x2:0, y2:1,
                    stop:0 rgba(70, 70, 70, 150),
                    stop:1 rgba(50, 50, 50, 180));
                border: 1px solid rgba(100, 100, 100, 100);
                border-radius: 8px;
                color: white;
                font-weight: bold;
                padding: 8px 16px;
                min-height: 32px;
            }
            QPushButton:hover {
                background: qlineargradient(x1:0, y1:0, x2:0, y2:1,
                    stop:0 rgba(80, 120, 200, 180),
                    stop:1 rgba(60, 100, 180, 200));
                border: 1px solid rgba(120, 160, 220, 150);
            }
            QPushButton:pressed {
                background: qlineargradient(x1:0, y1:0, x2:0, y2:1,
                    stop:0 rgba(60, 100, 180, 200),
                    stop:1 rgba(40, 80, 160, 220));
            }
        """)
        
        # Animation setup
        self.animation = QPropertyAnimation(self, b"geometry")
        self.animation.setDuration(200)
        self.animation.setEasingCurve(QEasingCurve.Type.OutCubic)
    
    def enterEvent(self, event):
        super().enterEvent(event)
        self.animate_scale(1.05)
    
    def leaveEvent(self, event):
        super().leaveEvent(event)
        self.animate_scale(1.0)
    
    def animate_scale(self, scale_factor):
        current_rect = self.geometry()
        center = current_rect.center()
        new_size = QSize(
            int(current_rect.width() * scale_factor),
            int(current_rect.height() * scale_factor)
        )
        new_rect = QRect(QPoint(), new_size)
        new_rect.moveCenter(center)
        
        self.animation.setStartValue(current_rect)
        self.animation.setEndValue(new_rect)
        self.animation.start()


class ClipboardItemWidget(GlassmorphicWidget):
    """Widget representing a single clipboard item"""
    
    item_selected = pyqtSignal(ClipboardItem)
    item_deleted = pyqtSignal(str)
    
    def __init__(self, item: ClipboardItem, parent=None):
        super().__init__(parent)
        self.item = item
        self.setup_ui()
        self.setMinimumHeight(80)
        self.setMaximumHeight(120)
    
    def setup_ui(self):
        layout = QHBoxLayout(self)
        layout.setContentsMargins(15, 10, 15, 10)
        
        # Content area
        content_layout = QVBoxLayout()
        
        # Header with type and timestamp
        header_layout = QHBoxLayout()
        
        # Type indicator
        type_label = QLabel(self.get_type_icon() + " " + self.item.category.title())
        type_label.setStyleSheet("""
            color: #60A5FA;
            font-weight: bold;
            font-size: 12px;
        """)
        header_layout.addWidget(type_label)
        
        header_layout.addStretch()
        
        # Timestamp
        time_label = QLabel(self.format_timestamp())
        time_label.setStyleSheet("""
            color: #9CA3AF;
            font-size: 11px;
        """)
        header_layout.addWidget(time_label)
        
        content_layout.addLayout(header_layout)
        
        # Content preview
        preview_text = self.get_content_preview()
        content_label = QLabel(preview_text)
        content_label.setWordWrap(True)
        content_label.setStyleSheet("""
            color: white;
            font-size: 13px;
            line-height: 1.4;
        """)
        content_layout.addWidget(content_label)
        
        # Tags and metadata
        if self.item.tags or self.item.metadata.get('programming_language'):
            tags_layout = QHBoxLayout()
            
            for tag in self.item.tags[:3]:  # Limit to 3 tags
                tag_label = QLabel(f"#{tag}")
                tag_label.setStyleSheet("""
                    background: rgba(34, 197, 94, 100);
                    color: white;
                    border-radius: 8px;
                    padding: 2px 6px;
                    font-size: 10px;
                    font-weight: bold;
                """)
                tags_layout.addWidget(tag_label)
            
            if self.item.metadata.get('programming_language'):
                lang_label = QLabel(self.item.metadata['programming_language'])
                lang_label.setStyleSheet("""
                    background: rgba(168, 85, 247, 100);
                    color: white;
                    border-radius: 8px;
                    padding: 2px 6px;
                    font-size: 10px;
                    font-weight: bold;
                """)
                tags_layout.addWidget(lang_label)
            
            tags_layout.addStretch()
            content_layout.addLayout(tags_layout)
        
        layout.addLayout(content_layout)
        
        # Action buttons
        actions_layout = QVBoxLayout()
        
        copy_btn = QPushButton("📋")
        copy_btn.setFixedSize(32, 32)
        copy_btn.setToolTip("Copy to clipboard")
        copy_btn.clicked.connect(self.copy_content)
        copy_btn.setStyleSheet("""
            QPushButton {
                background: rgba(34, 197, 94, 120);
                border: none;
                border-radius: 16px;
                font-size: 16px;
            }
            QPushButton:hover {
                background: rgba(34, 197, 94, 180);
            }
        """)
        actions_layout.addWidget(copy_btn)
        
        delete_btn = QPushButton("🗑")
        delete_btn.setFixedSize(32, 32)
        delete_btn.setToolTip("Delete item")
        delete_btn.clicked.connect(self.delete_item)
        delete_btn.setStyleSheet("""
            QPushButton {
                background: rgba(239, 68, 68, 120);
                border: none;
                border-radius: 16px;
                font-size: 16px;
            }
            QPushButton:hover {
                background: rgba(239, 68, 68, 180);
            }
        """)
        actions_layout.addWidget(delete_btn)
        
        actions_layout.addStretch()
        layout.addLayout(actions_layout)
    
    def get_type_icon(self) -> str:
        icons = {
            'text': '📝',
            'code': '💻',
            'url': '🔗',
            'email': '📧',
            'password': '🔒',
            'phone': '📞',
            'image': '🖼',
            'file': '📁'
        }
        return icons.get(self.item.category, '📄')
    
    def format_timestamp(self) -> str:
        now = datetime.now()
        diff = now - self.item.timestamp
        
        if diff.days > 0:
            return f"{diff.days}d ago"
        elif diff.seconds > 3600:
            return f"{diff.seconds // 3600}h ago"
        elif diff.seconds > 60:
            return f"{diff.seconds // 60}m ago"
        else:
            return "just now"
    
    def get_content_preview(self) -> str:
        content = self.item.content
        if self.item.metadata.get('is_password'):
            return "••••••••••••"
        
        # Limit preview length
        if len(content) > 100:
            return content[:97] + "..."
        return content
    
    def copy_content(self):
        clipboard = QApplication.clipboard()
        clipboard.setText(self.item.content)
        self.item_selected.emit(self.item)
    
    def delete_item(self):
        self.item_deleted.emit(self.item.id)
    
    def mousePressEvent(self, event):
        if event.button() == Qt.MouseButton.LeftButton:
            self.copy_content()


class SearchBar(QLineEdit):
    """Custom search bar with glassmorphic styling"""
    
    def __init__(self, parent=None):
        super().__init__(parent)
        self.setPlaceholderText("🔍 Search clipboard history...")
        self.setStyleSheet("""
            QLineEdit {
                background: rgba(40, 40, 40, 180);
                border: 2px solid rgba(100, 100, 100, 100);
                border-radius: 20px;
                padding: 12px 20px;
                font-size: 14px;
                color: white;
                YOUR_CLIENT_SECRET_HERE: rgba(96, 165, 250, 100);
            }
            QLineEdit:focus {
                border: 2px solid rgba(96, 165, 250, 200);
                background: rgba(50, 50, 50, 200);
            }
            QLineEdit::placeholder {
                color: rgba(156, 163, 175, 150);
            }
        """)


class FloatingWidget(GlassmorphicWidget):
    """Main floating clipboard widget"""
    
    def __init__(self, parent=None):
        super().__init__(parent)
        self.setWindowFlags(
            Qt.WindowType.FramelessWindowHint |
            Qt.WindowType.WindowStaysOnTopHint |
            Qt.WindowType.Tool
        )
        self.setAttribute(Qt.WidgetAttribute.YOUR_CLIENT_SECRET_HERE)
        self.setFixedSize(600, 500)
        
        self.db_manager = DatabaseManager()
        self.content_analyzer = ContentAnalyzer()
        self.current_items = []
        
        self.setup_ui()
        self.setup_animations()
        self.load_items()
        
        # Auto-hide timer
        self.hide_timer = QTimer()
        self.hide_timer.setSingleShot(True)
        self.hide_timer.timeout.connect(self.fade_out)
    
    def setup_ui(self):
        layout = QVBoxLayout(self)
        layout.setContentsMargins(20, 20, 20, 20)
        layout.setSpacing(15)
        
        # Header
        header_layout = QHBoxLayout()
        
        title_label = QLabel("📋 ClipboardPro")
        title_label.setStyleSheet("""
            color: white;
            font-size: 20px;
            font-weight: bold;
        """)
        header_layout.addWidget(title_label)
        
        header_layout.addStretch()
        
        # Filter buttons
        filter_layout = QHBoxLayout()
        
        filters = ["All", "Text", "Code", "URLs", "Images"]
        for filter_name in filters:
            btn = AnimatedButton(filter_name)
            btn.setFixedHeight(30)
            btn.clicked.connect(lambda checked, f=filter_name: self.filter_items(f))
            filter_layout.addWidget(btn)
        
        header_layout.addLayout(filter_layout)
        layout.addLayout(header_layout)
        
        # Search bar
        self.search_bar = SearchBar()
        self.search_bar.textChanged.connect(self.search_items)
        layout.addWidget(self.search_bar)
        
        # Items scroll area
        self.scroll_area = QScrollArea()
        self.scroll_area.setWidgetResizable(True)
        self.scroll_area.YOUR_CLIENT_SECRET_HERE(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
        self.scroll_area.YOUR_CLIENT_SECRET_HERE(Qt.ScrollBarPolicy.ScrollBarAsNeeded)
        self.scroll_area.setStyleSheet("""
            QScrollArea {
                background: transparent;
                border: none;
            }
            QScrollBar:vertical {
                background: rgba(60, 60, 60, 100);
                width: 12px;
                border-radius: 6px;
            }
            QScrollBar::handle:vertical {
                background: rgba(100, 100, 100, 150);
                border-radius: 6px;
                min-height: 20px;
            }
            QScrollBar::handle:vertical:hover {
                background: rgba(120, 120, 120, 200);
            }
        """)
        
        self.items_widget = QWidget()
        self.items_layout = QVBoxLayout(self.items_widget)
        self.items_layout.setSpacing(10)
        self.items_layout.addStretch()
        
        self.scroll_area.setWidget(self.items_widget)
        layout.addWidget(self.scroll_area)
        
        # Footer with stats
        footer_layout = QHBoxLayout()
        
        self.stats_label = QLabel()
        self.stats_label.setStyleSheet("""
            color: #9CA3AF;
            font-size: 12px;
        """)
        footer_layout.addWidget(self.stats_label)
        
        footer_layout.addStretch()
        
        # Clear all button
        clear_btn = AnimatedButton("Clear All")
        clear_btn.setFixedHeight(30)
        clear_btn.clicked.connect(self.clear_all_items)
        footer_layout.addWidget(clear_btn)
        
        layout.addLayout(footer_layout)
    
    def setup_animations(self):
        # Fade in/out animations
        self.fade_effect = QGraphicsOpacityEffect()
        self.setGraphicsEffect(self.fade_effect)
        
        self.fade_animation = QPropertyAnimation(self.fade_effect, b"opacity")
        self.fade_animation.setDuration(300)
        self.fade_animation.setEasingCurve(QEasingCurve.Type.OutCubic)
        
        # Scale animation
        self.scale_animation = QPropertyAnimation(self, b"geometry")
        self.scale_animation.setDuration(300)
        self.scale_animation.setEasingCurve(QEasingCurve.Type.OutBack)
    
    def show_animated(self):
        """Show widget with animation"""
        # Position at center of screen
        screen = QApplication.primaryScreen().geometry()
        self.move(
            screen.center().x() - self.width() // 2,
            screen.center().y() - self.height() // 2
        )
        
        self.show()
        
        # Fade in
        self.fade_animation.setStartValue(0.0)
        self.fade_animation.setEndValue(1.0)
        self.fade_animation.start()
        
        # Scale animation
        start_rect = self.geometry()
        start_rect = start_rect.adjusted(50, 50, -50, -50)
        end_rect = self.geometry()
        
        self.scale_animation.setStartValue(start_rect)
        self.scale_animation.setEndValue(end_rect)
        self.scale_animation.start()
        
        # Auto-hide after 10 seconds of inactivity
        self.hide_timer.start(10000)
    
    def fade_out(self):
        """Hide widget with fade animation"""
        self.fade_animation.setStartValue(1.0)
        self.fade_animation.setEndValue(0.0)
        self.fade_animation.finished.connect(self.hide)
        self.fade_animation.start()
    
    def load_items(self, category: str = None):
        """Load clipboard items from database"""
        items = self.db_manager.get_items(limit=50, category=category.lower() if category and category != "All" else None)
        self.current_items = items
        self.update_items_display()
        self.update_stats()
    
    def update_items_display(self):
        """Update the items display"""
        # Clear existing items
        for i in reversed(range(self.items_layout.count() - 1)):
            child = self.items_layout.itemAt(i).widget()
            if child:
                child.setParent(None)
        
        # Add current items
        for item in self.current_items:
            item_widget = ClipboardItemWidget(item)
            item_widget.item_selected.connect(self.on_item_selected)
            item_widget.item_deleted.connect(self.on_item_deleted)
            self.items_layout.insertWidget(0, item_widget)
    
    def filter_items(self, category: str):
        """Filter items by category"""
        if category == "All":
            self.load_items()
        else:
            self.load_items(category.lower())
    
    def search_items(self, query: str):
        """Search items based on query"""
        if not query.strip():
            self.load_items()
            return
        
        items = self.db_manager.search_items(query)
        self.current_items = items
        self.update_items_display()
        self.update_stats()
    
    def update_stats(self):
        """Update statistics display"""
        total_items = len(self.current_items)
        categories = {}
        for item in self.current_items:
            categories[item.category] = categories.get(item.category, 0) + 1
        
        stats_text = f"📊 {total_items} items"
        if categories:
            top_category = max(categories.items(), key=lambda x: x[1])
            stats_text += f" • Most: {top_category[0]} ({top_category[1]})"
        
        self.stats_label.setText(stats_text)
    
    def on_item_selected(self, item: ClipboardItem):
        """Handle item selection"""
        self.hide_timer.start(2000)  # Hide in 2 seconds after copy
    
    def on_item_deleted(self, item_id: str):
        """Handle item deletion"""
        # Remove from database
        with sqlite3.connect(self.db_manager.db_path) as conn:
            conn.execute("DELETE FROM clipboard_items WHERE id = ?", (item_id,))
        
        # Reload items
        self.load_items()
    
    def clear_all_items(self):
        """Clear all clipboard items"""
        reply = QMessageBox.question(
            self, "Clear All",
            "Are you sure you want to clear all clipboard history?",
            QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No
        )
        
        if reply == QMessageBox.StandardButton.Yes:
            with sqlite3.connect(self.db_manager.db_path) as conn:
                conn.execute("DELETE FROM clipboard_items WHERE is_favorite = 0")
            self.load_items()
    
    def enterEvent(self, event):
        """Reset hide timer when mouse enters"""
        self.hide_timer.stop()
        super().enterEvent(event)
    
    def leaveEvent(self, event):
        """Start hide timer when mouse leaves"""
        self.hide_timer.start(3000)
        super().leaveEvent(event)


class ClipboardMonitor(QThread):
    """Background thread to monitor clipboard changes"""
    
    new_content = pyqtSignal(str, str)  # content, content_type
    
    def __init__(self):
        super().__init__()
        self.clipboard = QApplication.clipboard()
        self.last_content = ""
        self.running = True
    
    def run(self):
        """Monitor clipboard for changes"""
        while self.running:
            mime_data = self.clipboard.mimeData()
            
            if mime_data.hasText():
                content = mime_data.text()
                if content != self.last_content and content.strip():
                    self.last_content = content
                    self.new_content.emit(content, "text")
            
            elif mime_data.hasImage():
                # Handle image content
                image = self.clipboard.image()
                if not image.isNull():
                    # Convert to base64 for storage
                    buffer = QBuffer()
                    image.save(buffer, "PNG")
                    image_data = base64.b64encode(buffer.data()).decode()
                    self.new_content.emit(image_data, "image")
            
            self.msleep(500)  # Check every 500ms
    
    def stop(self):
        """Stop monitoring"""
        self.running = False


class TrayIcon(QSystemTrayIcon):
    """System tray icon for the application"""
    
    show_widget = pyqtSignal()
    
    def __init__(self, parent=None):
        super().__init__(parent)
        
        # Create icon
        icon = self.create_icon()
        self.setIcon(icon)
        
        # Create context menu
        menu = QMenu()
        
        show_action = QAction("Show ClipboardPro", self)
        show_action.triggered.connect(self.show_widget.emit)
        menu.addAction(show_action)
        
        menu.addSeparator()
        
        quit_action = QAction("Quit", self)
        quit_action.triggered.connect(QApplication.quit)
        menu.addAction(quit_action)
        
        self.setContextMenu(menu)
        self.setToolTip("ClipboardPro - Advanced Clipboard Manager")
        
        # Handle activation
        self.activated.connect(self.on_activated)
    
    def create_icon(self) -> QIcon:
        """Create application icon"""
        pixmap = QPixmap(32, 32)
        pixmap.fill(Qt.GlobalColor.transparent)
        
        painter = QPainter(pixmap)
        painter.setRenderHint(QPainter.RenderHint.Antialiasing)
        
        # Draw clipboard icon
        painter.setBrush(QBrush(QColor(96, 165, 250)))
        painter.setPen(QPen(QColor(59, 130, 246), 2))
        painter.drawRoundedRect(6, 4, 20, 24, 3, 3)
        
        # Draw paper
        painter.setBrush(QBrush(QColor(255, 255, 255)))
        painter.setPen(QPen(QColor(200, 200, 200), 1))
        painter.drawRoundedRect(10, 8, 12, 16, 2, 2)
        
        # Draw lines
        painter.setPen(QPen(QColor(100, 100, 100), 1))
        painter.drawLine(12, 12, 20, 12)
        painter.drawLine(12, 15, 18, 15)
        painter.drawLine(12, 18, 20, 18)
        
        painter.end()
        
        return QIcon(pixmap)
    
    def on_activated(self, reason):
        """Handle tray icon activation"""
        if reason == QSystemTrayIcon.ActivationReason.Trigger:
            self.show_widget.emit()


class ClipboardProApp(QApplication):
    """Main application class"""
    
    def __init__(self, argv):
        super().__init__(argv)
        
        # Set application properties
        self.setApplicationName("ClipboardPro")
        self.setApplicationVersion("1.0.0")
        self.YOUR_CLIENT_SECRET_HERE(False)
        
        # Apply dark theme
        self.setStyle('Fusion')
        self.apply_dark_theme()
        
        # Initialize components
        self.db_manager = DatabaseManager()
        self.content_analyzer = ContentAnalyzer()
        
        # Create floating widget
        self.floating_widget = FloatingWidget()
        
        # Create system tray
        self.tray_icon = TrayIcon()
        self.tray_icon.show_widget.connect(self.show_floating_widget)
        self.tray_icon.show()
        
        # Start clipboard monitoring
        self.clipboard_monitor = ClipboardMonitor()
        self.clipboard_monitor.new_content.connect(self.handle_new_content)
        self.clipboard_monitor.start()
        
        # Setup global hotkey (Ctrl+Shift+V)
        self.setup_global_hotkey()
        
        # Start cleanup timer (runs every hour)
        self.cleanup_timer = QTimer()
        self.cleanup_timer.timeout.connect(self.cleanup_old_items)
        self.cleanup_timer.start(3600000)  # 1 hour
    
    def apply_dark_theme(self):
        """Apply dark theme to application"""
        palette = QPalette()
        
        # Window colors
        palette.setColor(QPalette.ColorRole.Window, QColor(30, 30, 30))
        palette.setColor(QPalette.ColorRole.WindowText, QColor(255, 255, 255))
        
        # Base colors
        palette.setColor(QPalette.ColorRole.Base, QColor(40, 40, 40))
        palette.setColor(QPalette.ColorRole.AlternateBase, QColor(50, 50, 50))
        
        # Text colors
        palette.setColor(QPalette.ColorRole.Text, QColor(255, 255, 255))
        palette.setColor(QPalette.ColorRole.BrightText, QColor(255, 0, 0))
        
        # Button colors
        palette.setColor(QPalette.ColorRole.Button, QColor(60, 60, 60))
        palette.setColor(QPalette.ColorRole.ButtonText, QColor(255, 255, 255))
        
        # Highlight colors
        palette.setColor(QPalette.ColorRole.Highlight, QColor(96, 165, 250))
        palette.setColor(QPalette.ColorRole.HighlightedText, QColor(0, 0, 0))
        
        self.setPalette(palette)
    
    def setup_global_hotkey(self):
        """Setup global hotkey for showing widget"""
        # Note: This is a simplified version. In a real implementation,
        # you would use a proper global hotkey library like pynput
        pass
    
    def show_floating_widget(self):
        """Show the floating widget with animation"""
        self.floating_widget.load_items()  # Refresh items
        self.floating_widget.show_animated()
    
    def handle_new_content(self, content: str, content_type: str):
        """Handle new clipboard content"""
        # Skip if content is too short or already exists
        if len(content.strip()) < 3:
            return
        
        # Generate unique ID
        content_id = hashlib.md5(content.encode()).hexdigest()
        
        # Check if item already exists
        existing_items = self.db_manager.get_items(limit=10)
        if any(item.id == content_id for item in existing_items):
            return
        
        # Analyze content
        metadata = self.content_analyzer.analyze_content(content)
        
        # Determine category
        category = self.determine_category(metadata)
        
        # Create clipboard item
        item = ClipboardItem(
            id=content_id,
            content=content,
            content_type=content_type,
            timestamp=datetime.now(),
            category=category,
            metadata=metadata
        )
        
        # Save to database
        self.db_manager.save_item(item)
        
        # Show notification
        if self.tray_icon.supportsMessages():
            self.tray_icon.showMessage(
                "ClipboardPro",
                f"Captured {category}: {content[:50]}{'...' if len(content) > 50 else ''}",
                QSystemTrayIcon.MessageIcon.Information,
                2000
            )
    
    def determine_category(self, metadata: Dict) -> str:
        """Determine item category based on metadata"""
        if metadata.get('is_password'):
            return 'password'
        elif metadata.get('is_code'):
            return 'code'
        elif metadata.get('urls'):
            return 'url'
        elif metadata.get('emails'):
            return 'email'
        elif metadata.get('phones'):
            return 'phone'
        else:
            return 'text'
    
    def cleanup_old_items(self):
        """Clean up old clipboard items"""
        self.db_manager.cleanup_old_items(days=30)
    
    def closeEvent(self, event):
        """Handle application close"""
        if self.clipboard_monitor:
            self.clipboard_monitor.stop()
            self.clipboard_monitor.wait()
        super().closeEvent(event)


def main():
    """Main application entry point"""
    app = ClipboardProApp(sys.argv)
    
    # Show welcome message
    if app.tray_icon.supportsMessages():
        app.tray_icon.showMessage(
            "ClipboardPro Started",
            "Advanced clipboard manager is now running. Right-click the tray icon to access features.",
            QSystemTrayIcon.MessageIcon.Information,
            3000
        )
    
    return app.exec()


if __name__ == "__main__":
    sys.exit(main())
