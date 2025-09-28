# Laptop Driver Updater

A comprehensive, automated driver update tool specifically designed for ASUS laptops with AMD CPUs and NVIDIA GPUs. This application automatically detects your hardware, finds the latest drivers, and installs them with minimal user intervention.

## Features

🔍 **Automatic Hardware Detection**
- Detects ASUS laptop model
- Identifies AMD CPU and GPU components  
- Recognizes NVIDIA GPU specifications
- Gathers system information for compatibility

⚡ **Intelligent Driver Management**
- Checks current driver versions
- Finds latest available drivers from official sources
- Compares versions to identify updates needed
- Downloads drivers directly from manufacturer websites

🚀 **Automated Installation**
- Silent driver installation with minimal user interaction
- Supports NVIDIA graphics drivers
- Handles AMD CPU chipset and GPU drivers  
- Installs ASUS-specific utilities and system drivers
- Creates system restore points before installation

🖥️ **User-Friendly Interface**
- Modern GUI with progress tracking
- Command-line interface for advanced users
- Detailed logging and error reporting
- Scan-only mode to check for updates without installing

## Supported Hardware

### ASUS Laptops
- All ASUS laptop models with automatic model detection
- ASUS-specific utilities (MyASUS, Armoury Crate, etc.)
- System Control Interface drivers
- Battery and power management utilities

### NVIDIA Graphics
- RTX 40 Series (4090, 4080, 4070, 4060)
- RTX 30 Series (3090, 3080, 3070, 3060)  
- RTX 20 Series (2080, 2070, 2060)
- GTX 16 Series (1660, 1650)
- GTX 10 Series (1080, 1070, 1060, 1050)
- Mobile/Laptop variants supported

### AMD Components
- Ryzen 9, 7, 5, 3 processors
- AMD Radeon graphics (RX 7000, 6000, 5000 series)
- AMD Chipset drivers
- AMD Software Adrenalin Edition

## Quick Start

### 1. Download and Setup
```bash
# Download the application to your desired folder
# Navigate to the folder and run:
setup.bat
```

### 2. Run the Application

**GUI Mode (Recommended)**
```bash
run_gui.bat
```

**Command Line Mode**
```bash
run_cli.bat
```

**Scan Only (Check for updates without installing)**
```bash
run_scan.bat
```

## Installation Guide

### Prerequisites
- Windows 10/11 (64-bit)
- Python 3.8 or later
- Administrator privileges (recommended for driver installation)
- Internet connection

### Automated Setup
1. Download all files to a folder (e.g., `C:\LaptopDrivers`)
2. Right-click `setup.bat` and select "Run as administrator"
3. Follow the on-screen instructions
4. The setup will:
   - Check Python installation
   - Create a virtual environment
   - Install all required packages

### Manual Setup
If you prefer manual installation:

```bash
# Create virtual environment
python -m venv venv

# Activate virtual environment
venv\Scripts\activate.bat

# Install requirements
pip install -r requirements.txt

# Run the application
python main.py
```

## Usage

### GUI Mode
1. Run `run_gui.bat` (preferably as administrator)
2. The application will automatically detect your hardware
3. Click "Scan for Updates" to check for new drivers
4. Select the drivers you want to install
5. Click "Install Selected Updates"
6. Monitor progress in the GUI
7. Restart when prompted

### CLI Mode
1. Run `run_cli.bat` (preferably as administrator)
2. The application will automatically:
   - Detect hardware
   - Check for updates
   - Display available updates
   - Ask for confirmation
   - Install selected updates

### Command Line Options
```bash
python main.py --help                    # Show help
python main.py --no-gui                  # Run in CLI mode
python main.py --auto-install            # Auto-install without confirmation
python main.py --log-level DEBUG         # Set logging level
```

## Configuration

The application uses a configuration file at `config/settings.json`. Key settings include:

```json
{
  "auto_install": false,
  "create_restore_point": true,
  "download_directory": "./downloads",
  "install_timeout": 1800,
  "nvidia": {
    "install_hd_audio_driver": true,
    "perform_clean_install": false
  },
  "amd": {
    "install_chipset_drivers": true,
    "minimal_install": false
  },
  "asus": {
    "install_utilities": true,
    "install_bios_updates": false
  }
}
```

## Safety Features

- **System Restore Points**: Automatically created before driver installation
- **Driver Signature Verification**: Only installs signed drivers
- **BIOS Update Safety**: BIOS updates require manual confirmation
- **Rollback Support**: System restore available if issues occur
- **Comprehensive Logging**: Detailed logs for troubleshooting

## Troubleshooting

### Common Issues

**"Permission Denied" Error**
- Run as administrator
- Disable antivirus temporarily during installation

**"Hardware Not Detected"**
- Ensure you're running on a supported ASUS laptop
- Check Windows Device Manager for hardware visibility

**"Download Failed"**
- Check internet connection
- Verify firewall/proxy settings
- Try running at a different time (servers may be busy)

**"Installation Failed"**
- Run as administrator
- Close other applications
- Temporarily disable antivirus
- Check available disk space

### Log Files
- Main log: `logs/driver_updater.log`
- Error log: `logs/errors.log`
- Configuration: `config/settings.json`

## File Structure

```
LaptopDrivers/
├── main.py                 # Main application entry point
├── requirements.txt        # Python dependencies
├── setup.bat              # Automated setup script
├── run_gui.bat            # GUI launcher
├── run_cli.bat            # CLI launcher  
├── run_scan.bat           # Scan-only launcher
├── README.md              # This file
├── modules/               # Core application modules
│   ├── hardware_detector.py
│   ├── driver_checker.py
│   ├── nvidia_handler.py
│   ├── amd_handler.py
│   ├── asus_handler.py
│   ├── config_manager.py
│   └── logger_setup.py
├── gui/                   # GUI components
│   └── main_window.py
├── config/               # Configuration files
│   └── settings.json
├── logs/                 # Log files
├── downloads/            # Downloaded drivers
└── venv/                 # Python virtual environment
```

## Advanced Usage

### Custom Configuration
Edit `config/settings.json` to customize behavior:
- Download directory
- Installation timeouts  
- Driver selection preferences
- Network proxy settings

### Scheduled Updates
Use Windows Task Scheduler to run automatic scans:
```bash
# Create a scheduled task to run scan weekly
schtasks /create /tn "Driver Update Scan" /tr "C:\path\to\run_scan.bat" /sc weekly
```

### Integration with Other Tools
The application can be integrated with:
- System monitoring tools
- Automated deployment systems
- IT management platforms

## Contributing

This is a specialized tool for ASUS laptops with AMD/NVIDIA hardware. If you encounter issues or have suggestions:

1. Check the log files for detailed error information
2. Ensure you're running on supported hardware
3. Verify you have administrator privileges
4. Test with the latest version

## Disclaimer

- **Use at your own risk**: Driver installation can affect system stability
- **Create backups**: Always backup important data before driver updates
- **System restore recommended**: The tool creates restore points, but manual backups are advised
- **BIOS updates**: Require manual installation for safety reasons
- **Compatibility**: Designed specifically for ASUS laptops with AMD/NVIDIA hardware

## License

This software is provided as-is for personal use. Driver packages are downloaded from official manufacturer websites and are subject to their respective licenses and terms of service.

---

**Last Updated**: 2025-09-28
**Version**: 1.0.0
**Compatibility**: Windows 10/11, ASUS Laptops, AMD CPUs, NVIDIA GPUs
