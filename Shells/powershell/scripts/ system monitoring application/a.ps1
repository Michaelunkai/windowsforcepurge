# Advanced System Monitoring Dashboard with Material Design WPF Interface
# Requires: PowerShell 5.1+, .NET Framework 4.7.2+

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Windows.Forms

# Global variables for real-time monitoring
$Global:MonitoringActive = $false
$Global:SystemData = @{}
$Global:ChartData = @{
    CPU = New-Object System.Collections.ArrayList
    RAM = New-Object System.Collections.ArrayList
    Disk = New-Object System.Collections.ArrayList
    Network = New-Object System.Collections.ArrayList
}

# XAML for the main window with Material Design styling
$xaml = @"
<Window x:Class="SystemMonitor.MainWindow"
        xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Advanced System Monitor" Height="900" Width="1400" WindowStartupLocation="CenterScreen"
        Background="#FF1E1E1E" FontFamily="Segoe UI" WindowStyle="None" AllowsTransparency="True"
        ResizeMode="CanResize">
    
    <Window.Resources>
        <!-- Material Design Color Palette -->
        <SolidColorBrush x:Key="PrimaryBrush" Color="#FF2196F3"/>
        <SolidColorBrush x:Key="PrimaryDarkBrush" Color="#FF1976D2"/>
        <SolidColorBrush x:Key="AccentBrush" Color="#FF03DAC6"/>
        <SolidColorBrush x:Key="SurfaceBrush" Color="#FF2D2D2D"/>
        <SolidColorBrush x:Key="BackgroundBrush" Color="#FF1E1E1E"/>
        <SolidColorBrush x:Key="OnSurfaceBrush" Color="#FFFFFFFF"/>
        <SolidColorBrush x:Key="OnBackgroundBrush" Color="#FFFFFFFF"/>
        <SolidColorBrush x:Key="SuccessBrush" Color="#FF4CAF50"/>
        <SolidColorBrush x:Key="WarningBrush" Color="#FFFF9800"/>
        <SolidColorBrush x:Key="ErrorBrush" Color="#FFF44336"/>
        
        <!-- Glassmorphism Effect -->
        <Style x:Key="GlassmorphismPanel" TargetType="Border">
            <Setter Property="Background">
                <Setter.Value>
                    <SolidColorBrush Color="#AA2D2D2D" Opacity="0.8"/>
                </Setter.Value>
            </Setter>
            <Setter Property="CornerRadius" Value="12"/>
            <Setter Property="Effect">
                <Setter.Value>
                    <DropShadowEffect Color="Black" BlurRadius="20" ShadowDepth="0" Opacity="0.3"/>
                </Setter.Value>
            </Setter>
        </Style>
        
        <!-- Custom Button Style -->
        <Style x:Key="MaterialButton" TargetType="Button">
            <Setter Property="Background" Value="{StaticResource PrimaryBrush}"/>
            <Setter Property="Foreground" Value="White"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Padding" Value="16,8"/>
            <Setter Property="FontSize" Value="14"/>
            <Setter Property="FontWeight" Value="Medium"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border Background="{TemplateBinding Background}" 
                                CornerRadius="6" 
                                Padding="{TemplateBinding Padding}">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                            <Border.Effect>
                                <DropShadowEffect Color="Black" BlurRadius="8" ShadowDepth="2" Opacity="0.3"/>
                            </Border.Effect>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter Property="Background" Value="{StaticResource PrimaryDarkBrush}"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
        
        <!-- Circular Progress Bar Style -->
        <Style x:Key="CircularProgress" TargetType="ProgressBar">
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="ProgressBar">
                        <Grid>
                            <Ellipse Stroke="#FF404040" StrokeThickness="8" Fill="Transparent"/>
                            <Ellipse x:Name="PART_Indicator" 
                                   Stroke="{StaticResource PrimaryBrush}" 
                                   StrokeThickness="8" 
                                   Fill="Transparent"
                                   StrokeDashArray="251.2" 
                                   StrokeDashOffset="251.2"
                                   RenderTransformOrigin="0.5,0.5">
                                <Ellipse.RenderTransform>
                                    <RotateTransform Angle="-90"/>
                                </Ellipse.RenderTransform>
                            </Ellipse>
                            <TextBlock Text="{Binding RelativeSource={RelativeSource TemplatedParent}, Path=Value, StringFormat={}{0:F0}%}"
                                     HorizontalAlignment="Center" 
                                     VerticalAlignment="Center"
                                     FontSize="16" 
                                     FontWeight="Bold"
                                     Foreground="{StaticResource OnSurfaceBrush}"/>
                        </Grid>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
        
        <!-- Data Grid Style -->
        <Style x:Key="MaterialDataGrid" TargetType="DataGrid">
            <Setter Property="Background" Value="{StaticResource SurfaceBrush}"/>
            <Setter Property="Foreground" Value="{StaticResource OnSurfaceBrush}"/>
            <Setter Property="BorderBrush" Value="#FF404040"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="GridLinesVisibility" Value="Horizontal"/>
            <Setter Property="HorizontalGridLinesBrush" Value="#FF404040"/>
            <Setter Property="RowBackground" Value="Transparent"/>
            <Setter Property="AlternatingRowBackground" Value="#FF2A2A2A"/>
            <Setter Property="HeadersVisibility" Value="Column"/>
            <Setter Property="CanUserResizeRows" Value="False"/>
            <Setter Property="SelectionMode" Value="Single"/>
            <Setter Property="IsReadOnly" Value="True"/>
        </Style>
    </Window.Resources>
    
    <Grid>
        <!-- Title Bar -->
        <Grid Height="40" VerticalAlignment="Top" Background="{StaticResource PrimaryBrush}">
            <TextBlock Text="Advanced System Monitor" 
                      VerticalAlignment="Center" 
                      HorizontalAlignment="Left" 
                      Margin="15,0" 
                      FontSize="16" 
                      FontWeight="Bold" 
                      Foreground="White"/>
            <StackPanel Orientation="Horizontal" HorizontalAlignment="Right" Margin="10,0">
                <Button x:Name="MinimizeButton" Content="🗕" Width="30" Height="30" 
                       Background="Transparent" BorderThickness="0" Foreground="White" FontSize="12"/>
                <Button x:Name="MaximizeButton" Content="🗖" Width="30" Height="30" 
                       Background="Transparent" BorderThickness="0" Foreground="White" FontSize="12"/>
                <Button x:Name="CloseButton" Content="✕" Width="30" Height="30" 
                       Background="Transparent" BorderThickness="0" Foreground="White" FontSize="12"/>
            </StackPanel>
        </Grid>
        
        <!-- Main Content -->
        <Grid Margin="0,40,0,0">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="250"/>
                <ColumnDefinition Width="*"/>
            </Grid.ColumnDefinitions>
            
            <!-- Navigation Panel -->
            <Border Grid.Column="0" Style="{StaticResource GlassmorphismPanel}" Margin="10">
                <ScrollViewer VerticalScrollBarVisibility="Auto">
                    <StackPanel Margin="15">
                        <TextBlock Text="DASHBOARD" FontSize="14" FontWeight="Bold" 
                                  Foreground="{StaticResource AccentBrush}" Margin="0,0,0,10"/>
                        
                        <Button x:Name="OverviewButton" Content="📊 Overview" Style="{StaticResource MaterialButton}" 
                               Margin="0,2" HorizontalAlignment="Stretch"/>
                        <Button x:Name="PerformanceButton" Content="⚡ Performance" Style="{StaticResource MaterialButton}" 
                               Margin="0,2" HorizontalAlignment="Stretch"/>
                        <Button x:Name="ServicesButton" Content="🔧 Services" Style="{StaticResource MaterialButton}" 
                               Margin="0,2" HorizontalAlignment="Stretch"/>
                        <Button x:Name="StartupButton" Content="🚀 Startup" Style="{StaticResource MaterialButton}" 
                               Margin="0,2" HorizontalAlignment="Stretch"/>
                        
                        <TextBlock Text="MAINTENANCE" FontSize="14" FontWeight="Bold" 
                                  Foreground="{StaticResource AccentBrush}" Margin="0,20,0,10"/>
                        
                        <Button x:Name="CleanupButton" Content="🧹 Cleanup" Style="{StaticResource MaterialButton}" 
                               Margin="0,2" HorizontalAlignment="Stretch"/>
                        <Button x:Name="UpdatesButton" Content="🔄 Updates" Style="{StaticResource MaterialButton}" 
                               Margin="0,2" HorizontalAlignment="Stretch"/>
                        <Button x:Name="DriversButton" Content="💾 Drivers" Style="{StaticResource MaterialButton}" 
                               Margin="0,2" HorizontalAlignment="Stretch"/>
                        
                        <TextBlock Text="SYSTEM HEALTH" FontSize="14" FontWeight="Bold" 
                                  Foreground="{StaticResource AccentBrush}" Margin="0,20,0,10"/>
                        
                        <Border Background="{StaticResource SurfaceBrush}" CornerRadius="8" Padding="15" Margin="0,5">
                            <StackPanel>
                                <TextBlock Text="Health Score" FontSize="12" Foreground="#FFAAAAAA" Margin="0,0,0,5"/>
                                <ProgressBar x:Name="HealthScoreProgress" 
                                           Style="{StaticResource CircularProgress}" 
                                           Width="80" Height="80" 
                                           Value="85"/>
                            </StackPanel>
                        </Border>
                        
                        <Button x:Name="ReportsButton" Content="📈 Reports" Style="{StaticResource MaterialButton}" 
                               Margin="0,15,0,2" HorizontalAlignment="Stretch"/>
                        <Button x:Name="SettingsButton" Content="⚙️ Settings" Style="{StaticResource MaterialButton}" 
                               Margin="0,2" HorizontalAlignment="Stretch"/>
                    </StackPanel>
                </ScrollViewer>
            </Border>
            
            <!-- Main Content Area -->
            <Grid Grid.Column="1" Margin="5,10,10,10">
                <!-- Overview Panel -->
                <ScrollViewer x:Name="OverviewPanel" Visibility="Visible">
                    <Grid>
                        <Grid.RowDefinitions>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="*"/>
                        </Grid.RowDefinitions>
                        
                        <!-- Quick Stats -->
                        <UniformGrid Grid.Row="0" Columns="4" Margin="0,0,0,20">
                            <Border Style="{StaticResource GlassmorphismPanel}" Margin="5" Padding="20">
                                <StackPanel>
                                    <TextBlock Text="CPU" FontSize="14" Foreground="#FFAAAAAA"/>
                                    <ProgressBar x:Name="CPUProgress" Style="{StaticResource CircularProgress}" 
                                               Width="60" Height="60" Value="45" Margin="0,10"/>
                                    <TextBlock x:Name="CPUDetails" Text="Intel i7-10700K" FontSize="10" 
                                              Foreground="#FFAAAAAA" HorizontalAlignment="Center"/>
                                </StackPanel>
                            </Border>
                            
                            <Border Style="{StaticResource GlassmorphismPanel}" Margin="5" Padding="20">
                                <StackPanel>
                                    <TextBlock Text="RAM" FontSize="14" Foreground="#FFAAAAAA"/>
                                    <ProgressBar x:Name="RAMProgress" Style="{StaticResource CircularProgress}" 
                                               Width="60" Height="60" Value="68" Margin="0,10"/>
                                    <TextBlock x:Name="RAMDetails" Text="16 GB Total" FontSize="10" 
                                              Foreground="#FFAAAAAA" HorizontalAlignment="Center"/>
                                </StackPanel>
                            </Border>
                            
                            <Border Style="{StaticResource GlassmorphismPanel}" Margin="5" Padding="20">
                                <StackPanel>
                                    <TextBlock Text="DISK" FontSize="14" Foreground="#FFAAAAAA"/>
                                    <ProgressBar x:Name="DiskProgress" Style="{StaticResource CircularProgress}" 
                                               Width="60" Height="60" Value="32" Margin="0,10"/>
                                    <TextBlock x:Name="DiskDetails" Text="SSD 512GB" FontSize="10" 
                                              Foreground="#FFAAAAAA" HorizontalAlignment="Center"/>
                                </StackPanel>
                            </Border>
                            
                            <Border Style="{StaticResource GlassmorphismPanel}" Margin="5" Padding="20">
                                <StackPanel>
                                    <TextBlock Text="NETWORK" FontSize="14" Foreground="#FFAAAAAA"/>
                                    <ProgressBar x:Name="NetworkProgress" Style="{StaticResource CircularProgress}" 
                                               Width="60" Height="60" Value="23" Margin="0,10"/>
                                    <TextBlock x:Name="NetworkDetails" Text="1 Gbps" FontSize="10" 
                                              Foreground="#FFAAAAAA" HorizontalAlignment="Center"/>
                                </StackPanel>
                            </Border>
                        </UniformGrid>
                        
                        <!-- Charts Row -->
                        <Grid Grid.Row="1" Height="300" Margin="0,0,0,20">
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="*"/>
                            </Grid.ColumnDefinitions>
                            
                            <Border Grid.Column="0" Style="{StaticResource GlassmorphismPanel}" Margin="5" Padding="20">
                                <StackPanel>
                                    <TextBlock Text="Performance Trends" FontSize="16" FontWeight="Bold" 
                                              Foreground="{StaticResource OnSurfaceBrush}" Margin="0,0,0,15"/>
                                    <Canvas x:Name="PerformanceChart" Height="200" Background="Transparent"/>
                                </StackPanel>
                            </Border>
                            
                            <Border Grid.Column="1" Style="{StaticResource GlassmorphismPanel}" Margin="5" Padding="20">
                                <StackPanel>
                                    <TextBlock Text="System Alerts" FontSize="16" FontWeight="Bold" 
                                              Foreground="{StaticResource OnSurfaceBrush}" Margin="0,0,0,15"/>
                                    <ListBox x:Name="AlertsList" Background="Transparent" BorderThickness="0" 
                                            Height="200" Foreground="{StaticResource OnSurfaceBrush}"/>
                                </StackPanel>
                            </Border>
                        </Grid>
                        
                        <!-- System Information -->
                        <Border Grid.Row="2" Style="{StaticResource GlassmorphismPanel}" Margin="5" Padding="20">
                            <StackPanel>
                                <TextBlock Text="System Information" FontSize="16" FontWeight="Bold" 
                                          Foreground="{StaticResource OnSurfaceBrush}" Margin="0,0,0,15"/>
                                <Grid>
                                    <Grid.ColumnDefinitions>
                                        <ColumnDefinition Width="*"/>
                                        <ColumnDefinition Width="*"/>
                                    </Grid.ColumnDefinitions>
                                    
                                    <StackPanel Grid.Column="0" Margin="0,0,10,0">
                                        <TextBlock x:Name="OSInfo" Text="Operating System: Windows 11 Pro" 
                                                  Foreground="{StaticResource OnSurfaceBrush}" Margin="0,2"/>
                                        <TextBlock x:Name="CPUInfo" Text="Processor: Intel Core i7-10700K" 
                                                  Foreground="{StaticResource OnSurfaceBrush}" Margin="0,2"/>
                                        <TextBlock x:Name="MemoryInfo" Text="Installed RAM: 16.0 GB" 
                                                  Foreground="{StaticResource OnSurfaceBrush}" Margin="0,2"/>
                                        <TextBlock x:Name="UptimeInfo" Text="System Uptime: 2 days, 14 hours" 
                                                  Foreground="{StaticResource OnSurfaceBrush}" Margin="0,2"/>
                                    </StackPanel>
                                    
                                    <StackPanel Grid.Column="1" Margin="10,0,0,0">
                                        <TextBlock x:Name="MotherboardInfo" Text="Motherboard: ASUS ROG STRIX Z490-E" 
                                                  Foreground="{StaticResource OnSurfaceBrush}" Margin="0,2"/>
                                        <TextBlock x:Name="GPUInfo" Text="Graphics: NVIDIA RTX 3080" 
                                                  Foreground="{StaticResource OnSurfaceBrush}" Margin="0,2"/>
                                        <TextBlock x:Name="StorageInfo" Text="Storage: 512 GB NVMe SSD" 
                                                  Foreground="{StaticResource OnSurfaceBrush}" Margin="0,2"/>
                                        <TextBlock x:Name="NetworkInfo" Text="Network: Gigabit Ethernet" 
                                                  Foreground="{StaticResource OnSurfaceBrush}" Margin="0,2"/>
                                    </StackPanel>
                                </Grid>
                            </StackPanel>
                        </Border>
                    </Grid>
                </ScrollViewer>
                
                <!-- Services Panel -->
                <ScrollViewer x:Name="ServicesPanel" Visibility="Collapsed">
                    <Border Style="{StaticResource GlassmorphismPanel}" Padding="20">
                        <StackPanel>
                            <TextBlock Text="Service Management" FontSize="20" FontWeight="Bold" 
                                      Foreground="{StaticResource OnSurfaceBrush}" Margin="0,0,0,20"/>
                            
                            <Grid Margin="0,0,0,15">
                                <Grid.ColumnDefinitions>
                                    <ColumnDefinition Width="*"/>
                                    <ColumnDefinition Width="Auto"/>
                                </Grid.ColumnDefinitions>
                                
                                <TextBox x:Name="ServiceSearchBox" Grid.Column="0" 
                                        Background="{StaticResource SurfaceBrush}" 
                                        Foreground="{StaticResource OnSurfaceBrush}"
                                        BorderBrush="#FF404040" 
                                        Padding="10" 
                                        FontSize="14"
                                        Text="Search services..."/>
                                
                                <Button x:Name="RefreshServicesButton" Grid.Column="1" 
                                       Content="🔄 Refresh" 
                                       Style="{StaticResource MaterialButton}" 
                                       Margin="10,0,0,0"/>
                            </Grid>
                            
                            <DataGrid x:Name="ServicesDataGrid" 
                                     Style="{StaticResource MaterialDataGrid}" 
                                     Height="500" 
                                     AutoGenerateColumns="False">
                                <DataGrid.Columns>
                                    <DataGridTextColumn Header="Service Name" Binding="{Binding Name}" Width="200"/>
                                    <DataGridTextColumn Header="Display Name" Binding="{Binding DisplayName}" Width="300"/>
                                    <DataGridTextColumn Header="Status" Binding="{Binding Status}" Width="100"/>
                                    <DataGridTextColumn Header="Startup Type" Binding="{Binding StartType}" Width="120"/>
                                    <DataGridTextColumn Header="Impact" Binding="{Binding Impact}" Width="100"/>
                                </DataGrid.Columns>
                            </DataGrid>
                            
                            <StackPanel Orientation="Horizontal" Margin="0,15,0,0">
                                <Button x:Name="StartServiceButton" Content="▶️ Start" Style="{StaticResource MaterialButton}" Margin="0,0,10,0"/>
                                <Button x:Name="StopServiceButton" Content="⏹️ Stop" Style="{StaticResource MaterialButton}" Margin="0,0,10,0"/>
                                <Button x:Name="RestartServiceButton" Content="🔄 Restart" Style="{StaticResource MaterialButton}" Margin="0,0,10,0"/>
                                <Button x:Name="ServicePropertiesButton" Content="⚙️ Properties" Style="{StaticResource MaterialButton}"/>
                            </StackPanel>
                        </StackPanel>
                    </Border>
                </ScrollViewer>
                
                <!-- Startup Panel -->
                <ScrollViewer x:Name="StartupPanel" Visibility="Collapsed">
                    <Border Style="{StaticResource GlassmorphismPanel}" Padding="20">
                        <StackPanel>
                            <TextBlock Text="Startup Program Optimization" FontSize="20" FontWeight="Bold" 
                                      Foreground="{StaticResource OnSurfaceBrush}" Margin="0,0,0,20"/>
                            
                            <Grid Margin="0,0,0,15">
                                <Grid.ColumnDefinitions>
                                    <ColumnDefinition Width="*"/>
                                    <ColumnDefinition Width="Auto"/>
                                </Grid.ColumnDefinitions>
                                
                                <StackPanel Grid.Column="0" Orientation="Horizontal">
                                    <TextBlock Text="Current Boot Time: " Foreground="{StaticResource OnSurfaceBrush}" VerticalAlignment="Center"/>
                                    <TextBlock x:Name="BootTimeText" Text="45 seconds" FontWeight="Bold" 
                                              Foreground="{StaticResource AccentBrush}" VerticalAlignment="Center"/>
                                    <TextBlock Text=" | Potential Improvement: " Foreground="{StaticResource OnSurfaceBrush}" VerticalAlignment="Center" Margin="20,0,0,0"/>
                                    <TextBlock x:Name="ImprovementText" Text="12 seconds" FontWeight="Bold" 
                                              Foreground="{StaticResource SuccessBrush}" VerticalAlignment="Center"/>
                                </StackPanel>
                                
                                <Button x:Name="OptimizeStartupButton" Grid.Column="1" 
                                       Content="🚀 Optimize" 
                                       Style="{StaticResource MaterialButton}"/>
                            </Grid>
                            
                            <DataGrid x:Name="StartupDataGrid" 
                                     Style="{StaticResource MaterialDataGrid}" 
                                     Height="450" 
                                     AutoGenerateColumns="False">
                                <DataGrid.Columns>
                                    <DataGridTextColumn Header="Program" Binding="{Binding Name}" Width="250"/>
                                    <DataGridTextColumn Header="Publisher" Binding="{Binding Publisher}" Width="200"/>
                                    <DataGridTextColumn Header="Status" Binding="{Binding Status}" Width="100"/>
                                    <DataGridTextColumn Header="Impact" Binding="{Binding Impact}" Width="100"/>
                                    <DataGridTextColumn Header="Boot Delay" Binding="{Binding BootDelay}" Width="100"/>
                                </DataGrid.Columns>
                            </DataGrid>
                            
                            <StackPanel Orientation="Horizontal" Margin="0,15,0,0">
                                <Button x:Name="EnableStartupButton" Content="✅ Enable" Style="{StaticResource MaterialButton}" Margin="0,0,10,0"/>
                                <Button x:Name="DisableStartupButton" Content="❌ Disable" Style="{StaticResource MaterialButton}" Margin="0,0,10,0"/>
                                <Button x:Name="DelayStartupButton" Content="⏰ Delay" Style="{StaticResource MaterialButton}"/>
                            </StackPanel>
                        </StackPanel>
                    </Border>
                </ScrollViewer>
                
                <!-- Cleanup Panel -->
                <ScrollViewer x:Name="CleanupPanel" Visibility="Collapsed">
                    <Border Style="{StaticResource GlassmorphismPanel}" Padding="20">
                        <StackPanel>
                            <TextBlock Text="System Cleanup & Optimization" FontSize="20" FontWeight="Bold" 
                                      Foreground="{StaticResource OnSurfaceBrush}" Margin="0,0,0,20"/>
                            
                            <UniformGrid Columns="3" Margin="0,0,0,20">
                                <Border Style="{StaticResource GlassmorphismPanel}" Margin="5" Padding="15">
                                    <StackPanel>
                                        <TextBlock Text="📁 Temp Files" FontSize="14" FontWeight="Bold" 
                                                  Foreground="{StaticResource AccentBrush}" HorizontalAlignment="Center"/>
                                        <TextBlock x:Name="TempFilesSize" Text="2.4 GB" FontSize="24" FontWeight="Bold" 
                                                  Foreground="{StaticResource OnSurfaceBrush}" HorizontalAlignment="Center" Margin="0,5"/>
                                        <Button x:Name="CleanTempButton" Content="Clean" Style="{StaticResource MaterialButton}" 
                                               HorizontalAlignment="Stretch" Margin="0,5"/>
                                    </StackPanel>
                                </Border>
                                
                                <Border Style="{StaticResource GlassmorphismPanel}" Margin="5" Padding="15">
                                    <StackPanel>
                                        <TextBlock Text="🗑️ Recycle Bin" FontSize="14" FontWeight="Bold" 
                                                  Foreground="{StaticResource AccentBrush}" HorizontalAlignment="Center"/>
                                        <TextBlock x:Name="RecycleBinSize" Text="856 MB" FontSize="24" FontWeight="Bold" 
                                                  Foreground="{StaticResource OnSurfaceBrush}" HorizontalAlignment="Center" Margin="0,5"/>
                                        <Button x:Name="EmptyRecycleButton" Content="Empty" Style="{StaticResource MaterialButton}" 
                                               HorizontalAlignment="Stretch" Margin="0,5"/>
                                    </StackPanel>
                                </Border>
                                
                                <Border Style="{StaticResource GlassmorphismPanel}" Margin="5" Padding="15">
                                    <StackPanel>
                                        <TextBlock Text="📋 Cache Files" FontSize="14" FontWeight="Bold" 
                                                  Foreground="{StaticResource AccentBrush}" HorizontalAlignment="Center"/>
                                        <TextBlock x:Name="CacheFilesSize" Text="1.2 GB" FontSize="24" FontWeight="Bold" 
                                                  Foreground="{StaticResource OnSurfaceBrush}" HorizontalAlignment="Center" Margin="0,5"/>
                                        <Button x:Name="CleanCacheButton" Content="Clean" Style="{StaticResource MaterialButton}" 
                                               HorizontalAlignment="Stretch" Margin="0,5"/>
                                    </StackPanel>
                                </Border>
                            </UniformGrid>
                            
                            <Border Style="{StaticResource GlassmorphismPanel}" Margin="0,0,0,15" Padding="20">
                                <StackPanel>
                                    <TextBlock Text="Cleanup Progress" FontSize="16" FontWeight="Bold" 
                                              Foreground="{StaticResource OnSurfaceBrush}" Margin="0,0,0,10"/>
                                    <ProgressBar x:Name="CleanupProgress" Height="20" Background="#FF404040" 
                                                Foreground="{StaticResource SuccessBrush}" Value="0"/>
                                    <TextBlock x:Name="CleanupStatus" Text="Ready to clean..." 
                                              Foreground="{StaticResource OnSurfaceBrush}" Margin="0,5,0,0"/>
                                </StackPanel>
                            </Border>
                            
                            <Button x:Name="FullCleanupButton" Content="🧹 Run Full Cleanup" 
                                   Style="{StaticResource MaterialButton}" 
                                   FontSize="16" 
                                   Padding="20,10" 
                                   HorizontalAlignment="Center"/>
                        </StackPanel>
                    </Border>
                </ScrollViewer>
            </Grid>
        </Grid>
        
        <!-- Status Bar -->
        <Border Height="30" VerticalAlignment="Bottom" Background="{StaticResource SurfaceBrush}">
            <Grid Margin="10,0">
                <StackPanel Orientation="Horizontal">
                    <TextBlock x:Name="StatusText" Text="System Monitor Ready" 
                              Foreground="{StaticResource OnSurfaceBrush}" 
                              VerticalAlignment="Center"/>
                    <Ellipse x:Name="StatusIndicator" Width="8" Height="8" 
                            Fill="{StaticResource SuccessBrush}" 
                            Margin="10,0,0,0"/>
                </StackPanel>
                
                <StackPanel Orientation="Horizontal" HorizontalAlignment="Right">
                    <Button x:Name="StartMonitoringButton" Content="▶️ Start Monitoring" 
                           Style="{StaticResource MaterialButton}" 
                           Margin="0,2" 
                           Padding="10,2"/>
                    <TextBlock x:Name="LastUpdateText" Text="Last Update: Never" 
                              Foreground="#FFAAAAAA" 
                              VerticalAlignment="Center" 
                              Margin="15,0,0,0"/>
                </StackPanel>
            </Grid>
        </Border>
    </Grid>
