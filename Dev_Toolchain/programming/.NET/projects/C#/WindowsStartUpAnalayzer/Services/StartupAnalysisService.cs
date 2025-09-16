using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Management;
using Microsoft.Win32;
using Windows11StartupAnalyzer.Models;

namespace Windows11StartupAnalyzer.Services
{
    public class StartupAnalysisService
    {
        private readonly PerformanceService _performanceService;
        
        public StartupAnalysisService()
        {
            _performanceService = new PerformanceService();
        }
        
        public List<StartupItem> GetStartupItems()
        {
            var startupItems = new List<StartupItem>();
            var processStartupTimes = _performanceService.GetProcessStartupTimes();
            
            startupItems.AddRange(GetRegistryStartupItems(processStartupTimes));
            startupItems.AddRange(GetStartupFolderItems(processStartupTimes));
            startupItems.AddRange(GetTaskSchedulerStartupItems(processStartupTimes));
            startupItems.AddRange(GetRunningProcessStartupItems(processStartupTimes));
            
            return RankStartupItems(startupItems);
        }
        
        private List<StartupItem> GetRegistryStartupItems(Dictionary<string, double> processStartupTimes)
        {
            var items = new List<StartupItem>();
            
            var registryPaths = new[]
            {
                @"SOFTWARE\Microsoft\Windows\CurrentVersion\Run",
                @"SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce",
                @"SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run",
                @"SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\RunOnce"
            };
            
            foreach (var path in registryPaths)
            {
                items.AddRange(GetRegistryStartupItemsFromPath(RegistryHive.LocalMachine, path, processStartupTimes, "HKEY_LOCAL_MACHINE"));
                items.AddRange(GetRegistryStartupItemsFromPath(RegistryHive.CurrentUser, path, processStartupTimes, "HKEY_CURRENT_USER"));
            }
            
            return items;
        }
        
        private List<StartupItem> GetRegistryStartupItemsFromPath(RegistryHive hive, string path, 
            Dictionary<string, double> processStartupTimes, string hiveName)
        {
            var items = new List<StartupItem>();
            
            try
            {
                using var baseKey = RegistryKey.OpenBaseKey(hive, RegistryView.Registry64);
                using var key = baseKey.OpenSubKey(path);
                
                if (key != null)
                {
                    foreach (var valueName in key.GetValueNames())
                    {
                        var value = key.GetValue(valueName)?.ToString();
                        if (string.IsNullOrEmpty(value)) continue;
                        
                        var executablePath = ExtractExecutablePath(value);
                        var processName = Path.GetFileNameWithoutExtension(executablePath);
                        
                        var loadTime = GetEstimatedLoadTime(processName, executablePath, processStartupTimes);
                        
                        var item = new StartupItem
                        {
                            Name = string.IsNullOrEmpty(valueName) ? processName : valueName,
                            LoadTimeSeconds = loadTime,
                            Status = "Enabled",
                            Impact = GetImpactLevel(loadTime),
                            Location = $"{hiveName}\\{path}",
                            RegistryPath = $"{hiveName}\\{path}\\{valueName}",
                            ExecutablePath = executablePath,
                            CanDisable = !IsSystemCritical(processName),
                            CanDelay = !IsSystemCritical(processName),
                            Publisher = GetFilePublisher(executablePath),
                            Version = GetFileVersion(executablePath)
                        };
                        
                        items.Add(item);
                    }
                }
            }
            catch (Exception ex)
            {
                Debug.WriteLine($"Error reading registry path {path}: {ex.Message}");
            }
            
            return items;
        }
        
