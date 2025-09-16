#!/usr/bin/env python3
"""
Comprehensive Freelance Automation Platform
Professional CRM-style interface with automated bidding, client management, and project tracking
"""

import sys
import json
import sqlite3
import datetime
import random
from typing import Dict, List, Any, Optional
from dataclasses import dataclass, asdict
from pathlib import Path

from PyQt6.QtWidgets import (
    QApplication, QMainWindow, QWidget, QVBoxLayout, QHBoxLayout, 
    QTabWidget, QLabel, QLineEdit, QPushButton, QTableWidget, 
    QTableWidgetItem, QTextEdit, QComboBox, QSpinBox, QDoubleSpinBox,
    QCheckBox, QGroupBox, QFormLayout, QGridLayout, QScrollArea,
    QProgressBar, QSlider, QDateEdit, QTimeEdit, QListWidget,
    QListWidgetItem, QSplitter, QFrame, QMessageBox, QDialog,
    QDialogButtonBox, QTreeWidget, QTreeWidgetItem, QHeaderView
)
from PyQt6.QtCore import (
    Qt, QTimer, QThread, pyqtSignal, QDate, QTime, QDateTime,
    QPropertyAnimation, QEasingCurve, QRect
)
from PyQt6.QtGui import (
    QFont, QPixmap, QPainter, QPen, QBrush, QColor, QLinearGradient,
    QIcon, QPalette, QAction
)
from PyQt6.QtCharts import (
    QChart, QChartView, QLineSeries, QBarSeries, QBarSet,
    QValueAxis, QDateTimeAxis, QPieSeries, QAreaSeries
)

# Data Models
@dataclass
class Client:
    id: int
    name: str
    email: str
    company: str
    projects_count: int
    total_revenue: float
    satisfaction_score: float
    last_contact: str
    status: str
    notes: str

@dataclass
class Project:
    id: int
    title: str
    client_id: int
    platform: str
    budget: float
    deadline: str
    status: str
    progress: int
    description: str
    proposal_sent: bool
    won: bool

@dataclass
class Proposal:
    id: int
    project_id: int
    content: str
    sent_date: str
    response_received: bool
    success: bool
    bid_amount: float

class DatabaseManager:
    """Handles all database operations"""
    
    def __init__(self, db_path: str = "freelance_platform.db"):
        self.db_path = db_path
        self.init_database()
    
    def init_database(self):
        """Initialize database with required tables"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        # Clients table
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS clients (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                name TEXT NOT NULL,
                email TEXT,
                company TEXT,
                projects_count INTEGER DEFAULT 0,
                total_revenue REAL DEFAULT 0,
                satisfaction_score REAL DEFAULT 5.0,
                last_contact TEXT,
                status TEXT DEFAULT 'active',
                notes TEXT
            )
        ''')
        
        # Projects table
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS projects (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                title TEXT NOT NULL,
                client_id INTEGER,
                platform TEXT,
                budget REAL,
                deadline TEXT,
                status TEXT DEFAULT 'pending',
                progress INTEGER DEFAULT 0,
                description TEXT,
                proposal_sent BOOLEAN DEFAULT 0,
                won BOOLEAN DEFAULT 0,
                FOREIGN KEY (client_id) REFERENCES clients (id)
            )
        ''')
        
        # Proposals table
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS proposals (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                project_id INTEGER,
                content TEXT,
                sent_date TEXT,
                response_received BOOLEAN DEFAULT 0,
                success BOOLEAN DEFAULT 0,
                bid_amount REAL,
                FOREIGN KEY (project_id) REFERENCES projects (id)
            )
        ''')
        
        # Time tracking table
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS time_entries (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                project_id INTEGER,
                date TEXT,
                hours REAL,
                description TEXT,
                FOREIGN KEY (project_id) REFERENCES projects (id)
            )
        ''')
        
        # Invoices table
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS invoices (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                client_id INTEGER,
                project_id INTEGER,
                amount REAL,
                date_sent TEXT,
                due_date TEXT,
                paid BOOLEAN DEFAULT 0,
                FOREIGN KEY (client_id) REFERENCES clients (id),
                FOREIGN KEY (project_id) REFERENCES projects (id)
            )
        ''')
        
        conn.commit()
        conn.close()
        
        # Add sample data if tables are empty
        self.add_sample_data()
    
    def add_sample_data(self):
        """Add sample data for demonstration"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        # Check if data exists
        cursor.execute("SELECT COUNT(*) FROM clients")
        if cursor.fetchone()[0] == 0:
            # Sample clients
            clients = [
                ("TechCorp Inc", "john@techcorp.com", "TechCorp", 3, 15000, 4.8, "2025-07-25", "active", "Great client, pays on time"),
                ("StartupXYZ", "mary@startupxyz.com", "StartupXYZ", 2, 8500, 4.5, "2025-07-20", "active", "Growing company, potential for more work"),
                ("Digital Agency", "sarah@digitalagency.com", "Digital Agency", 1, 3000, 4.2, "2025-07-15", "prospect", "New client, first project"),
                ("E-commerce Co", "mike@ecommerce.com", "E-commerce Co", 4, 22000, 4.9, "2025-07-28", "active", "Long-term partner"),
            ]
            
            for client in clients:
                cursor.execute('''
                    INSERT INTO clients (name, email, company, projects_count, total_revenue, 
                                       satisfaction_score, last_contact, status, notes)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                ''', client)
            
            # Sample projects
            projects = [
                ("E-commerce Website Development", 1, "Upwork", 5000, "2025-08-15", "in_progress", 75, "Full stack e-commerce solution", True, True),
                ("Mobile App UI/UX Design", 2, "Fiverr", 2500, "2025-08-10", "in_progress", 50, "Modern mobile app design", True, True),
                ("Data Analysis Dashboard", 3, "Freelancer", 3000, "2025-08-20", "pending", 25, "Python dashboard with charts", True, False),
                ("WordPress Plugin Development", 4, "Upwork", 1800, "2025-08-05", "completed", 100, "Custom WordPress plugin", True, True),
                ("API Integration Project", 1, "Upwork", 4200, "2025-08-25", "proposal", 0, "REST API integration", True, False),
            ]
            
            for project in projects:
                cursor.execute('''
                    INSERT INTO projects (title, client_id, platform, budget, deadline, status, 
                                        progress, description, proposal_sent, won)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                ''', project)
        
        conn.commit()
        conn.close()

