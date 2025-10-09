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
#include <tlhelp32.h>

#pragma comment(lib, "shlwapi.lib")
#pragma comment(lib, "advapi32.lib")
#pragma comment(lib, "userenv.lib")
#pragma comment(lib, "kernel32.lib")

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

BOOL MatchesAppInFile(const wchar_t* filePath, const wchar_t* appName);

void KillProcessesByNamePattern(const wchar_t* appName);

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

    // Extended registry locations to scan for thorough cleanup
    const wchar_t* registryPaths[] = {
        L"SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Uninstall",
        L"SOFTWARE\\WOW6432Node\\Microsoft\\Windows\\CurrentVersion\\Uninstall",
        L"SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Run",
        L"SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\RunOnce",
        L"SOFTWARE\\Classes",
        L"SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\App Paths",
        L"SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Explorer\\User Shell Folders",
        L"SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Policies\\Explorer\\Run",
        L"SOFTWARE\\WOW6432Node\\Microsoft\\Windows\\CurrentVersion\\Run",
        L"SOFTWARE\\WOW6432Node\\Microsoft\\Windows\\CurrentVersion\\RunOnce",
        L"SYSTEM\\CurrentControlSet\\Services",
        NULL
    };

    for (int i = 0; registryPaths[i] != NULL; i++) {
        ScanRegistryKeys(HKEY_LOCAL_MACHINE, registryPaths[i], appName, 2);
        ScanRegistryKeys(HKEY_CURRENT_USER, registryPaths[i], appName, 2);
    }
    
    // Additionally check for user-specific locations
    const wchar_t* userRegistryPaths[] = {
        L"Software\\Microsoft\\Windows\\CurrentVersion\\Run",
        L"Software\\Microsoft\\Windows\\CurrentVersion\\RunOnce",
        L"Software\\Microsoft\\Windows\\CurrentVersion\\Uninstall",
        NULL
    };
    
    for (int i = 0; userRegistryPaths[i] != NULL; i++) {
        ScanRegistryKeys(HKEY_CURRENT_USER, userRegistryPaths[i], appName, 2);
    }

    wprintf(L"Registry scan complete.\n");
}

BOOL ForceCloseProcessByImageName(const wchar_t* imageName) {
    wprintf(L"Attempting to force close processes matching: %s\n", imageName);
    
    HANDLE hSnapshot = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
    if (hSnapshot == INVALID_HANDLE_VALUE) {
        return FALSE;
    }

    PROCESSENTRY32W pe32;
    pe32.dwSize = sizeof(PROCESSENTRY32W);

    if (!Process32FirstW(hSnapshot, &pe32)) {
        CloseHandle(hSnapshot);
        return FALSE;
    }

    BOOL processesClosed = FALSE;
    do {
        if (MatchesAppName(pe32.szExeFile, imageName)) {
            if (pe32.th32ProcessID != GetCurrentProcessId()) { // Don't kill self
                HANDLE hProcess = OpenProcess(PROCESS_TERMINATE, FALSE, pe32.th32ProcessID);
                if (hProcess != NULL) {
                    if (TerminateProcess(hProcess, 1)) {
                        wprintf(L"Force closed process: %s (PID: %lu)\n", pe32.szExeFile, pe32.th32ProcessID);
                        processesClosed = TRUE;
                    } else {
                        wprintf(L"Failed to terminate process: %s (PID: %lu, Error: %lu)\n", pe32.szExeFile, pe32.th32ProcessID, GetLastError());
                    }
                    CloseHandle(hProcess);
                }
            }
        }
    } while (Process32NextW(hSnapshot, &pe32));

    CloseHandle(hSnapshot);
    return processesClosed;
}

