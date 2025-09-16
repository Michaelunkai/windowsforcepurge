#!/usr/bin/env python3
"""
Enhanced System Performance Monitoring Dashboard with Process Ranking
Optimized for WSL2 on Windows 11 with detailed process resource usage.
"""

import os
import sys
import json
import sqlite3
import logging
import threading
import time
import signal
import platform
import subprocess
from datetime import datetime, timedelta
from pathlib import Path
from typing import Dict, List, Optional, Tuple
import argparse

# Auto-install dependencies
def install_dependencies():
    """Install required Python packages."""
    required_packages = [
        'flask', 'flask-cors', 'psutil', 'plotly', 'pandas'
    ]
    
    print("Installing required packages...")
    for package in required_packages:
        try:
            __import__(package.replace('-', '_'))
        except ImportError:
            print(f"Installing {package}...")
            try:
                import subprocess
                subprocess.check_call([sys.executable, '-m', 'pip', 'install', package])
            except Exception as e:
                print(f"Failed to install {package}: {e}")
                print(f"Please install manually: pip install {package}")

# Install dependencies first
install_dependencies()

import psutil
import pandas as pd
import plotly.graph_objs as go
import plotly.utils
from flask import Flask, render_template_string, jsonify, request
from flask_cors import CORS

def detect_wsl2():
    """Detect if running in WSL2."""
    try:
        if platform.system() == 'Linux':
            with open('/proc/version', 'r') as f:
                version_info = f.read().lower()
                return 'microsoft' in version_info and 'wsl2' in version_info
    except:
        pass
    return False

class Config:
    """Configuration management for the monitoring system."""
    
    def __init__(self, config_path: str = None):
        self.is_wsl2 = detect_wsl2()
        
        if config_path is None:
            if self.is_wsl2:
                # WSL2 specific paths that work well with Windows 11
                config_dir = '/mnt/c/ProgramData/SysMonitor'
                self.config_path = os.path.join(config_dir, 'config.json')
            elif platform.system() == 'Windows':
                config_dir = os.path.join(os.environ.get('PROGRAMDATA', 'C:\\ProgramData'), 'SysMonitor')
                self.config_path = os.path.join(config_dir, 'config.json')
            else:
                self.config_path = '/etc/sysmonitor/config.json'
        else:
            self.config_path = config_path
            
        self.config = self.load_config()
    
    def get_default_config(self):
        """Get default configuration based on platform."""
        if self.is_wsl2:
            db_path = '/mnt/c/ProgramData/SysMonitor/monitoring.db'
            log_path = '/mnt/c/ProgramData/SysMonitor/sysmonitor.log'
        elif platform.system() == 'Windows':
            db_path = os.path.join(os.environ.get('PROGRAMDATA', 'C:\\ProgramData'), 'SysMonitor', 'monitoring.db')
            log_path = os.path.join(os.environ.get('PROGRAMDATA', 'C:\\ProgramData'), 'SysMonitor', 'sysmonitor.log')
        else:
            db_path = '/var/lib/sysmonitor/monitoring.db'
            log_path = '/var/log/sysmonitor.log'
            
        return {
            'database': {
                'path': db_path,
                'retention_days': 30
            },
            'web': {
                'host': '0.0.0.0',
                'port': 8080,
                'debug': False
            },
            'monitoring': {
                'interval_seconds': 5,
                'cpu_threshold': 80,
                'memory_threshold': 85,
                'disk_threshold': 90,
                'network_threshold_mbps': 100,
                'process_count': 10,  # Top N processes to track
                'track_processes': True
            },
            'email': {
                'enabled': False,
                'smtp_server': 'smtp.gmail.com',
                'smtp_port': 587,
                'username': '',
                'password': '',
                'from_email': '',
                'to_emails': [],
                'alert_cooldown_minutes': 30
            },
            'logging': {
                'level': 'INFO',
                'file': log_path,
                'max_size_mb': 100,
                'backup_count': 5
            },
            'wsl2': {
                'enabled': self.is_wsl2,
                'windows_host_access': True,
                'YOUR_CLIENT_SECRET_HERE': ['eth0', 'wlan0']
            }
        }
    
    def load_config(self) -> dict:
        """Load configuration from file or create default."""
        try:
            if os.path.exists(self.config_path):
                with open(self.config_path, 'r') as f:
                    config = json.load(f)
                # Merge with defaults
                return self._merge_config(self.get_default_config(), config)
            else:
                return self.get_default_config()
        except Exception as e:
            print(f"Error loading config: {e}. Using defaults.")
            return self.get_default_config()
    
    def _merge_config(self, default: dict, user: dict) -> dict:
        """Recursively merge user config with defaults."""
        result = default.copy()
        for key, value in user.items():
            if key in result and isinstance(result[key], dict) and isinstance(value, dict):
                result[key] = self._merge_config(result[key], value)
            else:
                result[key] = value
        return result
    
    def save_config(self):
        """Save current configuration to file."""
        try:
            os.makedirs(os.path.dirname(self.config_path), exist_ok=True)
            with open(self.config_path, 'w') as f:
                json.dump(self.config, f, indent=2)
        except Exception as e:
            print(f"Error saving config: {e}")
    
    def get(self, key_path: str, default=None):
        """Get configuration value using dot notation."""
        keys = key_path.split('.')
        value = self.config
        for key in keys:
            if isinstance(value, dict) and key in value:
                value = value[key]
            else:
                return default
        return value

