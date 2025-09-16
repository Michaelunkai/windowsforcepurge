import React, { useState, useEffect } from 'react';
import { Calendar, Clock, DollarSign, Users, Bell, Settings, Menu, X, ChevronLeft, ChevronRight, Plus, Edit, Trash2, Phone, Mail, CreditCard, Check, AlertCircle, Star, MapPin, User, LogOut } from 'lucide-react';

const BookingSaaS = () => {
  const [currentView, setCurrentView] = useState('login');
  const [userType, setUserType] = useState('customer'); // customer, provider, admin
  const [selectedDate, setSelectedDate] = useState(new Date());
  const [selectedService, setSelectedService] = useState(null);
  const [bookings, setBookings] = useState([]);
  const [services, setServices] = useState([
    { id: 1, name: 'Dog Grooming', duration: 90, price: 65, provider: 'Sarah Wilson', rating: 4.8, location: 'Downtown' },
    { id: 2, name: 'Personal Training', duration: 60, price: 80, provider: 'Mike Johnson', rating: 4.9, location: 'Gym Center' },
    { id: 3, name: 'Piano Lessons', duration: 45, price: 50, provider: 'Emily Chen', rating: 4.7, location: 'Music Studio' },
    { id: 4, name: 'Massage Therapy', duration: 75, price: 95, provider: 'Alex Rodriguez', rating: 4.9, location: 'Wellness Spa' }
  ]);
  const [currentUser, setCurrentUser] = useState(null);
  const [showMobileMenu, setShowMobileMenu] = useState(false);
  const [selectedTimeSlot, setSelectedTimeSlot] = useState(null);
  const [paymentMethod, setPaymentMethod] = useState('stripe');

  // Mock authentication
  const handleLogin = (email, password, type) => {
    setCurrentUser({ email, type });
    setUserType(type);
    if (type === 'admin') {
      setCurrentView('admin');
    } else if (type === 'provider') {
      setCurrentView('provider-dashboard');
    } else {
      setCurrentView('customer-dashboard');
    }
  };

  const handleLogout = () => {
    setCurrentUser(null);
    setCurrentView('login');
  };

  // Generate time slots
  const generateTimeSlots = (date) => {
    const slots = [];
    const startHour = 9;
    const endHour = 18;
    for (let hour = startHour; hour < endHour; hour++) {
      for (let minute = 0; minute < 60; minute += 30) {
        const time = `${hour.toString().padStart(2, '0')}:${minute.toString().padStart(2, '0')}`;
        slots.push({
          id: `${date.toDateString()}-${time}`,
          time,
          available: Math.random() > 0.3, // Mock availability
          booked: Math.random() > 0.7
        });
      }
    }
    return slots;
  };

  const timeSlots = generateTimeSlots(selectedDate);

  // Login Component
  const LoginForm = () => (
    <div className="min-h-screen bg-gradient-to-br from-blue-50 to-indigo-100 flex items-center justify-center p-4">
      <div className="bg-white rounded-2xl shadow-2xl w-full max-w-md p-8">
        <div className="text-center mb-8">
          <h1 className="text-3xl font-bold text-gray-900 mb-2">NicheBook</h1>
          <p className="text-gray-600">Book specialized services with ease</p>
        </div>
        
        <div className="space-y-4">
          <div className="flex bg-gray-100 rounded-lg p-1">
            <button
              onClick={() => setUserType('customer')}
              className={`flex-1 py-2 px-4 rounded-md text-sm font-medium transition-colors ${
                userType === 'customer' ? 'bg-white text-blue-600 shadow-sm' : 'text-gray-500'
              }`}
            >
              Customer
            </button>
            <button
              onClick={() => setUserType('provider')}
              className={`flex-1 py-2 px-4 rounded-md text-sm font-medium transition-colors ${
                userType === 'provider' ? 'bg-white text-blue-600 shadow-sm' : 'text-gray-500'
              }`}
            >
              Provider
            </button>
            <button
              onClick={() => setUserType('admin')}
              className={`flex-1 py-2 px-4 rounded-md text-sm font-medium transition-colors ${
                userType === 'admin' ? 'bg-white text-blue-600 shadow-sm' : 'text-gray-500'
              }`}
            >
              Admin
            </button>
          </div>
          
          <input
            type="email"
            placeholder="Email address"
            className="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
          />
          <input
            type="password"
            placeholder="Password"
            className="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
          />
          
          <button
            onClick={() => handleLogin('demo@email.com', 'password', userType)}
            className="w-full bg-blue-600 text-white py-3 rounded-lg font-medium hover:bg-blue-700 transition-colors"
          >
            Sign In
          </button>
          
          <div className="text-center">
            <a href="#" className="text-sm text-blue-600 hover:underline">
              Forgot your password?
            </a>
          </div>
          
          <div className="text-center pt-4 border-t">
            <p className="text-sm text-gray-600">
              Don't have an account?{' '}
              <a href="#" className="text-blue-600 hover:underline font-medium">
                Sign up
              </a>
            </p>
          </div>
        </div>
      </div>
    </div>
  );

  // Mobile Navigation
  const MobileMenu = () => (
    <div className={`fixed inset-0 bg-black bg-opacity-50 z-50 lg:hidden ${showMobileMenu ? 'block' : 'hidden'}`}>
      <div className="fixed inset-y-0 left-0 w-64 bg-white shadow-xl">
        <div className="flex items-center justify-between p-4 border-b">
          <h2 className="text-lg font-semibold">Menu</h2>
          <button onClick={() => setShowMobileMenu(false)}>
            <X className="h-6 w-6" />
          </button>
        </div>
        <nav className="p-4">
          <NavigationItems />
        </nav>
      </div>
    </div>
  );

  // Navigation Items
  const NavigationItems = () => {
    const getNavItems = () => {
      if (userType === 'admin') {
        return [
          { id: 'admin', label: 'Dashboard', icon: Users },
          { id: 'admin-users', label: 'Users', icon: User },
          { id: 'admin-bookings', label: 'Bookings', icon: Calendar },
          { id: 'admin-revenue', label: 'Revenue', icon: DollarSign },
          { id: 'admin-settings', label: 'Settings', icon: Settings }
        ];
      } else if (userType === 'provider') {
        return [
          { id: 'provider-dashboard', label: 'Dashboard', icon: Users },
          { id: 'provider-calendar', label: 'Calendar', icon: Calendar },
          { id: 'provider-services', label: 'Services', icon: Settings },
          { id: 'provider-earnings', label: 'Earnings', icon: DollarSign },
          { id: 'provider-notifications', label: 'Notifications', icon: Bell }
        ];
      } else {
        return [
          { id: 'customer-dashboard', label: 'Dashboard', icon: User },
          { id: 'browse-services', label: 'Browse Services', icon: Calendar },
          { id: 'my-bookings', label: 'My Bookings', icon: Clock },
          { id: 'notifications', label: 'Notifications', icon: Bell }
        ];
      }
    };

    return (
      <div className="space-y-2">
        {getNavItems().map((item) => (
          <button
            key={item.id}
            onClick={() => {
              setCurrentView(item.id);
              setShowMobileMenu(false);
            }}
            className={`w-full flex items-center gap-3 px-3 py-2 rounded-lg text-left transition-colors ${
              currentView === item.id
                ? 'bg-blue-100 text-blue-700'
                : 'text-gray-600 hover:bg-gray-100'
            }`}
          >
            <item.icon className="h-5 w-5" />
            {item.label}
          </button>
        ))}
        <button
          onClick={handleLogout}
          className="w-full flex items-center gap-3 px-3 py-2 rounded-lg text-left text-red-600 hover:bg-red-50 transition-colors mt-8"
        >
          <LogOut className="h-5 w-5" />
          Logout
        </button>
      </div>
    );
  };

  // Header Component
  const Header = () => (
    <header className="bg-white shadow-sm border-b">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="flex justify-between items-center h-16">
          <div className="flex items-center gap-4">
            <button
              onClick={() => setShowMobileMenu(true)}
              className="lg:hidden p-2 rounded-md text-gray-400 hover:text-gray-500"
            >
              <Menu className="h-6 w-6" />
            </button>
            <h1 className="text-xl font-bold text-gray-900">NicheBook</h1>
          </div>
          
          <div className="flex items-center gap-4">
            <button className="p-2 text-gray-400 hover:text-gray-500">
              <Bell className="h-6 w-6" />
            </button>
            <div className="flex items-center gap-2">
              <div className="w-8 h-8 bg-blue-500 rounded-full flex items-center justify-center">
                <span className="text-white text-sm font-medium">
                  {currentUser?.email?.charAt(0).toUpperCase()}
                </span>
              </div>
              <span className="hidden sm:block text-sm text-gray-700">
                {currentUser?.email}
              </span>
            </div>
          </div>
        </div>
      </div>
    </header>
  );

  // Service Browser
  const ServiceBrowser = () => (
    <div className="space-y-6">
      <div className="flex flex-col sm:flex-row gap-4 items-start sm:items-center justify-between">
        <h2 className="text-2xl font-bold text-gray-900">Available Services</h2>
        <div className="flex gap-2">
          <input
            type="text"
            placeholder="Search services..."
            className="px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
          />
          <select className="px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500">
            <option>All Categories</option>
            <option>Beauty & Wellness</option>
            <option>Fitness</option>
            <option>Education</option>
            <option>Pet Care</option>
          </select>
        </div>
      </div>
      
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
        {services.map((service) => (
          <div key={service.id} className="bg-white rounded-xl shadow-lg overflow-hidden hover:shadow-xl transition-shadow">
            <div className="h-48 bg-gradient-to-br from-blue-400 to-purple-500"></div>
            <div className="p-6">
              <div className="flex items-start justify-between mb-2">
                <h3 className="text-lg font-semibold text-gray-900">{service.name}</h3>
                <div className="flex items-center gap-1">
                  <Star className="h-4 w-4 text-yellow-400 fill-current" />
                  <span className="text-sm text-gray-600">{service.rating}</span>
                </div>
              </div>
              <p className="text-gray-600 mb-2">with {service.provider}</p>
              <div className="flex items-center gap-4 text-sm text-gray-500 mb-4">
                <div className="flex items-center gap-1">
                  <Clock className="h-4 w-4" />
                  {service.duration} min
                </div>
                <div className="flex items-center gap-1">
                  <MapPin className="h-4 w-4" />
                  {service.location}
                </div>
              </div>
              <div className="flex items-center justify-between">
                <span className="text-2xl font-bold text-gray-900">${service.price}</span>
                <button
                  onClick={() => {
                    setSelectedService(service);
                    setCurrentView('booking');
                  }}
                  className="bg-blue-600 text-white px-4 py-2 rounded-lg hover:bg-blue-700 transition-colors"
                >
                  Book Now
                </button>
              </div>
            </div>
          </div>
        ))}
      </div>
    </div>
  );

  // Booking Interface
  const BookingInterface = () => {
    if (!selectedService) return null;

    return (
      <div className="max-w-4xl mx-auto space-y-8">
        <div className="flex items-center gap-4">
          <button
            onClick={() => setCurrentView('browse-services')}
            className="p-2 text-gray-500 hover:text-gray-700"
          >
            <ChevronLeft className="h-6 w-6" />
          </button>
          <h2 className="text-2xl font-bold text-gray-900">Book {selectedService.name}</h2>
        </div>

        <div className="grid grid-cols-1 lg:grid-cols-2 gap-8">
          {/* Calendar */}
          <div className="bg-white rounded-xl shadow-lg p-6">
            <h3 className="text-lg font-semibold mb-4">Select Date</h3>
            <div className="space-y-4">
              <div className="flex items-center justify-between">
                <button
                  onClick={() => {
                    const newDate = new Date(selectedDate);
                    newDate.setMonth(newDate.getMonth() - 1);
                    setSelectedDate(newDate);
                  }}
                  className="p-2 text-gray-500 hover:text-gray-700"
                >
                  <ChevronLeft className="h-5 w-5" />
                </button>
                <h4 className="text-lg font-medium">
                  {selectedDate.toLocaleDateString('en-US', { month: 'long', year: 'numeric' })}
                </h4>
                <button
                  onClick={() => {
                    const newDate = new Date(selectedDate);
                    newDate.setMonth(newDate.getMonth() + 1);
                    setSelectedDate(newDate);
                  }}
                  className="p-2 text-gray-500 hover:text-gray-700"
                >
                  <ChevronRight className="h-5 w-5" />
                </button>
              </div>
              
              <div className="grid grid-cols-7 gap-2 text-center">
                {['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'].map((day) => (
                  <div key={day} className="text-sm font-medium text-gray-500 py-2">
                    {day}
                  </div>
                ))}
                {Array.from({ length: 35 }, (_, i) => {
                  const date = new Date(selectedDate.getFullYear(), selectedDate.getMonth(), i - 14);
                  const isCurrentMonth = date.getMonth() === selectedDate.getMonth();
                  const isSelected = date.toDateString() === selectedDate.toDateString();
                  const isToday = date.toDateString() === new Date().toDateString();
                  
                  return (
                    <button
                      key={i}
                      onClick={() => setSelectedDate(date)}
                      className={`p-2 text-sm rounded-lg transition-colors ${
                        !isCurrentMonth
                          ? 'text-gray-300'
                          : isSelected
                          ? 'bg-blue-600 text-white'
                          : isToday
                          ? 'bg-blue-100 text-blue-700'
                          : 'hover:bg-gray-100'
                      }`}
                    >
                      {date.getDate()}
                    </button>
                  );
                })}
              </div>
            </div>
          </div>

          {/* Time Slots */}
          <div className="bg-white rounded-xl shadow-lg p-6">
            <h3 className="text-lg font-semibold mb-4">Select Time</h3>
            <div className="grid grid-cols-2 gap-2 max-h-96 overflow-y-auto">
              {timeSlots.map((slot) => (
                <button
                  key={slot.id}
                  onClick={() => setSelectedTimeSlot(slot)}
                  disabled={!slot.available || slot.booked}
                  className={`p-3 text-sm rounded-lg border transition-colors ${
                    selectedTimeSlot?.id === slot.id
                      ? 'bg-blue-600 text-white border-blue-600'
                      : slot.available && !slot.booked
                      ? 'border-gray-300 hover:border-blue-500 hover:bg-blue-50'
                      : 'border-gray-200 text-gray-400 cursor-not-allowed bg-gray-50'
                  }`}
                >
                  {slot.time}
                  {slot.booked && <div className="text-xs mt-1">Booked</div>}
                </button>
              ))}
            </div>
          </div>
        </div>

        {/* Booking Summary */}
        {selectedTimeSlot && (
          <div className="bg-white rounded-xl shadow-lg p-6">
            <h3 className="text-lg font-semibold mb-4">Booking Summary</h3>
            <div className="space-y-4">
              <div className="flex justify-between">
                <span>Service:</span>
                <span className="font-medium">{selectedService.name}</span>
              </div>
              <div className="flex justify-between">
                <span>Provider:</span>
                <span className="font-medium">{selectedService.provider}</span>
              </div>
              <div className="flex justify-between">
                <span>Date & Time:</span>
                <span className="font-medium">
                  {selectedDate.toLocaleDateString()} at {selectedTimeSlot.time}
                </span>
              </div>
              <div className="flex justify-between">
                <span>Duration:</span>
                <span className="font-medium">{selectedService.duration} minutes</span>
              </div>
              <div className="flex justify-between text-lg font-semibold">
                <span>Total:</span>
                <span>${selectedService.price}</span>
              </div>
              
              <div className="border-t pt-4">
                <h4 className="font-medium mb-3">Payment Method</h4>
                <div className="space-y-2">
                  <label className="flex items-center gap-2">
                    <input
                      type="radio"
                      name="payment"
                      value="stripe"
                      checked={paymentMethod === 'stripe'}
                      onChange={(e) => setPaymentMethod(e.target.value)}
                      className="text-blue-600"
                    />
                    <CreditCard className="h-5 w-5" />
                    Credit Card (Stripe)
                  </label>
                  <label className="flex items-center gap-2">
                    <input
                      type="radio"
                      name="payment"
                      value="paypal"
                      checked={paymentMethod === 'paypal'}
                      onChange={(e) => setPaymentMethod(e.target.value)}
                      className="text-blue-600"
                    />
                    PayPal
                  </label>
                </div>
              </div>
              
              <button
                onClick={() => {
                  // Mock booking creation
                  const newBooking = {
                    id: Date.now(),
                    service: selectedService,
                    date: selectedDate,
                    time: selectedTimeSlot.time,
                    status: 'confirmed',
                    paymentMethod
                  };
                  setBookings([...bookings, newBooking]);
                  setCurrentView('my-bookings');
                }}
                className="w-full bg-blue-600 text-white py-3 rounded-lg font-medium hover:bg-blue-700 transition-colors"
              >
                Confirm Booking & Pay ${selectedService.price}
              </button>
            </div>
          </div>
        )}
      </div>
    );
  };

  // Provider Dashboard
  const ProviderDashboard = () => (
    <div className="space-y-6">
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
        <div className="bg-white rounded-xl shadow-lg p-6">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm text-gray-600">Today's Bookings</p>
              <p className="text-2xl font-bold text-gray-900">8</p>
            </div>
            <Calendar className="h-8 w-8 text-blue-500" />
          </div>
        </div>
        <div className="bg-white rounded-xl shadow-lg p-6">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm text-gray-600">This Week's Revenue</p>
              <p className="text-2xl font-bold text-gray-900">$1,240</p>
            </div>
            <DollarSign className="h-8 w-8 text-green-500" />
          </div>
        </div>
        <div className="bg-white rounded-xl shadow-lg p-6">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm text-gray-600">Rating</p>
              <p className="text-2xl font-bold text-gray-900">4.8</p>
            </div>
            <Star className="h-8 w-8 text-yellow-500" />
          </div>
        </div>
        <div className="bg-white rounded-xl shadow-lg p-6">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm text-gray-600">Active Services</p>
              <p className="text-2xl font-bold text-gray-900">3</p>
            </div>
            <Settings className="h-8 w-8 text-purple-500" />
          </div>
        </div>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <div className="bg-white rounded-xl shadow-lg p-6">
          <h3 className="text-lg font-semibold mb-4">Today's Schedule</h3>
          <div className="space-y-3">
            {[
              { time: '09:00', client: 'John Doe', service: 'Dog Grooming', status: 'confirmed' },
              { time: '10:30', client: 'Jane Smith', service: 'Dog Grooming', status: 'confirmed' },
              { time: '14:00', client: 'Mike Wilson', service: 'Dog Grooming', status: 'pending' },
              { time: '15:30', client: 'Sarah Brown', service: 'Dog Grooming', status: 'confirmed' }
            ].map((appointment, index) => (
              <div key={index} className="flex items-center justify-between p-3 bg-gray-50 rounded-lg">
                <div>
                  <p className="font-medium">{appointment.time} - {appointment.client}</p>
                  <p className="text-sm text-gray-600">{appointment.service}</p>
                </div>
                <span className={`px-2 py-1 rounded-full text-xs ${
                  appointment.status === 'confirmed' 
                    ? 'bg-green-100 text-green-800' 
                    : 'bg-yellow-100 text-yellow-800'
                }`}>
                  {appointment.status}
                </span>
              </div>
            ))}
          </div>
        </div>

        <div className="bg-white rounded-xl shadow-lg p-6">
          <h3 className="text-lg font-semibold mb-4">Recent Reviews</h3>
          <div className="space-y-4">
            {[
              { name: 'Alice Johnson', rating: 5, comment: 'Excellent service! Very professional.' },
              { name: 'Bob Miller', rating: 4, comment: 'Great experience, will book again.' },
              { name: 'Carol Davis', rating: 5, comment: 'Amazing work, highly recommended!' }
            ].map((review, index) => (
              <div key={index} className="border-b border-gray-200 last:border-0 pb-3 last:pb-0">
                <div className="flex items-center justify-between mb-2">
                  <p className="font-medium">{review.name}</p>
                  <div className="flex">
                    {[...Array(5)].map((_, i) => (
                      <Star
                        key={i}
                        className={`h-4 w-4 ${
                          i < review.rating ? 'text-yellow-400 fill-current' : 'text-gray-300'
                        }`}
                      />
                    ))}
                  </div>
                </div>
                <p className="text-sm text-gray-600">{review.comment}</p>
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  );

  // Admin Dashboard
  const AdminDashboard = () => (
    <div className="space-y-6">
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
        <div className="bg-white rounded-xl shadow-lg p-6">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm text-gray-600">Total Users</p>
              <p className="text-2xl font-bold text-gray-900">1,234</p>
            </div>
            <Users className="h-8 w-8 text-blue-500" />
          </div>
        </div>
        <div className="bg-white rounded-xl shadow-lg p-6">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm text-gray-600">Monthly Revenue</p>
              <p className="text-2xl font-bold text-gray-900">$24,580</p>
            </div>
            <DollarSign className="h-8 w-8 text-green-500" />
          </div>
        </div>
        <div className="bg-white rounded-xl shadow-lg p-6">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm text-gray-600">Active Bookings</p>
              <p className="text-2xl font-bold text-gray-900">156</p>
            </div>
            <Calendar className="h-8 w-8 text-purple-500" />
          </div>
        </div>
        <div className="bg-white rounded-xl shadow-lg p-6">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm text-gray-600">Commission Earned</p>
              <p className="text-2xl font-bold text-gray-900">$2,458</p>
            </div>
            <DollarSign className="h-8 w-8 text-yellow-500" />
          </div>
        </div>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <div className="bg-white rounded-xl shadow-lg p-6">
          <h3 className="text-lg font-semibold mb-4">Recent Bookings</h3>
          <div className="space-y-3">
            {[
              { id: '001', customer: 'John Doe', provider: 'Sarah Wilson', service: 'Dog Grooming', amount: '$65' },
              { id: '002', customer: 'Jane Smith', provider: 'Mike Johnson', service: 'Personal Training', amount: '$80' },
              { id: '003', customer: 'Bob Wilson', provider: 'Emily Chen', service: 'Piano Lessons', amount: '$50' }
            ].map((booking) => (
              <div key={booking.id} className="flex items-center justify-between p-3 bg-gray-50 rounded-lg">
                <div>
                  <p className="font-medium">#{booking.id} - {booking.customer}</p>
                  <p className="text-sm text-gray-600">{booking.service} with {booking.provider}</p>
                </div>
                <span className="font-semibold text-green-600">{booking.amount}</span>
              </div>
            ))}
          </div>
        </div>

        <div className="bg-white rounded-xl shadow-lg p-6">
          <h3 className="text-lg font-semibold mb-4">Top Providers</h3>
          <div className="space-y-3">
            {[
              { name: 'Sarah Wilson', service: 'Dog Grooming', bookings: 45, revenue: '$2,925' },
              { name: 'Mike Johnson', service: 'Personal Training', bookings: 38, revenue: '$3,040' },
              { name: 'Emily Chen', service: 'Piano Lessons', bookings: 32, revenue: '$1,600' }
            ].map((provider, index) => (
              <div key={index} className="flex items-center justify-between p-3 bg-gray-50 rounded-lg">
                <div>
                  <p className="font-medium">{provider.name}</p>
                  <p className="text-sm text-gray-600">{provider.service} • {provider.bookings} bookings</p>
                </div>
                <span className="font-semibold text-green-600">{provider.revenue}</span>
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  );

  // My Bookings Component
  const MyBookings = () => (
    <div className="space-y-6">
      <h2 className="text-2xl font-bold text-gray-900">My Bookings</h2>
      
      <div className="space-y-4">
        {bookings.length === 0 ? (
          <div className="text-center py-12 bg-white rounded-xl shadow-lg">
            <Calendar className="h-12 w-12 text-gray-400 mx-auto mb-4" />
            <p className="text-gray-600">No bookings yet. Browse services to make your first booking!</p>
            <button
              onClick={() => setCurrentView('browse-services')}
              className="mt-4 bg-blue-600 text-white px-6 py-2 rounded-lg hover:bg-blue-700 transition-colors"
            >
              Browse Services
            </button>
          </div>
        ) : (
          bookings.map((booking) => (
            <div key={booking.id} className="bg-white rounded-xl shadow-lg p-6">
              <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
                <div className="flex-1">
                  <h3 className="text-lg font-semibold text-gray-900">{booking.service.name}</h3>
                  <p className="text-gray-600">with {booking.service.provider}</p>
                  <div className="flex items-center gap-4 mt-2 text-sm text-gray-500">
                    <div className="flex items-center gap-1">
                      <Calendar className="h-4 w-4" />
                      {booking.date.toLocaleDateString()}
                    </div>
                    <div className="flex items-center gap-1">
                      <Clock className="h-4 w-4" />
                      {booking.time}
                    </div>
                    <div className="flex items-center gap-1">
                      <DollarSign className="h-4 w-4" />
                      ${booking.service.price}
                    </div>
                  </div>
                </div>
                <div className="flex items-center gap-2">
                  <span className={`px-3 py-1 rounded-full text-sm ${
                    booking.status === 'confirmed' 
                      ? 'bg-green-100 text-green-800' 
                      : 'bg-yellow-100 text-yellow-800'
                  }`}>
                    {booking.status}
                  </span>
                  <button className="text-red-600 hover:text-red-700 p-2">
                    <Trash2 className="h-4 w-4" />
                  </button>
                </div>
              </div>
            </div>
          ))
        )}
      </div>
    </div>
  );

  // Main Layout
  const MainLayout = ({ children }) => (
    <div className="min-h-screen bg-gray-50">
      <Header />
      <MobileMenu />
      
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <div className="lg:grid lg:grid-cols-4 lg:gap-8">
          {/* Sidebar */}
          <div className="hidden lg:block lg:col-span-1">
            <div className="bg-white rounded-xl shadow-lg p-6 sticky top-8">
              <NavigationItems />
            </div>
          </div>
          
          {/* Main Content */}
          <div className="lg:col-span-3">
            {children}
          </div>
        </div>
      </div>
    </div>
  );

  // Render based on current view
  if (currentView === 'login') {
    return <LoginForm />;
  }

  const renderCurrentView = () => {
    switch (currentView) {
      case 'customer-dashboard':
      case 'browse-services':
        return <ServiceBrowser />;
      case 'booking':
        return <BookingInterface />;
      case 'my-bookings':
        return <MyBookings />;
      case 'provider-dashboard':
      case 'provider-calendar':
      case 'provider-services':
      case 'provider-earnings':
      case 'provider-notifications':
        return <ProviderDashboard />;
      case 'admin':
      case 'admin-users':
      case 'admin-bookings':
      case 'admin-revenue':
      case 'admin-settings':
        return <AdminDashboard />;
      default:
        return <ServiceBrowser />;
    }
  };

  return (
    <MainLayout>
      {renderCurrentView()}
    </MainLayout>
  );
};

export default BookingSaaS;
