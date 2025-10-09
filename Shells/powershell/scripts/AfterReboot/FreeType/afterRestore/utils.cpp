#include "utils.h"
#include <windows.h>
#include <iostream>
#include <fstream>
#include <sstream>
#include <shellapi.h>
#include <shlobj.h>
#include <vector>
#include <iomanip>
#include <sstream>
#include <random>
#include <algorithm>
#include <cctype>
#include <rpc.h>

std::string executeCommand(const std::string& cmd) {
    std::string result;
    FILE* pipe = _popen(cmd.c_str(), "r");
    if (!pipe) {
        return "ERROR";
    }
    
    char buffer[4096];
    while (fgets(buffer, sizeof(buffer), pipe) != nullptr) {
        result += buffer;
    }
    
    _pclose(pipe);
    return result;
}

bool createDirectory(const std::string& path) {
    return CreateDirectoryA(path.c_str(), NULL) || GetLastError() == ERROR_ALREADY_EXISTS;
}

bool writeFile(const std::string& filePath, const std::string& content) {
    std::ofstream file(filePath, std::ios::binary);
    if (!file.is_open()) {
        return false;
    }
    
    file << content;
    file.close();
    return true;
}

bool fileExists(const std::string& filePath) {
    std::ifstream file(filePath);
    return file.good();
}

std::string getCurrentExecutablePath() {
    char buffer[MAX_PATH];
    GetModuleFileNameA(NULL, buffer, MAX_PATH);
    return std::string(buffer);
}

std::string generateGUID() {
    UUID uuid;
    UuidCreate(&uuid);
    
    RPC_CSTR str;
    UuidToStringA(&uuid, &str);
    
    std::string result = std::string((char*)str);
    RpcStringFreeA(&str);
    return result;
}

bool isRunningAsAdmin() {
    BOOL isAdmin = FALSE;
    PSID adminGroup = NULL;
    
    SID_IDENTIFIER_AUTHORITY ntAuthority = SECURITY_NT_AUTHORITY;
    if (AllocateAndInitializeSid(&ntAuthority, 2, 
                                SECURITY_BUILTIN_DOMAIN_RID, 
                                DOMAIN_ALIAS_RID_ADMINS, 
                                0, 0, 0, 0, 0, 0, 
                                &adminGroup)) {
        CheckTokenMembership(NULL, adminGroup, &isAdmin);
        FreeSid(adminGroup);
    }
    
    return isAdmin == TRUE;
}

// Simplified scheduled task creation using command line
bool createScheduledTask(const std::string& taskName, const std::string& taskPath) {
    // Just using command line approach for task creation
    std::string taskCommand = "schtasks /create /tn \"" + taskName + "\" /tr \"powershell.exe -ExecutionPolicy Bypass -NoProfile -File \\\"" + taskPath + "\\\"\" /sc ONLOGON /rl HIGHEST /f";
    std::string result = executeCommand(taskCommand);
    
    return result.find("ERROR") == std::string::npos && !result.empty();
}

std::vector<std::string> split(const std::string& str, char delimiter) {
    std::vector<std::string> tokens;
    std::stringstream ss(str);
    std::string token;
    
    while (std::getline(ss, token, delimiter)) {
        // Trim whitespace
        token.erase(0, token.find_first_not_of(" \t\r\n"));
        token.erase(token.find_last_not_of(" \t\r\n") + 1);
        if (!token.empty()) {
            tokens.push_back(token);
        }
    }
    
    return tokens;
}