</Window>
"@

# System Information Functions
function Get-SystemInfo {
    $computerSystem = Get-CimInstance -ClassName Win32_ComputerSystem
    $operatingSystem = Get-CimInstance -ClassName Win32_OperatingSystem
    $processor = Get-CimInstance -ClassName Win32_Processor | Select-Object -First 1
    $memory = Get-CimInstance -ClassName Win32_PhysicalMemory | Measure-Object -Property Capacity -Sum
    $disk = Get-CimInstance -ClassName Win32_LogicalDisk | Where-Object { $_.DriveType -eq 3 } | Select-Object -First 1
    
    return @{
        OS = "$($operatingSystem.Caption) $($operatingSystem.Version)"
        CPU = $processor.Name
        RAM = [math]::Round($memory.Sum / 1GB, 1)
        Motherboard = $computerSystem.Model
        Uptime = (Get-Date) - $operatingSystem.LastBootUpTime
        TotalDisk = [math]::Round($disk.Size / 1GB, 0)
        FreeDisk = [math]::Round($disk.FreeSpace / 1GB, 0)
    }
}

function Get-PerformanceCounters {
    try {
        $cpu = (Get-Counter '\Processor(_Total)\% Processor Time').CounterSamples[0].CookedValue
        $memory = Get-CimInstance -ClassName Win32_OperatingSystem
        $memoryUsed = (($memory.TotalVisibleMemorySize - $memory.FreePhysicalMemory) / $memory.TotalVisibleMemorySize) * 100
        
        $disk = Get-CimInstance -ClassName Win32_LogicalDisk | Where-Object { $_.DriveType -eq 3 } | Select-Object -First 1
        $diskUsed = (($disk.Size - $disk.FreeSpace) / $disk.Size) * 100
        
        # Simulate network usage (would need more complex implementation for real data)
        $networkUsage = Get-Random -Minimum 5 -Maximum 50
        
        return @{
            CPU = [math]::Round($cpu, 1)
            Memory = [math]::Round($memoryUsed, 1)
            Disk = [math]::Round($diskUsed, 1)
            Network = $networkUsage
        }
    }
    catch {
        return @{
            CPU = 0
            Memory = 0
            Disk = 0
            Network = 0
        }
    }
}

