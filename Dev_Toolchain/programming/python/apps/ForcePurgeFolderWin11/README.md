# ForcePurge - Advanced Windows File/Folder Deletion Tool

**Python 3.13 Optimized Force Deletion Application**

ForcePurge is a comprehensive Windows file and folder deletion tool that can delete ANY file or folder regardless of permissions, attributes, locks, or system protection. It uses multiple deletion strategies including Windows API calls, privilege escalation, process termination, and COM interfaces to ensure complete deletion.

## Features

- **Delete ANY file or folder** regardless of permissions, attributes, or locks
- **Handle long paths** (>260 characters) using `\\?\` prefix
- **Take ownership** of files using Windows security APIs
- **Remove all attributes** (read-only, hidden, system) using multiple methods
- **Terminate locking processes** using psutil to identify and kill processes
- **Enable Windows privileges** (SE_TAKE_OWNERSHIP, SE_BACKUP, SE_RESTORE, SE_DEBUG)
- **Multi-threaded parallel deletion** for maximum speed
- **Schedule stubborn files** for deletion on next reboot
- **Command-line interface** with verbose logging and dry-run mode
- **Comprehensive error handling** and logging
- **Python 3.13 optimized** with enhanced type hints and error messages

## Requirements

- **Windows 10/11** (64-bit recommended)
- **Python 3.13** or higher
- **Administrator privileges** (required for full functionality)
- **Dependencies**: `pywin32`, `psutil`, `comtypes`

## Installation

### Install Dependencies
```cmd
pip install pywin32 psutil comtypes
```

### Run Directly
```cmd
python app.py "C:\path\to\delete"
```

### Install as Package
```cmd
pip install -e .
```

## Usage

### Basic Usage
```cmd
python app.py "C:\path\to\delete"
```

### With Options
```cmd
python app.py "C:\path\to\delete" --verbose                    # Verbose logging
python app.py "C:\path\to\delete" --dry-run                   # Show what would be deleted
python app.py "C:\path\to\delete" --force-reboot              # Schedule for reboot deletion
python app.py "C:\path\to\delete" --force                     # Force system directory deletion
```

### Examples
```cmd
python app.py "C:\Unwanted\Directory"
python app.py "C:\file.txt" --verbose
python app.py "C:\stubborn_folder" --force-reboot
```

## Command Line Options

- `--verbose, -v`: Enable verbose logging
- `--dry-run`: Show what would be deleted without actually deleting
- `--force-reboot`: Schedule stubborn files for deletion on next reboot
- `--force`: Force deletion (required for system directories)

## Security Considerations

⚠️ **WARNING**: This tool can delete ANY file or folder, including system-critical files. Use with extreme caution:

- Always backup important data before use
- Test on non-critical directories first
- Use `--dry-run` flag to preview deletions
- System directories require `--force` flag for deletion
- Running as Administrator gives full system access

## How It Works

ForcePurge uses multiple deletion strategies in order of preference:

1. **Standard deletion** using `shutil.rmtree` with error handling
2. **Windows API calls** using `DeleteFileW` and `RemoveDirectoryW`
3. **COM interfaces** using `IFileOperation` for robust deletion
4. **Process termination** to kill locking processes
5. **Privilege escalation** to take ownership and remove attributes
6. **Reboot scheduling** for stubborn files that can't be deleted immediately

## Performance

- **Multi-threaded parallel deletion** for maximum speed
- **Batch operations** for efficient processing
- **Optimized Windows API calls** for native performance
- **Memory efficient** with streaming operations

## Dependencies

- `pywin32`: Windows API bindings and security functions
- `psutil`: Process management and system utilities
- `comtypes`: COM interface support for advanced operations
- Standard library: `ctypes`, `os`, `shutil`, `argparse`, `logging`, `threading`, `concurrent.futures`

## Python 3.13 Features Used

- Enhanced type hints and typing module
- Improved error messages and exception handling
- Better performance in concurrent operations
- Latest standard library optimizations

## Testing

Run unit tests:
```cmd
python test_forcepurge.py
```

## Packaging

Create standalone executable:
```cmd
pip install pyinstaller
pyinstaller forcepurge.spec
```

## Files Included

- `app.py`: Main application
- `setup.py`: Installation script
- `INSTALL.md`: Detailed installation guide
- `test_forcepurge.py`: Unit tests
- `forcepurge.spec`: PyInstaller spec file
- `README.md`: This documentation

## Troubleshooting

### Common Issues:

**"ModuleNotFoundError: No module named 'win32security'"**
- Solution: `pip install pywin32`

**"Access is denied" errors**
- Solution: Run as Administrator

**"Path too long" errors**
- Solution: The application handles long paths automatically

**"Permission denied" for system files**
- Solution: Use `--force` flag and run as Administrator

## License

MIT License - See LICENSE file for details.
