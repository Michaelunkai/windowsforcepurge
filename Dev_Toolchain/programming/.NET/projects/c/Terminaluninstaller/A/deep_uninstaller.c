#define _WIN32_WINNT 0x0601
#define UNICODE
#define _UNICODE

#include <windows.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <wchar.h>
#include <shlwapi.h>
#include <userenv.h>

#pragma comment(lib, "shlwapi.lib")
#pragma comment(lib, "advapi32.lib")
#pragma comment(lib, "userenv.lib")

// Progress tracking
typedef struct {
    DWORD filesScanned;
    DWORD filesDeleted;
    DWORD directoriesDeleted;
    DWORD registryKeysDeleted;
    DWORD servicesDeleted;
    DWORD pendingOperations;
    DWORD lastProgressTick;
    DWORD operationCounter;
} ProgressStats;

ProgressStats g_stats = {0};

void ShowHeartbeat(const wchar_t* operation) {
    DWORD currentTick = GetTickCount();
    if (currentTick - g_stats.lastProgressTick >= 3000) { // Every 3 seconds
        wprintf(L"[ACTIVE] %s... [%lu ops | %lu files | %lu deleted | %lu dirs | %lu reg | %lu svc]\n",
                operation, g_stats.operationCounter, g_stats.filesScanned,
                g_stats.filesDeleted, g_stats.directoriesDeleted,
                g_stats.registryKeysDeleted, g_stats.servicesDeleted);
        fflush(stdout);
        g_stats.lastProgressTick = currentTick;
    }
}

// Protected system directories and patterns
const wchar_t* PROTECTED_PATHS[] = {
    L"\\Windows\\System32",
    L"\\Windows\\SysWOW64",
    L"\\Windows\\WinSxS",
    L"\\Windows\\Boot",
    L"\\Windows\\Fonts",
    L"\\Windows\\Resources",
    L"\\Program Files\\Windows",
    L"\\Program Files (x86)\\Windows",
    NULL
};

// Directories to skip (rarely contain app data, waste time)
const wchar_t* SKIP_DIRS[] = {
    L"\\Windows\\assembly",
    L"\\Windows\\Installer",
    L"\\System Volume Information",
    L"\\$Recycle.Bin",
    L"\\Windows\\WinSxS",
    NULL
};

// Forward declaration
BOOL MatchesAppName(const wchar_t* path, const wchar_t* appName);

BOOL ShouldSkipDirectory(const wchar_t* path, const wchar_t* appName) {
    wchar_t upperPath[MAX_PATH * 2];
    wcscpy_s(upperPath, MAX_PATH * 2, path);
    CharUpperW(upperPath);

    // Check if this directory matches the app name - if so, DON'T skip it
    if (MatchesAppName(path, appName)) {
        return FALSE;
    }

    // Only skip system directories that never contain app data
    for (int i = 0; SKIP_DIRS[i] != NULL; i++) {
        wchar_t skipUpper[MAX_PATH];
        wcscpy_s(skipUpper, MAX_PATH, SKIP_DIRS[i]);
        CharUpperW(skipUpper);
        if (wcsstr(upperPath, skipUpper) != NULL) {
            return TRUE;
        }
    }
    return FALSE;
}

void PrintProgress(const wchar_t* action, const wchar_t* target) {
    wprintf(L"[%lu files | %lu deleted | %lu dirs | %lu reg | %lu svc | %lu pending] %s: %s\n",
            g_stats.filesScanned, g_stats.filesDeleted, g_stats.directoriesDeleted,
            g_stats.registryKeysDeleted, g_stats.servicesDeleted, g_stats.pendingOperations,
            action, target);
    fflush(stdout);
}