class ModernChartWidget(QChartView):
    """Custom chart widget with modern styling"""
    
    def __init__(self, chart_type="line", parent=None):
        super().__init__(parent)
        self.chart_type = chart_type
        self.setup_chart()
    
    def setup_chart(self):
        """Setup chart with modern dark theme"""
        chart = QChart()
        chart.setTheme(QChart.ChartTheme.ChartThemeDark)
        chart.setBackgroundBrush(QBrush(QColor(45, 45, 45)))
        chart.setTitleBrush(QBrush(QColor(255, 255, 255)))
        
        if self.chart_type == "line":
            self.setup_earnings_chart(chart)
        elif self.chart_type == "bar":
            self.setup_projects_chart(chart)
        elif self.chart_type == "pie":
            self.setup_platform_chart(chart)
        
        self.setChart(chart)
        self.setRenderHint(QPainter.RenderHint.Antialiasing)
    
    def setup_earnings_chart(self, chart):
        """Setup earnings trend line chart"""
        series = QLineSeries()
        series.setName("Monthly Earnings")
        
        # Sample data for last 6 months
        months = ["Feb", "Mar", "Apr", "May", "Jun", "Jul"]
        earnings = [3200, 4500, 3800, 5200, 4100, 6800]
        
        for i, earning in enumerate(earnings):
            series.append(i, earning)
        
        chart.addSeries(series)
        chart.setTitle("Earnings Trend (Last 6 Months)")
        
        # Styling
        pen = QPen(QColor(100, 200, 255))
        pen.setWidth(3)
        series.setPen(pen)
    
    def setup_projects_chart(self, chart):
        """Setup projects status bar chart"""
        series = QBarSeries()
        
        completed = QBarSet("Completed")
        in_progress = QBarSet("In Progress")
        pending = QBarSet("Pending")
        
        completed.append([12, 15, 18, 14, 16, 20])
        in_progress.append([3, 4, 2, 5, 3, 4])
        pending.append([2, 3, 4, 2, 3, 2])
        
        series.append(completed)
        series.append(in_progress)
        series.append(pending)
        
        chart.addSeries(series)
        chart.setTitle("Project Status by Month")
    
    def setup_platform_chart(self, chart):
        """Setup platform distribution pie chart"""
        series = QPieSeries()
        
        series.append("Upwork", 45)
        series.append("Fiverr", 30)
        series.append("Freelancer", 15)
        series.append("Direct Clients", 10)
        
        chart.addSeries(series)
        chart.setTitle("Revenue by Platform")

class AutoBiddingWidget(QWidget):
    """Automated bidding configuration and monitoring"""
    
    def __init__(self, parent=None):
        super().__init__(parent)
        self.setup_ui()
    
    def setup_ui(self):
        layout = QVBoxLayout(self)
        
        # Bidding Configuration
        config_group = QGroupBox("Bidding Configuration")
        config_layout = QFormLayout(config_group)
        
        self.enabled_checkbox = QCheckBox("Enable Auto-Bidding")
        self.enabled_checkbox.setChecked(True)
        config_layout.addRow("Status:", self.enabled_checkbox)
        
        self.keywords_edit = QLineEdit("python, web development, data analysis")
        config_layout.addRow("Keywords:", self.keywords_edit)
        
        self.min_budget_spin = QSpinBox()
        self.min_budget_spin.setRange(100, 10000)
        self.min_budget_spin.setValue(500)
        self.min_budget_spin.setSuffix(" $")
        config_layout.addRow("Min Budget:", self.min_budget_spin)
        
        self.max_budget_spin = QSpinBox()
        self.max_budget_spin.setRange(1000, 50000)
        self.max_budget_spin.setValue(5000)
        self.max_budget_spin.setSuffix(" $")
        config_layout.addRow("Max Budget:", self.max_budget_spin)
        
        self.bid_percentage = QSlider(Qt.Orientation.Horizontal)
        self.bid_percentage.setRange(70, 95)
        self.bid_percentage.setValue(85)
        self.bid_percentage_label = QLabel("85%")
        
        bid_layout = QHBoxLayout()
        bid_layout.addWidget(self.bid_percentage)
        bid_layout.addWidget(self.bid_percentage_label)
        config_layout.addRow("Bid Percentage:", bid_layout)
        
        self.bid_percentage.valueChanged.connect(
            lambda v: self.bid_percentage_label.setText(f"{v}%")
        )
        
        layout.addWidget(config_group)
        
        # Platform Selection
        platform_group = QGroupBox("Platforms to Monitor")
        platform_layout = QVBoxLayout(platform_group)
        
        self.upwork_check = QCheckBox("Upwork")
        self.upwork_check.setChecked(True)
        self.fiverr_check = QCheckBox("Fiverr")
        self.fiverr_check.setChecked(True)
        self.freelancer_check = QCheckBox("Freelancer.com")
        self.freelancer_check.setChecked(True)
        
        platform_layout.addWidget(self.upwork_check)
        platform_layout.addWidget(self.fiverr_check)
        platform_layout.addWidget(self.freelancer_check)
        
        layout.addWidget(platform_group)
        
        # Recent Activity
        activity_group = QGroupBox("Recent Bidding Activity")
        activity_layout = QVBoxLayout(activity_group)
        
        self.activity_list = QListWidget()
        self.populate_activity_list()
        activity_layout.addWidget(self.activity_list)
        
        layout.addWidget(activity_group)
        
        # Control Buttons
        button_layout = QHBoxLayout()
        
        self.start_button = QPushButton("Start Auto-Bidding")
        self.start_button.setStyleSheet("""
            QPushButton {
                background-color: #4CAF50;
                color: white;
                border: none;
                padding: 10px;
                border-radius: 5px;
                font-weight: bold;
            }
            QPushButton:hover {
                background-color: #45a049;
            }
        """)
        
        self.stop_button = QPushButton("Stop Auto-Bidding")
        self.stop_button.setStyleSheet("""
            QPushButton {
                background-color: #f44336;
                color: white;
                border: none;
                padding: 10px;
                border-radius: 5px;
                font-weight: bold;
            }
            QPushButton:hover {
                background-color: #da190b;
            }
        """)
        
        button_layout.addWidget(self.start_button)
        button_layout.addWidget(self.stop_button)
        layout.addLayout(button_layout)
    
    def populate_activity_list(self):
        """Populate with sample bidding activity"""
        activities = [
            "🟢 Successfully bid on 'Python Web Scraping Project' - $450",
            "🟡 Proposal sent for 'E-commerce Dashboard' - $2,100",
            "🔴 Bid rejected for 'Mobile App Development' - Budget too low",
            "🟢 Won project: 'Data Analysis Dashboard' - $1,800",
            "🟡 Proposal under review: 'API Integration' - $950",
        ]
        
        for activity in activities:
            item = QListWidgetItem(activity)
            self.activity_list.addItem(item)