class DatabaseManager:
    """SQLite database manager for storing monitoring data."""
    
    def __init__(self, db_path: str):
        self.db_path = db_path
        self.init_database()
    
    def init_database(self):
        """Initialize database tables."""
        os.makedirs(os.path.dirname(self.db_path), exist_ok=True)
        
        with sqlite3.connect(self.db_path) as conn:
            # System metrics table
            conn.execute('''
                CREATE TABLE IF NOT EXISTS system_metrics (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
                    cpu_percent REAL,
                    memory_percent REAL,
                    memory_used_gb REAL,
                    memory_total_gb REAL,
                    disk_percent REAL,
                    disk_used_gb REAL,
                    disk_total_gb REAL,
                    network_bytes_sent INTEGER,
                    network_bytes_recv INTEGER,
                    load_avg_1 REAL,
                    load_avg_5 REAL,
                    load_avg_15 REAL
                )
            ''')
            
            # Process metrics table
            conn.execute('''
                CREATE TABLE IF NOT EXISTS process_metrics (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
                    pid INTEGER,
                    name TEXT,
                    cpu_percent REAL,
                    memory_percent REAL,
                    memory_mb REAL,
                    read_bytes INTEGER,
                    write_bytes INTEGER,
                    status TEXT,
                    num_threads INTEGER
                )
            ''')
            
            # Alerts table
            conn.execute('''
                CREATE TABLE IF NOT EXISTS alerts (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
                    alert_type TEXT,
                    message TEXT,
                    value REAL,
                    threshold REAL
                )
            ''')
            
            # Create indexes
            conn.execute('CREATE INDEX IF NOT EXISTS idx_metrics_timestamp ON system_metrics(timestamp)')
            conn.execute('CREATE INDEX IF NOT EXISTS idx_process_timestamp ON process_metrics(timestamp)')
            conn.execute('CREATE INDEX IF NOT EXISTS idx_process_name ON process_metrics(name)')
    
    def insert_metrics(self, metrics: dict):
        """Insert system metrics into database."""
        with sqlite3.connect(self.db_path) as conn:
            conn.execute('''
                INSERT INTO system_metrics 
                (cpu_percent, memory_percent, memory_used_gb, memory_total_gb,
                 disk_percent, disk_used_gb, disk_total_gb, network_bytes_sent,
                 network_bytes_recv, load_avg_1, load_avg_5, load_avg_15)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ''', (
                metrics['cpu_percent'], metrics['memory_percent'],
                metrics['memory_used_gb'], metrics['memory_total_gb'],
                metrics['disk_percent'], metrics['disk_used_gb'],
                metrics['disk_total_gb'], metrics['network_bytes_sent'],
                metrics['network_bytes_recv'], metrics['load_avg_1'],
                metrics['load_avg_5'], metrics['load_avg_15']
            ))
    
    def insert_process_metrics(self, processes: List[dict]):
        """Insert process metrics into database."""
        with sqlite3.connect(self.db_path) as conn:
            for proc in processes:
                conn.execute('''
                    INSERT INTO process_metrics 
                    (pid, name, cpu_percent, memory_percent, memory_mb, 
                     read_bytes, write_bytes, status, num_threads)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                ''', (
                    proc['pid'], proc['name'], proc['cpu_percent'],
                    proc['memory_percent'], proc['memory_mb'],
                    proc['read_bytes'], proc['write_bytes'],
                    proc['status'], proc['num_threads']
                ))
    
    def insert_alert(self, alert_type: str, message: str, value: float, threshold: float):
        """Insert alert into database."""
        with sqlite3.connect(self.db_path) as conn:
            conn.execute('''
                INSERT INTO alerts (alert_type, message, value, threshold)
                VALUES (?, ?, ?, ?)
            ''', (alert_type, message, value, threshold))
    
    def get_recent_metrics(self, hours: int = 24) -> List[dict]:
        """Get metrics from the last N hours."""
        with sqlite3.connect(self.db_path) as conn:
            conn.row_factory = sqlite3.Row
            cursor = conn.execute('''
                SELECT * FROM system_metrics 
                WHERE timestamp > datetime('now', '-{} hours')
                ORDER BY timestamp
            '''.format(hours))
            return [dict(row) for row in cursor.fetchall()]
    
    def YOUR_CLIENT_SECRET_HERE(self, hours: int = 1) -> List[dict]:
        """Get recent process metrics."""
        with sqlite3.connect(self.db_path) as conn:
            conn.row_factory = sqlite3.Row
            cursor = conn.execute('''
                SELECT * FROM process_metrics 
                WHERE timestamp > datetime('now', '-{} hours')
                ORDER BY timestamp DESC, cpu_percent DESC
                LIMIT 100
            '''.format(hours))
            return [dict(row) for row in cursor.fetchall()]
    
    def cleanup_old_data(self, retention_days: int):
        """Remove old data beyond retention period."""
        with sqlite3.connect(self.db_path) as conn:
            conn.execute('''
                DELETE FROM system_metrics 
                WHERE timestamp < datetime('now', '-{} days')
            '''.format(retention_days))
            conn.execute('''
                DELETE FROM process_metrics 
                WHERE timestamp < datetime('now', '-{} days')
            '''.format(retention_days))
            conn.execute('''
                DELETE FROM alerts 
                WHERE timestamp < datetime('now', '-{} days')
            '''.format(retention_days))