BOOL IsProtectedPath(const wchar_t* path) {
    wchar_t upperPath[MAX_PATH * 2];
    wcscpy_s(upperPath, MAX_PATH * 2, path);
    CharUpperW(upperPath);

    // Check if it's on C: drive only
    if (upperPath[0] != L'C' || upperPath[1] != L':') {
        return TRUE; // Protect non-C drives
    }

    for (int i = 0; PROTECTED_PATHS[i] != NULL; i++) {
        wchar_t protectedUpper[MAX_PATH];
        wcscpy_s(protectedUpper, MAX_PATH, PROTECTED_PATHS[i]);
        CharUpperW(protectedUpper);

        if (wcsstr(upperPath, protectedUpper) != NULL) {
            return TRUE;
        }
    }

    // Protect critical system files
    if (wcsstr(upperPath, L"\\NTLDR") || wcsstr(upperPath, L"\\BOOTMGR") ||
        wcsstr(upperPath, L"\\PAGEFILE.SYS") || wcsstr(upperPath, L"\\HIBERFIL.SYS")) {
        return TRUE;
    }

    return FALSE;
}

BOOL MatchesAppName(const wchar_t* path, const wchar_t* appName) {
    wchar_t upperPath[MAX_PATH * 2];
    wchar_t upperApp[MAX_PATH];

    wcscpy_s(upperPath, MAX_PATH * 2, path);
    wcscpy_s(upperApp, MAX_PATH, appName);

    CharUpperW(upperPath);
    CharUpperW(upperApp);

    return wcsstr(upperPath, upperApp) != NULL;
}

void ScheduleDeleteOnReboot(const wchar_t* path) {
    if (MoveFileExW(path, NULL, MOVEFILE_DELAY_UNTIL_REBOOT)) {
        g_stats.pendingOperations++;
        PrintProgress(L"REBOOT-DELETE", path);
    } else {
        wprintf(L"[ERROR] Failed to schedule reboot deletion: %s (Error: %lu)\n", path, GetLastError());
    }
}

BOOL ForceDeleteFile(const wchar_t* filePath) {
    g_stats.filesScanned++;

    // Try to remove read-only, hidden, system attributes
    DWORD attrs = GetFileAttributesW(filePath);
    if (attrs != INVALID_FILE_ATTRIBUTES) {
        SetFileAttributesW(filePath, FILE_ATTRIBUTE_NORMAL);
    }

    if (DeleteFileW(filePath)) {
        g_stats.filesDeleted++;
        return TRUE;
    }

    DWORD error = GetLastError();
    if (error == ERROR_ACCESS_DENIED || error == ERROR_SHARING_VIOLATION) {
        // File is in use, schedule for reboot
        ScheduleDeleteOnReboot(filePath);
        return TRUE;
    }

    return FALSE;
}

BOOL ForceDeleteDirectory(const wchar_t* dirPath) {
    if (RemoveDirectoryW(dirPath)) {
        g_stats.directoriesDeleted++;
        return TRUE;
    }

    DWORD error = GetLastError();
    if (error == ERROR_ACCESS_DENIED || error == ERROR_SHARING_VIOLATION ||
        error == ERROR_DIR_NOT_EMPTY) {
        ScheduleDeleteOnReboot(dirPath);
        return TRUE;
    }

    return FALSE;
}

void DeleteDirectoryRecursive(const wchar_t* path, const wchar_t* appName) {
    WIN32_FIND_DATAW findData;
    wchar_t searchPath[MAX_PATH * 2];
    wchar_t fullPath[MAX_PATH * 2];

    if (IsProtectedPath(path)) {
        return;
    }

    swprintf_s(searchPath, MAX_PATH * 2, L"%s\\*", path);
    HANDLE hFind = FindFirstFileW(searchPath, &findData);

    if (hFind == INVALID_HANDLE_VALUE) {
        return;
    }

    do {
        ShowHeartbeat(L"Deep cleaning directory");

        if (wcscmp(findData.cFileName, L".") == 0 || wcscmp(findData.cFileName, L"..") == 0) {
            continue;
        }

        swprintf_s(fullPath, MAX_PATH * 2, L"%s\\%s", path, findData.cFileName);

        if (IsProtectedPath(fullPath)) {
            continue;
        }

        if (findData.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY) {
            DeleteDirectoryRecursive(fullPath, appName);
        } else {
            if (MatchesAppName(fullPath, appName)) {
                PrintProgress(L"DELETE-FILE", fullPath);
                ForceDeleteFile(fullPath);
            }
        }
    } while (FindNextFileW(hFind, &findData));

    FindClose(hFind);

    // Try to remove the directory itself if it matches
    if (MatchesAppName(path, appName)) {
        PrintProgress(L"DELETE-DIR", path);
        ForceDeleteDirectory(path);
    }
}