class ClientManagementWidget(QWidget):
    """Client relationship management interface"""
    
    def __init__(self, db_manager: DatabaseManager, parent=None):
        super().__init__(parent)
        self.db_manager = db_manager
        self.setup_ui()
        self.load_clients()
    
    def setup_ui(self):
        layout = QHBoxLayout(self)
        
        # Left panel - Client list
        left_panel = QWidget()
        left_layout = QVBoxLayout(left_panel)
        
        # Search and filters
        search_layout = QHBoxLayout()
        self.search_edit = QLineEdit()
        self.search_edit.setPlaceholderText("Search clients...")
        self.add_client_btn = QPushButton("Add Client")
        self.add_client_btn.clicked.connect(self.add_client)
        
        search_layout.addWidget(self.search_edit)
        search_layout.addWidget(self.add_client_btn)
        left_layout.addLayout(search_layout)
        
        # Client table
        self.client_table = QTableWidget()
        self.client_table.setColumnCount(6)
        self.client_table.YOUR_CLIENT_SECRET_HERE([
            "Name", "Company", "Projects", "Revenue", "Score", "Status"
        ])
        self.client_table.horizontalHeader().setStretchLastSection(True)
        self.client_table.selectionModel().selectionChanged.connect(self.on_client_selected)
        
        left_layout.addWidget(self.client_table)
        
        # Right panel - Client details
        right_panel = QWidget()
        right_layout = QVBoxLayout(right_panel)
        
        # Client info form
        info_group = QGroupBox("Client Information")
        info_layout = QFormLayout(info_group)
        
        self.name_edit = QLineEdit()
        self.email_edit = QLineEdit()
        self.company_edit = QLineEdit()
        self.status_combo = QComboBox()
        self.status_combo.addItems(["active", "prospect", "inactive"])
        self.notes_edit = QTextEdit()
        self.notes_edit.setMaximumHeight(100)
        
        info_layout.addRow("Name:", self.name_edit)
        info_layout.addRow("Email:", self.email_edit)
        info_layout.addRow("Company:", self.company_edit)
        info_layout.addRow("Status:", self.status_combo)
        info_layout.addRow("Notes:", self.notes_edit)
        
        right_layout.addWidget(info_group)
        
        # Client statistics
        stats_group = QGroupBox("Client Statistics")
        stats_layout = QGridLayout(stats_group)
        
        self.projects_label = QLabel("Projects: 0")
        self.revenue_label = QLabel("Revenue: $0")
        self.satisfaction_label = QLabel("Satisfaction: 0/5")
        self.last_contact_label = QLabel("Last Contact: Never")
        
        stats_layout.addWidget(self.projects_label, 0, 0)
        stats_layout.addWidget(self.revenue_label, 0, 1)
        stats_layout.addWidget(self.satisfaction_label, 1, 0)
        stats_layout.addWidget(self.last_contact_label, 1, 1)
        
        right_layout.addWidget(stats_group)
        
        # Action buttons
        action_layout = QHBoxLayout()
        self.save_btn = QPushButton("Save Changes")
        self.save_btn.clicked.connect(self.save_client)
        self.contact_btn = QPushButton("Record Contact")
        self.delete_btn = QPushButton("Delete Client")
        
        action_layout.addWidget(self.save_btn)
        action_layout.addWidget(self.contact_btn)
        action_layout.addWidget(self.delete_btn)
        right_layout.addLayout(action_layout)
        
        right_layout.addStretch()
        
        # Add panels to splitter
        splitter = QSplitter()
        splitter.addWidget(left_panel)
        splitter.addWidget(right_panel)
        splitter.setSizes([400, 300])
        
        layout.addWidget(splitter)
    
    def load_clients(self):
        """Load clients from database"""
        conn = sqlite3.connect(self.db_manager.db_path)
        cursor = conn.cursor()
        cursor.execute("SELECT * FROM clients")
        clients = cursor.fetchall()
        conn.close()
        
        self.client_table.setRowCount(len(clients))
        for row, client in enumerate(clients):
            self.client_table.setItem(row, 0, QTableWidgetItem(client[1]))  # name
            self.client_table.setItem(row, 1, QTableWidgetItem(client[3]))  # company
            self.client_table.setItem(row, 2, QTableWidgetItem(str(client[4])))  # projects
            self.client_table.setItem(row, 3, QTableWidgetItem(f"${client[5]:,.0f}"))  # revenue
            self.client_table.setItem(row, 4, QTableWidgetItem(f"{client[6]:.1f}"))  # score
            self.client_table.setItem(row, 5, QTableWidgetItem(client[8]))  # status
    
    def on_client_selected(self):
        """Handle client selection"""
        current_row = self.client_table.currentRow()
        if current_row >= 0:
            # Get client data from database
            conn = sqlite3.connect(self.db_manager.db_path)
            cursor = conn.cursor()
            cursor.execute("SELECT * FROM clients LIMIT 1 OFFSET ?", (current_row,))
            client = cursor.fetchone()
            conn.close()
            
            if client:
                self.name_edit.setText(client[1])
                self.email_edit.setText(client[2] or "")
                self.company_edit.setText(client[3] or "")
                self.status_combo.setCurrentText(client[8])
                self.notes_edit.setText(client[9] or "")
                
                self.projects_label.setText(f"Projects: {client[4]}")
                self.revenue_label.setText(f"Revenue: ${client[5]:,.0f}")
                self.satisfaction_label.setText(f"Satisfaction: {client[6]:.1f}/5")
                self.last_contact_label.setText(f"Last Contact: {client[7]}")
    
    def add_client(self):
        """Add new client"""
        dialog = QDialog(self)
        dialog.setWindowTitle("Add New Client")
        dialog.setModal(True)
        dialog.resize(400, 300)
        
        layout = QFormLayout(dialog)
        
        name_edit = QLineEdit()
        email_edit = QLineEdit()
        company_edit = QLineEdit()
        notes_edit = QTextEdit()
        
        layout.addRow("Name:", name_edit)
        layout.addRow("Email:", email_edit)
        layout.addRow("Company:", company_edit)
        layout.addRow("Notes:", notes_edit)
        
        buttons = QDialogButtonBox(QDialogButtonBox.StandardButton.Ok | QDialogButtonBox.StandardButton.Cancel)
        buttons.accepted.connect(dialog.accept)
        buttons.rejected.connect(dialog.reject)
        layout.addRow(buttons)
        
        if dialog.exec() == QDialog.DialogCode.Accepted:
            # Add to database
            conn = sqlite3.connect(self.db_manager.db_path)
            cursor = conn.cursor()
            cursor.execute('''
                INSERT INTO clients (name, email, company, notes, last_contact)
                VALUES (?, ?, ?, ?, ?)
            ''', (name_edit.text(), email_edit.text(), company_edit.text(), 
                  notes_edit.toPlainText(), datetime.datetime.now().strftime("%Y-%m-%d")))
            conn.commit()
            conn.close()
            
            self.load_clients()
    
    def save_client(self):
        """Save client changes"""
        current_row = self.client_table.currentRow()
        if current_row >= 0:
            # Update database
            conn = sqlite3.connect(self.db_manager.db_path)
            cursor = conn.cursor()
            
            # Get client ID
            cursor.execute("SELECT id FROM clients LIMIT 1 OFFSET ?", (current_row,))
            client_id = cursor.fetchone()[0]
            
            cursor.execute('''
                UPDATE clients SET name=?, email=?, company=?, status=?, notes=?
                WHERE id=?
            ''', (self.name_edit.text(), self.email_edit.text(), self.company_edit.text(),
                  self.status_combo.currentText(), self.notes_edit.toPlainText(), client_id))
            
            conn.commit()
            conn.close()
            
            self.load_clients()
            QMessageBox.information(self, "Success", "Client updated successfully!")

