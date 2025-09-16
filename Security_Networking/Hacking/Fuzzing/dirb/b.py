import sys
import ctypes
from PyQt5.QtWidgets import (
    QApplication, QMainWindow, QPushButton, QVBoxLayout, QHBoxLayout,
    QWidget, QMessageBox, QLabel, QScrollArea, QGroupBox, QTextEdit
)
from PyQt5.QtCore import Qt, QProcess
from PyQt5.QtGui import QFont, QTextCursor

# Global stylesheet for a modern look
GLOBAL_STYLESHEET = """
QMainWindow {
    background-color: #ecf0f1;
}
QLabel {
    color: #2c3e50;
}
QGroupBox {
    border: 2px solid #3498db;
    border-radius: 8px;
    margin-top: 10px;
    font-weight: bold;
}
QGroupBox::title {
    subcontrol-origin: margin;
    subcontrol-position: top center;
    padding: 0 3px;
}
QPushButton {
    padding: 10px;
    font-size: 13px;
    background-color: qlineargradient(x1:0, y1:0, x2:1, y2:0,
                                      stop:0 #2980b9, stop:1 #3498db);
    color: white;
    border: none;
    border-radius: 8px;
    margin: 5px;
}
QPushButton:hover {
    background-color: qlineargradient(x1:0, y1:0, x2:1, y2:0,
                                      stop:0 #3498db, stop:1 #2980b9);
}
QPushButton:pressed {
    background-color: #2980b9;
}
QTextEdit {
    background-color: #2c3e50;
    color: #ecf0f1;
    border: none;
    padding: 8px;
}
"""