void ScanRegistryKeys(HKEY hRootKey, const wchar_t* subKey, const wchar_t* appName, int maxDepth) {
    if (maxDepth <= 0) return;

    HKEY hKey;
    if (RegOpenKeyExW(hRootKey, subKey, 0, KEY_READ, &hKey) != ERROR_SUCCESS) {
        return;
    }

    DWORD index = 0;
    wchar_t keyName[256];
    DWORD keyNameSize;
    int keysChecked = 0;

    // Enumerate subkeys - limit to 2000 keys per level
    while (keysChecked < 2000) {
        keyNameSize = 256;
        if (RegEnumKeyExW(hKey, index, keyName, &keyNameSize, NULL, NULL, NULL, NULL) != ERROR_SUCCESS) {
            break;
        }

        if (MatchesAppName(keyName, appName)) {
            // Found matching key - delete it
            wchar_t fullSubKey[512];
            swprintf_s(fullSubKey, 512, L"%s\\%s", subKey, keyName);
            
            // Close current key before deleting
            RegCloseKey(hKey);
            
            // Try to delete the matching key
            HKEY hParent;
            if (RegOpenKeyExW(hRootKey, subKey, 0, KEY_WRITE, &hParent) == ERROR_SUCCESS) {
                if (RegDeleteTreeW(hParent, keyName) == ERROR_SUCCESS) {
                    g_stats.registryKeysDeleted++;
                    PrintProgress(L"DELETE-REGKEY", fullSubKey);
                }
                RegCloseKey(hParent);
            }
            
            // Reopen to continue enumeration
            if (RegOpenKeyExW(hRootKey, subKey, 0, KEY_READ, &hKey) != ERROR_SUCCESS) {
                return;
            }
            // Don't increment index after delete
        } else {
            index++;
        }
        
        keysChecked++;
        if (keysChecked % 100 == 0) {
            ShowHeartbeat(L"Scanning registry");
        }
    }

    RegCloseKey(hKey);
}

void CleanRegistry(const wchar_t* appName) {
    wprintf(L"\n=== REGISTRY CLEANUP ===\n");

    // Only scan specific, targeted registry locations
    const wchar_t* registryPaths[] = {
        L"SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Uninstall",
        L"SOFTWARE\\WOW6432Node\\Microsoft\\Windows\\CurrentVersion\\Uninstall",
        L"SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Run",
        L"SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\RunOnce",
        NULL
    };

    for (int i = 0; registryPaths[i] != NULL; i++) {
        ScanRegistryKeys(HKEY_LOCAL_MACHINE, registryPaths[i], appName, 2);
        ScanRegistryKeys(HKEY_CURRENT_USER, registryPaths[i], appName, 2);
    }

    wprintf(L"Registry scan complete.\n");
}