class ProjectTrackingWidget(QWidget):
    """Project management and tracking interface"""
    
    def __init__(self, db_manager: DatabaseManager, parent=None):
        super().__init__(parent)
        self.db_manager = db_manager
        self.setup_ui()
        self.load_projects()
    
    def setup_ui(self):
        layout = QVBoxLayout(self)
        
        # Top toolbar
        toolbar_layout = QHBoxLayout()
        
        self.add_project_btn = QPushButton("Add Project")
        self.add_project_btn.clicked.connect(self.add_project)
        
        self.status_filter = QComboBox()
        self.status_filter.addItems(["All Status", "pending", "in_progress", "completed", "cancelled"])
        self.status_filter.currentTextChanged.connect(self.filter_projects)
        
        self.platform_filter = QComboBox()
        self.platform_filter.addItems(["All Platforms", "Upwork", "Fiverr", "Freelancer", "Direct"])
        self.platform_filter.currentTextChanged.connect(self.filter_projects)
        
        toolbar_layout.addWidget(self.add_project_btn)
        toolbar_layout.addStretch()
        toolbar_layout.addWidget(QLabel("Status:"))
        toolbar_layout.addWidget(self.status_filter)
        toolbar_layout.addWidget(QLabel("Platform:"))
        toolbar_layout.addWidget(self.platform_filter)
        
        layout.addLayout(toolbar_layout)
        
        # Projects table
        self.project_table = QTableWidget()
        self.project_table.setColumnCount(8)
        self.project_table.YOUR_CLIENT_SECRET_HERE([
            "Title", "Client", "Platform", "Budget", "Deadline", "Status", "Progress", "Actions"
        ])
        
        header = self.project_table.horizontalHeader()
        header.setStretchLastSection(True)
        
        self.project_table.cellDoubleClicked.connect(self.edit_project)
        
        layout.addWidget(self.project_table)
    
    def load_projects(self):
        """Load projects from database"""
        conn = sqlite3.connect(self.db_manager.db_path)
        cursor = conn.cursor()
        cursor.execute('''
            SELECT p.*, c.name as client_name 
            FROM projects p 
            LEFT JOIN clients c ON p.client_id = c.id
            ORDER BY p.deadline
        ''')
        projects = cursor.fetchall()
        conn.close()
        
        self.project_table.setRowCount(len(projects))
        for row, project in enumerate(projects):
            self.project_table.setItem(row, 0, QTableWidgetItem(project[1]))  # title
            self.project_table.setItem(row, 1, QTableWidgetItem(project[11] or "No Client"))  # client
            self.project_table.setItem(row, 2, QTableWidgetItem(project[3]))  # platform
            self.project_table.setItem(row, 3, QTableWidgetItem(f"${project[4]:,.0f}"))  # budget
            self.project_table.setItem(row, 4, QTableWidgetItem(project[5]))  # deadline
            self.project_table.setItem(row, 5, QTableWidgetItem(project[6]))  # status
            
            # Progress bar
            progress_widget = QProgressBar()
            progress_widget.setValue(project[7])
            progress_widget.setStyleSheet("""
                QProgressBar {
                    border: 1px solid grey;
                    border-radius: 5px;
                    text-align: center;
                }
                QProgressBar::chunk {
                    background-color: #4CAF50;
                    border-radius: 3px;
                }
            """)
            self.project_table.setCellWidget(row, 6, progress_widget)
            
            # Action buttons
            action_widget = QWidget()
            action_layout = QHBoxLayout(action_widget)
            action_layout.setContentsMargins(0, 0, 0, 0)
            
            edit_btn = QPushButton("Edit")
            edit_btn.setMaximumWidth(50)
            edit_btn.clicked.connect(lambda checked, r=row: self.edit_project(r, 0))
            
            delete_btn = QPushButton("Del")
            delete_btn.setMaximumWidth(40)
            delete_btn.setStyleSheet("background-color: #f44336; color: white;")
            
            action_layout.addWidget(edit_btn)
            action_layout.addWidget(delete_btn)
            
            self.project_table.setCellWidget(row, 7, action_widget)
    
    def filter_projects(self):
        """Filter projects based on status and platform"""
        status_filter = self.status_filter.currentText()
        platform_filter = self.platform_filter.currentText()
        
        for row in range(self.project_table.rowCount()):
            show_row = True
            
            if status_filter != "All Status":
                status_item = self.project_table.item(row, 5)
                if status_item and status_item.text() != status_filter:
                    show_row = False
            
            if platform_filter != "All Platforms":
                platform_item = self.project_table.item(row, 2)
                if platform_item and platform_item.text() != platform_filter:
                    show_row = False
            
            self.project_table.setRowHidden(row, not show_row)
    
    def add_project(self):
        """Add new project dialog"""
        dialog = ProjectDialog(self.db_manager, parent=self)
        if dialog.exec() == QDialog.DialogCode.Accepted:
            self.load_projects()
    
    def edit_project(self, row, column):
        """Edit project dialog"""
        # Get project ID from database
        conn = sqlite3.connect(self.db_manager.db_path)
        cursor = conn.cursor()
        cursor.execute("SELECT * FROM projects LIMIT 1 OFFSET ?", (row,))
        project = cursor.fetchone()
        conn.close()
        
        if project:
            dialog = ProjectDialog(self.db_manager, project_data=project, parent=self)
            if dialog.exec() == QDialog.DialogCode.Accepted:
                self.load_projects()

class ProjectDialog(QDialog):
    """Dialog for adding/editing projects"""
    
    def __init__(self, db_manager: DatabaseManager, project_data=None, parent=None):
        super().__init__(parent)
        self.db_manager = db_manager
        self.project_data = project_data
        self.setWindowTitle("Add Project" if not project_data else "Edit Project")
        self.setModal(True)
        self.resize(500, 400)
        self.setup_ui()
        
        if project_data:
            self.populate_form()
    
    def setup_ui(self):
        layout = QFormLayout(self)
        
        self.title_edit = QLineEdit()
        self.client_combo = QComboBox()
        self.platform_combo = QComboBox()
        self.platform_combo.addItems(["Upwork", "Fiverr", "Freelancer", "Direct"])
        self.budget_spin = QDoubleSpinBox()
        self.budget_spin.setRange(0, 100000)
        self.budget_spin.setPrefix("$")
        
        self.deadline_edit = QDateEdit()
        self.deadline_edit.setDate(QDate.currentDate().addDays(30))
        
        self.status_combo = QComboBox()
        self.status_combo.addItems(["pending", "in_progress", "completed", "cancelled"])
        
        self.progress_spin = QSpinBox()
        self.progress_spin.setRange(0, 100)
        self.progress_spin.setSuffix("%")
        
        self.description_edit = QTextEdit()
        self.description_edit.setMaximumHeight(100)
        
        # Load clients for combo box
        self.load_clients()
        
        layout.addRow("Title:", self.title_edit)
        layout.addRow("Client:", self.client_combo)
        layout.addRow("Platform:", self.platform_combo)
        layout.addRow("Budget:", self.budget_spin)
        layout.addRow("Deadline:", self.deadline_edit)
        layout.addRow("Status:", self.status_combo)
        layout.addRow("Progress:", self.progress_spin)
        layout.addRow("Description:", self.description_edit)
        
        buttons = QDialogButtonBox(QDialogButtonBox.StandardButton.Ok | QDialogButtonBox.StandardButton.Cancel)
        buttons.accepted.connect(self.save_project)
        buttons.rejected.connect(self.reject)
        layout.addRow(buttons)
    
    def load_clients(self):
        """Load clients for combo box"""
        conn = sqlite3.connect(self.db_manager.db_path)
        cursor = conn.cursor()
        cursor.execute("SELECT id, name FROM clients")
        clients = cursor.fetchall()
        conn.close()
        
        self.client_combo.addItem("No Client", 0)
        for client_id, name in clients:
            self.client_combo.addItem(name, client_id)
    
    def populate_form(self):
        """Populate form with project data"""
        if self.project_data:
            self.title_edit.setText(self.project_data[1])
            
            # Set client
            for i in range(self.client_combo.count()):
                if self.client_combo.itemData(i) == self.project_data[2]:
                    self.client_combo.setCurrentIndex(i)
                    break
            
            self.platform_combo.setCurrentText(self.project_data[3])
            self.budget_spin.setValue(self.project_data[4])
            
            deadline = QDate.fromString(self.project_data[5], "yyyy-MM-dd")
            self.deadline_edit.setDate(deadline)
            
            self.status_combo.setCurrentText(self.project_data[6])
            self.progress_spin.setValue(self.project_data[7])
            self.description_edit.setText(self.project_data[8])
    
    def save_project(self):
        """Save project to database"""
        conn = sqlite3.connect(self.db_manager.db_path)
        cursor = conn.cursor()
        
        client_id = self.client_combo.currentData()
        if client_id == 0:
            client_id = None
        
        if self.project_data:
            # Update existing project
            cursor.execute('''
                UPDATE projects SET title=?, client_id=?, platform=?, budget=?, 
                                  deadline=?, status=?, progress=?, description=?
                WHERE id=?
            ''', (
                self.title_edit.text(),
                client_id,
                self.platform_combo.currentText(),
                self.budget_spin.value(),
                self.deadline_edit.date().toString("yyyy-MM-dd"),
                self.status_combo.currentText(),
                self.progress_spin.value(),
                self.description_edit.toPlainText(),
                self.project_data[0]
            ))
        else:
            # Insert new project
            cursor.execute('''
                INSERT INTO projects (title, client_id, platform, budget, deadline, 
                                    status, progress, description)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            ''', (
                self.title_edit.text(),
                client_id,
                self.platform_combo.currentText(),
                self.budget_spin.value(),
                self.deadline_edit.date().toString("yyyy-MM-dd"),
                self.status_combo.currentText(),
                self.progress_spin.value(),
                self.description_edit.toPlainText()
            ))
        
        conn.commit()
        conn.close()
        self.accept()

