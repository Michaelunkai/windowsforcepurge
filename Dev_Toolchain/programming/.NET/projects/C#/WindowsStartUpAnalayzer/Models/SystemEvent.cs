using System;

namespace Windows11StartupAnalyzer.Models
{
    public class SystemEvent
    {
        public DateTime EventTime { get; set; }
        public string EventName { get; set; } = string.Empty;
        public double Duration { get; set; }
        public string Source { get; set; } = string.Empty;
        public string Details { get; set; } = string.Empty;
        public int EventId { get; set; }
        public string LogName { get; set; } = string.Empty;
    }
}