void ForceStopService(const wchar_t* serviceName) {
    wprintf(L"Attempting to stop service: %s\n", serviceName);
    
    SC_HANDLE scManager = OpenSCManagerW(NULL, NULL, SC_MANAGER_ALL_ACCESS); // Changed to ALL_ACCESS for more control
    if (!scManager) {
        wprintf(L"Could not open service manager (error: %lu)\n", GetLastError());
        return;
    }

    SC_HANDLE service = OpenServiceW(scManager, serviceName, SERVICE_ALL_ACCESS);
    if (service) {
        SERVICE_STATUS_PROCESS status;
        DWORD bytesNeeded;
        
        // First, try to get the current status of the service
        if (QueryServiceStatusEx(service, SC_STATUS_PROCESS_INFO, (LPBYTE)&status, sizeof(SERVICE_STATUS_PROCESS), &bytesNeeded)) {
            if (status.dwCurrentState == SERVICE_STOPPED) {
                wprintf(L"Service %s is already stopped\n", serviceName);
                CloseServiceHandle(service);
                CloseServiceHandle(scManager);
                return;
            }
        }
        
        // Try to stop the service gracefully first
        if (ControlService(service, SERVICE_CONTROL_STOP, (LPSERVICE_STATUS)&status)) {
            wprintf(L"Sent stop command to service: %s\n", serviceName);
            
            // Wait for the service to stop gracefully
            DWORD startTime = GetTickCount();
            while (GetTickCount() - startTime < 5000) { // Wait up to 5 seconds
                Sleep(500);
                if (QueryServiceStatusEx(service, SC_STATUS_PROCESS_INFO, (LPBYTE)&status, sizeof(SERVICE_STATUS_PROCESS), &bytesNeeded)) {
                    if (status.dwCurrentState == SERVICE_STOPPED) {
                        wprintf(L"Service %s stopped successfully\n", serviceName);
                        CloseServiceHandle(service);
                        CloseServiceHandle(scManager);
                        return;
                    }
                }
            }
        }
        
        // If the service did not stop gracefully, try to pause it first, then stop
        if (status.dwCurrentState != SERVICE_STOPPED) {
            wprintf(L"Service %s did not stop gracefully, attempting to pause first...\n", serviceName);
            
            // Some services respond to pause command before stopping
            if (ControlService(service, SERVICE_CONTROL_PAUSE, (LPSERVICE_STATUS)&status)) {
                Sleep(1000); // Wait 1 second after pause
            }
            
            // Try to stop again after pause
            ControlService(service, SERVICE_CONTROL_STOP, (LPSERVICE_STATUS)&status);
            Sleep(2000); // Wait additional 2 seconds
            
            // Final check if service is stopped
            if (QueryServiceStatusEx(service, SC_STATUS_PROCESS_INFO, (LPBYTE)&status, sizeof(SERVICE_STATUS_PROCESS), &bytesNeeded)) {
                if (status.dwCurrentState == SERVICE_STOPPED) {
                    wprintf(L"Service %s stopped after pause attempt\n", serviceName);
                    CloseServiceHandle(service);
                    CloseServiceHandle(scManager);
                    return;
                }
            }
        }
        
        // If still not stopped, try to interrogate the service (sometimes this helps)
        if (status.dwCurrentState != SERVICE_STOPPED) {
            wprintf(L"Service %s still running, attempting to interrogate...\n", serviceName);
            ControlService(service, SERVICE_CONTROL_INTERROGATE, (LPSERVICE_STATUS)&status);
            Sleep(1000);
        }
        
        // If service is still not stopped, try to close the service handle and return
        wprintf(L"Service %s could not be stopped gracefully\n", serviceName);
        CloseServiceHandle(service);
    } else {
        wprintf(L"Could not open service %s (error: %lu)\n", serviceName, GetLastError());
    }

    CloseServiceHandle(scManager);
}