void StopAndDeleteService(const wchar_t* appName) {
    wprintf(L"\n=== SERVICE CLEANUP ===\n");

    SC_HANDLE scManager = OpenSCManagerW(NULL, NULL, SC_MANAGER_ALL_ACCESS);
    if (!scManager) {
        wprintf(L"No service access (may require admin).\n");
        return;
    }

    DWORD bytesNeeded = 0;
    DWORD servicesReturned = 0;
    DWORD resumeHandle = 0;

    // Get buffer size
    EnumServicesStatusExW(scManager, SC_ENUM_PROCESS_INFO, SERVICE_WIN32,
                          SERVICE_STATE_ALL, NULL, 0, &bytesNeeded,
                          &servicesReturned, &resumeHandle, NULL);

    BYTE* buffer = (BYTE*)malloc(bytesNeeded);
    if (!buffer) {
        CloseServiceHandle(scManager);
        return;
    }

    if (EnumServicesStatusExW(scManager, SC_ENUM_PROCESS_INFO, SERVICE_WIN32,
                              SERVICE_STATE_ALL, buffer, bytesNeeded, &bytesNeeded,
                              &servicesReturned, &resumeHandle, NULL)) {

        ENUM_SERVICE_STATUS_PROCESSW* services = (ENUM_SERVICE_STATUS_PROCESSW*)buffer;

        for (DWORD i = 0; i < servicesReturned && i < 1000; i++) { // Limit to 1000 services
            if (i % 100 == 0) {
                ShowHeartbeat(L"Scanning services");
            }

            if (MatchesAppName(services[i].lpServiceName, appName) ||
                MatchesAppName(services[i].lpDisplayName, appName)) {

                SC_HANDLE service = OpenServiceW(scManager, services[i].lpServiceName,
                                                  SERVICE_ALL_ACCESS);
                if (service) {
                    // Stop the service
                    SERVICE_STATUS status;
                    ControlService(service, SERVICE_CONTROL_STOP, &status);

                    // Wait a bit for it to stop
                    Sleep(500);

                    // Delete the service
                    if (DeleteService(service)) {
                        g_stats.servicesDeleted++;
                        PrintProgress(L"DELETE-SERVICE", services[i].lpServiceName);
                    }

                    CloseServiceHandle(service);
                }
            }
        }
    }

    free(buffer);
    CloseServiceHandle(scManager);
}

void ScanAndClean(const wchar_t* basePath, const wchar_t* appName, int maxDepth) {
    WIN32_FIND_DATAW findData;
    wchar_t searchPath[MAX_PATH * 2];
    wchar_t fullPath[MAX_PATH * 2];

    if (IsProtectedPath(basePath) || ShouldSkipDirectory(basePath, appName) || maxDepth <= 0) {
        return;
    }

    swprintf_s(searchPath, MAX_PATH * 2, L"%s\\*", basePath);
    HANDLE hFind = FindFirstFileW(searchPath, &findData);

    if (hFind == INVALID_HANDLE_VALUE) {
        return;
    }

    do {
        if (g_stats.operationCounter++ % 100 == 0) {
            ShowHeartbeat(L"Scanning filesystem");
        }

        if (wcscmp(findData.cFileName, L".") == 0 || wcscmp(findData.cFileName, L"..") == 0) {
            continue;
        }

        swprintf_s(fullPath, MAX_PATH * 2, L"%s\\%s", basePath, findData.cFileName);

        if (IsProtectedPath(fullPath)) {
            continue;
        }

        if (findData.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY) {
            // Skip hidden/system directories unless they match app name
            if ((findData.dwFileAttributes & (FILE_ATTRIBUTE_HIDDEN | FILE_ATTRIBUTE_SYSTEM)) &&
                !MatchesAppName(findData.cFileName, appName)) {
                continue;
            }
            
            if (ShouldSkipDirectory(fullPath, appName)) {
                continue; // Skip only system directories
            }
            
            if (MatchesAppName(findData.cFileName, appName)) {
                PrintProgress(L"FOUND-DIR", fullPath);
                DeleteDirectoryRecursive(fullPath, appName);
                // Don't recurse into deleted directory
            } else {
                // Recurse into directory with depth limit
                ScanAndClean(fullPath, appName, maxDepth - 1);
            }
        } else {
            g_stats.filesScanned++;
            if (MatchesAppName(findData.cFileName, appName)) {
                PrintProgress(L"DELETE-FILE", fullPath);
                ForceDeleteFile(fullPath);
            }
        }
    } while (FindNextFileW(hFind, &findData));

    FindClose(hFind);
}