class ProcessMonitor:
    """Monitor individual processes and their resource usage."""
    
    def __init__(self, is_wsl2: bool = False):
        self.is_wsl2 = is_wsl2
    
    def get_top_processes(self, limit: int = 10) -> Tuple[List[dict], List[dict], List[dict]]:
        """Get top processes by CPU, memory, and I/O usage."""
        processes = []
        
        for proc in psutil.process_iter(['pid', 'name', 'cpu_percent', 'memory_percent', 
                                       'memory_info', 'status', 'num_threads']):
            try:
                pinfo = proc.info
                
                # Get I/O stats if available
                try:
                    io_counters = proc.io_counters()
                    read_bytes = io_counters.read_bytes
                    write_bytes = io_counters.write_bytes
                except (psutil.NoSuchProcess, psutil.AccessDenied, AttributeError):
                    read_bytes = 0
                    write_bytes = 0
                
                memory_mb = pinfo['memory_info'].rss / 1024 / 1024 if pinfo['memory_info'] else 0
                
                processes.append({
                    'pid': pinfo['pid'],
                    'name': pinfo['name'] or 'Unknown',
                    'cpu_percent': pinfo['cpu_percent'] or 0,
                    'memory_percent': pinfo['memory_percent'] or 0,
                    'memory_mb': round(memory_mb, 2),
                    'read_bytes': read_bytes,
                    'write_bytes': write_bytes,
                    'total_bytes': read_bytes + write_bytes,
                    'status': pinfo['status'] or 'unknown',
                    'num_threads': pinfo['num_threads'] or 0
                })
            except (psutil.NoSuchProcess, psutil.AccessDenied, psutil.ZombieProcess):
                continue
        
        # Sort by different criteria
        cpu_top = sorted(processes, key=lambda x: x['cpu_percent'], reverse=True)[:limit]
        memory_top = sorted(processes, key=lambda x: x['memory_mb'], reverse=True)[:limit]
        io_top = sorted(processes, key=lambda x: x['total_bytes'], reverse=True)[:limit]
        
        return cpu_top, memory_top, io_top
    
    def get_network_processes(self) -> List[dict]:
        """Get processes with network connections."""
        network_procs = []
        connections = psutil.net_connections()
        
        pid_connections = {}
        for conn in connections:
            if conn.pid:
                if conn.pid not in pid_connections:
                    pid_connections[conn.pid] = 0
                pid_connections[conn.pid] += 1
        
        for pid, conn_count in pid_connections.items():
            try:
                proc = psutil.Process(pid)
                network_procs.append({
                    'pid': pid,
                    'name': proc.name(),
                    'connections': conn_count,
                    'cpu_percent': proc.cpu_percent(),
                    'memory_mb': proc.memory_info().rss / 1024 / 1024
                })
            except (psutil.NoSuchProcess, psutil.AccessDenied):
                continue
        
        return sorted(network_procs, key=lambda x: x['connections'], reverse=True)[:10]

