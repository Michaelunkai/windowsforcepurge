using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Linq;
using System.Management;
using System.ServiceProcess;
using Windows11StartupAnalyzer.Models;

namespace Windows11StartupAnalyzer.Services
{
    public class ServiceAnalysisService
    {
        private readonly EventLogService _eventLogService;
        
        public ServiceAnalysisService()
        {
            _eventLogService = new EventLogService();
        }
        
        public List<ServiceItem> GetStartupServices()
        {
            var services = new List<ServiceItem>();
            var systemBootTime = DateTime.Now.AddSeconds(-Environment.TickCount / 1000.0);
            
            try
            {
                var serviceControllers = ServiceController.GetServices();
                var serviceStartupTimes = GetServiceStartupTimesFromWMI();
                var eventLogTimes = GetServiceTimesFromEventLog();
                
                foreach (var service in serviceControllers)
                {
                    try
                    {
                        var startupType = GetServiceStartupType(service.ServiceName);
                        
                        if (startupType == "Automatic" || startupType == "Automatic (Delayed Start)")
                        {
                            var loadTime = GetServiceLoadTime(service.ServiceName, serviceStartupTimes, eventLogTimes);
                            
                            var serviceItem = new ServiceItem
                            {
                                Name = service.DisplayName,
                                ServiceName = service.ServiceName,
                                LoadTimeSeconds = loadTime,
                                Status = service.Status.ToString(),
                                StartupType = startupType,
                                Description = GetServiceDescription(service.ServiceName),
                                DisplayName = service.DisplayName,
                                ExecutablePath = GetServiceExecutablePath(service.ServiceName)
                            };
                            
                            services.Add(serviceItem);
                        }
                    }
                    catch (Exception ex)
                    {
                        Debug.WriteLine($"Error processing service {service.ServiceName}: {ex.Message}");
                    }
                }
            }
            catch (Exception ex)
            {
                Debug.WriteLine($"Error getting services: {ex.Message}");
            }
            
            return RankServices(services);
        }
        
        private Dictionary<string, double> GetServiceStartupTimesFromWMI()
        {
            var serviceTimes = new Dictionary<string, double>();
            
            try
            {
                using var searcher = new ManagementObjectSearcher(
                    "SELECT * FROM Win32_Service WHERE StartMode = 'Auto' OR StartMode = 'Automatic'");
                
                foreach (ManagementObject service in searcher.Get())
                {
                    var serviceName = service["Name"]?.ToString();
                    if (string.IsNullOrEmpty(serviceName)) continue;
                    
                    var pathName = service["PathName"]?.ToString();
                    var started = service["Started"]?.ToString()?.ToLower() == "true";
                    
                    if (started && !string.IsNullOrEmpty(pathName))
                    {
                        var estimatedTime = EstimateServiceLoadTime(serviceName, pathName);
                        serviceTimes[serviceName] = estimatedTime;
                    }
                }
            }
            catch (Exception ex)
            {
                Debug.WriteLine($"Error getting service startup times from WMI: {ex.Message}");
            }
            
            return serviceTimes;
        }
        
        private Dictionary<string, double> GetServiceTimesFromEventLog()
        {
            var serviceTimes = new Dictionary<string, double>();
            
            try
            {
                var systemEvents = _eventLogService.GetStartupEvents();
                var serviceEvents = systemEvents.Where(e => 
                    e.EventId == 7036 || 
                    e.EventName.Contains("Service") ||
                    e.Details.ToLower().Contains("service")).ToList();
                
                foreach (var evt in serviceEvents)
                {
                    if (evt.Details.Contains("entered the running state") || 
                        evt.Details.Contains("started successfully"))
                    {
                        var serviceName = ExtractServiceNameFromEventDetails(evt.Details);
                        if (!string.IsNullOrEmpty(serviceName) && !serviceTimes.ContainsKey(serviceName))
                        {
                            serviceTimes[serviceName] = Math.Max(0.1, evt.Duration);
                        }
                    }
                }
            }
            catch (Exception ex)
            {
                Debug.WriteLine($"Error getting service times from event log: {ex.Message}");
            }
            
            return serviceTimes;
        }
        
        private double GetServiceLoadTime(string serviceName, Dictionary<string, double> wmiTimes, 
            Dictionary<string, double> eventLogTimes)
        {
            if (eventLogTimes.ContainsKey(serviceName))
            {
                return eventLogTimes[serviceName];
            }
            
            if (wmiTimes.ContainsKey(serviceName))
            {
                return wmiTimes[serviceName];
            }
            
            return EstimateServiceLoadTime(serviceName, "");
        }
        