void ForceCloseAppServices(const wchar_t* appName) {
    wprintf(L"\n=== FORCE CLOSING APP SERVICES AND PROCESSES ===\n");

    SC_HANDLE scManager = OpenSCManagerW(NULL, NULL, SC_MANAGER_ALL_ACCESS);
    if (!scManager) {
        wprintf(L"No service access (may require admin, error: %lu).\n", GetLastError());
        return;
    }

    DWORD bytesNeeded = 0;
    DWORD servicesReturned = 0;
    DWORD resumeHandle = 0;

    // Get buffer size - try multiple times to ensure we get all services
    DWORD attempts = 0;
    while (attempts < 3) {
        if (EnumServicesStatusExW(scManager, SC_ENUM_PROCESS_INFO, SERVICE_WIN32 | SERVICE_DRIVER,
                              SERVICE_STATE_ALL, NULL, 0, &bytesNeeded,
                              &servicesReturned, &resumeHandle, NULL)) {
            break;  // No need to get buffer size, we'll try again with allocated buffer
        }
        if (GetLastError() != ERROR_MORE_DATA) {
            wprintf(L"Error getting service list (error: %lu), attempt %d\n", GetLastError(), attempts + 1);
            attempts++;
            Sleep(500);
            continue;
        }
        break;
    }

    BYTE* buffer = (BYTE*)malloc(bytesNeeded);
    if (!buffer) {
        wprintf(L"Could not allocate memory for service enumeration\n");
        CloseServiceHandle(scManager);
        return;
    }

    resumeHandle = 0; // Reset for actual enumeration
    if (EnumServicesStatusExW(scManager, SC_ENUM_PROCESS_INFO, SERVICE_WIN32 | SERVICE_DRIVER,
                              SERVICE_STATE_ALL, buffer, bytesNeeded,
                              &bytesNeeded, &servicesReturned, &resumeHandle, NULL)) {

        ENUM_SERVICE_STATUS_PROCESSW* services = (ENUM_SERVICE_STATUS_PROCESSW*)buffer;

        // First pass: Stop services that match the app name directly
        for (DWORD i = 0; i < servicesReturned && i < 2000; i++) { // Increased limit to 2000
            if (i % 100 == 0) {
                ShowHeartbeat(L"Scanning services for termination");
            }

            if (MatchesAppName(services[i].lpServiceName, appName) ||
                MatchesAppName(services[i].lpDisplayName, appName)) {

                wprintf(L"Found matching service: %s (Display: %s, Status: %lu)\n", 
                        services[i].lpServiceName, services[i].lpDisplayName, services[i].ServiceStatusProcess.dwCurrentState);
                ForceStopService(services[i].lpServiceName);
            }
        }
        
        // Second pass: Try to stop services that might be related even if not directly matching
        // This can help with Fortect services that may have different naming patterns
        for (DWORD i = 0; i < servicesReturned && i < 2000; i++) {
            if (i % 100 == 0) {
                ShowHeartbeat(L"Scanning services for termination");
            }

            // Additional check for related services (checking if service path contains app name)
            if (services[i].ServiceStatusProcess.dwCurrentState != SERVICE_STOPPED) {
                // Try to query the service configuration to get the binary path
                SC_HANDLE hService = OpenServiceW(scManager, services[i].lpServiceName, SERVICE_QUERY_CONFIG);
                if (hService) {
                    // Get buffer size needed for service configuration
                    DWORD needed = 0;
                    QueryServiceConfigW(hService, NULL, 0, &needed);
                    if (GetLastError() == ERROR_INSUFFICIENT_BUFFER) {
                        LPQUERY_SERVICE_CONFIGW config = (LPQUERY_SERVICE_CONFIGW)malloc(needed);
                        if (config) {
                            if (QueryServiceConfigW(hService, config, needed, &needed)) {
                                // Check if the binary path contains the app name (for Fortect-related services)
                                if (config->lpBinaryPathName && 
                                    (MatchesAppName(config->lpBinaryPathName, appName))) {
                                    wprintf(L"Found related service by path: %s (Path: %s)\n", 
                                            services[i].lpServiceName, config->lpBinaryPathName);
                                    ForceStopService(services[i].lpServiceName);
                                }
                            }
                            free(config);
                        }
                    }
                    CloseServiceHandle(hService);
                }
            }
        }
    } else {
        wprintf(L"Failed to enumerate services (error: %lu)\n", GetLastError());
    }

    free(buffer);
    CloseServiceHandle(scManager);
    
    // Also force close any matching processes with more aggressive approach
    ForceCloseProcessByImageName(appName);
    
    // Additional step: For Fortect-related services, try to kill processes by name pattern matching
    wprintf(L"Performing additional process termination for %s\n", appName);
    KillProcessesByNamePattern(appName);
}

