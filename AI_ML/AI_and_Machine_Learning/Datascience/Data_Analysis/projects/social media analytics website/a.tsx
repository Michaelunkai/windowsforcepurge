import React, { useState, useEffect } from 'react';
import { LineChart, Line, AreaChart, Area, BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, PieChart, Pie, Cell } from 'recharts';
import { Heart, MessageCircle, Share2, Eye, TrendingUp, Users, DollarSign, Calendar, Search, Bell, Settings, Instagram, Youtube, Twitter, Globe, ChevronRight, X, ExternalLink, Camera, Video, FileImage, MoreHorizontal } from 'lucide-react';

const SocialMediaAnalytics = () => {
  const [activeTab, setActiveTab] = useState('overview');
  const [activePlatform, setActivePlatform] = useState('instagram');
  const [selectedPost, setSelectedPost] = useState(null);
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [animatedMetrics, setAnimatedMetrics] = useState({
    followers: 0,
    engagement: 0,
    reach: 0,
    revenue: 0
  });

  // Animation for metrics
  useEffect(() => {
    const targets = { followers: 284567, engagement: 4.7, reach: 1200000, revenue: 15420 };
    const duration = 2000;
    const steps = 60;
    const stepDuration = duration / steps;

    let currentStep = 0;
    const interval = setInterval(() => {
      currentStep++;
      const progress = currentStep / steps;
      const easeOut = 1 - Math.pow(1 - progress, 3);

      setAnimatedMetrics({
        followers: Math.round(targets.followers * easeOut),
        engagement: (targets.engagement * easeOut).toFixed(1),
        reach: Math.round(targets.reach * easeOut),
        revenue: Math.round(targets.revenue * easeOut)
      });

      if (currentStep >= steps) {
        clearInterval(interval);
      }
    }, stepDuration);

    return () => clearInterval(interval);
  }, []);

  // Mock data
  const engagementData = [
    { date: 'Jan', likes: 12000, comments: 840, shares: 320, reach: 45000 },
    { date: 'Feb', likes: 15000, comments: 1020, shares: 480, reach: 52000 },
    { date: 'Mar', likes: 18000, comments: 1200, shares: 560, reach: 61000 },
    { date: 'Apr', likes: 22000, comments: 1500, shares: 720, reach: 75000 },
    { date: 'May', likes: 25000, comments: 1800, shares: 880, reach: 84000 },
    { date: 'Jun', likes: 28000, comments: 2100, shares: 960, reach: 92000 }
  ];

  const platformData = [
    { name: 'Instagram', value: 45, color: '#E4405F' },
    { name: 'TikTok', value: 30, color: '#000000' },
    { name: 'YouTube', value: 15, color: '#FF0000' },
    { name: 'Twitter', value: 10, color: '#1DA1F2' }
  ];

  const posts = [
    {
      id: 1,
      platform: 'instagram',
      type: 'image',
      image: 'https://images.unsplash.com/photo-1611162617474-5b21e879e113?w=400',
      caption: 'Beautiful sunset vibes ✨ #sunset #photography',
      likes: 15420,
      comments: 284,
      shares: 89,
      reach: 45672,
      timestamp: '2h ago',
      engagement: 4.8
    },
    {
      id: 2,
      platform: 'instagram',
      type: 'video',
      image: 'https://images.unsplash.com/photo-1611162616305-c69b3fa7fbe0?w=400',
      caption: 'Behind the scenes of our latest photoshoot 🎬',
      likes: 8934,
      comments: 156,
      shares: 67,
      reach: 32140,
      timestamp: '6h ago',
      engagement: 3.2
    },
    {
      id: 3,
      platform: 'tiktok',
      type: 'video',
      image: 'https://images.unsplash.com/photo-1611162618071-b39a2ec055fb?w=400',
      caption: 'Quick makeup tutorial! Save this post 💄',
      likes: 42156,
      comments: 892,
      shares: 324,
      reach: 123456,
      timestamp: '1d ago',
      engagement: 6.7
    },
    {
      id: 4,
      platform: 'youtube',
      type: 'video',
      image: 'https://images.unsplash.com/photo-1611162617213-7d7a39e9b1d7?w=400',
      caption: 'GRWM: Date Night Edition | Full Tutorial',
      likes: 12840,
      comments: 487,
      shares: 156,
      reach: 87432,
      timestamp: '2d ago',
      engagement: 5.1
    },
    {
      id: 5,
      platform: 'instagram',
      type: 'image',
      image: 'https://images.unsplash.com/photo-1611162618479-ee3d24aaef0b?w=400',
      caption: 'Coffee & contemplation ☕️ #mondayvibes',
      likes: 9876,
      comments: 203,
      shares: 45,
      reach: 28934,
      timestamp: '3d ago',
      engagement: 3.8
    },
    {
      id: 6,
      platform: 'tiktok',
      type: 'video',
      image: 'https://images.unsplash.com/photo-1611162616475-46b635cb6868?w=400',
      caption: 'POV: You finally found your style ✨',
      likes: 67823,
      comments: 1245,
      shares: 567,
      reach: 198765,
      timestamp: '4d ago',
      engagement: 8.2
    }
  ];

  const influencers = [
    {
      id: 1,
      name: 'Emma Rodriguez',
      username: '@emmabeauty',
      followers: '2.4M',
      engagement: '4.8%',
      niche: 'Beauty & Lifestyle',
      avatar: 'https://images.unsplash.com/photo-1494790108755-2616b612b786?w=150',
      verified: true,
      rate: '$8,500'
    },
    {
      id: 2,
      name: 'Alex Chen',
      username: '@alexfitness',
      followers: '1.8M',
      engagement: '5.2%',
      niche: 'Fitness & Health',
      avatar: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150',
      verified: true,
      rate: '$6,200'
    },
    {
      id: 3,
      name: 'Sofia Martinez',
      username: '@sofiatravel',
      followers: '980K',
      engagement: '6.1%',
      niche: 'Travel & Adventure',
      avatar: 'https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=150',
      verified: false,
      rate: '$3,800'
    }
  ];

  const platforms = [
    { id: 'instagram', name: 'Instagram', icon: Instagram, color: 'from-purple-500 to-pink-500' },
    { id: 'tiktok', name: 'TikTok', icon: Globe, color: 'from-black to-gray-800' },
    { id: 'youtube', name: 'YouTube', icon: Youtube, color: 'from-red-500 to-red-600' },
    { id: 'twitter', name: 'Twitter', icon: Twitter, color: 'from-blue-400 to-blue-500' }
  ];

  const openModal = (post) => {
    setSelectedPost(post);
    setIsModalOpen(true);
  };

  const closeModal = () => {
    setIsModalOpen(false);
    setSelectedPost(null);
  };

  const getPlatformIcon = (platform) => {
    switch (platform) {
      case 'instagram': return Instagram;
      case 'tiktok': return Globe;
      case 'youtube': return Youtube;
      case 'twitter': return Twitter;
      default: return Globe;
    }
  };

  const getTypeIcon = (type) => {
    switch (type) {
      case 'video': return Video;
      case 'image': return FileImage;
      default: return Camera;
    }
  };

  return (
    <div className="min-h-screen bg-gradient-to-br from-gray-50 to-gray-100">
      {/* Header */}
      <header className="bg-white shadow-sm border-b border-gray-200 sticky top-0 z-40">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex justify-between items-center h-16">
            <div className="flex items-center space-x-4">
              <div className="w-8 h-8 bg-gradient-to-r from-purple-500 to-pink-500 rounded-lg flex items-center justify-center">
                <TrendingUp className="w-5 h-5 text-white" />
              </div>
              <h1 className="text-xl font-bold text-gray-900">SocialMetrics</h1>
            </div>
            
            <div className="flex items-center space-x-4">
              <div className="relative">
                <Search className="w-5 h-5 text-gray-400 absolute left-3 top-1/2 transform -translate-y-1/2" />
                <input
                  type="text"
                  placeholder="Search campaigns, influencers..."
                  className="pl-10 pr-4 py-2 border border-gray-200 rounded-lg focus:ring-2 focus:ring-purple-500 focus:border-transparent w-64"
                />
              </div>
              <button className="p-2 text-gray-400 hover:text-gray-600 transition-colors">
                <Bell className="w-5 h-5" />
              </button>
              <button className="p-2 text-gray-400 hover:text-gray-600 transition-colors">
                <Settings className="w-5 h-5" />
              </button>
              <div className="w-8 h-8 bg-gradient-to-r from-purple-500 to-pink-500 rounded-full"></div>
            </div>
          </div>
        </div>
      </header>

      {/* Navigation Tabs */}
      <nav className="bg-white shadow-sm border-b border-gray-200">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex space-x-8">
            {[
              { id: 'overview', label: 'Overview' },
              { id: 'analytics', label: 'Analytics' },
              { id: 'content', label: 'Content' },
              { id: 'influencers', label: 'Influencers' },
              { id: 'campaigns', label: 'Campaigns' }
            ].map((tab) => (
              <button
                key={tab.id}
                onClick={() => setActiveTab(tab.id)}
                className={`py-4 px-1 border-b-2 font-medium text-sm transition-colors ${
                  activeTab === tab.id
                    ? 'border-purple-500 text-purple-600'
                    : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'
                }`}
              >
                {tab.label}
              </button>
            ))}
          </div>
        </div>
      </nav>

      {/* Main Content */}
      <main className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        {activeTab === 'overview' && (
          <div className="space-y-8">
            {/* Key Metrics */}
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
              <div className="bg-white rounded-xl shadow-sm p-6 border border-gray-200 hover:shadow-md transition-shadow">
                <div className="flex items-center justify-between">
                  <div>
                    <p className="text-sm font-medium text-gray-600">Total Followers</p>
                    <p className="text-3xl font-bold text-gray-900">{animatedMetrics.followers.toLocaleString()}</p>
                    <div className="flex items-center mt-2">
                      <TrendingUp className="w-4 h-4 text-green-500" />
                      <span className="text-sm text-green-600 ml-1">+12.5%</span>
                    </div>
                  </div>
                  <div className="w-12 h-12 bg-gradient-to-r from-blue-500 to-purple-600 rounded-lg flex items-center justify-center">
                    <Users className="w-6 h-6 text-white" />
                  </div>
                </div>
              </div>

              <div className="bg-white rounded-xl shadow-sm p-6 border border-gray-200 hover:shadow-md transition-shadow">
                <div className="flex items-center justify-between">
                  <div>
                    <p className="text-sm font-medium text-gray-600">Engagement Rate</p>
                    <p className="text-3xl font-bold text-gray-900">{animatedMetrics.engagement}%</p>
                    <div className="flex items-center mt-2">
                      <TrendingUp className="w-4 h-4 text-green-500" />
                      <span className="text-sm text-green-600 ml-1">+0.8%</span>
                    </div>
                  </div>
                  <div className="w-12 h-12 bg-gradient-to-r from-pink-500 to-red-500 rounded-lg flex items-center justify-center">
                    <Heart className="w-6 h-6 text-white" />
                  </div>
                </div>
              </div>

              <div className="bg-white rounded-xl shadow-sm p-6 border border-gray-200 hover:shadow-md transition-shadow">
                <div className="flex items-center justify-between">
                  <div>
                    <p className="text-sm font-medium text-gray-600">Total Reach</p>
                    <p className="text-3xl font-bold text-gray-900">{(animatedMetrics.reach / 1000000).toFixed(1)}M</p>
                    <div className="flex items-center mt-2">
                      <TrendingUp className="w-4 h-4 text-green-500" />
                      <span className="text-sm text-green-600 ml-1">+18.2%</span>
                    </div>
                  </div>
                  <div className="w-12 h-12 bg-gradient-to-r from-green-500 to-teal-500 rounded-lg flex items-center justify-center">
                    <Eye className="w-6 h-6 text-white" />
                  </div>
                </div>
              </div>

              <div className="bg-white rounded-xl shadow-sm p-6 border border-gray-200 hover:shadow-md transition-shadow">
                <div className="flex items-center justify-between">
                  <div>
                    <p className="text-sm font-medium text-gray-600">Revenue</p>
                    <p className="text-3xl font-bold text-gray-900">${animatedMetrics.revenue.toLocaleString()}</p>
                    <div className="flex items-center mt-2">
                      <TrendingUp className="w-4 h-4 text-green-500" />
                      <span className="text-sm text-green-600 ml-1">+24.1%</span>
                    </div>
                  </div>
                  <div className="w-12 h-12 bg-gradient-to-r from-yellow-500 to-orange-500 rounded-lg flex items-center justify-center">
                    <DollarSign className="w-6 h-6 text-white" />
                  </div>
                </div>
              </div>
            </div>

            {/* Charts */}
            <div className="grid grid-cols-1 lg:grid-cols-2 gap-8">
              <div className="bg-white rounded-xl shadow-sm p-6 border border-gray-200">
                <h3 className="text-lg font-semibold text-gray-900 mb-4">Engagement Trends</h3>
                <ResponsiveContainer width="100%" height={300}>
                  <AreaChart data={engagementData}>
                    <defs>
                      <linearGradient id="colorLikes" x1="0" y1="0" x2="0" y2="1">
                        <stop offset="5%" stopColor="#8B5CF6" stopOpacity={0.8}/>
                        <stop offset="95%" stopColor="#8B5CF6" stopOpacity={0.1}/>
                      </linearGradient>
                    </defs>
                    <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
                    <XAxis dataKey="date" stroke="#6b7280" />
                    <YAxis stroke="#6b7280" />
                    <Tooltip 
                      contentStyle={{ 
                        background: 'white', 
                        border: '1px solid #e5e7eb', 
                        borderRadius: '8px',
                        boxShadow: '0 4px 6px -1px rgba(0, 0, 0, 0.1)'
                      }} 
                    />
                    <Area type="monotone" dataKey="likes" stroke="#8B5CF6" fillOpacity={1} fill="url(#colorLikes)" strokeWidth={2} />
                  </AreaChart>
                </ResponsiveContainer>
              </div>

              <div className="bg-white rounded-xl shadow-sm p-6 border border-gray-200">
                <h3 className="text-lg font-semibold text-gray-900 mb-4">Platform Distribution</h3>
                <ResponsiveContainer width="100%" height={300}>
                  <PieChart>
                    <Pie
                      data={platformData}
                      cx="50%"
                      cy="50%"
                      innerRadius={60}
                      outerRadius={120}
                      paddingAngle={5}
                      dataKey="value"
                    >
                      {platformData.map((entry, index) => (
                        <Cell key={`cell-${index}`} fill={entry.color} />
                      ))}
                    </Pie>
                    <Tooltip 
                      contentStyle={{ 
                        background: 'white', 
                        border: '1px solid #e5e7eb', 
                        borderRadius: '8px',
                        boxShadow: '0 4px 6px -1px rgba(0, 0, 0, 0.1)'
                      }} 
                    />
                  </PieChart>
                </ResponsiveContainer>
                <div className="mt-4 grid grid-cols-2 gap-4">
                  {platformData.map((platform, index) => (
                    <div key={index} className="flex items-center">
                      <div className={`w-3 h-3 rounded-full mr-2`} style={{ backgroundColor: platform.color }}></div>
                      <span className="text-sm text-gray-600">{platform.name} ({platform.value}%)</span>
                    </div>
                  ))}
                </div>
              </div>
            </div>
          </div>
        )}

        {activeTab === 'content' && (
          <div className="space-y-6">
            {/* Platform Filter */}
            <div className="flex space-x-4 overflow-x-auto pb-2">
              {platforms.map((platform) => {
                const Icon = platform.icon;
                return (
                  <button
                    key={platform.id}
                    onClick={() => setActivePlatform(platform.id)}
                    className={`flex items-center space-x-2 px-4 py-2 rounded-lg font-medium text-sm whitespace-nowrap transition-all ${
                      activePlatform === platform.id
                        ? `bg-gradient-to-r ${platform.color} text-white shadow-lg`
                        : 'bg-white text-gray-600 hover:bg-gray-50 border border-gray-200'
                    }`}
                  >
                    <Icon className="w-4 h-4" />
                    <span>{platform.name}</span>
                  </button>
                );
              })}
            </div>

            {/* Content Grid */}
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
              {posts
                .filter(post => activePlatform === 'all' || post.platform === activePlatform)
                .map((post) => {
                  const PlatformIcon = getPlatformIcon(post.platform);
                  const TypeIcon = getTypeIcon(post.type);
                  
                  return (
                    <div 
                      key={post.id} 
                      className="bg-white rounded-xl shadow-sm border border-gray-200 overflow-hidden hover:shadow-lg transition-all duration-300 cursor-pointer group"
                      onClick={() => openModal(post)}
                    >
                      <div className="relative">
                        <img 
                          src={post.image} 
                          alt="Post content" 
                          className="w-full h-64 object-cover group-hover:scale-105 transition-transform duration-300"
                        />
                        <div className="absolute top-3 left-3 bg-black bg-opacity-50 rounded-lg p-2 flex items-center space-x-1">
                          <PlatformIcon className="w-4 h-4 text-white" />
                          <TypeIcon className="w-4 h-4 text-white" />
                        </div>
                        <div className="absolute top-3 right-3 bg-black bg-opacity-50 rounded-lg px-2 py-1">
                          <span className="text-white text-xs font-medium">{post.engagement}%</span>
                        </div>
                      </div>
                      
                      <div className="p-4">
                        <p className="text-gray-900 text-sm mb-3 line-clamp-2">{post.caption}</p>
                        
                        <div className="flex items-center justify-between text-sm text-gray-500 mb-3">
                          <span>{post.timestamp}</span>
                          <div className="flex items-center space-x-3">
                            <div className="flex items-center space-x-1">
                              <Heart className="w-4 h-4" />
                              <span>{post.likes.toLocaleString()}</span>
                            </div>
                            <div className="flex items-center space-x-1">
                              <MessageCircle className="w-4 h-4" />
                              <span>{post.comments}</span>
                            </div>
                          </div>
                        </div>
                        
                        <div className="flex items-center justify-between">
                          <div className="flex items-center space-x-4 text-xs text-gray-500">
                            <span>Reach: {post.reach.toLocaleString()}</span>
                          </div>
                          <ChevronRight className="w-4 h-4 text-gray-400 group-hover:text-purple-500 transition-colors" />
                        </div>
                      </div>
                    </div>
                  );
                })}
            </div>
          </div>
        )}

        {activeTab === 'influencers' && (
          <div className="space-y-6">
            <div className="flex justify-between items-center">
              <h2 className="text-2xl font-bold text-gray-900">Top Influencers</h2>
              <button className="bg-gradient-to-r from-purple-500 to-pink-500 text-white px-4 py-2 rounded-lg font-medium hover:shadow-lg transition-shadow">
                Find Influencers
              </button>
            </div>

            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
              {influencers.map((influencer) => (
                <div key={influencer.id} className="bg-white rounded-xl shadow-sm border border-gray-200 p-6 hover:shadow-lg transition-all duration-300 group">
                  <div className="flex items-center space-x-4 mb-4">
                    <img 
                      src={influencer.avatar} 
                      alt={influencer.name}
                      className="w-16 h-16 rounded-full object-cover ring-2 ring-purple-100 group-hover:ring-purple-300 transition-all"
                    />
                    <div className="flex-1">
                      <div className="flex items-center space-x-2">
                        <h3 className="font-semibold text-gray-900">{influencer.name}</h3>
                        {influencer.verified && (
                          <div className="w-5 h-5 bg-blue-500 rounded-full flex items-center justify-center">
                            <svg className="w-3 h-3 text-white" fill="currentColor" viewBox="0 0 20 20">
                              <path fillRule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clipRule="evenodd" />
                            </svg>
                          </div>
                        )}
                      </div>
                      <p className="text-gray-500 text-sm">{influencer.username}</p>
                    </div>
                  </div>

                  <div className="space-y-3 mb-4">
                    <div className="flex justify-between">
                      <span className="text-gray-600 text-sm">Followers</span>
                      <span className="font-semibold text-gray-900">{influencer.followers}</span>
                    </div>
                    <div className="flex justify-between">
                      <span className="text-gray-600 text-sm">Engagement</span>
                      <span className="font-semibold text-green-600">{influencer.engagement}</span>
                    </div>
                    <div className="flex justify-between">
                      <span className="text-gray-600 text-sm">Rate</span>
                      <span className="font-semibold text-purple-600">{influencer.rate}</span>
                    </div>
                  </div>

                  <div className="mb-4">
                    <span className="inline-block bg-purple-100 text-purple-800 text-xs px-2 py-1 rounded-full">
                      {influencer.niche}
                    </span>
                  </div>

                  <div className="flex space-x-2">
                    <button className="flex-1 bg-gradient-to-r from-purple-500 to-pink-500 text-white py-2 px-4 rounded-lg text-sm font-medium hover:shadow-lg transition-shadow">
                      Contact
                    </button>
                    <button className="p-2 border border-gray-200 rounded-lg hover:bg-gray-50 transition-colors">
                      <ExternalLink className="w-4 h-4 text-gray-600" />
                    </button>
                  </div>
                </div>
              ))}
            </div>
          </div>
        )}
      </main>

      {/* Modal */}
      {isModalOpen && selectedPost && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-50">
          <div className="bg-white rounded-xl max-w-4xl w-full max-h-[90vh] overflow-hidden">
            <div className="flex items-center justify-between p-6 border-b border-gray-200">
              <h3 className="text-lg font-semibold text-gray-900">Post Analytics</h3>
              <button 
                onClick={closeModal}
                className="p-2 hover:bg-gray-100 rounded-lg transition-colors"
              >
                <X className="w-5 h-5 text-gray-500" />
              </button>
            </div>
            
            <div className="p-6 overflow-y-auto max-h-[calc(90vh-80px)]">
              <div className="grid grid-cols-1 lg:grid-cols-2 gap-8">
                <div>
                  <img 
                    src={selectedPost.image} 
                    alt="Post content" 
                    className="w-full rounded-lg shadow-sm"
                  />
                  <div className="mt-4">
                    <p className="text-gray-900 mb-4">{selectedPost.caption}</p>
                    <div className="flex items-center space-x-4 text-sm text-gray-500">
                      <span>{selectedPost.timestamp}</span>
                      <span>•</span>
                      <span className="capitalize">{selectedPost.platform}</span>
                    </div>
                  </div>
                </div>
                
                <div className="space-y-6">
                  <div className="grid grid-cols-2 gap-4">
                    <div className="bg-gradient-to-r from-pink-50 to-red-50 p-4 rounded-lg">
                      <div className="flex items-center space-x-2 mb-2">
                        <Heart className="w-5 h-5 text-pink-500" />
                        <span className="text-sm font-medium text-gray-600">Likes</span>
                      </div>
                      <p className="text-2xl font-bold text-gray-900">{selectedPost.likes.toLocaleString()}</p>
                    </div>
                    
                    <div className="bg-gradient-to-r from-blue-50 to-indigo-50 p-4 rounded-lg">
                      <div className="flex items-center space-x-2 mb-2">
                        <MessageCircle className="w-5 h-5 text-blue-500" />
                        <span className="text-sm font-medium text-gray-600">Comments</span>
                      </div>
                      <p className="text-2xl font-bold text-gray-900">{selectedPost.comments.toLocaleString()}</p>
                    </div>
                    
                    <div className="bg-gradient-to-r from-green-50 to-emerald-50 p-4 rounded-lg">
                      <div className="flex items-center space-x-2 mb-2">
                        <Share2 className="w-5 h-5 text-green-500" />
                        <span className="text-sm font-medium text-gray-600">Shares</span>
                      </div>
                      <p className="text-2xl font-bold text-gray-900">{selectedPost.shares}</p>
                    </div>
                    
                    <div className="bg-gradient-to-r from-purple-50 to-violet-50 p-4 rounded-lg">
                      <div className="flex items-center space-x-2 mb-2">
                        <Eye className="w-5 h-5 text-purple-500" />
                        <span className="text-sm font-medium text-gray-600">Reach</span>
                      </div>
                      <p className="text-2xl font-bold text-gray-900">{selectedPost.reach.toLocaleString()}</p>
                    </div>
                  </div>
                  
                  <div className="bg-gray-50 p-4 rounded-lg">
                    <h4 className="font-semibold text-gray-900 mb-3">Engagement Rate</h4>
                    <div className="flex items-center space-x-3">
                      <div className="flex-1 bg-gray-200 rounded-full h-2">
                        <div 
                          className="bg-gradient-to-r from-purple-500 to-pink-500 h-2 rounded-full transition-all duration-1000"
                          style={{ width: `${selectedPost.engagement * 10}%` }}
                        ></div>
                      </div>
                      <span className="text-lg font-bold text-purple-600">{selectedPost.engagement}%</span>
                    </div>
                  </div>
                  
                  <div className="space-y-3">
                    <h4 className="font-semibold text-gray-900">Performance Insights</h4>
                    <div className="space-y-2 text-sm text-gray-600">
                      <p>• This post performed {selectedPost.engagement > 4 ? 'above' : 'below'} average engagement</p>
                      <p>• Best performing time: {selectedPost.timestamp}</p>
                      <p>• Audience sentiment: Positive</p>
                      <p>• Estimated revenue impact: ${(selectedPost.likes * 0.02).toFixed(0)}</p>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default SocialMediaAnalytics;
