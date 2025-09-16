using System;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.ComponentModel;
using System.Linq;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Data;
using Windows11StartupAnalyzer.Models;
using Windows11StartupAnalyzer.Services;

namespace Windows11StartupAnalyzer
{
    public partial class MainWindow : Window
    {
        private readonly StartupAnalysisService _startupAnalysisService;
        private readonly ServiceAnalysisService _serviceAnalysisService;
        private readonly EventLogService _eventLogService;
        private readonly OptimizationService _optimizationService;
        private readonly PerformanceService _performanceService;
        
        private ObservableCollection<StartupItem> _startupItems;
        private ObservableCollection<ServiceItem> _serviceItems;
        private ObservableCollection<SystemEvent> _systemEvents;
        private ICollectionView _startupItemsView;
        
        public MainWindow()
        {
            InitializeComponent();
            
            _startupAnalysisService = new StartupAnalysisService();
            _serviceAnalysisService = new ServiceAnalysisService();
            _eventLogService = new EventLogService();
            _optimizationService = new OptimizationService();
            _performanceService = new PerformanceService();
            
            _startupItems = new ObservableCollection<StartupItem>();
            _serviceItems = new ObservableCollection<ServiceItem>();
            _systemEvents = new ObservableCollection<SystemEvent>();
            
            StartupItemsGrid.ItemsSource = _startupItems;
            ServicesGrid.ItemsSource = _serviceItems;
            SystemEventsGrid.ItemsSource = _systemEvents;
            
            _startupItemsView = CollectionViewSource.GetDefaultView(_startupItems);
            
            Loaded += MainWindow_Loaded;
        }
        
        private async void MainWindow_Loaded(object sender, RoutedEventArgs e)
        {
            if (!_optimizationService.CanOptimizeSystem())
            {
                MessageBox.Show("This application requires administrator privileges to function properly. " +
                    "Please restart as administrator for full functionality.", "Administrator Required", 
                    MessageBoxButton.OK, MessageBoxImage.Warning);
            }
            
            await RefreshAllDataAsync();
        }
        
        private async void RefreshButton_Click(object sender, RoutedEventArgs e)
        {
            await RefreshAllDataAsync();
        }
        
        private async Task RefreshAllDataAsync()
        {
            try
            {
                StatusText.Text = "Analyzing startup performance...";
                RefreshButton.IsEnabled = false;
                TotalStartupTimeText.Text = "Calculating...";
                
                await Task.Run(async () =>
                {
                    var startupItemsTask = Task.Run(() => _startupAnalysisService.GetStartupItems());
                    var servicesTask = Task.Run(() => _serviceAnalysisService.GetStartupServices());
                    var eventsTask = Task.Run(() => _eventLogService.GetStartupEvents());
                    var totalTimeTask = Task.Run(() => CalculateTotalStartupTime());
                    
                    await Task.WhenAll(startupItemsTask, servicesTask, eventsTask, totalTimeTask);
                    
                    Dispatcher.Invoke(() =>
                    {
                        _startupItems.Clear();
                        foreach (var item in startupItemsTask.Result)
                        {
                            _startupItems.Add(item);
                        }
                        
                        _serviceItems.Clear();
                        foreach (var service in servicesTask.Result)
                        {
                            _serviceItems.Add(service);
                        }
                        
                        _systemEvents.Clear();
                        foreach (var evt in eventsTask.Result)
                        {
                            _systemEvents.Add(evt);
                        }
                        
                        TotalStartupTimeText.Text = $"{totalTimeTask.Result:F1}";
                        
                        UpdateOptimizationRecommendations();
                    });
                });
                
                StatusText.Text = $"Analysis complete - Found {_startupItems.Count} startup items, {_serviceItems.Count} services";
                LastUpdateText.Text = $"Last updated: {DateTime.Now:yyyy-MM-dd HH:mm:ss}";
            }
            catch (Exception ex)
            {
                StatusText.Text = $"Error during analysis: {ex.Message}";
                MessageBox.Show($"An error occurred during analysis: {ex.Message}", "Error", 
                    MessageBoxButton.OK, MessageBoxImage.Error);
            }
            finally
            {
                RefreshButton.IsEnabled = true;
            }
        }
        