// Additional function to kill processes by name pattern matching
void KillProcessesByNamePattern(const wchar_t* appName) {
    HANDLE hSnapshot = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
    if (hSnapshot == INVALID_HANDLE_VALUE) {
        return;
    }

    PROCESSENTRY32W pe32;
    pe32.dwSize = sizeof(PROCESSENTRY32W);

    if (!Process32FirstW(hSnapshot, &pe32)) {
        CloseHandle(hSnapshot);
        return;
    }

    do {
        if (pe32.th32ProcessID != 0 && pe32.th32ProcessID != GetCurrentProcessId()) {
            // Enhanced matching - check various patterns that might relate to Fortect
            if (MatchesAppName(pe32.szExeFile, appName) ||
                MatchesAppName(pe32.szExeFile, L"Fortect") ||  // Specifically look for Fortect
                wcsstr(pe32.szExeFile, L"forti") ||  // Common pattern in Fortinet/Fortect
                wcsstr(pe32.szExeFile, L"forti") ||
                wcsstr(pe32.szExeFile, L"service") ||
                wcsstr(pe32.szExeFile, L"agent") ||
                wcsstr(pe32.szExeFile, L"daemon")) {
                
                HANDLE hProcess = OpenProcess(PROCESS_TERMINATE | PROCESS_QUERY_INFORMATION | PROCESS_VM_READ, FALSE, pe32.th32ProcessID);
                if (hProcess != NULL) {
                    // Get full image name to confirm it's related to the app
                    wchar_t processPath[MAX_PATH];
                    DWORD pathSize = MAX_PATH;
                    if (QueryFullProcessImageNameW(hProcess, 0, processPath, &pathSize)) {
                        // Create a temporary copy for case-insensitive comparison
                        wchar_t tempPath[MAX_PATH];
                        wcscpy_s(tempPath, MAX_PATH, processPath);
                        CharUpperW(tempPath); // Convert to uppercase using Windows API
                        
                        if (MatchesAppName(processPath, appName) ||
                            MatchesAppName(processPath, L"Fortect") ||
                            wcsstr(tempPath, L"FORTI")) { // Check if path contains Forti-related strings
                            
                            wprintf(L"Force terminating process: %s (PID: %lu) at %s\n", 
                                    pe32.szExeFile, pe32.th32ProcessID, processPath);
                                    
                            if (TerminateProcess(hProcess, 1)) {
                                wprintf(L"Successfully terminated: %s\n", pe32.szExeFile);
                                Sleep(100); // Brief pause to allow process to terminate
                            } else {
                                wprintf(L"Failed to terminate process: %s (Error: %lu)\n", pe32.szExeFile, GetLastError());
                                
                                // Try alternative termination methods
                                HANDLE hToken = NULL;
                                if (OpenProcessToken(hProcess, TOKEN_ADJUST_PRIVILEGES | TOKEN_QUERY, &hToken)) {
                                    TOKEN_PRIVILEGES tp;
                                    LookupPrivilegeValueW(NULL, L"SeDebugPrivilege", &tp.Privileges[0].Luid);
                                    tp.PrivilegeCount = 1;
                                    tp.Privileges[0].Attributes = SE_PRIVILEGE_ENABLED;
                                    AdjustTokenPrivileges(hToken, FALSE, &tp, sizeof(tp), NULL, NULL);
                                    CloseHandle(hToken);
                                    
                                    // Try again with elevated privileges
                                    if (TerminateProcess(hProcess, 1)) {
                                        wprintf(L"Terminated after privilege escalation: %s\n", pe32.szExeFile);
                                    }
                                }
                            }
                        }
                    }
                    CloseHandle(hProcess);
                }
            }
        }
    } while (Process32NextW(hSnapshot, &pe32));

    CloseHandle(hSnapshot);
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
            // Don't skip hidden/system directories if they match the app name - scan them too
            if (ShouldSkipDirectory(fullPath, appName) && !MatchesAppName(findData.cFileName, appName)) {
                continue; // Skip system directories that don't match app name
            }
            
            if (MatchesAppName(findData.cFileName, appName)) {
                PrintProgress(L"FOUND-DIR", fullPath);
                DeleteDirectoryRecursive(fullPath, appName);
                // Don't recurse into deleted directory
            } else {
                // Recurse into directory with depth limit - even if it's hidden or system
                ScanAndClean(fullPath, appName, maxDepth - 1);
            }
        } else {
            g_stats.filesScanned++;
            // Check for app name matches in filename
            if (MatchesAppName(findData.cFileName, appName)) {
                PrintProgress(L"DELETE-FILE", fullPath);
                ForceDeleteFile(fullPath);
            } else {
                // Also check file contents for app references in common text-based files
                wchar_t* ext = wcsrchr(findData.cFileName, L'.');
                if (ext != NULL) {
                    // Check common config files that might contain app references
                    if (wcsicmp(ext, L".ini") == 0 || wcsicmp(ext, L".cfg") == 0 || 
                        wcsicmp(ext, L".txt") == 0 || wcsicmp(ext, L".log") == 0 ||
                        wcsicmp(ext, L".xml") == 0 || wcsicmp(ext, L".json") == 0) {
                        
                        // Read a portion of the file to check if it contains app name
                        if (MatchesAppInFile(fullPath, appName)) {
                            PrintProgress(L"DELETE-CONFIG-FILE", fullPath);
                            ForceDeleteFile(fullPath);
                        }
                    }
                }
            }
        }
    } while (FindNextFileW(hFind, &findData));

    FindClose(hFind);
}

