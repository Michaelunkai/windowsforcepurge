"""
RAM Optimizer GUI Application
Modern interface for Windows memory optimization
"""

import customtkinter as ctk
import tkinter as tk
from tkinter import messagebox, ttk
import threading
import time
from memory_manager import WindowsMemoryManager
import matplotlib.pyplot as plt
from matplotlib.backends.backend_tkagg import FigureCanvasTkAgg
from matplotlib.figure import Figure
import configparser
import os
from datetime import datetime

# Set appearance mode and color theme
ctk.set_appearance_mode("dark")  # Modes: "System" (standard), "Dark", "Light"
ctk.set_default_color_theme("blue")  # Themes: "blue", "green", "dark-blue"

class RamOptimizerGUI:
    def __init__(self):
        self.root = ctk.CTk()
        self.root.title("RAM Optimizer Pro")
        self.root.geometry("800x600")
        self.root.resizable(True, True)
        
        # Initialize memory manager
        self.memory_manager = WindowsMemoryManager()
        
        # Configuration
        self.config = configparser.ConfigParser()
        self.config_file = "ram_optimizer_config.ini"
        self.load_config()
        
        # Variables
        self.is_monitoring = False
        self.memory_data = []
        self.max_data_points = 60  # Keep last 60 readings
        
        # Setup GUI
        self.setup_gui()
        
        # Start initial memory update
        self.update_memory_display()
        
        # Setup automatic GUI updates
        self.root.after(2000, self.periodic_update)  # Update every 2 seconds
    
    def load_config(self):
        """Load configuration from file"""
        if os.path.exists(self.config_file):
            self.config.read(self.config_file)
        else:
            # Default configuration
            self.config['Settings'] = {
                'auto_clean_interval': '30',
                'memory_threshold': '80',
                'auto_start_monitoring': 'false',
                'minimize_to_tray': 'true'
            }
            self.save_config()
    
    def save_config(self):
        """Save configuration to file"""
        with open(self.config_file, 'w') as configfile:
            self.config.write(configfile)
    
    def setup_gui(self):
        """Setup the main GUI interface"""
        # Configure grid weight
        self.root.grid_columnconfigure(0, weight=1)
        self.root.grid_rowconfigure(1, weight=1)
        
        # Title frame
        title_frame = ctk.CTkFrame(self.root)
        title_frame.grid(row=0, column=0, padx=10, pady=10, sticky="ew")
        
        title_label = ctk.CTkLabel(title_frame, text="RAM Optimizer Pro", 
                                  font=ctk.CTkFont(size=24, weight="bold"))
        title_label.pack(pady=10)
        
        # Main container
        main_frame = ctk.CTkFrame(self.root)
        main_frame.grid(row=1, column=0, padx=10, pady=(0, 10), sticky="nsew")
        main_frame.grid_columnconfigure(1, weight=1)
        main_frame.grid_rowconfigure(0, weight=1)
        
        # Left panel - Controls
        self.setup_control_panel(main_frame)
        
        # Right panel - Memory info and graph
        self.setup_info_panel(main_frame)
    
    def setup_control_panel(self, parent):
        """Setup the left control panel"""
        control_frame = ctk.CTkFrame(parent)
        control_frame.grid(row=0, column=0, padx=10, pady=10, sticky="nsew")
        
        # Control buttons
        ctk.CTkLabel(control_frame, text="Manual Controls", 
                    font=ctk.CTkFont(size=16, weight="bold")).pack(pady=(10, 5))
        
        self.optimize_btn = ctk.CTkButton(control_frame, text="🚀 Optimize RAM Now", 
                                         command=self.manual_optimize, height=40,
                                         font=ctk.CTkFont(size=14))
        self.optimize_btn.pack(pady=5, padx=10, fill="x")
        
        # Auto monitoring controls
        ctk.CTkLabel(control_frame, text="Auto Monitoring", 
                    font=ctk.CTkFont(size=16, weight="bold")).pack(pady=(20, 5))
        
        self.monitor_btn = ctk.CTkButton(control_frame, text="▶️ Start Auto Monitor", 
                                        command=self.toggle_monitoring, height=40,
                                        font=ctk.CTkFont(size=14))
        self.monitor_btn.pack(pady=5, padx=10, fill="x")
        
        # Settings frame
        settings_frame = ctk.CTkFrame(control_frame)
        settings_frame.pack(pady=10, padx=10, fill="x")
        
        ctk.CTkLabel(settings_frame, text="Settings", 
                    font=ctk.CTkFont(size=14, weight="bold")).pack(pady=5)
        
        # Interval setting
        ctk.CTkLabel(settings_frame, text="Check Interval (seconds):").pack(pady=(5, 0))
        self.interval_var = ctk.StringVar(value=self.config['Settings']['auto_clean_interval'])
        interval_entry = ctk.CTkEntry(settings_frame, textvariable=self.interval_var, width=100)
        interval_entry.pack(pady=5)
        
        # Threshold setting
        ctk.CTkLabel(settings_frame, text="Memory Threshold (%):").pack(pady=(10, 0))
        self.threshold_var = ctk.StringVar(value=self.config['Settings']['memory_threshold'])
        threshold_entry = ctk.CTkEntry(settings_frame, textvariable=self.threshold_var, width=100)
        threshold_entry.pack(pady=5)
        
        # Apply settings button
        apply_btn = ctk.CTkButton(settings_frame, text="Apply Settings", 
                                 command=self.apply_settings, height=30)
        apply_btn.pack(pady=10)
        
        # Process list button
        process_btn = ctk.CTkButton(control_frame, text="📊 View Process Memory", 
                                   command=self.show_process_window, height=35)
        process_btn.pack(pady=10, padx=10, fill="x")
        
        # Status frame
        self.status_frame = ctk.CTkFrame(control_frame)
        self.status_frame.pack(pady=10, padx=10, fill="x")
        
        ctk.CTkLabel(self.status_frame, text="Status", 
                    font=ctk.CTkFont(size=14, weight="bold")).pack(pady=5)
        
        self.status_label = ctk.CTkLabel(self.status_frame, text="Ready", 
                                        font=ctk.CTkFont(size=12))
        self.status_label.pack(pady=5)
    
    def setup_info_panel(self, parent):
        """Setup the right information panel"""
        info_frame = ctk.CTkFrame(parent)
        info_frame.grid(row=0, column=1, padx=10, pady=10, sticky="nsew")
        info_frame.grid_rowconfigure(1, weight=1)
        
        # Memory info display
        memory_frame = ctk.CTkFrame(info_frame)
        memory_frame.pack(pady=10, padx=10, fill="x")
        
        ctk.CTkLabel(memory_frame, text="Memory Information", 
                    font=ctk.CTkFont(size=16, weight="bold")).pack(pady=5)
        
        # Memory stats
        self.memory_labels = {}
        stats_frame = ctk.CTkFrame(memory_frame)
        stats_frame.pack(pady=5, padx=5, fill="x")
        
        for i, (key, label) in enumerate([
            ('total', 'Total Memory:'),
            ('used', 'Used Memory:'),
            ('available', 'Available:'),
            ('percentage', 'Usage:')
        ]):
            row_frame = ctk.CTkFrame(stats_frame)
            row_frame.pack(pady=2, fill="x")
            
            ctk.CTkLabel(row_frame, text=label, width=100).pack(side="left", padx=5)
            self.memory_labels[key] = ctk.CTkLabel(row_frame, text="--", 
                                                  font=ctk.CTkFont(size=12, weight="bold"))
            self.memory_labels[key].pack(side="right", padx=5)
        
        # Memory usage graph
        graph_frame = ctk.CTkFrame(info_frame)
        graph_frame.pack(pady=10, padx=10, fill="both", expand=True)
        
        ctk.CTkLabel(graph_frame, text="Memory Usage Over Time", 
                    font=ctk.CTkFont(size=14, weight="bold")).pack(pady=5)
        
        # Create matplotlib figure
        self.fig = Figure(figsize=(6, 3), dpi=100, facecolor='#2b2b2b')
        self.ax = self.fig.add_subplot(111)
        self.ax.set_facecolor('#1f1f1f')
        self.ax.tick_params(colors='white')
        self.ax.set_xlabel('Time', color='white')
        self.ax.set_ylabel('Memory Usage (%)', color='white')
        
        self.canvas = FigureCanvasTkAgg(self.fig, graph_frame)
        self.canvas.get_tk_widget().pack(pady=5, padx=5, fill="both", expand=True)
    
    def update_memory_display(self):
        """Update memory information display"""
        try:
            memory_info = self.memory_manager.get_memory_info()
            
            # Update labels
            self.memory_labels['total'].configure(text=f"{memory_info['total']:.1f} GB")
            self.memory_labels['used'].configure(text=f"{memory_info['used']:.1f} GB")
            self.memory_labels['available'].configure(text=f"{memory_info['available']:.1f} GB")
            self.memory_labels['percentage'].configure(text=f"{memory_info['percentage']:.1f}%")
            
            # Add to memory data for graph
            self.memory_data.append(memory_info['percentage'])
            if len(self.memory_data) > self.max_data_points:
                self.memory_data.pop(0)
            
            # Update graph
            self.update_memory_graph()
            
        except Exception as e:
            print(f"Error updating memory display: {e}")
    
    def update_memory_graph(self):
        """Update the memory usage graph"""
        try:
            self.ax.clear()
            self.ax.set_facecolor('#1f1f1f')
            
            if self.memory_data:
                x_data = list(range(len(self.memory_data)))
                self.ax.plot(x_data, self.memory_data, color='#1f77b4', linewidth=2)
                self.ax.fill_between(x_data, self.memory_data, alpha=0.3, color='#1f77b4')
                
                # Add threshold line if monitoring
                if self.is_monitoring:
                    threshold = int(self.threshold_var.get())
                    self.ax.axhline(y=threshold, color='red', linestyle='--', alpha=0.7)
            
            self.ax.set_ylim(0, 100)
            self.ax.set_ylabel('Memory Usage (%)', color='white')
            self.ax.set_xlabel('Time', color='white')
            self.ax.tick_params(colors='white')
            self.ax.grid(True, alpha=0.3)
            
            self.canvas.draw()
        except Exception as e:
            print(f"Error updating graph: {e}")
    
    def manual_optimize(self):
        """Perform manual memory optimization"""
        def optimize_thread():
            try:
                self.optimize_btn.configure(state="disabled", text="🔄 Optimizing...")
                self.status_label.configure(text="Optimizing memory...")
                
                results = self.memory_manager.comprehensive_cleanup()
                
                if results['status'] == 'success':
                    memory_freed = results['memory_freed_mb']
                    processes_cleaned = results['processes_cleaned']
                    
                    message = f"✅ Optimization Complete!\n\n"
                    message += f"• Processes optimized: {processes_cleaned}\n"
                    message += f"• Memory freed: {memory_freed:.1f} MB\n"
                    
                    before = results['memory_before']['percentage']
                    after = results['memory_after']['percentage']
                    message += f"• Memory usage: {before:.1f}% → {after:.1f}%"
                    
                    self.root.after(0, lambda: messagebox.showinfo("Optimization Complete", message))
                    self.root.after(0, lambda: self.status_label.configure(text="Optimization complete"))
                else:
                    self.root.after(0, lambda: messagebox.showerror("Error", f"Optimization failed: {results['status']}"))
                    self.root.after(0, lambda: self.status_label.configure(text="Optimization failed"))
                
            except Exception as e:
                self.root.after(0, lambda: messagebox.showerror("Error", f"Optimization error: {str(e)}"))
                self.root.after(0, lambda: self.status_label.configure(text="Error occurred"))
            finally:
                self.root.after(0, lambda: self.optimize_btn.configure(state="normal", text="🚀 Optimize RAM Now"))
        
        threading.Thread(target=optimize_thread, daemon=True).start()
    
    def toggle_monitoring(self):
        """Toggle automatic monitoring"""
        if not self.is_monitoring:
            # Start monitoring
            self.apply_settings()  # Apply current settings first
            
            if self.memory_manager.start_auto_monitoring(self.monitoring_callback):
                self.is_monitoring = True
                self.monitor_btn.configure(text="⏸️ Stop Auto Monitor", fg_color="red")
                self.status_label.configure(text="Auto monitoring active")
            else:
                messagebox.showerror("Error", "Failed to start monitoring")
        else:
            # Stop monitoring
            self.memory_manager.stop_auto_monitoring()
            self.is_monitoring = False
            self.monitor_btn.configure(text="▶️ Start Auto Monitor", fg_color=None)
            self.status_label.configure(text="Monitoring stopped")
    
    def monitoring_callback(self, event_type, data):
        """Callback for monitoring events"""
        if event_type == 'high_memory':
            self.root.after(0, lambda: self.status_label.configure(
                text=f"High memory usage: {data['percentage']:.1f}%"))
        elif event_type == 'cleanup_performed':
            if data['status'] == 'success':
                self.root.after(0, lambda: self.status_label.configure(
                    text=f"Auto-cleaned: {data['memory_freed_mb']:.1f} MB freed"))
        elif event_type == 'error':
            self.root.after(0, lambda: self.status_label.configure(text=f"Error: {data}"))
    
    def apply_settings(self):
        """Apply settings changes"""
        try:
            interval = int(self.interval_var.get())
            threshold = int(self.threshold_var.get())
            
            # Validate settings
            if interval < 10:
                interval = 10
                self.interval_var.set("10")
            if threshold < 50 or threshold > 95:
                threshold = max(50, min(95, threshold))
                self.threshold_var.set(str(threshold))
            
            # Apply to memory manager
            self.memory_manager.set_auto_clean_settings(interval, threshold)
            
            # Save to config
            self.config['Settings']['auto_clean_interval'] = str(interval)
            self.config['Settings']['memory_threshold'] = str(threshold)
            self.save_config()
            
            self.status_label.configure(text="Settings applied")
            
        except ValueError:
            messagebox.showerror("Error", "Please enter valid numbers for settings")
    
    def show_process_window(self):
        """Show process memory usage window"""
        process_window = ctk.CTkToplevel(self.root)
        process_window.title("Process Memory Usage")
        process_window.geometry("600x400")
        
        # Create treeview for process list
        frame = ctk.CTkFrame(process_window)
        frame.pack(fill="both", expand=True, padx=10, pady=10)
        
        ctk.CTkLabel(frame, text="Top Memory-Using Processes", 
                    font=ctk.CTkFont(size=16, weight="bold")).pack(pady=10)
        
        # Create scrollable frame
        scrollable_frame = ctk.CTkScrollableFrame(frame)
        scrollable_frame.pack(fill="both", expand=True, padx=10, pady=10)
        
        # Get process info
        processes = self.memory_manager.get_process_memory_info()
        
        # Create process list
        for i, proc in enumerate(processes):
            proc_frame = ctk.CTkFrame(scrollable_frame)
            proc_frame.pack(fill="x", pady=2, padx=5)
            
            name_label = ctk.CTkLabel(proc_frame, text=proc['name'], width=200)
            name_label.pack(side="left", padx=5, pady=5)
            
            memory_label = ctk.CTkLabel(proc_frame, text=f"{proc['memory_mb']:.1f} MB")
            memory_label.pack(side="right", padx=5, pady=5)
            
            pid_label = ctk.CTkLabel(proc_frame, text=f"PID: {proc['pid']}")
            pid_label.pack(side="right", padx=5, pady=5)
    
    def periodic_update(self):
        """Periodic update of memory display"""
        self.update_memory_display()
        self.root.after(2000, self.periodic_update)  # Update every 2 seconds
    
    def on_closing(self):
        """Handle application closing"""
        if self.is_monitoring:
            self.memory_manager.stop_auto_monitoring()
        self.save_config()
        self.root.destroy()
    
    def run(self):
        """Start the GUI application"""
        self.root.protocol("WM_DELETE_WINDOW", self.on_closing)
        self.root.mainloop()

if __name__ == "__main__":
    app = RamOptimizerGUI()
    app.run() 