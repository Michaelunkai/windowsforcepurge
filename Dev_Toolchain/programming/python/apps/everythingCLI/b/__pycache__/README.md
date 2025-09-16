# Everything CLI

A command-line version of the popular "Everything" file search tool for Windows. This CLI application scans files and directories on the C drive only, sorts them by size (largest to smallest), and displays the 1000 heaviest files and folders. Safe-to-delete files are highlighted in green for improved usability.

## Features

- 🔍 **C Drive Only Scanning** - Scans files and directories on the C drive only for safety
- 📊 **Size-based sorting** - Shows largest files first to help identify space usage
- 📈 **Top 1000 Heaviest Items** - Displays the 1000 heaviest files and folders with full details
- 🗑️ **Force delete functionality** - Safely delete files and directories with confirmation
- ⌨️ **Interactive navigation** - Use arrow keys for smooth browsing
- 🖥️ **Safety highlighting** - Safe-to-delete files are shown in GREEN
- 🔄 **Real-time updates** - Rescan functionality to refresh the file list
- ⚡ **Multithreaded scanning** - Fast performance on large filesystems

## Installation

### Prerequisites
- Python 3.6 or higher
- pip (Python package installer)

### Quick Start (Windows)
1. Double-click `run.bat` to install dependencies and start the application
2. The application will automatically scan your system and display files

### Manual Installation
1. Install required dependencies:
   ```bash
   pip install -r requirements.txt
   ```

2. Run the application:
   ```bash
   python everything_cli.py
   ```

## Usage

### Basic Commands

- **Arrow Keys (↑/↓)** - Navigate through the file list
- **'d'** - Delete the currently selected file/folder
- **'r'** - Rescan files (refresh the list)
- **'q'** - Quit the application
- **'c'** - Calculate directory size (for selected directory)

### Command Line Options

```bash
# Scan C drive (default)
python everything_cli.py

# Force simple mode (no arrow key navigation)
python everything_cli.py --simple

# Get help
python everything_cli.py --help
```

### Interface Modes

1. **Interactive Mode** (default if keyboard library is available)
   - Real-time arrow key navigation
   - Immediate response to keystrokes
   - Best user experience

2. **Simple Mode** (fallback or forced with --simple)
   - Text-based menu system
   - Type commands and press Enter
   - Works without additional dependencies

## Safety Features

- **Green highlighting** - Safe-to-delete files are shown in green
- **Confirmation required** - Type "DELETE" to confirm file deletion
- **Error handling** - Gracefully handles permission errors and inaccessible files
- **Non-destructive scanning** - Read-only operations during file discovery
- **Interrupt support** - Ctrl+C safely stops scanning or operation

## Display Format

```
================================================================================
EVERYTHING CLI - File Manager (Sorted by Size)
================================================================================
Total items: 1,234 | Current: 1
Threads: 8 | Min size:      0B
Navigation: Up/Down arrows, 'd'=delete, 'q'=quit, 'r'=rescan, 'c'=calc dir
NOTE: Files shown in GREEN are safe to delete
--------------------------------------------------------------------------------
→ [DEL] [FILE] 1.5GB | C:\Users\Username\Videos\large_video.mp4
  [    ] [DIR ] 850MB | C:\Program Files\Large Application
  [    ] \033[92m[FILE] 650MB | C:\Users\Username\Downloads\temp_file.tmp\033[0m
  [    ] \033[92m[FILE] 425MB | C:\Users\Username\Desktop\old_backup.zip\033[0m
```

## Performance Notes

- **Initial scan time**: Depends on the number of files on your system
- **Directory size calculation**: May take longer for directories with many files
- **Memory usage**: Stores file information in memory for fast navigation
- **Interrupt anytime**: Press Ctrl+C during scanning to stop

## Troubleshooting

### Common Issues

1. **"keyboard module not found"**
   - Run: `pip install keyboard`
   - Or use `--simple` flag to run without interactive mode

2. **Permission errors during scanning**
   - Normal behavior - protected files are skipped automatically
   - Run as administrator for complete system access

3. **Slow directory size calculation**
   - Large directories with many files take time to calculate
   - Size calculation is accurate but may be slow for huge directories

4. **Python not found**
   - Install Python 3.6+ from python.org
   - Add Python to your system PATH

## Technical Details

- **Language**: Python 3.6+
- **Dependencies**: keyboard (optional, for interactive mode)
- **File size calculation**: Uses os.path.getsize() and os.walk()
- **Sorting algorithm**: Python's built-in Timsort (stable, efficient)
- **Safety features**: ANSI color codes for safe file highlighting
- **Scan limitation**: Restricted to C drive for improved safety

## License

This project is open source. Feel free to modify and distribute.

## Contributing

To add features or fix bugs:
1. Fork the repository
2. Make your changes
3. Test thoroughly
4. Submit a pull request

## Version History

- **v2.0** - Consolidated version with enhanced safety features
  - Single-file implementation
  - Green highlighting for safe-to-delete files
  - Multithreaded scanning for better performance
  - Always restricted to C drive for safety
  - Display top 1000 heaviest items with full details