// Helper function to check if a text file contains app name
BOOL MatchesAppInFile(const wchar_t* filePath, const wchar_t* appName) {
    HANDLE hFile = CreateFileW(filePath, GENERIC_READ, FILE_SHARE_READ, NULL, 
                               OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, NULL);
    if (hFile == INVALID_HANDLE_VALUE) {
        return FALSE;
    }

    DWORD fileSize = GetFileSize(hFile, NULL);
    if (fileSize == INVALID_FILE_SIZE || fileSize > 10 * 1024 * 1024) { // Limit to 10MB
        CloseHandle(hFile);
        return FALSE;
    }

    // Allocate buffer to read the beginning and end of the file
    DWORD readSize = min(fileSize, 10240); // Read up to 10KB
    char* buffer = (char*)malloc(readSize + 1);
    if (buffer == NULL) {
        CloseHandle(hFile);
        return FALSE;
    }

    DWORD bytesRead;
    BOOL found = FALSE;

    // Read beginning of file
    if (ReadFile(hFile, buffer, readSize, &bytesRead, NULL) && bytesRead > 0) {
        buffer[bytesRead] = '\0';
        
        // Convert to wide char for comparison
        wchar_t* wideBuffer = (wchar_t*)malloc((bytesRead + 1) * sizeof(wchar_t));
        if (wideBuffer) {
            MultiByteToWideChar(CP_UTF8, 0, buffer, bytesRead, wideBuffer, bytesRead);
            wideBuffer[bytesRead] = L'\0';
            
            if (MatchesAppName(wideBuffer, appName)) {
                found = TRUE;
            }
            free(wideBuffer);
        }
    }
    
    // If not found in beginning, also check end of file if it's large
    if (!found && fileSize > readSize) {
        SetFilePointer(hFile, fileSize - readSize, NULL, FILE_BEGIN);
        if (ReadFile(hFile, buffer, readSize, &bytesRead, NULL) && bytesRead > 0) {
            buffer[bytesRead] = '\0';
            
            // Convert to wide char for comparison
            wchar_t* wideBuffer = (wchar_t*)malloc((bytesRead + 1) * sizeof(wchar_t));
            if (wideBuffer) {
                MultiByteToWideChar(CP_UTF8, 0, buffer, bytesRead, wideBuffer, bytesRead);
                wideBuffer[bytesRead] = L'\0';
                
                if (MatchesAppName(wideBuffer, appName)) {
                    found = TRUE;
                }
                free(wideBuffer);
            }
        }
    }

    free(buffer);
    CloseHandle(hFile);
    return found;
}

