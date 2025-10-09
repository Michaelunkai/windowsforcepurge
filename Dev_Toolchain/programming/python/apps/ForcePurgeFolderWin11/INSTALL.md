# ForcePurge Installation Guide

## System Requirements

- **Windows 10/11** (64-bit recommended)
- **Python 3.13** or higher
- **Administrator privileges** (required for full functionality)
- **Visual Studio C++ Build Tools** (for compiling dependencies)

## Python 3.13 Installation

### Option 1: Official Python Website
1. Download Python 3.13 from [python.org](https://www.python.org/downloads/)
2. During installation, ensure you check "Add Python to PATH"
3. Verify installation: `python --version`

### Option 2: Using Package Managers

**Using Chocolatey:**
```cmd
choco install python -version 3.13
```

**Using Scoop:**
```cmd
scoop install python313
```

## Required Dependencies

ForcePurge requires the following Python packages:

- `pywin32` - Windows API bindings
- `psutil` - Process and system utilities  
- `comtypes` - COM interface support
- Standard library modules (included with Python)

## Installation Methods

### Method 1: Direct Installation (Recommended)

```cmd
# Install required packages
pip install pywin32 psutil comtypes

# Run the application directly
python app.py "C:\path\to\delete"
```

### Method 2: Using setup.py

```cmd
# Install in development mode
pip install -e .

# Or install normally
pip install .

# Run the application
forcepurge "C:\path\to\delete"
```

### Method 3: Virtual Environment (Recommended for Development)

```cmd
# Create virtual environment
python -m venv forcepurge-env

# Activate virtual environment
forcepurge-env\Scripts\activate

# Upgrade pip
python -m pip install --upgrade pip

# Install dependencies
pip install pywin32 psutil comtypes

# Run the application
python app.py "C:\path\to\delete"
```

## Installing PyInstaller for Executable Creation

To create a standalone executable:

```cmd
pip install pyinstaller
```

## Creating Standalone Executable

```cmd
# Basic executable
pyinstaller --onefile app.py

# With additional options for Windows GUI/console
pyinstaller --onefile --windowed --icon=icon.ico app.py

# With hidden imports for Windows modules
pyinstaller --onefile --hidden-import=win32timezone --hidden-import=win32security --hidden-import=win32file app.py
```

## PyInstaller Spec File (Advanced)

Create `forcepurge.spec` for advanced packaging:

```python
# forcepurge.spec
# -*- mode: python ; coding: utf-8 -*-

block_cipher = None

a = Analysis(
    ['app.py'],
    pathex=[],
    binaries=[],
    datas=[],
    hiddenimports=[
        'win32timezone',
        'win32security', 
        'win32file',
        'win32api',
        'win32con',
        'win32service',
        'psutil',
        'comtypes',
        'comtypes.shell',
        'comtypes.gen'
    ],
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=[],
    win_no_prefer_redirects=False,
    win_private_assemblies=False,
    cipher=block_cipher,
    noarchive=False,
)

pyz = PYZ(a.pure, a.zipped_data, cipher=block_cipher)

exe = EXE(
    pyz,
    a.scripts,
    a.binaries,
    a.zipfiles,
    a.datas,
    [],
    name='forcepurge',
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=True,
    upx_exclude=[],
    runtime_tmpdir=None,
    console=True,
    disable_windowed_traceback=False,
    argv_emulation=False,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
    icon=None  # Add icon path here if available
)
```

Build with: `pyinstaller forcepurge.spec`

## Verification Steps

1. **Check Python version:**
   ```cmd
   python --version
   # Should show Python 3.13.x
   ```

2. **Verify dependencies:**
   ```cmd
   python -c "import win32security, win32file, win32api, psutil, comtypes; print('All dependencies available')"
   ```

3. **Test basic functionality:**
   ```cmd
   python app.py --help
   ```

## Troubleshooting

### Common Issues:

**"ModuleNotFoundError: No module named 'win32security'"**
- Solution: `pip install pywin32`
- Run: `python Scripts/pywin32_postinstall.py -install` (if needed)

**"Access is denied" errors**
- Solution: Run as Administrator
- Right-click Command Prompt → "Run as administrator"

**"Path too long" errors**
- Solution: The application handles long paths automatically using \\?\ prefix

**"Permission denied" for system files**
- Solution: Use --force flag for system directories
- Ensure running with Administrator privileges

## Security Considerations

⚠️ **WARNING**: This tool can delete ANY file or folder, including system-critical files. Use with extreme caution:

- Always backup important data before use
- Test on non-critical directories first
- Use --dry-run flag to preview deletions
- System directories require --force flag for deletion
- Running as Administrator gives full system access

## Python 3.13 Specific Features Used

- Enhanced type hints and typing module
- Improved error messages and exception handling
- Better performance in concurrent operations
- Latest standard library optimizations
