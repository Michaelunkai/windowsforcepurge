import React, { useState, useEffect, useRef } from 'react';
import { LineChart, Line, XAxis, YAxis, ResponsiveContainer, AreaChart, Area } from 'recharts';
import { TrendingUp, TrendingDown, Play, Pause, Settings, Bell, User, Search, Menu, X, Plus, Minus, BarChart3, PieChart, Wallet, RefreshCw } from 'lucide-react';

const CryptoTradingPlatform = () => {
  const [selectedCrypto, setSelectedCrypto] = useState('BTC');
  const [isPlaying, setIsPlaying] = useState(true);
  const [showOrderModal, setShowOrderModal] = useState(false);
  const [orderType, setOrderType] = useState('buy');
  const [chartData, setChartData] = useState([]);
  const [currentPrices, setCurrentPrices] = useState({
    BTC: 45250.00,
    ETH: 3150.50,
    ADA: 0.485,
    SOL: 125.75,
    DOT: 8.95,
    AVAX: 28.50
  });
  
  const [portfolio, setPortfolio] = useState({
    BTC: { amount: 0.5, value: 22625 },
    ETH: { amount: 2.3, value: 7246.15 },
    ADA: { amount: 1500, value: 727.5 },
    SOL: { amount: 8, value: 1006 }
  });

  const cryptoList = [
    { symbol: 'BTC', name: 'Bitcoin', icon: '₿' },
    { symbol: 'ETH', name: 'Ethereum', icon: 'Ξ' },
    { symbol: 'ADA', name: 'Cardano', icon: '₳' },
    { symbol: 'SOL', name: 'Solana', icon: '◎' },
    { symbol: 'DOT', name: 'Polkadot', icon: '●' },
    { symbol: 'AVAX', name: 'Avalanche', icon: '▲' }
  ];

  // Generate initial chart data
  useEffect(() => {
    const generateChartData = () => {
      const data = [];
      const basePrice = currentPrices[selectedCrypto];
      for (let i = 0; i < 50; i++) {
        const timestamp = new Date(Date.now() - (49 - i) * 1000 * 60).toLocaleTimeString();
        const variation = (Math.random() - 0.5) * 0.02;
        const price = basePrice * (1 + variation);
        data.push({
          time: timestamp,
          price: price,
          volume: Math.random() * 1000000
        });
      }
      return data;
    };
    setChartData(generateChartData());
  }, [selectedCrypto, currentPrices]);

  // Simulate real-time price updates
  useEffect(() => {
    if (!isPlaying) return;
    
    const interval = setInterval(() => {
      setCurrentPrices(prev => {
        const updated = { ...prev };
        Object.keys(updated).forEach(crypto => {
          const variation = (Math.random() - 0.5) * 0.005;
          updated[crypto] = Math.max(0.01, updated[crypto] * (1 + variation));
        });
        return updated;
      });

      setChartData(prev => {
        const newData = [...prev];
        const lastPrice = newData[newData.length - 1]?.price || currentPrices[selectedCrypto];
        const variation = (Math.random() - 0.5) * 0.01;
        const newPrice = lastPrice * (1 + variation);
        
        newData.push({
          time: new Date().toLocaleTimeString(),
          price: newPrice,
          volume: Math.random() * 1000000
        });
        
        if (newData.length > 50) newData.shift();
        return newData;
      });
    }, 2000);

    return () => clearInterval(interval);
  }, [isPlaying, selectedCrypto, currentPrices]);

  const formatPrice = (price) => {
    if (price < 1) return price.toFixed(4);
    if (price < 100) return price.toFixed(2);
    return price.toLocaleString('en-US', { 
      style: 'currency', 
      currency: 'USD',
      minimumFractionDigits: 2,
      maximumFractionDigits: 2
    });
  };

  const getPriceChange = (current, previous = current * 0.98) => {
    const change = current - previous;
    const percentage = (change / previous) * 100;
    return { change, percentage };
  };

  const OrderModal = () => (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
      <div className="bg-gray-900 rounded-lg p-6 w-96 border border-gray-700">
        <div className="flex justify-between items-center mb-4">
          <h3 className="text-xl font-bold text-white">
            {orderType === 'buy' ? 'Buy' : 'Sell'} {selectedCrypto}
          </h3>
          <button 
            onClick={() => setShowOrderModal(false)}
            className="text-gray-400 hover:text-white"
          >
            <X size={20} />
          </button>
        </div>
        
        <div className="space-y-4">
          <div className="flex space-x-2">
            <button 
              onClick={() => setOrderType('buy')}
              className={`flex-1 py-2 rounded ${orderType === 'buy' ? 'bg-green-600' : 'bg-gray-700'} text-white`}
            >
              Buy
            </button>
            <button 
              onClick={() => setOrderType('sell')}
              className={`flex-1 py-2 rounded ${orderType === 'sell' ? 'bg-red-600' : 'bg-gray-700'} text-white`}
            >
              Sell
            </button>
          </div>
          
          <div>
            <label className="block text-gray-400 mb-2">Amount</label>
            <input 
              type="number" 
              placeholder="0.00"
              className="w-full bg-gray-800 text-white p-3 rounded border border-gray-600 focus:border-blue-500"
            />
          </div>
          
          <div>
            <label className="block text-gray-400 mb-2">Price</label>
            <input 
              type="number" 
              placeholder={formatPrice(currentPrices[selectedCrypto])}
              className="w-full bg-gray-800 text-white p-3 rounded border border-gray-600 focus:border-blue-500"
            />
          </div>
          
          <button className={`w-full py-3 rounded font-semibold ${
            orderType === 'buy' ? 'bg-green-600 hover:bg-green-700' : 'bg-red-600 hover:bg-red-700'
          } text-white transition-colors`}>
            Place {orderType === 'buy' ? 'Buy' : 'Sell'} Order
          </button>
        </div>
      </div>
    </div>
  );

  const PriceTicker = () => (
    <div className="bg-gray-900 border-b border-gray-700 overflow-hidden">
      <div className="flex space-x-8 animate-pulse">
        {cryptoList.map(crypto => {
          const price = currentPrices[crypto.symbol];
          const change = getPriceChange(price);
          const isPositive = change.percentage >= 0;
          
          return (
            <div 
              key={crypto.symbol}
              className="flex items-center space-x-3 py-3 px-4 cursor-pointer hover:bg-gray-800 transition-colors"
              onClick={() => setSelectedCrypto(crypto.symbol)}
            >
              <span className="text-2xl">{crypto.icon}</span>
              <div>
                <div className="flex items-center space-x-2">
                  <span className="text-white font-semibold">{crypto.symbol}</span>
                  <span className="text-gray-400 text-sm">{crypto.name}</span>
                </div>
                <div className="flex items-center space-x-2">
                  <span className="text-white">{formatPrice(price)}</span>
                  <div className={`flex items-center space-x-1 ${isPositive ? 'text-green-400' : 'text-red-400'}`}>
                    {isPositive ? <TrendingUp size={12} /> : <TrendingDown size={12} />}
                    <span className="text-sm">{Math.abs(change.percentage).toFixed(2)}%</span>
                  </div>
                </div>
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );

  const TradingChart = () => (
    <div className="bg-gray-900 rounded-lg border border-gray-700 p-4">
      <div className="flex justify-between items-center mb-4">
        <div className="flex items-center space-x-4">
          <h2 className="text-xl font-bold text-white">
            {cryptoList.find(c => c.symbol === selectedCrypto)?.icon} {selectedCrypto}/USD
          </h2>
          <div className="flex items-center space-x-2">
            <span className="text-2xl text-white">{formatPrice(currentPrices[selectedCrypto])}</span>
            <div className="flex items-center space-x-1 text-green-400">
              <TrendingUp size={16} />
              <span>+2.45%</span>
            </div>
          </div>
        </div>
        
        <div className="flex items-center space-x-2">
          <button 
            onClick={() => setIsPlaying(!isPlaying)}
            className="bg-gray-800 hover:bg-gray-700 p-2 rounded"
          >
            {isPlaying ? <Pause className="text-white" size={16} /> : <Play className="text-white" size={16} />}
          </button>
          <button className="bg-gray-800 hover:bg-gray-700 p-2 rounded">
            <Settings className="text-white" size={16} />
          </button>
        </div>
      </div>
      
      <div style={{ height: '400px' }}>
        <ResponsiveContainer width="100%" height="100%">
          <AreaChart data={chartData}>
            <defs>
              <linearGradient id="priceGradient" x1="0" y1="0" x2="0" y2="1">
                <stop offset="5%" stopColor="#10B981" stopOpacity={0.3}/>
                <stop offset="95%" stopColor="#10B981" stopOpacity={0}/>
              </linearGradient>
            </defs>
            <XAxis 
              dataKey="time" 
              axisLine={false}
              tickLine={false}
              tick={{ fill: '#9CA3AF', fontSize: 12 }}
            />
            <YAxis 
              domain={['dataMin', 'dataMax']}
              axisLine={false}
              tickLine={false}
              tick={{ fill: '#9CA3AF', fontSize: 12 }}
              tickFormatter={(value) => formatPrice(value)}
            />
            <Area
              type="monotone"
              dataKey="price"
              stroke="#10B981"
              strokeWidth={2}
              fill="url(#priceGradient)"
              animationDuration={1000}
            />
          </AreaChart>
        </ResponsiveContainer>
      </div>
    </div>
  );

  const OrderBook = () => (
    <div className="bg-gray-900 rounded-lg border border-gray-700 p-4">
      <h3 className="text-lg font-semibold text-white mb-4">Order Book</h3>
      
      <div className="space-y-2">
        <div className="grid grid-cols-3 text-gray-400 text-sm font-medium">
          <span>Price (USD)</span>
          <span className="text-right">Amount</span>
          <span className="text-right">Total</span>
        </div>
        
        {/* Sell Orders */}
        {Array.from({ length: 5 }).map((_, i) => {
          const price = currentPrices[selectedCrypto] * (1 + (i + 1) * 0.001);
          const amount = Math.random() * 10;
          return (
            <div key={`sell-${i}`} className="grid grid-cols-3 text-sm text-red-400">
              <span>{formatPrice(price)}</span>
              <span className="text-right">{amount.toFixed(4)}</span>
              <span className="text-right">{formatPrice(price * amount)}</span>
            </div>
          );
        })}
        
        <div className="border-t border-gray-700 my-2 pt-2">
          <div className="text-center text-white font-semibold">
            {formatPrice(currentPrices[selectedCrypto])}
          </div>
        </div>
        
        {/* Buy Orders */}
        {Array.from({ length: 5 }).map((_, i) => {
          const price = currentPrices[selectedCrypto] * (1 - (i + 1) * 0.001);
          const amount = Math.random() * 10;
          return (
            <div key={`buy-${i}`} className="grid grid-cols-3 text-sm text-green-400">
              <span>{formatPrice(price)}</span>
              <span className="text-right">{amount.toFixed(4)}</span>
              <span className="text-right">{formatPrice(price * amount)}</span>
            </div>
          );
        })}
      </div>
    </div>
  );

  const TradingPanel = () => (
    <div className="bg-gray-900 rounded-lg border border-gray-700 p-4">
      <div className="flex space-x-2 mb-4">
        <button 
          onClick={() => { setOrderType('buy'); setShowOrderModal(true); }}
          className="flex-1 bg-green-600 hover:bg-green-700 text-white py-3 rounded font-semibold transition-colors"
        >
          Buy {selectedCrypto}
        </button>
        <button 
          onClick={() => { setOrderType('sell'); setShowOrderModal(true); }}
          className="flex-1 bg-red-600 hover:bg-red-700 text-white py-3 rounded font-semibold transition-colors"
        >
          Sell {selectedCrypto}
        </button>
      </div>
      
      <div className="space-y-4">
        <div>
          <label className="block text-gray-400 mb-2">Quick Trade</label>
          <div className="grid grid-cols-4 gap-2">
            {['25%', '50%', '75%', '100%'].map(percent => (
              <button 
                key={percent}
                className="bg-gray-800 hover:bg-gray-700 text-white py-2 rounded text-sm transition-colors"
              >
                {percent}
              </button>
            ))}
          </div>
        </div>
        
        <div className="bg-gray-800 rounded p-3">
          <div className="flex justify-between text-sm">
            <span className="text-gray-400">Available Balance</span>
            <span className="text-white">$12,450.00</span>
          </div>
          <div className="flex justify-between text-sm mt-1">
            <span className="text-gray-400">Est. Fee</span>
            <span className="text-white">$2.50</span>
          </div>
        </div>
      </div>
    </div>
  );

  const Portfolio = () => {
    const totalValue = Object.values(portfolio).reduce((sum, asset) => sum + asset.value, 0);
    
    return (
      <div className="bg-gray-900 rounded-lg border border-gray-700 p-4">
        <div className="flex justify-between items-center mb-4">
          <h3 className="text-lg font-semibold text-white">Portfolio</h3>
          <div className="text-right">
            <div className="text-2xl font-bold text-white">${totalValue.toLocaleString()}</div>
            <div className="text-green-400 text-sm">+$1,234 (+4.2%)</div>
          </div>
        </div>
        
        <div className="space-y-3">
          {Object.entries(portfolio).map(([symbol, data]) => {
            const crypto = cryptoList.find(c => c.symbol === symbol);
            const currentPrice = currentPrices[symbol];
            const percentage = (data.value / totalValue) * 100;
            
            return (
              <div key={symbol} className="flex items-center justify-between p-3 bg-gray-800 rounded">
                <div className="flex items-center space-x-3">
                  <span className="text-xl">{crypto?.icon}</span>
                  <div>
                    <div className="text-white font-medium">{symbol}</div>
                    <div className="text-gray-400 text-sm">{data.amount} {symbol}</div>
                  </div>
                </div>
                <div className="text-right">
                  <div className="text-white font-medium">${data.value.toLocaleString()}</div>
                  <div className="text-gray-400 text-sm">{percentage.toFixed(1)}%</div>
                </div>
              </div>
            );
          })}
        </div>
      </div>
    );
  };

  return (
    <div className="min-h-screen bg-gray-950 text-white">
      {/* Header */}
      <header className="bg-gray-900 border-b border-gray-700 px-6 py-4">
        <div className="flex justify-between items-center">
          <div className="flex items-center space-x-6">
            <h1 className="text-2xl font-bold text-white">CryptoTrade Pro</h1>
            <nav className="hidden md:flex space-x-6">
              <button className="text-blue-400 hover:text-blue-300">Trade</button>
              <button className="text-gray-400 hover:text-white">Markets</button>
              <button className="text-gray-400 hover:text-white">Portfolio</button>
              <button className="text-gray-400 hover:text-white">Analytics</button>
            </nav>
          </div>
          
          <div className="flex items-center space-x-4">
            <div className="flex items-center space-x-2 bg-gray-800 rounded-lg px-3 py-2">
              <Search size={16} className="text-gray-400" />
              <input 
                type="text" 
                placeholder="Search assets..."
                className="bg-transparent text-white placeholder-gray-400 focus:outline-none"
              />
            </div>
            <button className="p-2 bg-gray-800 rounded-lg hover:bg-gray-700">
              <Bell size={16} className="text-gray-400" />
            </button>
            <button className="p-2 bg-gray-800 rounded-lg hover:bg-gray-700">
              <User size={16} className="text-gray-400" />
            </button>
          </div>
        </div>
      </header>

      {/* Price Ticker */}
      <PriceTicker />

      {/* Main Content */}
      <div className="p-6 grid grid-cols-1 lg:grid-cols-4 gap-6">
        {/* Chart Section */}
        <div className="lg:col-span-3 space-y-6">
          <TradingChart />
          
          {/* Trading Cards */}
          <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
            <div className="bg-gray-900 rounded-lg border border-gray-700 p-4">
              <div className="flex items-center space-x-3">
                <div className="p-3 bg-blue-600 rounded-lg">
                  <BarChart3 className="text-white" size={24} />
                </div>
                <div>
                  <div className="text-gray-400 text-sm">24h Volume</div>
                  <div className="text-white text-xl font-bold">$2.4B</div>
                </div>
              </div>
            </div>
            
            <div className="bg-gray-900 rounded-lg border border-gray-700 p-4">
              <div className="flex items-center space-x-3">
                <div className="p-3 bg-green-600 rounded-lg">
                  <TrendingUp className="text-white" size={24} />
                </div>
                <div>
                  <div className="text-gray-400 text-sm">Market Cap</div>
                  <div className="text-white text-xl font-bold">$847B</div>
                </div>
              </div>
            </div>
            
            <div className="bg-gray-900 rounded-lg border border-gray-700 p-4">
              <div className="flex items-center space-x-3">
                <div className="p-3 bg-purple-600 rounded-lg">
                  <PieChart className="text-white" size={24} />
                </div>
                <div>
                  <div className="text-gray-400 text-sm">Dominance</div>
                  <div className="text-white text-xl font-bold">42.3%</div>
                </div>
              </div>
            </div>
          </div>
        </div>

        {/* Side Panel */}
        <div className="space-y-6">
          <TradingPanel />
          <OrderBook />
          <Portfolio />
        </div>
      </div>

      {/* Order Modal */}
      {showOrderModal && <OrderModal />}
    </div>
  );
};

export default CryptoTradingPlatform;