class SystemMonitor:
    """Core system monitoring functionality."""
    
    def __init__(self, is_wsl2: bool = False):
        self.last_network_stats = psutil.net_io_counters()
        self.last_time = time.time()
        self.is_wsl2 = is_wsl2
        self.process_monitor = ProcessMonitor(is_wsl2)
    
    def get_load_average(self):
        """Get system load average (cross-platform)."""
        try:
            if hasattr(os, 'getloadavg'):
                return os.getloadavg()
            else:
                # For Windows/WSL2, use CPU count as approximation
                cpu_count = psutil.cpu_count()
                cpu_percent = psutil.cpu_percent()
                load_approx = (cpu_percent / 100.0) * cpu_count
                return (load_approx, load_approx, load_approx)
        except:
            return (0, 0, 0)
    
    def get_disk_usage(self):
        """Get disk usage with WSL2 optimization."""
        if self.is_wsl2:
            # In WSL2, also check Windows drives
            disks = []
            # Linux root
            try:
                disk = psutil.disk_usage('/')
                disks.append({
                    'path': '/',
                    'percent': disk.percent,
                    'used_gb': disk.used / (1024**3),
                    'total_gb': disk.total / (1024**3)
                })
            except:
                pass
            
            # Windows C: drive
            try:
                disk = psutil.disk_usage('/mnt/c')
                disks.append({
                    'path': '/mnt/c (Windows)',
                    'percent': disk.percent,
                    'used_gb': disk.used / (1024**3),
                    'total_gb': disk.total / (1024**3)
                })
            except:
                pass
            
            # Return the highest usage for alerting
            if disks:
                primary_disk = max(disks, key=lambda x: x['percent'])
                primary_disk['all_disks'] = disks
                return primary_disk
        
        # Standard disk usage
        disk_path = 'C:\\' if platform.system() == 'Windows' else '/'
        disk = psutil.disk_usage(disk_path)
        return {
            'path': disk_path,
            'percent': disk.percent,
            'used_gb': disk.used / (1024**3),
            'total_gb': disk.total / (1024**3),
            'all_disks': [{'path': disk_path, 'percent': disk.percent, 
                          'used_gb': disk.used / (1024**3), 'total_gb': disk.total / (1024**3)}]
        }
    
    def get_current_metrics(self) -> dict:
        """Get current system metrics."""
        # CPU
        cpu_percent = psutil.cpu_percent(interval=1)
        
        # Memory
        memory = psutil.virtual_memory()
        memory_percent = memory.percent
        memory_used_gb = memory.used / (1024**3)
        memory_total_gb = memory.total / (1024**3)
        
        # Disk
        disk_info = self.get_disk_usage()
        
        # Network
        current_network_stats = psutil.net_io_counters()
        current_time = time.time()
        
        time_delta = current_time - self.last_time
        if time_delta > 0:
            bytes_sent_per_sec = (current_network_stats.bytes_sent - self.last_network_stats.bytes_sent) / time_delta
            bytes_recv_per_sec = (current_network_stats.bytes_recv - self.last_network_stats.bytes_recv) / time_delta
        else:
            bytes_sent_per_sec = 0
            bytes_recv_per_sec = 0
        
        self.last_network_stats = current_network_stats
        self.last_time = current_time
        
        # Load average
        load_avg = self.get_load_average()
        
        # Process information
        cpu_top, memory_top, io_top = self.process_monitor.get_top_processes()
        network_procs = self.process_monitor.get_network_processes()
        
        return {
            'timestamp': datetime.now().isoformat(),
            'cpu_percent': cpu_percent,
            'memory_percent': memory_percent,
            'memory_used_gb': round(memory_used_gb, 2),
            'memory_total_gb': round(memory_total_gb, 2),
            'disk_percent': disk_info['percent'],
            'disk_used_gb': round(disk_info['used_gb'], 2),
            'disk_total_gb': round(disk_info['total_gb'], 2),
            'disk_info': disk_info,
            'network_bytes_sent': current_network_stats.bytes_sent,
            'network_bytes_recv': current_network_stats.bytes_recv,
            'network_sent_per_sec': bytes_sent_per_sec,
            'network_recv_per_sec': bytes_recv_per_sec,
            'load_avg_1': load_avg[0],
            'load_avg_5': load_avg[1],
            'load_avg_15': load_avg[2],
            'processes': {
                'cpu_top': cpu_top,
                'memory_top': memory_top,
                'io_top': io_top,
                'network_top': network_procs
            }
        }

class AlertManager:
    """Handle system alerts and notifications."""
    
    def __init__(self, config: Config, db: DatabaseManager):
        self.config = config
        self.db = db
        self.last_alerts = {}
    
    def check_thresholds(self, metrics: dict):
        """Check if any metrics exceed thresholds."""
        alerts = []
        
        # CPU check
        cpu_threshold = self.config.get('monitoring.cpu_threshold')
        if metrics['cpu_percent'] > cpu_threshold:
            alerts.append({
                'type': 'cpu',
                'message': f"High CPU usage: {metrics['cpu_percent']:.1f}%",
                'value': metrics['cpu_percent'],
                'threshold': cpu_threshold
            })
        
        # Memory check
        memory_threshold = self.config.get('monitoring.memory_threshold')
        if metrics['memory_percent'] > memory_threshold:
            alerts.append({
                'type': 'memory',
                'message': f"High memory usage: {metrics['memory_percent']:.1f}%",
                'value': metrics['memory_percent'],
                'threshold': memory_threshold
            })
        
        # Disk check
        disk_threshold = self.config.get('monitoring.disk_threshold')
        if metrics['disk_percent'] > disk_threshold:
            alerts.append({
                'type': 'disk',
                'message': f"High disk usage: {metrics['disk_percent']:.1f}%",
                'value': metrics['disk_percent'],
                'threshold': disk_threshold
            })
        
        # Process-specific alerts
        for proc in metrics['processes']['cpu_top'][:3]:
            if proc['cpu_percent'] > 50:  # Individual process using >50% CPU
                alerts.append({
                    'type': 'process_cpu',
                    'message': f"Process {proc['name']} (PID {proc['pid']}) high CPU: {proc['cpu_percent']:.1f}%",
                    'value': proc['cpu_percent'],
                    'threshold': 50
                })
        
        # Process alerts
        for alert in alerts:
            self.process_alert(alert)
    
    def process_alert(self, alert: dict):
        """Process an alert (save to DB, send email)."""
        alert_key = f"{alert['type']}_{alert.get('message', '')[:50]}"
        cooldown_minutes = self.config.get('email.alert_cooldown_minutes', 30)
        
        # Check cooldown
        if alert_key in self.last_alerts:
            last_alert_time = self.last_alerts[alert_key]
            if datetime.now() - last_alert_time < timedelta(minutes=cooldown_minutes):
                return
        
        # Save to database
        self.db.insert_alert(
            alert['type'], alert['message'], 
            alert['value'], alert['threshold']
        )
        
        # Send email
        if self.config.get('email.enabled'):
            self.send_email_alert(alert)
        
        self.last_alerts[alert_key] = datetime.now()
        logging.warning(f"ALERT: {alert['message']}")
    
    def send_email_alert(self, alert: dict):
        """Send email alert."""
        try:
            import smtplib
            from email.mime.text import MIMEText
            from email.mime.multipart import MIMEMultipart
            
            smtp_server = self.config.get('email.smtp_server')
            smtp_port = self.config.get('email.smtp_port')
            username = self.config.get('email.username')
            password = self.config.get('email.password')
            from_email = self.config.get('email.from_email')
            to_emails = self.config.get('email.to_emails')
            
            if not all([smtp_server, username, password, from_email, to_emails]):
                logging.error("Email configuration incomplete")
                return
            
            msg = MIMEMultipart()
            msg['From'] = from_email
            msg['To'] = ', '.join(to_emails)
            msg['Subject'] = f"System Alert: {alert['type'].upper()}"
            
            body = f"""
System Alert Generated

Alert Type: {alert['type'].upper()}
Message: {alert['message']}
Current Value: {alert['value']:.1f}
Threshold: {alert['threshold']:.1f}
Timestamp: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}

Please check your system immediately.
            """
            
            msg.attach(MIMEText(body, 'plain'))
            
            server = smtplib.SMTP(smtp_server, smtp_port)
            server.starttls()
            server.login(username, password)
            server.send_message(msg)
            server.quit()
            
            logging.info(f"Alert email sent for {alert['type']}")
            
        except Exception as e:
            logging.error(f"Failed to send email alert: {e}")

