"""
Simplified RAM Optimizer GUI using basic tkinter
For systems where customtkinter installation fails
"""

import tkinter as tk
from tkinter import ttk, messagebox
import threading
import time
from memory_manager import WindowsMemoryManager
import configparser
import os

class SimpleRamOptimizerGUI:
    def __init__(self):
        self.root = tk.Tk()
        self.root.title("RAM Optimizer Pro")
        self.root.geometry("700x500")
        self.root.resizable(True, True)
        
        # Initialize memory manager
        self.memory_manager = WindowsMemoryManager()
        
        # Configuration
        self.config = configparser.ConfigParser()
        self.config_file = "ram_optimizer_config.ini"
        self.load_config()
        
        # Variables
        self.is_monitoring = False
        
        # Setup GUI
        self.setup_gui()
        
        # Start initial memory update
        self.update_memory_display()
        
        # Setup automatic GUI updates
        self.root.after(3000, self.periodic_update)  # Update every 3 seconds
    
    def load_config(self):
        """Load configuration from file"""
        if os.path.exists(self.config_file):
            self.config.read(self.config_file)
        else:
            # Default configuration
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
        # Main frame
        main_frame = ttk.Frame(self.root, padding="10")
        main_frame.grid(row=0, column=0, sticky=(tk.W, tk.E, tk.N, tk.S))
        self.root.columnconfigure(0, weight=1)
        self.root.rowconfigure(0, weight=1)
        
        # Title
        title_label = ttk.Label(main_frame, text="RAM Optimizer Pro", 
                               font=('Arial', 16, 'bold'))
        title_label.grid(row=0, column=0, columnspan=2, pady=(0, 20))
        
        # Left frame - Controls
        control_frame = ttk.LabelFrame(main_frame, text="Controls", padding="10")
        control_frame.grid(row=1, column=0, sticky=(tk.W, tk.E, tk.N, tk.S), padx=(0, 10))
        
        # Memory info frame
        info_frame = ttk.LabelFrame(main_frame, text="Memory Information", padding="10")
        info_frame.grid(row=1, column=1, sticky=(tk.W, tk.E, tk.N, tk.S))
        
        main_frame.columnconfigure(0, weight=1)
        main_frame.columnconfigure(1, weight=2)
        main_frame.rowconfigure(1, weight=1)
        
        self.setup_controls(control_frame)
        self.setup_memory_info(info_frame)
    
    def setup_controls(self, parent):
        """Setup control buttons and settings"""
        # Manual optimization
        self.optimize_btn = ttk.Button(parent, text="🚀 Optimize RAM Now", 
                                      command=self.manual_optimize)
        self.optimize_btn.grid(row=0, column=0, sticky=(tk.W, tk.E), pady=(0, 10))
        
        # Auto monitoring
        self.monitor_btn = ttk.Button(parent, text="▶️ Start Auto Monitor", 
                                     command=self.toggle_monitoring)
        self.monitor_btn.grid(row=1, column=0, sticky=(tk.W, tk.E), pady=(0, 10))
        
        # Settings
        settings_frame = ttk.LabelFrame(parent, text="Settings", padding="5")
        settings_frame.grid(row=2, column=0, sticky=(tk.W, tk.E), pady=(10, 0))
        
        ttk.Label(settings_frame, text="Check Interval (sec):").grid(row=0, column=0, sticky=tk.W)
        self.interval_var = tk.StringVar(value=self.config['Settings']['auto_clean_interval'])
        interval_entry = ttk.Entry(settings_frame, textvariable=self.interval_var, width=10)
        interval_entry.grid(row=0, column=1, padx=(5, 0))
        
        ttk.Label(settings_frame, text="Memory Threshold (%):").grid(row=1, column=0, sticky=tk.W)
        self.threshold_var = tk.StringVar(value=self.config['Settings']['memory_threshold'])
        threshold_entry = ttk.Entry(settings_frame, textvariable=self.threshold_var, width=10)
        threshold_entry.grid(row=1, column=1, padx=(5, 0))
        
        apply_btn = ttk.Button(settings_frame, text="Apply Settings", 
                              command=self.apply_settings)
        apply_btn.grid(row=2, column=0, columnspan=2, pady=(5, 0))
        
        # Process viewer
        process_btn = ttk.Button(parent, text="📊 View Processes", 
                                command=self.show_process_window)
        process_btn.grid(row=3, column=0, sticky=(tk.W, tk.E), pady=(10, 0))
        
        # Status
        status_frame = ttk.LabelFrame(parent, text="Status", padding="5")
        status_frame.grid(row=4, column=0, sticky=(tk.W, tk.E), pady=(10, 0))
        
        self.status_label = ttk.Label(status_frame, text="Ready", foreground="green")
        self.status_label.grid(row=0, column=0)
        
        parent.columnconfigure(0, weight=1)
    
    def setup_memory_info(self, parent):
        """Setup memory information display"""
        # Memory stats
        self.memory_labels = {}
        
        for i, (key, label) in enumerate([
            ('total', 'Total Memory:'),
            ('used', 'Used Memory:'),
            ('available', 'Available Memory:'),
            ('percentage', 'Usage Percentage:')
        ]):
            ttk.Label(parent, text=label).grid(row=i, column=0, sticky=tk.W, pady=2)
            self.memory_labels[key] = ttk.Label(parent, text="--", font=('Arial', 10, 'bold'))
            self.memory_labels[key].grid(row=i, column=1, sticky=tk.E, pady=2)
        
        # Progress bar for memory usage
        ttk.Label(parent, text="Memory Usage:").grid(row=4, column=0, sticky=tk.W, pady=(10, 2))
        self.memory_progress = ttk.Progressbar(parent, length=200, mode='determinate')
        self.memory_progress.grid(row=4, column=1, sticky=(tk.W, tk.E), pady=(10, 2))
        
        # Last optimization info
        self.last_opt_frame = ttk.LabelFrame(parent, text="Last Optimization", padding="5")
        self.last_opt_frame.grid(row=5, column=0, columnspan=2, sticky=(tk.W, tk.E), pady=(10, 0))
        
        self.last_opt_label = ttk.Label(self.last_opt_frame, text="No optimization performed yet")
        self.last_opt_label.grid(row=0, column=0)
        
        parent.columnconfigure(1, weight=1)
    
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
            self.memory_progress['value'] = memory_info['percentage']
            
            # Color coding for memory usage
            if memory_info['percentage'] > 85:
                self.memory_labels['percentage'].configure(foreground="red")
            elif memory_info['percentage'] > 70:
                self.memory_labels['percentage'].configure(foreground="orange")
            else:
                self.memory_labels['percentage'].configure(foreground="green")
                
        except Exception as e:
            print(f"Error updating memory display: {e}")
    
    def manual_optimize(self):
        """Perform manual memory optimization"""
        def optimize_thread():
            try:
                self.optimize_btn.configure(state="disabled", text="🔄 Optimizing...")
                self.status_label.configure(text="Optimizing memory...", foreground="blue")
                
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
                    
                    # Update last optimization info
                    self.root.after(0, lambda: self.last_opt_label.configure(
                        text=f"Freed {memory_freed:.1f} MB from {processes_cleaned} processes"))
                    
                    self.root.after(0, lambda: messagebox.showinfo("Optimization Complete", message))
                    self.root.after(0, lambda: self.status_label.configure(text="Optimization complete", foreground="green"))
                else:
                    self.root.after(0, lambda: messagebox.showerror("Error", f"Optimization failed: {results['status']}"))
                    self.root.after(0, lambda: self.status_label.configure(text="Optimization failed", foreground="red"))
                
            except Exception as e:
                self.root.after(0, lambda: messagebox.showerror("Error", f"Optimization error: {str(e)}"))
                self.root.after(0, lambda: self.status_label.configure(text="Error occurred", foreground="red"))
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
                self.monitor_btn.configure(text="⏸️ Stop Auto Monitor")
                self.status_label.configure(text="Auto monitoring active", foreground="blue")
            else:
                messagebox.showerror("Error", "Failed to start monitoring")
        else:
            # Stop monitoring
            self.memory_manager.stop_auto_monitoring()
            self.is_monitoring = False
            self.monitor_btn.configure(text="▶️ Start Auto Monitor")
            self.status_label.configure(text="Monitoring stopped", foreground="orange")
    
    def monitoring_callback(self, event_type, data):
        """Callback for monitoring events"""
        if event_type == 'high_memory':
            self.root.after(0, lambda: self.status_label.configure(
                text=f"High memory usage: {data['percentage']:.1f}%", foreground="red"))
        elif event_type == 'cleanup_performed':
            if data['status'] == 'success':
                self.root.after(0, lambda: self.status_label.configure(
                    text=f"Auto-cleaned: {data['memory_freed_mb']:.1f} MB freed", foreground="green"))
                self.root.after(0, lambda: self.last_opt_label.configure(
                    text=f"Auto: Freed {data['memory_freed_mb']:.1f} MB from {data['processes_cleaned']} processes"))
        elif event_type == 'error':
            self.root.after(0, lambda: self.status_label.configure(text=f"Error: {data}", foreground="red"))
    
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
            
            self.status_label.configure(text="Settings applied", foreground="green")
            
        except ValueError:
            messagebox.showerror("Error", "Please enter valid numbers for settings")
    
    def show_process_window(self):
        """Show process memory usage window"""
        process_window = tk.Toplevel(self.root)
        process_window.title("Process Memory Usage")
        process_window.geometry("600x400")
        
        # Create frame with scrollbar
        main_frame = ttk.Frame(process_window)
        main_frame.pack(fill="both", expand=True, padx=10, pady=10)
        
        # Title
        title_label = ttk.Label(main_frame, text="Top Memory-Using Processes", 
                               font=('Arial', 12, 'bold'))
        title_label.pack(pady=(0, 10))
        
        # Create treeview
        tree_frame = ttk.Frame(main_frame)
        tree_frame.pack(fill="both", expand=True)
        
        tree = ttk.Treeview(tree_frame, columns=('PID', 'Memory'), show='tree headings')
        tree.heading('#0', text='Process Name')
        tree.heading('PID', text='PID')
        tree.heading('Memory', text='Memory (MB)')
        
        tree.column('#0', width=200)
        tree.column('PID', width=100)
        tree.column('Memory', width=100)
        
        # Scrollbar
        scrollbar = ttk.Scrollbar(tree_frame, orient="vertical", command=tree.yview)
        tree.configure(yscrollcommand=scrollbar.set)
        
        tree.pack(side="left", fill="both", expand=True)
        scrollbar.pack(side="right", fill="y")
        
        # Get process info
        processes = self.memory_manager.get_process_memory_info()
        
        # Populate tree
        for proc in processes:
            tree.insert('', 'end', text=proc['name'], 
                       values=(proc['pid'], f"{proc['memory_mb']:.1f}"))
    
    def periodic_update(self):
        """Periodic update of memory display"""
        self.update_memory_display()
        self.root.after(3000, self.periodic_update)  # Update every 3 seconds
    
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
    app = SimpleRamOptimizerGUI()
    app.run() 