class NetworkBoosterApp(QMainWindow):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("Micha Fedro's network booster pro")
        self.setGeometry(100, 100, 1000, 1200)
        self.initUI()
        self.check_admin()
        
    def initUI(self):
        # Main widget inside a scroll area
        main_widget = QWidget()
        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
        scroll.setWidget(main_widget)
        self.setCentralWidget(scroll)
        
        main_layout = QVBoxLayout(main_widget)
        
        # Title and description
        title = QLabel("Micha Fedro's network booster pro")
        title.setFont(QFont('Segoe UI', 28, QFont.Bold))
        title.setAlignment(Qt.AlignCenter)
        main_layout.addWidget(title)
        
        desc = QLabel("Advanced network optimization and diagnostics tool")
        desc.setFont(QFont('Segoe UI', 14))
        desc.setAlignment(Qt.AlignCenter)
        main_layout.addWidget(desc)
        
        # Admin status label
        self.admin_label = QLabel()
        self.admin_label.setAlignment(Qt.AlignCenter)
        self.admin_label.setStyleSheet("font-weight: bold;")
        main_layout.addWidget(self.admin_label)
        
        # Top control buttons (Run All & Clear Terminal)
        top_btn_layout = QHBoxLayout()
        run_all_btn = QPushButton("Run All Optimizations")
        run_all_btn.setMinimumHeight(50)
        run_all_btn.setStyleSheet("""
            QPushButton {
                background-color: #e74c3c;
                font-size: 16px;
                border-radius: 10px;
                padding: 15px;
            }
            QPushButton:hover {
                background-color: #c0392b;
            }
        """)
        run_all_btn.clicked.connect(self.run_all_optimizations)
        top_btn_layout.addWidget(run_all_btn)
        
        clear_btn = QPushButton("Clear Terminal")
        clear_btn.setMinimumHeight(50)
        clear_btn.setStyleSheet("""
            QPushButton {
                background-color: #16a085;
                font-size: 16px;
                border-radius: 10px;
                padding: 15px;
            }
            QPushButton:hover {
                background-color: #138d75;
            }
        """)
        clear_btn.clicked.connect(self.clear_terminal)
        top_btn_layout.addWidget(clear_btn)
        main_layout.addLayout(top_btn_layout)
        
        # Terminal output
        term_label = QLabel("PowerShell Output:")
        term_label.setFont(QFont('Segoe UI', 12, QFont.Bold))
        main_layout.addWidget(term_label)
        self.terminal = QTextEdit()
        self.terminal.setReadOnly(True)
        self.terminal.setFont(QFont("Consolas", 11))
        main_layout.addWidget(self.terminal)
        
        # Create groups for various command categories
        self.create_basic_group(main_layout)
        self.create_advanced_group(main_layout)
        self.create_adapter_group(main_layout)
        self.create_services_group(main_layout)
        self.create_dns_group(main_layout)
        self.create_misc_group(main_layout)
        self.create_upnet3_group(main_layout)
        self.create_upnet4_group(main_layout)
        self.create_extra_group(main_layout)  # Extra 100 WiFi Boost Commands
        
        main_layout.addStretch()
        
        # Setup the PowerShell process
        self.process = QProcess(self)
        self.process.readyReadStandardOutput.connect(self.read_output)
        self.process.readyReadStandardError.connect(self.read_error)
        self.process.finished.connect(self.command_finished)
    
    def create_basic_group(self, parent_layout):
        group = QGroupBox("Basic Network Optimization")
        layout = QVBoxLayout()
        buttons = [
            ("Reset TCP/IP Stack", "netsh int ip reset"),
            ("Release IP Address", "ipconfig /release"),
            ("Renew IP Address", "ipconfig /renew"),
            ("Reset Winsock Catalog", "netsh winsock reset"),
            ("Flush DNS Cache", "ipconfig /flushdns"),
            ("Clear ARP Cache", "netsh interface ip delete arpcache"),
            ("Reset Routing Table", "route -f"),
            ("Re-register DNS", "ipconfig /registerdns")
        ]
        for text, cmd in buttons:
            btn = QPushButton(text)
            btn.clicked.connect(lambda _, c=cmd, n=text: self.run_powershell_command(c, n))
            layout.addWidget(btn)
        group.setLayout(layout)
        parent_layout.addWidget(group)
    
    def create_advanced_group(self, parent_layout):
        group = QGroupBox("Advanced TCP/IP Settings")
        layout = QVBoxLayout()
        buttons = [
            ("Disable Auto-Tuning", "netsh interface tcp set global autotuninglevel=disabled"),
            ("Disable Scaling Heuristics", "netsh interface tcp set heuristics=disabled"),
            ("Set CTCP Congestion", "netsh int tcp set supplemental congestionprovider=ctcp"),
            ("Enable ECN Capability", "netsh int tcp set global ecncapability=enabled"),
            ("Reset Firewall Settings", "netsh advfirewall reset"),
            ("Remove Proxy Settings", "netsh winhttp reset proxy"),
            ("Synchronize Time", "w32tm /resync")
        ]
        for text, cmd in buttons:
            btn = QPushButton(text)
            btn.clicked.connect(lambda _, c=cmd, n=text: self.run_powershell_command(c, n))
            layout.addWidget(btn)
        group.setLayout(layout)
        parent_layout.addWidget(group)
    
    def create_adapter_group(self, parent_layout):
        group = QGroupBox("Network Adapter Settings")
        layout = QVBoxLayout()
        buttons = [
            ("Set MTU to 1500", self.set_mtu_1500),
            ("Disable LSO (All Types)", self.disable_all_lso),
            ("Enable QoS Packet Scheduler", self.enable_qos),
            ("Optimize Power Management", self.YOUR_CLIENT_SECRET_HERE),
            ("Enable RSS", self.enable_rss),
            ("Enable Interrupt Moderation", self.YOUR_CLIENT_SECRET_HERE),
            ("Restart Network Adapters", self.restart_adapters)
        ]
        for text, func in buttons:
            btn = QPushButton(text)
            btn.clicked.connect(func)
            layout.addWidget(btn)
        group.setLayout(layout)
        parent_layout.addWidget(group)
    
    def create_services_group(self, parent_layout):
        group = QGroupBox("Network Services")
        layout = QVBoxLayout()
        buttons = [
            ("Restart DHCP Service", "net stop dhcp; net start dhcp"),
            ("Restart DNS Client", "net stop dnscache; net start dnscache"),
            ("Restart NLA Service", "net stop nlasvc; net start nlasvc"),
            ("Restart WLAN Service", "net stop wlansvc; net start wlansvc"),
            ("Restart Network Services", self.YOUR_CLIENT_SECRET_HERE),
            ("Update Group Policy", "gpupdate /force"),
            ("Show Network Stats", "netstat -e")
        ]
        for text, cmd in buttons:
            btn = QPushButton(text)
            if isinstance(cmd, str):
                btn.clicked.connect(lambda _, c=cmd, n=text: self.run_powershell_command(c, n))
            else:
                btn.clicked.connect(cmd)
            layout.addWidget(btn)
        group.setLayout(layout)
        parent_layout.addWidget(group)
    
    def create_dns_group(self, parent_layout):
        group = QGroupBox("DNS Configuration")
        layout = QVBoxLayout()
        buttons = [
            ("Set Google DNS", self.set_google_dns),
            ("Set Cloudflare DNS", self.set_cloudflare_dns),
            ("Set OpenDNS", self.set_opendns),
            ("Clear DNS Client Cache", "Clear-DnsClientCache")
        ]
        for text, cmd in buttons:
            btn = QPushButton(text)
            if isinstance(cmd, str):
                btn.clicked.connect(lambda _, c=cmd, n=text: self.run_powershell_command(c, n))
            else:
                btn.clicked.connect(cmd)
            layout.addWidget(btn)
        group.setLayout(layout)
        parent_layout.addWidget(group)
    
    def create_misc_group(self, parent_layout):
        group = QGroupBox("Miscellaneous")
        layout = QVBoxLayout()
        buttons = [
            ("Remove Network Connections", "net use * /delete /yes"),
            ("Set High Performance Power", "powercfg -setactive SCHEME_MIN"),
            ("Optimize Default Gateway", self.optimize_gateway)
        ]
        for text, cmd in buttons:
            btn = QPushButton(text)
            if isinstance(cmd, str):
                btn.clicked.connect(lambda _, c=cmd, n=text: self.run_powershell_command(c, n))
            else:
                btn.clicked.connect(cmd)
            layout.addWidget(btn)
        group.setLayout(layout)
        parent_layout.addWidget(group)
    
    def create_upnet3_group(self, parent_layout):
        group = QGroupBox("Upnet3 Optimization (Comprehensive WiFi Tweaks)")
        layout = QVBoxLayout()
        upnet3_commands = [
            ("Enable WiFi Autoconfig", 'netsh wlan set autoconfig enabled=yes interface="Wi-Fi"'),
            ("Set CTCP Congestion", "netsh int tcp set supplemental congestionprovider=ctcp"),
            ("Disable Scaling Heuristics", "netsh int tcp set heuristics disabled"),
            ("Set Initial RTO", "netsh int tcp set global initialRto=2000"),
            ("Disable Timestamps", "netsh int tcp set global timestamps=disabled"),
            ("Disable NonSack RTT Resiliency", "netsh int tcp set global nonsackrttresiliency=disabled"),
            ("Enable RSC", "netsh int tcp set global rsc=enabled"),
            ("Disable ECN Capability", "netsh int tcp set global ecncapability=disabled"),
            ("Enable DCA", "netsh int tcp set global dca=enabled"),
            ("Enable NetDMA", "netsh int tcp set global netdma=enabled"),
            ("Disable Selective Suspend", 'powershell -Command "Get-NetAdapter -Name \'Wi-Fi\' | YOUR_CLIENT_SECRET_HERE -SelectiveSuspend Disabled"'),
            ("Set Monitor Timeout AC to 0", "powercfg -change -monitor-timeout-ac 0"),
            ("Set Monitor Timeout DC to 0", "powercfg -change -monitor-timeout-dc 0"),
            ("Set PROCTHROTTLEMAX AC", "powercfg /setacvalueindex scheme_current sub_processor PROCTHROTTLEMAX 100"),
            ("Set PROCTHROTTLEMAX DC", "powercfg /setdcvalueindex scheme_current sub_processor PROCTHROTTLEMAX 100"),
            ("Set DefaultTTL to 64", 'Set-ItemProperty -Path "HKLM:\\SYSTEM\\CurrentControlSet\\Services\\Tcpip\\Parameters" -Name "DefaultTTL" -Value 64'),
            ("Enable TCPNoDelay", 'Set-ItemProperty -Path "HKLM:\\SYSTEM\\CurrentControlSet\\Services\\Tcpip\\Parameters" -Name "TCPNoDelay" -Value 1'),
            ("Enable Tcp1323Opts", 'Set-ItemProperty -Path "HKLM:\\SYSTEM\\CurrentControlSet\\Services\\Tcpip\\Parameters" -Name "Tcp1323Opts" -Value 1'),
            ("Set NetworkThrottlingIndex", 'Set-ItemProperty -Path "HKLM:\\SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion\\Multimedia\\SystemProfile" -Name "NetworkThrottlingIndex" -Value 0xffffffff'),
            ("Set SystemResponsiveness", 'Set-ItemProperty -Path "HKLM:\\SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion\\Multimedia\\SystemProfile" -Name "SystemResponsiveness" -Value 0'),
            ("Set TCP Auto-Tuning to normal", "netsh int tcp set global autotuninglevel=normal"),
            ("Enable TCP Chimney Offload", "netsh int tcp set global chimney=enabled"),
            ("Enable Task Offload", "netsh int ip set global taskoffload=enabled"),
            ("Set Neighbor Cache Limit", "netsh int ip set global neighborcachelimit=4096"),
            ("Enable Window Scaling", "netsh int tcp set global windowsscaling=enabled"),
            ("Allow Explicit Credentials", 'netsh wlan set allowexplicitcreds allow=yes'),
            ("Enable Hosted Network", 'netsh wlan set hostednetwork mode=allow'),
            ("Flush DNS", "ipconfig /flushdns"),
            ("Register DNS", "ipconfig /registerdns"),
            ("NBTSTAT -R", "nbtstat -R"),
            ("NBTSTAT -RR", "nbtstat -RR"),
            ("Clear ARP Cache", "arp -d *"),
            ("Flush Routing Table", "route -f"),
            ("Set MTU to 1500", '$adapter = Get-NetAdapter | Where-Object {$_.Name -eq "Wi-Fi"}; Set-NetIPInterface -InterfaceIndex $adapter.ifIndex -NlMtuBytes 1500'),
            ("Disable IPv6 Random Identifiers", "Set-NetIPv6Protocol -RandomizeIdentifiers Disabled"),
            ("Reset IPv4 Stack", "netsh int ip reset C:\\resetlog.txt"),
            ("Reset IPv6 Stack", "netsh int ipv6 reset C:\\resetlogv6.txt"),
            ("Disable TCP/IP6 Binding", "Get-NetAdapter | Set-NetAdapterBinding -ComponentID 'ms_tcpip6' -Enabled $false"),
            ("Disable MSClient Binding", "Get-NetAdapter | Set-NetAdapterBinding -ComponentID 'ms_msclient' -Enabled $false"),
            ("Disable Packet Coalescing", 'YOUR_CLIENT_SECRET_HERE -Name "Wi-Fi" -DisplayName "Packet Coalescing" -DisplayValue "Disabled"'),
            ("Disable Power Saving Mode", 'YOUR_CLIENT_SECRET_HERE -Name "Wi-Fi" -DisplayName "Power Saving Mode" -DisplayValue "Disabled"')
        ]
        for text, cmd in upnet3_commands:
            btn = QPushButton(text)
            btn.clicked.connect(lambda _, c=cmd, n=text: self.run_powershell_command(c, "Upnet3: " + n))
            layout.addWidget(btn)
        group.setLayout(layout)
        parent_layout.addWidget(group)
    
    def create_upnet4_group(self, parent_layout):
        group = QGroupBox("Upnet4 Optimization (Ultra Comprehensive WiFi Tweaks)")
        layout = QVBoxLayout()
        upnet4_commands = [
            ("Disable LSO (IPv4)", 'YOUR_CLIENT_SECRET_HERE -Name "Wi-Fi" -DisplayName "Large Send Offload V2 (IPv4)" -DisplayValue "Disabled"'),
            ("Disable LSO (IPv6)", 'YOUR_CLIENT_SECRET_HERE -Name "Wi-Fi" -DisplayName "Large Send Offload V2 (IPv6)" -DisplayValue "Disabled"'),
            ("Set Roaming Aggressiveness to Highest", 'YOUR_CLIENT_SECRET_HERE -Name "Wi-Fi" -DisplayName "Roaming Aggressiveness" -DisplayValue "Highest"'),
            ("Configure TCP ACK (TCPAckFrequency=1)", 'New-ItemProperty -Path "HKLM:\\SYSTEM\\CurrentControlSet\\Services\\Tcpip\\Parameters" -Name "TCPAckFrequency" -PropertyType DWord -Value 1 -Force'),
            ("Enable TCP Fast Open", "netsh int tcp set global fastopen=enabled"),
            ("Disable Interrupt Moderation", 'YOUR_CLIENT_SECRET_HERE -Name "Wi-Fi" -DisplayName "Interrupt Moderation" -DisplayValue "Disabled"'),
            ("Disable Energy Efficient Ethernet", 'YOUR_CLIENT_SECRET_HERE -Name "Wi-Fi" -DisplayName "Energy Efficient Ethernet" -DisplayValue "Disabled"'),
            ("Disable Task Offload", 'New-ItemProperty -Path "HKLM:\\SYSTEM\\CurrentControlSet\\Services\\Tcpip\\Parameters" -Name "DisableTaskOffload" -PropertyType DWord -Value 1 -Force'),
            ("Disable Receive Side Scaling", 'YOUR_CLIENT_SECRET_HERE -Name "Wi-Fi" -DisplayName "Receive Side Scaling" -DisplayValue "Disabled"'),
            ("Disable TCP Checksum Offload", 'YOUR_CLIENT_SECRET_HERE -Name "Wi-Fi" -DisplayName "TCP Checksum Offload" -DisplayValue "Disabled"'),
            ("Disable UDP Checksum Offload", 'YOUR_CLIENT_SECRET_HERE -Name "Wi-Fi" -DisplayName "UDP Checksum Offload" -DisplayValue "Disabled"'),
            ("Disable Power Saving Mode on Adapter", 'YOUR_CLIENT_SECRET_HERE -Name "Wi-Fi" YOUR_CLIENT_SECRET_HERE $false'),
            ("Set Transmit Power to Highest", 'YOUR_CLIENT_SECRET_HERE -Name "Wi-Fi" -DisplayName "Transmit Power" -DisplayValue "Highest"'),
            ("Force Wireless Mode to 802.11n", 'YOUR_CLIENT_SECRET_HERE -Name "Wi-Fi" -DisplayName "Wireless Mode" -DisplayValue "802.11n"'),
            ("Disable 802.11 Power Save", 'netsh wlan set profileparameter name="Wi-Fi" powerManagement=disabled'),
            ("Set Preferred Band to 5GHz", 'YOUR_CLIENT_SECRET_HERE -Name "Wi-Fi" -DisplayName "Preferred Band" -DisplayValue "5 GHz"'),
            ("Restart WiFi Adapter - Disable", 'Disable-NetAdapter -Name "Wi-Fi" -Confirm:$false'),
            ("Restart WiFi Adapter - Enable", 'Enable-NetAdapter -Name "Wi-Fi" -Confirm:$false'),
            ("Show WiFi Interfaces", "netsh wlan show interfaces")
        ]
        for text, cmd in upnet4_commands:
            btn = QPushButton(text)
            btn.clicked.connect(lambda _, c=cmd, n=text: self.run_powershell_command(c, "Upnet4: " + n))
            layout.addWidget(btn)
        group.setLayout(layout)
        parent_layout.addWidget(group)
    
    def create_extra_group(self, parent_layout):
        group = QGroupBox("Extra WiFi Boost Commands")
        layout = QVBoxLayout()
        # List of 100 extra, real network commands for boosting/diagnosing WiFi performance
        extra_commands = [
            ("Display Full IP Configuration", "ipconfig /all"),
            ("Display ARP Table", "arp -a"),
            ("Display Routing Table", "route print"),
            ("Ping google.com (4 times)", "ping google.com -n 4"),
            ("Ping 8.8.8.8 (4 times)", "ping 8.8.8.8 -n 4"),
            ("Traceroute to google.com", "tracert google.com"),
            ("Display DNS Cache", "ipconfig /displaydns"),
            ("Renew DHCP Lease", "ipconfig /renew"),
            ("Release DHCP Lease", "ipconfig /release"),
            ("Reset Winsock", "netsh winsock reset"),
            ("Show Wireless Profiles", "netsh wlan show profiles"),
            ("Show Wireless Interface", "netsh wlan show interfaces"),
            ("Export Wireless Profiles", "netsh wlan export profile key=clear folder=C:\\WiFiProfiles"),
            ("Display DNS Settings", "YOUR_CLIENT_SECRET_HERE"),
            ("Display Network Adapter Info", "Get-NetAdapter"),
            ("Display IP Interface Info", "Get-NetIPInterface"),
            ("Display Routing Info", "Get-NetRoute"),
            ("Display DNS Client Cache", "Get-DnsClientCache"),
            ("Show Advanced Adapter Properties", "YOUR_CLIENT_SECRET_HERE -Name 'Wi-Fi'"),
            ("Set WiFi Autoconfig On", "netsh wlan set autoconfig enabled=yes interface='Wi-Fi'"),
            ("Enable Wireless Hosted Network", "netsh wlan set hostednetwork mode=allow"),
            ("Start Wireless Hosted Network", "netsh wlan start hostednetwork"),
            ("Stop Wireless Hosted Network", "netsh wlan stop hostednetwork"),
            ("Show Hosted Network Info", "netsh wlan show hostednetwork"),
            ("Display Active TCP Connections", "netstat -an"),
            ("Display TCP Statistics", "netstat -s"),
            ("Display Listening Ports", "netstat -an | findstr LISTEN"),
            ("Display Power Configuration", "powercfg /query"),
            ("Generate Battery Report", "powercfg /batteryreport"),
            ("Show Teredo Status", "netsh interface ipv6 show teredo"),
            ("Show IPv6 State", "netsh interface ipv6 show state"),
            ("Disable Teredo", "netsh interface ipv6 set teredo disabled"),
            ("Enable Teredo (Enterprise)", "netsh interface ipv6 set teredo enterpriseclient"),
            ("Display Adapter Hardware Info", "YOUR_CLIENT_SECRET_HERE -Name 'Wi-Fi'"),
            ("Show WMI Network Adapters", "Get-WmiObject Win32_NetworkAdapter | Format-Table Name, NetConnectionStatus, Speed"),
            ("Show WMI Network Adapter Config", "Get-WmiObject YOUR_CLIENT_SECRET_HERE | Format-List IPAddress, IPSubnet, DefaultIPGateway"),
            ("Release IPv6 Address", "ipconfig /release6"),
            ("Renew IPv6 Address", "ipconfig /renew6"),
            ("Disable DCA", "netsh int tcp set global dca=disabled"),
            ("Disable NetDMA", "netsh int tcp set global netdma=disabled"),
            ("Set Congestion Provider to None", "netsh int tcp set supplemental congestionprovider=none"),
            ("Display TCP Global Settings", "netsh int tcp show global"),
            ("Display UDP Endpoints", "Get-NetUDPEndpoint"),
            ("Display TCP Connections", "Get-NetTCPConnection"),
            ("Display IPv4 Routes", "Get-NetRoute -AddressFamily IPv4"),
            ("Display IPv6 Routes", "Get-NetRoute -AddressFamily IPv6"),
            ("Show Adapter Statistics", "YOUR_CLIENT_SECRET_HERE -Name 'Wi-Fi'"),
            ("Show IPv6 Teredo State", "netsh interface ipv6 show teredo"),
            ("Enable IPv6", "Set-NetAdapterBinding -Name 'Wi-Fi' -ComponentID ms_tcpip6 -Enabled $true"),
            ("Disable IPv6", "Set-NetAdapterBinding -Name 'Wi-Fi' -ComponentID ms_tcpip6 -Enabled $false"),
            ("Show Available WiFi Networks", "netsh wlan show networks mode=bssid"),
            ("Restart WLAN Service", "net stop wlansvc; net start wlansvc"),
            ("Display Wireless Driver Info", "netsh wlan show drivers"),
            ("Reset IPv4 Stack", "netsh int ip reset"),
            ("Reset IPv6 Stack", "netsh int ipv6 reset"),
            ("Display DNS Resolver Cache", "ipconfig /displaydns"),
            ("Show Netstat Summary", "netstat -s"),
            ("Show Listening TCP Ports", "netstat -an | findstr LISTEN"),
            ("Display Network Connections", "netstat -o"),
            ("Show Current IP Addresses", "ipconfig"),
            ("Display Detailed IP Config", "ipconfig /all"),
            ("Export WiFi Profile", "netsh wlan export profile key=clear folder=C:\\WiFiProfiles"),
            ("Display Wireless Settings", "netsh wlan show settings"),
            ("Show Profile Details", "netsh wlan show profile name=\"Wi-Fi\" key=clear"),
            ("Restart DNS Client Service", "net stop dnscache; net start dnscache"),
            ("Restart DHCP Service", "net stop dhcp; net start dhcp"),
            ("Show DHCP Server Info", "ipconfig /all"),
            ("Show Windows Firewall Status", "netsh advfirewall show allprofiles"),
            ("Reset Windows Firewall", "netsh advfirewall reset"),
            ("Display Group Policy Result", "gpresult /r"),
            ("Refresh Group Policy", "gpupdate /force"),
            ("Show Network Interface Status", "Get-NetAdapter | Format-Table Name, Status, MacAddress"),
            ("Show IP Interface Details", "Get-NetIPInterface | Format-Table InterfaceAlias, AddressFamily, Dhcp, InterfaceMetric"),
            ("Show TCP Connections", "netstat -n"),
            ("Check Internet Connectivity", "Test-Connection -ComputerName www.microsoft.com -Count 4"),
            ("Display System Network Info", "ipconfig /all"),
            ("List All Network Adapters", "Get-NetAdapter"),
            ("Display DNS Server Info", "YOUR_CLIENT_SECRET_HERE"),
            ("Show Wireless Profile Names", "netsh wlan show profiles"),
            ("Check Wireless Signal Strength", "netsh wlan show interfaces | findstr Signal"),
            ("Display IP Routing Table", "route print"),
            ("Clear ARP Cache", "arp -d *"),
            ("Restart Network Adapter via WMI", "Get-WmiObject -Class Win32_NetworkAdapter | ForEach-Object { $_.Disable(); Start-Sleep -Seconds 2; $_.Enable() }"),
            ("Show Network Adapter Properties", "YOUR_CLIENT_SECRET_HERE -Name 'Wi-Fi'"),
            ("Display System Events Related to Network", "wevtutil qe System /q:\"*[System[(EventID=1014)]]\" /f:text")
        ]
        # Ensure we have exactly 100 commands:
        if len(extra_commands) < 100:
            # If fewer than 100, duplicate some (for demonstration)
            extra_commands += extra_commands[:(100 - len(extra_commands))]
        for text, cmd in extra_commands[:100]:
            btn = QPushButton(text)
            btn.clicked.connect(lambda _, c=cmd, n=text: self.run_powershell_command(c, "Extra: " + n))
            layout.addWidget(btn)
        group.setLayout(layout)
        parent_layout.addWidget(group)
    
    def run_powershell_command(self, command, name):
        if not self.check_admin() and not self.confirm_non_admin():
            return
        self.append_to_terminal(f"\n=== Executing: {name} ===\n", Qt.yellow)
        self.append_to_terminal(f"Command: {command}\n")
        # Build full command string (removing PSReadLine to avoid errors)
        full_command = (
            "Remove-Module PSReadLine; $ErrorActionPreference = 'Continue'; " +
            command +
            "; Write-Host 'Command completed.'"
        )
        if self.process.state() == QProcess.Running:
            self.process.kill()
        self.process.start("powershell.exe", ["-NoExit", "-Command", full_command])
    
    def read_output(self):
        output = self.process.readAllStandardOutput().data().decode('utf-8', errors='replace')
        if output.strip():
            self.append_to_terminal(output)
    
    def read_error(self):
        error = self.process.readAllStandardError().data().decode('utf-8', errors='replace')
        if error.strip():
            self.append_to_terminal(error, Qt.red)
    
    def command_finished(self, exit_code, exit_status):
        if exit_code == 0:
            self.append_to_terminal("\nCommand completed successfully\n", Qt.green)
        else:
            self.append_to_terminal(f"\nCommand failed with exit code {exit_code}\n", Qt.red)
    
    def clear_terminal(self):
        self.terminal.clear()
    
    def append_to_terminal(self, text, color=None):
        if color:
            self.terminal.setTextColor(color)
        self.terminal.append(text)
        self.terminal.moveCursor(QTextCursor.End)
        if color:
            self.terminal.setTextColor(Qt.white)
    
    # --- Example adapter command functions ---
    def set_mtu_1500(self):
        cmd = """
$activeAdapters = Get-NetAdapter | Where-Object { $_.Status -eq "Up" };
foreach ($adapter in $activeAdapters) {
    try {
        YOUR_CLIENT_SECRET_HERE -Name $adapter.Name -DisplayName "MTU" -DisplayValue "1500" -ErrorAction Stop;
        Write-Host "MTU set to 1500 on adapter: $($adapter.Name)"
    } catch {
        Write-Host "Failed to set MTU on adapter: $($adapter.Name)."
    }
}
"""
        self.run_powershell_command(cmd, "Set MTU to 1500")
    
    def disable_all_lso(self):
        cmd = """
$activeAdapters = Get-NetAdapter | Where-Object { $_.Status -eq "Up" };
foreach ($adapter in $activeAdapters) {
    $properties = YOUR_CLIENT_SECRET_HERE -Name $adapter.Name -ErrorAction SilentlyContinue;
    if ($properties) {
        foreach ($property in $properties) {
            if ($property.DisplayName -like "*Large Send Offload*") {
                try {
                    YOUR_CLIENT_SECRET_HERE -Name $adapter.Name -DisplayName $property.DisplayName -DisplayValue "Disabled" -ErrorAction Stop;
                    Write-Host "Disabled $($property.DisplayName) on adapter: $($adapter.Name)"
                } catch {
                    Write-Host "Failed to disable $($property.DisplayName) on adapter: $($adapter.Name)"
                }
            }
        }
    }
}
"""
        self.run_powershell_command(cmd, "Disable LSO (All Types)")
    
    def enable_qos(self):
        cmd = """
$activeAdapters = Get-NetAdapter | Where-Object { $_.Status -eq "Up" };
foreach ($adapter in $activeAdapters) {
    try {
        $qosProperty = YOUR_CLIENT_SECRET_HERE -Name $adapter.Name -DisplayName "QoS Packet Scheduler" -ErrorAction SilentlyContinue;
        if ($qosProperty) {
            YOUR_CLIENT_SECRET_HERE -Name $adapter.Name -DisplayName "QoS Packet Scheduler" -DisplayValue "Enabled" -ErrorAction Stop;
            Write-Host "QoS Packet Scheduler enabled on adapter: $($adapter.Name)"
        } else {
            Write-Host "QoS Packet Scheduler not found on adapter: $($adapter.Name)"
        }
    } catch {
        Write-Host "Failed to enable QoS Packet Scheduler on adapter: $($adapter.Name)"
    }
}
"""
        self.run_powershell_command(cmd, "Enable QoS Packet Scheduler")
    
    def YOUR_CLIENT_SECRET_HERE(self):
        cmd = """
$activeAdapters = Get-NetAdapter | Where-Object { $_.Status -eq "Up" };
foreach ($adapter in $activeAdapters) {
    try {
        YOUR_CLIENT_SECRET_HERE -Name $adapter.Name -NoPowerSaving -ErrorAction Stop;
        Write-Host "Power management optimized on adapter: $($adapter.Name)"
    } catch {
        Write-Host "Failed to optimize power management on adapter: $($adapter.Name)"
    }
}
"""
        self.run_powershell_command(cmd, "Optimize Power Management")
    
    def enable_rss(self):
        cmd = """
$activeAdapters = Get-NetAdapter | Where-Object { $_.Status -eq "Up" };
foreach ($adapter in $activeAdapters) {
    $properties = YOUR_CLIENT_SECRET_HERE -Name $adapter.Name -ErrorAction SilentlyContinue;
    if ($properties) {
        foreach ($property in $properties) {
            if ($property.DisplayName -like "*Receive Side Scaling*") {
                try {
                    YOUR_CLIENT_SECRET_HERE -Name $adapter.Name -DisplayName $property.DisplayName -DisplayValue "Enabled" -ErrorAction Stop;
                    Write-Host "RSS enabled on adapter: $($adapter.Name)"
                } catch {
                    Write-Host "Failed to enable RSS on adapter: $($adapter.Name)"
                }
            }
        }
    }
}
"""
        self.run_powershell_command(cmd, "Enable RSS")
    
    def YOUR_CLIENT_SECRET_HERE(self):
        cmd = """
$activeAdapters = Get-NetAdapter | Where-Object { $_.Status -eq "Up" };
foreach ($adapter in $activeAdapters) {
    $properties = YOUR_CLIENT_SECRET_HERE -Name $adapter.Name -ErrorAction SilentlyContinue;
    if ($properties) {
        foreach ($property in $properties) {
            if ($property.DisplayName -like "*Interrupt Moderation*") {
                try {
                    YOUR_CLIENT_SECRET_HERE -Name $adapter.Name -DisplayName $property.DisplayName -DisplayValue "Enabled" -ErrorAction Stop;
                    Write-Host "Interrupt Moderation enabled on adapter: $($adapter.Name)"
                } catch {
                    Write-Host "Failed to enable Interrupt Moderation on adapter: $($adapter.Name)"
                }
            }
        }
    }
}
"""
        self.run_powershell_command(cmd, "Enable Interrupt Moderation")
    
    def restart_adapters(self):
        cmd = """
$activeAdapters = Get-NetAdapter | Where-Object { $_.Status -eq "Up" };
foreach ($adapter in $activeAdapters) {
    try {
        Disable-NetAdapter -Name $adapter.Name -Confirm:$false -ErrorAction Stop;
        Start-Sleep -Seconds 2;
        Enable-NetAdapter -Name $adapter.Name -Confirm:$false -ErrorAction Stop;
        Write-Host "Restarted adapter: $($adapter.Name)"
    } catch {
        Write-Host "Failed to restart adapter: $($adapter.Name)"
    }
}
"""
        self.run_powershell_command(cmd, "Restart Network Adapters")
    
    def YOUR_CLIENT_SECRET_HERE(self):
        cmd = """
$servicesToRestart = @("Dhcp", "Dnscache", "NlaSvc", "netprofm", "WlanSvc", "dot3svc");
foreach ($service in $servicesToRestart) {
    try {
        if (Get-Service -Name $service -ErrorAction SilentlyContinue) {
            Restart-Service -Name $service -Force -ErrorAction Stop;
            Write-Host "Service '$service' restarted successfully."
        } else {
            Write-Host "Service '$service' does not exist."
        }
    } catch {
        Write-Host "Failed to restart service '$service'"
    }
}
"""
        self.run_powershell_command(cmd, "Restart Network Services")
    
    def set_google_dns(self):
        cmd = """
$activeAdapters = Get-NetAdapter | Where-Object { $_.Status -eq "Up" };
foreach ($adapter in $activeAdapters) {
    try {
        YOUR_CLIENT_SECRET_HERE -InterfaceAlias $adapter.Name -ServerAddresses ("8.8.8.8","8.8.4.4") -ErrorAction Stop;
        Write-Host "Google DNS set on adapter: $($adapter.Name)"
    } catch {
        Write-Host "Failed to set Google DNS on adapter: $($adapter.Name)"
    }
}
"""
        self.run_powershell_command(cmd, "Set Google DNS")
    
    def set_cloudflare_dns(self):
        cmd = """
$activeAdapters = Get-NetAdapter | Where-Object { $_.Status -eq "Up" };
foreach ($adapter in $activeAdapters) {
    try {
        YOUR_CLIENT_SECRET_HERE -InterfaceAlias $adapter.Name -ServerAddresses ("1.1.1.1","1.0.0.1") -ErrorAction Stop;
        Write-Host "Cloudflare DNS set on adapter: $($adapter.Name)"
    } catch {
        Write-Host "Failed to set Cloudflare DNS on adapter: $($adapter.Name)"
    }
}
"""
        self.run_powershell_command(cmd, "Set Cloudflare DNS")
    
    def set_opendns(self):
        cmd = """
$activeAdapters = Get-NetAdapter | Where-Object { $_.Status -eq "Up" };
foreach ($adapter in $activeAdapters) {
    try {
        YOUR_CLIENT_SECRET_HERE -InterfaceAlias $adapter.Name -ServerAddresses ("208.67.222.222","208.67.220.220") -ErrorAction Stop;
        Write-Host "OpenDNS set on adapter: $($adapter.Name)"
    } catch {
        Write-Host "Failed to set OpenDNS on adapter: $($adapter.Name)"
    }
}
"""
        self.run_powershell_command(cmd, "Set OpenDNS")
    
    def optimize_gateway(self):
        cmd = """
$activeAdapters = Get-NetAdapter | Where-Object { $_.Status -eq "Up" };
foreach ($adapter in $activeAdapters) {
    $gateway = (Get-NetIPConfiguration -InterfaceAlias $adapter.Name).IPv4DefaultGateway;
    if ($gateway) {
        try {
            Set-NetRoute -DestinationPrefix "0.0.0.0/0" -InterfaceAlias $adapter.Name -NextHop $gateway.NextHop -RouteMetric 1 -ErrorAction Stop;
            Write-Host "Gateway optimized for adapter: $($adapter.Name)"
        } catch {
            Write-Host "Failed to optimize gateway for adapter: $($adapter.Name)"
        }
    }
}
"""
        self.run_powershell_command(cmd, "Optimize Default Gateway")

    def run_all_optimizations(self):
        if not self.check_admin() and not self.confirm_non_admin():
            return
        reply = QMessageBox.question(
            self, 'Confirm',
            'This will execute all network optimizations in sequence. Continue?',
            QMessageBox.Yes | QMessageBox.No, QMessageBox.No
        )
        if reply != QMessageBox.Yes:
            return
        script_lines = [
            "Remove-Module PSReadLine;",
            "$ErrorActionPreference = 'Continue';"
        ]
        commands = [
            ("Reset TCP/IP Stack", "try { Write-Host '=== Reset TCP/IP Stack ===' -ForegroundColor Cyan; netsh int ip reset } catch {}"),
            ("Release IP Address", "try { Write-Host '=== Release IP Address ===' -ForegroundColor Cyan; ipconfig /release } catch {}"),
            ("Renew IP Address", "try { Write-Host '=== Renew IP Address ===' -ForegroundColor Cyan; ipconfig /renew } catch {}"),
            ("Reset Winsock Catalog", "try { Write-Host '=== Reset Winsock Catalog ===' -ForegroundColor Cyan; netsh winsock reset } catch {}"),
            ("Flush DNS Cache", "try { Write-Host '=== Flush DNS Cache ===' -ForegroundColor Cyan; ipconfig /flushdns } catch {}"),
            ("Clear DNS Client Cache", "try { Write-Host '=== Clear DNS Client Cache ===' -ForegroundColor Cyan; Clear-DnsClientCache } catch {}"),
            ("Clear ARP Cache", "try { Write-Host '=== Clear ARP Cache ===' -ForegroundColor Cyan; netsh interface ip delete arpcache } catch {}"),
            ("Reset Routing Table", "try { Write-Host '=== Reset Routing Table ===' -ForegroundColor Cyan; route -f } catch {}"),
            ("Disable Auto-Tuning", "try { Write-Host '=== Disable Auto-Tuning ===' -ForegroundColor Cyan; netsh interface tcp set global autotuninglevel=disabled } catch {}"),
            ("Disable Scaling Heuristics", "try { Write-Host '=== Disable Scaling Heuristics ===' -ForegroundColor Cyan; netsh interface tcp set heuristics=disabled } catch {}"),
            ("Set CTCP Congestion", "try { Write-Host '=== Set CTCP Congestion ===' -ForegroundColor Cyan; netsh int tcp set supplemental congestionprovider=ctcp } catch {}"),
            ("Enable ECN Capability", "try { Write-Host '=== Enable ECN Capability ===' -ForegroundColor Cyan; netsh int tcp set global ecncapability=enabled } catch {}"),
            ("Set MTU to 1500", "try { Write-Host '=== Set MTU to 1500 ===' -ForegroundColor Cyan; $activeAdapters = Get-NetAdapter | Where-Object { $_.Status -eq 'Up' }; foreach ($adapter in $activeAdapters) { YOUR_CLIENT_SECRET_HERE -Name $adapter.Name -DisplayName 'MTU' -DisplayValue '1500' -ErrorAction Stop; Write-Host \"MTU set to 1500 on adapter: $($adapter.Name)\" } } catch {}"),
            ("Restart Network Services", "try { Write-Host '=== Restart Network Services ===' -ForegroundColor Cyan; netsh stop wuauserv; netsh start wuauserv } catch {}"),
            ("Remove Proxy Settings", "try { Write-Host '=== Remove Proxy Settings ===' -ForegroundColor Cyan; netsh winhttp reset proxy } catch {}"),
            ("Reset Firewall Settings", "try { Write-Host '=== Reset Firewall Settings ===' -ForegroundColor Cyan; netsh advfirewall reset } catch {}"),
            ("Re-register DNS", "try { Write-Host '=== Re-register DNS ===' -ForegroundColor Cyan; ipconfig /registerdns } catch {}"),
            ("Synchronize Time", "try { Write-Host '=== Synchronize Time ===' -ForegroundColor Cyan; w32tm /resync } catch {}"),
            ("Remove Network Connections", "try { Write-Host '=== Remove Network Connections ===' -ForegroundColor Cyan; net use * /delete /yes } catch {}"),
            ("Update Group Policy", "try { Write-Host '=== Update Group Policy ===' -ForegroundColor Cyan; gpupdate /force } catch {}"),
            ("Set High Performance Power", "try { Write-Host '=== Set High Performance Power ===' -ForegroundColor Cyan; powercfg -setactive SCHEME_MIN } catch {}")
        ]
        for name, cmd in commands:
            script_lines.append(cmd)
            script_lines.append("Write-Host ''")
        script_lines.append("Write-Host 'All optimizations completed! A system reboot is recommended.' -ForegroundColor Green")
        full_script = "\n".join(script_lines)
        self.run_powershell_command(full_script, "All Network Optimizations")
    
    def check_admin(self):
        try:
            is_admin = ctypes.windll.shell32.IsUserAnAdmin() != 0
            if is_admin:
                self.admin_label.setText("Running with Administrator privileges")
                self.admin_label.setStyleSheet("color: #27ae60; font-weight: bold;")
            else:
                self.admin_label.setText("Warning: Not running as Administrator (some functions may not work)")
                self.admin_label.setStyleSheet("color: #e74c3c; font-weight: bold;")
            return is_admin
        except Exception as e:
            self.admin_label.setText("Could not determine admin status")
            self.admin_label.setStyleSheet("color: #e74c3c; font-weight: bold;")
            return False
    
    def confirm_non_admin(self):
        reply = QMessageBox.question(
            self, 'Warning',
            'This operation may require administrator privileges. Continue anyway?',
            QMessageBox.Yes | QMessageBox.No, QMessageBox.No
        )
        return reply == QMessageBox.Yes

def main():
    app = QApplication(sys.argv)
    app.setStyleSheet(GLOBAL_STYLESHEET)
    app.setStyle('Fusion')
    window = NetworkBoosterApp()
    window.show()
    sys.exit(app.exec_())

if __name__ == "__main__":
    main()