void DeepClean(const wchar_t* appName) {
    wprintf(L"\n========================================\n");
    wprintf(L"DEEP UNINSTALL: %s\n", appName);
    wprintf(L"========================================\n\n");

    DWORD appStartTime = GetTickCount();
    DWORD timeout = 3 * 60 * 1000; // 3 minutes per app MAX

    // Get user profile directory for targeted scanning
    wchar_t userProfile[MAX_PATH];
    DWORD size = MAX_PATH;
    GetEnvironmentVariableW(L"USERPROFILE", userProfile, size);

    // Build targeted user paths
    wchar_t userAppData[MAX_PATH];
    wchar_t userLocalAppData[MAX_PATH];
    wchar_t userRoaming[MAX_PATH];
    wchar_t userTemp[MAX_PATH];
    wchar_t userStartMenu[MAX_PATH];
    swprintf_s(userAppData, MAX_PATH, L"%s\\AppData", userProfile);
    swprintf_s(userLocalAppData, MAX_PATH, L"%s\\AppData\\Local", userProfile);
    swprintf_s(userRoaming, MAX_PATH, L"%s\\AppData\\Roaming", userProfile);
    swprintf_s(userTemp, MAX_PATH, L"%s\\AppData\\Local\\Temp", userProfile);
    swprintf_s(userStartMenu, MAX_PATH, L"%s\\AppData\\Roaming\\Microsoft\\Windows\\Start Menu", userProfile);

    // Targeted scan paths - most specific first
    const wchar_t* searchPaths[] = {
        L"C:\\Program Files",
        L"C:\\Program Files (x86)",
        L"C:\\ProgramData",
        userLocalAppData,      // AppData\Local
        userRoaming,           // AppData\Roaming
        userTemp,              // Temp folder
        userStartMenu,         // Start Menu shortcuts
        userProfile,           // User root (for .cargo, .rustup, etc)
        L"C:\\Windows\\Temp",  // System temp
        NULL
    };

    wprintf(L"=== FILE SYSTEM CLEANUP ===\n");
    for (int i = 0; searchPaths[i] != NULL; i++) {
        if (GetTickCount() - appStartTime > timeout) {
            wprintf(L"\n[TIMEOUT] Reached 3 minute limit for %s - moving to cleanup\n", appName);
            break;
        }
        wprintf(L"\nScanning: %s\n", searchPaths[i]);
        
        // Optimized depth: shallow for system dirs, deeper for user dirs
        int depth;
        if (i < 3) {
            depth = 5;  // Program Files, ProgramData - 5 levels max
        } else if (i < 7) {
            depth = 4;  // AppData Local/Roaming, Temp, Start Menu - 4 levels
        } else if (i == 7) {
            depth = 3;  // User profile root - 3 levels (catches .cargo, .rustup and subdirs)
        } else {
            depth = 3;  // Windows\Temp - 3 levels
        }
        
        ScanAndClean(searchPaths[i], appName, depth);
    }

    // Clean registry (fast operation)
    wprintf(L"\n=== REGISTRY CLEANUP ===\n");
    if (GetTickCount() - appStartTime <= timeout) {
        CleanRegistry(appName);
    }

    // Stop and delete services (fast operation)
    wprintf(L"\n=== SERVICE CLEANUP ===\n");
    if (GetTickCount() - appStartTime <= timeout) {
        StopAndDeleteService(appName);
    }

    DWORD appElapsed = (GetTickCount() - appStartTime) / 1000;

    wprintf(L"\n========================================\n");
    wprintf(L"CLEANUP COMPLETE: %s (%lu seconds)\n", appName, appElapsed);
    wprintf(L"  Files Scanned: %lu\n", g_stats.filesScanned);
    wprintf(L"  Files Deleted: %lu\n", g_stats.filesDeleted);
    wprintf(L"  Directories Deleted: %lu\n", g_stats.directoriesDeleted);
    wprintf(L"  Registry Keys/Values Deleted: %lu\n", g_stats.registryKeysDeleted);
    wprintf(L"  Services Deleted: %lu\n", g_stats.servicesDeleted);
    wprintf(L"  Pending Reboot Operations: %lu\n", g_stats.pendingOperations);
    wprintf(L"========================================\n\n");

    // Reset stats for next app
    memset(&g_stats, 0, sizeof(ProgressStats));
}