class AnalyticsWidget(QWidget):
    """Analytics and reporting dashboard"""
    
    def __init__(self, db_manager: DatabaseManager, parent=None):
        super().__init__(parent)
        self.db_manager = db_manager
        self.setup_ui()
    
    def setup_ui(self):
        layout = QVBoxLayout(self)
        
        # KPI Cards
        kpi_layout = QHBoxLayout()
        
        # Total Revenue Card
        revenue_card = self.create_kpi_card("Total Revenue", "$48,500", "+12%", "#4CAF50")
        kpi_layout.addWidget(revenue_card)
        
        # Active Projects Card
        projects_card = self.create_kpi_card("Active Projects", "8", "+2", "#2196F3")
        kpi_layout.addWidget(projects_card)
        
        # Win Rate Card
        winrate_card = self.create_kpi_card("Win Rate", "73%", "+5%", "#FF9800")
        kpi_layout.addWidget(winrate_card)
        
        # Avg Project Value Card
        avgvalue_card = self.create_kpi_card("Avg Project", "$3,200", "+8%", "#9C27B0")
        kpi_layout.addWidget(avgvalue_card)
        
        layout.addLayout(kpi_layout)
        
        # Charts Section
        charts_layout = QHBoxLayout()
        
        # Earnings Chart
        earnings_chart = ModernChartWidget("line")
        charts_layout.addWidget(earnings_chart)
        
        # Platform Distribution Chart
        platform_chart = ModernChartWidget("pie")
        charts_layout.addWidget(platform_chart)
        
        layout.addLayout(charts_layout)
        
        # Projects Chart
        projects_chart = ModernChartWidget("bar")
        layout.addWidget(projects_chart)
    
    def create_kpi_card(self, title: str, value: str, change: str, color: str) -> QGroupBox:
        """Create a KPI card widget"""
        card = QGroupBox()
        card.setStyleSheet(f"""
            QGroupBox {{
                border: 2px solid {color};
                border-radius: 10px;
                margin: 5px;
                padding: 10px;
                background-color: rgba(45, 45, 45, 0.9);
            }}
        """)
        
        layout = QVBoxLayout(card)
        
        title_label = QLabel(title)
        title_label.setStyleSheet("color: #888; font-size: 12px;")
        
        value_label = QLabel(value)
        value_label.setStyleSheet(f"color: {color}; font-size: 24px; font-weight: bold;")
        
        change_label = QLabel(change)
        change_color = "#4CAF50" if change.startswith("+") else "#f44336"
        change_label.setStyleSheet(f"color: {change_color}; font-size: 14px;")
        
        layout.addWidget(title_label)
        layout.addWidget(value_label)
        layout.addWidget(change_label)
        
        return card

