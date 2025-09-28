"""
Logger Setup Module
Configures comprehensive logging for the laptop driver updater application.
"""

import logging
import logging.handlers
import sys
from pathlib import Path
from typing import Optional
import colorama
from colorama import Fore, Back, Style

# Initialize colorama for Windows color support
colorama.init()

class ColoredFormatter(logging.Formatter):
    """Custom formatter that adds colors to log levels."""
    
    # Color mapping for different log levels
    COLORS = {
        'DEBUG': Fore.CYAN,
        'INFO': Fore.GREEN,
        'WARNING': Fore.YELLOW,
        'ERROR': Fore.RED,
        'CRITICAL': Fore.RED + Back.WHITE + Style.BRIGHT,
    }
    
    def format(self, record):
        # Add color to the log level name
        if record.levelname in self.COLORS:
            colored_levelname = f"{self.COLORS[record.levelname]}{record.levelname}{Style.RESET_ALL}"
            record.levelname = colored_levelname
        
        return super().format(record)

def setup_logging(log_level: str = "INFO", log_file: Optional[Path] = None, 
                 enable_colors: bool = True) -> logging.Logger:
    """
    Set up comprehensive logging for the application.
    
    Args:
        log_level: Logging level (DEBUG, INFO, WARNING, ERROR, CRITICAL)
        log_file: Optional path to log file. If None, uses default location.
        enable_colors: Whether to enable colored console output
    
    Returns:
        Configured logger instance
    """
    
    # Create logs directory if it doesn't exist
    if log_file is None:
        log_file = Path.cwd() / "logs" / "driver_updater.log"
    
    log_file.parent.mkdir(parents=True, exist_ok=True)
    
    # Get the root logger
    logger = logging.getLogger()
    logger.setLevel(getattr(logging, log_level.upper(), logging.INFO))
    
    # Clear any existing handlers
    for handler in logger.handlers[:]:
        logger.removeHandler(handler)
    
    # Create detailed formatter for file logging
    file_formatter = logging.Formatter(
        fmt='%(asctime)s | %(levelname)-8s | %(name)-20s | %(funcName)-15s:%(lineno)-4d | %(message)s',
        datefmt='%Y-%m-%d %H:%M:%S'
    )
    
    # Create simpler formatter for console logging
    if enable_colors:
        console_formatter = ColoredFormatter(
            fmt='%(asctime)s | %(levelname)-8s | %(name)-15s | %(message)s',
            datefmt='%H:%M:%S'
        )
    else:
        console_formatter = logging.Formatter(
            fmt='%(asctime)s | %(levelname)-8s | %(name)-15s | %(message)s',
            datefmt='%H:%M:%S'
        )
    
    # Set up file handler with rotation
    file_handler = logging.handlers.RotatingFileHandler(
        log_file,
        maxBytes=10 * 1024 * 1024,  # 10MB
        backupCount=5,
        encoding='utf-8'
    )
    file_handler.setLevel(logging.DEBUG)  # Always log everything to file
    file_handler.setFormatter(file_formatter)
    logger.addHandler(file_handler)
    
    # Set up console handler
    console_handler = logging.StreamHandler(sys.stdout)
    console_handler.setLevel(getattr(logging, log_level.upper(), logging.INFO))
    console_handler.setFormatter(console_formatter)
    logger.addHandler(console_handler)
    
    # Set up error handler (separate file for errors)
    error_log_file = log_file.parent / "errors.log"
    error_handler = logging.handlers.RotatingFileHandler(
        error_log_file,
        maxBytes=5 * 1024 * 1024,  # 5MB
        backupCount=3,
        encoding='utf-8'
    )
    error_handler.setLevel(logging.ERROR)
    error_handler.setFormatter(file_formatter)
    logger.addHandler(error_handler)
    
    # Configure third-party library logging levels
    configure_third_party_logging()
    
    # Log the initialization
    app_logger = logging.getLogger('driver_updater')
    app_logger.info("="*60)
    app_logger.info("Laptop Driver Updater - Logging Initialized")
    app_logger.info(f"Log Level: {log_level}")
    app_logger.info(f"Log File: {log_file}")
    app_logger.info(f"Error Log: {error_log_file}")
    app_logger.info("="*60)
    
    return app_logger

