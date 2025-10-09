# -*- mode: python ; coding: utf-8 -*-

"""
PyInstaller spec file for ForcePurge - Advanced Windows File/Folder Deletion Tool
This spec file optimizes the executable creation with proper Windows API support
"""

import sys
from PyInstaller.utils.hooks import collect_submodules, collect_data_files
from PyInstaller.building.build_main import Analysis
from PyInstaller.building.api import PYZ, EXE

# Collect all necessary hidden imports
hiddenimports = [
    # Windows-specific modules
    'win32timezone',
    'win32security', 
    'win32file',
    'win32api',
    'win32con',
    'win32service',
    'win32process',
    'win32gui',
    'win32console',
    'pywintypes',
    'pythoncom',
    
    # Process management
    'psutil',
    'psutil._psutil_windows',
    'psutil._pswindows',
    
    # COM interface support
    'comtypes',
    'comtypes.client',
    'comtypes.gen',
    'comtypes.shell',
    'comtypes.server',
    'comtypes.typeinfo',
    
    # Standard library modules that might be imported dynamically
    'ctypes',
    'ctypes.wintypes',
    'logging',
    'argparse',
    'tempfile',
    'threading',
    'concurrent.futures',
    'os',
    'sys',
    'time',
    'shutil',
    'subprocess',
    'pathlib',
    'typing',
]

# Additional binary files to include
binaries = []

# Data files to include
datas = []

# Exclude unnecessary modules to reduce size
excludes = [
    'tkinter',
    'matplotlib',
    'numpy',
    'scipy',
    'pandas',  # If accidentally included
    'IPython',
    'jupyter',
    'notebook',
    'pytest',
    'unittest',
]

# Analysis object - analyzes the script and its dependencies
a = Analysis(
    ['app.py'],  # Main script
    pathex=[],  # Additional paths to search for modules
    binaries=binaries,  # Additional binary files
    datas=datas,  # Additional data files
    hiddenimports=hiddenimports,  # Hidden imports
    hookspath=[],  # Additional hook paths
    hooksconfig={},  # Hook configuration
    runtime_hooks=[],  # Runtime hooks
    excludes=excludes,  # Modules to exclude
    win_no_prefer_redirects=False,
    win_private_assemblies=False,
    cipher=None,  # No encryption
    noarchive=False,
)

# Remove Python bytecode files to reduce size
a.datas = [(x[0], x[1], x[2]) for x in a.datas if not x[0].endswith('.pyc')]

# Create PYZ archive (frozen Python bytecode)
pyz = PYZ(a.pure, a.zipped_data, cipher=None)

# Executable configuration
exe = EXE(
    pyz,  # PYZ archive
    a.scripts, # Script files
    a.binaries,  # Binary files
    a.zipfiles,  # ZIP files
    a.datas,  # Data files
    [],
    name='forcepurge',  # Output executable name
    debug=False,  # Disable debug mode
    bootloader_ignore_signals=False,
    strip=False,
    upx=True,  # Use UPX compression if available
    upx_exclude=[],
    runtime_tmpdir=None,
    console=True,  # Keep console window (command line tool)
    disable_windowed_traceback=False,
    argv_emulation=False,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
    icon=None,  # Add icon path here if available
)

# Alternative executable for GUI version (without console)
# gui_exe = EXE(
#     pyz,
#     a.scripts,
#     a.binaries,
#     a.zipfiles,
#     a.datas,
#     [],
#     name='forcepurge_gui',
#     debug=False,
#     bootloader_ignore_signals=False,
#     strip=False,
#     upx=True,
#     upx_exclude=[],
#     runtime_tmpdir=None,
#     console=False,  # No console window
#     disable_windowed_traceback=False,
#     argv_emulation=False,
#     target_arch=None,
#     codesign_identity=None,
#     entitlements_file=None,
#     icon='icon.ico',  # Add icon if available
# )