class TimeTrackingWidget(QWidget):
    """Time tracking with productivity monitoring"""
    
    def __init__(self, db_manager: DatabaseManager, parent=None):
        super().__init__(parent)
        self.db_manager = db_manager
        self.is_tracking = False
        self.current_project = None
        self.start_time = None
        self.timer = QTimer()
        self.timer.timeout.connect(self.update_timer)
        self.setup_ui()
    
    def setup_ui(self):
        layout = QVBoxLayout(self)
        
        # Current Session
        session_group = QGroupBox("Current Session")
        session_layout = QVBoxLayout(session_group)
        
        # Project selection
        project_layout = QHBoxLayout()
        project_layout.addWidget(QLabel("Project:"))
        
        self.project_combo = QComboBox()
        self.load_projects()
        project_layout.addWidget(self.project_combo)
        
        session_layout.addLayout(project_layout)
        
        # Timer display
        self.timer_display = QLabel("00:00:00")
        self.timer_display.setStyleSheet("""
            QLabel {
                font-size: 48px;
                font-weight: bold;
                color: #4CAF50;
                text-align: center;
                padding: 20px;
                border: 2px solid #4CAF50;
                border-radius: 10px;
                background-color: rgba(76, 175, 80, 0.1);
            }
        """)
        self.timer_display.setAlignment(Qt.AlignmentFlag.AlignCenter)
        session_layout.addWidget(self.timer_display)
        
        # Control buttons
        control_layout = QHBoxLayout()
        
        self.start_btn = QPushButton("Start")
        self.start_btn.clicked.connect(self.start_tracking)
        self.start_btn.setStyleSheet("""
            QPushButton {
                background-color: #4CAF50;
                color: white;
                border: none;
                padding: 15px 30px;
                border-radius: 8px;
                font-size: 16px;
                font-weight: bold;
            }
            QPushButton:hover {
                background-color: #45a049;
            }
        """)
        
        self.stop_btn = QPushButton("Stop")
        self.stop_btn.clicked.connect(self.stop_tracking)
        self.stop_btn.setEnabled(False)
        self.stop_btn.setStyleSheet("""
            QPushButton {
                background-color: #f44336;
                color: white;
                border: none;
                padding: 15px 30px;
                border-radius: 8px;
                font-size: 16px;
                font-weight: bold;
            }
            QPushButton:hover {
                background-color: #da190b;
            }
            QPushButton:disabled {
                background-color: #666;
            }
        """)
        
        control_layout.addWidget(self.start_btn)
        control_layout.addWidget(self.stop_btn)
        session_layout.addLayout(control_layout)
        
        # Description
        self.description_edit = QLineEdit()
        self.description_edit.setPlaceholderText("What are you working on?")
        session_layout.addWidget(self.description_edit)
        
        layout.addWidget(session_group)
        
        # Today's Summary
        summary_group = QGroupBox("Today's Summary")
        summary_layout = QHBoxLayout(summary_group)
        
        self.total_hours_label = QLabel("Total Hours: 0.0")
        self.total_hours_label.setStyleSheet("font-size: 16px; font-weight: bold;")
        
        self.projects_worked_label = QLabel("Projects: 0")
        self.projects_worked_label.setStyleSheet("font-size: 16px; font-weight: bold;")
        
        summary_layout.addWidget(self.total_hours_label)
        summary_layout.addWidget(self.projects_worked_label)
        
        layout.addWidget(summary_group)
        
        # Recent Entries
        entries_group = QGroupBox("Recent Time Entries")
        entries_layout = QVBoxLayout(entries_group)
        
        self.entries_table = QTableWidget()
        self.entries_table.setColumnCount(4)
        self.entries_table.YOUR_CLIENT_SECRET_HERE(["Date", "Project", "Hours", "Description"])
        self.entries_table.horizontalHeader().setStretchLastSection(True)
        
        entries_layout.addWidget(self.entries_table)
        layout.addWidget(entries_group)
        
        self.load_time_entries()
    
    def load_projects(self):
        """Load projects for time tracking"""
        conn = sqlite3.connect(self.db_manager.db_path)
        cursor = conn.cursor()
        cursor.execute("SELECT id, title FROM projects WHERE status != 'completed'")
        projects = cursor.fetchall()
        conn.close()
        
        for project_id, title in projects:
            self.project_combo.addItem(title, project_id)
    
    def start_tracking(self):
        """Start time tracking"""
        if self.project_combo.currentData():
            self.is_tracking = True
            self.current_project = self.project_combo.currentData()
            self.start_time = datetime.datetime.now()
            self.timer.start(1000)  # Update every second
            
            self.start_btn.setEnabled(False)
            self.stop_btn.setEnabled(True)
            self.project_combo.setEnabled(False)
    
    def stop_tracking(self):
        """Stop time tracking and save entry"""
        if self.is_tracking:
            self.is_tracking = False
            self.timer.stop()
            
            # Calculate hours
            end_time = datetime.datetime.now()
            duration = end_time - self.start_time
            hours = duration.total_seconds() / 3600
            
            # Save to database
            conn = sqlite3.connect(self.db_manager.db_path)
            cursor = conn.cursor()
            cursor.execute('''
                INSERT INTO time_entries (project_id, date, hours, description)
                VALUES (?, ?, ?, ?)
            ''', (
                self.current_project,
                datetime.date.today().isoformat(),
                hours,
                self.description_edit.text()
            ))
            conn.commit()
            conn.close()
            
            # Reset UI
            self.start_btn.setEnabled(True)
            self.stop_btn.setEnabled(False)
            self.project_combo.setEnabled(True)
            self.timer_display.setText("00:00:00")
            self.description_edit.clear()
            
            self.load_time_entries()
            
            QMessageBox.information(self, "Time Saved", f"Logged {hours:.2f} hours")
    
    def update_timer(self):
        """Update timer display"""
        if self.is_tracking and self.start_time:
            duration = datetime.datetime.now() - self.start_time
            total_seconds = int(duration.total_seconds())
            
            hours = total_seconds // 3600
            minutes = (total_seconds % 3600) // 60
            seconds = total_seconds % 60
            
            self.timer_display.setText(f"{hours:02d}:{minutes:02d}:{seconds:02d}")
    
    def load_time_entries(self):
        """Load recent time entries"""
        conn = sqlite3.connect(self.db_manager.db_path)
        cursor = conn.cursor()
        cursor.execute('''
            SELECT te.date, p.title, te.hours, te.description
            FROM time_entries te
            JOIN projects p ON te.project_id = p.id
            ORDER BY te.date DESC
            LIMIT 10
        ''')
        entries = cursor.fetchall()
        conn.close()
        
        self.entries_table.setRowCount(len(entries))
        for row, entry in enumerate(entries):
            self.entries_table.setItem(row, 0, QTableWidgetItem(entry[0]))
            self.entries_table.setItem(row, 1, QTableWidgetItem(entry[1]))
            self.entries_table.setItem(row, 2, QTableWidgetItem(f"{entry[2]:.2f}"))
            self.entries_table.setItem(row, 3, QTableWidgetItem(entry[3] or ""))

class InvoiceManagementWidget(QWidget):
    """Invoice generation and payment tracking"""
    
    def __init__(self, db_manager: DatabaseManager, parent=None):
        super().__init__(parent)
        self.db_manager = db_manager
        self.setup_ui()
        self.load_invoices()
    
    def setup_ui(self):
        layout = QVBoxLayout(self)
        
        # Toolbar
        toolbar_layout = QHBoxLayout()
        
        self.create_invoice_btn = QPushButton("Create Invoice")
        self.create_invoice_btn.clicked.connect(self.create_invoice)
        
        self.send_reminders_btn = QPushButton("Send Reminders")
        
        toolbar_layout.addWidget(self.create_invoice_btn)
        toolbar_layout.addWidget(self.send_reminders_btn)
        toolbar_layout.addStretch()
        
        layout.addLayout(toolbar_layout)
        
        # Invoice table
        self.invoice_table = QTableWidget()
        self.invoice_table.setColumnCount(7)
        self.invoice_table.YOUR_CLIENT_SECRET_HERE([
            "Invoice #", "Client", "Project", "Amount", "Date Sent", "Due Date", "Status"
        ])
        self.invoice_table.horizontalHeader().setStretchLastSection(True)
        
        layout.addWidget(self.invoice_table)
        
        # Payment summary
        summary_group = QGroupBox("Payment Summary")
        summary_layout = QHBoxLayout(summary_group)
        
        self.total_outstanding_label = QLabel("Outstanding: $0")
        self.total_paid_label = QLabel("Paid This Month: $0")
        self.overdue_label = QLabel("Overdue: $0")
        
        summary_layout.addWidget(self.total_outstanding_label)
        summary_layout.addWidget(self.total_paid_label)
        summary_layout.addWidget(self.overdue_label)
        
        layout.addWidget(summary_group)
    
    def load_invoices(self):
        """Load invoices from database"""
        conn = sqlite3.connect(self.db_manager.db_path)
        cursor = conn.cursor()
        cursor.execute('''
            SELECT i.*, c.name as client_name, p.title as project_title
            FROM invoices i
            LEFT JOIN clients c ON i.client_id = c.id
            LEFT JOIN projects p ON i.project_id = p.id
            ORDER BY i.date_sent DESC
        ''')
        invoices = cursor.fetchall()
        conn.close()
        
        self.invoice_table.setRowCount(len(invoices))
        for row, invoice in enumerate(invoices):
            self.invoice_table.setItem(row, 0, QTableWidgetItem(f"INV-{invoice[0]:04d}"))
            self.invoice_table.setItem(row, 1, QTableWidgetItem(invoice[7] or "Unknown"))
            self.invoice_table.setItem(row, 2, QTableWidgetItem(invoice[8] or "Unknown"))
            self.invoice_table.setItem(row, 3, QTableWidgetItem(f"${invoice[3]:,.2f}"))
            self.invoice_table.setItem(row, 4, QTableWidgetItem(invoice[4]))
            self.invoice_table.setItem(row, 5, QTableWidgetItem(invoice[5]))
            
            status = "Paid" if invoice[6] else "Unpaid"
            status_item = QTableWidgetItem(status)
            if status == "Paid":
                status_item.setForeground(QColor("#4CAF50"))
            else:
                # Check if overdue
                due_date = datetime.datetime.strptime(invoice[5], "%Y-%m-%d").date()
                if due_date < datetime.date.today():
                    status_item.setForeground(QColor("#f44336"))
                    status = "Overdue"
                    status_item.setText(status)
                else:
                    status_item.setForeground(QColor("#FF9800"))
            
            self.invoice_table.setItem(row, 6, status_item)
    
    def create_invoice(self):
        """Create new invoice dialog"""
        dialog = InvoiceDialog(self.db_manager, parent=self)
        if dialog.exec() == QDialog.DialogCode.Accepted:
            self.load_invoices()

