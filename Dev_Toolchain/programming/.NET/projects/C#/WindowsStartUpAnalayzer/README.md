# 🚀 Windows 11 Startup Analyzer

A comprehensive Windows application that analyzes and optimizes your Windows 11 startup performance. Get detailed insights into what's slowing down your boot time and take action to optimize it.

![Windows 11](https://img.shields.io/badge/Windows-11-0078D4?style=flat-square&logo=windows&logoColor=white)
![.NET](https://img.shields.io/badge/.NET-8.0-512BD4?style=flat-square&logo=.net&logoColor=white)
![WPF](https://img.shields.io/badge/WPF-Windows%20Presentation%20Foundation-0078D4?style=flat-square)
![C#](https://img.shields.io/badge/C%23-239120?style=flat-square&logo=c-sharp&logoColor=white)

## ✨ Features

### 📊 **Comprehensive Startup Analysis**
- **Real-time monitoring** of all startup programs and services
- **Precise timing** - shows exact load time in seconds for each item
- **Smart ranking** - automatically sorts items from slowest to fastest
- **Total boot time calculation** - displays overall Windows 11 startup time

### 🔍 **Deep System Insights**
- **Startup Programs**: Registry entries, startup folders, scheduled tasks
- **Windows Services**: Service startup times and configurations
- **System Events**: Boot events from Windows Event Log
- **Performance Metrics**: CPU, memory, and disk usage analysis

### ⚡ **Optimization Tools**
- **Disable** unnecessary startup programs
- **Delay** startup programs by customizable time intervals
- **Configure** Windows service startup types
- **Safe optimization** - prevents disabling critical system components

### 🎯 **Advanced Filtering & Search**
- Filter by performance impact (High/Medium/Low)
- Search by program name, publisher, or location
- Real-time results with instant filtering

### 🛡️ **Safety Features**
- **Administrator privilege detection** and warnings
- **Critical system protection** - prevents disabling essential components
- **Confirmation dialogs** for potentially dangerous operations
- **Backup mechanisms** for disabled startup items

## 🖥️ Screenshots

### Main Interface
The application provides a clean, tabbed interface showing all startup items with their load times:

- **Startup Programs Tab**: Shows all programs that start with Windows
- **Services Tab**: Displays Windows services and their startup impact
- **System Events Tab**: Boot events and timing from Windows Event Log
- **Optimization Tips Tab**: AI-generated recommendations for improving boot time

### Key Information Displayed
- **Rank**: Performance impact ranking (1 = slowest)
- **Program/Service Name**: Clear identification of each item
- **Load Time**: Precise timing in seconds
- **Impact Level**: High/Medium/Low classification
- **Actions**: Disable, delay, or configure options

## 🚀 Quick Start

### Prerequisites
- **Windows 11** (required for full functionality)
- **.NET 8.0 Runtime** or later
- **Administrator privileges** (for optimization features)

### Installation & Setup

1. **Clone or Download the Project**
   ```bash
   git clone <repository-url>
   cd WindowsStartUpAnalayzer
   ```

2. **Restore Dependencies**
   ```bash
   dotnet restore
   ```

3. **Build the Application**
   ```bash
   dotnet build
   ```

4. **Run the Application**
   ```bash
   dotnet run
   ```

   **OR run the executable directly:**
   ```bash
   .\bin\Debug\net8.0-windows\Windows11StartupAnalyzer.exe
   ```

### 🔐 Administrator Requirements

For **full functionality**, run the application as Administrator:

1. Right-click on the executable or shortcut
2. Select "Run as administrator"
3. Accept the UAC prompt

**Why Administrator access is needed:**
- Reading Windows Event Logs
- Accessing system registry startup entries
- Modifying service configurations
- Creating/modifying scheduled tasks
- Disabling startup programs

## 📋 System Requirements

### Minimum Requirements
- **OS**: Windows 11 (any edition)
- **RAM**: 4 GB minimum, 8 GB recommended
- **Storage**: 100 MB free space
- **.NET**: 8.0 Runtime or SDK

### Recommended Requirements
- **OS**: Windows 11 with latest updates
- **RAM**: 8 GB or more
- **Storage**: SSD for best performance
- **Privileges**: Administrator access

## 🛠️ Development

### Project Structure
```
WindowsStartUpAnalayzer/
├── App.xaml/cs              # Application entry point
├── MainWindow.xaml/cs       # Main UI and logic
├── Models/                  # Data models
│   ├── StartupItem.cs       # Startup program model
│   ├── ServiceItem.cs       # Windows service model
│   └── SystemEvent.cs       # System event model
├── Services/                # Core analysis services
│   ├── StartupAnalysisService.cs    # Startup program analysis
│   ├── ServiceAnalysisService.cs    # Windows service analysis
│   ├── EventLogService.cs           # Event log monitoring
│   ├── PerformanceService.cs        # Performance monitoring
│   └── OptimizationService.cs       # Optimization operations
└── README.md               # This file
```

### Key Technologies Used
- **WPF (Windows Presentation Foundation)** - Modern Windows UI
- **System.Management** - WMI queries for system information
- **System.Diagnostics** - Performance counters and event logs
- **System.ServiceProcess** - Windows service management
- **Microsoft.Win32.Registry** - Registry access for startup items

### Building from Source

1. **Install .NET 8.0 SDK**
   ```bash
   # Download from https://dotnet.microsoft.com/download
   ```

2. **Clone the Repository**
   ```bash
   git clone <repository-url>
   cd WindowsStartUpAnalayzer
   ```

3. **Restore NuGet Packages**
   ```bash
   dotnet restore
   ```

4. **Build**
   ```bash
   dotnet build --configuration Release
   ```

5. **Run Tests** (if any)
   ```bash
   dotnet test
   ```

## 🔧 Usage Guide

### 1. **Initial Analysis**
   - Launch the application (preferably as Administrator)
   - Click "🔄 Refresh Analysis" to scan your system
   - Review the total startup time displayed at the top

### 2. **Understanding the Results**
   - **Rank**: Lower numbers = higher impact on boot time
   - **Load Time**: Actual time each item takes to start
   - **Impact**: High (>5s), Medium (1-5s), Low (<1s)
   - **Status**: Enabled, Disabled, Running, etc.

### 3. **Optimization Actions**
   - **Disable**: Completely prevent a program from starting
   - **Delay**: Start the program X seconds after login
   - **Configure**: Change Windows service startup type
   - **Info**: View detailed information about the item

### 4. **Safety Guidelines**
   - **Never disable** programs you don't recognize without research
   - **Keep antivirus** and security software enabled
   - **Test changes** - restart and verify system stability
   - **Create backups** before making major changes

## ⚠️ Important Notes

### Safety Considerations
- The application includes **built-in safety checks** to prevent disabling critical system components
- Always **research unfamiliar programs** before disabling them
- **Test system stability** after making changes
- Keep **antivirus and security software** enabled

### Performance Tips
- **Focus on high-impact items** (>5 seconds load time) first
- **Consider delaying** rather than disabling programs you occasionally need
- **Regular maintenance** - run the analysis monthly to catch new startup items
- **SSD upgrade** provides the biggest boot time improvement

### Troubleshooting
- **"Access Denied" errors**: Run as Administrator
- **Missing startup items**: Ensure Windows is fully booted before analysis
- **Incorrect timings**: Wait 2-3 minutes after boot before running analysis
- **Application won't start**: Ensure .NET 8.0 runtime is installed

## 📊 Understanding Startup Impact

### High Impact Items (>5 seconds)
- Usually large applications (Adobe products, Office suite)
- Antivirus/security software during initial scan
- Cloud sync services with large data sets
- **Action**: Consider disabling non-essential items

### Medium Impact Items (1-5 seconds)
- Most desktop applications
- Hardware drivers and utilities
- System tray applications
- **Action**: Consider delaying by 30-60 seconds

### Low Impact Items (<1 second)
- Windows system components
- Lightweight utilities
- Hardware monitoring tools
- **Action**: Generally safe to leave enabled

## 🤝 Contributing

Contributions are welcome! Please feel free to submit issues, feature requests, or pull requests.

### Development Setup
1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly on Windows 11
5. Submit a pull request

## 📄 License

This project is provided as-is for educational and personal use. Please ensure you comply with Windows terms of service when modifying system configurations.

## 🆘 Support

If you encounter issues:

1. **Check Prerequisites**: Ensure you have .NET 8.0 and Windows 11
2. **Run as Administrator**: Many features require elevated privileges
3. **Check Event Logs**: Windows Event Viewer may contain error details
4. **Create an Issue**: Report bugs with detailed system information

## 🎯 Future Enhancements

- **Startup time history tracking** and trends
- **Automatic optimization suggestions** based on usage patterns
- **System restore integration** for safer modifications
- **Export functionality** for startup configurations
- **Scheduled analysis** with email reports

---

**⚡ Optimize your Windows 11 startup time and enjoy faster boot speeds!**

*Built with ❤️ for Windows 11 users who value performance*