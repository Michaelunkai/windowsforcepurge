import React, { useState, useEffect } from 'react';
import { 
  CreditCard, 
  FileText, 
  TrendingUp, 
  Users, 
  Settings, 
  Bell, 
  Plus, 
  Search,
  Filter,
  Download,
  Send,
  Eye,
  Edit,
  Trash2,
  Calendar,
  DollarSign,
  PieChart,
  BarChart3,
  Target,
  Zap,
  Shield,
  Globe,
  Star,
  Check,
  X,
  Menu,
  ChevronRight,
  ArrowRight,
  Play,
  Award,
  Briefcase,
  Clock,
  Mail,
  Phone,
  Building,
  Receipt,
  Calculator,
  RefreshCw,
  Sparkles
} from 'lucide-react';

const FinanceMasterPro = () => {
  const [currentView, setCurrentView] = useState('landing');
  const [sidebarOpen, setSidebarOpen] = useState(false);
  const [invoices, setInvoices] = useState([
    { id: 'INV-001', client: 'Acme Corp', amount: 2500, status: 'paid', date: '2024-01-15', dueDate: '2024-02-15' },
    { id: 'INV-002', client: 'Tech Solutions', amount: 1800, status: 'pending', date: '2024-01-20', dueDate: '2024-02-20' },
    { id: 'INV-003', client: 'Design Studio', amount: 3200, status: 'overdue', date: '2024-01-10', dueDate: '2024-02-10' }
  ]);
  
  const [expenses, setExpenses] = useState([
    { id: 1, description: 'Office Supplies', amount: 150, category: 'Office', date: '2024-01-22' },
    { id: 2, description: 'Software License', amount: 99, category: 'Software', date: '2024-01-20' },
    { id: 3, description: 'Client Lunch', amount: 85, category: 'Meals', date: '2024-01-18' }
  ]);

  const [selectedPlan, setSelectedPlan] = useState('pro');
  const [animatedStats, setAnimatedStats] = useState({
    revenue: 0,
    invoices: 0,
    clients: 0,
    savings: 0
  });

  useEffect(() => {
    if (currentView === 'dashboard') {
      const targets = { revenue: 45750, invoices: 127, clients: 23, savings: 8450 };
      const duration = 2000;
      const steps = 60;
      const stepDuration = duration / steps;
      
      let currentStep = 0;
      const timer = setInterval(() => {
        currentStep++;
        const progress = currentStep / steps;
        const easeOut = 1 - Math.pow(1 - progress, 3);
        
        setAnimatedStats({
          revenue: Math.round(targets.revenue * easeOut),
          invoices: Math.round(targets.invoices * easeOut),
          clients: Math.round(targets.clients * easeOut),
          savings: Math.round(targets.savings * easeOut)
        });
        
        if (currentStep >= steps) clearInterval(timer);
      }, stepDuration);
      
      return () => clearInterval(timer);
    }
  }, [currentView]);

  const pricingPlans = [
    {
      name: 'Free',
      price: '$0',
      period: 'forever',
      description: 'Perfect for getting started',
      features: [
        '5 invoices per month',
        'Basic expense tracking',
        'Client management',
        'Payment tracking',
        'Mobile app access',
        'Email support'
      ],
      limitations: ['Limited invoice templates', 'Basic reporting'],
      buttonText: 'Start Free',
      popular: false
    },
    {
      name: 'Pro',
      price: '$15',
      period: 'per month',
      description: 'Everything you need to grow',
      features: [
        'Unlimited invoices',
        'AI-powered invoice generation',
        'Advanced expense tracking',
        'Receipt OCR scanning',
        'Automated payment reminders',
        'Tax calculations',
        'Client portal access',
        'Recurring invoices',
        'Advanced analytics',
        'Priority support'
      ],
      limitations: [],
      buttonText: 'Start Pro Trial',
      popular: true
    },
    {
      name: 'Business',
      price: '$35',
      period: 'per month',
      description: 'For growing teams and agencies',
      features: [
        'Everything in Pro',
        'Team collaboration',
        'White-label branding',
        'Multi-user access',
        'Advanced integrations',
        'Custom invoice templates',
        'API access',
        'Dedicated account manager',
        'Custom reporting',
        'Phone support'
      ],
      limitations: [],
      buttonText: 'Start Business Trial',
      popular: false
    }
  ];

  const testimonials = [
    {
      name: 'Sarah Johnson',
      company: 'Johnson Design Studio',
      avatar: '👩‍💼',
      rating: 5,
      text: 'FinanceMaster transformed how I handle my freelance business. The AI invoice generation saves me hours every week!'
    },
    {
      name: 'Mike Chen',
      company: 'Chen Consulting',
      avatar: '👨‍💻',
      rating: 5,
      text: 'The payment tracking and automated reminders have improved my cash flow by 40%. Couldn\'t run my business without it.'
    },
    {
      name: 'Lisa Rodriguez',
      company: 'Rodriguez Marketing',
      avatar: '👩‍🚀',
      rating: 5,
      text: 'The analytics dashboard gives me insights I never had before. I can make better business decisions with real data.'
    }
  ];

  const NavigationSidebar = () => (
    <div className={`fixed inset-y-0 left-0 z-50 w-64 bg-white/80 backdrop-blur-lg border-r border-gray-200 transform transition-transform duration-300 ${sidebarOpen ? 'translate-x-0' : '-translate-x-full'} lg:translate-x-0`}>
      <div className="p-6">
        <div className="flex items-center space-x-2 mb-8">
          <div className="w-8 h-8 bg-gradient-to-r from-blue-600 to-purple-600 rounded-lg flex items-center justify-center">
            <TrendingUp className="w-5 h-5 text-white" />
          </div>
          <span className="text-xl font-bold bg-gradient-to-r from-blue-600 to-purple-600 bg-clip-text text-transparent">
            FinanceMaster
          </span>
        </div>
        
        <nav className="space-y-2">
          {[
            { id: 'dashboard', label: 'Dashboard', icon: BarChart3 },
            { id: 'invoices', label: 'Invoices', icon: FileText },
            { id: 'expenses', label: 'Expenses', icon: Receipt },
            { id: 'clients', label: 'Clients', icon: Users },
            { id: 'analytics', label: 'Analytics', icon: PieChart },
            { id: 'settings', label: 'Settings', icon: Settings }
          ].map(({ id, label, icon: Icon }) => (
            <button
              key={id}
              onClick={() => setCurrentView(id)}
              className={`w-full flex items-center space-x-3 px-4 py-3 rounded-lg transition-all duration-200 ${
                currentView === id 
                  ? 'bg-gradient-to-r from-blue-500 to-purple-500 text-white shadow-lg' 
                  : 'text-gray-600 hover:bg-gray-100'
              }`}
            >
              <Icon className="w-5 h-5" />
              <span className="font-medium">{label}</span>
            </button>
          ))}
        </nav>
      </div>
    </div>
  );

  const LandingPage = () => (
    <div className="min-h-screen bg-gradient-to-br from-slate-50 via-blue-50 to-purple-50">
      {/* Navigation */}
      <nav className="bg-white/80 backdrop-blur-lg border-b border-gray-200 sticky top-0 z-40">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex justify-between items-center h-16">
            <div className="flex items-center space-x-2">
              <div className="w-8 h-8 bg-gradient-to-r from-blue-600 to-purple-600 rounded-lg flex items-center justify-center">
                <TrendingUp className="w-5 h-5 text-white" />
              </div>
              <span className="text-xl font-bold bg-gradient-to-r from-blue-600 to-purple-600 bg-clip-text text-transparent">
                FinanceMaster Pro
              </span>
            </div>
            
            <div className="hidden md:flex items-center space-x-8">
              <a href="#features" className="text-gray-600 hover:text-blue-600 transition-colors">Features</a>
              <a href="#pricing" className="text-gray-600 hover:text-blue-600 transition-colors">Pricing</a>
              <a href="#testimonials" className="text-gray-600 hover:text-blue-600 transition-colors">Testimonials</a>
              <button 
                onClick={() => setCurrentView('dashboard')}
                className="bg-gradient-to-r from-blue-600 to-purple-600 text-white px-6 py-2 rounded-lg font-medium hover:shadow-lg transition-all duration-200"
              >
                Try Free
              </button>
            </div>
            
            <button className="md:hidden">
              <Menu className="w-6 h-6" />
            </button>
          </div>
        </div>
      </nav>

      {/* Hero Section */}
      <section className="pt-20 pb-32">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 text-center">
          <div className="max-w-4xl mx-auto">
            <div className="mb-8">
              <span className="inline-flex items-center px-4 py-2 rounded-full bg-blue-100 text-blue-800 text-sm font-medium mb-6">
                <Sparkles className="w-4 h-4 mr-2" />
                AI-Powered Finance Management
              </span>
            </div>
            
            <h1 className="text-5xl md:text-7xl font-bold text-gray-900 mb-8 leading-tight">
              Transform Your
              <span className="bg-gradient-to-r from-blue-600 to-purple-600 bg-clip-text text-transparent"> Business </span>
              Finances
            </h1>
            
            <p className="text-xl text-gray-600 mb-12 max-w-3xl mx-auto leading-relaxed">
              The most intelligent invoicing and finance management platform for freelancers and small businesses. 
              Generate professional invoices with AI, track payments automatically, and grow your business with powerful analytics.
            </p>
            
            <div className="flex flex-col sm:flex-row gap-4 justify-center mb-16">
              <button 
                onClick={() => setCurrentView('dashboard')}
                className="bg-gradient-to-r from-blue-600 to-purple-600 text-white px-8 py-4 rounded-lg font-semibold text-lg hover:shadow-xl transition-all duration-300 transform hover:-translate-y-1"
              >
                Start Free Trial
                <ArrowRight className="w-5 h-5 ml-2 inline" />
              </button>
              <button className="border-2 border-gray-300 text-gray-700 px-8 py-4 rounded-lg font-semibold text-lg hover:border-blue-500 hover:text-blue-600 transition-all duration-200">
                <Play className="w-5 h-5 mr-2 inline" />
                Watch Demo
              </button>
            </div>
            
            {/* Stats */}
            <div className="grid grid-cols-2 md:grid-cols-4 gap-8 mb-20">
              {[
                { label: 'Active Users', value: '50,000+', icon: Users },
                { label: 'Invoices Generated', value: '2M+', icon: FileText },
                { label: 'Revenue Processed', value: '$500M+', icon: DollarSign },
                { label: 'Time Saved', value: '100,000h', icon: Clock }
              ].map(({ label, value, icon: Icon }) => (
                <div key={label} className="text-center">
                  <div className="bg-white/60 backdrop-blur-sm rounded-xl p-6 border border-gray-200 hover:shadow-lg transition-all duration-300">
                    <Icon className="w-8 h-8 text-blue-600 mx-auto mb-3" />
                    <div className="text-2xl font-bold text-gray-900 mb-1">{value}</div>
                    <div className="text-gray-600 text-sm">{label}</div>
                  </div>
                </div>
              ))}
            </div>
          </div>
        </div>
      </section>

      {/* Features Section */}
      <section id="features" className="py-20 bg-white">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="text-center mb-16">
            <h2 className="text-4xl font-bold text-gray-900 mb-4">
              Everything You Need to Manage Your Business
            </h2>
            <p className="text-xl text-gray-600 max-w-3xl mx-auto">
              From AI-powered invoicing to advanced analytics, we've built the most comprehensive finance platform for modern businesses.
            </p>
          </div>
          
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-8">
            {[
              {
                icon: Sparkles,
                title: 'AI-Powered Invoicing',
                description: 'Generate professional invoices instantly with smart client data auto-fill and intelligent template suggestions.',
                color: 'from-blue-500 to-cyan-500'
              },
              {
                icon: RefreshCw,
                title: 'Automated Reminders',
                description: 'Never chase payments again. Customizable follow-up sequences keep your cash flow healthy.',
                color: 'from-purple-500 to-pink-500'
              },
              {
                icon: Receipt,
                title: 'Smart Expense Tracking',
                description: 'OCR receipt scanning with automatic categorization and tax calculation for effortless bookkeeping.',
                color: 'from-green-500 to-emerald-500'
              },
              {
                icon: Calculator,
                title: 'Tax Management',
                description: 'Automated tax calculations and reporting with seamless integration to popular accounting software.',
                color: 'from-orange-500 to-red-500'
              },
              {
                icon: Globe,
                title: 'Client Portal',
                description: 'Professional client portal for payments, project updates, and seamless communication.',
                color: 'from-indigo-500 to-purple-500'
              },
              {
                icon: BarChart3,
                title: 'Business Analytics',
                description: 'Comprehensive dashboards with profit/loss visualization and actionable business insights.',
                color: 'from-teal-500 to-blue-500'
              }
            ].map(({ icon: Icon, title, description, color }) => (
              <div key={title} className="group">
                <div className="bg-white rounded-2xl p-8 border border-gray-200 hover:shadow-xl transition-all duration-300 transform hover:-translate-y-2">
                  <div className={`w-12 h-12 bg-gradient-to-r ${color} rounded-lg flex items-center justify-center mb-6 group-hover:scale-110 transition-transform duration-200`}>
                    <Icon className="w-6 h-6 text-white" />
                  </div>
                  <h3 className="text-xl font-semibold text-gray-900 mb-3">{title}</h3>
                  <p className="text-gray-600 leading-relaxed">{description}</p>
                </div>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* Pricing Section */}
      <section id="pricing" className="py-20 bg-gradient-to-br from-slate-50 to-blue-50">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="text-center mb-16">
            <h2 className="text-4xl font-bold text-gray-900 mb-4">
              Choose Your Plan
            </h2>
            <p className="text-xl text-gray-600 max-w-2xl mx-auto">
              Start free and scale as you grow. All plans include our core features with no setup fees.
            </p>
          </div>
          
          <div className="grid grid-cols-1 md:grid-cols-3 gap-8 max-w-6xl mx-auto">
            {pricingPlans.map((plan) => (
              <div 
                key={plan.name}
                className={`relative bg-white/80 backdrop-blur-sm rounded-2xl p-8 border-2 transition-all duration-300 hover:shadow-xl transform hover:-translate-y-2 ${
                  plan.popular ? 'border-blue-500 scale-105' : 'border-gray-200'
                }`}
              >
                {plan.popular && (
                  <div className="absolute -top-4 left-1/2 transform -translate-x-1/2">
                    <span className="bg-gradient-to-r from-blue-600 to-purple-600 text-white px-6 py-2 rounded-full text-sm font-semibold">
                      Most Popular
                    </span>
                  </div>
                )}
                
                <div className="text-center mb-8">
                  <h3 className="text-2xl font-bold text-gray-900 mb-2">{plan.name}</h3>
                  <div className="mb-2">
                    <span className="text-4xl font-bold text-gray-900">{plan.price}</span>
                    <span className="text-gray-600 ml-2">{plan.period}</span>
                  </div>
                  <p className="text-gray-600">{plan.description}</p>
                </div>
                
                <ul className="space-y-4 mb-8">
                  {plan.features.map((feature) => (
                    <li key={feature} className="flex items-center">
                      <Check className="w-5 h-5 text-green-500 mr-3 flex-shrink-0" />
                      <span className="text-gray-700">{feature}</span>
                    </li>
                  ))}
                  {plan.limitations.map((limitation) => (
                    <li key={limitation} className="flex items-center text-gray-400">
                      <X className="w-5 h-5 mr-3 flex-shrink-0" />
                      <span>{limitation}</span>
                    </li>
                  ))}
                </ul>
                
                <button 
                  onClick={() => setCurrentView('dashboard')}
                  className={`w-full py-3 px-6 rounded-lg font-semibold transition-all duration-200 ${
                    plan.popular
                      ? 'bg-gradient-to-r from-blue-600 to-purple-600 text-white hover:shadow-lg'
                      : 'border-2 border-gray-300 text-gray-700 hover:border-blue-500 hover:text-blue-600'
                  }`}
                >
                  {plan.buttonText}
                </button>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* Testimonials */}
      <section id="testimonials" className="py-20 bg-white">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="text-center mb-16">
            <h2 className="text-4xl font-bold text-gray-900 mb-4">
              Loved by Thousands of Businesses
            </h2>
            <div className="flex items-center justify-center mb-4">
              {[...Array(5)].map((_, i) => (
                <Star key={i} className="w-6 h-6 text-yellow-400 fill-current" />
              ))}
              <span className="ml-2 text-lg text-gray-600">4.9/5 from 2,500+ reviews</span>
            </div>
          </div>
          
          <div className="grid grid-cols-1 md:grid-cols-3 gap-8">
            {testimonials.map((testimonial) => (
              <div key={testimonial.name} className="bg-gradient-to-br from-white to-gray-50 rounded-2xl p-8 border border-gray-200 hover:shadow-lg transition-all duration-300">
                <div className="flex items-center mb-4">
                  <div className="text-3xl mr-4">{testimonial.avatar}</div>
                  <div>
                    <div className="font-semibold text-gray-900">{testimonial.name}</div>
                    <div className="text-gray-600 text-sm">{testimonial.company}</div>
                  </div>
                </div>
                <div className="flex mb-4">
                  {[...Array(testimonial.rating)].map((_, i) => (
                    <Star key={i} className="w-4 h-4 text-yellow-400 fill-current" />
                  ))}
                </div>
                <p className="text-gray-700 leading-relaxed">"{testimonial.text}"</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* CTA Section */}
      <section className="py-20 bg-gradient-to-r from-blue-600 to-purple-600">
        <div className="max-w-4xl mx-auto text-center px-4 sm:px-6 lg:px-8">
          <h2 className="text-4xl font-bold text-white mb-6">
            Ready to Transform Your Business?
          </h2>
          <p className="text-xl text-blue-100 mb-8">
            Join thousands of successful businesses already using FinanceMaster Pro.
            Start your free trial today – no credit card required.
          </p>
          <button 
            onClick={() => setCurrentView('dashboard')}
            className="bg-white text-blue-600 px-8 py-4 rounded-lg font-semibold text-lg hover:shadow-2xl transition-all duration-300 transform hover:-translate-y-1"
          >
            Start Your Free Trial
            <ArrowRight className="w-5 h-5 ml-2 inline" />
          </button>
        </div>
      </section>
    </div>
  );

  const Dashboard = () => (
    <div className="p-6 lg:p-8">
      {/* Header */}
      <div className="mb-8">
        <div className="flex items-center justify-between mb-6">
          <div>
            <h1 className="text-3xl font-bold text-gray-900">Welcome back, Alex!</h1>
            <p className="text-gray-600 mt-1">Here's what's happening with your business today.</p>
          </div>
          <div className="flex items-center space-x-4">
            <button className="bg-gradient-to-r from-blue-600 to-purple-600 text-white px-6 py-3 rounded-lg font-medium hover:shadow-lg transition-all duration-200">
              <Plus className="w-5 h-5 mr-2 inline" />
              New Invoice
            </button>
          </div>
        </div>
      </div>

      {/* Stats Cards */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-8">
        {[
          { label: 'Total Revenue', value: `$${animatedStats.revenue.toLocaleString()}`, icon: DollarSign, color: 'from-green-500 to-emerald-500', change: '+12.5%' },
          { label: 'Invoices Sent', value: animatedStats.invoices, icon: FileText, color: 'from-blue-500 to-cyan-500', change: '+8.2%' },
          { label: 'Active Clients', value: animatedStats.clients, icon: Users, color: 'from-purple-500 to-pink-500', change: '+15.3%' },
          { label: 'Tax Savings', value: `$${animatedStats.savings.toLocaleString()}`, icon: Calculator, color: 'from-orange-500 to-red-500', change: '+22.1%' }
        ].map(({ label, value, icon: Icon, color, change }) => (
          <div key={label} className="bg-white/80 backdrop-blur-lg rounded-2xl p-6 border border-gray-200 hover:shadow-lg transition-all duration-300">
            <div className="flex items-center justify-between mb-4">
              <div className={`w-12 h-12 bg-gradient-to-r ${color} rounded-xl flex items-center justify-center`}>
                <Icon className="w-6 h-6 text-white" />
              </div>
              <span className="text-green-600 text-sm font-medium">{change}</span>
            </div>
            <div className="text-2xl font-bold text-gray-900 mb-1">{value}</div>
            <div className="text-gray-600 text-sm">{label}</div>
          </div>
        ))}
      </div>

      {/* Charts Section */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-8 mb-8">
        {/* Revenue Chart */}
        <div className="bg-white/80 backdrop-blur-lg rounded-2xl p-6 border border-gray-200">
          <h3 className="text-lg font-semibold text-gray-900 mb-4">Revenue Trend</h3>
          <div className="h-64 flex items-end space-x-2">
            {[65, 45, 75, 55, 85, 70, 90, 80, 95, 85, 100, 90].map((height, i) => (
              <div key={i} className="flex-1 bg-gradient-to-t from-blue-500 to-purple-500 rounded-t opacity-80 hover:opacity-100 transition-opacity cursor-pointer" style={{height: `${height}%`}}></div>
            ))}
          </div>
          <div className="flex justify-between text-sm text-gray-600 mt-2">
            <span>Jan</span>
            <span>Jun</span>
            <span>Dec</span>
          </div>
        </div>

        {/* Recent Activity */}
        <div className="bg-white/80 backdrop-blur-lg rounded-2xl p-6 border border-gray-200">
          <h3 className="text-lg font-semibold text-gray-900 mb-4">Recent Activity</h3>
          <div className="space-y-4">
            {[
              { type: 'payment', message: 'Payment received from Acme Corp', amount: '$2,500', time: '2 hours ago' },
              { type: 'invoice', message: 'Invoice sent to Tech Solutions', amount: '$1,800', time: '4 hours ago' },
              { type: 'expense', message: 'Office supplies expense added', amount: '$150', time: '6 hours ago' },
              { type: 'reminder', message: 'Payment reminder sent to Design Studio', amount: '$3,200', time: '1 day ago' }
            ].map((activity, i) => (
              <div key={i} className="flex items-center space-x-4 p-3 rounded-lg hover:bg-gray-50 transition-colors">
                <div className={`w-10 h-10 rounded-full flex items-center justify-center ${
                  activity.type === 'payment' ? 'bg-green-100 text-green-600' :
                  activity.type === 'invoice' ? 'bg-blue-100 text-blue-600' :
                  activity.type === 'expense' ? 'bg-red-100 text-red-600' :
                  'bg-yellow-100 text-yellow-600'
                }`}>
                  {activity.type === 'payment' ? <DollarSign className="w-5 h-5" /> :
                   activity.type === 'invoice' ? <FileText className="w-5 h-5" /> :
                   activity.type === 'expense' ? <Receipt className="w-5 h-5" /> :
                   <Bell className="w-5 h-5" />}
                </div>
                <div className="flex-1">
                  <p className="text-gray-900 text-sm">{activity.message}</p>
                  <p className="text-gray-500 text-xs">{activity.time}</p>
                </div>
                <div className="text-right">
                  <p className="font-semibold text-gray-900">{activity.amount}</p>
                </div>
              </div>
            ))}
          </div>
        </div>
      </div>

      {/* Quick Actions */}
      <div className="bg-white/80 backdrop-blur-lg rounded-2xl p-6 border border-gray-200">
        <h3 className="text-lg font-semibold text-gray-900 mb-4">Quick Actions</h3>
        <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
          {[
            { label: 'Create Invoice', icon: Plus, color: 'from-blue-500 to-cyan-500' },
            { label: 'Add Expense', icon: Receipt, color: 'from-green-500 to-emerald-500' },
            { label: 'Send Reminder', icon: Send, color: 'from-purple-500 to-pink-500' },
            { label: 'View Reports', icon: BarChart3, color: 'from-orange-500 to-red-500' }
          ].map(({ label, icon: Icon, color }) => (
            <button key={label} className="p-4 rounded-xl border border-gray-200 hover:shadow-lg transition-all duration-200 text-center group">
              <div className={`w-12 h-12 bg-gradient-to-r ${color} rounded-lg flex items-center justify-center mx-auto mb-3 group-hover:scale-110 transition-transform duration-200`}>
                <Icon className="w-6 h-6 text-white" />
              </div>
              <span className="text-sm font-medium text-gray-700">{label}</span>
            </button>
          ))}
        </div>
      </div>
    </div>
  );

  const InvoicesView = () => (
    <div className="p-6 lg:p-8">
      <div className="flex items-center justify-between mb-8">
        <div>
          <h1 className="text-3xl font-bold text-gray-900">Invoices</h1>
          <p className="text-gray-600 mt-1">Manage and track all your invoices</p>
        </div>
        <button className="bg-gradient-to-r from-blue-600 to-purple-600 text-white px-6 py-3 rounded-lg font-medium hover:shadow-lg transition-all duration-200">
          <Plus className="w-5 h-5 mr-2 inline" />
          New Invoice
        </button>
      </div>

      {/* Filter Bar */}
      <div className="bg-white/80 backdrop-blur-lg rounded-2xl p-6 border border-gray-200 mb-8">
        <div className="flex flex-col md:flex-row md:items-center md:justify-between space-y-4 md:space-y-0">
          <div className="flex items-center space-x-4">
            <div className="relative">
              <Search className="w-5 h-5 text-gray-400 absolute left-3 top-1/2 transform -translate-y-1/2" />
              <input 
                type="text" 
                placeholder="Search invoices..." 
                className="pl-10 pr-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
              />
            </div>
            <button className="flex items-center space-x-2 px-4 py-2 border border-gray-300 rounded-lg hover:bg-gray-50">
              <Filter className="w-5 h-5" />
              <span>Filter</span>
            </button>
          </div>
          <button className="flex items-center space-x-2 px-4 py-2 border border-gray-300 rounded-lg hover:bg-gray-50">
            <Download className="w-5 h-5" />
            <span>Export</span>
          </button>
        </div>
      </div>

      {/* Invoices Table */}
      <div className="bg-white/80 backdrop-blur-lg rounded-2xl border border-gray-200 overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full">
            <thead className="bg-gray-50 border-b border-gray-200">
              <tr>
                <th className="text-left p-6 font-semibold text-gray-900">Invoice ID</th>
                <th className="text-left p-6 font-semibold text-gray-900">Client</th>
                <th className="text-left p-6 font-semibold text-gray-900">Amount</th>
                <th className="text-left p-6 font-semibold text-gray-900">Status</th>
                <th className="text-left p-6 font-semibold text-gray-900">Date</th>
                <th className="text-left p-6 font-semibold text-gray-900">Actions</th>
              </tr>
            </thead>
            <tbody>
              {invoices.map((invoice) => (
                <tr key={invoice.id} className="border-b border-gray-100 hover:bg-gray-50 transition-colors">
                  <td className="p-6 font-medium text-gray-900">{invoice.id}</td>
                  <td className="p-6 text-gray-700">{invoice.client}</td>
                  <td className="p-6 font-semibold text-gray-900">${invoice.amount.toLocaleString()}</td>
                  <td className="p-6">
                    <span className={`inline-flex items-center px-3 py-1 rounded-full text-sm font-medium ${
                      invoice.status === 'paid' ? 'bg-green-100 text-green-800' :
                      invoice.status === 'pending' ? 'bg-yellow-100 text-yellow-800' :
                      'bg-red-100 text-red-800'
                    }`}>
                      {invoice.status.charAt(0).toUpperCase() + invoice.status.slice(1)}
                    </span>
                  </td>
                  <td className="p-6 text-gray-600">{invoice.date}</td>
                  <td className="p-6">
                    <div className="flex items-center space-x-2">
                      <button className="p-2 text-gray-600 hover:text-blue-600 hover:bg-blue-50 rounded-lg transition-colors">
                        <Eye className="w-4 h-4" />
                      </button>
                      <button className="p-2 text-gray-600 hover:text-blue-600 hover:bg-blue-50 rounded-lg transition-colors">
                        <Edit className="w-4 h-4" />
                      </button>
                      <button className="p-2 text-gray-600 hover:text-blue-600 hover:bg-blue-50 rounded-lg transition-colors">
                        <Send className="w-4 h-4" />
                      </button>
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

  const ExpensesView = () => (
    <div className="p-6 lg:p-8">
      <div className="flex items-center justify-between mb-8">
        <div>
          <h1 className="text-3xl font-bold text-gray-900">Expenses</h1>
          <p className="text-gray-600 mt-1">Track and categorize your business expenses</p>
        </div>
        <button className="bg-gradient-to-r from-blue-600 to-purple-600 text-white px-6 py-3 rounded-lg font-medium hover:shadow-lg transition-all duration-200">
          <Plus className="w-5 h-5 mr-2 inline" />
          Add Expense
        </button>
      </div>

      {/* Expense Categories */}
      <div className="grid grid-cols-1 md:grid-cols-4 gap-6 mb-8">
        {[
          { label: 'Office Supplies', amount: 1250, color: 'from-blue-500 to-cyan-500' },
          { label: 'Software', amount: 899, color: 'from-purple-500 to-pink-500' },
          { label: 'Travel', amount: 2100, color: 'from-green-500 to-emerald-500' },
          { label: 'Meals', amount: 650, color: 'from-orange-500 to-red-500' }
        ].map(({ label, amount, color }) => (
          <div key={label} className="bg-white/80 backdrop-blur-lg rounded-2xl p-6 border border-gray-200 hover:shadow-lg transition-all duration-300">
            <div className={`w-12 h-12 bg-gradient-to-r ${color} rounded-xl flex items-center justify-center mb-4`}>
              <Receipt className="w-6 h-6 text-white" />
            </div>
            <div className="text-xl font-bold text-gray-900 mb-1">${amount}</div>
            <div className="text-gray-600 text-sm">{label}</div>
          </div>
        ))}
      </div>

      {/* Recent Expenses */}
      <div className="bg-white/80 backdrop-blur-lg rounded-2xl border border-gray-200 overflow-hidden">
        <div className="p-6 border-b border-gray-200">
          <h3 className="text-lg font-semibold text-gray-900">Recent Expenses</h3>
        </div>
        <div className="overflow-x-auto">
          <table className="w-full">
            <thead className="bg-gray-50 border-b border-gray-200">
              <tr>
                <th className="text-left p-6 font-semibold text-gray-900">Description</th>
                <th className="text-left p-6 font-semibold text-gray-900">Category</th>
                <th className="text-left p-6 font-semibold text-gray-900">Amount</th>
                <th className="text-left p-6 font-semibold text-gray-900">Date</th>
                <th className="text-left p-6 font-semibold text-gray-900">Actions</th>
              </tr>
            </thead>
            <tbody>
              {expenses.map((expense) => (
                <tr key={expense.id} className="border-b border-gray-100 hover:bg-gray-50 transition-colors">
                  <td className="p-6 font-medium text-gray-900">{expense.description}</td>
                  <td className="p-6">
                    <span className="inline-flex items-center px-3 py-1 rounded-full text-sm font-medium bg-blue-100 text-blue-800">
                      {expense.category}
                    </span>
                  </td>
                  <td className="p-6 font-semibold text-gray-900">${expense.amount}</td>
                  <td className="p-6 text-gray-600">{expense.date}</td>
                  <td className="p-6">
                    <div className="flex items-center space-x-2">
                      <button className="p-2 text-gray-600 hover:text-blue-600 hover:bg-blue-50 rounded-lg transition-colors">
                        <Edit className="w-4 h-4" />
                      </button>
                      <button className="p-2 text-gray-600 hover:text-red-600 hover:bg-red-50 rounded-lg transition-colors">
                        <Trash2 className="w-4 h-4" />
                      </button>
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

  const AnalyticsView = () => (
    <div className="p-6 lg:p-8">
      <div className="mb-8">
        <h1 className="text-3xl font-bold text-gray-900">Analytics</h1>
        <p className="text-gray-600 mt-1">Insights and trends for your business</p>
      </div>

      {/* Key Metrics */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-6 mb-8">
        {[
          { label: 'Monthly Recurring Revenue', value: '$12,450', change: '+18.2%', positive: true },
          { label: 'Average Invoice Value', value: '$1,875', change: '+5.4%', positive: true },
          { label: 'Payment Collection Rate', value: '94.2%', change: '-2.1%', positive: false }
        ].map(({ label, value, change, positive }) => (
          <div key={label} className="bg-white/80 backdrop-blur-lg rounded-2xl p-6 border border-gray-200 hover:shadow-lg transition-all duration-300">
            <div className="text-2xl font-bold text-gray-900 mb-2">{value}</div>
            <div className="text-gray-600 text-sm mb-2">{label}</div>
            <div className={`text-sm font-medium ${positive ? 'text-green-600' : 'text-red-600'}`}>
              {change} from last month
            </div>
          </div>
        ))}
      </div>

      {/* Charts */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-8">
        {/* Profit/Loss Chart */}
        <div className="bg-white/80 backdrop-blur-lg rounded-2xl p-6 border border-gray-200">
          <h3 className="text-lg font-semibold text-gray-900 mb-4">Profit & Loss</h3>
          <div className="h-64 flex items-end justify-center space-x-4">
            <div className="flex flex-col items-center space-y-2">
              <div className="w-16 h-32 bg-gradient-to-t from-green-500 to-emerald-500 rounded-t opacity-80"></div>
              <span className="text-xs text-gray-600">Revenue</span>
            </div>
            <div className="flex flex-col items-center space-y-2">
              <div className="w-16 h-20 bg-gradient-to-t from-red-500 to-orange-500 rounded-t opacity-80"></div>
              <span className="text-xs text-gray-600">Expenses</span>
            </div>
            <div className="flex flex-col items-center space-y-2">
              <div className="w-16 h-24 bg-gradient-to-t from-blue-500 to-purple-500 rounded-t opacity-80"></div>
              <span className="text-xs text-gray-600">Profit</span>
            </div>
          </div>
        </div>

        {/* Client Distribution */}
        <div className="bg-white/80 backdrop-blur-lg rounded-2xl p-6 border border-gray-200">
          <h3 className="text-lg font-semibold text-gray-900 mb-4">Top Clients</h3>
          <div className="space-y-4">
            {[
              { name: 'Acme Corp', percentage: 35, amount: '$15,750' },
              { name: 'Tech Solutions', percentage: 28, amount: '$12,600' },
              { name: 'Design Studio', percentage: 20, amount: '$9,000' },
              { name: 'Others', percentage: 17, amount: '$7,650' }
            ].map(({ name, percentage, amount }) => (
              <div key={name} className="flex items-center justify-between">
                <div className="flex-1">
                  <div className="flex justify-between items-center mb-1">
                    <span className="text-sm font-medium text-gray-900">{name}</span>
                    <span className="text-sm text-gray-600">{amount}</span>
                  </div>
                  <div className="w-full bg-gray-200 rounded-full h-2">
                    <div 
                      className="bg-gradient-to-r from-blue-500 to-purple-500 h-2 rounded-full transition-all duration-500"
                      style={{ width: `${percentage}%` }}
                    ></div>
                  </div>
                </div>
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  );

  if (currentView === 'landing') {
    return <LandingPage />;
  }

  return (
    <div className="min-h-screen bg-gradient-to-br from-slate-50 via-blue-50 to-purple-50">
      <NavigationSidebar />
      
      {/* Mobile Header */}
      <div className="lg:hidden bg-white/80 backdrop-blur-lg border-b border-gray-200 px-4 py-3">
        <div className="flex items-center justify-between">
          <button
            onClick={() => setSidebarOpen(!sidebarOpen)}
            className="p-2 text-gray-600 hover:text-gray-900"
          >
            <Menu className="w-6 h-6" />
          </button>
          <div className="flex items-center space-x-2">
            <div className="w-6 h-6 bg-gradient-to-r from-blue-600 to-purple-600 rounded-md flex items-center justify-center">
              <TrendingUp className="w-4 h-4 text-white" />
            </div>
            <span className="font-bold bg-gradient-to-r from-blue-600 to-purple-600 bg-clip-text text-transparent">
              FinanceMaster
            </span>
          </div>
          <button 
            onClick={() => setCurrentView('landing')}
            className="text-gray-600 hover:text-gray-900"
          >
            <X className="w-6 h-6" />
          </button>
        </div>
      </div>

      {/* Main Content */}
      <div className="lg:ml-64">
        {currentView === 'dashboard' && <Dashboard />}
        {currentView === 'invoices' && <InvoicesView />}
        {currentView === 'expenses' && <ExpensesView />}
        {currentView === 'analytics' && <AnalyticsView />}
        {currentView === 'clients' && (
          <div className="p-6 lg:p-8">
            <h1 className="text-3xl font-bold text-gray-900 mb-4">Clients</h1>
            <div className="bg-white/80 backdrop-blur-lg rounded-2xl p-8 border border-gray-200 text-center">
              <Users className="w-16 h-16 text-gray-400 mx-auto mb-4" />
              <h3 className="text-xl font-semibold text-gray-900 mb-2">Client Management</h3>
              <p className="text-gray-600">Manage your clients, contacts, and project relationships.</p>
            </div>
          </div>
        )}
        {currentView === 'settings' && (
          <div className="p-6 lg:p-8">
            <h1 className="text-3xl font-bold text-gray-900 mb-4">Settings</h1>
            <div className="bg-white/80 backdrop-blur-lg rounded-2xl p-8 border border-gray-200 text-center">
              <Settings className="w-16 h-16 text-gray-400 mx-auto mb-4" />
              <h3 className="text-xl font-semibold text-gray-900 mb-2">Account Settings</h3>
              <p className="text-gray-600">Customize your account, billing preferences, and integrations.</p>
            </div>
          </div>
        )}
      </div>

      {/* Mobile Sidebar Overlay */}
      {sidebarOpen && (
        <div 
          className="fixed inset-0 bg-black bg-opacity-50 z-40 lg:hidden"
          onClick={() => setSidebarOpen(false)}
        />
      )}
    </div>
  );
};

export default FinanceMasterPro;