class InvoiceDialog(QDialog):
    """Dialog for creating invoices"""
    
    def __init__(self, db_manager: DatabaseManager, parent=None):
        super().__init__(parent)
        self.db_manager = db_manager
        self.setWindowTitle("Create Invoice")
        self.setModal(True)
        self.resize(400, 300)
        self.setup_ui()
    
    def setup_ui(self):
        layout = QFormLayout(self)
        
        self.client_combo = QComboBox()
        self.project_combo = QComboBox()
        self.amount_spin = QDoubleSpinBox()
        self.amount_spin.setRange(0, 100000)
        self.amount_spin.setPrefix("$")
        
        self.due_date_edit = QDateEdit()
        self.due_date_edit.setDate(QDate.currentDate().addDays(30))
        
        # Load clients and projects
        self.load_clients()
        self.client_combo.currentTextChanged.connect(self.YOUR_CLIENT_SECRET_HERE)
        
        layout.addRow("Client:", self.client_combo)
        layout.addRow("Project:", self.project_combo)
        layout.addRow("Amount:", self.amount_spin)
        layout.addRow("Due Date:", self.due_date_edit)
        
        buttons = QDialogButtonBox(QDialogButtonBox.StandardButton.Ok | QDialogButtonBox.StandardButton.Cancel)
        buttons.accepted.connect(self.create_invoice)
        buttons.rejected.connect(self.reject)
        layout.addRow(buttons)
    
    def load_clients(self):
        """Load clients for combo box"""
        conn = sqlite3.connect(self.db_manager.db_path)
        cursor = conn.cursor()
        cursor.execute("SELECT id, name FROM clients")
        clients = cursor.fetchall()
        conn.close()
        
        for client_id, name in clients:
            self.client_combo.addItem(name, client_id)
        
        if clients:
            self.YOUR_CLIENT_SECRET_HERE()
    
    def YOUR_CLIENT_SECRET_HERE(self):
        """Load projects for selected client"""
        self.project_combo.clear()
        
        client_id = self.client_combo.currentData()
        if client_id:
            conn = sqlite3.connect(self.db_manager.db_path)
            cursor = conn.cursor()
            cursor.execute("SELECT id, title FROM projects WHERE client_id = ?", (client_id,))
            projects = cursor.fetchall()
            conn.close()
            
            for project_id, title in projects:
                self.project_combo.addItem(title, project_id)
    
    def create_invoice(self):
        """Create the invoice"""
        conn = sqlite3.connect(self.db_manager.db_path)
        cursor = conn.cursor()
        
        cursor.execute('''
            INSERT INTO invoices (client_id, project_id, amount, date_sent, due_date)
            VALUES (?, ?, ?, ?, ?)
        ''', (
            self.client_combo.currentData(),
            self.project_combo.currentData(),
            self.amount_spin.value(),
            datetime.date.today().isoformat(),
            self.due_date_edit.date().toString("yyyy-MM-dd")
        ))
        
        conn.commit()
        conn.close()
        
        self.accept()