        private List<StartupItem> GetStartupFolderItems(Dictionary<string, double> processStartupTimes)
        {
            var items = new List<StartupItem>();
            
            var startupFolders = new[]
            {
                Environment.GetFolderPath(Environment.SpecialFolder.Startup),
                Environment.GetFolderPath(Environment.SpecialFolder.CommonStartup)
            };
            
            foreach (var folder in startupFolders)
            {
                if (!Directory.Exists(folder)) continue;
                
                try
                {
                    var files = Directory.GetFiles(folder, "*.*", SearchOption.TopDirectoryOnly)
                        .Where(f => Path.GetExtension(f).ToLower() is ".exe" or ".lnk" or ".bat" or ".cmd");
                    
                    foreach (var file in files)
                    {
                        var name = Path.GetFileNameWithoutExtension(file);
                        var processName = name;
                        
                        if (Path.GetExtension(file).ToLower() == ".lnk")
                        {
                            var targetPath = GetShortcutTarget(file);
                            if (!string.IsNullOrEmpty(targetPath))
                            {
                                processName = Path.GetFileNameWithoutExtension(targetPath);
                            }
                        }
                        
                        var loadTime = GetEstimatedLoadTime(processName, file, processStartupTimes);
                        
                        var item = new StartupItem
                        {
                            Name = name,
                            LoadTimeSeconds = loadTime,
                            Status = "Enabled",
                            Impact = GetImpactLevel(loadTime),
                            Location = folder,
                            ExecutablePath = file,
                            CanDisable = true,
                            CanDelay = true,
                            Publisher = GetFilePublisher(file),
                            Version = GetFileVersion(file)
                        };
                        
                        items.Add(item);
                    }
                }
                catch (Exception ex)
                {
                    Debug.WriteLine($"Error reading startup folder {folder}: {ex.Message}");
                }
            }
            
            return items;
        }
        
        private List<StartupItem> GetTaskSchedulerStartupItems(Dictionary<string, double> processStartupTimes)
        {
            var items = new List<StartupItem>();
            
            try
            {
                using var searcher = new ManagementObjectSearcher(
                    "SELECT * FROM Win32_ScheduledJob WHERE Command IS NOT NULL");
                
                foreach (ManagementObject obj in searcher.Get())
                {
                    var command = obj["Command"]?.ToString();
                    if (string.IsNullOrEmpty(command)) continue;
                    
                    var name = obj["Name"]?.ToString() ?? Path.GetFileNameWithoutExtension(command);
                    var processName = Path.GetFileNameWithoutExtension(ExtractExecutablePath(command));
                    
                    var loadTime = GetEstimatedLoadTime(processName, command, processStartupTimes);
                    
                    var item = new StartupItem
                    {
                        Name = name,
                        LoadTimeSeconds = loadTime,
                        Status = "Scheduled",
                        Impact = GetImpactLevel(loadTime),
                        Location = "Task Scheduler",
                        ExecutablePath = command,
                        CanDisable = true,
                        CanDelay = true
                    };
                    
                    items.Add(item);
                }
            }
            catch (Exception ex)
            {
                Debug.WriteLine($"Error reading scheduled tasks: {ex.Message}");
            }
            
            return items;
        }
        
        private List<StartupItem> GetRunningProcessStartupItems(Dictionary<string, double> processStartupTimes)
        {
            var items = new List<StartupItem>();
            var addedProcesses = new HashSet<string>();
            
            foreach (var kvp in processStartupTimes)
            {
                if (addedProcesses.Contains(kvp.Key.ToLower())) continue;
                
                var item = new StartupItem
                {
                    Name = kvp.Key,
                    LoadTimeSeconds = kvp.Value,
                    Status = "Running",
                    Impact = GetImpactLevel(kvp.Value),
                    Location = "System Process",
                    CanDisable = !IsSystemCritical(kvp.Key),
                    CanDelay = !IsSystemCritical(kvp.Key)
                };
                
                items.Add(item);
                addedProcesses.Add(kvp.Key.ToLower());
            }
            
            return items;
        }
        
        private List<StartupItem> RankStartupItems(List<StartupItem> items)
        {
            var rankedItems = items
                .GroupBy(i => i.Name.ToLower())
                .Select(g => g.OrderByDescending(i => i.LoadTimeSeconds).First())
                .OrderByDescending(i => i.LoadTimeSeconds)
                .ToList();
            
            for (int i = 0; i < rankedItems.Count; i++)
            {
                rankedItems[i].Rank = i + 1;
            }
            
            return rankedItems;
        }
        
