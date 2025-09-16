import React, { useState, useEffect } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, AreaChart, Area, BarChart, Bar, PieChart, Pie, Cell } from 'recharts';

const AILogAnalyzer = () => {
  const [drawerOpen, setDrawerOpen] = useState(false);
  const [currentView, setCurrentView] = useState('dashboard');
  const [searchTerm, setSearchTerm] = useState('');
  const [isStreaming, setIsStreaming] = useState(true);
  const [logs, setLogs] = useState([]);
  const [anomalies, setAnomalies] = useState([]);
  const [loading, setLoading] = useState(true);
  const [selectedFilters, setSelectedFilters] = useState([]);

  // Mock data for demonstrations
  const timelineData = [
    { time: '00:00', errors: 12, warnings: 25, info: 156 },
    { time: '04:00', errors: 8, warnings: 18, info: 134 },
    { time: '08:00', errors: 45, warnings: 67, info: 289 },
    { time: '12:00', errors: 23, warnings: 41, info: 198 },
    { time: '16:00', errors: 67, warnings: 89, info: 345 },
    { time: '20:00', errors: 34, warnings: 52, info: 267 }
  ];

  const anomalyData = [
    { time: '08:15', severity: 85, type: 'CPU Spike', confidence: 0.94 },
    { time: '10:23', severity: 72, type: 'Memory Leak', confidence: 0.87 },
    { time: '14:45', severity: 91, type: 'Authentication Failure', confidence: 0.96 },
    { time: '16:12', severity: 68, type: 'Database Timeout', confidence: 0.82 },
    { time: '18:30', severity: 79, type: 'API Rate Limit', confidence: 0.89 }
  ];

  const logLevels = [
    { name: 'ERROR', count: 234, color: '#ef4444' },
    { name: 'WARNING', count: 567, color: '#f59e0b' },
    { name: 'INFO', count: 1234, color: '#3b82f6' },
    { name: 'DEBUG', count: 2345, color: '#10b981' }
  ];

  const mockLogs = [
    { id: 1, timestamp: '2025-07-20T10:30:15Z', level: 'ERROR', source: 'auth-service', message: 'Authentication failed for user johndoe@example.com', metadata: { ip: '192.168.1.100', userAgent: 'Mozilla/5.0' } },
    { id: 2, timestamp: '2025-07-20T10:30:12Z', level: 'WARNING', source: 'api-gateway', message: 'Rate limit approaching for API key abc123', metadata: { requests: 985, limit: 1000 } },
    { id: 3, timestamp: '2025-07-20T10:30:08Z', level: 'INFO', source: 'user-service', message: 'User profile updated successfully', metadata: { userId: 'usr_789', changes: ['email', 'preferences'] } },
    { id: 4, timestamp: '2025-07-20T10:30:05Z', level: 'ERROR', source: 'database', message: 'Connection timeout after 30 seconds', metadata: { database: 'postgres-prod', query: 'SELECT * FROM users WHERE...' } },
    { id: 5, timestamp: '2025-07-20T10:30:02Z', level: 'DEBUG', source: 'cache-service', message: 'Cache miss for key user:profile:123', metadata: { key: 'user:profile:123', ttl: 3600 } }
  ];

  useEffect(() => {
    const loadTimer = setTimeout(() => setLoading(false), 2000);
    
    const logTimer = setInterval(() => {
      if (isStreaming) {
        const newLog = {
          id: Date.now(),
          timestamp: new Date().toISOString(),
          level: ['ERROR', 'WARNING', 'INFO', 'DEBUG'][Math.floor(Math.random() * 4)],
          source: ['auth-service', 'api-gateway', 'user-service', 'database', 'cache-service'][Math.floor(Math.random() * 5)],
          message: [
            'Request processed successfully',
            'Database query executed',
            'User authentication completed',
            'Cache invalidated',
            'Background job started'
          ][Math.floor(Math.random() * 5)],
          metadata: { timestamp: Date.now() }
        };
        setLogs(prev => [newLog, ...prev.slice(0, 99)]);
      }
    }, 3000);

    setLogs(mockLogs);
    setAnomalies(anomalyData);

    return () => {
      clearTimeout(loadTimer);
      clearInterval(logTimer);
    };
  }, [isStreaming]);

  const getLogIcon = (level) => {
    switch (level) {
      case 'ERROR': return '❌';
      case 'WARNING': return '⚠️';
      case 'INFO': return 'ℹ️';
      case 'DEBUG': return '✅';
      default: return 'ℹ️';
    }
  };

  const getLogBgColor = (level) => {
    switch (level) {
      case 'ERROR': return 'bg-red-50 border-l-red-500';
      case 'WARNING': return 'bg-yellow-50 border-l-yellow-500';
      case 'INFO': return 'bg-blue-50 border-l-blue-500';
      case 'DEBUG': return 'bg-green-50 border-l-green-500';
      default: return 'bg-gray-50 border-l-gray-500';
    }
  };

  const getLogBadgeColor = (level) => {
    switch (level) {
      case 'ERROR': return 'bg-red-100 text-red-800';
      case 'WARNING': return 'bg-yellow-100 text-yellow-800';
      case 'INFO': return 'bg-blue-100 text-blue-800';
      case 'DEBUG': return 'bg-green-100 text-green-800';
      default: return 'bg-gray-100 text-gray-800';
    }
  };

  const menuItems = [
    { id: 'dashboard', label: 'Dashboard', icon: '📊' },
    { id: 'timeline', label: 'Timeline', icon: '📈' },
    { id: 'analytics', label: 'Analytics', icon: '🤖' },
    { id: 'search', label: 'Search', icon: '🔍' }
  ];

  const filteredLogs = logs.filter(log => {
    const matchesSearch = log.message.toLowerCase().includes(searchTerm.toLowerCase()) ||
                         log.source.toLowerCase().includes(searchTerm.toLowerCase());
    const matchesFilter = selectedFilters.length === 0 || selectedFilters.includes(log.level);
    return matchesSearch && matchesFilter;
  });

  const containerVariants = {
    hidden: { opacity: 0, y: 20 },
    visible: { opacity: 1, y: 0, transition: { duration: 0.6, staggerChildren: 0.1 } }
  };

  const itemVariants = {
    hidden: { opacity: 0, y: 20 },
    visible: { opacity: 1, y: 0 }
  };

  const LoadingSkeleton = () => (
    <div className="p-6 space-y-4">
      <div className="animate-pulse">
        <div className="h-48 bg-gray-200 rounded-2xl mb-4"></div>
        <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
          {[...Array(6)].map((_, i) => (
            <div key={i} className="h-32 bg-gray-200 rounded-xl"></div>
          ))}
        </div>
      </div>
    </div>
  );

  const toggleFilter = (level) => {
    setSelectedFilters(prev => 
      prev.includes(level) 
        ? prev.filter(f => f !== level)
        : [...prev, level]
    );
  };

  if (loading) {
    return (
      <div className="min-h-screen bg-gradient-to-br from-indigo-600 via-purple-600 to-pink-600">
        <header className="bg-white/10 backdrop-blur-lg border-b border-white/20">
          <div className="px-6 py-4">
            <h1 className="text-2xl font-bold text-white">AI Log Analyzer</h1>
          </div>
        </header>
        <LoadingSkeleton />
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gradient-to-br from-indigo-600 via-purple-600 to-pink-600 relative">
      {/* Header */}
      <header className="bg-white/10 backdrop-blur-lg border-b border-white/20 sticky top-0 z-40">
        <div className="px-6 py-4 flex items-center justify-between">
          <div className="flex items-center space-x-4">
            <button
              onClick={() => setDrawerOpen(true)}
              className="text-white hover:bg-white/10 p-2 rounded-lg transition-colors"
            >
              <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 6h16M4 12h16M4 18h16" />
              </svg>
            </button>
            <h1 className="text-2xl font-bold text-white">AI Log Analyzer</h1>
          </div>
          <div className="flex items-center space-x-4">
            <label className="flex items-center space-x-2 text-white">
              <span>Live Stream</span>
              <input
                type="checkbox"
                checked={isStreaming}
                onChange={(e) => setIsStreaming(e.target.checked)}
                className="rounded"
              />
            </label>
            <div className="relative">
              <button className="text-white hover:bg-white/10 p-2 rounded-lg transition-colors">
                ⚠️
              </button>
              <span className="absolute -top-1 -right-1 bg-red-500 text-white text-xs rounded-full h-5 w-5 flex items-center justify-center">
                {anomalies.length}
              </span>
            </div>
          </div>
        </div>
      </header>

      {/* Sidebar */}
      <AnimatePresence>
        {drawerOpen && (
          <>
            <motion.div
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              exit={{ opacity: 0 }}
              className="fixed inset-0 bg-black/50 z-40"
              onClick={() => setDrawerOpen(false)}
            />
            <motion.div
              initial={{ x: -300 }}
              animate={{ x: 0 }}
              exit={{ x: -300 }}
              className="fixed left-0 top-0 h-full w-80 bg-gray-900 z-50 shadow-2xl"
            >
              <div className="p-6">
                <h2 className="text-xl font-bold text-white mb-6">Navigation</h2>
                <nav className="space-y-2">
                  {menuItems.map((item) => (
                    <button
                      key={item.id}
                      onClick={() => {
                        setCurrentView(item.id);
                        setDrawerOpen(false);
                      }}
                      className={`w-full flex items-center space-x-3 px-4 py-3 rounded-lg transition-colors ${
                        currentView === item.id
                          ? 'bg-indigo-600 text-white'
                          : 'text-gray-300 hover:bg-gray-800'
                      }`}
                    >
                      <span className="text-xl">{item.icon}</span>
                      <span>{item.label}</span>
                    </button>
                  ))}
                </nav>
              </div>
            </motion.div>
          </>
        )}
      </AnimatePresence>

      {/* Main Content */}
      <main className="p-6">
        <AnimatePresence mode="wait">
          <motion.div
            key={currentView}
            variants={containerVariants}
            initial="hidden"
            animate="visible"
            exit="hidden"
          >
            {currentView === 'dashboard' && (
              <div className="space-y-6">
                {/* System Overview Chart */}
                <motion.div variants={itemVariants}>
                  <div className="bg-white/95 backdrop-blur-lg rounded-2xl shadow-xl p-6">
                    <h2 className="text-2xl font-bold text-gray-800 mb-4">System Overview</h2>
                    <div className="h-80">
                      <ResponsiveContainer width="100%" height="100%">
                        <AreaChart data={timelineData}>
                          <defs>
                            <linearGradient id="errorGradient" x1="0" y1="0" x2="0" y2="1">
                              <stop offset="5%" stopColor="#ef4444" stopOpacity={0.8}/>
                              <stop offset="95%" stopColor="#ef4444" stopOpacity={0.1}/>
                            </linearGradient>
                            <linearGradient id="warningGradient" x1="0" y1="0" x2="0" y2="1">
                              <stop offset="5%" stopColor="#f59e0b" stopOpacity={0.8}/>
                              <stop offset="95%" stopColor="#f59e0b" stopOpacity={0.1}/>
                            </linearGradient>
                            <linearGradient id="infoGradient" x1="0" y1="0" x2="0" y2="1">
                              <stop offset="5%" stopColor="#3b82f6" stopOpacity={0.8}/>
                              <stop offset="95%" stopColor="#3b82f6" stopOpacity={0.1}/>
                            </linearGradient>
                          </defs>
                          <XAxis dataKey="time" />
                          <YAxis />
                          <CartesianGrid strokeDasharray="3 3" />
                          <Tooltip />
                          <Area type="monotone" dataKey="errors" stackId="1" stroke="#ef4444" fill="url(#errorGradient)" />
                          <Area type="monotone" dataKey="warnings" stackId="1" stroke="#f59e0b" fill="url(#warningGradient)" />
                          <Area type="monotone" dataKey="info" stackId="1" stroke="#3b82f6" fill="url(#infoGradient)" />
                        </AreaChart>
                      </ResponsiveContainer>
                    </div>
                  </div>
                </motion.div>

                <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
                  {/* Anomaly Detection */}
                  <motion.div variants={itemVariants} className="lg:col-span-2">
                    <div className="bg-white/95 backdrop-blur-lg rounded-2xl shadow-xl p-6">
                      <h3 className="text-xl font-bold text-gray-800 mb-4">AI Anomaly Detection</h3>
                      <div className="h-64">
                        <ResponsiveContainer width="100%" height="100%">
                          <BarChart data={anomalies}>
                            <XAxis dataKey="time" />
                            <YAxis />
                            <CartesianGrid strokeDasharray="3 3" />
                            <Tooltip />
                            <Bar dataKey="severity" fill="#e91e63" radius={[4, 4, 0, 0]} />
                          </BarChart>
                        </ResponsiveContainer>
                      </div>
                    </div>
                  </motion.div>

                  {/* Log Distribution */}
                  <motion.div variants={itemVariants}>
                    <div className="bg-white/95 backdrop-blur-lg rounded-2xl shadow-xl p-6">
                      <h3 className="text-xl font-bold text-gray-800 mb-4">Log Distribution</h3>
                      <div className="h-64">
                        <ResponsiveContainer width="100%" height="100%">
                          <PieChart>
                            <Pie
                              data={logLevels}
                              cx="50%"
                              cy="50%"
                              innerRadius={40}
                              outerRadius={80}
                              dataKey="count"
                            >
                              {logLevels.map((entry, index) => (
                                <Cell key={`cell-${index}`} fill={entry.color} />
                              ))}
                            </Pie>
                            <Tooltip />
                          </PieChart>
                        </ResponsiveContainer>
                      </div>
                    </div>
                  </motion.div>
                </div>

                {/* Anomaly Cards */}
                <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
                  {anomalies.slice(0, 3).map((anomaly, index) => (
                    <motion.div key={index} variants={itemVariants}>
                      <div className="bg-white/95 backdrop-blur-lg rounded-2xl shadow-xl p-6 border border-red-200">
                        <div className="flex items-center mb-3">
                          <span className="text-2xl mr-2">⚠️</span>
                          <h4 className="text-lg font-bold text-gray-800">{anomaly.type}</h4>
                        </div>
                        <p className="text-sm text-gray-600 mb-3">Detected at {anomaly.time}</p>
                        <div className="mb-2">
                          <div className="bg-gray-200 rounded-full h-2">
                            <div 
                              className="bg-red-500 h-2 rounded-full transition-all duration-300"
                              style={{ width: `${anomaly.severity}%` }}
                            ></div>
                          </div>
                        </div>
                        <p className="text-sm text-gray-700">
                          Severity: {anomaly.severity}% | Confidence: {(anomaly.confidence * 100).toFixed(0)}%
                        </p>
                      </div>
                    </motion.div>
                  ))}
                </div>
              </div>
            )}

            {currentView === 'timeline' && (
              <motion.div variants={itemVariants}>
                <div className="bg-white/95 backdrop-blur-lg rounded-2xl shadow-xl p-6">
                  <h2 className="text-2xl font-bold text-gray-800 mb-4">Log Timeline Analysis</h2>
                  <div className="h-96">
                    <ResponsiveContainer width="100%" height="100%">
                      <LineChart data={timelineData}>
                        <XAxis dataKey="time" />
                        <YAxis />
                        <CartesianGrid strokeDasharray="3 3" />
                        <Tooltip />
                        <Line type="monotone" dataKey="errors" stroke="#ef4444" strokeWidth={3} dot={{ fill: '#ef4444', strokeWidth: 2, r: 4 }} />
                        <Line type="monotone" dataKey="warnings" stroke="#f59e0b" strokeWidth={3} dot={{ fill: '#f59e0b', strokeWidth: 2, r: 4 }} />
                        <Line type="monotone" dataKey="info" stroke="#3b82f6" strokeWidth={3} dot={{ fill: '#3b82f6', strokeWidth: 2, r: 4 }} />
                      </LineChart>
                    </ResponsiveContainer>
                  </div>
                </div>
              </motion.div>
            )}

            {currentView === 'analytics' && (
              <div className="space-y-6">
                <motion.div variants={itemVariants}>
                  <div className="bg-white/95 backdrop-blur-lg rounded-2xl shadow-xl p-6">
                    <h2 className="text-2xl font-bold text-gray-800 mb-4">ML-Powered Analytics</h2>
                    <div className="bg-blue-50 border border-blue-200 rounded-lg p-4 mb-6">
                      <p className="text-blue-800">
                        🤖 AI models have detected {anomalies.length} anomalies in the last 24 hours with an average confidence of 89.6%
                      </p>
                    </div>
                    <div className="h-80">
                      <ResponsiveContainer width="100%" height="100%">
                        <AreaChart data={anomalies}>
                          <defs>
                            <linearGradient id="severityGradient" x1="0" y1="0" x2="0" y2="1">
                              <stop offset="5%" stopColor="#e91e63" stopOpacity={0.8}/>
                              <stop offset="95%" stopColor="#e91e63" stopOpacity={0.1}/>
                            </linearGradient>
                          </defs>
                          <XAxis dataKey="time" />
                          <YAxis />
                          <CartesianGrid strokeDasharray="3 3" />
                          <Tooltip />
                          <Area type="monotone" dataKey="severity" stroke="#e91e63" fill="url(#severityGradient)" strokeWidth={3} />
                        </AreaChart>
                      </ResponsiveContainer>
                    </div>
                  </div>
                </motion.div>
              </div>
            )}

            {currentView === 'search' && (
              <div className="space-y-6">
                {/* Search Interface */}
                <motion.div variants={itemVariants}>
                  <div className="bg-white/95 backdrop-blur-lg rounded-2xl shadow-xl p-6">
                    <div className="relative mb-4">
                      <input
                        type="text"
                        placeholder="Search logs by message, source, or metadata..."
                        value={searchTerm}
                        onChange={(e) => setSearchTerm(e.target.value)}
                        className="w-full pl-12 pr-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-indigo-500 focus:border-transparent"
                      />
                      <svg className="absolute left-4 top-3.5 w-5 h-5 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
                      </svg>
                    </div>
                    <div className="flex flex-wrap gap-2">
                      {['ERROR', 'WARNING', 'INFO', 'DEBUG'].map((level) => (
                        <button
                          key={level}
                          onClick={() => toggleFilter(level)}
                          className={`px-3 py-1 rounded-full text-sm font-medium transition-colors ${
                            selectedFilters.includes(level)
                              ? getLogBadgeColor(level) + ' ring-2 ring-offset-2 ring-indigo-500'
                              : 'bg-gray-100 text-gray-700 hover:bg-gray-200'
                          }`}
                        >
                          {getLogIcon(level)} {level}
                        </button>
                      ))}
                    </div>
                  </div>
                </motion.div>

                {/* Log Stream */}
                <motion.div variants={itemVariants}>
                  <h3 className="text-xl font-bold text-white mb-4">
                    Live Log Stream ({filteredLogs.length} entries)
                  </h3>
                </motion.div>

                <div className="space-y-3">
                  <AnimatePresence>
                    {filteredLogs.map((log) => (
                      <motion.div
                        key={log.id}
                        variants={itemVariants}
                        initial="hidden"
                        animate="visible"
                        exit="hidden"
                        layout
                        className={`bg-white rounded-lg shadow-md p-4 border-l-4 ${getLogBgColor(log.level)}`}
                      >
                        <div className="flex items-start space-x-3">
                          <span className="text-2xl">{getLogIcon(log.level)}</span>
                          <div className="flex-1">
                            <div className="flex justify-between items-center mb-2">
                              <span className={`px-2 py-1 rounded-full text-xs font-medium ${getLogBadgeColor(log.level)}`}>
                                {log.level}
                              </span>
                              <span className="text-xs text-gray-500">
                                {new Date(log.timestamp).toLocaleTimeString()}
                              </span>
                            </div>
                            <p className="font-mono text-sm mb-2">
                              <span className="font-semibold">[{log.source}]</span> {log.message}
                            </p>
                            {log.metadata && (
                              <p className="font-mono text-xs text-gray-500">
                                {JSON.stringify(log.metadata)}
                              </p>
                            )}
                          </div>
                        </div>
                      </motion.div>
                    ))}
                  </AnimatePresence>
                </div>
              </div>
            )}
          </motion.div>
        </AnimatePresence>
      </main>

      {/* Floating Action Buttons */}
      <div className="fixed bottom-6 right-6 flex flex-col space-y-3">
        <motion.button
          whileHover={{ scale: 1.1 }}
          whileTap={{ scale: 0.9 }}
          onClick={() => setIsStreaming(!isStreaming)}
          className="w-14 h-14 bg-gradient-to-r from-indigo-500 to-purple-600 text-white rounded-full shadow-lg hover:shadow-xl transition-shadow flex items-center justify-center"
        >
          {isStreaming ? '⏸️' : '▶️'}
        </motion.button>
        <motion.button
          whileHover={{ scale: 1.1 }}
          whileTap={{ scale: 0.9 }}
          className="w-14 h-14 bg-gradient-to-r from-pink-500 to-red-600 text-white rounded-full shadow-lg hover:shadow-xl transition-shadow flex items-center justify-center"
        >
          📤
        </motion.button>
      </div>
    </div>
  );
};

export default AILogAnalyzer;