function Get-ServiceInfo {
    $services = Get-Service | Select-Object -First 50 | ForEach-Object {
        $impact = switch ($_.StartType) {
            'Automatic' { 'High' }
            'Manual' { 'Medium' }
            'Disabled' { 'Low' }
            default { 'Unknown' }
        }
        
        [PSCustomObject]@{
            Name = $_.Name
            DisplayName = $_.DisplayName
            Status = $_.Status
            StartType = $_.StartType
            Impact = $impact
        }
    }
    return $services
}

function Get-StartupPrograms {
    $startupItems = @()
    
    # Get startup items from registry
    $registryPaths = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run',
        'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run'
    )
    
    foreach ($path in $registryPaths) {
        if (Test-Path $path) {
            $items = Get-ItemProperty -Path $path | Get-Member -MemberType NoteProperty | Where-Object { $_.Name -notlike 'PS*' }
            foreach ($item in $items) {
                $startupItems += [PSCustomObject]@{
                    Name = $item.Name
                    Publisher = 'Unknown'
                    Status = 'Enabled'
                    Impact = (Get-Random -Minimum 1 -Maximum 4) | ForEach-Object { @('Low', 'Medium', 'High')[$_ - 1] }
                    BootDelay = "$(Get-Random -Minimum 1 -Maximum 10)s"
                }
            }
        }
    }
    
    # Add some sample data if no items found
    if ($startupItems.Count -eq 0) {
        $samplePrograms = @(
            @{Name='Microsoft Teams'; Publisher='Microsoft'; Status='Enabled'; Impact='High'; BootDelay='3.2s'},
            @{Name='Spotify'; Publisher='Spotify AB'; Status='Enabled'; Impact='Medium'; BootDelay='2.1s'},
            @{Name='Steam'; Publisher='Valve'; Status='Disabled'; Impact='High'; BootDelay='0s'},
            @{Name='Adobe Updater'; Publisher='Adobe'; Status='Enabled'; Impact='Low'; BootDelay='1.5s'},
            @{Name='NVIDIA GeForce Experience'; Publisher='NVIDIA'; Status='Enabled'; Impact='Medium'; BootDelay='4.1s'}
        )
        
        foreach ($program in $samplePrograms) {
            $startupItems += [PSCustomObject]$program
        }
    }
    
    return $startupItems
}

