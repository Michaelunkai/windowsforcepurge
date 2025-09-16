using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Management;
using System.ServiceProcess;
using System.Threading.Tasks;
using Microsoft.Win32;
using Windows11StartupAnalyzer.Models;

namespace Windows11StartupAnalyzer.Services
{
    public class OptimizationService
    {
        public List<string> GenerateOptimizationRecommendations(List<StartupItem> startupItems, List<ServiceItem> services)
        {
            var recommendations = new List<string>();
            
            recommendations.AddRange(AnalyzeStartupItems(startupItems));
            recommendations.AddRange(AnalyzeServices(services));
            recommendations.AddRange(GetGeneralOptimizationTips());
            
            return recommendations;
        }
        
        private List<string> AnalyzeStartupItems(List<StartupItem> items)
        {
            var recommendations = new List<string>();
            
            var slowItems = items.Where(i => i.LoadTimeSeconds > 5.0).ToList();
            var totalSlowTime = slowItems.Sum(i => i.LoadTimeSeconds);
            
            if (slowItems.Count > 0)
            {
                recommendations.Add($"🔴 HIGH PRIORITY: {slowItems.Count} startup programs are taking more than 5 seconds to load, " +
                    $"adding {totalSlowTime:F1} seconds to your boot time.");
                
                foreach (var item in slowItems.Take(5))
                {
                    recommendations.Add($"   • {item.Name} ({item.LoadTimeSeconds:F1}s) - Consider disabling if not essential");
                }
            }
            
            var mediumItems = items.Where(i => i.LoadTimeSeconds >= 2.0 && i.LoadTimeSeconds < 5.0).ToList();
            if (mediumItems.Count > 3)
            {
                recommendations.Add($"🟡 MEDIUM PRIORITY: {mediumItems.Count} programs have moderate startup impact. " +
                    "Consider delaying non-essential ones by 30-60 seconds.");
            }
            
            var duplicatePrograms = items
                .GroupBy(i => i.Name.ToLower())
                .Where(g => g.Count() > 1)
                .ToList();
            
            if (duplicatePrograms.Any())
            {
                recommendations.Add($"⚠️ DUPLICATE DETECTION: Found {duplicatePrograms.Count} programs with multiple startup entries. " +
                    "Remove duplicates to reduce startup time.");
            }
            
            return recommendations;
        }
        
        private List<string> AnalyzeServices(List<ServiceItem> services)
        {
            var recommendations = new List<string>();
            
            var slowServices = services.Where(s => s.LoadTimeSeconds > 8.0).ToList();
            if (slowServices.Count > 0)
            {
                recommendations.Add($"🔴 SERVICE OPTIMIZATION: {slowServices.Count} services are taking excessive time to start. " +
                    "Consider changing startup type to 'Manual' for non-critical services.");
                
                foreach (var service in slowServices.Take(3))
                {
                    recommendations.Add($"   • {service.Name} ({service.LoadTimeSeconds:F1}s)");
                }
            }
            
            var automaticServices = services.Where(s => s.StartupType.Contains("Automatic")).ToList();
            if (automaticServices.Count > 50)
            {
                recommendations.Add($"⚠️ TOO MANY AUTO SERVICES: {automaticServices.Count} services set to start automatically. " +
                    "Review and set non-essential services to 'Manual' startup.");
            }
            
            return recommendations;
        }
        
        private List<string> GetGeneralOptimizationTips()
        {
            var tips = new List<string>
            {
                "💡 QUICK WINS:",
                "   • Use SSD instead of HDD for faster boot times",
                "   • Ensure you have adequate RAM (8GB+ recommended)",
                "   • Keep Windows updated for performance improvements",
                "   • Regularly run disk cleanup and defragmentation",
                "   • Disable visual effects if performance is critical",
                "",
                "🛡️ SECURITY CONSIDERATIONS:",
                "   • Keep antivirus enabled but consider lighter alternatives",
                "   • Don't disable Windows Defender unless replacing it",
                "   • Be cautious when disabling system services",
                "",
                "⚡ ADVANCED OPTIMIZATIONS:",
                "   • Enable Fast Startup in Power Options",
                "   • Use hibernation instead of shutdown for faster 'boot'",
                "   • Consider using Windows 11's startup apps settings",
                "   • Monitor startup impact regularly and adjust accordingly"
            };
            
            return tips;
        }
        
        public async Task<bool> DisableStartupItemAsync(StartupItem item)
        {
            try
            {
                if (item.Location.Contains("HKEY_"))
                {
                    return await DisableRegistryStartupItem(item);
                }
                else if (item.Location.Contains("Startup"))
                {
                    return await DisableStartupFolderItem(item);
                }
                else if (item.Location.Contains("Task Scheduler"))
                {
                    return await DisableScheduledTaskItem(item);
                }
                
                return false;
            }
            catch (Exception ex)
            {
                Debug.WriteLine($"Error disabling startup item {item.Name}: {ex.Message}");
                return false;
            }
        }
        
        private async Task<bool> DisableRegistryStartupItem(StartupItem item)
        {
            return await Task.Run(() =>
            {
                try
                {
                    var parts = item.RegistryPath.Split('\\');
                    var hiveName = parts[0];
                    var keyPath = string.Join("\\", parts.Skip(1).Take(parts.Length - 2));
                    var valueName = parts.Last();
                    
                    RegistryHive hive = hiveName.Contains("LOCAL_MACHINE") ? RegistryHive.LocalMachine : RegistryHive.CurrentUser;
                    
                    using var baseKey = RegistryKey.OpenBaseKey(hive, RegistryView.Registry64);
                    using var key = baseKey.OpenSubKey(keyPath, true);
                    
                    if (key != null && key.GetValue(valueName) != null)
                    {
                        key.DeleteValue(valueName);
                        return true;
                    }
                }
                catch (Exception ex)
                {
                    Debug.WriteLine($"Error disabling registry startup item: {ex.Message}");
                }
                
                return false;
            });
        }
        
