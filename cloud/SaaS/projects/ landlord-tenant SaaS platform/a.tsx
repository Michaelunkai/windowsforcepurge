import React, { useState, useEffect } from 'react';
import { 
  Home, Users, Building, CreditCard, Wrench, MessageSquare, 
  FileText, Settings, Bell, Menu, X, Plus, Search, Filter,
  Calendar, DollarSign, AlertTriangle, CheckCircle, Clock,
  Upload, Send, Phone, Mail, MapPin, Star, TrendingUp,
  Shield, Zap, Eye, Edit, Trash2, Download, User
} from 'lucide-react';

// Mock data
const mockUsers = {
  landlords: [
    { id: 1, name: 'John Smith', email: 'john@example.com', properties: 3, tenants: 8, revenue: 12500 },
    { id: 2, name: 'Sarah Johnson', email: 'sarah@example.com', properties: 1, tenants: 2, revenue: 3200 }
  ],
  tenants: [
    { id: 1, name: 'Mike Wilson', email: 'mike@example.com', property: 'Sunset Apartments #101', rent: 1200, status: 'current' },
    { id: 2, name: 'Lisa Chen', email: 'lisa@example.com', property: 'Oak Street House', rent: 1800, status: 'late' }
  ]
};

const mockProperties = [
  { id: 1, name: 'Sunset Apartments', address: '123 Sunset Blvd', units: 4, occupied: 3, revenue: 4800 },
  { id: 2, name: 'Oak Street House', address: '456 Oak Street', units: 1, occupied: 1, revenue: 1800 }
];

const mockTickets = [
  { id: 1, title: 'Leaky Faucet', property: 'Sunset Apartments #101', tenant: 'Mike Wilson', priority: 'medium', status: 'open', date: '2025-07-25' },
  { id: 2, title: 'AC Not Working', property: 'Oak Street House', tenant: 'Lisa Chen', priority: 'high', status: 'in-progress', date: '2025-07-24' }
];

const mockMessages = [
  { id: 1, from: 'Mike Wilson', to: 'John Smith', message: 'Hi, the rent payment went through successfully.', timestamp: '2025-07-28 10:30', unread: false },
  { id: 2, from: 'Lisa Chen', to: 'John Smith', message: 'When will the maintenance issue be resolved?', timestamp: '2025-07-28 09:15', unread: true }
];

