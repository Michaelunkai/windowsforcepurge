===============================================================================
                    DEEP UNINSTALLER - Ultimate App Remover
                           Version 1.0 - C: Drive Only
===============================================================================

DESCRIPTION:
  This is the most comprehensive Windows application uninstaller available.
  It performs a DEEP clean of applications, removing:
  - All files and folders matching the app name
  - All registry entries (HKLM and HKCU)
  - All Windows services
  - Locked files (scheduled for deletion on reboot)
  - All user profile data

  It searches through:
  - C:\Program Files
  - C:\Program Files (x86)
  - C:\ProgramData
  - C:\Users (all user profiles)
  - C:\ root (with depth limit)

  SAFETY: Protected system directories are excluded to prevent Windows damage.

REQUIREMENTS:
  - Windows 7 or later
  - Administrator privileges (REQUIRED)
  - C: drive only (other drives are protected)

USAGE:
  deep_uninstaller.exe <AppName1> <AppName2> <AppName3> ...

EXAMPLES:
  deep_uninstaller.exe Firefox
  deep_uninstaller.exe Chrome Discord "Visual Studio"
  deep_uninstaller.exe Steam Epic Uplay Origin

FEATURES:
  ✓ Real-time progress display
  ✓ Statistics tracking (files, dirs, registry, services)
  ✓ Force deletion with reboot scheduling for locked files
  ✓ Case-insensitive matching
  ✓ Partial name matching (finds all related files)
  ✓ Service detection and removal
  ✓ Complete registry cleanup
  ✓ User profile cleanup

NOTES:
  - App names are matched as substrings (case-insensitive)
  - ALL matching files will be deleted - be specific with names
  - Locked files will be deleted on next reboot
  - This action CANNOT be undone
  - Creates no backups - deletions are permanent

WARNING:
  This tool is EXTREMELY powerful. It will delete EVERYTHING matching
  the application name. Double-check the app name before running!

PROTECTED AREAS (Safe from deletion):
  - Windows\System32
  - Windows\SysWOW64
  - Windows\WinSxS
  - Windows\Boot
  - Critical system files (NTLDR, BOOTMGR, pagefile.sys, etc.)
  - Non-C: drives

EXIT CODES:
  0 = Success
  1 = Error (missing admin rights or invalid arguments)

===============================================================================
             Developed for maximum uninstall thoroughness
                     Use responsibly - No warranty
===============================================================================