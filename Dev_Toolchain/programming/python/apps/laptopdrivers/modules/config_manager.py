"""
Configuration Manager Module
Handles application configuration, settings, and preferences.
"""

import json
import logging
from pathlib import Path
from typing import Dict, Any, Optional

class ConfigManager:
    """Manages application configuration and settings."""
    
    def __init__(self, config_file: Optional[Path] = None):
        self.logger = logging.getLogger(__name__)
        
        # Set default config file location
        if config_file is None:
            self.config_file = Path.cwd() / "config" / "settings.json"
        else:
            self.config_file = config_file
        
        # Default configuration
        self.default_config = {
            "auto_install": False,
            "create_restore_point": True,
            "download_directory": str(Path.cwd() / "downloads"),
            "log_level": "INFO",
            "check_for_updates_on_startup": True,
            "backup_drivers": True,
            "install_timeout": 1800,  # 30 minutes
            "nvidia": {
                "install_geforce_experience": False,
                "install_hd_audio_driver": True,
                "perform_clean_install": False
            },
            "amd": {
                "install_chipset_drivers": True,
                "install_audio_drivers": True,
                "install_display_drivers": True,
                "minimal_install": False
            },
            "asus": {
                "install_utilities": True,
                "install_bios_updates": False,  # Safety: Manual BIOS updates only
                "install_system_drivers": True,
                "skip_gaming_software": False
            },
            "network": {
                "use_proxy": False,
                "proxy_host": "",
                "proxy_port": 8080,
                "proxy_username": "",
                "proxy_password": "",
                "connection_timeout": 30,
                "download_retries": 3
            },
            "notifications": {
                "show_completion_notification": True,
                "show_error_notifications": True,
                "play_sounds": True
            },
            "advanced": {
                "verify_driver_signatures": True,
                "create_system_restore_point": True,
                "enable_debug_logging": False,
                "parallel_downloads": False,
                "max_concurrent_downloads": 2
            }
        }
        
        # Load configuration
        self.config = self.load_config()
    
    def load_config(self) -> Dict[str, Any]:
        """Load configuration from file."""
        try:
            if self.config_file.exists():
                with open(self.config_file, 'r', encoding='utf-8') as f:
                    loaded_config = json.load(f)
                
                # Merge with defaults to ensure all keys exist
                merged_config = self._merge_configs(self.default_config, loaded_config)
                self.logger.info(f"Configuration loaded from: {self.config_file}")
                return merged_config
            else:
                self.logger.info("Config file not found, using defaults")
                return self.default_config.copy()
                
        except Exception as e:
            self.logger.error(f"Error loading config: {e}")
            self.logger.info("Using default configuration")
            return self.default_config.copy()
    
    def save_config(self) -> bool:
        """Save current configuration to file."""
        try:
            # Ensure config directory exists
            self.config_file.parent.mkdir(parents=True, exist_ok=True)
            
            with open(self.config_file, 'w', encoding='utf-8') as f:
                json.dump(self.config, f, indent=2, ensure_ascii=False)
            
            self.logger.info(f"Configuration saved to: {self.config_file}")
            return True
            
        except Exception as e:
            self.logger.error(f"Error saving config: {e}")
            return False
    
    def get(self, key: str, default: Any = None) -> Any:
        """Get a configuration value using dot notation (e.g., 'nvidia.install_hd_audio_driver')."""
        try:
            keys = key.split('.')
            value = self.config
            
            for k in keys:
                if isinstance(value, dict) and k in value:
                    value = value[k]
                else:
                    return default
            
            return value
            
        except Exception as e:
            self.logger.error(f"Error getting config value '{key}': {e}")
            return default
    
    def set(self, key: str, value: Any) -> bool:
        """Set a configuration value using dot notation."""
        try:
            keys = key.split('.')
            config = self.config
            
            # Navigate to the parent of the target key
            for k in keys[:-1]:
                if k not in config:
                    config[k] = {}
                config = config[k]
            
            # Set the value
            config[keys[-1]] = value
            
            self.logger.debug(f"Config value set: {key} = {value}")
            return True
            
        except Exception as e:
            self.logger.error(f"Error setting config value '{key}': {e}")
            return False
    
    def reset_to_defaults(self) -> bool:
        """Reset configuration to default values."""
        try:
            self.config = self.default_config.copy()
            self.logger.info("Configuration reset to defaults")
            return True
            
        except Exception as e:
            self.logger.error(f"Error resetting config: {e}")
            return False
    
    def _merge_configs(self, default: Dict, loaded: Dict) -> Dict:
        """Recursively merge loaded config with defaults."""
        merged = default.copy()
        
        for key, value in loaded.items():
            if key in merged and isinstance(merged[key], dict) and isinstance(value, dict):
                merged[key] = self._merge_configs(merged[key], value)
            else:
                merged[key] = value
        
        return merged
    
    def get_download_directory(self) -> Path:
        """Get the configured download directory as a Path object."""
        download_dir = Path(self.get('download_directory', str(Path.cwd() / "downloads")))
        download_dir.mkdir(parents=True, exist_ok=True)
        return download_dir
    
    def is_auto_install_enabled(self) -> bool:
        """Check if auto-install is enabled."""
        return self.get('auto_install', False)
    
    def should_create_restore_point(self) -> bool:
        """Check if system restore point should be created."""
        return self.get('create_restore_point', True)
    
    def get_install_timeout(self) -> int:
        """Get the installation timeout in seconds."""
        return self.get('install_timeout', 1800)
    
    def get_log_level(self) -> str:
        """Get the configured log level."""
        return self.get('log_level', 'INFO')
    
    def export_config(self, export_path: Path) -> bool:
        """Export current configuration to a file."""
        try:
            with open(export_path, 'w', encoding='utf-8') as f:
                json.dump(self.config, f, indent=2, ensure_ascii=False)
            
            self.logger.info(f"Configuration exported to: {export_path}")
            return True
            
        except Exception as e:
            self.logger.error(f"Error exporting config: {e}")
            return False
    
    def import_config(self, import_path: Path) -> bool:
        """Import configuration from a file."""
        try:
            if not import_path.exists():
                self.logger.error(f"Import file does not exist: {import_path}")
                return False
            
            with open(import_path, 'r', encoding='utf-8') as f:
                imported_config = json.load(f)
            
            # Validate and merge with defaults
            self.config = self._merge_configs(self.default_config, imported_config)
            
            self.logger.info(f"Configuration imported from: {import_path}")
            return True
            
        except Exception as e:
            self.logger.error(f"Error importing config: {e}")
            return False
    
    def validate_config(self) -> bool:
        """Validate the current configuration."""
        try:
            # Check required directories
            download_dir = Path(self.get('download_directory'))
            if not download_dir.parent.exists():
                self.logger.warning(f"Download directory parent does not exist: {download_dir.parent}")
            
            # Check log level
            valid_log_levels = ['DEBUG', 'INFO', 'WARNING', 'ERROR', 'CRITICAL']
            if self.get('log_level') not in valid_log_levels:
                self.logger.warning(f"Invalid log level: {self.get('log_level')}")
                self.set('log_level', 'INFO')
            
            # Check timeout values
            if self.get('install_timeout') < 60:
                self.logger.warning("Install timeout is too low, setting to 60 seconds")
                self.set('install_timeout', 60)
            
            # Check network settings
            if self.get('network.use_proxy'):
                proxy_host = self.get('network.proxy_host')
                proxy_port = self.get('network.proxy_port')
                
                if not proxy_host:
                    self.logger.warning("Proxy enabled but no host specified")
                    self.set('network.use_proxy', False)
                
                if not isinstance(proxy_port, int) or proxy_port < 1 or proxy_port > 65535:
                    self.logger.warning("Invalid proxy port, setting to 8080")
                    self.set('network.proxy_port', 8080)
            
            return True
            
        except Exception as e:
            self.logger.error(f"Error validating config: {e}")
            return False
