using System;

namespace Windows11StartupAnalyzer.Models
{
    public class StartupItem
    {
        public int Rank { get; set; }
        public string Name { get; set; } = string.Empty;
        public double LoadTimeSeconds { get; set; }
        public string Status { get; set; } = string.Empty;
        public string Impact { get; set; } = string.Empty;
        public string Location { get; set; } = string.Empty;
        public bool CanDisable { get; set; } = true;
        public bool CanDelay { get; set; } = true;
        public string RegistryPath { get; set; } = string.Empty;
        public string ExecutablePath { get; set; } = string.Empty;
        public DateTime LastAccessTime { get; set; }
        public string Publisher { get; set; } = string.Empty;
        public string Version { get; set; } = string.Empty;
    }
}