class MonitoringDashboard:
    """Web dashboard and REST API."""
    
    def __init__(self, config: Config, db: DatabaseManager, monitor: SystemMonitor):
        self.config = config
        self.db = db
        self.monitor = monitor
        self.app = Flask(__name__)
        CORS(self.app)
        self.setup_routes()
    
    def setup_routes(self):
        """Setup Flask routes."""
        
        @self.app.route('/')
        def dashboard():
            return render_template_string(self.get_dashboard_template())
        
        @self.app.route('/api/metrics/current')
        def current_metrics():
            """Get current system metrics."""
            try:
                metrics = self.monitor.get_current_metrics()
                return jsonify(metrics)
            except Exception as e:
                return jsonify({'error': str(e)}), 500
        
        @self.app.route('/api/metrics/history')
        def metrics_history():
            """Get historical metrics."""
            try:
                hours = request.args.get('hours', 24, type=int)
                metrics = self.db.get_recent_metrics(hours)
                return jsonify(metrics)
            except Exception as e:
                return jsonify({'error': str(e)}), 500
        
        @self.app.route('/api/processes/current')
        def current_processes():
            """Get current process information."""
            try:
                cpu_top, memory_top, io_top = self.monitor.process_monitor.get_top_processes()
                network_procs = self.monitor.process_monitor.get_network_processes()
                return jsonify({
                    'cpu_top': cpu_top,
                    'memory_top': memory_top,
                    'io_top': io_top,
                    'network_top': network_procs
                })
            except Exception as e:
                return jsonify({'error': str(e)}), 500
        
        @self.app.route('/api/processes/history')
        def process_history():
            """Get historical process metrics."""
            try:
                hours = request.args.get('hours', 1, type=int)
                processes = self.db.YOUR_CLIENT_SECRET_HERE(hours)
                return jsonify(processes)
            except Exception as e:
                return jsonify({'error': str(e)}), 500
        
        @self.app.route('/api/health')
        def health_check():
            """Health check endpoint."""
            return jsonify({
                'status': 'healthy',
                'timestamp': datetime.now().isoformat(),
                'platform': platform.system(),
                'wsl2': self.config.get('wsl2.enabled', False)
            })
    
    def get_dashboard_template(self):
        """Return the HTML template for the dashboard."""
        return '''
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Enhanced System Performance Monitor</title>
    <script src="https://cdn.plot.ly/plotly-latest.min.js"></script>
    <style>
        body { 
            font-family: Arial, sans-serif; 
            margin: 0; 
            padding: 20px; 
            background-color: #f5f5f5; 
        }
        .header { 
            text-align: center; 
            margin-bottom: 30px; 
            color: #333; 
        }
        .metrics-grid { 
            display: grid; 
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr)); 
            gap: 20px; 
            margin-bottom: 30px; 
        }
        .metric-card { 
            background: white; 
            padding: 20px; 
            border-radius: 8px; 
            box-shadow: 0 2px 4px rgba(0,0,0,0.1); 
            text-align: center; 
        }
        .metric-value { 
            font-size: 2em; 
            font-weight: bold; 
            margin: 10px 0; 
        }
        .metric-label { 
            color: #666; 
            font-size: 0.9em; 
        }
        .charts-container { 
            display: grid; 
            grid-template-columns: 1fr 1fr; 
            gap: 20px; 
            margin-bottom: 30px;
        }
        .chart-card { 
            background: white; 
            padding: 20px; 
            border-radius: 8px; 
            box-shadow: 0 2px 4px rgba(0,0,0,0.1); 
        }
        .process-container {
            display: grid;
            grid-template-columns: 1fr 1fr;
            gap: 20px;
            margin-bottom: 30px;
        }
        .process-card {
            background: white;
            padding: 20px;
            border-radius: 8px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        .process-table {
            width: 100%;
            border-collapse: collapse;
            margin-top: 10px;
        }
        .process-table th, .process-table td {
            padding: 8px;
            text-align: left;
            border-bottom: 1px solid #ddd;
            font-size: 0.9em;
        }
        .process-table th {
            background-color: #f8f9fa;
            font-weight: bold;
        }
        .process-table tr:hover {
            background-color: #f5f5f5;
        }
        .status-indicator { 
            display: inline-block; 
            width: 10px; 
            height: 10px; 
            border-radius: 50%; 
            margin-left: 10px; 
        }
        .status-normal { background-color: #4CAF50; }
        .status-warning { background-color: #FF9800; }
        .status-critical { background-color: #F44336; }
        .disk-info {
            font-size: 0.8em;
            color: #666;
            margin-top: 5px;
        }
        @media (max-width: 768px) {
            .charts-container, .process-container { 
                grid-template-columns: 1fr; 
            }
        }
    </style>
</head>
<body>
    <div class="header">
        <h1>Enhanced System Performance Monitor</h1>
        <p>Real-time monitoring with process ranking - <span id="platform-info"></span></p>
    </div>
    
    <div class="metrics-grid">
        <div class="metric-card">
            <div class="metric-label">CPU Usage</div>
            <div class="metric-value" id="cpu-value">-</div>
            <span class="status-indicator" id="cpu-status"></span>
        </div>
        <div class="metric-card">
            <div class="metric-label">Memory Usage</div>
            <div class="metric-value" id="memory-value">-</div>
            <span class="status-indicator" id="memory-status"></span>
        </div>
        <div class="metric-card">
            <div class="metric-label">Disk Usage</div>
            <div class="metric-value" id="disk-value">-</div>
            <div class="disk-info" id="disk-info">-</div>
            <span class="status-indicator" id="disk-status"></span>
        </div>
        <div class="metric-card">
            <div class="metric-label">Load Average</div>
            <div class="metric-value" id="load-value">-</div>
            <span class="status-indicator" id="load-status"></span>
        </div>
    </div>
    
    <div class="charts-container">
        <div class="chart-card">
            <div id="cpu-chart"></div>
        </div>
        <div class="chart-card">
            <div id="memory-chart"></div>
        </div>
        <div class="chart-card">
            <div id="disk-chart"></div>
        </div>
        <div class="chart-card">
            <div id="network-chart"></div>
        </div>
    </div>

    <div class="process-container">
        <div class="process-card">
            <h3>🔥 Top CPU Processes</h3>
            <table class="process-table" id="cpu-processes">
                <thead>
                    <tr>
                        <th>Process</th>
                        <th>PID</th>
                        <th>CPU %</th>
                        <th>Memory MB</th>
                    </tr>
                </thead>
                <tbody></tbody>
            </table>
        </div>
        
        <div class="process-card">
            <h3>🧠 Top Memory Processes</h3>
            <table class="process-table" id="memory-processes">
                <thead>
                    <tr>
                        <th>Process</th>
                        <th>PID</th>
                        <th>Memory MB</th>
                        <th>Memory %</th>
                    </tr>
                </thead>
                <tbody></tbody>
            </table>
        </div>
        
        <div class="process-card">
            <h3>💾 Top I/O Processes</h3>
            <table class="process-table" id="io-processes">
                <thead>
                    <tr>
                        <th>Process</th>
                        <th>PID</th>
                        <th>Read/Write GB</th>
                        <th>CPU %</th>
                    </tr>
                </thead>
                <tbody></tbody>
            </table>
        </div>
        
        <div class="process-card">
            <h3>🌐 Top Network Processes</h3>
            <table class="process-table" id="network-processes">
                <thead>
                    <tr>
                        <th>Process</th>
                        <th>PID</th>
                        <th>Connections</th>
                        <th>CPU %</th>
                    </tr>
                </thead>
                <tbody></tbody>
            </table>
        </div>
    </div>

    <script>
        let historyData = [];
        
        function updateMetrics() {
            fetch('/api/metrics/current')
                .then(response => response.json())
                .then(data => {
                    // Update metric cards
                    document.getElementById('cpu-value').textContent = data.cpu_percent.toFixed(1) + '%';
                    document.getElementById('memory-value').textContent = data.memory_percent.toFixed(1) + '%';
                    document.getElementById('disk-value').textContent = data.disk_percent.toFixed(1) + '%';
                    document.getElementById('load-value').textContent = data.load_avg_1.toFixed(2);
                    
                    // Update disk info
                    if (data.disk_info && data.disk_info.all_disks) {
                        let diskInfo = data.disk_info.all_disks.map(d => 
                            `${d.path}: ${d.percent.toFixed(1)}%`
                        ).join(' | ');
                        document.getElementById('disk-info').textContent = diskInfo;
                    }
                    
                    // Update status indicators
                    updateStatusIndicator('cpu-status', data.cpu_percent, 80);
                    updateStatusIndicator('memory-status', data.memory_percent, 85);
                    updateStatusIndicator('disk-status', data.disk_percent, 90);
                    updateStatusIndicator('load-status', data.load_avg_1, 2);
                    
                    // Update process tables
                    updateProcessTable('cpu-processes', data.processes.cpu_top, 'cpu');
                    updateProcessTable('memory-processes', data.processes.memory_top, 'memory');
                    updateProcessTable('io-processes', data.processes.io_top, 'io');
                    updateProcessTable('network-processes', data.processes.network_top, 'network');
                    
                    // Add to history
                    historyData.push(data);
                    if (historyData.length > 100) {
                        historyData.shift();
                    }
                    
                    updateCharts();
                })
                .catch(error => console.error('Error fetching metrics:', error));
        }
        
        function updateProcessTable(tableId, processes, type) {
            const tbody = document.querySelector(`#${tableId} tbody`);
            tbody.innerHTML = '';
            
            processes.forEach(proc => {
                const row = tbody.insertRow();
                row.insertCell().textContent = proc.name;
                row.insertCell().textContent = proc.pid;
                
                if (type === 'cpu') {
                    row.insertCell().textContent = proc.cpu_percent.toFixed(1) + '%';
                    row.insertCell().textContent = proc.memory_mb.toFixed(1);
                } else if (type === 'memory') {
                    row.insertCell().textContent = proc.memory_mb.toFixed(1);
                    row.insertCell().textContent = proc.memory_percent.toFixed(1) + '%';
                } else if (type === 'io') {
                    row.insertCell().textContent = (proc.total_bytes / 1024 / 1024 / 1024).toFixed(2);
                    row.insertCell().textContent = proc.cpu_percent.toFixed(1) + '%';
                } else if (type === 'network') {
                    row.insertCell().textContent = proc.connections;
                    row.insertCell().textContent = proc.cpu_percent.toFixed(1) + '%';
                }
            });
        }
        
        function updateStatusIndicator(elementId, value, threshold) {
            const element = document.getElementById(elementId);
            element.className = 'status-indicator ';
            if (value < threshold * 0.7) {
                element.className += 'status-normal';
            } else if (value < threshold) {
                element.className += 'status-warning';
            } else {
                element.className += 'status-critical';
            }
        }
        
        function updateCharts() {
            if (historyData.length < 2) return;
            
            const timestamps = historyData.map(d => new Date(d.timestamp));
            
            // CPU Chart
            Plotly.newPlot('cpu-chart', [{
                x: timestamps,
                y: historyData.map(d => d.cpu_percent),
                type: 'scatter',
                mode: 'lines',
                name: 'CPU %',
                line: { color: '#2196F3' }
            }], {
                title: 'CPU Usage Over Time',
                xaxis: { title: 'Time' },
                yaxis: { title: 'Percentage', range: [0, 100] }
            }, { responsive: true });
            
            // Memory Chart
            Plotly.newPlot('memory-chart', [{
                x: timestamps,
                y: historyData.map(d => d.memory_percent),
                type: 'scatter',
                mode: 'lines',
                name: 'Memory %',
                line: { color: '#4CAF50' }
            }], {
                title: 'Memory Usage Over Time',
                xaxis: { title: 'Time' },
                yaxis: { title: 'Percentage', range: [0, 100] }
            }, { responsive: true });
            
            // Disk Chart
            Plotly.newPlot('disk-chart', [{
                x: timestamps,
                y: historyData.map(d => d.disk_percent),
                type: 'scatter',
                mode: 'lines',
                name: 'Disk %',
                line: { color: '#FF9800' }
            }], {
                title: 'Disk Usage Over Time',
                xaxis: { title: 'Time' },
                yaxis: { title: 'Percentage', range: [0, 100] }
            }, { responsive: true });
            
            // Network Chart
            Plotly.newPlot('network-chart', [{
                x: timestamps,
                y: historyData.map(d => d.network_sent_per_sec / 1024 / 1024),
                type: 'scatter',
                mode: 'lines',
                name: 'Sent MB/s',
                line: { color: '#9C27B0' }
            }, {
                x: timestamps,
                y: historyData.map(d => d.network_recv_per_sec / 1024 / 1024),
                type: 'scatter',
                mode: 'lines',
                name: 'Received MB/s',
                line: { color: '#E91E63' }
            }], {
                title: 'Network Usage Over Time',
                xaxis: { title: 'Time' },
                yaxis: { title: 'MB/s' }
            }, { responsive: true });
        }
        
        // Check platform info
        fetch('/api/health')
            .then(response => response.json())
            .then(data => {
                let platformText = data.platform;
                if (data.wsl2) {
                    platformText += ' (WSL2 Optimized)';
                }
                document.getElementById('platform-info').textContent = platformText;
            });
        
        // Initialize
        updateMetrics();
        setInterval(updateMetrics, 5000);
        
        // Load historical data
        fetch('/api/metrics/history?hours=1')
            .then(response => response.json())
            .then(data => {
                historyData = data.slice(-100);
                updateCharts();
            });
    </script>
</body>
</html>
        '''
    
    def run(self):
        """Start the web server."""
        host = self.config.get('web.host')
        port = self.config.get('web.port')
        debug = self.config.get('web.debug')
        
        self.app.run(host=host, port=port, debug=debug, threaded=True)

