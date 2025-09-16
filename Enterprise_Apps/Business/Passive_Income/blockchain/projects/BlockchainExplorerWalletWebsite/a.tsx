import React, { useState, useEffect, useRef } from 'react';
import { Wallet, Activity, BarChart3, Globe, Zap, ArrowUpRight, ArrowDownLeft, Copy, ExternalLink, Settings, Search, Plus, Minus } from 'lucide-react';

const BlockchainExplorer = () => {
  const [activeTab, setActiveTab] = useState('explorer');
  const [selectedTransaction, setSelectedTransaction] = useState(null);
  const [walletBalance, setWalletBalance] = useState(12.5847);
  const [isConnected, setIsConnected] = useState(false);
  const [networkNodes, setNetworkNodes] = useState([]);
  const canvasRef = useRef(null);
  const particlesRef = useRef(null);

  // Mock data
  const blockchainStats = {
    blockHeight: 847293,
    hashRate: '320.5 EH/s',
    difficulty: '48.71T',
    mempool: 15420,
    networkNodes: 15847
  };

  const recentTransactions = [
    {
      id: '0x1a2b3c...',
      from: '0x742d35...',
      to: '0x8f9e1a...',
      amount: '2.45 ETH',
      status: 'confirmed',
      timestamp: '2 min ago',
      fee: '0.0021 ETH'
    },
    {
      id: '0x4d5e6f...',
      from: '0x123abc...',
      to: '0x789def...',
      amount: '0.8 ETH',
      status: 'pending',
      timestamp: '5 min ago',
      fee: '0.0018 ETH'
    },
    {
      id: '0x7g8h9i...',
      from: '0x456ghi...',
      to: '0x012jkl...',
      amount: '15.2 ETH',
      status: 'confirmed',
      timestamp: '8 min ago',
      fee: '0.0035 ETH'
    }
  ];

  const walletAssets = [
    { symbol: 'ETH', name: 'Ethereum', balance: '12.5847', value: '$24,657.82', change: '+5.2%' },
    { symbol: 'BTC', name: 'Bitcoin', balance: '0.3421', value: '$15,892.44', change: '+2.8%' },
    { symbol: 'USDC', name: 'USD Coin', balance: '5,420.50', value: '$5,420.50', change: '0.0%' }
  ];

  // Particle animation effect
  useEffect(() => {
    const canvas = particlesRef.current;
    if (!canvas) return;

    const ctx = canvas.getContext('2d');
    canvas.width = window.innerWidth;
    canvas.height = window.innerHeight;

    const particles = [];
    const particleCount = 100;

    for (let i = 0; i < particleCount; i++) {
      particles.push({
        x: Math.random() * canvas.width,
        y: Math.random() * canvas.height,
        vx: (Math.random() - 0.5) * 0.5,
        vy: (Math.random() - 0.5) * 0.5,
        radius: Math.random() * 2 + 1,
        opacity: Math.random() * 0.5 + 0.1
      });
    }

    function animate() {
      ctx.clearRect(0, 0, canvas.width, canvas.height);
      
      particles.forEach(particle => {
        particle.x += particle.vx;
        particle.y += particle.vy;
        
        if (particle.x < 0 || particle.x > canvas.width) particle.vx *= -1;
        if (particle.y < 0 || particle.y > canvas.height) particle.vy *= -1;
        
        ctx.beginPath();
        ctx.arc(particle.x, particle.y, particle.radius, 0, Math.PI * 2);
        ctx.fillStyle = `rgba(59, 130, 246, ${particle.opacity})`;
        ctx.fill();
      });
      
      requestAnimationFrame(animate);
    }
    
    animate();

    const handleResize = () => {
      canvas.width = window.innerWidth;
      canvas.height = window.innerHeight;
    };

    window.addEventListener('resize', handleResize);
    return () => window.removeEventListener('resize', handleResize);
  }, []);

  // Blockchain visualization
  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;

    const ctx = canvas.getContext('2d');
    canvas.width = canvas.offsetWidth;
    canvas.height = canvas.offsetHeight;

    const blocks = [];
    const blockCount = 10;
    const blockSize = 60;
    const spacing = 20;

    for (let i = 0; i < blockCount; i++) {
      blocks.push({
        x: i * (blockSize + spacing) + 50,
        y: canvas.height / 2 - blockSize / 2,
        width: blockSize,
        height: blockSize,
        hash: `Block ${847293 - i}`,
        glow: Math.random() * 0.5 + 0.5
      });
    }

    function drawBlock(block, index) {
      const gradient = ctx.createLinearGradient(block.x, block.y, block.x, block.y + block.height);
      gradient.addColorStop(0, '#6366f1');
      gradient.addColorStop(1, '#8b5cf6');
      
      // Glow effect
      ctx.shadowColor = '#6366f1';
      ctx.shadowBlur = 15 * block.glow;
      
      ctx.fillStyle = gradient;
      ctx.fillRect(block.x, block.y, block.width, block.height);
      
      ctx.shadowBlur = 0;
      
      // Block text
      ctx.fillStyle = '#ffffff';
      ctx.font = '10px monospace';
      ctx.textAlign = 'center';
      ctx.fillText(block.hash, block.x + block.width/2, block.y + block.height/2 + 3);
      
      // Connection line to next block
      if (index < blocks.length - 1) {
        ctx.strokeStyle = '#6366f1';
        ctx.lineWidth = 2;
        ctx.setLineDash([5, 5]);
        ctx.beginPath();
        ctx.moveTo(block.x + block.width, block.y + block.height/2);
        ctx.lineTo(block.x + block.width + spacing, block.y + block.height/2);
        ctx.stroke();
        ctx.setLineDash([]);
      }
    }

    function animate() {
      ctx.clearRect(0, 0, canvas.width, canvas.height);
      
      blocks.forEach((block, index) => {
        block.glow = Math.sin(Date.now() * 0.003 + index) * 0.3 + 0.7;
        drawBlock(block, index);
      });
      
      requestAnimationFrame(animate);
    }
    
    animate();
  }, [activeTab]);

  const StatCard = ({ title, value, icon: Icon, trend, glowing = false }) => (
    <div className={`bg-gray-800/50 backdrop-blur-sm rounded-xl p-6 border border-gray-700/50 hover:border-blue-500/50 transition-all duration-300 ${glowing ? 'shadow-lg shadow-blue-500/20' : ''} group`}>
      <div className="flex items-center justify-between mb-4">
        <div className={`p-3 rounded-lg ${glowing ? 'bg-blue-500/20' : 'bg-gray-700/50'} group-hover:bg-blue-500/30 transition-colors`}>
          <Icon className={`w-6 h-6 ${glowing ? 'text-blue-400' : 'text-gray-300'}`} />
        </div>
        {trend && (
          <span className={`text-sm ${trend.startsWith('+') ? 'text-green-400' : 'text-red-400'}`}>
            {trend}
          </span>
        )}
      </div>
      <h3 className="text-gray-400 text-sm mb-1">{title}</h3>
      <p className="text-white text-2xl font-bold">{value}</p>
    </div>
  );

  const TransactionRow = ({ tx }) => (
    <div 
      className="flex items-center justify-between p-4 bg-gray-800/30 rounded-lg border border-gray-700/30 hover:border-blue-500/50 hover:bg-gray-800/50 transition-all duration-300 cursor-pointer group"
      onClick={() => setSelectedTransaction(tx)}
    >
      <div className="flex items-center space-x-4">
        <div className={`p-2 rounded-full ${tx.status === 'confirmed' ? 'bg-green-500/20 text-green-400' : 'bg-yellow-500/20 text-yellow-400'}`}>
          {tx.status === 'confirmed' ? <ArrowUpRight className="w-4 h-4" /> : <Zap className="w-4 h-4" />}
        </div>
        <div>
          <p className="text-white font-mono text-sm">{tx.id}</p>
          <p className="text-gray-400 text-xs">{tx.timestamp}</p>
        </div>
      </div>
      <div className="text-right">
        <p className="text-white font-semibold">{tx.amount}</p>
        <p className="text-gray-400 text-xs">Fee: {tx.fee}</p>
      </div>
      <ExternalLink className="w-4 h-4 text-gray-400 group-hover:text-blue-400 transition-colors" />
    </div>
  );

  const AssetRow = ({ asset }) => (
    <div className="flex items-center justify-between p-4 bg-gray-800/30 rounded-lg border border-gray-700/30 hover:border-blue-500/50 hover:bg-gray-800/50 transition-all duration-300">
      <div className="flex items-center space-x-4">
        <div className="w-10 h-10 bg-gradient-to-br from-blue-500 to-purple-600 rounded-full flex items-center justify-center">
          <span className="text-white font-bold text-sm">{asset.symbol}</span>
        </div>
        <div>
          <p className="text-white font-semibold">{asset.name}</p>
          <p className="text-gray-400 text-sm">{asset.balance} {asset.symbol}</p>
        </div>
      </div>
      <div className="text-right">
        <p className="text-white font-semibold">{asset.value}</p>
        <p className={`text-sm ${asset.change.startsWith('+') ? 'text-green-400' : asset.change.startsWith('-') ? 'text-red-400' : 'text-gray-400'}`}>
          {asset.change}
        </p>
      </div>
    </div>
  );

  return (
    <div className="min-h-screen bg-gradient-to-br from-gray-900 via-blue-900/20 to-purple-900/20 text-white relative overflow-hidden">
      {/* Particle Background */}
      <canvas 
        ref={particlesRef}
        className="fixed inset-0 pointer-events-none z-0"
      />
      
      {/* Main Content */}
      <div className="relative z-10">
        {/* Header */}
        <header className="bg-gray-900/80 backdrop-blur-md border-b border-gray-700/50 sticky top-0 z-50">
          <div className="max-w-7xl mx-auto px-6 py-4">
            <div className="flex items-center justify-between">
              <div className="flex items-center space-x-8">
                <div className="flex items-center space-x-3">
                  <div className="w-8 h-8 bg-gradient-to-br from-blue-500 to-purple-600 rounded-lg flex items-center justify-center">
                    <Activity className="w-5 h-5 text-white" />
                  </div>
                  <h1 className="text-xl font-bold bg-gradient-to-r from-blue-400 to-purple-400 bg-clip-text text-transparent">
                    BlockExplorer
                  </h1>
                </div>
                
                <nav className="flex space-x-6">
                  <button
                    onClick={() => setActiveTab('explorer')}
                    className={`px-4 py-2 rounded-lg transition-all duration-300 ${
                      activeTab === 'explorer' 
                        ? 'bg-blue-500/20 text-blue-400 border border-blue-500/50' 
                        : 'text-gray-400 hover:text-white'
                    }`}
                  >
                    Explorer
                  </button>
                  <button
                    onClick={() => setActiveTab('wallet')}
                    className={`px-4 py-2 rounded-lg transition-all duration-300 ${
                      activeTab === 'wallet' 
                        ? 'bg-blue-500/20 text-blue-400 border border-blue-500/50' 
                        : 'text-gray-400 hover:text-white'
                    }`}
                  >
                    Wallet
                  </button>
                  <button
                    onClick={() => setActiveTab('network')}
                    className={`px-4 py-2 rounded-lg transition-all duration-300 ${
                      activeTab === 'network' 
                        ? 'bg-blue-500/20 text-blue-400 border border-blue-500/50' 
                        : 'text-gray-400 hover:text-white'
                    }`}
                  >
                    Network
                  </button>
                </nav>
              </div>
              
              <div className="flex items-center space-x-4">
                <div className="relative">
                  <Search className="w-5 h-5 text-gray-400 absolute left-3 top-1/2 transform -translate-y-1/2" />
                  <input
                    type="text"
                    placeholder="Search transactions, blocks..."
                    className="bg-gray-800/50 border border-gray-700/50 rounded-lg pl-10 pr-4 py-2 text-white placeholder-gray-400 focus:outline-none focus:border-blue-500/50 focus:bg-gray-800/70 transition-all"
                  />
                </div>
                
                <button
                  onClick={() => setIsConnected(!isConnected)}
                  className={`px-4 py-2 rounded-lg border transition-all duration-300 ${
                    isConnected 
                      ? 'bg-green-500/20 border-green-500/50 text-green-400' 
                      : 'bg-blue-500/20 border-blue-500/50 text-blue-400 hover:bg-blue-500/30'
                  }`}
                >
                  <Wallet className="w-4 h-4 inline mr-2" />
                  {isConnected ? 'Connected' : 'Connect Wallet'}
                </button>
              </div>
            </div>
          </div>
        </header>

        {/* Explorer Tab */}
        {activeTab === 'explorer' && (
          <div className="max-w-7xl mx-auto px-6 py-8">
            {/* Blockchain Visualization */}
            <div className="mb-8">
              <h2 className="text-2xl font-bold mb-6">Live Blockchain</h2>
              <div className="bg-gray-800/30 rounded-xl border border-gray-700/50 p-6 overflow-x-auto">
                <canvas 
                  ref={canvasRef}
                  className="w-full h-32"
                />
              </div>
            </div>

            {/* Stats Grid */}
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-5 gap-6 mb-8">
              <StatCard 
                title="Block Height" 
                value={blockchainStats.blockHeight.toLocaleString()} 
                icon={BarChart3}
                glowing={true}
              />
              <StatCard 
                title="Hash Rate" 
                value={blockchainStats.hashRate} 
                icon={Zap}
              />
              <StatCard 
                title="Difficulty" 
                value={blockchainStats.difficulty} 
                icon={Activity}
              />
              <StatCard 
                title="Mempool" 
                value={blockchainStats.mempool.toLocaleString()} 
                icon={Globe}
                trend="+12"
              />
              <StatCard 
                title="Network Nodes" 
                value={blockchainStats.networkNodes.toLocaleString()} 
                icon={Globe}
                trend="+5"
              />
            </div>

            {/* Recent Transactions */}
            <div className="bg-gray-800/30 rounded-xl border border-gray-700/50 p-6">
              <h3 className="text-xl font-bold mb-6">Recent Transactions</h3>
              <div className="space-y-4">
                {recentTransactions.map((tx, index) => (
                  <TransactionRow key={index} tx={tx} />
                ))}
              </div>
            </div>
          </div>
        )}

        {/* Wallet Tab */}
        {activeTab === 'wallet' && (
          <div className="max-w-7xl mx-auto px-6 py-8">
            {/* Wallet Overview */}
            <div className="mb-8">
              <div className="bg-gradient-to-r from-blue-600/20 to-purple-600/20 rounded-xl border border-blue-500/30 p-8 backdrop-blur-sm">
                <div className="flex items-center justify-between mb-6">
                  <h2 className="text-3xl font-bold">Portfolio Balance</h2>
                  <Settings className="w-6 h-6 text-gray-400 hover:text-white cursor-pointer transition-colors" />
                </div>
                <div className="flex items-center space-x-8">
                  <div>
                    <p className="text-4xl font-bold bg-gradient-to-r from-blue-400 to-purple-400 bg-clip-text text-transparent">
                      ${(walletBalance * 1965.43).toLocaleString('en-US', { minimumFractionDigits: 2 })}
                    </p>
                    <p className="text-gray-400 mt-1">
                      {walletBalance} ETH
                    </p>
                  </div>
                  <div className="flex space-x-4">
                    <button className="bg-blue-500 hover:bg-blue-600 px-6 py-3 rounded-lg font-semibold transition-colors flex items-center space-x-2">
                      <Plus className="w-4 h-4" />
                      <span>Send</span>
                    </button>
                    <button className="bg-green-500 hover:bg-green-600 px-6 py-3 rounded-lg font-semibold transition-colors flex items-center space-x-2">
                      <ArrowDownLeft className="w-4 h-4" />
                      <span>Receive</span>
                    </button>
                  </div>
                </div>
              </div>
            </div>

            {/* Assets */}
            <div className="bg-gray-800/30 rounded-xl border border-gray-700/50 p-6">
              <h3 className="text-xl font-bold mb-6">Your Assets</h3>
              <div className="space-y-4">
                {walletAssets.map((asset, index) => (
                  <AssetRow key={index} asset={asset} />
                ))}
              </div>
            </div>
          </div>
        )}

        {/* Network Tab */}
        {activeTab === 'network' && (
          <div className="max-w-7xl mx-auto px-6 py-8">
            <div className="bg-gray-800/30 rounded-xl border border-gray-700/50 p-6">
              <h3 className="text-xl font-bold mb-6">Network Topology</h3>
              <div className="h-96 bg-gray-900/50 rounded-lg flex items-center justify-center border border-gray-700/30">
                <div className="text-center">
                  <Globe className="w-16 h-16 text-blue-400 mx-auto mb-4 animate-pulse" />
                  <p className="text-gray-400">Network visualization coming soon...</p>
                  <p className="text-sm text-gray-500 mt-2">Interactive node topology with real-time connections</p>
                </div>
              </div>
            </div>
          </div>
        )}
      </div>

      {/* Transaction Modal */}
      {selectedTransaction && (
        <div className="fixed inset-0 bg-black/50 backdrop-blur-sm z-50 flex items-center justify-center p-4">
          <div className="bg-gray-800 rounded-xl border border-gray-700 p-6 max-w-lg w-full max-h-96 overflow-y-auto">
            <div className="flex items-center justify-between mb-6">
              <h3 className="text-xl font-bold">Transaction Details</h3>
              <button 
                onClick={() => setSelectedTransaction(null)}
                className="text-gray-400 hover:text-white transition-colors"
              >
                <Minus className="w-5 h-5" />
              </button>
            </div>
            
            <div className="space-y-4">
              <div>
                <label className="text-gray-400 text-sm block mb-1">Transaction Hash</label>
                <div className="flex items-center space-x-2">
                  <code className="text-blue-400 font-mono text-sm">{selectedTransaction.id}</code>
                  <Copy className="w-4 h-4 text-gray-400 hover:text-white cursor-pointer transition-colors" />
                </div>
              </div>
              
              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="text-gray-400 text-sm block mb-1">From</label>
                  <code className="text-white font-mono text-sm">{selectedTransaction.from}</code>
                </div>
                <div>
                  <label className="text-gray-400 text-sm block mb-1">To</label>
                  <code className="text-white font-mono text-sm">{selectedTransaction.to}</code>
                </div>
              </div>
              
              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="text-gray-400 text-sm block mb-1">Amount</label>
                  <p className="text-white font-semibold">{selectedTransaction.amount}</p>
                </div>
                <div>
                  <label className="text-gray-400 text-sm block mb-1">Fee</label>
                  <p className="text-white">{selectedTransaction.fee}</p>
                </div>
              </div>
              
              <div>
                <label className="text-gray-400 text-sm block mb-1">Status</label>
                <span className={`inline-flex items-center px-3 py-1 rounded-full text-sm ${
                  selectedTransaction.status === 'confirmed' 
                    ? 'bg-green-500/20 text-green-400' 
                    : 'bg-yellow-500/20 text-yellow-400'
                }`}>
                  {selectedTransaction.status}
                </span>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default BlockchainExplorer;