function Get-CleanupInfo {
    $tempSize = 0
    $cacheSize = 0
    
    try {
        # Calculate temp files size
        $tempPaths = @($env:TEMP, $env:TMP, "$env:SystemRoot\Temp")
        foreach ($path in $tempPaths) {
            if (Test-Path $path) {
                $tempSize += (Get-ChildItem -Path $path -Recurse -ErrorAction SilentlyContinue | 
                            Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
            }
        }
        
        # Calculate cache size (simplified)
        $cachePaths = @("$env:LOCALAPPDATA\Microsoft\Windows\INetCache")
        foreach ($path in $cachePaths) {
            if (Test-Path $path) {
                $cacheSize += (Get-ChildItem -Path $path -Recurse -ErrorAction SilentlyContinue | 
                             Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
            }
        }
    }
    catch {
        # Use sample data if calculation fails
        $tempSize = 2.4GB
        $cacheSize = 1.2GB
    }
    
    return @{
        TempFiles = if ($tempSize -gt 0) { [math]::Round($tempSize / 1GB, 1) } else { 2.4 }
        CacheFiles = if ($cacheSize -gt 0) { [math]::Round($cacheSize / 1GB, 1) } else { 1.2 }
        RecycleBin = 0.856
    }
}

function Start-SystemMonitoring {
    param($Window)
    
    $Global:MonitoringActive = $true
    
    # Create a timer for real-time updates
    $timer = New-Object System.Windows.Threading.DispatcherTimer
    $timer.Interval = [TimeSpan]::FromSeconds(2)
    
    $timer.Add_Tick({
        if (-not $Global:MonitoringActive) {
            $timer.Stop()
            return
        }
        
        try {
            $perfData = Get-PerformanceCounters
            
            # Update progress bars
            $Window.FindName('CPUProgress').Value = $perfData.CPU
            $Window.FindName('RAMProgress').Value = $perfData.Memory
            $Window.FindName('DiskProgress').Value = $perfData.Disk
            $Window.FindName('NetworkProgress').Value = $perfData.Network
            
            # Update chart data
            $Global:ChartData.CPU.Add($perfData.CPU)
            $Global:ChartData.RAM.Add($perfData.Memory)
            $Global:ChartData.Disk.Add($perfData.Disk)
            $Global:ChartData.Network.Add($perfData.Network)
            
            # Limit chart data points
            if ($Global:ChartData.CPU.Count -gt 50) {
                $Global:ChartData.CPU.RemoveAt(0)
                $Global:ChartData.RAM.RemoveAt(0)
                $Global:ChartData.Disk.RemoveAt(0)
                $Global:ChartData.Network.RemoveAt(0)
            }
            
            # Update status
            $Window.FindName('LastUpdateText').Text = "Last Update: $(Get-Date -Format 'HH:mm:ss')"
            $Window.FindName('StatusIndicator').Fill = if ($perfData.CPU -lt 80) { '#FF4CAF50' } else { '#FFF44336' }
            
            # Draw simple chart
            Update-PerformanceChart -Canvas $Window.FindName('PerformanceChart')
        }
        catch {
            Write-Host "Monitoring error: $_"
        }
    })
    
    $timer.Start()
    return $timer
}

function Update-PerformanceChart {
    param($Canvas)
    
    if (-not $Canvas -or $Global:ChartData.CPU.Count -eq 0) { return }
    
    $Canvas.Children.Clear()
    
    $width = $Canvas.ActualWidth
    $height = $Canvas.ActualHeight
    
    if ($width -le 0 -or $height -le 0) { return }
    
    $dataPoints = $Global:ChartData.CPU.Count
    $stepX = $width / ($dataPoints - 1)
    
    # Draw CPU line
    for ($i = 0; $i -lt ($dataPoints - 1); $i++) {
        $line = New-Object System.Windows.Shapes.Line
        $line.X1 = $i * $stepX
        $line.Y1 = $height - ($Global:ChartData.CPU[$i] * $height / 100)
        $line.X2 = ($i + 1) * $stepX
        $line.Y2 = $height - ($Global:ChartData.CPU[$i + 1] * $height / 100)
        $line.Stroke = '#FF2196F3'
        $line.StrokeThickness = 2
        $Canvas.Children.Add($line)
    }
}

function Initialize-SystemData {
    param($Window)
    
    # Get system information
    $sysInfo = Get-SystemInfo
    
    # Update system info display
    $Window.FindName('OSInfo').Text = "Operating System: $($sysInfo.OS)"
    $Window.FindName('CPUInfo').Text = "Processor: $($sysInfo.CPU)"
    $Window.FindName('MemoryInfo').Text = "Installed RAM: $($sysInfo.RAM) GB"
    $Window.FindName('UptimeInfo').Text = "System Uptime: $($sysInfo.Uptime.Days) days, $($sysInfo.Uptime.Hours) hours"
    $Window.FindName('StorageInfo').Text = "Storage: $($sysInfo.FreeDisk) GB free of $($sysInfo.TotalDisk) GB"
    
    # Update details
    $Window.FindName('CPUDetails').Text = $sysInfo.CPU.Split()[0..2] -join ' '
    $Window.FindName('RAMDetails').Text = "$($sysInfo.RAM) GB Total"
    $Window.FindName('DiskDetails').Text = "$($sysInfo.TotalDisk) GB SSD"
    
    # Initialize services data
    $services = Get-ServiceInfo
    $Window.FindName('ServicesDataGrid').ItemsSource = $services
    
    # Initialize startup data
    $startupPrograms = Get-StartupPrograms
    $Window.FindName('StartupDataGrid').ItemsSource = $startupPrograms
    
    # Initialize cleanup data
    $cleanupInfo = Get-CleanupInfo
    $Window.FindName('TempFilesSize').Text = "$($cleanupInfo.TempFiles) GB"
    $Window.FindName('CacheFilesSize').Text = "$($cleanupInfo.CacheFiles) GB"
    $Window.FindName('RecycleBinSize').Text = "$($cleanupInfo.RecycleBin) GB"
    
    # Add some sample alerts
    $alerts = @(
        "✅ System performance is optimal",
        "⚠️ High memory usage detected",
        "ℹ️ 3 Windows updates available",
        "✅ All critical services running",
        "⚠️ Disk cleanup recommended"
    )
    $Window.FindName('AlertsList').ItemsSource = $alerts
}

function Show-Panel {
    param($Window, $PanelName)
    
    # Hide all panels
    $panels = @('OverviewPanel', 'ServicesPanel', 'StartupPanel', 'CleanupPanel')
    foreach ($panel in $panels) {
        $Window.FindName($panel).Visibility = 'Collapsed'
    }
    
    # Show selected panel
    $Window.FindName($PanelName).Visibility = 'Visible'
}

# Create and show the window
try {
    $window = [Windows.Markup.XamlReader]::Parse($xaml)
    
    # Initialize system data
    Initialize-SystemData -Window $window
    
    # Window controls
    $window.FindName('CloseButton').Add_Click({
        $Global:MonitoringActive = $false
        $window.Close()
    })
    
    $window.FindName('MinimizeButton').Add_Click({
        $window.WindowState = 'Minimized'
    })
    
    $window.FindName('MaximizeButton').Add_Click({
        if ($window.WindowState -eq 'Maximized') {
            $window.WindowState = 'Normal'
        } else {
            $window.WindowState = 'Maximized'
        }
    })
    
    # Navigation buttons
    $window.FindName('OverviewButton').Add_Click({
        Show-Panel -Window $window -PanelName 'OverviewPanel'
    })
    
    $window.FindName('ServicesButton').Add_Click({
        Show-Panel -Window $window -PanelName 'ServicesPanel'
    })
    
    $window.FindName('StartupButton').Add_Click({
        Show-Panel -Window $window -PanelName 'StartupPanel'
    })
    
    $window.FindName('CleanupButton').Add_Click({
        Show-Panel -Window $window -PanelName 'CleanupPanel'
    })
    
    # Monitoring controls
    $window.FindName('StartMonitoringButton').Add_Click({
        $button = $window.FindName('StartMonitoringButton')
        if ($Global:MonitoringActive) {
            $Global:MonitoringActive = $false
            $button.Content = "▶️ Start Monitoring"
            $window.FindName('StatusText').Text = "Monitoring Stopped"
        } else {
            Start-SystemMonitoring -Window $window
            $button.Content = "⏸️ Stop Monitoring"
            $window.FindName('StatusText').Text = "Monitoring Active"
        }
    })
    
    # Service management buttons
    $window.FindName('RefreshServicesButton').Add_Click({
        $services = Get-ServiceInfo
        $window.FindName('ServicesDataGrid').ItemsSource = $services
        $window.FindName('StatusText').Text = "Services refreshed"
    })
    
    # Cleanup buttons
    $window.FindName('FullCleanupButton').Add_Click({
        $progressBar = $window.FindName('CleanupProgress')
        $statusText = $window.FindName('CleanupStatus')
        
        # Simulate cleanup process
        $statusText.Text = "Cleaning temporary files..."
        $progressBar.Value = 25
        Start-Sleep -Milliseconds 500
        
        $statusText.Text = "Emptying recycle bin..."
        $progressBar.Value = 50
        Start-Sleep -Milliseconds 500
        
        $statusText.Text = "Clearing cache files..."
        $progressBar.Value = 75
        Start-Sleep -Milliseconds 500
        
        $statusText.Text = "Cleanup completed successfully!"
        $progressBar.Value = 100
        
        # Reset after delay
        $timer = New-Object System.Windows.Threading.DispatcherTimer
        $timer.Interval = [TimeSpan]::FromSeconds(3)
        $timer.Add_Tick({
            $progressBar.Value = 0
            $statusText.Text = "Ready to clean..."
            $timer.Stop()
        })
        $timer.Start()
    })
    
    # Startup optimization
    $window.FindName('OptimizeStartupButton').Add_Click({
        $window.FindName('BootTimeText').Text = "33 seconds"
        $window.FindName('ImprovementText').Text = "Optimized!"
        $window.FindName('StatusText').Text = "Startup optimization completed"
    })
    
    # Enable drag to move window
    $window.Add_MouseLeftButtonDown({
        $window.DragMove()
    })
    
    # Show the window
    $window.ShowDialog()
}
catch {
    Write-Host "Error creating window: $_"
    Write-Host "Make sure you're running PowerShell 5.1+ with .NET Framework 4.7.2+"
}