        private double CalculateTotalStartupTime()
        {
            var bootTime = _eventLogService.GetTotalBootTime();
            var startupItemsTime = _startupItems.Sum(i => i.LoadTimeSeconds);
            var servicesTime = _serviceItems.Sum(s => s.LoadTimeSeconds);
            
            var totalTime = Math.Max(bootTime, startupItemsTime + servicesTime * 0.4);
            
            return Math.Min(totalTime, 300);
        }
        
        private void UpdateOptimizationRecommendations()
        {
            try
            {
                var recommendations = _optimizationService.GenerateOptimizationRecommendations(
                    _startupItems.ToList(), _serviceItems.ToList());
                
                OptimizationTipsPanel.Children.Clear();
                
                foreach (var recommendation in recommendations)
                {
                    var textBlock = new TextBlock
                    {
                        Text = recommendation,
                        TextWrapping = TextWrapping.Wrap,
                        Margin = new Thickness(0, 2, 0, 2),
                        FontSize = recommendation.StartsWith("   ") ? 12 : 13,
                        FontWeight = recommendation.Contains("PRIORITY") || recommendation.Contains("💡") || 
                                   recommendation.Contains("🛡️") || recommendation.Contains("⚡") ? 
                                   FontWeights.Bold : FontWeights.Normal
                    };
                    
                    OptimizationTipsPanel.Children.Add(textBlock);
                }
            }
            catch (Exception ex)
            {
                StatusText.Text = $"Error generating recommendations: {ex.Message}";
            }
        }
        
        private async void DisableStartupItem_Click(object sender, RoutedEventArgs e)
        {
            var button = sender as Button;
            var item = button?.DataContext as StartupItem;
            
            if (item == null) return;
            
            var result = MessageBox.Show(
                $"Are you sure you want to disable '{item.Name}'?\n\n" +
                "This will prevent it from starting automatically with Windows. " +
                "You can manually start the program later if needed.",
                "Disable Startup Item",
                MessageBoxButton.YesNo,
                MessageBoxImage.Question);
            
            if (result == MessageBoxResult.Yes)
            {
                try
                {
                    StatusText.Text = $"Disabling {item.Name}...";
                    button.IsEnabled = false;
                    
                    var success = await _optimizationService.DisableStartupItemAsync(item);
                    
                    if (success)
                    {
                        item.Status = "Disabled";
                        item.CanDisable = false;
                        StatusText.Text = $"Successfully disabled {item.Name}";
                        
                        MessageBox.Show($"'{item.Name}' has been disabled from startup.", "Success", 
                            MessageBoxButton.OK, MessageBoxImage.Information);
                    }
                    else
                    {
                        StatusText.Text = $"Failed to disable {item.Name}";
                        MessageBox.Show($"Failed to disable '{item.Name}'. You may need administrator privileges.", 
                            "Error", MessageBoxButton.OK, MessageBoxImage.Error);
                    }
                }
                catch (Exception ex)
                {
                    StatusText.Text = $"Error disabling {item.Name}: {ex.Message}";
                    MessageBox.Show($"Error: {ex.Message}", "Error", MessageBoxButton.OK, MessageBoxImage.Error);
                }
                finally
                {
                    button.IsEnabled = true;
                }
            }
        }
        
        private async void DelayStartupItem_Click(object sender, RoutedEventArgs e)
        {
            var button = sender as Button;
            var item = button?.DataContext as StartupItem;
            
            if (item == null) return;
            
            var delayDialog = new DelayInputDialog();
            if (delayDialog.ShowDialog() == true)
            {
                try
                {
                    StatusText.Text = $"Setting up delayed start for {item.Name}...";
                    button.IsEnabled = false;
                    
                    var success = await _optimizationService.DelayStartupItemAsync(item, delayDialog.DelaySeconds);
                    
                    if (success)
                    {
                        item.Status = $"Delayed ({delayDialog.DelaySeconds}s)";
                        StatusText.Text = $"Successfully set up delayed start for {item.Name}";
                        
                        MessageBox.Show($"'{item.Name}' will now start {delayDialog.DelaySeconds} seconds after login.", 
                            "Success", MessageBoxButton.OK, MessageBoxImage.Information);
                    }
                    else
                    {
                        StatusText.Text = $"Failed to set up delayed start for {item.Name}";
                        MessageBox.Show($"Failed to set up delayed start for '{item.Name}'. " +
                            "Administrator privileges may be required.", "Error", 
                            MessageBoxButton.OK, MessageBoxImage.Error);
                    }
                }
                catch (Exception ex)
                {
                    StatusText.Text = $"Error setting up delayed start: {ex.Message}";
                    MessageBox.Show($"Error: {ex.Message}", "Error", MessageBoxButton.OK, MessageBoxImage.Error);
                }
                finally
                {
                    button.IsEnabled = true;
                }
            }
        }
        
