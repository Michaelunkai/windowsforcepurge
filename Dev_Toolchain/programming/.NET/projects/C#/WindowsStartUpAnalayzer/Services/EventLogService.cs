using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Linq;
using Windows11StartupAnalyzer.Models;

namespace Windows11StartupAnalyzer.Services
{
    public class EventLogService
    {
        public List<SystemEvent> GetStartupEvents()
        {
            var events = new List<SystemEvent>();
            
            try
            {
                var systemLog = new EventLog("System");
                var applicationLog = new EventLog("Application");
                
                var cutoffTime = DateTime.Now.AddHours(-24);
                
                AddEventsFromLog(events, systemLog, cutoffTime);
                AddEventsFromLog(events, applicationLog, cutoffTime);
                
                return events.OrderBy(e => e.EventTime).ToList();
            }
            catch (Exception ex)
            {
                Debug.WriteLine($"Error reading event logs: {ex.Message}");
                return new List<SystemEvent>();
            }
        }
        
        private void AddEventsFromLog(List<SystemEvent> events, EventLog log, DateTime cutoffTime)
        {
            try
            {
                var relevantEventIds = new HashSet<int> 
                { 
                    6005, 6006, 6009, 6013, 1, 100, 200, 12, 13, 1001, 1074, 6008,
                    7001, 7002, 7026, 7031, 7034, 7040
                };
                
                foreach (EventLogEntry entry in log.Entries)
                {
                    if (entry.TimeGenerated < cutoffTime) continue;
                    
                    if (relevantEventIds.Contains(entry.EventID) || 
                        IsStartupRelatedEvent(entry))
                    {
                        var systemEvent = new SystemEvent
                        {
                            EventTime = entry.TimeGenerated,
                            EventName = GetEventDescription(entry.EventID),
                            Duration = CalculateEventDuration(entry),
                            Source = entry.Source,
                            Details = entry.Message?.Substring(0, Math.Min(entry.Message.Length, 200)) ?? "",
                            EventId = entry.EventID,
                            LogName = log.LogDisplayName
                        };
                        
                        events.Add(systemEvent);
                    }
                }
            }
            catch (Exception ex)
            {
                Debug.WriteLine($"Error processing log {log.LogDisplayName}: {ex.Message}");
            }
        }
        
        private bool IsStartupRelatedEvent(EventLogEntry entry)
        {
            var message = entry.Message?.ToLower() ?? "";
            var startupKeywords = new[] { "startup", "boot", "logon", "login", "session", "service started" };
            
            return startupKeywords.Any(keyword => message.Contains(keyword));
        }
        
        private string GetEventDescription(int eventId)
        {
            return eventId switch
            {
                6005 => "System Startup",
                6006 => "System Shutdown",
                6009 => "System Boot",
                6013 => "System Uptime",
                1 => "Service Start",
                100 => "Application Start",
                200 => "Application Load",
                12 => "Kernel Boot",
                13 => "Kernel Ready",
                1001 => "User Logon",
                1074 => "System Restart",
                6008 => "Unexpected Shutdown",
                7001 => "Service Start Failed",
                7002 => "Service Start Delayed",
                7026 => "System Service Load Failed",
                7031 => "Service Terminated",
                7034 => "Service Crashed",
                7040 => "Service Startup Type Changed",
                _ => $"Event {eventId}"
            };
        }
        
        private double CalculateEventDuration(EventLogEntry entry)
        {
            try
            {
                var message = entry.Message ?? "";
                
                if (message.Contains("seconds") && message.Contains("took"))
                {
                    var words = message.Split(' ');
                    for (int i = 0; i < words.Length - 1; i++)
                    {
                        if (words[i + 1].ToLower().Contains("second") && double.TryParse(words[i], out double seconds))
                        {
                            return seconds;
                        }
                    }
                }
                
                return entry.EventID switch
                {
                    6005 => 2.5,
                    6009 => 15.0,
                    1001 => 3.2,
                    100 => 1.8,
                    _ => 1.0
                };
            }
            catch
            {
                return 1.0;
            }
        }
        
        public double GetTotalBootTime()
        {
            try
            {
                var systemLog = new EventLog("System");
                var cutoffTime = DateTime.Now.AddHours(-24);
                
                DateTime? bootStart = null;
                DateTime? bootComplete = null;
                
                foreach (EventLogEntry entry in systemLog.Entries)
                {
                    if (entry.TimeGenerated < cutoffTime) continue;
                    
                    if (entry.EventID == 6009 && bootStart == null)
                    {
                        bootStart = entry.TimeGenerated;
                    }
                    else if (entry.EventID == 6013 && bootStart != null)
                    {
                        bootComplete = entry.TimeGenerated;
                        break;
                    }
                }
                
                if (bootStart.HasValue && bootComplete.HasValue)
                {
                    return (bootComplete.Value - bootStart.Value).TotalSeconds;
                }
                
                return EstimateBootTime();
            }
            catch
            {
                return EstimateBootTime();
            }
        }
        
        private double EstimateBootTime()
        {
            try
            {
                using var process = new Process();
                process.StartInfo.FileName = "wmic";
                process.StartInfo.Arguments = "OS get LastBootUpTime /value";
                process.StartInfo.UseShellExecute = false;
                process.StartInfo.RedirectStandardOutput = true;
                process.StartInfo.CreateNoWindow = true;
                
                process.Start();
                string output = process.StandardOutput.ReadToEnd();
                process.WaitForExit();
                
                if (output.Contains("LastBootUpTime="))
                {
                    var bootTimeStr = output.Split('=')[1].Split('.')[0];
                    if (DateTime.TryParseExact(bootTimeStr, "yyyyMMddHHmmss", null, 
                        System.Globalization.DateTimeStyles.None, out DateTime bootTime))
                    {
                        var upTime = Environment.TickCount / 1000.0;
                        return Math.Min(upTime, 180);
                    }
                }
                
                return Environment.TickCount / 1000.0;
            }
            catch
            {
                return 45.0;
            }
        }
    }
}