def configure_third_party_logging():
    """Configure logging levels for third-party libraries."""
    
    # Reduce noise from HTTP libraries
    logging.getLogger('urllib3').setLevel(logging.WARNING)
    logging.getLogger('requests').setLevel(logging.WARNING)
    logging.getLogger('aiohttp').setLevel(logging.WARNING)
    
    # Reduce noise from GUI libraries
    logging.getLogger('tkinter').setLevel(logging.WARNING)
    
    # Reduce noise from other libraries
    logging.getLogger('asyncio').setLevel(logging.WARNING)
    logging.getLogger('concurrent.futures').setLevel(logging.WARNING)

class LogCapture:
    """Context manager to capture log messages for testing or GUI display."""
    
    def __init__(self, logger_name: str = None, level: int = logging.INFO):
        self.logger_name = logger_name
        self.level = level
        self.handler = None
        self.logs = []
    
    def __enter__(self):
        self.handler = LogCaptureHandler(self.logs)
        self.handler.setLevel(self.level)
        
        if self.logger_name:
            logger = logging.getLogger(self.logger_name)
        else:
            logger = logging.getLogger()
        
        logger.addHandler(self.handler)
        return self.logs
    
    def __exit__(self, exc_type, exc_val, exc_tb):
        if self.handler:
            if self.logger_name:
                logger = logging.getLogger(self.logger_name)
            else:
                logger = logging.getLogger()
            
            logger.removeHandler(self.handler)

class LogCaptureHandler(logging.Handler):
    """Custom logging handler that captures log records in a list."""
    
    def __init__(self, log_list):
        super().__init__()
        self.log_list = log_list
    
    def emit(self, record):
        try:
            msg = self.format(record)
            self.log_list.append({
                'timestamp': record.created,
                'level': record.levelname,
                'logger': record.name,
                'message': msg,
                'raw_record': record
            })
        except Exception:
            self.handleError(record)

def get_logger(name: str) -> logging.Logger:
    """Get a logger with the specified name."""
    return logging.getLogger(name)

def log_system_info():
    """Log system information for debugging purposes."""
    import platform
    import psutil
    
    logger = logging.getLogger('system_info')
    
    try:
        logger.info("System Information:")
        logger.info(f"  OS: {platform.system()} {platform.release()}")
        logger.info(f"  Architecture: {platform.architecture()[0]}")
        logger.info(f"  Machine: {platform.machine()}")
        logger.info(f"  Processor: {platform.processor()}")
        logger.info(f"  Python: {platform.python_version()}")
        
        # Memory info
        memory = psutil.virtual_memory()
        logger.info(f"  RAM: {memory.total // (1024**3)} GB total, {memory.available // (1024**3)} GB available")
        
        # Disk info
        disk = psutil.disk_usage('/')
        logger.info(f"  Disk: {disk.total // (1024**3)} GB total, {disk.free // (1024**3)} GB free")
        
    except Exception as e:
        logger.error(f"Error getting system info: {e}")

def log_performance_info(func):
    """Decorator to log function performance information."""
    import time
    import functools
    
    @functools.wraps(func)
    def wrapper(*args, **kwargs):
        logger = logging.getLogger(f"performance.{func.__module__}.{func.__name__}")
        start_time = time.time()
        
        try:
            result = func(*args, **kwargs)
            end_time = time.time()
            execution_time = end_time - start_time
            
            logger.debug(f"Function executed in {execution_time:.3f} seconds")
            return result
            
        except Exception as e:
            end_time = time.time()
            execution_time = end_time - start_time
            logger.error(f"Function failed after {execution_time:.3f} seconds: {e}")
            raise
    
    return wrapper

# Create a module-level logger for this file
module_logger = logging.getLogger(__name__)