BOOL IsRunningAsAdmin() {
    BOOL isAdmin = FALSE;
    PSID adminGroup = NULL;
    SID_IDENTIFIER_AUTHORITY ntAuthority = SECURITY_NT_AUTHORITY;

    if (AllocateAndInitializeSid(&ntAuthority, 2, SECURITY_BUILTIN_DOMAIN_RID,
                                  DOMAIN_ALIAS_RID_ADMINS, 0, 0, 0, 0, 0, 0, &adminGroup)) {
        CheckTokenMembership(NULL, adminGroup, &isAdmin);
        FreeSid(adminGroup);
    }

    return isAdmin;
}

int wmain(int argc, wchar_t* argv[]) {
    SetConsoleOutputCP(CP_UTF8);

    wprintf(L"\n");
    wprintf(L"╔════════════════════════════════════════════════════════════╗\n");
    wprintf(L"║        DEEP UNINSTALLER - Ultimate Application Remover     ║\n");
    wprintf(L"║                    C: Drive Only - v1.0                    ║\n");
    wprintf(L"╚════════════════════════════════════════════════════════════╝\n\n");

    if (!IsRunningAsAdmin()) {
        wprintf(L"[ERROR] This application requires Administrator privileges!\n");
        wprintf(L"Please run as Administrator.\n\n");
        return 1;
    }

    if (argc < 2) {
        wprintf(L"Usage: %s <AppName1> <AppName2> <AppName3> ...\n\n", argv[0]);
        wprintf(L"Example: %s Firefox Chrome Discord\n\n", argv[0]);
        wprintf(L"This will deeply uninstall the specified applications from C: drive,\n");
        wprintf(L"removing ALL files, directories, registry entries, and services.\n\n");
        return 1;
    }

    wprintf(L"WARNING: This will PERMANENTLY DELETE all traces of the following applications:\n");
    for (int i = 1; i < argc; i++) {
        wprintf(L"  - %s\n", argv[i]);
    }
    wprintf(L"\nThis action CANNOT be undone!\n");
    wprintf(L"Starting in 3 seconds... Press Ctrl+C to cancel.\n\n");
    Sleep(3000);

    DWORD startTime = GetTickCount();

    for (int i = 1; i < argc; i++) {
        DeepClean(argv[i]);
    }

    DWORD endTime = GetTickCount();
    DWORD elapsedSeconds = (endTime - startTime) / 1000;

    wprintf(L"\n╔════════════════════════════════════════════════════════════╗\n");
    wprintf(L"║                   ALL OPERATIONS COMPLETE                  ║\n");
    wprintf(L"╚════════════════════════════════════════════════════════════╝\n\n");
    wprintf(L"Time elapsed: %lu seconds\n", elapsedSeconds);

    if (g_stats.pendingOperations > 0) {
        wprintf(L"\n[!] REBOOT REQUIRED to complete deletion of locked files.\n");
        wprintf(L"    %lu file/directory operations are pending.\n\n", g_stats.pendingOperations);
    }

    wprintf(L"\nAll specified applications have been purged from C: drive.\n\n");
    return 0;
}