        private async Task<bool> DisableStartupFolderItem(StartupItem item)
        {
            return await Task.Run(() =>
            {
                try
                {
                    if (File.Exists(item.ExecutablePath))
                    {
                        var backupPath = item.ExecutablePath + ".disabled";
                        File.Move(item.ExecutablePath, backupPath);
                        return true;
                    }
                }
                catch (Exception ex)
                {
                    Debug.WriteLine($"Error disabling startup folder item: {ex.Message}");
                }
                
                return false;
            });
        }
        
        private async Task<bool> DisableScheduledTaskItem(StartupItem item)
        {
            return await Task.Run(() =>
            {
                try
                {
                    using var process = new Process();
                    process.StartInfo.FileName = "schtasks";
                    process.StartInfo.Arguments = $"/change /tn \"{item.Name}\" /disable";
                    process.StartInfo.UseShellExecute = false;
                    process.StartInfo.CreateNoWindow = true;
                    process.StartInfo.RedirectStandardOutput = true;
                    
                    process.Start();
                    process.WaitForExit();
                    
                    return process.ExitCode == 0;
                }
                catch (Exception ex)
                {
                    Debug.WriteLine($"Error disabling scheduled task: {ex.Message}");
                    return false;
                }
            });
        }
        
        public async Task<bool> DelayStartupItemAsync(StartupItem item, int delaySeconds = 30)
        {
            try
            {
                if (item.Location.Contains("HKEY_") && item.ExecutablePath.Contains(".exe"))
                {
                    return await CreateDelayedStartupTask(item, delaySeconds);
                }
                
                return false;
            }
            catch (Exception ex)
            {
                Debug.WriteLine($"Error delaying startup item {item.Name}: {ex.Message}");
                return false;
            }
        }
        
        private async Task<bool> CreateDelayedStartupTask(StartupItem item, int delaySeconds)
        {
            return await Task.Run(() =>
            {
                try
                {
                    var taskName = $"Delayed_{item.Name}_{DateTime.Now:yyyyMMddHHmmss}";
                    
                    using var process = new Process();
                    process.StartInfo.FileName = "schtasks";
                    process.StartInfo.Arguments = $"/create /tn \"{taskName}\" " +
                        $"/tr \"{item.ExecutablePath}\" " +
                        $"/sc onlogon " +
                        $"/delay 00{delaySeconds / 60:00}:{delaySeconds % 60:00} " +
                        $"/rl highest";
                    process.StartInfo.UseShellExecute = false;
                    process.StartInfo.CreateNoWindow = true;
                    process.StartInfo.RedirectStandardOutput = true;
                    
                    process.Start();
                    process.WaitForExit();
                    
                    if (process.ExitCode == 0)
                    {
                        return true;
                    }
                }
                catch (Exception ex)
                {
                    Debug.WriteLine($"Error creating delayed startup task: {ex.Message}");
                }
                
                return false;
            });
        }
        
        public async Task<bool> ChangeServiceStartupTypeAsync(ServiceItem service, string newStartupType)
        {
            return await Task.Run(() =>
            {
                try
                {
                    var startMode = newStartupType switch
                    {
                        "Automatic" => "auto",
                        "Manual" => "demand",
                        "Disabled" => "disabled",
                        _ => "demand"
                    };
                    
                    using var process = new Process();
                    process.StartInfo.FileName = "sc";
                    process.StartInfo.Arguments = $"config \"{service.ServiceName}\" start= {startMode}";
                    process.StartInfo.UseShellExecute = false;
                    process.StartInfo.CreateNoWindow = true;
                    process.StartInfo.RedirectStandardOutput = true;
                    
                    process.Start();
                    process.WaitForExit();
                    
                    return process.ExitCode == 0;
                }
                catch (Exception ex)
                {
                    Debug.WriteLine($"Error changing service startup type: {ex.Message}");
                    return false;
                }
            });
        }
        
        public string GetItemDetails(StartupItem item)
        {
            return $"Name: {item.Name}\n" +
                   $"Load Time: {item.LoadTimeSeconds:F2} seconds\n" +
                   $"Impact: {item.Impact}\n" +
                   $"Location: {item.Location}\n" +
                   $"Executable: {item.ExecutablePath}\n" +
                   $"Publisher: {item.Publisher}\n" +
                   $"Version: {item.Version}\n" +
                   $"Can Disable: {(item.CanDisable ? "Yes" : "No (System Critical)")}\n" +
                   $"Can Delay: {(item.CanDelay ? "Yes" : "No")}";
        }
        
        public string GetServiceDetails(ServiceItem service)
        {
            return $"Service: {service.DisplayName}\n" +
                   $"System Name: {service.ServiceName}\n" +
                   $"Load Time: {service.LoadTimeSeconds:F2} seconds\n" +
                   $"Status: {service.Status}\n" +
                   $"Startup Type: {service.StartupType}\n" +
                   $"Description: {service.Description}\n" +
                   $"Executable: {service.ExecutablePath}";
        }
        
        public bool CanOptimizeSystem()
        {
            try
            {
                using var identity = System.Security.Principal.WindowsIdentity.GetCurrent();
                var principal = new System.Security.Principal.WindowsPrincipal(identity);
                return principal.IsInRole(System.Security.Principal.WindowsBuiltInRole.Administrator);
            }
            catch
            {
                return false;
            }
        }
    }
}