import React, { useState, useEffect } from 'react';
import { 
  Play, 
  Pause, 
  Square, 
  BarChart3, 
  Cpu, 
  FileText, 
  CloudUpload,
  X,
  Eye,
  Trash2,
  Settings,
  Beaker,
  Upload
} from 'lucide-react';
import { LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, AreaChart, Area } from 'recharts';

const MLTrainingPlatform = () => {
  const [activeTab, setActiveTab] = useState('dashboard');
  const [selectedExperiment, setSelectedExperiment] = useState(null);
  const [isTraining, setIsTraining] = useState(false);
  const [trainingProgress, setTrainingProgress] = useState(0);
  const [currentEpoch, setCurrentEpoch] = useState(0);
  const [showModal, setShowModal] = useState(false);
  const [dragOver, setDragOver] = useState(false);

  // Mock training data
  const [trainingData, setTrainingData] = useState([
    { epoch: 1, loss: 0.85, accuracy: 0.72, val_loss: 0.89, val_accuracy: 0.68 },
    { epoch: 2, loss: 0.72, accuracy: 0.78, val_loss: 0.76, val_accuracy: 0.74 },
    { epoch: 3, loss: 0.65, accuracy: 0.82, val_loss: 0.71, val_accuracy: 0.79 },
    { epoch: 4, loss: 0.58, accuracy: 0.85, val_loss: 0.68, val_accuracy: 0.81 },
    { epoch: 5, loss: 0.52, accuracy: 0.88, val_loss: 0.65, val_accuracy: 0.83 }
  ]);

  // Mock experiments data
  const experiments = [
    {
      id: 1,
      name: "ResNet-50 Classification",
      status: "completed",
      accuracy: 94.2,
      loss: 0.15,
      duration: "2h 34m",
      dataset: "ImageNet-1K",
      model: "ResNet-50",
      epochs: 100,
      created: "2025-07-19",
      parameters: 25600000
    },
    {
      id: 2,
      name: "BERT Fine-tuning",
      status: "training",
      accuracy: 87.6,
      loss: 0.42,
      duration: "45m",
      dataset: "GLUE-SST2",
      model: "BERT-Base",
      epochs: 50,
      created: "2025-07-20",
      parameters: 110000000
    },
    {
      id: 3,
      name: "GPT-2 Language Model",
      status: "failed",
      accuracy: 0,
      loss: 2.34,
      duration: "12m",
      dataset: "WikiText-103",
      model: "GPT-2-Small",
      epochs: 10,
      created: "2025-07-20",
      parameters: 124000000
    },
    {
      id: 4,
      name: "CNN Image Segmentation",
      status: "queued",
      accuracy: 0,
      loss: 0,
      duration: "0m",
      dataset: "COCO-2017",
      model: "U-Net",
      epochs: 75,
      created: "2025-07-20",
      parameters: 34500000
    }
  ];

  // Training simulation
  useEffect(() => {
    let interval;
    if (isTraining) {
      interval = setInterval(() => {
        setTrainingProgress(prev => {
          if (prev >= 100) {
            setIsTraining(false);
            return 100;
          }
          return prev + 2;
        });
        
        setCurrentEpoch(prev => Math.floor(trainingProgress / 2) + 1);
        
        // Add new training data point
        if (trainingProgress > 0 && trainingProgress % 20 === 0) {
          const newEpoch = trainingData.length + 1;
          const newPoint = {
            epoch: newEpoch,
            loss: Math.max(0.1, 0.85 - (newEpoch * 0.08) + Math.random() * 0.1),
            accuracy: Math.min(0.95, 0.72 + (newEpoch * 0.03) + Math.random() * 0.02),
            val_loss: Math.max(0.15, 0.89 - (newEpoch * 0.07) + Math.random() * 0.08),
            val_accuracy: Math.min(0.92, 0.68 + (newEpoch * 0.035) + Math.random() * 0.02)
          };
          setTrainingData(prev => [...prev, newPoint]);
        }
      }, 100);
    }
    return () => clearInterval(interval);
  }, [isTraining, trainingProgress, trainingData.length]);

  const startTraining = () => {
    setIsTraining(true);
    setTrainingProgress(0);
    setCurrentEpoch(0);
  };

  const stopTraining = () => {
    setIsTraining(false);
  };

  const getStatusColor = (status) => {
    switch (status) {
      case 'completed': return 'text-green-400';
      case 'training': return 'text-blue-400';
      case 'failed': return 'text-red-400';
      case 'queued': return 'text-yellow-400';
      default: return 'text-gray-400';
    }
  };

  const getStatusBg = (status) => {
    switch (status) {
      case 'completed': return 'bg-green-900/20 border-green-500/30';
      case 'training': return 'bg-blue-900/20 border-blue-500/30';
      case 'failed': return 'bg-red-900/20 border-red-500/30';
      case 'queued': return 'bg-yellow-900/20 border-yellow-500/30';
      default: return 'bg-gray-900/20 border-gray-500/30';
    }
  };

  const handleDragOver = (e) => {
    e.preventDefault();
    setDragOver(true);
  };

  const handleDragLeave = (e) => {
    e.preventDefault();
    setDragOver(false);
  };

  const handleDrop = (e) => {
    e.preventDefault();
    setDragOver(false);
    // Handle file upload logic here
    console.log('Files dropped:', e.dataTransfer.files);
  };

  const ModelDetailsModal = ({ experiment, onClose }) => {
    if (!experiment) return null;

    const modelConfig = `{
  "model_type": "${experiment.model}",
  "architecture": {
    "layers": 50,
    "input_shape": [224, 224, 3],
    "num_classes": 1000,
    "dropout": 0.5
  },
  "optimizer": {
    "type": "Adam",
    "learning_rate": 0.001,
    "beta1": 0.9,
    "beta2": 0.999
  },
  "training": {
    "batch_size": 32,
    "epochs": ${experiment.epochs},
    "validation_split": 0.2
  }
}`;

    return (
      <div className="fixed inset-0 bg-black/60 backdrop-blur-sm flex items-center justify-center z-50 p-4">
        <div className="bg-gray-900 rounded-2xl border border-gray-700 max-w-4xl w-full max-h-[90vh] overflow-y-auto">
          <div className="flex items-center justify-between p-6 border-b border-gray-700">
            <h2 className="text-2xl font-bold text-white">{experiment.name}</h2>
            <button
              onClick={onClose}
              className="text-gray-400 hover:text-white transition-colors"
            >
              <XMarkIcon className="w-6 h-6" />
            </button>
          </div>
          
          <div className="p-6 grid grid-cols-1 lg:grid-cols-2 gap-6">
            <div>
              <h3 className="text-lg font-semibold text-white mb-4">Experiment Details</h3>
              <div className="space-y-3">
                <div className="flex justify-between">
                  <span className="text-gray-400">Status</span>
                  <span className={`capitalize ${getStatusColor(experiment.status)}`}>
                    {experiment.status}
                  </span>
                </div>
                <div className="flex justify-between">
                  <span className="text-gray-400">Accuracy</span>
                  <span className="text-white">{experiment.accuracy}%</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-gray-400">Loss</span>
                  <span className="text-white">{experiment.loss}</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-gray-400">Duration</span>
                  <span className="text-white">{experiment.duration}</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-gray-400">Dataset</span>
                  <span className="text-white">{experiment.dataset}</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-gray-400">Parameters</span>
                  <span className="text-white">{experiment.parameters.toLocaleString()}</span>
                </div>
              </div>
            </div>
            
            <div>
              <h3 className="text-lg font-semibold text-white mb-4">Model Configuration</h3>
              <div className="bg-gray-800 rounded-lg p-4 overflow-x-auto">
                <pre className="text-green-400 text-sm font-mono whitespace-pre-wrap">
                  {modelConfig}
                </pre>
              </div>
            </div>
          </div>
          
          {experiment.status === 'completed' && (
            <div className="p-6 border-t border-gray-700">
              <h3 className="text-lg font-semibold text-white mb-4">Training Metrics</h3>
              <div className="h-64">
                <ResponsiveContainer width="100%" height="100%">
                  <LineChart data={trainingData}>
                    <CartesianGrid strokeDasharray="3 3" stroke="#374151" />
                    <XAxis dataKey="epoch" stroke="#9CA3AF" />
                    <YAxis stroke="#9CA3AF" />
                    <Tooltip 
                      contentStyle={{ 
                        backgroundColor: '#1F2937', 
                        border: '1px solid #374151',
                        borderRadius: '8px'
                      }}
                    />
                    <Line type="monotone" dataKey="accuracy" stroke="#10B981" strokeWidth={2} />
                    <Line type="monotone" dataKey="val_accuracy" stroke="#3B82F6" strokeWidth={2} />
                  </LineChart>
                </ResponsiveContainer>
              </div>
            </div>
          )}
        </div>
      </div>
    );
  };

  return (
    <div className="min-h-screen bg-gray-950 text-white">
      {/* Header */}
      <header className="bg-gray-900 border-b border-gray-800 px-6 py-4">
        <div className="flex items-center justify-between">
          <div className="flex items-center space-x-4">
            <div className="flex items-center space-x-2">
              <Beaker className="w-8 h-8 text-blue-400" />
              <h1 className="text-2xl font-bold bg-gradient-to-r from-blue-400 to-purple-500 bg-clip-text text-transparent">
                MLFlow Pro
              </h1>
            </div>
            <nav className="flex space-x-6 ml-8">
              {[
                { id: 'dashboard', label: 'Dashboard', icon: BarChart3 },
                { id: 'experiments', label: 'Experiments', icon: Beaker },
                { id: 'training', label: 'Training', icon: Cpu },
                { id: 'datasets', label: 'Datasets', icon: FileText }
              ].map(tab => (
                <button
                  key={tab.id}
                  onClick={() => setActiveTab(tab.id)}
                  className={`flex items-center space-x-2 px-4 py-2 rounded-lg transition-all ${
                    activeTab === tab.id 
                      ? 'bg-blue-600 text-white' 
                      : 'text-gray-400 hover:text-white hover:bg-gray-800'
                  }`}
                >
                  <tab.icon className="w-4 h-4" />
                  <span>{tab.label}</span>
                </button>
              ))}
            </nav>
          </div>
          
          <div className="flex items-center space-x-4">
            <button className="bg-blue-600 hover:bg-blue-700 px-4 py-2 rounded-lg font-medium transition-colors">
              New Experiment
            </button>
            <Settings className="w-6 h-6 text-gray-400 hover:text-white cursor-pointer transition-colors" />
          </div>
        </div>
      </header>

      <div className="flex">
        {/* Sidebar */}
        <aside className="w-64 bg-gray-900 border-r border-gray-800 min-h-[calc(100vh-73px)]">
          <div className="p-6">
            <h2 className="text-lg font-semibold mb-4">Quick Actions</h2>
            <div className="space-y-2">
              <button 
                onClick={startTraining}
                disabled={isTraining}
                className="w-full bg-green-600 hover:bg-green-700 disabled:bg-gray-700 disabled:cursor-not-allowed px-4 py-2 rounded-lg font-medium transition-colors flex items-center space-x-2"
              >
                <Play className="w-4 h-4" />
                <span>{isTraining ? 'Training...' : 'Start Training'}</span>
              </button>
              
              {isTraining && (
                <button 
                  onClick={stopTraining}
                  className="w-full bg-red-600 hover:bg-red-700 px-4 py-2 rounded-lg font-medium transition-colors flex items-center space-x-2"
                >
                  <Square className="w-4 h-4" />
                  <span>Stop Training</span>
                </button>
              )}
            </div>

            {isTraining && (
              <div className="mt-6">
                <h3 className="text-sm font-medium text-gray-400 mb-2">Training Progress</h3>
                <div className="bg-gray-800 rounded-lg p-4">
                  <div className="flex justify-between text-sm mb-2">
                    <span>Epoch {currentEpoch}/50</span>
                    <span>{trainingProgress.toFixed(0)}%</span>
                  </div>
                  <div className="w-full bg-gray-700 rounded-full h-2">
                    <div 
                      className="bg-gradient-to-r from-blue-500 to-purple-500 h-2 rounded-full transition-all duration-300"
                      style={{ width: `${trainingProgress}%` }}
                    />
                  </div>
                  <div className="text-xs text-gray-400 mt-2">
                    ETA: {Math.max(0, Math.ceil((100 - trainingProgress) / 2))}m remaining
                  </div>
                </div>
              </div>
            )}
          </div>
        </aside>

        {/* Main Content */}
        <main className="flex-1 p-6">
          {activeTab === 'dashboard' && (
            <div className="space-y-6">
              <div className="flex items-center justify-between">
                <h2 className="text-3xl font-bold">Dashboard</h2>
                <div className="text-sm text-gray-400">
                  Last updated: {new Date().toLocaleTimeString()}
                </div>
              </div>

              {/* Stats Cards */}
              <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
                {[
                  { label: 'Active Experiments', value: '3', change: '+12%', color: 'blue' },
                  { label: 'Avg Accuracy', value: '89.2%', change: '+5.3%', color: 'green' },
                  { label: 'Total Models', value: '47', change: '+8', color: 'purple' },
                  { label: 'GPU Hours', value: '1,243', change: '+156h', color: 'yellow' }
                ].map((stat, index) => (
                  <div key={index} className="bg-gray-900 border border-gray-800 rounded-xl p-6 hover:border-gray-700 transition-colors">
                    <div className="flex items-center justify-between">
                      <div>
                        <p className="text-gray-400 text-sm">{stat.label}</p>
                        <p className="text-2xl font-bold mt-1">{stat.value}</p>
                      </div>
                      <div className={`text-${stat.color}-400 text-sm font-medium`}>
                        {stat.change}
                      </div>
                    </div>
                  </div>
                ))}
              </div>

              {/* Training Metrics Chart */}
              <div className="bg-gray-900 border border-gray-800 rounded-xl p-6">
                <h3 className="text-xl font-semibold mb-4">Training Metrics</h3>
                <div className="h-64">
                  <ResponsiveContainer width="100%" height="100%">
                    <AreaChart data={trainingData}>
                      <defs>
                        <linearGradient id="colorAccuracy" x1="0" y1="0" x2="0" y2="1">
                          <stop offset="5%" stopColor="#10B981" stopOpacity={0.3}/>
                          <stop offset="95%" stopColor="#10B981" stopOpacity={0}/>
                        </linearGradient>
                        <linearGradient id="colorLoss" x1="0" y1="0" x2="0" y2="1">
                          <stop offset="5%" stopColor="#EF4444" stopOpacity={0.3}/>
                          <stop offset="95%" stopColor="#EF4444" stopOpacity={0}/>
                        </linearGradient>
                      </defs>
                      <CartesianGrid strokeDasharray="3 3" stroke="#374151" />
                      <XAxis dataKey="epoch" stroke="#9CA3AF" />
                      <YAxis stroke="#9CA3AF" />
                      <Tooltip 
                        contentStyle={{ 
                          backgroundColor: '#1F2937', 
                          border: '1px solid #374151',
                          borderRadius: '8px'
                        }}
                      />
                      <Area 
                        type="monotone" 
                        dataKey="accuracy" 
                        stroke="#10B981" 
                        fillOpacity={1} 
                        fill="url(#colorAccuracy)" 
                      />
                      <Area 
                        type="monotone" 
                        dataKey="loss" 
                        stroke="#EF4444" 
                        fillOpacity={1} 
                        fill="url(#colorLoss)" 
                      />
                    </AreaChart>
                  </ResponsiveContainer>
                </div>
              </div>
            </div>
          )}

          {activeTab === 'experiments' && (
            <div className="space-y-6">
              <div className="flex items-center justify-between">
                <h2 className="text-3xl font-bold">Experiments</h2>
                <button className="bg-blue-600 hover:bg-blue-700 px-4 py-2 rounded-lg font-medium transition-colors">
                  Create Experiment
                </button>
              </div>

              {/* Experiments Grid */}
              <div className="grid grid-cols-1 lg:grid-cols-2 xl:grid-cols-3 gap-6">
                {experiments.map(experiment => (
                  <div 
                    key={experiment.id}
                    className={`bg-gray-900 border rounded-xl p-6 hover:border-gray-600 transition-all cursor-pointer transform hover:scale-105 ${getStatusBg(experiment.status)}`}
                  >
                    <div className="flex items-start justify-between mb-4">
                      <h3 className="text-lg font-semibold truncate">{experiment.name}</h3>
                      <div className="flex space-x-2">
                        <button 
                          onClick={() => {
                            setSelectedExperiment(experiment);
                            setShowModal(true);
                          }}
                          className="text-gray-400 hover:text-white transition-colors"
                        >
                          <EyeIcon className="w-4 h-4" />
                        </button>
                        <button className="text-gray-400 hover:text-red-400 transition-colors">
                          <TrashIcon className="w-4 h-4" />
                        </button>
                      </div>
                    </div>
                    
                    <div className="space-y-3">
                      <div className="flex justify-between">
                        <span className="text-gray-400">Status</span>
                        <span className={`capitalize ${getStatusColor(experiment.status)}`}>
                          {experiment.status}
                        </span>
                      </div>
                      
                      {experiment.status !== 'queued' && (
                        <>
                          <div className="flex justify-between">
                            <span className="text-gray-400">Accuracy</span>
                            <span className="text-white">{experiment.accuracy}%</span>
                          </div>
                          <div className="flex justify-between">
                            <span className="text-gray-400">Loss</span>
                            <span className="text-white">{experiment.loss}</span>
                          </div>
                        </>
                      )}
                      
                      <div className="flex justify-between">
                        <span className="text-gray-400">Model</span>
                        <span className="text-white text-sm">{experiment.model}</span>
                      </div>
                      
                      <div className="flex justify-between">
                        <span className="text-gray-400">Dataset</span>
                        <span className="text-white text-sm">{experiment.dataset}</span>
                      </div>
                      
                      <div className="flex justify-between">
                        <span className="text-gray-400">Duration</span>
                        <span className="text-white">{experiment.duration}</span>
                      </div>
                    </div>
                    
                    {experiment.status === 'training' && (
                      <div className="mt-4">
                        <div className="flex justify-between text-sm mb-1">
                          <span className="text-gray-400">Progress</span>
                          <span className="text-white">65%</span>
                        </div>
                        <div className="w-full bg-gray-700 rounded-full h-2">
                          <div className="bg-blue-500 h-2 rounded-full animate-pulse" style={{ width: '65%' }} />
                        </div>
                      </div>
                    )}
                  </div>
                ))}
              </div>
            </div>
          )}

          {activeTab === 'datasets' && (
            <div className="space-y-6">
              <div className="flex items-center justify-between">
                <h2 className="text-3xl font-bold">Datasets</h2>
                <button className="bg-green-600 hover:bg-green-700 px-4 py-2 rounded-lg font-medium transition-colors flex items-center space-x-2">
                  <ArrowUpTrayIcon className="w-4 h-4" />
                  <span>Upload Dataset</span>
                </button>
              </div>

              {/* File Upload Area */}
              <div
                onDragOver={handleDragOver}
                onDragLeave={handleDragLeave}
                onDrop={handleDrop}
                className={`border-2 border-dashed rounded-xl p-12 text-center transition-all ${
                  dragOver 
                    ? 'border-blue-500 bg-blue-500/10' 
                    : 'border-gray-700 hover:border-gray-600'
                }`}
              >
                <CloudArrowUpIcon className={`w-16 h-16 mx-auto mb-4 ${dragOver ? 'text-blue-400' : 'text-gray-400'}`} />
                <h3 className="text-xl font-semibold mb-2">
                  {dragOver ? 'Drop your files here' : 'Upload your datasets'}
                </h3>
                <p className="text-gray-400 mb-4">
                  Drag and drop your CSV, JSON, or image files here, or click to browse
                </p>
                <button className="bg-blue-600 hover:bg-blue-700 px-6 py-2 rounded-lg font-medium transition-colors">
                  Choose Files
                </button>
                <p className="text-sm text-gray-500 mt-2">
                  Supported formats: CSV, JSON, PNG, JPG, TXT (Max 100MB)
                </p>
              </div>

              {/* Dataset List */}
              <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
                {[
                  { name: 'ImageNet-1K', size: '144GB', files: '1.2M images', type: 'Image Classification' },
                  { name: 'COCO-2017', size: '18GB', files: '328K images', type: 'Object Detection' },
                  { name: 'WikiText-103', size: '517MB', files: '28K articles', type: 'Language Modeling' },
                  { name: 'GLUE-SST2', size: '7MB', files: '70K sentences', type: 'Sentiment Analysis' }
                ].map((dataset, index) => (
                  <div key={index} className="bg-gray-900 border border-gray-800 rounded-xl p-6 hover:border-gray-700 transition-colors">
                    <div className="flex items-start justify-between mb-4">
                      <h3 className="text-lg font-semibold">{dataset.name}</h3>
                      <button className="text-gray-400 hover:text-white transition-colors">
                        <DocumentTextIcon className="w-5 h-5" />
                      </button>
                    </div>
                    <div className="space-y-2">
                      <div className="flex justify-between">
                        <span className="text-gray-400">Size</span>
                        <span className="text-white">{dataset.size}</span>
                      </div>
                      <div className="flex justify-between">
                        <span className="text-gray-400">Files</span>
                        <span className="text-white">{dataset.files}</span>
                      </div>
                      <div className="flex justify-between">
                        <span className="text-gray-400">Type</span>
                        <span className="text-white text-sm">{dataset.type}</span>
                      </div>
                    </div>
                  </div>
                ))}
              </div>
            </div>
          )}
        </main>
      </div>

      {/* Modal */}
      {showModal && (
        <ModelDetailsModal 
          experiment={selectedExperiment} 
          onClose={() => {
            setShowModal(false);
            setSelectedExperiment(null);
          }} 
        />
      )}
    </div>
  );
};

export default MLTrainingPlatform;
