#ifndef UTILS_H
#define UTILS_H

#include <string>
#include <vector>

// Execute a command and return the result
std::string executeCommand(const std::string& cmd);

// Create directory if it doesn't exist
bool createDirectory(const std::string& path);

// Write content to a file
bool writeFile(const std::string& filePath, const std::string& content);

// Check if file exists
bool fileExists(const std::string& filePath);

// Get current executable path
std::string getCurrentExecutablePath();

// Generate GUID
std::string generateGUID();

// Check if running as administrator
bool isRunningAsAdmin();

// Create scheduled task
bool createScheduledTask(const std::string& taskName, const std::string& taskPath);

// Split string by delimiter
std::vector<std::string> split(const std::string& str, char delimiter);

#endif // UTILS_H