        private void InfoStartupItem_Click(object sender, RoutedEventArgs e)
        {
            var button = sender as Button;
            var item = button?.DataContext as StartupItem;
            
            if (item != null)
            {
                var details = _optimizationService.GetItemDetails(item);
                MessageBox.Show(details, $"Information: {item.Name}", 
                    MessageBoxButton.OK, MessageBoxImage.Information);
            }
        }
        
        private async void ConfigureService_Click(object sender, RoutedEventArgs e)
        {
            var button = sender as Button;
            var service = button?.DataContext as ServiceItem;
            
            if (service == null) return;
            
            var configDialog = new ServiceConfigDialog(service);
            if (configDialog.ShowDialog() == true)
            {
                try
                {
                    StatusText.Text = $"Configuring {service.Name}...";
                    button.IsEnabled = false;
                    
                    var success = await _optimizationService.ChangeServiceStartupTypeAsync(service, configDialog.NewStartupType);
                    
                    if (success)
                    {
                        service.StartupType = configDialog.NewStartupType;
                        StatusText.Text = $"Successfully configured {service.Name}";
                        
                        MessageBox.Show($"'{service.Name}' startup type changed to {configDialog.NewStartupType}.", 
                            "Success", MessageBoxButton.OK, MessageBoxImage.Information);
                    }
                    else
                    {
                        StatusText.Text = $"Failed to configure {service.Name}";
                        MessageBox.Show($"Failed to configure '{service.Name}'. Administrator privileges required.", 
                            "Error", MessageBoxButton.OK, MessageBoxImage.Error);
                    }
                }
                catch (Exception ex)
                {
                    StatusText.Text = $"Error configuring service: {ex.Message}";
                    MessageBox.Show($"Error: {ex.Message}", "Error", MessageBoxButton.OK, MessageBoxImage.Error);
                }
                finally
                {
                    button.IsEnabled = true;
                }
            }
        }
        
        private void InfoService_Click(object sender, RoutedEventArgs e)
        {
            var button = sender as Button;
            var service = button?.DataContext as ServiceItem;
            
            if (service != null)
            {
                var details = _optimizationService.GetServiceDetails(service);
                MessageBox.Show(details, $"Service Information: {service.DisplayName}", 
                    MessageBoxButton.OK, MessageBoxImage.Information);
            }
        }
        
        private void FilterComboBox_SelectionChanged(object sender, SelectionChangedEventArgs e)
        {
            if (_startupItemsView == null) return;
            
            var selectedItem = FilterComboBox.SelectedItem as ComboBoxItem;
            var filterText = selectedItem?.Content?.ToString();
            
            _startupItemsView.Filter = filterText switch
            {
                "Slow Items (>5s)" => item => ((StartupItem)item).LoadTimeSeconds > 5.0,
                "Medium Items (1-5s)" => item => ((StartupItem)item).LoadTimeSeconds >= 1.0 && ((StartupItem)item).LoadTimeSeconds <= 5.0,
                "Fast Items (<1s)" => item => ((StartupItem)item).LoadTimeSeconds < 1.0,
                _ => null
            };
        }
        
        private void SearchTextBox_TextChanged(object sender, TextChangedEventArgs e)
        {
            if (_startupItemsView == null) return;
            
            var searchText = SearchTextBox.Text?.ToLower() ?? "";
            
            if (string.IsNullOrWhiteSpace(searchText))
            {
                _startupItemsView.Filter = null;
            }
            else
            {
                _startupItemsView.Filter = item =>
                {
                    var startupItem = (StartupItem)item;
                    return startupItem.Name.ToLower().Contains(searchText) ||
                           startupItem.Location.ToLower().Contains(searchText) ||
                           startupItem.Publisher.ToLower().Contains(searchText);
                };
            }
        }
    }
    
