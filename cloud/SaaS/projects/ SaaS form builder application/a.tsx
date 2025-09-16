import React, { useState, useRef, useCallback } from 'react';
import { 
  Plus, Type, Mail, Phone, Calendar, FileUp, List, 
  Users, Settings, BarChart3, Webhook, Slack, Bell,
  Move, Eye, Save, Share, Trash2, Edit3,
  CreditCard, Crown, Shield, Smartphone, Monitor,
  CheckCircle, Clock, X, Menu, Home, FileText,
  Zap, Target, ArrowRight, Star, PlayCircle
} from 'lucide-react';

const SaaSFormBuilder = () => {
  const [currentView, setCurrentView] = useState('dashboard');
  const [currentUser, setCurrentUser] = useState({
    name: 'Sarah Chen',
    email: 'sarah@company.com',
    plan: 'Pro',
    team: 'Design Team'
  });
  
  const [forms, setForms] = useState([
    {
      id: 1,
      name: 'Customer Feedback Survey',
      submissions: 234,
      status: 'active',
      lastModified: '2 hours ago',
      conversionRate: '78%'
    },
    {
      id: 2,
      name: 'Job Application Form',
      submissions: 89,
      status: 'active',
      lastModified: '1 day ago',
      conversionRate: '65%'
    },
    {
      id: 3,
      name: 'Event Registration',
      submissions: 156,
      status: 'draft',
      lastModified: '3 days ago',
      conversionRate: '82%'
    }
  ]);

  const [formBuilder, setFormBuilder] = useState({
    elements: [
      {
        id: 1,
        type: 'text',
        label: 'Full Name',
        required: true,
        placeholder: 'Enter your full name'
      },
      {
        id: 2,
        type: 'email',
        label: 'Email Address',
        required: true,
        placeholder: 'your@email.com'
      }
    ],
    settings: {
      title: 'Contact Form',
      description: 'Get in touch with us',
      webhookUrl: '',
      slackChannel: '#general',
      emailNotifications: true,
      approvalFlow: false
    }
  });

  const [draggedElement, setDraggedElement] = useState(null);
  const [selectedElement, setSelectedElement] = useState(null);

  const elementTypes = [
    { type: 'text', label: 'Text Input', icon: Type },
    { type: 'email', label: 'Email', icon: Mail },
    { type: 'phone', label: 'Phone', icon: Phone },
    { type: 'date', label: 'Date', icon: Calendar },
    { type: 'file', label: 'File Upload', icon: FileUp },
    { type: 'select', label: 'Dropdown', icon: List }
  ];

  const handleDragStart = (elementType) => {
    setDraggedElement(elementType);
  };

  const handleDrop = useCallback((e) => {
    e.preventDefault();
    if (draggedElement) {
      const newElement = {
        id: Date.now(),
        type: draggedElement.type,
        label: draggedElement.label,
        required: false,
        placeholder: `Enter ${draggedElement.label.toLowerCase()}`
      };
      setFormBuilder(prev => ({
        ...prev,
        elements: [...prev.elements, newElement]
      }));
      setDraggedElement(null);
    }
  }, [draggedElement]);

  const handleDragOver = (e) => {
    e.preventDefault();
  };

  const removeElement = (id) => {
    setFormBuilder(prev => ({
      ...prev,
      elements: prev.elements.filter(el => el.id !== id)
    }));
    setSelectedElement(null);
  };

  const updateElement = (id, updates) => {
    setFormBuilder(prev => ({
      ...prev,
      elements: prev.elements.map(el => 
        el.id === id ? { ...el, ...updates } : el
      )
    }));
  };

  const submissions = [
    {
      id: 1,
      formName: 'Customer Feedback',
      submittedBy: 'john.doe@email.com',
      submittedAt: '2024-01-15 10:30 AM',
      status: 'pending_approval',
      data: { name: 'John Doe', feedback: 'Great service!' }
    },
    {
      id: 2,
      formName: 'Job Application',
      submittedBy: 'jane.smith@email.com',
      submittedAt: '2024-01-15 09:15 AM',
      status: 'approved',
      data: { name: 'Jane Smith', position: 'Frontend Developer' }
    },
    {
      id: 3,
      formName: 'Event Registration',
      submittedBy: 'mike.johnson@email.com',
      submittedAt: '2024-01-15 08:45 AM',
      status: 'rejected',
      data: { name: 'Mike Johnson', event: 'Tech Conference 2024' }
    }
  ];

  const renderFormElement = (element) => {
    const Icon = elementTypes.find(t => t.type === element.type)?.icon || Type;
    
    return (
      <div 
        key={element.id}
        className={`p-4 border-2 border-dashed rounded-lg transition-all cursor-pointer ${
          selectedElement?.id === element.id 
            ? 'border-blue-500 bg-blue-50' 
            : 'border-gray-300 hover:border-gray-400'
        }`}
        onClick={() => setSelectedElement(element)}
      >
        <div className="flex items-center justify-between mb-2">
          <div className="flex items-center gap-2">
            <Icon className="w-4 h-4 text-gray-600" />
            <span className="text-sm font-medium text-gray-700">{element.label}</span>
            {element.required && <span className="text-red-500 text-xs">*</span>}
          </div>
          <button
            onClick={(e) => {
              e.stopPropagation();
              removeElement(element.id);
            }}
            className="text-gray-400 hover:text-red-500 transition-colors"
          >
            <Trash2 className="w-4 h-4" />
          </button>
        </div>
        
        {element.type === 'text' && (
          <input
            type="text"
            placeholder={element.placeholder}
            className="w-full p-2 border border-gray-300 rounded-md text-sm"
            disabled
          />
        )}
        {element.type === 'email' && (
          <input
            type="email"
            placeholder={element.placeholder}
            className="w-full p-2 border border-gray-300 rounded-md text-sm"
            disabled
          />
        )}
        {element.type === 'file' && (
          <div className="border-2 border-dashed border-gray-300 rounded-md p-4 text-center">
            <FileUp className="w-6 h-6 text-gray-400 mx-auto mb-2" />
            <span className="text-sm text-gray-500">Click to upload or drag files here</span>
          </div>
        )}
        {element.type === 'select' && (
          <select className="w-full p-2 border border-gray-300 rounded-md text-sm" disabled>
            <option>Select an option</option>
          </select>
        )}
      </div>
    );
  };

  const DashboardView = () => (
    <div className="space-y-6">
      {/* Stats Cards */}
      <div className="grid grid-cols-1 md:grid-cols-4 gap-6">
        <div className="bg-gradient-to-r from-blue-500 to-blue-600 p-6 rounded-xl text-white">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-blue-100 text-sm">Total Forms</p>
              <p className="text-2xl font-bold">12</p>
            </div>
            <FileText className="w-8 h-8 text-blue-200" />
          </div>
        </div>
        <div className="bg-gradient-to-r from-green-500 to-green-600 p-6 rounded-xl text-white">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-green-100 text-sm">Submissions</p>
              <p className="text-2xl font-bold">1,247</p>
            </div>
            <BarChart3 className="w-8 h-8 text-green-200" />
          </div>
        </div>
        <div className="bg-gradient-to-r from-purple-500 to-purple-600 p-6 rounded-xl text-white">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-purple-100 text-sm">Conversion Rate</p>
              <p className="text-2xl font-bold">73.5%</p>
            </div>
            <Target className="w-8 h-8 text-purple-200" />
          </div>
        </div>
        <div className="bg-gradient-to-r from-orange-500 to-orange-600 p-6 rounded-xl text-white">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-orange-100 text-sm">Team Members</p>
              <p className="text-2xl font-bold">8</p>
            </div>
            <Users className="w-8 h-8 text-orange-200" />
          </div>
        </div>
      </div>

      {/* Quick Actions */}
      <div className="bg-white rounded-xl shadow-sm border border-gray-200 p-6">
        <h3 className="text-lg font-semibold text-gray-900 mb-4">Quick Actions</h3>
        <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
          <button 
            onClick={() => setCurrentView('builder')}
            className="flex items-center gap-3 p-4 border border-gray-200 rounded-lg hover:border-blue-300 hover:bg-blue-50 transition-colors"
          >
            <Plus className="w-5 h-5 text-blue-600" />
            <span className="font-medium text-gray-900">Create New Form</span>
          </button>
          <button className="flex items-center gap-3 p-4 border border-gray-200 rounded-lg hover:border-green-300 hover:bg-green-50 transition-colors">
            <Eye className="w-5 h-5 text-green-600" />
            <span className="font-medium text-gray-900">View Analytics</span>
          </button>
          <button className="flex items-center gap-3 p-4 border border-gray-200 rounded-lg hover:border-purple-300 hover:bg-purple-50 transition-colors">
            <Settings className="w-5 h-5 text-purple-600" />
            <span className="font-medium text-gray-900">Team Settings</span>
          </button>
        </div>
      </div>

      {/* Recent Forms */}
      <div className="bg-white rounded-xl shadow-sm border border-gray-200">
        <div className="p-6 border-b border-gray-200">
          <div className="flex items-center justify-between">
            <h3 className="text-lg font-semibold text-gray-900">Recent Forms</h3>
            <button className="text-blue-600 hover:text-blue-700 font-medium text-sm">
              View All
            </button>
          </div>
        </div>
        <div className="divide-y divide-gray-200">
          {forms.map(form => (
            <div key={form.id} className="p-6 hover:bg-gray-50 transition-colors">
              <div className="flex items-center justify-between">
                <div className="flex-1">
                  <h4 className="font-medium text-gray-900">{form.name}</h4>
                  <div className="flex items-center gap-4 mt-1 text-sm text-gray-500">
                    <span>{form.submissions} submissions</span>
                    <span>•</span>
                    <span>Updated {form.lastModified}</span>
                    <span>•</span>
                    <span className="text-green-600 font-medium">{form.conversionRate} conversion</span>
                  </div>
                </div>
                <div className="flex items-center gap-2">
                  <span className={`px-2 py-1 text-xs rounded-full ${
                    form.status === 'active' 
                      ? 'bg-green-100 text-green-800' 
                      : 'bg-yellow-100 text-yellow-800'
                  }`}>
                    {form.status}
                  </span>
                  <button className="p-2 text-gray-400 hover:text-gray-600">
                    <Edit3 className="w-4 h-4" />
                  </button>
                </div>
              </div>
            </div>
          ))}
        </div>
      </div>
    </div>
  );

  const FormBuilderView = () => (
    <div className="grid grid-cols-1 lg:grid-cols-4 gap-6 h-full">
      {/* Elements Panel */}
      <div className="lg:col-span-1 bg-white rounded-xl shadow-sm border border-gray-200 p-6">
        <h3 className="text-lg font-semibold text-gray-900 mb-4">Form Elements</h3>
        <div className="space-y-2">
          {elementTypes.map(element => (
            <div
              key={element.type}
              draggable
              onDragStart={() => handleDragStart(element)}
              className="flex items-center gap-3 p-3 border border-gray-200 rounded-lg cursor-grab hover:border-blue-300 hover:bg-blue-50 transition-colors"
            >
              <element.icon className="w-4 h-4 text-gray-600" />
              <span className="text-sm font-medium text-gray-700">{element.label}</span>
            </div>
          ))}
        </div>
        
        <div className="mt-6 pt-6 border-t border-gray-200">
          <h4 className="text-sm font-semibold text-gray-900 mb-3">Form Settings</h4>
          <div className="space-y-3">
            <div>
              <label className="block text-xs font-medium text-gray-700 mb-1">Form Title</label>
              <input
                type="text"
                value={formBuilder.settings.title}
                onChange={(e) => setFormBuilder(prev => ({
                  ...prev,
                  settings: { ...prev.settings, title: e.target.value }
                }))}
                className="w-full p-2 text-sm border border-gray-300 rounded-md"
              />
            </div>
            <div>
              <label className="block text-xs font-medium text-gray-700 mb-1">Description</label>
              <textarea
                value={formBuilder.settings.description}
                onChange={(e) => setFormBuilder(prev => ({
                  ...prev,
                  settings: { ...prev.settings, description: e.target.value }
                }))}
                className="w-full p-2 text-sm border border-gray-300 rounded-md"
                rows="2"
              />
            </div>
          </div>
        </div>
      </div>

      {/* Form Builder Canvas */}
      <div className="lg:col-span-2 bg-white rounded-xl shadow-sm border border-gray-200 p-6">
        <div className="flex items-center justify-between mb-6">
          <h3 className="text-lg font-semibold text-gray-900">Form Builder</h3>
          <div className="flex items-center gap-2">
            <button className="flex items-center gap-2 px-3 py-2 text-sm bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors">
              <Eye className="w-4 h-4" />
              Preview
            </button>
            <button className="flex items-center gap-2 px-3 py-2 text-sm border border-gray-300 rounded-lg hover:bg-gray-50 transition-colors">
              <Save className="w-4 h-4" />
              Save
            </button>
          </div>
        </div>
        
        <div
          onDrop={handleDrop}
          onDragOver={handleDragOver}
          className="min-h-96 border-2 border-dashed border-gray-300 rounded-lg p-6 space-y-4"
        >
          <div className="text-center mb-6">
            <h2 className="text-xl font-semibold text-gray-900">{formBuilder.settings.title}</h2>
            <p className="text-gray-600 mt-1">{formBuilder.settings.description}</p>
          </div>
          
          {formBuilder.elements.length === 0 ? (
            <div className="text-center py-12">
              <Move className="w-12 h-12 text-gray-400 mx-auto mb-4" />
              <p className="text-gray-500">Drag and drop elements here to build your form</p>
            </div>
          ) : (
            formBuilder.elements.map(renderFormElement)
          )}
        </div>
      </div>

      {/* Properties Panel */}
      <div className="lg:col-span-1 bg-white rounded-xl shadow-sm border border-gray-200 p-6">
        <h3 className="text-lg font-semibold text-gray-900 mb-4">
          {selectedElement ? 'Element Properties' : 'Automations'}
        </h3>
        
        {selectedElement ? (
          <div className="space-y-4">
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Label</label>
              <input
                type="text"
                value={selectedElement.label}
                onChange={(e) => updateElement(selectedElement.id, { label: e.target.value })}
                className="w-full p-2 border border-gray-300 rounded-md text-sm"
              />
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Placeholder</label>
              <input
                type="text"
                value={selectedElement.placeholder}
                onChange={(e) => updateElement(selectedElement.id, { placeholder: e.target.value })}
                className="w-full p-2 border border-gray-300 rounded-md text-sm"
              />
            </div>
            <div className="flex items-center">
              <input
                type="checkbox"
                id="required"
                checked={selectedElement.required}
                onChange={(e) => updateElement(selectedElement.id, { required: e.target.checked })}
                className="mr-2"
              />
              <label htmlFor="required" className="text-sm text-gray-700">Required field</label>
            </div>
          </div>
        ) : (
          <div className="space-y-4">
            <div className="flex items-center gap-3 p-3 border border-gray-200 rounded-lg">
              <Webhook className="w-5 h-5 text-blue-600" />
              <div>
                <p className="text-sm font-medium text-gray-900">Webhooks</p>
                <p className="text-xs text-gray-500">Send data to external services</p>
              </div>
            </div>
            <div className="flex items-center gap-3 p-3 border border-gray-200 rounded-lg">
              <Slack className="w-5 h-5 text-green-600" />
              <div>
                <p className="text-sm font-medium text-gray-900">Slack Notifications</p>
                <p className="text-xs text-gray-500">Get notified in Slack</p>
              </div>
            </div>
            <div className="flex items-center gap-3 p-3 border border-gray-200 rounded-lg">
              <Bell className="w-5 h-5 text-orange-600" />
              <div>
                <p className="text-sm font-medium text-gray-900">Email Alerts</p>
                <p className="text-xs text-gray-500">Email notifications for submissions</p>
              </div>
            </div>
            <div className="flex items-center gap-3 p-3 border border-gray-200 rounded-lg">
              <CheckCircle className="w-5 h-5 text-purple-600" />
              <div>
                <p className="text-sm font-medium text-gray-900">Approval Workflow</p>
                <p className="text-xs text-gray-500">Require approval for submissions</p>
              </div>
            </div>
          </div>
        )}
      </div>
    </div>
  );

  const SubmissionsView = () => (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h2 className="text-2xl font-bold text-gray-900">Form Submissions</h2>
        <div className="flex items-center gap-3">
          <select className="border border-gray-300 rounded-lg px-3 py-2 text-sm">
            <option>All Forms</option>
            <option>Customer Feedback</option>
            <option>Job Applications</option>
            <option>Event Registration</option>
          </select>
          <select className="border border-gray-300 rounded-lg px-3 py-2 text-sm">
            <option>All Status</option>
            <option>Pending</option>
            <option>Approved</option>
            <option>Rejected</option>
          </select>
        </div>
      </div>

      <div className="bg-white rounded-xl shadow-sm border border-gray-200 overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full">
            <thead className="bg-gray-50 border-b border-gray-200">
              <tr>
                <th className="text-left py-3 px-6 text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Form / Submitter
                </th>
                <th className="text-left py-3 px-6 text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Submitted
                </th>
                <th className="text-left py-3 px-6 text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Status
                </th>
                <th className="text-right py-3 px-6 text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Actions
                </th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-200">
              {submissions.map(submission => (
                <tr key={submission.id} className="hover:bg-gray-50">
                  <td className="py-4 px-6">
                    <div>
                      <p className="font-medium text-gray-900">{submission.formName}</p>
                      <p className="text-sm text-gray-500">{submission.submittedBy}</p>
                    </div>
                  </td>
                  <td className="py-4 px-6 text-sm text-gray-600">
                    {submission.submittedAt}
                  </td>
                  <td className="py-4 px-6">
                    <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${
                      submission.status === 'approved' 
                        ? 'bg-green-100 text-green-800'
                        : submission.status === 'rejected'
                        ? 'bg-red-100 text-red-800'
                        : 'bg-yellow-100 text-yellow-800'
                    }`}>
                      {submission.status.replace('_', ' ')}
                    </span>
                  </td>
                  <td className="py-4 px-6 text-right">
                    <div className="flex items-center justify-end gap-2">
                      <button className="text-blue-600 hover:text-blue-700 text-sm font-medium">
                        View
                      </button>
                      {submission.status === 'pending_approval' && (
                        <>
                          <button className="text-green-600 hover:text-green-700 text-sm font-medium">
                            Approve
                          </button>
                          <button className="text-red-600 hover:text-red-700 text-sm font-medium">
                            Reject
                          </button>
                        </>
                      )}
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );

  const BillingView = () => (
    <div className="space-y-6">
      <h2 className="text-2xl font-bold text-gray-900">Billing & Subscription</h2>
      
      {/* Current Plan */}
      <div className="bg-gradient-to-r from-blue-500 to-blue-600 rounded-xl p-6 text-white">
        <div className="flex items-center justify-between">
          <div>
            <div className="flex items-center gap-2 mb-2">
              <Crown className="w-5 h-5" />
              <span className="text-sm font-medium text-blue-100">Current Plan</span>
            </div>
            <h3 className="text-2xl font-bold">Pro Plan</h3>
            <p className="text-blue-100">$29/month • Unlimited forms • 10,000 submissions/month</p>
          </div>
          <div className="text-right">
            <p className="text-sm text-blue-100">Next billing date</p>
            <p className="text-lg font-semibold">Feb 15, 2024</p>
          </div>
        </div>
      </div>

      {/* Usage Stats */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
        <div className="bg-white rounded-xl shadow-sm border border-gray-200 p-6">
          <div className="flex items-center justify-between mb-4">
            <h3 className="font-semibold text-gray-900">Forms Created</h3>
            <FileText className="w-5 h-5 text-gray-400" />
          </div>
          <div className="flex items-end gap-2">
            <span className="text-2xl font-bold text-gray-900">12</span>
            <span className="text-sm text-gray-500">/ Unlimited</span>
          </div>
          <div className="w-full bg-gray-200 rounded-full h-2 mt-3">
            <div className="bg-blue-600 h-2 rounded-full" style={{width: '12%'}}></div>
          </div>
        </div>
        
        <div className="bg-white rounded-xl shadow-sm border border-gray-200 p-6">
          <div className="flex items-center justify-between mb-4">
            <h3 className="font-semibold text-gray-900">Submissions</h3>
            <BarChart3 className="w-5 h-5 text-gray-400" />
          </div>
          <div className="flex items-end gap-2">
            <span className="text-2xl font-bold text-gray-900">1,247</span>
            <span className="text-sm text-gray-500">/ 10,000</span>
          </div>
          <div className="w-full bg-gray-200 rounded-full h-2 mt-3">
            <div className="bg-green-600 h-2 rounded-full" style={{width: '12.47%'}}></div>
          </div>
        </div>
        
        <div className="bg-white rounded-xl shadow-sm border border-gray-200 p-6">
          <div className="flex items-center justify-between mb-4">
            <h3 className="font-semibold text-gray-900">Team Members</h3>
            <Users className="w-5 h-5 text-gray-400" />
          </div>
          <div className="flex items-end gap-2">
            <span className="text-2xl font-bold text-gray-900">8</span>
            <span className="text-sm text-gray-500">/ Unlimited</span>
          </div>
          <div className="w-full bg-gray-200 rounded-full h-2 mt-3">
            <div className="bg-purple-600 h-2 rounded-full" style={{width: '8%'}}></div>
          </div>
        </div>
      </div>

      {/* Pricing Plans */}
      <div className="bg-white rounded-xl shadow-sm border border-gray-200 p-6">
        <h3 className="text-lg font-semibold text-gray-900 mb-6">Available Plans</h3>
        <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
          <div className="border border-gray-200 rounded-xl p-6">
            <h4 className="text-lg font-semibold text-gray-900">Starter</h4>
            <p className="text-3xl font-bold text-gray-900 mt-2">$9<span className="text-lg text-gray-500">/month</span></p>
            <ul className="mt-4 space-y-2 text-sm text-gray-600">
              <li className="flex items-center gap-2">
                <CheckCircle className="w-4 h-4 text-green-500" />
                Up to 3 forms
              </li>
              <li className="flex items-center gap-2">
                <CheckCircle className="w-4 h-4 text-green-500" />
                1,000 submissions/month
              </li>
              <li className="flex items-center gap-2">
                <CheckCircle className="w-4 h-4 text-green-500" />
                Basic integrations
              </li>
            </ul>
            <button className="w-full mt-6 py-2 border border-gray-300 rounded-lg text-gray-700 hover:bg-gray-50 transition-colors">
              Current Plan
            </button>
          </div>
          
          <div className="border-2 border-blue-500 rounded-xl p-6 relative">
            <div className="absolute -top-3 left-1/2 transform -translate-x-1/2">
              <span className="bg-blue-500 text-white px-3 py-1 rounded-full text-xs font-medium">
                Current
              </span>
            </div>
            <h4 className="text-lg font-semibold text-gray-900">Pro</h4>
            <p className="text-3xl font-bold text-gray-900 mt-2">$29<span className="text-lg text-gray-500">/month</span></p>
            <ul className="mt-4 space-y-2 text-sm text-gray-600">
              <li className="flex items-center gap-2">
                <CheckCircle className="w-4 h-4 text-green-500" />
                Unlimited forms
              </li>
              <li className="flex items-center gap-2">
                <CheckCircle className="w-4 h-4 text-green-500" />
                10,000 submissions/month
              </li>
              <li className="flex items-center gap-2">
                <CheckCircle className="w-4 h-4 text-green-500" />
                Advanced integrations
              </li>
              <li className="flex items-center gap-2">
                <CheckCircle className="w-4 h-4 text-green-500" />
                Approval workflows
              </li>
            </ul>
            <button className="w-full mt-6 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors">
              Current Plan
            </button>
          </div>
          
          <div className="border border-gray-200 rounded-xl p-6">
            <h4 className="text-lg font-semibold text-gray-900">Enterprise</h4>
            <p className="text-3xl font-bold text-gray-900 mt-2">$99<span className="text-lg text-gray-500">/month</span></p>
            <ul className="mt-4 space-y-2 text-sm text-gray-600">
              <li className="flex items-center gap-2">
                <CheckCircle className="w-4 h-4 text-green-500" />
                Unlimited everything
              </li>
              <li className="flex items-center gap-2">
                <CheckCircle className="w-4 h-4 text-green-500" />
                Custom integrations
              </li>
              <li className="flex items-center gap-2">
                <CheckCircle className="w-4 h-4 text-green-500" />
                Priority support
              </li>
              <li className="flex items-center gap-2">
                <CheckCircle className="w-4 h-4 text-green-500" />
                SSO & SAML
              </li>
            </ul>
            <button className="w-full mt-6 py-2 bg-gray-900 text-white rounded-lg hover:bg-gray-800 transition-colors">
              Upgrade
            </button>
          </div>
        </div>
      </div>
    </div>
  );

  const TeamView = () => (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h2 className="text-2xl font-bold text-gray-900">Team Management</h2>
        <button className="flex items-center gap-2 px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors">
          <Plus className="w-4 h-4" />
          Invite Member
        </button>
      </div>

      {/* Team Stats */}
      <div className="grid grid-cols-1 md:grid-cols-4 gap-6">
        <div className="bg-white rounded-xl shadow-sm border border-gray-200 p-6">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm text-gray-500">Total Members</p>
              <p className="text-2xl font-bold text-gray-900">8</p>
            </div>
            <Users className="w-8 h-8 text-blue-500" />
          </div>
        </div>
        <div className="bg-white rounded-xl shadow-sm border border-gray-200 p-6">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm text-gray-500">Admins</p>
              <p className="text-2xl font-bold text-gray-900">2</p>
            </div>
            <Shield className="w-8 h-8 text-green-500" />
          </div>
        </div>
        <div className="bg-white rounded-xl shadow-sm border border-gray-200 p-6">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm text-gray-500">Editors</p>
              <p className="text-2xl font-bold text-gray-900">4</p>
            </div>
            <Edit3 className="w-8 h-8 text-purple-500" />
          </div>
        </div>
        <div className="bg-white rounded-xl shadow-sm border border-gray-200 p-6">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm text-gray-500">Viewers</p>
              <p className="text-2xl font-bold text-gray-900">2</p>
            </div>
            <Eye className="w-8 h-8 text-orange-500" />
          </div>
        </div>
      </div>

      {/* Team Members */}
      <div className="bg-white rounded-xl shadow-sm border border-gray-200">
        <div className="p-6 border-b border-gray-200">
          <h3 className="text-lg font-semibold text-gray-900">Team Members</h3>
        </div>
        <div className="divide-y divide-gray-200">
          {[
            { name: 'Sarah Chen', email: 'sarah@company.com', role: 'Admin', status: 'Active', avatar: 'SC' },
            { name: 'Mike Johnson', email: 'mike@company.com', role: 'Editor', status: 'Active', avatar: 'MJ' },
            { name: 'Emily Davis', email: 'emily@company.com', role: 'Editor', status: 'Active', avatar: 'ED' },
            { name: 'James Wilson', email: 'james@company.com', role: 'Viewer', status: 'Pending', avatar: 'JW' },
          ].map((member, index) => (
            <div key={index} className="p-6 flex items-center justify-between">
              <div className="flex items-center gap-4">
                <div className="w-10 h-10 bg-blue-100 rounded-full flex items-center justify-center">
                  <span className="text-blue-600 font-medium text-sm">{member.avatar}</span>
                </div>
                <div>
                  <p className="font-medium text-gray-900">{member.name}</p>
                  <p className="text-sm text-gray-500">{member.email}</p>
                </div>
              </div>
              <div className="flex items-center gap-4">
                <span className="text-sm font-medium text-gray-700">{member.role}</span>
                <span className={`px-2 py-1 text-xs rounded-full ${
                  member.status === 'Active' 
                    ? 'bg-green-100 text-green-800' 
                    : 'bg-yellow-100 text-yellow-800'
                }`}>
                  {member.status}
                </span>
                <button className="text-gray-400 hover:text-gray-600">
                  <Settings className="w-4 h-4" />
                </button>
              </div>
            </div>
          ))}
        </div>
      </div>
    </div>
  );

  const renderView = () => {
    switch (currentView) {
      case 'dashboard':
        return <DashboardView />;
      case 'builder':
        return <FormBuilderView />;
      case 'submissions':
        return <SubmissionsView />;
      case 'billing':
        return <BillingView />;
      case 'team':
        return <TeamView />;
      default:
        return <DashboardView />;
    }
  };

  return (
    <div className="min-h-screen bg-gray-50 flex">
      {/* Sidebar */}
      <div className="w-64 bg-white shadow-sm border-r border-gray-200 flex flex-col">
        <div className="p-6 border-b border-gray-200">
          <div className="flex items-center gap-3">
            <div className="w-8 h-8 bg-gradient-to-r from-blue-500 to-blue-600 rounded-lg flex items-center justify-center">
              <Zap className="w-5 h-5 text-white" />
            </div>
            <span className="text-xl font-bold text-gray-900">FormCraft</span>
          </div>
        </div>

        <nav className="flex-1 p-4">
          <div className="space-y-1">
            {[
              { id: 'dashboard', label: 'Dashboard', icon: Home },
              { id: 'builder', label: 'Form Builder', icon: Edit3 },
              { id: 'submissions', label: 'Submissions', icon: FileText },
              { id: 'team', label: 'Team', icon: Users },
              { id: 'billing', label: 'Billing', icon: CreditCard },
            ].map(item => (
              <button
                key={item.id}
                onClick={() => setCurrentView(item.id)}
                className={`w-full flex items-center gap-3 px-3 py-2 rounded-lg text-left transition-colors ${
                  currentView === item.id
                    ? 'bg-blue-50 text-blue-600 border border-blue-200'
                    : 'text-gray-600 hover:bg-gray-50'
                }`}
              >
                <item.icon className="w-5 h-5" />
                {item.label}
              </button>
            ))}
          </div>
        </nav>

        <div className="p-4 border-t border-gray-200">
          <div className="flex items-center gap-3">
            <div className="w-8 h-8 bg-blue-100 rounded-full flex items-center justify-center">
              <span className="text-blue-600 font-medium text-sm">SC</span>
            </div>
            <div className="flex-1 min-w-0">
              <p className="text-sm font-medium text-gray-900 truncate">{currentUser.name}</p>
              <p className="text-xs text-gray-500 truncate">{currentUser.plan} Plan</p>
            </div>
          </div>
        </div>
      </div>

      {/* Main Content */}
      <div className="flex-1 overflow-auto">
        <div className="p-8">
          {renderView()}
        </div>
      </div>
    </div>
  );
};

export default SaaSFormBuilder;