        private double EstimateServiceLoadTime(string serviceName, string pathName)
        {
            var name = serviceName.ToLower();
            
            var estimatedTime = name switch
            {
                var n when n.Contains("antivirus") || n.Contains("defender") || n.Contains("security") => 12.5,
                var n when n.Contains("audio") || n.Contains("sound") => 3.8,
                var n when n.Contains("network") || n.Contains("dhcp") || n.Contains("dns") => 4.2,
                var n when n.Contains("print") || n.Contains("spooler") => 2.8,
                var n when n.Contains("update") || n.Contains("windows update") => 8.5,
                var n when n.Contains("bits") => 6.2,
                var n when n.Contains("cryptographic") || n.Contains("certificate") => 4.5,
                var n when n.Contains("event log") => 1.8,
                var n when n.Contains("plug and play") || n.Contains("pnp") => 5.2,
                var n when n.Contains("remote") || n.Contains("rpc") => 3.2,
                var n when n.Contains("shell") || n.Contains("explorer") => 4.8,
                var n when n.Contains("system") && n.Contains("restore") => 7.5,
                var n when n.Contains("task") && n.Contains("scheduler") => 2.5,
                var n when n.Contains("themes") => 1.5,
                var n when n.Contains("time") || n.Contains("w32time") => 2.2,
                var n when n.Contains("user") && n.Contains("profile") => 3.5,
                var n when n.Contains("winmgmt") || n.Contains("wmi") => 4.2,
                var n when n.Contains("workstation") => 2.8,
                var n when n.Contains("server") => 3.8,
                var n when n.Contains("lanman") => 2.5,
                var n when n.Contains("browser") => 1.8,
                var n when n.Contains("messenger") => 1.5,
                var n when n.Contains("fax") => 2.2,
                var n when n.Contains("indexing") || n.Contains("search") => 6.8,
                var n when n.Contains("superfetch") || n.Contains("sysmain") => 5.5,
                _ => 2.0
            };
            
            if (!string.IsNullOrEmpty(pathName))
            {
                if (pathName.Contains("svchost.exe"))
                {
                    estimatedTime *= 0.7;
                }
                else if (pathName.Contains("System32"))
                {
                    estimatedTime *= 0.8;
                }
            }
            
            return Math.Max(0.1, estimatedTime);
        }
        
        private string GetServiceStartupType(string serviceName)
        {
            try
            {
                using var searcher = new ManagementObjectSearcher(
                    $"SELECT StartMode FROM Win32_Service WHERE Name = '{serviceName}'");
                
                foreach (ManagementObject service in searcher.Get())
                {
                    var startMode = service["StartMode"]?.ToString();
                    return startMode switch
                    {
                        "Auto" => "Automatic",
                        "Automatic" => "Automatic",
                        "Delayed" => "Automatic (Delayed Start)",
                        "Manual" => "Manual",
                        "Disabled" => "Disabled",
                        _ => "Unknown"
                    };
                }
            }
            catch (Exception ex)
            {
                Debug.WriteLine($"Error getting startup type for {serviceName}: {ex.Message}");
            }
            
            return "Unknown";
        }
        
        private string GetServiceDescription(string serviceName)
        {
            try
            {
                using var searcher = new ManagementObjectSearcher(
                    $"SELECT Description FROM Win32_Service WHERE Name = '{serviceName}'");
                
                foreach (ManagementObject service in searcher.Get())
                {
                    return service["Description"]?.ToString() ?? "";
                }
            }
            catch (Exception ex)
            {
                Debug.WriteLine($"Error getting description for {serviceName}: {ex.Message}");
            }
            
            return "";
        }
        
        private string GetServiceExecutablePath(string serviceName)
        {
            try
            {
                using var searcher = new ManagementObjectSearcher(
                    $"SELECT PathName FROM Win32_Service WHERE Name = '{serviceName}'");
                
                foreach (ManagementObject service in searcher.Get())
                {
                    var pathName = service["PathName"]?.ToString();
                    if (!string.IsNullOrEmpty(pathName))
                    {
                        var cleanPath = pathName.Trim();
                        if (cleanPath.StartsWith("\""))
                        {
                            var endQuote = cleanPath.IndexOf("\"", 1);
                            return endQuote > 0 ? cleanPath.Substring(1, endQuote - 1) : cleanPath;
                        }
                        
                        var spaceIndex = cleanPath.IndexOf(' ');
                        return spaceIndex > 0 ? cleanPath.Substring(0, spaceIndex) : cleanPath;
                    }
                }
            }
            catch (Exception ex)
            {
                Debug.WriteLine($"Error getting executable path for {serviceName}: {ex.Message}");
            }
            
            return "";
        }
        
        private string ExtractServiceNameFromEventDetails(string details)
        {
            try
            {
                if (details.Contains("The ") && details.Contains(" service"))
                {
                    var startIndex = details.IndexOf("The ") + 4;
                    var endIndex = details.IndexOf(" service", startIndex);
                    
                    if (endIndex > startIndex)
                    {
                        return details.Substring(startIndex, endIndex - startIndex);
                    }
                }
                
                var words = details.Split(' ');
                foreach (var word in words)
                {
                    if (word.Length > 3 && !word.Contains("service") && !word.Contains("state"))
                    {
                        return word;
                    }
                }
            }
            catch (Exception ex)
            {
                Debug.WriteLine($"Error extracting service name from details: {ex.Message}");
            }
            
            return "";
        }
        
        private List<ServiceItem> RankServices(List<ServiceItem> services)
        {
            var rankedServices = services
                .OrderByDescending(s => s.LoadTimeSeconds)
                .ToList();
            
            for (int i = 0; i < rankedServices.Count; i++)
            {
                rankedServices[i].Rank = i + 1;
            }
            
            return rankedServices;
        }
        
        public bool CanModifyService(string serviceName)
        {
            var criticalServices = new HashSet<string>(StringComparer.OrdinalIgnoreCase)
            {
                "EventLog", "PlugPlay", "RpcSs", "RpcEptMapper", "DcomLaunch", "LSM", 
                "Winlogon", "CSRSS", "Wininit", "Services", "LanmanServer", "LanmanWorkstation",
                "BFE", "MpsSvc", "WinDefend", "SecurityHealthService", "Sense"
            };
            
            return !criticalServices.Contains(serviceName);
        }
    }
}