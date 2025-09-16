import React, { useState, useEffect } from 'react';
import { LineChart, Line, AreaChart, Area, BarChart, Bar, PieChart, Pie, Cell, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, Legend } from 'recharts';
import { Activity, Database, Zap, TrendingUp, AlertTriangle, CheckCircle, Clock, Users, HardDrive, Cpu, BarChart3, Search, Filter, Download, Settings, RefreshCw, Eye } from 'lucide-react';

const DatabaseMonitoringDashboard = () => {
  const [activeTab, setActiveTab] = useState('overview');
  const [selectedDatabase, setSelectedDatabase] = useState('production');
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [selectedQuery, setSelectedQuery] = useState(null);
  const [refreshing, setRefreshing] = useState(false);
  const [searchTerm, setSearchTerm] = useState('');
  const [filterStatus, setFilterStatus] = useState('all');

  // Mock data for real-time metrics
  const [realTimeData, setRealTimeData] = useState([
    { time: '14:00', cpu: 45, memory: 62, connections: 128, queries: 1250 },
    { time: '14:05', cpu: 52, memory: 58, connections: 135, queries: 1340 },
    { time: '14:10', cpu: 38, memory: 61, connections: 142, queries: 1180 },
    { time: '14:15', cpu: 44, memory: 65, connections: 138, queries: 1290 },
    { time: '14:20', cpu: 49, memory: 63, connections: 145, queries: 1380 },
    { time: '14:25', cpu: 41, memory: 59, connections: 132, queries: 1220 },
  ]);

  const queryPerformanceData = [
    { hour: '00:00', avgTime: 0.8, slowQueries: 2, totalQueries: 450 },
    { hour: '04:00', avgTime: 0.6, slowQueries: 1, totalQueries: 320 },
    { hour: '08:00', avgTime: 1.2, slowQueries: 8, totalQueries: 1200 },
    { hour: '12:00', avgTime: 1.8, slowQueries: 15, totalQueries: 1800 },
    { hour: '16:00', avgTime: 1.4, slowQueries: 12, totalQueries: 1600 },
    { hour: '20:00', avgTime: 0.9, slowQueries: 4, totalQueries: 800 },
  ];

  const databases = [
    { key: 'production', name: 'Production DB', status: 'healthy', connections: 145, size: '2.3TB' },
    { key: 'staging', name: 'Staging DB', status: 'warning', connections: 23, size: '450GB' },
    { key: 'analytics', name: 'Analytics DB', status: 'healthy', connections: 67, size: '1.8TB' },
    { key: 'backup', name: 'Backup DB', status: 'healthy', connections: 5, size: '2.1TB' },
  ];

  const slowQueries = [
    {
      id: 1,
      query: 'SELECT * FROM orders o JOIN customers c ON o.customer_id = c.id WHERE o.date > ?',
      database: 'production',
      duration: 2.45,
      frequency: 125,
      lastExecuted: '2 min ago',
      status: 'critical',
      suggestion: 'Add composite index on (customer_id, date)'
    },
    {
      id: 2,
      query: 'UPDATE user_sessions SET last_activity = NOW() WHERE session_id = ?',
      database: 'production',
      duration: 1.23,
      frequency: 890,
      lastExecuted: '5 sec ago',
      status: 'warning',
      suggestion: 'Consider connection pooling optimization'
    },
    {
      id: 3,
      query: 'SELECT COUNT(*) FROM logs WHERE created_at BETWEEN ? AND ?',
      database: 'analytics',
      duration: 3.67,
      frequency: 45,
      lastExecuted: '1 min ago',
      status: 'critical',
      suggestion: 'Partition table by date range'
    },
    {
      id: 4,
      query: 'SELECT u.*, p.* FROM users u LEFT JOIN profiles p ON u.id = p.user_id',
      database: 'production',
      duration: 0.89,
      frequency: 234,
      lastExecuted: '10 sec ago',
      status: 'normal',
      suggestion: 'Query performance is acceptable'
    }
  ];

  const indexSuggestions = [
    {
      table: 'orders',
      columns: ['customer_id', 'created_at'],
      impact: 'High',
      estimatedImprovement: '65%',
      size: '45MB',
      reason: 'Frequent WHERE clauses on these columns'
    },
    {
      table: 'user_sessions',
      columns: ['session_id', 'last_activity'],
      impact: 'Medium',
      estimatedImprovement: '35%',
      size: '12MB',
      reason: 'UPDATE queries would benefit from this index'
    },
    {
      table: 'logs',
      columns: ['created_at'],
      impact: 'High',
      estimatedImprovement: '80%',
      size: '120MB',
      reason: 'Date range queries are frequent'
    }
  ];

  // Simulate real-time updates
  useEffect(() => {
    const interval = setInterval(() => {
      setRealTimeData(prev => {
        const newData = [...prev.slice(1)];
        const lastPoint = prev[prev.length - 1];
        const newTime = new Date(Date.now()).toLocaleTimeString('en-US', { 
          hour12: false, 
          hour: '2-digit', 
          minute: '2-digit' 
        });
        
        newData.push({
          time: newTime,
          cpu: Math.max(20, Math.min(80, lastPoint.cpu + (Math.random() - 0.5) * 10)),
          memory: Math.max(40, Math.min(85, lastPoint.memory + (Math.random() - 0.5) * 8)),
          connections: Math.max(100, Math.min(200, lastPoint.connections + Math.floor((Math.random() - 0.5) * 20))),
          queries: Math.max(1000, Math.min(2000, lastPoint.queries + Math.floor((Math.random() - 0.5) * 200)))
        });
        
        return newData;
      });
    }, 5000);

    return () => clearInterval(interval);
  }, []);

  const handleRefresh = () => {
    setRefreshing(true);
    setTimeout(() => setRefreshing(false), 1000);
  };

  const openQueryModal = (query) => {
    setSelectedQuery(query);
    setIsModalOpen(true);
  };

  const getStatusColor = (status) => {
    switch (status) {
      case 'critical': return 'text-red-500';
      case 'warning': return 'text-yellow-500';
      case 'normal': return 'text-green-500';
      default: return 'text-gray-500';
    }
  };

  const getStatusBadgeColor = (status) => {
    switch (status) {
      case 'healthy': return 'bg-green-100 text-green-800';
      case 'warning': return 'bg-yellow-100 text-yellow-800';
      case 'critical': return 'bg-red-100 text-red-800';
      default: return 'bg-gray-100 text-gray-800';
    }
  };

  const filteredQueries = slowQueries.filter(query => {
    const matchesSearch = query.query.toLowerCase().includes(searchTerm.toLowerCase()) ||
                         query.database.toLowerCase().includes(searchTerm.toLowerCase());
    const matchesFilter = filterStatus === 'all' || query.status === filterStatus;
    return matchesSearch && matchesFilter;
  });

  const MetricCard = ({ title, value, change, icon: Icon, color = "blue" }) => (
    <div className="bg-white rounded-xl shadow-sm border border-gray-100 p-6 hover:shadow-md transition-all duration-300">
      <div className="flex items-center justify-between">
        <div>
          <p className="text-sm font-medium text-gray-600">{title}</p>
          <p className="text-2xl font-bold text-gray-900 mt-1">{value}</p>
          {change && (
            <p className={`text-sm mt-1 flex items-center ${change > 0 ? 'text-green-600' : 'text-red-600'}`}>
              <TrendingUp className="w-4 h-4 mr-1" />
              {change > 0 ? '+' : ''}{change}%
            </p>
          )}
        </div>
        <div className={`p-3 rounded-lg bg-${color}-50`}>
          <Icon className={`w-6 h-6 text-${color}-600`} />
        </div>
      </div>
    </div>
  );

  const TabButton = ({ id, label, active, onClick }) => (
    <button
      onClick={() => onClick(id)}
      className={`px-6 py-3 font-medium text-sm rounded-lg transition-all duration-200 ${
        active
          ? 'bg-blue-600 text-white shadow-sm'
          : 'text-gray-600 hover:text-gray-900 hover:bg-gray-50'
      }`}
    >
      {label}
    </button>
  );

  return (
    <div className="min-h-screen bg-gray-50">
      {/* Header */}
      <div className="bg-white border-b border-gray-200 px-6 py-4">
        <div className="flex items-center justify-between">
          <div className="flex items-center space-x-4">
            <div className="flex items-center space-x-2">
              <Database className="w-8 h-8 text-blue-600" />
              <h1 className="text-2xl font-bold text-gray-900">DBMonitor Pro</h1>
            </div>
            <span className="text-sm text-gray-500">Enterprise Database Management</span>
          </div>
          
          <div className="flex items-center space-x-4">
            <select 
              value={selectedDatabase}
              onChange={(e) => setSelectedDatabase(e.target.value)}
              className="px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
            >
              {databases.map(db => (
                <option key={db.key} value={db.key}>{db.name}</option>
              ))}
            </select>
            
            <button
              onClick={handleRefresh}
              className={`p-2 text-gray-500 hover:text-gray-700 transition-colors ${refreshing ? 'animate-spin' : ''}`}
            >
              <RefreshCw className="w-5 h-5" />
            </button>
            
            <button className="p-2 text-gray-500 hover:text-gray-700">
              <Settings className="w-5 h-5" />
            </button>
          </div>
        </div>
      </div>

      {/* Navigation Tabs */}
      <div className="bg-white border-b border-gray-200 px-6">
        <div className="flex space-x-1">
          <TabButton id="overview" label="Overview" active={activeTab === 'overview'} onClick={setActiveTab} />
          <TabButton id="queries" label="Query Performance" active={activeTab === 'queries'} onClick={setActiveTab} />
          <TabButton id="indexes" label="Index Optimization" active={activeTab === 'indexes'} onClick={setActiveTab} />
          <TabButton id="monitoring" label="Real-time Monitoring" active={activeTab === 'monitoring'} onClick={setActiveTab} />
        </div>
      </div>

      <div className="p-6">
        {/* Overview Tab */}
        {activeTab === 'overview' && (
          <div className="space-y-6">
            {/* Metric Cards */}
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
              <MetricCard
                title="Active Connections"
                value="145"
                change={5.2}
                icon={Users}
                color="blue"
              />
              <MetricCard
                title="Avg Query Time"
                value="1.2ms"
                change={-12.5}
                icon={Clock}
                color="green"
              />
              <MetricCard
                title="CPU Usage"
                value="49%"
                change={2.1}
                icon={Cpu}
                color="orange"
              />
              <MetricCard
                title="Storage Used"
                value="2.3TB"
                change={1.8}
                icon={HardDrive}
                color="purple"
              />
            </div>

            {/* Database Status Overview */}
            <div className="bg-white rounded-xl shadow-sm border border-gray-100 p-6">
              <h2 className="text-lg font-semibold text-gray-900 mb-4">Database Status Overview</h2>
              <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
                {databases.map(db => (
                  <div key={db.key} className="p-4 border border-gray-200 rounded-lg hover:shadow-sm transition-shadow">
                    <div className="flex items-center justify-between mb-2">
                      <h3 className="font-medium text-gray-900">{db.name}</h3>
                      <span className={`px-2 py-1 text-xs font-medium rounded-full ${getStatusBadgeColor(db.status)}`}>
                        {db.status}
                      </span>
                    </div>
                    <div className="space-y-1 text-sm text-gray-600">
                      <div>Connections: {db.connections}</div>
                      <div>Size: {db.size}</div>
                    </div>
                  </div>
                ))}
              </div>
            </div>

            {/* Performance Chart */}
            <div className="bg-white rounded-xl shadow-sm border border-gray-100 p-6">
              <h2 className="text-lg font-semibold text-gray-900 mb-4">Query Performance Trends</h2>
              <ResponsiveContainer width="100%" height={300}>
                <AreaChart data={queryPerformanceData}>
                  <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
                  <XAxis dataKey="hour" stroke="#666" />
                  <YAxis stroke="#666" />
                  <Tooltip 
                    contentStyle={{ 
                      backgroundColor: 'white', 
                      border: '1px solid #e5e7eb', 
                      borderRadius: '8px',
                      boxShadow: '0 4px 6px -1px rgba(0, 0, 0, 0.1)'
                    }} 
                  />
                  <Area type="monotone" dataKey="avgTime" stroke="#3b82f6" fill="#3b82f6" fillOpacity={0.1} />
                  <Area type="monotone" dataKey="slowQueries" stroke="#ef4444" fill="#ef4444" fillOpacity={0.1} />
                </AreaChart>
              </ResponsiveContainer>
            </div>
          </div>
        )}

        {/* Query Performance Tab */}
        {activeTab === 'queries' && (
          <div className="space-y-6">
            {/* Filters */}
            <div className="bg-white rounded-xl shadow-sm border border-gray-100 p-4">
              <div className="flex flex-col sm:flex-row gap-4">
                <div className="flex-1">
                  <div className="relative">
                    <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 text-gray-400 w-4 h-4" />
                    <input
                      type="text"
                      placeholder="Search queries..."
                      value={searchTerm}
                      onChange={(e) => setSearchTerm(e.target.value)}
                      className="w-full pl-10 pr-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                    />
                  </div>
                </div>
                <select
                  value={filterStatus}
                  onChange={(e) => setFilterStatus(e.target.value)}
                  className="px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                >
                  <option value="all">All Status</option>
                  <option value="critical">Critical</option>
                  <option value="warning">Warning</option>
                  <option value="normal">Normal</option>
                </select>
                <button className="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors flex items-center space-x-2">
                  <Download className="w-4 h-4" />
                  <span>Export</span>
                </button>
              </div>
            </div>

            {/* Slow Queries Table */}
            <div className="bg-white rounded-xl shadow-sm border border-gray-100 overflow-hidden">
              <div className="p-6 border-b border-gray-200">
                <h2 className="text-lg font-semibold text-gray-900">Slow Query Analysis</h2>
              </div>
              <div className="overflow-x-auto">
                <table className="w-full">
                  <thead className="bg-gray-50">
                    <tr>
                      <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Query</th>
                      <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Database</th>
                      <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Duration</th>
                      <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Frequency</th>
                      <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Status</th>
                      <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Actions</th>
                    </tr>
                  </thead>
                  <tbody className="bg-white divide-y divide-gray-200">
                    {filteredQueries.map((query) => (
                      <tr key={query.id} className="hover:bg-gray-50 transition-colors">
                        <td className="px-6 py-4">
                          <div className="text-sm text-gray-900 font-mono max-w-xs truncate">
                            {query.query}
                          </div>
                        </td>
                        <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                          {query.database}
                        </td>
                        <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                          {query.duration}s
                        </td>
                        <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                          {query.frequency}/hr
                        </td>
                        <td className="px-6 py-4 whitespace-nowrap">
                          <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${
                            query.status === 'critical' ? 'bg-red-100 text-red-800' :
                            query.status === 'warning' ? 'bg-yellow-100 text-yellow-800' :
                            'bg-green-100 text-green-800'
                          }`}>
                            {query.status}
                          </span>
                        </td>
                        <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                          <button
                            onClick={() => openQueryModal(query)}
                            className="text-blue-600 hover:text-blue-900 flex items-center space-x-1"
                          >
                            <Eye className="w-4 h-4" />
                            <span>View</span>
                          </button>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </div>
          </div>
        )}

        {/* Index Optimization Tab */}
        {activeTab === 'indexes' && (
          <div className="space-y-6">
            <div className="bg-white rounded-xl shadow-sm border border-gray-100 p-6">
              <h2 className="text-lg font-semibold text-gray-900 mb-4">Index Optimization Recommendations</h2>
              <div className="space-y-4">
                {indexSuggestions.map((suggestion, index) => (
                  <div key={index} className="border border-gray-200 rounded-lg p-4 hover:shadow-sm transition-shadow">
                    <div className="flex items-start justify-between">
                      <div className="flex-1">
                        <div className="flex items-center space-x-3 mb-2">
                          <h3 className="font-medium text-gray-900">
                            Table: <span className="font-mono text-blue-600">{suggestion.table}</span>
                          </h3>
                          <span className={`px-2 py-1 text-xs font-medium rounded-full ${
                            suggestion.impact === 'High' ? 'bg-red-100 text-red-800' :
                            suggestion.impact === 'Medium' ? 'bg-yellow-100 text-yellow-800' :
                            'bg-green-100 text-green-800'
                          }`}>
                            {suggestion.impact} Impact
                          </span>
                        </div>
                        <div className="grid grid-cols-1 md:grid-cols-3 gap-4 text-sm text-gray-600">
                          <div>
                            <span className="font-medium">Columns:</span> {suggestion.columns.join(', ')}
                          </div>
                          <div>
                            <span className="font-medium">Est. Improvement:</span> {suggestion.estimatedImprovement}
                          </div>
                          <div>
                            <span className="font-medium">Index Size:</span> {suggestion.size}
                          </div>
                        </div>
                        <p className="text-sm text-gray-600 mt-2">{suggestion.reason}</p>
                      </div>
                      <div className="flex space-x-2 ml-4">
                        <button className="px-3 py-1 text-xs bg-blue-600 text-white rounded hover:bg-blue-700 transition-colors">
                          Create Index
                        </button>
                        <button className="px-3 py-1 text-xs border border-gray-300 text-gray-700 rounded hover:bg-gray-50 transition-colors">
                          Analyze
                        </button>
                      </div>
                    </div>
                  </div>
                ))}
              </div>
            </div>
          </div>
        )}

        {/* Real-time Monitoring Tab */}
        {activeTab === 'monitoring' && (
          <div className="space-y-6">
            <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
              {/* CPU & Memory Chart */}
              <div className="bg-white rounded-xl shadow-sm border border-gray-100 p-6">
                <h3 className="text-lg font-semibold text-gray-900 mb-4">CPU & Memory Usage</h3>
                <ResponsiveContainer width="100%" height={250}>
                  <LineChart data={realTimeData}>
                    <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
                    <XAxis dataKey="time" stroke="#666" />
                    <YAxis stroke="#666" />
                    <Tooltip 
                      contentStyle={{ 
                        backgroundColor: 'white', 
                        border: '1px solid #e5e7eb', 
                        borderRadius: '8px',
                        boxShadow: '0 4px 6px -1px rgba(0, 0, 0, 0.1)'
                      }} 
                    />
                    <Line type="monotone" dataKey="cpu" stroke="#3b82f6" strokeWidth={2} dot={false} />
                    <Line type="monotone" dataKey="memory" stroke="#10b981" strokeWidth={2} dot={false} />
                  </LineChart>
                </ResponsiveContainer>
              </div>

              {/* Connections Chart */}
              <div className="bg-white rounded-xl shadow-sm border border-gray-100 p-6">
                <h3 className="text-lg font-semibold text-gray-900 mb-4">Active Connections</h3>
                <ResponsiveContainer width="100%" height={250}>
                  <AreaChart data={realTimeData}>
                    <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
                    <XAxis dataKey="time" stroke="#666" />
                    <YAxis stroke="#666" />
                    <Tooltip 
                      contentStyle={{ 
                        backgroundColor: 'white', 
                        border: '1px solid #e5e7eb', 
                        borderRadius: '8px',
                        boxShadow: '0 4px 6px -1px rgba(0, 0, 0, 0.1)'
                      }} 
                    />
                    <Area type="monotone" dataKey="connections" stroke="#8b5cf6" fill="#8b5cf6" fillOpacity={0.2} />
                  </AreaChart>
                </ResponsiveContainer>
              </div>
            </div>

            {/* Queries per Second */}
            <div className="bg-white rounded-xl shadow-sm border border-gray-100 p-6">
              <h3 className="text-lg font-semibold text-gray-900 mb-4">Queries per Second</h3>
              <ResponsiveContainer width="100%" height={300}>
                <BarChart data={realTimeData}>
                  <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
                  <XAxis dataKey="time" stroke="#666" />
                  <YAxis stroke="#666" />
                  <Tooltip 
                    contentStyle={{ 
                      backgroundColor: 'white', 
                      border: '1px solid #e5e7eb', 
                      borderRadius: '8px',
                      boxShadow: '0 4px 6px -1px rgba(0, 0, 0, 0.1)'
                    }} 
                  />
                  <Bar dataKey="queries" fill="#f59e0b" radius={[2, 2, 0, 0]} />
                </BarChart>
              </ResponsiveContainer>
            </div>
          </div>
        )}
      </div>

      {/* Query Details Modal */}
      {isModalOpen && selectedQuery && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-50">
          <div className="bg-white rounded-xl shadow-2xl max-w-4xl w-full max-h-[90vh] overflow-y-auto">
            <div className="p-6 border-b border-gray-200">
              <div className="flex items-center justify-between">
                <h2 className="text-xl font-semibold text-gray-900">Query Details</h2>
                <button
                  onClick={() => setIsModalOpen(false)}
                  className="text-gray-400 hover:text-gray-600"
                >
                  <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
                  </svg>
                </button>
              </div>
            </div>
            
            <div className="p-6 space-y-6">
              <div>
                <h3 className="text-sm font-medium text-gray-500 mb-2">SQL Query</h3>
                <div className="bg-gray-900 text-gray-100 p-4 rounded-lg font-mono text-sm overflow-x-auto">
                  {selectedQuery.query}
                </div>
              </div>
              
              <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                <div>
                  <h3 className="text-sm font-medium text-gray-500 mb-3">Performance Metrics</h3>
                  <div className="space-y-3">
                    <div className="flex justify-between">
                      <span className="text-gray-600">Execution Time:</span>
                      <span className="font-medium">{selectedQuery.duration}s</span>
                    </div>
                    <div className="flex justify-between">
                      <span className="text-gray-600">Frequency:</span>
                      <span className="font-medium">{selectedQuery.frequency}/hr</span>
                    </div>
                    <div className="flex justify-between">
                      <span className="text-gray-600">Database:</span>
                      <span className="font-medium">{selectedQuery.database}</span>
                    </div>
                    <div className="flex justify-between">
                      <span className="text-gray-600">Last Executed:</span>
                      <span className="font-medium">{selectedQuery.lastExecuted}</span>
                    </div>
                  </div>
                </div>
                
                <div>
                  <h3 className="text-sm font-medium text-gray-500 mb-3">Optimization</h3>
                  <div className="p-4 bg-blue-50 border border-blue-200 rounded-lg">
                    <div className="flex items-start space-x-2">
                      <AlertTriangle className="w-5 h-5 text-blue-600 mt-0.5" />
                      <div>
                        <p className="text-sm font-medium text-blue-900">Suggestion</p>
                        <p className="text-sm text-blue-700 mt-1">{selectedQuery.suggestion}</p>
                      </div>
                    </div>
                  </div>
                </div>
              </div>
              
              <div className="flex justify-end space-x-3 pt-4 border-t border-gray-200">
                <button
                  onClick={() => setIsModalOpen(false)}
                  className="px-4 py-2 text-gray-700 border border-gray-300 rounded-lg hover:bg-gray-50 transition-colors"
                >
                  Close
                </button>
                <button className="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors">
                  Optimize Query
                </button>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default DatabaseMonitoringDashboard;