class SystemMonitorService:
    """Main service orchestrator."""
    
    def __init__(self, config_path: str = None):
        self.config = Config(config_path)
        self.setup_logging()
        
        # Initialize components
        self.db = DatabaseManager(self.config.get('database.path'))
        self.monitor = SystemMonitor(self.config.get('wsl2.enabled'))
        self.alert_manager = AlertManager(self.config, self.db)
        self.dashboard = MonitoringDashboard(self.config, self.db, self.monitor)
        
        # Control flags
        self.running = False
        self.monitoring_thread = None
        self.cleanup_thread = None
        
        # Setup signal handlers
        if hasattr(signal, 'SIGTERM'):
            signal.signal(signal.SIGTERM, self._signal_handler)
        signal.signal(signal.SIGINT, self._signal_handler)
    
    def setup_logging(self):
        """Configure logging."""
        log_level = getattr(logging, self.config.get('logging.level', 'INFO'))
        log_file = self.config.get('logging.file')
        
        # Create log directory
        os.makedirs(os.path.dirname(log_file), exist_ok=True)
        
        logging.basicConfig(
            level=log_level,
            format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
            handlers=[
                logging.FileHandler(log_file),
                logging.StreamHandler(sys.stdout)
            ]
        )
    
    def _signal_handler(self, signum, frame):
        """Handle shutdown signals."""
        logging.info(f"Received signal {signum}, shutting down...")
        self.stop()
    
    def monitoring_loop(self):
        """Main monitoring loop."""
        interval = self.config.get('monitoring.interval_seconds')
        
        while self.running:
            try:
                # Get current metrics
                metrics = self.monitor.get_current_metrics()
                
                # Store in database
                self.db.insert_metrics(metrics)
                
                # Store process metrics if enabled
                if self.config.get('monitoring.track_processes'):
                    all_processes = []
                    for proc_list in [metrics['processes']['cpu_top'], 
                                    metrics['processes']['memory_top']]:
                        all_processes.extend(proc_list)
                    
                    # Remove duplicates based on PID
                    unique_processes = []
                    seen_pids = set()
                    for proc in all_processes:
                        if proc['pid'] not in seen_pids:
                            unique_processes.append(proc)
                            seen_pids.add(proc['pid'])
                    
                    self.db.insert_process_metrics(unique_processes)
                
                # Check for alerts
                self.alert_manager.check_thresholds(metrics)
                
                # Log current status
                logging.debug(f"Metrics collected: CPU={metrics['cpu_percent']:.1f}%, "
                            f"Memory={metrics['memory_percent']:.1f}%, "
                            f"Disk={metrics['disk_percent']:.1f}%")
                
            except Exception as e:
                logging.error(f"Error in monitoring loop: {e}")
            
            time.sleep(interval)
    
    def cleanup_loop(self):
        """Periodic cleanup of old data."""
        while self.running:
            try:
                retention_days = self.config.get('database.retention_days')
                self.db.cleanup_old_data(retention_days)
                logging.info("Database cleanup completed")
            except Exception as e:
                logging.error(f"Error in cleanup: {e}")
            
            # Run cleanup every hour
            time.sleep(3600)
    
    def start(self):
        """Start the monitoring service."""
        if self.running:
            return
        
        self.running = True
        
        wsl_info = " (WSL2 Optimized)" if self.config.get('wsl2.enabled') else ""
        logging.info(f"Starting Enhanced System Monitor Service{wsl_info}")
        
        # Start monitoring thread
        self.monitoring_thread = threading.Thread(target=self.monitoring_loop)
        self.monitoring_thread.daemon = True
        self.monitoring_thread.start()
        
        # Start cleanup thread
        self.cleanup_thread = threading.Thread(target=self.cleanup_loop)
        self.cleanup_thread.daemon = True
        self.cleanup_thread.start()
        
        # Start web dashboard
        try:
            port = self.config.get('web.port')
            print(f"🚀 Enhanced System Monitor starting on http://localhost:{port}")
            print(f"📊 Features: Process ranking, Real-time charts, Alerts")
            if self.config.get('wsl2.enabled'):
                print(f"🐧 WSL2 mode: Monitoring both Linux and Windows drives")
            self.dashboard.run()
        except Exception as e:
            logging.error(f"Dashboard error: {e}")
            self.stop()
    
    def stop(self):
        """Stop the monitoring service."""
        if not self.running:
            return
        
        self.running = False
        logging.info("Stopping Enhanced System Monitor Service")
        
        # Wait for threads to finish
        if self.monitoring_thread and self.monitoring_thread.is_alive():
            self.monitoring_thread.join(timeout=5)
        
        if self.cleanup_thread and self.cleanup_thread.is_alive():
            self.cleanup_thread.join(timeout=5)

def create_default_config():
    """Create default configuration file."""
    config = Config()
    config.save_config()
    print(f"✅ Default configuration created at {config.config_path}")
    if config.is_wsl2:
        print("🐧 WSL2 detected - Configuration optimized for Windows 11")
    print("📝 Edit the configuration file to customize settings and email alerts")

def main():
    """Main entry point."""
    parser = argparse.ArgumentParser(description='Enhanced System Performance Monitor with Process Ranking')
    parser.add_argument('--config', action='store_true', 
                       help='Create default configuration file')
    parser.add_argument('--config-path', 
                       help='Path to configuration file')
    
    args = parser.parse_args()
    
    if args.config:
        create_default_config()
        return
    
    try:
        # Create and start service
        service = SystemMonitorService(args.config_path)
        service.start()
    except KeyboardInterrupt:
        print("\n👋 Shutdown requested...")
    except Exception as e:
        print(f"❌ Error: {e}")
        sys.exit(1)

if __name__ == '__main__':
    main()
