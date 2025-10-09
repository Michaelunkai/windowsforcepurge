"""
Setup script for ForcePurge - Advanced Windows File/Folder Deletion Tool
"""
from setuptools import setup, find_packages

setup(
    name="forcepurge",
    version="1.0.0",
    description="Advanced Windows File/Folder Force Deletion Tool optimized for Python 3.13",
    long_description="""
ForcePurge is a comprehensive Windows file and folder deletion tool that can delete ANY file or folder 
regardless of permissions, attributes, locks, or system protection. It uses multiple deletion strategies 
including Windows API calls, privilege escalation, process termination, and COM interfaces to ensure 
complete deletion.

Features:
- Delete files and folders regardless of permissions, attributes, or locks
- Handle long paths (>260 characters) using \\?\\ prefix
- Take ownership of files using Windows security APIs
- Remove read-only, hidden, and system attributes
- Terminate processes that are locking files
- Enable necessary Windows privileges (SE_TAKE_OWNERSHIP, SE_BACKUP, SE_RESTORE, SE_DEBUG)
- Multi-threaded parallel deletion for maximum speed
- Schedule stubborn files for deletion on next reboot
- Command-line interface with verbose logging and dry-run mode
- Comprehensive error handling and logging
    """,
    author="ForcePurge Team",
    author_email="forcepurge@example.com",
    url="https://github.com/forcepurge/forcepurge",
    packages=find_packages(),
    install_requires=[
        "pywin32>=306; sys_platform == 'win32'",  # Windows-specific APIs
        "psutil>=5.9.0",  # Process management
        "comtypes>=1.1.10; sys_platform == 'win32'",  # COM interface support
    ],
    python_requires=">=3.13",
    entry_points={
        'console_scripts': [
            'forcepurge=app:main',
        ],
    },
    classifiers=[
        "Development Status :: 5 - Production/Stable",
        "Intended Audience :: System Administrators",
        "License :: OSI Approved :: MIT License",
        "Operating System :: Microsoft :: Windows",
        "Programming Language :: Python :: 3.13",
        "Topic :: System :: Filesystems",
        "Topic :: System :: Systems Administration",
        "Topic :: Utilities",
    ],
    keywords="windows file deletion force remove admin system",
    license="MIT",
)
