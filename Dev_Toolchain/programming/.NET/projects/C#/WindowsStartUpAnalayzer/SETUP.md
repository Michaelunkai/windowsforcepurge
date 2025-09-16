# 🛠️ Setup Guide - Windows 11 Startup Analyzer

This guide will help you set up and run the Windows 11 Startup Analyzer on your system.

## 📋 Prerequisites

### System Requirements
- ✅ **Windows 11** (any edition)
- ✅ **.NET 8.0 Runtime** or SDK
- ✅ **Administrator privileges** (recommended for full functionality)
- ✅ **4+ GB RAM** (8+ GB recommended)
- ✅ **100 MB free disk space**

## 🚀 Quick Setup (5 minutes)

### Option 1: Using Pre-built Release
1. **Download the latest release** from the releases section
2. **Extract the zip file** to your preferred location
3. **Right-click** on `Windows11StartupAnalyzer.exe`
4. **Select "Run as administrator"**
5. **Click "Yes"** on the UAC prompt
6. **Done!** The application will start analyzing your startup

### Option 2: Building from Source

#### Step 1: Install .NET 8.0
```bash
# Download .NET 8.0 from Microsoft
# Visit: https://dotnet.microsoft.com/download/dotnet/8.0
# Download and install the SDK (recommended) or Runtime
```

#### Step 2: Verify Installation
```bash
dotnet --version
# Should show 8.0.x or higher
```

#### Step 3: Clone/Download Project
```bash
# Clone with Git (if available)
git clone <repository-url>
cd WindowsStartUpAnalayzer

# OR download ZIP and extract to desired folder
```

#### Step 4: Restore Dependencies
```bash
# Navigate to project folder
cd WindowsStartUpAnalayzer

# Restore NuGet packages
dotnet restore
```

#### Step 5: Build the Application
```bash
# Build in Release mode for optimal performance
dotnet build --configuration Release

# OR build in Debug mode for development
dotnet build
```

#### Step 6: Run the Application
```bash
# Method 1: Using dotnet run (requires admin privileges)
dotnet run

# Method 2: Run the executable directly
.\bin\Release\net8.0-windows\Windows11StartupAnalyzer.exe

# Method 3: Debug build
.\bin\Debug\net8.0-windows\Windows11StartupAnalyzer.exe
```

## 🔐 Administrator Privileges Setup

### Why Administrator Access is Required
The application needs elevated privileges to:
- **Read Windows Event Logs** for boot timing
- **Access Registry** startup entries
- **Query System Services** and their configurations
- **Modify Startup Settings** for optimization
- **Create Scheduled Tasks** for delayed startup

### How to Run as Administrator

#### Method 1: Right-Click Context Menu
1. **Locate** the `Windows11StartupAnalyzer.exe` file
2. **Right-click** on the executable
3. **Select** "Run as administrator"
4. **Click "Yes"** when prompted by UAC

#### Method 2: Command Prompt as Admin
1. **Press** `Win + X`
2. **Select** "Windows Terminal (Admin)" or "Command Prompt (Admin)"
3. **Navigate** to the project folder:
   ```cmd
   cd "F:\study\Dev_Toolchain\programming\.net\projects\C#\WindowsStartUpAnalyzer"
   ```
4. **Run** the application:
   ```cmd
   dotnet run
   ```

#### Method 3: Create Admin Shortcut
1. **Right-click** on `Windows11StartupAnalyzer.exe`
2. **Select** "Create shortcut"
3. **Right-click** the shortcut → "Properties"
4. **Click** "Advanced..." in the Shortcut tab
5. **Check** "Run as administrator"
6. **Click** "OK" → "OK"

## 🔧 Troubleshooting Setup Issues

### .NET Runtime Issues
```bash
# Error: "The framework 'Microsoft.NETCore.App', version '8.0.x' was not found"
# Solution: Install .NET 8.0 Runtime from Microsoft's website
```

### Permission Errors
```
# Error: "Access to the path 'xyz' is denied"
# Solution: Run as Administrator or check file permissions
```

### Missing Dependencies
```bash
# Error: Package restore failed
# Solution: Clear NuGet cache and restore
dotnet nuget locals all --clear
dotnet restore
```

### Build Errors
```bash
# Error: Compilation failed
# Solution: Clean and rebuild
dotnet clean
dotnet build
```

### Application Won't Start
1. **Check .NET version**: `dotnet --version`
2. **Verify Windows 11**: The app is optimized for Windows 11
3. **Run as Administrator**: Required for full functionality
4. **Check Windows Event Viewer**: Look for application errors

## 📁 Project Structure After Setup

```
WindowsStartUpAnalayzer/
├── 📄 README.md                 # Main documentation
├── 📄 SETUP.md                  # This setup guide
├── 📄 .gitignore               # Git ignore rules
├── 📄 Windows11StartupAnalyzer.csproj  # Project file
├── 📄 app.manifest             # Admin privileges manifest
├── 📄 App.xaml                 # Application definition
├── 📄 App.xaml.cs             # Application code-behind
├── 📄 MainWindow.xaml          # Main window UI
├── 📄 MainWindow.xaml.cs       # Main window logic
├── 📁 Models/                  # Data models
│   ├── 📄 StartupItem.cs       # Startup program model
│   ├── 📄 ServiceItem.cs       # Windows service model
│   └── 📄 SystemEvent.cs       # System event model
├── 📁 Services/                # Core services
│   ├── 📄 StartupAnalysisService.cs    # Startup analysis
│   ├── 📄 ServiceAnalysisService.cs    # Service analysis
│   ├── 📄 EventLogService.cs           # Event log reading
│   ├── 📄 PerformanceService.cs        # Performance monitoring
│   └── 📄 OptimizationService.cs       # Optimization features
├── 📁 bin/                     # Built executables (after build)
└── 📁 obj/                     # Build intermediate files
```

## ✅ Verification Steps

After setup, verify everything works:

1. **Launch** the application as Administrator
2. **Check** that the total startup time appears at the top
3. **Verify** tabs load data:
   - ✅ Startup Programs tab shows programs
   - ✅ Services tab shows Windows services  
   - ✅ System Events tab shows boot events
   - ✅ Optimization Tips tab shows recommendations
4. **Test** functionality:
   - ✅ Filtering and search work
   - ✅ Refresh button updates data
   - ✅ Info buttons show details

## 🎯 First Run Recommendations

1. **Wait 2-3 minutes** after Windows boot before running analysis
2. **Close unnecessary applications** for accurate timing
3. **Run "Refresh Analysis"** to get current data
4. **Review high-impact items** (>5 seconds) first
5. **Research unfamiliar programs** before disabling

## 🆘 Getting Help

If you encounter issues during setup:

1. **Check Prerequisites** - Ensure .NET 8.0 and Windows 11
2. **Review Error Messages** - Note exact error text
3. **Check Windows Event Logs** - Look for application errors
4. **Try Safe Mode** - Run without optimizations first
5. **Create an Issue** - Report problems with system details

## 🚀 Ready to Optimize!

Once setup is complete, you're ready to:
- **Analyze** your Windows 11 startup performance
- **Identify** programs slowing down your boot
- **Optimize** startup times safely
- **Monitor** improvements over time

**Happy optimizing! 🎯**