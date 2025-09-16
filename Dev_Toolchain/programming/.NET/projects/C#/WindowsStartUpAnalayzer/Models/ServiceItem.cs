using System;

namespace Windows11StartupAnalyzer.Models
{
    public class ServiceItem
    {
        public int Rank { get; set; }
        public string Name { get; set; } = string.Empty;
        public double LoadTimeSeconds { get; set; }
        public string Status { get; set; } = string.Empty;
        public string StartupType { get; set; } = string.Empty;
        public string Description { get; set; } = string.Empty;
        public string DisplayName { get; set; } = string.Empty;
        public string ServiceName { get; set; } = string.Empty;
        public DateTime StartTime { get; set; }
        public string ExecutablePath { get; set; } = string.Empty;
    }
}