const PropertyTenantSaaS = () => {
  const [currentUser, setCurrentUser] = useState(null);
  const [userType, setUserType] = useState(null);
  const [currentView, setCurrentView] = useState('dashboard');
  const [sidebarOpen, setSidebarOpen] = useState(false);
  const [showPaymentModal, setShowPaymentModal] = useState(false);
  const [showTicketModal, setShowTicketModal] = useState(false);
  const [showMessageModal, setShowMessageModal] = useState(false);
  const [notifications, setNotifications] = useState([]);

  // Login system
  const LoginScreen = () => {
    const [email, setEmail] = useState('');
    const [password, setPassword] = useState('');
    const [loginType, setLoginType] = useState('landlord');

    const handleLogin = () => {
      if (loginType === 'landlord') {
        setCurrentUser(mockUsers.landlords[0]);
        setUserType('landlord');
      } else if (loginType === 'tenant') {
        setCurrentUser(mockUsers.tenants[0]);
        setUserType('tenant');
      } else {
        setCurrentUser({ id: 1, name: 'Admin User', email: 'admin@example.com' });
        setUserType('admin');
      }
    };

    return (
      <div className="min-h-screen bg-gradient-to-br from-blue-500 to-purple-600 flex items-center justify-center p-4">
        <div className="bg-white rounded-2xl shadow-2xl w-full max-w-md p-8">
          <div className="text-center mb-8">
            <div className="bg-blue-100 rounded-full w-20 h-20 flex items-center justify-center mx-auto mb-4">
              <Building className="w-10 h-10 text-blue-600" />
            </div>
            <h1 className="text-3xl font-bold text-gray-900">PropertyHub</h1>
            <p className="text-gray-600 mt-2">Manage properties, tenants & rent</p>
          </div>

          <div className="space-y-6">
            <div className="flex bg-gray-100 rounded-lg p-1 mb-6">
              <button
                type="button"
                onClick={() => setLoginType('landlord')}
                className={`flex-1 py-2 px-4 rounded-md text-sm font-medium transition-colors ${
                  loginType === 'landlord' ? 'bg-white text-blue-600 shadow' : 'text-gray-600'
                }`}
              >
                Landlord
              </button>
              <button
                type="button"
                onClick={() => setLoginType('tenant')}
                className={`flex-1 py-2 px-4 rounded-md text-sm font-medium transition-colors ${
                  loginType === 'tenant' ? 'bg-white text-blue-600 shadow' : 'text-gray-600'
                }`}
              >
                Tenant
              </button>
              <button
                type="button"
                onClick={() => setLoginType('admin')}
                className={`flex-1 py-2 px-4 rounded-md text-sm font-medium transition-colors ${
                  loginType === 'admin' ? 'bg-white text-blue-600 shadow' : 'text-gray-600'
                }`}
              >
                Admin
              </button>
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">Email</label>
              <input
                type="email"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                className="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                placeholder="Enter your email"
              />
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">Password</label>
              <input
                type="password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                className="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                placeholder="Enter your password"
              />
            </div>

            <button
              onClick={handleLogin}
              className="w-full bg-blue-600 text-white py-3 rounded-lg font-medium hover:bg-blue-700 transition-colors"
            >
              Sign In
            </button>
          </div>

          <div className="mt-6 text-center text-sm text-gray-600">
            Demo credentials: any email/password combination
          </div>
        </div>
      </div>
    );
  };

  // Navigation items for different user types
  const getNavigationItems = () => {
    const baseItems = [
      { id: 'dashboard', label: 'Dashboard', icon: Home },
      { id: 'messages', label: 'Messages', icon: MessageSquare }
    ];

    if (userType === 'landlord') {
      return [
        ...baseItems,
        { id: 'properties', label: 'Properties', icon: Building },
        { id: 'tenants', label: 'Tenants', icon: Users },
        { id: 'payments', label: 'Payments', icon: CreditCard },
        { id: 'maintenance', label: 'Maintenance', icon: Wrench },
        { id: 'leases', label: 'Leases', icon: FileText },
        { id: 'billing', label: 'Billing', icon: DollarSign },
        { id: 'settings', label: 'Settings', icon: Settings }
      ];
    } else if (userType === 'tenant') {
      return [
        ...baseItems,
        { id: 'rent', label: 'Pay Rent', icon: CreditCard },
        { id: 'maintenance', label: 'Maintenance', icon: Wrench },
        { id: 'lease', label: 'My Lease', icon: FileText },
        { id: 'profile', label: 'Profile', icon: User }
      ];
    } else {
      return [
        ...baseItems,
        { id: 'users', label: 'Users', icon: Users },
        { id: 'properties', label: 'Properties', icon: Building },
        { id: 'analytics', label: 'Analytics', icon: TrendingUp },
        { id: 'billing', label: 'Billing', icon: DollarSign },
        { id: 'settings', label: 'Settings', icon: Settings }
      ];
    }
  };

  // Sidebar component
  const Sidebar = () => (
    <div className={`fixed inset-y-0 left-0 z-50 w-64 bg-white shadow-lg transform ${sidebarOpen ? 'translate-x-0' : '-translate-x-full'} lg:translate-x-0 transition-transform duration-200 ease-in-out`}>
      <div className="flex items-center justify-between h-16 px-6 border-b">
        <div className="flex items-center">
          <Building className="w-8 h-8 text-blue-600" />
          <span className="ml-2 text-xl font-bold text-gray-900">PropertyHub</span>
        </div>
        <button
          onClick={() => setSidebarOpen(false)}
          className="lg:hidden p-2 rounded-md text-gray-400 hover:text-gray-600"
        >
          <X className="w-5 h-5" />
        </button>
      </div>
      
      <nav className="mt-6">
        {getNavigationItems().map((item) => (
          <button
            key={item.id}
            onClick={() => {
              setCurrentView(item.id);
              setSidebarOpen(false);
            }}
            className={`w-full flex items-center px-6 py-3 text-left hover:bg-blue-50 transition-colors ${
              currentView === item.id ? 'bg-blue-50 text-blue-600 border-r-2 border-blue-600' : 'text-gray-700'
            }`}
          >
            <item.icon className="w-5 h-5 mr-3" />
            {item.label}
          </button>
        ))}
      </nav>
    </div>
  );

  // Header component
  const Header = () => (
    <header className="h-16 bg-white shadow-sm border-b flex items-center justify-between px-6 lg:px-8">
      <div className="flex items-center">
        <button
          onClick={() => setSidebarOpen(true)}
          className="lg:hidden p-2 rounded-md text-gray-400 hover:text-gray-600"
        >
          <Menu className="w-5 h-5" />
        </button>
        <h1 className="text-2xl font-bold text-gray-900 ml-2 lg:ml-0">
          {getNavigationItems().find(item => item.id === currentView)?.label || 'Dashboard'}
        </h1>
      </div>
      
      <div className="flex items-center space-x-4">
        <button className="p-2 text-gray-400 hover:text-gray-600 relative">
          <Bell className="w-5 h-5" />
          {notifications.length > 0 && (
            <span className="absolute -top-1 -right-1 bg-red-500 text-white text-xs rounded-full w-5 h-5 flex items-center justify-center">
              {notifications.length}
            </span>
          )}
        </button>
        <div className="flex items-center space-x-3">
          <div className="text-right hidden sm:block">
            <p className="text-sm font-medium text-gray-900">{currentUser?.name}</p>
            <p className="text-xs text-gray-500 capitalize">{userType}</p>
          </div>
          <div className="w-8 h-8 bg-blue-100 rounded-full flex items-center justify-center">
            <span className="text-sm font-medium text-blue-600">
              {currentUser?.name?.charAt(0)}
            </span>
          </div>
        </div>
      </div>
    </header>
  );

  // Payment Modal
  const PaymentModal = () => (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-50">
      <div className="bg-white rounded-lg max-w-md w-full p-6">
        <div className="flex justify-between items-center mb-6">
          <h3 className="text-lg font-semibold">Pay Rent</h3>
          <button onClick={() => setShowPaymentModal(false)}>
            <X className="w-5 h-5" />
          </button>
        </div>
        
        <div className="space-y-4">
          <div className="bg-gray-50 p-4 rounded-lg">
            <p className="text-sm text-gray-600">Amount Due</p>
            <p className="text-2xl font-bold text-gray-900">$1,200.00</p>
            <p className="text-sm text-gray-600">Due: August 1, 2025</p>
          </div>
          
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">
              Payment Method
            </label>
            <select className="w-full px-3 py-2 border border-gray-300 rounded-md">
              <option>Bank Account (ACH) - ****1234</option>
              <option>Add New Account</option>
            </select>
          </div>
          
          <div className="flex space-x-3">
            <button
              onClick={() => setShowPaymentModal(false)}
              className="flex-1 px-4 py-2 border border-gray-300 rounded-md text-gray-700 hover:bg-gray-50"
            >
              Cancel
            </button>
            <button className="flex-1 px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700">
              Pay Now
            </button>
          </div>
        </div>
      </div>
    </div>
  );

  // Maintenance Ticket Modal
  const TicketModal = () => (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-50">
      <div className="bg-white rounded-lg max-w-md w-full p-6">
        <div className="flex justify-between items-center mb-6">
          <h3 className="text-lg font-semibold">Submit Maintenance Request</h3>
          <button onClick={() => setShowTicketModal(false)}>
            <X className="w-5 h-5" />
          </button>
        </div>
        
        <div className="space-y-4">
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">
              Issue Title
            </label>
            <input
              type="text"
              className="w-full px-3 py-2 border border-gray-300 rounded-md"
              placeholder="Brief description of the issue"
            />
          </div>
          
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">
              Priority
            </label>
            <select className="w-full px-3 py-2 border border-gray-300 rounded-md">
              <option>Low</option>
              <option>Medium</option>
              <option>High</option>
              <option>Emergency</option>
            </select>
          </div>
          
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">
              Description
            </label>
            <textarea
              className="w-full px-3 py-2 border border-gray-300 rounded-md"
              rows={4}
              placeholder="Detailed description of the maintenance issue"
            />
          </div>
          
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">
              Photos
            </label>
            <div className="border-2 border-dashed border-gray-300 rounded-md p-6 text-center">
              <Upload className="w-8 h-8 text-gray-400 mx-auto mb-2" />
              <p className="text-sm text-gray-600">Click to upload photos</p>
            </div>
          </div>
          
          <div className="flex space-x-3">
            <button
              onClick={() => setShowTicketModal(false)}
              className="flex-1 px-4 py-2 border border-gray-300 rounded-md text-gray-700 hover:bg-gray-50"
            >
              Cancel
            </button>
            <button className="flex-1 px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700">
              Submit Request
            </button>
          </div>
        </div>
      </div>
    </div>
  );

  // Dashboard Views
  const LandlordDashboard = () => (
    <div className="space-y-6">
      {/* Stats Cards */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
        <div className="bg-white p-6 rounded-lg shadow">
          <div className="flex items-center">
            <div className="p-2 bg-blue-100 rounded-lg">
              <Building className="w-6 h-6 text-blue-600" />
            </div>
            <div className="ml-4">
              <p className="text-sm font-medium text-gray-600">Properties</p>
              <p className="text-2xl font-bold text-gray-900">5</p>
            </div>
          </div>
        </div>
        
        <div className="bg-white p-6 rounded-lg shadow">
          <div className="flex items-center">
            <div className="p-2 bg-green-100 rounded-lg">
              <Users className="w-6 h-6 text-green-600" />
            </div>
            <div className="ml-4">
              <p className="text-sm font-medium text-gray-600">Active Tenants</p>
              <p className="text-2xl font-bold text-gray-900">18</p>
            </div>
          </div>
        </div>
        
        <div className="bg-white p-6 rounded-lg shadow">
          <div className="flex items-center">
            <div className="p-2 bg-yellow-100 rounded-lg">
              <DollarSign className="w-6 h-6 text-yellow-600" />
            </div>
            <div className="ml-4">
              <p className="text-sm font-medium text-gray-600">Monthly Revenue</p>
              <p className="text-2xl font-bold text-gray-900">$24,500</p>
            </div>
          </div>
        </div>
        
        <div className="bg-white p-6 rounded-lg shadow">
          <div className="flex items-center">
            <div className="p-2 bg-red-100 rounded-lg">
              <Wrench className="w-6 h-6 text-red-600" />
            </div>
            <div className="ml-4">
              <p className="text-sm font-medium text-gray-600">Open Tickets</p>
              <p className="text-2xl font-bold text-gray-900">7</p>
            </div>
          </div>
        </div>
      </div>

      {/* Recent Activity & Quick Actions */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <div className="bg-white p-6 rounded-lg shadow">
          <h3 className="text-lg font-semibold mb-4">Recent Maintenance Requests</h3>
          <div className="space-y-3">
            {mockTickets.map((ticket) => (
              <div key={ticket.id} className="flex items-center justify-between p-3 bg-gray-50 rounded-md">
                <div>
                  <p className="font-medium">{ticket.title}</p>
                  <p className="text-sm text-gray-600">{ticket.property}</p>
                </div>
                <span className={`px-2 py-1 text-xs rounded-full ${
                  ticket.priority === 'high' ? 'bg-red-100 text-red-800' : 
                  ticket.priority === 'medium' ? 'bg-yellow-100 text-yellow-800' : 
                  'bg-green-100 text-green-800'
                }`}>
                  {ticket.priority}
                </span>
              </div>
            ))}
          </div>
        </div>
        
        <div className="bg-white p-6 rounded-lg shadow">
          <h3 className="text-lg font-semibold mb-4">Quick Actions</h3>
          <div className="grid grid-cols-2 gap-3">
            <button className="p-4 bg-blue-50 rounded-lg text-left hover:bg-blue-100 transition-colors">
              <Plus className="w-6 h-6 text-blue-600 mb-2" />
              <p className="font-medium text-blue-900">Add Property</p>
            </button>
            <button className="p-4 bg-green-50 rounded-lg text-left hover:bg-green-100 transition-colors">
              <Users className="w-6 h-6 text-green-600 mb-2" />
              <p className="font-medium text-green-900">Add Tenant</p>
            </button>
            <button className="p-4 bg-purple-50 rounded-lg text-left hover:bg-purple-100 transition-colors">
              <FileText className="w-6 h-6 text-purple-600 mb-2" />
              <p className="font-medium text-purple-900">Upload Lease</p>
            </button>
            <button className="p-4 bg-orange-50 rounded-lg text-left hover:bg-orange-100 transition-colors">
              <MessageSquare className="w-6 h-6 text-orange-600 mb-2" />
              <p className="font-medium text-orange-900">Send Message</p>
            </button>
          </div>
        </div>
      </div>
    </div>
  );

  const TenantDashboard = () => (
    <div className="space-y-6">
      {/* Rent Status Card */}
      <div className="bg-white p-6 rounded-lg shadow">
        <div className="flex items-center justify-between">
          <div>
            <h3 className="text-lg font-semibold">Rent Status</h3>
            <p className="text-3xl font-bold text-green-600 mt-2">Paid</p>
            <p className="text-sm text-gray-600">Next payment due: August 1, 2025</p>
          </div>
          <div className="text-right">
            <p className="text-2xl font-bold text-gray-900">$1,200</p>
            <button
              onClick={() => setShowPaymentModal(true)}
              className="mt-2 px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700"
            >
              Pay Early
            </button>
          </div>
        </div>
      </div>

      {/* Quick Actions */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
        <button
          onClick={() => setShowTicketModal(true)}
          className="bg-white p-6 rounded-lg shadow hover:shadow-md transition-shadow text-left"
        >
          <Wrench className="w-8 h-8 text-blue-600 mb-3" />
          <h3 className="font-semibold">Maintenance Request</h3>
          <p className="text-sm text-gray-600 mt-1">Report an issue with your unit</p>
        </button>
        
        <button className="bg-white p-6 rounded-lg shadow hover:shadow-md transition-shadow text-left">
          <MessageSquare className="w-8 h-8 text-green-600 mb-3" />
          <h3 className="font-semibold">Contact Landlord</h3>
          <p className="text-sm text-gray-600 mt-1">Send a message to your landlord</p>
        </button>
        
        <button className="bg-white p-6 rounded-lg shadow hover:shadow-md transition-shadow text-left">
          <FileText className="w-8 h-8 text-purple-600 mb-3" />
          <h3 className="font-semibold">View Lease</h3>
          <p className="text-sm text-gray-600 mt-1">Access your lease documents</p>
        </button>
      </div>

      {/* Recent Activity */}
      <div className="bg-white p-6 rounded-lg shadow">
        <h3 className="text-lg font-semibold mb-4">Recent Activity</h3>
        <div className="space-y-3">
          <div className="flex items-center justify-between p-3 bg-gray-50 rounded-md">
            <div className="flex items-center">
              <CheckCircle className="w-5 h-5 text-green-500 mr-3" />
              <div>
                <p className="font-medium">Rent Payment Processed</p>
                <p className="text-sm text-gray-600">July 1, 2025 - $1,200</p>
              </div>
            </div>
          </div>
          <div className="flex items-center justify-between p-3 bg-gray-50 rounded-md">
            <div className="flex items-center">
              <Clock className="w-5 h-5 text-yellow-500 mr-3" />
              <div>
                <p className="font-medium">Maintenance Request Submitted</p>
                <p className="text-sm text-gray-600">June 28, 2025 - Leaky faucet</p>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );

  const AdminDashboard = () => (
    <div className="space-y-6">
      {/* System Stats */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
        <div className="bg-white p-6 rounded-lg shadow">
          <div className="flex items-center">
            <div className="p-2 bg-blue-100 rounded-lg">
              <Users className="w-6 h-6 text-blue-600" />
            </div>
            <div className="ml-4">
              <p className="text-sm font-medium text-gray-600">Total Users</p>
              <p className="text-2xl font-bold text-gray-900">1,247</p>
            </div>
          </div>
        </div>
        
        <div className="bg-white p-6 rounded-lg shadow">
          <div className="flex items-center">
            <div className="p-2 bg-green-100 rounded-lg">
              <DollarSign className="w-6 h-6 text-green-600" />
            </div>
            <div className="ml-4">
              <p className="text-sm font-medium text-gray-600">Monthly Revenue</p>
              <p className="text-2xl font-bold text-gray-900">$47,230</p>
            </div>
          </div>
        </div>
        
        <div className="bg-white p-6 rounded-lg shadow">
          <div className="flex items-center">
            <div className="p-2 bg-yellow-100 rounded-lg">
              <Building className="w-6 h-6 text-yellow-600" />
            </div>
            <div className="ml-4">
              <p className="text-sm font-medium text-gray-600">Active Properties</p>
              <p className="text-2xl font-bold text-gray-900">342</p>
            </div>
          </div>
        </div>
        
        <div className="bg-white p-6 rounded-lg shadow">
          <div className="flex items-center">
            <div className="p-2 bg-purple-100 rounded-lg">
              <TrendingUp className="w-6 h-6 text-purple-600" />
            </div>
            <div className="ml-4">
              <p className="text-sm font-medium text-gray-600">Growth Rate</p>
              <p className="text-2xl font-bold text-gray-900">+12%</p>
            </div>
          </div>
        </div>
      </div>

      {/* System Health & Recent Activity */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <div className="bg-white p-6 rounded-lg shadow">
          <h3 className="text-lg font-semibold mb-4">System Health</h3>
          <div className="space-y-3">
            <div className="flex items-center justify-between">
              <div className="flex items-center">
                <div className="w-3 h-3 bg-green-500 rounded-full mr-3"></div>
                <span>API Response Time</span>
              </div>
              <span className="text-sm text-gray-600">234ms</span>
            </div>
            <div className="flex items-center justify-between">
              <div className="flex items-center">
                <div className="w-3 h-3 bg-green-500 rounded-full mr-3"></div>
                <span>Database Performance</span>
              </div>
              <span className="text-sm text-gray-600">Optimal</span>
            </div>
            <div className="flex items-center justify-between">
              <div className="flex items-center">
                <div className="w-3 h-3 bg-yellow-500 rounded-full mr-3"></div>
                <span>Payment Processing</span>
              </div>
              <span className="text-sm text-gray-600">99.2% uptime</span>
            </div>
          </div>
        </div>
        
        <div className="bg-white p-6 rounded-lg shadow">
          <h3 className="text-lg font-semibold mb-4">Recent User Activity</h3>
          <div className="space-y-3">
            <div className="flex items-center justify-between p-3 bg-gray-50 rounded-md">
              <div>
                <p className="font-medium">New Landlord Registration</p>
                <p className="text-sm text-gray-600">sarah.johnson@email.com</p>
              </div>
              <span className="text-xs text-gray-500">2m ago</span>
            </div>
            <div className="flex items-center justify-between p-3 bg-gray-50 rounded-md">
              <div>
                <p className="font-medium">Payment Processed</p>
                <p className="text-sm text-gray-600">$2,400 rent payment</p>
              </div>
              <span className="text-xs text-gray-500">5m ago</span>
            </div>
          </div>
        </div>
      </div>
    </div>
  );

  // Content Views
  const PropertiesView = () => (
    <div className="space-y-6">
      <div className="flex justify-between items-center">
        <div className="flex items-center space-x-4">
          <div className="relative">
            <Search className="w-5 h-5 absolute left-3 top-1/2 transform -translate-y-1/2 text-gray-400" />
            <input
              type="text"
              placeholder="Search properties..."
              className="pl-10 pr-4 py-2 border border-gray-300 rounded-lg"
            />
          </div>
          <button className="p-2 border border-gray-300 rounded-lg">
            <Filter className="w-5 h-5" />
          </button>
        </div>
        <button className="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700">
          <Plus className="w-4 h-4 inline mr-2" />
          Add Property
        </button>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
        {mockProperties.map((property) => (
          <div key={property.id} className="bg-white rounded-lg shadow overflow-hidden">
            <div className="h-48 bg-gradient-to-r from-blue-500 to-purple-600"></div>
            <div className="p-6">
              <h3 className="text-lg font-semibold mb-2">{property.name}</h3>
              <p className="text-gray-600 mb-4">{property.address}</p>
              <div className="flex justify-between items-center text-sm">
                <span>{property.occupied}/{property.units} occupied</span>
                <span className="font-semibold">${property.revenue}/mo</span>
              </div>
              <div className="mt-4 flex space-x-2">
                <button className="flex-1 px-3 py-2 bg-blue-100 text-blue-700 rounded-md hover:bg-blue-200">
                  <Eye className="w-4 h-4 inline mr-1" />
                  View
                </button>
                <button className="flex-1 px-3 py-2 bg-gray-100 text-gray-700 rounded-md hover:bg-gray-200">
                  <Edit className="w-4 h-4 inline mr-1" />
                  Edit
                </button>
              </div>
            </div>
          </div>
        ))}
      </div>
    </div>
  );

  const PaymentsView = () => (
    <div className="space-y-6">
      <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
        <div className="bg-white p-6 rounded-lg shadow">
          <h3 className="text-sm font-medium text-gray-600">This Month</h3>
          <p className="text-2xl font-bold text-green-600">$24,500</p>
          <p className="text-sm text-gray-500">+5.2% from last month</p>
        </div>
        <div className="bg-white p-6 rounded-lg shadow">
          <h3 className="text-sm font-medium text-gray-600">Pending</h3>
          <p className="text-2xl font-bold text-yellow-600">$3,200</p>
          <p className="text-sm text-gray-500">2 late payments</p>
        </div>
        <div className="bg-white p-6 rounded-lg shadow">
          <h3 className="text-sm font-medium text-gray-600">Processing Fees</h3>
          <p className="text-2xl font-bold text-gray-900">$147</p>
          <p className="text-sm text-gray-500">0.6% of total</p>
        </div>
      </div>

      <div className="bg-white rounded-lg shadow">
        <div className="p-6 border-b">
          <h3 className="text-lg font-semibold">Recent Payments</h3>
        </div>
        <div className="divide-y">
          {[
            { tenant: 'Mike Wilson', amount: 1200, date: '2025-07-28', status: 'completed' },
            { tenant: 'Lisa Chen', amount: 1800, date: '2025-07-27', status: 'pending' },
            { tenant: 'John Doe', amount: 1500, date: '2025-07-26', status: 'completed' }
          ].map((payment, index) => (
            <div key={index} className="p-6 flex items-center justify-between">
              <div>
                <p className="font-medium">{payment.tenant}</p>
                <p className="text-sm text-gray-600">{payment.date}</p>
              </div>
              <div className="text-right">
                <p className="font-semibold">${payment.amount}</p>
                <span className={`inline-block px-2 py-1 text-xs rounded-full ${
                  payment.status === 'completed' ? 'bg-green-100 text-green-800' : 'bg-yellow-100 text-yellow-800'
                }`}>
                  {payment.status}
                </span>
              </div>
            </div>
          ))}
        </div>
      </div>
    </div>
  );

  const MessagesView = () => (
    <div className="bg-white rounded-lg shadow h-96 flex">
      <div className="w-1/3 border-r">
        <div className="p-4 border-b">
          <h3 className="font-semibold">Messages</h3>
        </div>
        <div className="divide-y">
          {mockMessages.map((message) => (
            <div key={message.id} className="p-4 hover:bg-gray-50 cursor-pointer">
              <div className="flex items-center justify-between mb-1">
                <p className="font-medium text-sm">{message.from}</p>
                {message.unread && <div className="w-2 h-2 bg-blue-600 rounded-full"></div>}
              </div>
              <p className="text-sm text-gray-600 truncate">{message.message}</p>
              <p className="text-xs text-gray-400 mt-1">{message.timestamp}</p>
            </div>
          ))}
        </div>
      </div>
      <div className="flex-1 flex flex-col">
        <div className="p-4 border-b">
          <p className="font-medium">Mike Wilson</p>
        </div>
        <div className="flex-1 p-4 overflow-y-auto">
          <div className="space-y-4">
            <div className="flex">
              <div className="bg-gray-100 rounded-lg p-3 max-w-xs">
                <p className="text-sm">Hi, the rent payment went through successfully.</p>
                <p className="text-xs text-gray-500 mt-1">10:30 AM</p>
              </div>
            </div>
            <div className="flex justify-end">
              <div className="bg-blue-600 text-white rounded-lg p-3 max-w-xs">
                <p className="text-sm">Great! Thank you for the confirmation.</p>
                <p className="text-xs text-blue-100 mt-1">10:32 AM</p>
              </div>
            </div>
          </div>
        </div>
        <div className="p-4 border-t">
          <div className="flex space-x-2">
            <input
              type="text"
              placeholder="Type a message..."
              className="flex-1 px-3 py-2 border border-gray-300 rounded-lg"
            />
            <button className="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700">
              <Send className="w-4 h-4" />
            </button>
          </div>
        </div>
      </div>
    </div>
  );

  // Main content renderer
  const renderContent = () => {
    switch (currentView) {
      case 'dashboard':
        if (userType === 'landlord') return <LandlordDashboard />;
        if (userType === 'tenant') return <TenantDashboard />;
        return <AdminDashboard />;
      case 'properties':
        return <PropertiesView />;
      case 'payments':
      case 'rent':
        return <PaymentsView />;
      case 'messages':
        return <MessagesView />;
      case 'maintenance':
        return (
          <div className="space-y-6">
            <div className="flex justify-between items-center">
              <h2 className="text-xl font-semibold">Maintenance Requests</h2>
              {userType === 'tenant' && (
                <button
                  onClick={() => setShowTicketModal(true)}
                  className="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700"
                >
                  <Plus className="w-4 h-4 inline mr-2" />
                  New Request
                </button>
              )}
            </div>
            <div className="bg-white rounded-lg shadow">
              <div className="divide-y">
                {mockTickets.map((ticket) => (
                  <div key={ticket.id} className="p-6">
                    <div className="flex items-center justify-between mb-2">
                      <h3 className="font-semibold">{ticket.title}</h3>
                      <span className={`px-3 py-1 text-sm rounded-full ${
                        ticket.status === 'open' ? 'bg-red-100 text-red-800' :
                        ticket.status === 'in-progress' ? 'bg-yellow-100 text-yellow-800' :
                        'bg-green-100 text-green-800'
                      }`}>
                        {ticket.status}
                      </span>
                    </div>
                    <p className="text-gray-600 mb-2">{ticket.property}</p>
                    <p className="text-sm text-gray-500">Submitted by {ticket.tenant} on {ticket.date}</p>
                  </div>
                ))}
              </div>
            </div>
          </div>
        );
      default:
        return (
          <div className="bg-white rounded-lg shadow p-8 text-center">
            <h3 className="text-lg font-semibold mb-2">Coming Soon</h3>
            <p className="text-gray-600">This feature is under development.</p>
          </div>
        );
    }
  };

  // Main app render
  if (!currentUser) {
    return <LoginScreen />;
  }

  return (
    <div className="min-h-screen bg-gray-100">
      <Sidebar />
      
      <div className="lg:pl-64">
        <Header />
        
        <main className="p-6 lg:p-8">
          {renderContent()}
        </main>
      </div>

      {/* Modals */}
      {showPaymentModal && <PaymentModal />}
      {showTicketModal && <TicketModal />}

      {/* Mobile sidebar overlay */}
      {sidebarOpen && (
        <div className="fixed inset-0 bg-black bg-opacity-50 z-40 lg:hidden" onClick={() => setSidebarOpen(false)} />
      )}
    </div>
  );
};

export default PropertyTenantSaaS;
