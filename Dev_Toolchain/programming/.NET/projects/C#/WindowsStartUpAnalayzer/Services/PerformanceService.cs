using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Linq;

namespace Windows11StartupAnalyzer.Services
{
    public class PerformanceService
    {
        public double GetSystemBootTime()
        {
            try
            {
                using var uptimeCounter = new PerformanceCounter("System", "System Up Time");
                uptimeCounter.NextValue();
                System.Threading.Thread.Sleep(100);
                var uptime = uptimeCounter.NextValue();
                return uptime;
            }
            catch (Exception ex)
            {
                Debug.WriteLine($"Error getting system uptime: {ex.Message}");
                return Environment.TickCount / 1000.0;
            }
        }
        
        public Dictionary<string, double> GetProcessStartupTimes()
        {
            var processStartupTimes = new Dictionary<string, double>();
            
            try
            {
                var systemBootTime = DateTime.Now.AddSeconds(-GetSystemBootTime());
                var processes = Process.GetProcesses();
                
                foreach (var process in processes)
                {
                    try
                    {
                        if (process.ProcessName.ToLower().Contains("system") ||
                            process.ProcessName.ToLower().Contains("idle") ||
                            process.Id == 0)
                            continue;
                            
                        var startTime = process.StartTime;
                        if (startTime > systemBootTime && startTime < systemBootTime.AddMinutes(10))
                        {
                            var timeSinceStart = (startTime - systemBootTime).TotalSeconds;
                            
                            if (!processStartupTimes.ContainsKey(process.ProcessName) ||
                                processStartupTimes[process.ProcessName] > timeSinceStart)
                            {
                                processStartupTimes[process.ProcessName] = Math.Max(0.1, timeSinceStart);
                            }
                        }
                    }
                    catch (Exception ex)
                    {
                        Debug.WriteLine($"Error processing {process.ProcessName}: {ex.Message}");
                    }
                }
            }
            catch (Exception ex)
            {
                Debug.WriteLine($"Error getting process startup times: {ex.Message}");
            }
            
            return processStartupTimes;
        }
        
        public double GetMemoryUsage()
        {
            try
            {
                using var memoryCounter = new PerformanceCounter("Memory", "Available MBytes");
                var availableMemory = memoryCounter.NextValue();
                
                var totalMemory = GetTotalPhysicalMemory();
                var usedMemory = totalMemory - (availableMemory * 1024 * 1024);
                
                return (usedMemory / totalMemory) * 100;
            }
            catch (Exception ex)
            {
                Debug.WriteLine($"Error getting memory usage: {ex.Message}");
                return 0.0;
            }
        }
        
        public double GetCpuUsage()
        {
            try
            {
                using var cpuCounter = new PerformanceCounter("Processor", "% Processor Time", "_Total");
                cpuCounter.NextValue();
                System.Threading.Thread.Sleep(1000);
                return cpuCounter.NextValue();
            }
            catch (Exception ex)
            {
                Debug.WriteLine($"Error getting CPU usage: {ex.Message}");
                return 0.0;
            }
        }
        
        public double GetDiskUsage()
        {
            try
            {
                using var diskCounter = new PerformanceCounter("PhysicalDisk", "% Disk Time", "_Total");
                diskCounter.NextValue();
                System.Threading.Thread.Sleep(1000);
                return diskCounter.NextValue();
            }
            catch (Exception ex)
            {
                Debug.WriteLine($"Error getting disk usage: {ex.Message}");
                return 0.0;
            }
        }
        
        private long GetTotalPhysicalMemory()
        {
            try
            {
                using var searcher = new System.Management.ManagementObjectSearcher("SELECT TotalPhysicalMemory FROM Win32_ComputerSystem");
                foreach (System.Management.ManagementObject obj in searcher.Get())
                {
                    return Convert.ToInt64(obj["TotalPhysicalMemory"]);
                }
                return 8L * 1024 * 1024 * 1024;
            }
            catch
            {
                return 8L * 1024 * 1024 * 1024;
            }
        }
        
        public List<(string ProcessName, double CpuTime, double WorkingSet)> GetTopProcessesByResource()
        {
            var processes = new List<(string ProcessName, double CpuTime, double WorkingSet)>();
            
            try
            {
                foreach (var process in Process.GetProcesses())
                {
                    try
                    {
                        if (process.ProcessName.ToLower().Contains("system") ||
                            process.ProcessName.ToLower().Contains("idle") ||
                            process.Id == 0)
                            continue;
                            
                        var cpuTime = process.TotalProcessorTime.TotalMilliseconds;
                        var workingSet = process.WorkingSet64 / (1024.0 * 1024.0);
                        
                        if (workingSet > 1.0)
                        {
                            processes.Add((process.ProcessName, cpuTime, workingSet));
                        }
                    }
                    catch (Exception ex)
                    {
                        Debug.WriteLine($"Error processing {process.ProcessName}: {ex.Message}");
                    }
                }
            }
            catch (Exception ex)
            {
                Debug.WriteLine($"Error getting top processes: {ex.Message}");
            }
            
            return processes
                .OrderByDescending(p => p.CpuTime + p.WorkingSet)
                .Take(20)
                .ToList();
        }
    }
}