void DeepClean(const wchar_t* appName) {
    wprintf(L"\n========================================\n");
    wprintf(L"DEEP UNINSTALL: %ls\n", appName);
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
    wprintf(L"CLEANUP COMPLETE: %ls (%lu seconds)\n", appName, appElapsed);
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

int main(int argc, char* argv[]) {
    // Convert ANSI args to wide chars for compatibility with existing code
    wchar_t** wargv = (wchar_t**)malloc(argc * sizeof(wchar_t*));
    for (int i = 0; i < argc; i++) {
        size_t len = strlen(argv[i]);
        wargv[i] = (wchar_t*)malloc((len + 1) * sizeof(wchar_t));
        mbstowcs(wargv[i], argv[i], len + 1);
    }

    SetConsoleOutputCP(CP_UTF8);

    wprintf(L"\n");
    wprintf(L"╔════════════════════════════════════════════════════════════╗\n");
    wprintf(L"║        DEEP UNINSTALLER - Ultimate Application Remover     ║\n");
    wprintf(L"║                    C: Drive Only - v1.0                    ║\n");
    wprintf(L"╚════════════════════════════════════════════════════════════╝\n\n");

    if (!IsRunningAsAdmin()) {
        wprintf(L"[ERROR] This application requires Administrator privileges!\n");
        wprintf(L"Please run as Administrator.\n\n");
        // Free allocated memory before returning
        for (int i = 0; i < argc; i++) {
            free(wargv[i]);
        }
        free(wargv);
        return 1;
    }

    if (argc < 2) {
        wprintf(L"Usage: deep_uninstaller <AppName1> <AppName2> <AppName3> ...\n\n");
        wprintf(L"Example: deep_uninstaller Firefox Chrome Discord\n\n");
        wprintf(L"This will deeply uninstall the specified applications from C: drive,\n");
        wprintf(L"removing ALL files, directories, registry entries, and services.\n\n");
        // Free allocated memory before returning
        for (int i = 0; i < argc; i++) {
            free(wargv[i]);
        }
        free(wargv);
        return 1;
    }

    wprintf(L"WARNING: This will PERMANENTLY DELETE all traces of the following applications:\n");
    for (int i = 1; i < argc; i++) {
        wprintf(L"  - %ls\n", wargv[i]);  // Use wide string format specifier
    }
    wprintf(L"\nThis action CANNOT be undone!\n");
    wprintf(L"Starting in 3 seconds... Press Ctrl+C to cancel.\n\n");
    Sleep(3000);

    DWORD startTime = GetTickCount();

    for (int i = 1; i < argc; i++) {
        DeepClean(wargv[i]);
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
    
    // Free allocated memory
    for (int i = 0; i < argc; i++) {
        free(wargv[i]);
    }
    free(wargv);
    
    return 0;
}