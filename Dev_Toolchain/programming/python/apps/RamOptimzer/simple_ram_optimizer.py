"""
Lightweight RAM Optimizer GUI - No external dependencies beyond tkinter
Focuses on core RAM optimization functionality
"""

import tkinter as tk
from tkinter import ttk, messagebox
import threading
import time
from memory_manager import WindowsMemoryManager
import configparser
import os

class LightweightRamOptimizer:
    def __init__(self):
        self.root = tk.Tk()
        self.root.title("RAM Optimizer Pro - Lightweight")
        self.root.geometry("600x450")
        self.root.resizable(True, True)
        
        # Set a modern color scheme
        self.root.configure(bg='#2b2b2b')
        style = ttk.Style()
        style.theme_use('clam')
        
        # Initialize memory manager
        self.memory_manager = WindowsMemoryManager()
        
        # Configuration
        self.config = configparser.ConfigParser()
        self.config_file = "ram_optimizer_config.ini"
        self.load_config()
        
        # Variables
        self.is_monitoring = False
        self.memory_history = []
        self.max_history = 20
        
        # Setup GUI
        self.setup_gui()
        
        # Start initial memory update
        self.update_memory_display()
        
        # Setup automatic GUI updates
        self.root.after(2000, self.periodic_update)
    
    def load_config(self):
        """Load configuration from file"""
        if os.path.exists(self.config_file):
            self.config.read(self.config_file)
        else:
            self.config['Settings'] = {
                'auto_clean_interval': '30',
                'memory_threshold': '80'
            }
            self.save_config()
    
    def save_config(self):
        """Save configuration to file"""
        with open(self.config_file, 'w') as configfile:
            self.config.write(configfile)
    
    def setup_gui(self):
        """Setup the main GUI interface"""
        # Title
        title_frame = tk.Frame(self.root, bg='#2b2b2b')
        title_frame.pack(fill='x', padx=10, pady=10)
        
        title_label = tk.Label(title_frame, text="🚀 RAM Optimizer Pro", 
                              font=('Arial', 20, 'bold'), 
                              fg='#ffffff', bg='#2b2b2b')
        title_label.pack()
        
        subtitle = tk.Label(title_frame, text="Lightweight Edition - Core Features Only", 
                           font=('Arial', 10), 
                           fg='#cccccc', bg='#2b2b2b')
        subtitle.pack()
        
        # Main container
        main_frame = tk.Frame(self.root, bg='#2b2b2b')
        main_frame.pack(fill='both', expand=True, padx=10, pady=5)
        
        # Memory info section
        self.setup_memory_section(main_frame)
        
        # Control section
        self.setup_control_section(main_frame)
        
        # Status section
        self.setup_status_section(main_frame)
    
    def setup_memory_section(self, parent):
        """Setup memory information display"""
        memory_frame = tk.LabelFrame(parent, text="Memory Information", 
                                    font=('Arial', 12, 'bold'),
                                    fg='#ffffff', bg='#3a3a3a')
        memory_frame.pack(fill='x', pady=5)
        
        # Memory stats grid
        stats_frame = tk.Frame(memory_frame, bg='#3a3a3a')
        stats_frame.pack(fill='x', padx=10, pady=10)
        
        self.memory_labels = {}
        
        # Create memory info display
        info_data = [
            ('total', 'Total Memory:', 0, 0),
            ('used', 'Used Memory:', 0, 2),
            ('available', 'Available:', 1, 0),
            ('percentage', 'Usage:', 1, 2)
        ]
        
        for key, label, row, col in info_data:
            tk.Label(stats_frame, text=label, font=('Arial', 10),
                    fg='#cccccc', bg='#3a3a3a').grid(row=row, column=col, sticky='w', padx=5, pady=2)
            
            self.memory_labels[key] = tk.Label(stats_frame, text="--", 
                                             font=('Arial', 10, 'bold'),
                                             fg='#ffffff', bg='#3a3a3a')
            self.memory_labels[key].grid(row=row, column=col+1, sticky='w', padx=5, pady=2)
        
        # Memory usage bar
        bar_frame = tk.Frame(memory_frame, bg='#3a3a3a')
        bar_frame.pack(fill='x', padx=10, pady=5)
        
        tk.Label(bar_frame, text="Memory Usage:", font=('Arial', 10),
                fg='#cccccc', bg='#3a3a3a').pack(side='left')
        
        self.memory_bar = ttk.Progressbar(bar_frame, length=300, mode='determinate')
        self.memory_bar.pack(side='left', padx=10, fill='x', expand=True)
        
        self.percentage_label = tk.Label(bar_frame, text="0%", font=('Arial', 10, 'bold'),
                                       fg='#ffffff', bg='#3a3a3a')
        self.percentage_label.pack(side='right')
    
    def setup_control_section(self, parent):
        """Setup control buttons"""
        control_frame = tk.LabelFrame(parent, text="Controls", 
                                     font=('Arial', 12, 'bold'),
                                     fg='#ffffff', bg='#3a3a3a')
        control_frame.pack(fill='x', pady=5)
        
        # Button frame
        btn_frame = tk.Frame(control_frame, bg='#3a3a3a')
        btn_frame.pack(fill='x', padx=10, pady=10)
        
        # Optimize button
        self.optimize_btn = tk.Button(btn_frame, text="🚀 Optimize RAM Now", 
                                     command=self.manual_optimize,
                                     font=('Arial', 12, 'bold'),
                                     bg='#4CAF50', fg='white',
                                     relief='flat', bd=0, padx=20, pady=8)
        self.optimize_btn.pack(side='left', padx=5)
        
        # Monitor button
        self.monitor_btn = tk.Button(btn_frame, text="▶️ Start Auto Monitor", 
                                    command=self.toggle_monitoring,
                                    font=('Arial', 12, 'bold'),
                                    bg='#2196F3', fg='white',
                                    relief='flat', bd=0, padx=20, pady=8)
        self.monitor_btn.pack(side='left', padx=5)
        
        # Process button
        process_btn = tk.Button(btn_frame, text="📊 View Processes", 
                               command=self.show_process_window,
                               font=('Arial', 12),
                               bg='#FF9800', fg='white',
                               relief='flat', bd=0, padx=20, pady=8)
        process_btn.pack(side='left', padx=5)
        
        # Settings frame
        settings_frame = tk.Frame(control_frame, bg='#3a3a3a')
        settings_frame.pack(fill='x', padx=10, pady=5)
        
        # Interval setting
        tk.Label(settings_frame, text="Check Interval:", font=('Arial', 9),
                fg='#cccccc', bg='#3a3a3a').grid(row=0, column=0, sticky='w', padx=5)
        
        self.interval_var = tk.StringVar(value=self.config['Settings']['auto_clean_interval'])
        interval_entry = tk.Entry(settings_frame, textvariable=self.interval_var, width=8)
        interval_entry.grid(row=0, column=1, padx=5)
        
        tk.Label(settings_frame, text="sec", font=('Arial', 9),
                fg='#cccccc', bg='#3a3a3a').grid(row=0, column=2, sticky='w')
        
        # Threshold setting
        tk.Label(settings_frame, text="Threshold:", font=('Arial', 9),
                fg='#cccccc', bg='#3a3a3a').grid(row=0, column=3, sticky='w', padx=(20,5))
        
        self.threshold_var = tk.StringVar(value=self.config['Settings']['memory_threshold'])
        threshold_entry = tk.Entry(settings_frame, textvariable=self.threshold_var, width=8)
        threshold_entry.grid(row=0, column=4, padx=5)
        
        tk.Label(settings_frame, text="%", font=('Arial', 9),
                fg='#cccccc', bg='#3a3a3a').grid(row=0, column=5, sticky='w')
        
        # Apply button
        apply_btn = tk.Button(settings_frame, text="Apply", 
                            command=self.apply_settings,
                            font=('Arial', 9),
                            bg='#9C27B0', fg='white',
                            relief='flat', bd=0, padx=10, pady=2)
        apply_btn.grid(row=0, column=6, padx=10)
    
    def setup_status_section(self, parent):
        """Setup status display"""
        status_frame = tk.LabelFrame(parent, text="Status & History", 
                                   font=('Arial', 12, 'bold'),
                                   fg='#ffffff', bg='#3a3a3a')
        status_frame.pack(fill='both', expand=True, pady=5)
        
        # Current status
        self.status_label = tk.Label(status_frame, text="Ready", 
                                   font=('Arial', 11, 'bold'),
                                   fg='#4CAF50', bg='#3a3a3a')
        self.status_label.pack(pady=5)
        
        # Last optimization info
        self.last_opt_label = tk.Label(status_frame, text="No optimization performed yet", 
                                     font=('Arial', 10),
                                     fg='#cccccc', bg='#3a3a3a')
        self.last_opt_label.pack(pady=2)
        
        # Memory history (text-based)
        history_frame = tk.Frame(status_frame, bg='#3a3a3a')
        history_frame.pack(fill='both', expand=True, padx=10, pady=5)
        
        tk.Label(history_frame, text="Recent Memory Usage:", font=('Arial', 9, 'bold'),
                fg='#cccccc', bg='#3a3a3a').pack(anchor='w')
        
        self.history_text = tk.Text(history_frame, height=6, width=70, 
                                   font=('Courier', 8),
                                   bg='#2b2b2b', fg='#ffffff',
                                   relief='sunken', bd=1)
        self.history_text.pack(fill='both', expand=True)
        
        # Scrollbar for history
        scrollbar = tk.Scrollbar(history_frame, command=self.history_text.yview)
        self.history_text.config(yscrollcommand=scrollbar.set)
        scrollbar.pack(side='right', fill='y')
    
    def update_memory_display(self):
        """Update memory information display"""
        try:
            memory_info = self.memory_manager.get_memory_info()
            
            # Update labels
            self.memory_labels['total'].configure(text=f"{memory_info['total']:.1f} GB")
            self.memory_labels['used'].configure(text=f"{memory_info['used']:.1f} GB")
            self.memory_labels['available'].configure(text=f"{memory_info['available']:.1f} GB")
            self.memory_labels['percentage'].configure(text=f"{memory_info['percentage']:.1f}%")
            
            # Update progress bar
            self.memory_bar['value'] = memory_info['percentage']
            self.percentage_label.configure(text=f"{memory_info['percentage']:.1f}%")
            
            # Color coding
            if memory_info['percentage'] > 85:
                color = '#F44336'  # Red
            elif memory_info['percentage'] > 70:
                color = '#FF9800'  # Orange
            else:
                color = '#4CAF50'  # Green
            
            self.percentage_label.configure(fg=color)
            
            # Add to history
            current_time = time.strftime("%H:%M:%S")
            self.memory_history.append(f"{current_time} - {memory_info['percentage']:.1f}% used ({memory_info['used']:.1f}GB)")
            
            # Keep only recent history
            if len(self.memory_history) > self.max_history:
                self.memory_history.pop(0)
            
            # Update history display
            self.history_text.delete('1.0', tk.END)
            for entry in self.memory_history:
                self.history_text.insert(tk.END, entry + '\n')
            self.history_text.see(tk.END)
            
        except Exception as e:
            print(f"Error updating memory display: {e}")
    
    def manual_optimize(self):
        """Perform manual memory optimization"""
        def optimize_thread():
            try:
                self.optimize_btn.configure(state="disabled", text="🔄 Optimizing...", bg='#9E9E9E')
                self.status_label.configure(text="Optimizing memory...", fg='#2196F3')
                
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
                    
                    # Update last optimization display
                    opt_text = f"Last: Freed {memory_freed:.1f} MB from {processes_cleaned} processes"
                    self.root.after(0, lambda: self.last_opt_label.configure(text=opt_text))
                    
                    self.root.after(0, lambda: messagebox.showinfo("Optimization Complete", message))
                    self.root.after(0, lambda: self.status_label.configure(text="Optimization complete ✅", fg='#4CAF50'))
                else:
                    self.root.after(0, lambda: messagebox.showerror("Error", f"Optimization failed: {results['status']}"))
                    self.root.after(0, lambda: self.status_label.configure(text="Optimization failed ❌", fg='#F44336'))
                
            except Exception as e:
                self.root.after(0, lambda: messagebox.showerror("Error", f"Optimization error: {str(e)}"))
                self.root.after(0, lambda: self.status_label.configure(text="Error occurred ❌", fg='#F44336'))
            finally:
                self.root.after(0, lambda: self.optimize_btn.configure(state="normal", text="🚀 Optimize RAM Now", bg='#4CAF50'))
        
        threading.Thread(target=optimize_thread, daemon=True).start()
    
    def toggle_monitoring(self):
        """Toggle automatic monitoring"""
        if not self.is_monitoring:
            self.apply_settings()
            
            if self.memory_manager.start_auto_monitoring(self.monitoring_callback):
                self.is_monitoring = True
                self.monitor_btn.configure(text="⏸️ Stop Monitor", bg='#F44336')
                self.status_label.configure(text="Auto monitoring active 🔄", fg='#2196F3')
            else:
                messagebox.showerror("Error", "Failed to start monitoring")
        else:
            self.memory_manager.stop_auto_monitoring()
            self.is_monitoring = False
            self.monitor_btn.configure(text="▶️ Start Auto Monitor", bg='#2196F3')
            self.status_label.configure(text="Monitoring stopped ⏹️", fg='#FF9800')
    
    def monitoring_callback(self, event_type, data):
        """Callback for monitoring events"""
        if event_type == 'high_memory':
            self.root.after(0, lambda: self.status_label.configure(
                text=f"High memory usage detected: {data['percentage']:.1f}% 🔥", fg='#F44336'))
        elif event_type == 'cleanup_performed':
            if data['status'] == 'success':
                self.root.after(0, lambda: self.status_label.configure(
                    text=f"Auto-cleaned: {data['memory_freed_mb']:.1f} MB freed ✅", fg='#4CAF50'))
                opt_text = f"Auto: Freed {data['memory_freed_mb']:.1f} MB from {data['processes_cleaned']} processes"
                self.root.after(0, lambda: self.last_opt_label.configure(text=opt_text))
        elif event_type == 'error':
            self.root.after(0, lambda: self.status_label.configure(text=f"Error: {data} ❌", fg='#F44336'))
    
    def apply_settings(self):
        """Apply settings changes"""
        try:
            interval = int(self.interval_var.get())
            threshold = int(self.threshold_var.get())
            
            if interval < 10:
                interval = 10
                self.interval_var.set("10")
            if threshold < 50 or threshold > 95:
                threshold = max(50, min(95, threshold))
                self.threshold_var.set(str(threshold))
            
            self.memory_manager.set_auto_clean_settings(interval, threshold)
            
            self.config['Settings']['auto_clean_interval'] = str(interval)
            self.config['Settings']['memory_threshold'] = str(threshold)
            self.save_config()
            
            self.status_label.configure(text="Settings applied ✅", fg='#4CAF50')
            
        except ValueError:
            messagebox.showerror("Error", "Please enter valid numbers for settings")
    
    def show_process_window(self):
        """Show process memory usage window"""
        process_window = tk.Toplevel(self.root)
        process_window.title("Process Memory Usage")
        process_window.geometry("700x500")
        process_window.configure(bg='#2b2b2b')
        
        # Title
        title_label = tk.Label(process_window, text="📊 Top Memory-Using Processes", 
                              font=('Arial', 14, 'bold'),
                              fg='#ffffff', bg='#2b2b2b')
        title_label.pack(pady=10)
        
        # Create frame for list
        list_frame = tk.Frame(process_window, bg='#2b2b2b')
        list_frame.pack(fill='both', expand=True, padx=10, pady=5)
        
        # Create text widget with scrollbar
        text_widget = tk.Text(list_frame, font=('Courier', 10),
                             bg='#3a3a3a', fg='#ffffff',
                             relief='sunken', bd=1)
        scrollbar = tk.Scrollbar(list_frame, command=text_widget.yview)
        text_widget.config(yscrollcommand=scrollbar.set)
        
        text_widget.pack(side='left', fill='both', expand=True)
        scrollbar.pack(side='right', fill='y')
        
        # Get and display process info
        processes = self.memory_manager.get_process_memory_info()
        
        # Header
        text_widget.insert(tk.END, f"{'Process Name':<30} {'PID':<8} {'Memory (MB)':<12}\n")
        text_widget.insert(tk.END, "-" * 60 + "\n")
        
        # Process list
        for proc in processes:
            text_widget.insert(tk.END, f"{proc['name']:<30} {proc['pid']:<8} {proc['memory_mb']:<12.1f}\n")
        
        text_widget.config(state='disabled')  # Make read-only
    
    def periodic_update(self):
        """Periodic update of memory display"""
        self.update_memory_display()
        self.root.after(2000, self.periodic_update)
    
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
    app = LightweightRamOptimizer()
    app.run() 