class FreelancePlatform(QMainWindow):
    """Main application window"""
    
    def __init__(self):
        super().__init__()
        self.db_manager = DatabaseManager()
        self.setup_ui()
        self.apply_dark_theme()
    
    def setup_ui(self):
        """Setup the main user interface"""
        self.setWindowTitle("Freelance Automation Platform - Professional CRM")
        self.setGeometry(100, 100, 1400, 900)
        
        # Central widget with tab system
        central_widget = QTabWidget()
        self.setCentralWidget(central_widget)
        
        # Dashboard tab
        dashboard_widget = self.create_dashboard()
        central_widget.addTab(dashboard_widget, "🏠 Dashboard")
        
        # Auto-bidding tab
        auto_bidding_widget = AutoBiddingWidget()
        central_widget.addTab(auto_bidding_widget, "🤖 Auto-Bidding")
        
        # Client management tab
        YOUR_CLIENT_SECRET_HERE = ClientManagementWidget(self.db_manager)
        central_widget.addTab(YOUR_CLIENT_SECRET_HERE, "👥 Clients")
        
        # Project tracking tab
        project_tracking_widget = ProjectTrackingWidget(self.db_manager)
        central_widget.addTab(project_tracking_widget, "📋 Projects")
        
        # Time tracking tab
        time_tracking_widget = TimeTrackingWidget(self.db_manager)
        central_widget.addTab(time_tracking_widget, "⏰ Time Tracking")
        
        # Invoice management tab
        invoice_widget = InvoiceManagementWidget(self.db_manager)
        central_widget.addTab(invoice_widget, "💰 Invoices")
        
        # Analytics tab
        analytics_widget = AnalyticsWidget(self.db_manager)
        central_widget.addTab(analytics_widget, "📊 Analytics")
        
        # Create menu bar
        self.create_menu_bar()
        
        # Create status bar
        self.statusBar().showMessage("Ready - Freelance Platform Loaded")
    
    def create_dashboard(self) -> QWidget:
        """Create the main dashboard"""
        dashboard = QWidget()
        layout = QVBoxLayout(dashboard)
        
        # Welcome section
        welcome_label = QLabel("Welcome to Your Freelance Command Center")
        welcome_label.setStyleSheet("""
            QLabel {
                font-size: 24px;
                font-weight: bold;
                color: #4CAF50;
                padding: 20px;
                text-align: center;
            }
        """)
        welcome_label.setAlignment(Qt.AlignmentFlag.AlignCenter)
        layout.addWidget(welcome_label)
        
        # Quick stats
        stats_layout = QHBoxLayout()
        
        # Quick action buttons
        actions_group = QGroupBox("Quick Actions")
        actions_layout = QVBoxLayout(actions_group)
        
        new_project_btn = QPushButton("🆕 New Project")
        new_project_btn.setStyleSheet(self.get_button_style("#4CAF50"))
        
        new_client_btn = QPushButton("👤 New Client")
        new_client_btn.setStyleSheet(self.get_button_style("#2196F3"))
        
        time_track_btn = QPushButton("⏱️ Start Timer")
        time_track_btn.setStyleSheet(self.get_button_style("#FF9800"))
        
        create_invoice_btn = QPushButton("💸 Create Invoice")
        create_invoice_btn.setStyleSheet(self.get_button_style("#9C27B0"))
        
        actions_layout.addWidget(new_project_btn)
        actions_layout.addWidget(new_client_btn)
        actions_layout.addWidget(time_track_btn)
        actions_layout.addWidget(create_invoice_btn)
        
        stats_layout.addWidget(actions_group)
        
        # Recent activity
        activity_group = QGroupBox("Recent Activity")
        activity_layout = QVBoxLayout(activity_group)
        
        activity_list = QListWidget()
        recent_activities = [
            "✅ Completed project: E-commerce Website",
            "📧 New proposal sent for Mobile App Design",
            "💰 Invoice paid: $3,500 from TechCorp",
            "⏰ Logged 4.5 hours on Data Dashboard",
            "🎯 Auto-bidding won new project: API Integration",
        ]
        
        for activity in recent_activities:
            activity_list.addItem(activity)
        
        activity_layout.addWidget(activity_list)
        stats_layout.addWidget(activity_group)
        
        layout.addLayout(stats_layout)
        
        # Charts section
        charts_layout = QHBoxLayout()
        
        earnings_chart = ModernChartWidget("line")
        charts_layout.addWidget(earnings_chart)
        
        platform_chart = ModernChartWidget("pie")
        charts_layout.addWidget(platform_chart)
        
        layout.addLayout(charts_layout)
        
        return dashboard
    
    def create_menu_bar(self):
        """Create application menu bar"""
        menubar = self.menuBar()
        
        # File menu
        file_menu = menubar.addMenu('File')
        
        backup_action = QAction('Backup Data', self)
        backup_action.triggered.connect(self.backup_data)
        file_menu.addAction(backup_action)
        
        restore_action = QAction('Restore Data', self)
        file_menu.addAction(restore_action)
        
        file_menu.addSeparator()
        
        exit_action = QAction('Exit', self)
        exit_action.triggered.connect(self.close)
        file_menu.addAction(exit_action)
        
        # Tools menu
        tools_menu = menubar.addMenu('Tools')
        
        settings_action = QAction('Settings', self)
        tools_menu.addAction(settings_action)
        
        preferences_action = QAction('Preferences', self)
        tools_menu.addAction(preferences_action)
        
        # Help menu
        help_menu = menubar.addMenu('Help')
        
        about_action = QAction('About', self)
        about_action.triggered.connect(self.show_about)
        help_menu.addAction(about_action)
    
    def get_button_style(self, color: str) -> str:
        """Get consistent button styling"""
        return f"""
            QPushButton {{
                background-color: {color};
                color: white;
                border: none;
                padding: 15px 20px;
                border-radius: 8px;
                font-size: 14px;
                font-weight: bold;
                margin: 5px;
            }}
            QPushButton:hover {{
                background-color: {color}dd;
            }}
            QPushButton:pressed {{
                background-color: {color}aa;
            }}
        """
    
    def apply_dark_theme(self):
        """Apply professional dark theme"""
        self.setStyleSheet("""
            QMainWindow {
                background-color: #2b2b2b;
                color: #ffffff;
            }
            
            QTabWidget::pane {
                border: 1px solid #3d3d3d;
                background-color: #2b2b2b;
            }
            
            QTabBar::tab {
                background-color: #3d3d3d;
                color: #ffffff;
                padding: 10px 20px;
                margin-right: 2px;
                border-top-left-radius: 8px;
                border-top-right-radius: 8px;
            }
            
            QTabBar::tab:selected {
                background-color: #4CAF50;
            }
            
            QTabBar::tab:hover {
                background-color: #4d4d4d;
            }
            
            QGroupBox {
                font-weight: bold;
                border: 2px solid #4d4d4d;
                border-radius: 8px;
                margin: 10px 0;
                padding-top: 10px;
                background-color: #353535;
            }
            
            QGroupBox::title {
                subcontrol-origin: margin;
                left: 10px;
                padding: 0 5px 0 5px;
                color: #4CAF50;
            }
            
            QTableWidget {
                background-color: #353535;
                YOUR_CLIENT_SECRET_HERE: #3d3d3d;
                YOUR_CLIENT_SECRET_HERE: #4CAF50;
                gridline-color: #4d4d4d;
                border: 1px solid #4d4d4d;
                border-radius: 5px;
            }
            
            QTableWidget::item {
                padding: 8px;
            }
            
            QHeaderView::section {
                background-color: #4d4d4d;
                color: #ffffff;
                padding: 10px;
                border: none;
                font-weight: bold;
            }
            
            QLineEdit, QTextEdit, QComboBox, QSpinBox, QDoubleSpinBox, QDateEdit {
                background-color: #3d3d3d;
                border: 2px solid #4d4d4d;
                border-radius: 5px;
                padding: 8px;
                color: #ffffff;
            }
            
            QLineEdit:focus, QTextEdit:focus, QComboBox:focus {
                border-color: #4CAF50;
            }
            
            QPushButton {
                background-color: #4d4d4d;
                color: #ffffff;
                border: none;
                padding: 10px 20px;
                border-radius: 5px;
                font-weight: bold;
            }
            
            QPushButton:hover {
                background-color: #5d5d5d;
            }
            
            QPushButton:pressed {
                background-color: #3d3d3d;
            }
            
            QListWidget {
                background-color: #353535;
                border: 1px solid #4d4d4d;
                border-radius: 5px;
            }
            
            QListWidget::item {
                padding: 8px;
                border-bottom: 1px solid #4d4d4d;
            }
            
            QListWidget::item:selected {
                background-color: #4CAF50;
            }
            
            QScrollBar:vertical {
                background-color: #3d3d3d;
                width: 15px;
                border-radius: 7px;
            }
            
            QScrollBar::handle:vertical {
                background-color: #5d5d5d;
                border-radius: 7px;
                min-height: 20px;
            }
            
            QScrollBar::handle:vertical:hover {
                background-color: #6d6d6d;
            }
        """)
    
    def backup_data(self):
        """Backup application data"""
        backup_path = f"backup_{datetime.date.today().isoformat()}.db"
        try:
            import shutil
            shutil.copy(self.db_manager.db_path, backup_path)
            QMessageBox.information(self, "Backup Complete", f"Data backed up to {backup_path}")
        except Exception as e:
            QMessageBox.warning(self, "Backup Failed", f"Failed to backup data: {str(e)}")
    
    def show_about(self):
        """Show about dialog"""
        QMessageBox.about(self, "About Freelance Platform", 
                         "Freelance Automation Platform v1.0\n\n"
                         "Professional CRM-style interface with automated bidding,\n"
                         "client management, and project tracking.\n\n"
                         "Features:\n"
                         "• Intelligent project scanning\n"
                         "• Automated proposal generation\n"
                         "• Client relationship management\n"
                         "• Time tracking with productivity reports\n"
                         "• Invoice generation and payment tracking\n"
                         "• Advanced analytics and reporting")

def main():
    """Main application entry point"""
    app = QApplication(sys.argv)
    app.setApplicationName("Freelance Automation Platform")
    app.setApplicationVersion("1.0")
    app.setOrganizationName("FreelancePro")
    
    # Create and show main window
    window = FreelancePlatform()
    window.show()
    
    sys.exit(app.exec())

if __name__ == "__main__":
    main()