        private double GetEstimatedLoadTime(string processName, string executablePath, 
            Dictionary<string, double> processStartupTimes)
        {
            if (processStartupTimes.ContainsKey(processName))
            {
                return processStartupTimes[processName];
            }
            
            if (!string.IsNullOrEmpty(executablePath) && File.Exists(executablePath))
            {
                var fileInfo = new FileInfo(executablePath);
                var sizeInMB = fileInfo.Length / (1024.0 * 1024.0);
                
                return Math.Max(0.5, Math.Min(15.0, sizeInMB * 0.1 + GetProcessComplexityFactor(processName)));
            }
            
            return GetProcessComplexityFactor(processName);
        }
        
        private double GetProcessComplexityFactor(string processName)
        {
            var name = processName.ToLower();
            
            return name switch
            {
                var n when n.Contains("antivirus") || n.Contains("defender") => 8.5,
                var n when n.Contains("office") || n.Contains("excel") || n.Contains("word") => 6.2,
                var n when n.Contains("adobe") || n.Contains("photoshop") => 7.8,
                var n when n.Contains("steam") || n.Contains("game") => 5.5,
                var n when n.Contains("chrome") || n.Contains("firefox") || n.Contains("browser") => 4.2,
                var n when n.Contains("skype") || n.Contains("teams") || n.Contains("zoom") => 3.8,
                var n when n.Contains("dropbox") || n.Contains("onedrive") || n.Contains("sync") => 3.2,
                var n when n.Contains("driver") => 2.8,
                var n when n.Contains("update") => 2.5,
                _ => 1.5
            };
        }
        
        private string GetImpactLevel(double loadTime)
        {
            return loadTime switch
            {
                >= 5.0 => "High",
                >= 2.0 => "Medium",
                >= 0.5 => "Low",
                _ => "None"
            };
        }
        
        private bool IsSystemCritical(string processName)
        {
            var criticalProcesses = new HashSet<string>(StringComparer.OrdinalIgnoreCase)
            {
                "winlogon", "csrss", "smss", "wininit", "services", "lsass", "svchost",
                "dwm", "explorer", "conhost", "audiodg", "spoolsv", "system", "idle",
                "registry", "memory compression", "secure system", "windefend"
            };
            
            return criticalProcesses.Contains(processName) || 
                   processName.ToLower().Contains("system") ||
                   processName.ToLower().Contains("windows");
        }
        
        private string ExtractExecutablePath(string command)
        {
            if (string.IsNullOrEmpty(command)) return "";
            
            command = command.Trim();
            
            if (command.StartsWith("\""))
            {
                var endQuote = command.IndexOf("\"", 1);
                return endQuote > 0 ? command.Substring(1, endQuote - 1) : command;
            }
            
            var spaceIndex = command.IndexOf(' ');
            return spaceIndex > 0 ? command.Substring(0, spaceIndex) : command;
        }
        
        private string GetShortcutTarget(string shortcutPath)
        {
            try
            {
                var shell = new object();
                var shellType = Type.GetTypeFromProgID("WScript.Shell");
                if (shellType != null)
                {
                    shell = Activator.CreateInstance(shellType);
                    var shortcut = shellType.InvokeMember("CreateShortcut", 
                        System.Reflection.BindingFlags.InvokeMethod, null, shell, new object[] { shortcutPath });
                    
                    var targetPath = shortcut?.GetType().InvokeMember("TargetPath", 
                        System.Reflection.BindingFlags.GetProperty, null, shortcut, null)?.ToString();
                    
                    return targetPath ?? "";
                }
            }
            catch (Exception ex)
            {
                Debug.WriteLine($"Error getting shortcut target: {ex.Message}");
            }
            
            return "";
        }
        
        private string GetFilePublisher(string filePath)
        {
            try
            {
                if (string.IsNullOrEmpty(filePath) || !File.Exists(filePath)) return "";
                
                var versionInfo = FileVersionInfo.GetVersionInfo(filePath);
                return versionInfo.CompanyName ?? "";
            }
            catch
            {
                return "";
            }
        }
        
        private string GetFileVersion(string filePath)
        {
            try
            {
                if (string.IsNullOrEmpty(filePath) || !File.Exists(filePath)) return "";
                
                var versionInfo = FileVersionInfo.GetVersionInfo(filePath);
                return versionInfo.FileVersion ?? "";
            }
            catch
            {
                return "";
            }
        }
    }
}