    public class DelayInputDialog : Window
    {
        public int DelaySeconds { get; private set; } = 30;
        
        public DelayInputDialog()
        {
            Title = "Delay Startup";
            Width = 300;
            Height = 150;
            WindowStartupLocation = WindowStartupLocation.CenterOwner;
            ResizeMode = ResizeMode.NoResize;
            
            var grid = new Grid();
            grid.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
            grid.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
            grid.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
            
            var label = new Label { Content = "Delay startup by how many seconds?", Margin = new Thickness(10) };
            Grid.SetRow(label, 0);
            
            var textBox = new TextBox { Text = "30", Margin = new Thickness(10, 0, 10, 10), Padding = new Thickness(5) };
            Grid.SetRow(textBox, 1);
            
            var buttonPanel = new StackPanel { Orientation = Orientation.Horizontal, HorizontalAlignment = HorizontalAlignment.Right, Margin = new Thickness(10) };
            var okButton = new Button { Content = "OK", Width = 75, Height = 25, Margin = new Thickness(5, 0, 0, 0) };
            var cancelButton = new Button { Content = "Cancel", Width = 75, Height = 25 };
            
            okButton.Click += (s, e) =>
            {
                if (int.TryParse(textBox.Text, out int delay) && delay > 0 && delay <= 300)
                {
                    DelaySeconds = delay;
                    DialogResult = true;
                }
                else
                {
                    MessageBox.Show("Please enter a valid delay between 1 and 300 seconds.", "Invalid Input", 
                        MessageBoxButton.OK, MessageBoxImage.Warning);
                }
            };
            
            cancelButton.Click += (s, e) => DialogResult = false;
            
            buttonPanel.Children.Add(cancelButton);
            buttonPanel.Children.Add(okButton);
            Grid.SetRow(buttonPanel, 2);
            
            grid.Children.Add(label);
            grid.Children.Add(textBox);
            grid.Children.Add(buttonPanel);
            
            Content = grid;
        }
    }
    
    public class ServiceConfigDialog : Window
    {
        public string NewStartupType { get; private set; } = string.Empty;
        
        public ServiceConfigDialog(ServiceItem service)
        {
            Title = $"Configure Service: {service.DisplayName}";
            Width = 400;
            Height = 200;
            WindowStartupLocation = WindowStartupLocation.CenterOwner;
            ResizeMode = ResizeMode.NoResize;
            
            var grid = new Grid();
            grid.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
            grid.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
            grid.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
            
            var label = new Label { Content = "Select new startup type:", Margin = new Thickness(10) };
            Grid.SetRow(label, 0);
            
            var comboBox = new ComboBox { Margin = new Thickness(10, 0, 10, 10), Padding = new Thickness(5) };
            comboBox.Items.Add("Automatic");
            comboBox.Items.Add("Manual");
            comboBox.Items.Add("Disabled");
            comboBox.SelectedItem = service.StartupType;
            Grid.SetRow(comboBox, 1);
            
            var buttonPanel = new StackPanel { Orientation = Orientation.Horizontal, HorizontalAlignment = HorizontalAlignment.Right, Margin = new Thickness(10) };
            var okButton = new Button { Content = "OK", Width = 75, Height = 25, Margin = new Thickness(5, 0, 0, 0) };
            var cancelButton = new Button { Content = "Cancel", Width = 75, Height = 25 };
            
            okButton.Click += (s, e) =>
            {
                NewStartupType = comboBox.SelectedItem?.ToString() ?? service.StartupType;
                DialogResult = true;
            };
            
            cancelButton.Click += (s, e) => DialogResult = false;
            
            buttonPanel.Children.Add(cancelButton);
            buttonPanel.Children.Add(okButton);
            Grid.SetRow(buttonPanel, 2);
            
            grid.Children.Add(label);
            grid.Children.Add(comboBox);
            grid.Children.Add(buttonPanel);
            
            Content = grid;
        }
    }
}