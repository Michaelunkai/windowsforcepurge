"""
Advanced Algorithmic Trading Platform
A sophisticated trading system with real-time visualization, backtesting, and strategy development
"""

import dearpygui.dearpygui as dpg
import numpy as np
import pandas as pd
import threading
import time
import random
import math
from datetime import datetime, timedelta
from typing import Dict, List, Tuple, Optional
from dataclasses import dataclass
from enum import Enum
import json

# Configure DearPyGui
dpg.create_context()

class OrderType(Enum):
    BUY = "BUY"
    SELL = "SELL"

class IndicatorType(Enum):
    SMA = "Simple Moving Average"
    EMA = "Exponential Moving Average" 
    RSI = "Relative Strength Index"
    MACD = "MACD"
    BOLLINGER = "Bollinger Bands"

@dataclass
class Trade:
    timestamp: datetime
    symbol: str
    order_type: OrderType
    quantity: float
    price: float
    pnl: float = 0.0

@dataclass
class MarketData:
    timestamp: datetime
    open: float
    high: float
    low: float
    close: float
    volume: float

class TechnicalIndicators:
    @staticmethod
    def sma(data: List[float], period: int) -> List[float]:
        """Simple Moving Average"""
        if len(data) < period:
            return [0] * len(data)
        
        sma_values = []
        for i in range(len(data)):
            if i < period - 1:
                sma_values.append(0)
            else:
                sma_values.append(sum(data[i-period+1:i+1]) / period)
        return sma_values
    
    @staticmethod
    def ema(data: List[float], period: int) -> List[float]:
        """Exponential Moving Average"""
        if not data:
            return []
        
        alpha = 2 / (period + 1)
        ema_values = [data[0]]
        
        for i in range(1, len(data)):
            ema_val = alpha * data[i] + (1 - alpha) * ema_values[-1]
            ema_values.append(ema_val)
        
        return ema_values
    
    @staticmethod
    def rsi(data: List[float], period: int = 14) -> List[float]:
        """Relative Strength Index"""
        if len(data) < period + 1:
            return [50] * len(data)
        
        deltas = [data[i] - data[i-1] for i in range(1, len(data))]
        gains = [max(0, delta) for delta in deltas]
        losses = [max(0, -delta) for delta in deltas]
        
        avg_gain = sum(gains[:period]) / period
        avg_loss = sum(losses[:period]) / period
        
        rsi_values = [50] * (period + 1)
        
        for i in range(period, len(deltas)):
            avg_gain = (avg_gain * (period - 1) + gains[i]) / period
            avg_loss = (avg_loss * (period - 1) + losses[i]) / period
            
            if avg_loss == 0:
                rsi_values.append(100)
            else:
                rs = avg_gain / avg_loss
                rsi = 100 - (100 / (1 + rs))
                rsi_values.append(rsi)
        
        return rsi_values

class MarketDataGenerator:
    """Generates realistic market data for simulation"""
    
    def __init__(self, initial_price: float = 100.0):
        self.current_price = initial_price
        self.trend = 0.0
        self.volatility = 0.02
        
    def generate_tick(self) -> MarketData:
        """Generate a single market data tick"""
        # Add some trend and random walk
        self.trend += random.gauss(0, 0.001)
        self.trend = max(-0.01, min(0.01, self.trend))  # Limit trend
        
        # Generate OHLC data
        price_change = random.gauss(self.trend, self.volatility)
        new_price = self.current_price * (1 + price_change)
        
        # Simulate intraday variation
        high = new_price * (1 + abs(random.gauss(0, 0.005)))
        low = new_price * (1 - abs(random.gauss(0, 0.005)))
        volume = random.randint(1000, 10000)
        
        market_data = MarketData(
            timestamp=datetime.now(),
            open=self.current_price,
            high=max(self.current_price, new_price, high),
            low=min(self.current_price, new_price, low),
            close=new_price,
            volume=volume
        )
        
        self.current_price = new_price
        return market_data

class Strategy:
    """Base class for trading strategies"""
    
    def __init__(self, name: str):
        self.name = name
        self.indicators = {}
        self.parameters = {}
        self.signals = []
        
    def add_indicator(self, name: str, indicator_type: IndicatorType, period: int):
        self.indicators[name] = {
            'type': indicator_type,
            'period': period,
            'values': []
        }
    
    def calculate_indicators(self, price_data: List[float]):
        """Calculate all indicators for the strategy"""
        for name, indicator in self.indicators.items():
            if indicator['type'] == IndicatorType.SMA:
                indicator['values'] = TechnicalIndicators.sma(price_data, indicator['period'])
            elif indicator['type'] == IndicatorType.EMA:
                indicator['values'] = TechnicalIndicators.ema(price_data, indicator['period'])
            elif indicator['type'] == IndicatorType.RSI:
                indicator['values'] = TechnicalIndicators.rsi(price_data, indicator['period'])
    
    def generate_signal(self, current_data: MarketData, historical_data: List[MarketData]) -> Optional[OrderType]:
        """Override this method to implement strategy logic"""
        return None

class YOUR_CLIENT_SECRET_HERE(Strategy):
    """Simple moving average crossover strategy"""
    
    def __init__(self):
        super().__init__("MA Cross Strategy")
        self.add_indicator("SMA_Fast", IndicatorType.SMA, 10)
        self.add_indicator("SMA_Slow", IndicatorType.SMA, 20)
        self.position = 0
    
    def generate_signal(self, current_data: MarketData, historical_data: List[MarketData]) -> Optional[OrderType]:
        if len(historical_data) < 21:
            return None
            
        price_data = [data.close for data in historical_data]
        self.calculate_indicators(price_data)
        
        fast_ma = self.indicators["SMA_Fast"]["values"]
        slow_ma = self.indicators["SMA_Slow"]["values"]
        
        if len(fast_ma) < 2 or len(slow_ma) < 2:
            return None
            
        # Golden cross - fast MA crosses above slow MA
        if fast_ma[-1] > slow_ma[-1] and fast_ma[-2] <= slow_ma[-2] and self.position <= 0:
            self.position = 1
            return OrderType.BUY
            
        # Death cross - fast MA crosses below slow MA  
        if fast_ma[-1] < slow_ma[-1] and fast_ma[-2] >= slow_ma[-2] and self.position >= 0:
            self.position = -1
            return OrderType.SELL
            
        return None

class BacktestEngine:
    """Comprehensive backtesting engine"""
    
    def __init__(self):
        self.trades = []
        self.equity_curve = []
        self.initial_capital = 100000
        self.current_capital = self.initial_capital
        self.position = 0
        self.position_value = 0
        
    def run_backtest(self, strategy: Strategy, historical_data: List[MarketData]) -> Dict:
        """Run backtest on historical data"""
        self.trades = []
        self.equity_curve = []
        self.current_capital = self.initial_capital
        self.position = 0
        self.position_value = 0
        
        for i, data in enumerate(historical_data):
            if i < 20:  # Need some history for indicators
                self.equity_curve.append(self.initial_capital)
                continue
                
            signal = strategy.generate_signal(data, historical_data[:i+1])
            
            if signal == OrderType.BUY and self.position <= 0:
                # Close short position if any
                if self.position < 0:
                    pnl = -self.position * (self.position_value - data.close)
                    self.current_capital += pnl
                    self.trades.append(Trade(data.timestamp, "STOCK", OrderType.BUY, -self.position, data.close, pnl))
                
                # Open long position
                shares = int(self.current_capital * 0.95 / data.close)  # Use 95% of capital
                if shares > 0:
                    self.position = shares
                    self.position_value = data.close
                    self.current_capital -= shares * data.close
                    
            elif signal == OrderType.SELL and self.position >= 0:
                # Close long position if any
                if self.position > 0:
                    pnl = self.position * (data.close - self.position_value)
                    self.current_capital += self.position * data.close
                    self.trades.append(Trade(data.timestamp, "STOCK", OrderType.SELL, self.position, data.close, pnl))
                    self.position = 0
                    self.position_value = 0
            
            # Calculate current equity
            current_equity = self.current_capital
            if self.position > 0:
                current_equity += self.position * data.close
            elif self.position < 0:
                current_equity += self.position * (2 * self.position_value - data.close)
                
            self.equity_curve.append(current_equity)
        
        return self.calculate_metrics()
    
    def calculate_metrics(self) -> Dict:
        """Calculate performance metrics"""
        if not self.equity_curve:
            return {}
            
        returns = [self.equity_curve[i] / self.equity_curve[i-1] - 1 
                  for i in range(1, len(self.equity_curve))]
        
        total_return = (self.equity_curve[-1] / self.initial_capital - 1) * 100
        winning_trades = len([t for t in self.trades if t.pnl > 0])
        total_trades = len(self.trades)
        win_rate = (winning_trades / total_trades * 100) if total_trades > 0 else 0
        
        # Sharpe ratio (simplified)
        avg_return = np.mean(returns) if returns else 0
        std_return = np.std(returns) if returns else 1
        sharpe_ratio = (avg_return / std_return * np.sqrt(252)) if std_return > 0 else 0
        
        # Maximum drawdown
        peak = self.initial_capital
        max_drawdown = 0
        for equity in self.equity_curve:
            if equity > peak:
                peak = equity
            drawdown = (peak - equity) / peak * 100
            max_drawdown = max(max_drawdown, drawdown)
        
        return {
            "Total Return (%)": round(total_return, 2),
            "Total Trades": total_trades,
            "Win Rate (%)": round(win_rate, 2),
            "Sharpe Ratio": round(sharpe_ratio, 2),
            "Max Drawdown (%)": round(max_drawdown, 2),
            "Final Equity": round(self.equity_curve[-1], 2) if self.equity_curve else self.initial_capital
        }

class TradingPlatform:
    """Main trading platform class"""
    
    def __init__(self):
        self.market_data_history = []
        self.current_strategy = YOUR_CLIENT_SECRET_HERE()
        self.backtest_engine = BacktestEngine()
        self.market_generator = MarketDataGenerator(150.0)
        self.is_running = False
        self.paper_trading = True
        self.portfolio_value = 100000
        
        # Generate historical data for backtesting
        self.YOUR_CLIENT_SECRET_HERE()
        
        # UI State
        self.selected_symbol = "AAPL"
        self.chart_timeframe = "1m"
        
    def YOUR_CLIENT_SECRET_HERE(self):
        """Generate historical market data for backtesting"""
        print("Generating historical market data...")
        
        # Generate 2 years of daily data
        base_date = datetime.now() - timedelta(days=730)
        generator = MarketDataGenerator(100.0)
        
        for i in range(730):
            data = generator.generate_tick()
            data.timestamp = base_date + timedelta(days=i)
            self.market_data_history.append(data)
        
        print(f"Generated {len(self.market_data_history)} historical data points")
    
    def setup_ui(self):
        """Setup the main UI"""
        # Create viewport
        dpg.create_viewport(title="Advanced Algorithmic Trading Platform", width=1800, height=1000)
        dpg.setup_dearpygui()
        
        # Create main window
        with dpg.window(label="Trading Platform", tag="main_window"):
            
            # Menu bar
            with dpg.menu_bar():
                with dpg.menu(label="File"):
                    dpg.add_menu_item(label="Save Strategy")
                    dpg.add_menu_item(label="Load Strategy")
                    dpg.add_separator()
                    dpg.add_menu_item(label="Exit", callback=lambda: dpg.stop_dearpygui())
                
                with dpg.menu(label="Trading"):
                    dpg.add_menu_item(label="Start Live Trading", callback=self.start_trading)
                    dpg.add_menu_item(label="Stop Trading", callback=self.stop_trading)
                    dpg.add_separator()
                    dpg.add_menu_item(label="Run Backtest", callback=self.run_backtest)
                
                with dpg.menu(label="Tools"):
                    dpg.add_menu_item(label="Strategy Builder")
                    dpg.add_menu_item(label="Risk Manager")
                    dpg.add_menu_item(label="Performance Analytics")
            
            # Main layout with tabs
            with dpg.tab_bar():
                
                # Trading Dashboard Tab
                with dpg.tab(label="📈 Trading Dashboard"):
                    with dpg.group(horizontal=True):
                        
                        # Left panel - Controls and Strategy
                        with dpg.child_window(width=350, height=600):
                            dpg.add_text("Trading Controls", color=[100, 200, 255])
                            dpg.add_separator()
                            
                            dpg.add_text("Symbol:")
                            dpg.add_input_text(default_value="AAPL", tag="symbol_input", width=200)
                            
                            dpg.add_text("Portfolio Value:")
                            dpg.add_text(f"${self.portfolio_value:,.2f}", tag="portfolio_value", color=[100, 255, 100])
                            
                            dpg.add_separator()
                            dpg.add_text("Strategy Settings", color=[100, 200, 255])
                            
                            dpg.add_text("Active Strategy:")
                            dpg.add_combo(["MA Cross Strategy", "RSI Strategy", "Custom Strategy"], 
                                        default_value="MA Cross Strategy", tag="strategy_combo", width=200)
                            
                            dpg.add_text("Risk Management:")
                            dpg.add_checkbox(label="Enable Stop Loss", default_value=True)
                            dpg.add_input_float(label="Stop Loss %", default_value=2.0, width=150)
                            dpg.add_input_float(label="Position Size %", default_value=25.0, width=150)
                            
                            dpg.add_separator()
                            
                            # Trading buttons
                            with dpg.group(horizontal=True):
                                dpg.add_button(label="▶ Start Trading", callback=self.start_trading, 
                                             width=100, height=40)
                                dpg.add_button(label="⏸ Stop Trading", callback=self.stop_trading, 
                                             width=100, height=40)
                            
                            dpg.add_button(label="🔬 Run Backtest", callback=self.run_backtest, 
                                         width=210, height=30)
                            
                            dpg.add_separator()
                            dpg.add_text("Recent Signals", color=[255, 200, 100])
                            dpg.add_listbox([], tag="signals_list", num_items=8, width=300)
                        
                        # Right panel - Charts
                        with dpg.child_window(width=1000, height=600):
                            dpg.add_text("Real-Time Market Data", color=[100, 200, 255])
                            
                            # Price chart
                            with dpg.plot(label="Price Chart", height=350, width=950, tag="price_plot"):
                                dpg.add_plot_legend()
                                dpg.add_plot_axis(dpg.mvXAxis, label="Time", tag="price_x_axis")
                                dpg.add_plot_axis(dpg.mvYAxis, label="Price ($)", tag="price_y_axis")
                                
                                # Candlestick data (simulated with line for now)
                                dpg.add_line_series([0], [150], label="Price", parent="price_y_axis", tag="price_line")
                                dpg.add_line_series([0], [150], label="SMA Fast", parent="price_y_axis", tag="sma_fast_line")
                                dpg.add_line_series([0], [150], label="SMA Slow", parent="price_y_axis", tag="sma_slow_line")
                            
                            # Volume chart
                            with dpg.plot(label="Volume", height=150, width=950, tag="volume_plot"):
                                dpg.add_plot_axis(dpg.mvXAxis, label="Time", tag="volume_x_axis")
                                dpg.add_plot_axis(dpg.mvYAxis, label="Volume", tag="volume_y_axis")
                                dpg.add_bar_series([0], [1000], label="Volume", parent="volume_y_axis", tag="volume_bars")
                
                # Backtesting Tab
                with dpg.tab(label="📊 Backtesting"):
                    with dpg.group(horizontal=True):
                        
                        # Backtest controls
                        with dpg.child_window(width=350, height=600):
                            dpg.add_text("Backtest Configuration", color=[100, 200, 255])
                            dpg.add_separator()
                            
                            dpg.add_text("Date Range:")
                            dpg.add_input_text(label="Start Date", default_value="2023-01-01", width=200)
                            dpg.add_input_text(label="End Date", default_value="2024-12-31", width=200)
                            
                            dpg.add_text("Initial Capital:")
                            dpg.add_input_float(label="Capital ($)", default_value=100000, width=200)
                            
                            dpg.add_separator()
                            dpg.add_button(label="🚀 Run Full Backtest", callback=self.run_full_backtest, 
                                         width=200, height=40)
                            
                            dpg.add_separator()
                            dpg.add_text("Performance Metrics", color=[255, 200, 100])
                            
                            # Performance metrics display
                            with dpg.table(header_row=True, tag="metrics_table"):
                                dpg.add_table_column(label="Metric")
                                dpg.add_table_column(label="Value")
                        
                        # Backtest results
                        with dpg.child_window(width=1000, height=600):
                            dpg.add_text("Backtest Results", color=[100, 200, 255])
                            
                            # Equity curve
                            with dpg.plot(label="Equity Curve", height=250, width=950, tag="equity_plot"):
                                dpg.add_plot_legend()
                                dpg.add_plot_axis(dpg.mvXAxis, label="Time", tag="equity_x_axis")
                                dpg.add_plot_axis(dpg.mvYAxis, label="Portfolio Value ($)", tag="equity_y_axis")
                                dpg.add_line_series([0], [100000], label="Equity", parent="equity_y_axis", tag="equity_line")
                            
                            # Drawdown chart
                            with dpg.plot(label="Drawdown", height=150, width=950, tag="drawdown_plot"):
                                dpg.add_plot_axis(dpg.mvXAxis, label="Time", tag="drawdown_x_axis")
                                dpg.add_plot_axis(dpg.mvYAxis, label="Drawdown (%)", tag="drawdown_y_axis")
                                dpg.add_line_series([0], [0], label="Drawdown", parent="drawdown_y_axis", tag="drawdown_line")
                            
                            # Trade log
                            dpg.add_text("Trade History")
                            with dpg.child_window(height=150):
                                with dpg.table(header_row=True, tag="trades_table"):
                                    dpg.add_table_column(label="Time")
                                    dpg.add_table_column(label="Type")
                                    dpg.add_table_column(label="Quantity")
                                    dpg.add_table_column(label="Price")
                                    dpg.add_table_column(label="P&L")
                
                # Strategy Builder Tab
                with dpg.tab(label="🔧 Strategy Builder"):
                    with dpg.group(horizontal=True):
                        
                        # Strategy components
                        with dpg.child_window(width=400, height=600):
                            dpg.add_text("Visual Strategy Builder", color=[100, 200, 255])
                            dpg.add_separator()
                            
                            dpg.add_text("Technical Indicators:")
                            
                            # Indicator selection
                            dpg.add_combo(["SMA", "EMA", "RSI", "MACD", "Bollinger Bands"], 
                                        label="Add Indicator", tag="indicator_combo")
                            dpg.add_input_int(label="Period", default_value=20, width=100, tag="indicator_period")
                            dpg.add_button(label="Add Indicator", callback=self.YOUR_CLIENT_SECRET_HERE)
                            
                            dpg.add_separator()
                            dpg.add_text("Current Strategy Components:")
                            dpg.add_listbox([], tag="strategy_components", num_items=10, width=300)
                            
                            dpg.add_separator()
                            dpg.add_text("Entry/Exit Conditions:")
                            
                            # Simple condition builder
                            dpg.add_combo(["SMA Fast > SMA Slow", "RSI < 30", "RSI > 70", "Price > SMA"], 
                                        label="Entry Condition", tag="entry_condition")
                            dpg.add_combo(["SMA Fast < SMA Slow", "RSI > 70", "RSI < 30", "Price < SMA"], 
                                        label="Exit Condition", tag="exit_condition")
                            
                            dpg.add_button(label="💾 Save Strategy", width=150)
                            dpg.add_button(label="📂 Load Strategy", width=150)
                        
                        # Strategy visualization
                        with dpg.child_window(width=1000, height=600):
                            dpg.add_text("Strategy Visualization", color=[100, 200, 255])
                            
                            # Strategy flow diagram (simplified)
                            with dpg.drawlist(width=950, height=500, tag="strategy_canvas"):
                                # Draw strategy flow
                                dpg.draw_rectangle([50, 50], [200, 100], color=[100, 150, 255], fill=[50, 75, 125])
                                dpg.draw_text([70, 70], "Market Data", size=15)
                                
                                dpg.draw_rectangle([300, 50], [450, 100], color=[255, 150, 100], fill=[125, 75, 50])
                                dpg.draw_text([320, 70], "Indicators", size=15)
                                
                                dpg.draw_rectangle([550, 50], [700, 100], color=[150, 255, 100], fill=[75, 125, 50])
                                dpg.draw_text([580, 70], "Strategy Logic", size=15)
                                
                                dpg.draw_rectangle([550, 150], [700, 200], color=[255, 255, 100], fill=[125, 125, 50])
                                dpg.draw_text([580, 170], "Trading Signal", size=15)
                                
                                # Draw arrows
                                dpg.draw_arrow([200, 75], [300, 75], color=[255, 255, 255], thickness=2)
                                dpg.draw_arrow([450, 75], [550, 75], color=[255, 255, 255], thickness=2)
                                dpg.draw_arrow([625, 100], [625, 150], color=[255, 255, 255], thickness=2)
                
                # Portfolio Analytics Tab  
                with dpg.tab(label="📈 Portfolio Analytics"):
                    with dpg.group(horizontal=True):
                        
                        # Analytics controls
                        with dpg.child_window(width=350, height=600):
                            dpg.add_text("Portfolio Analysis", color=[100, 200, 255])
                            dpg.add_separator()
                            
                            dpg.add_text("Risk Metrics:")
                            dpg.add_text("VaR (95%): $0.00", tag="var_metric")
                            dpg.add_text("Beta: 1.00", tag="beta_metric")
                            dpg.add_text("Volatility: 0.00%", tag="volatility_metric")
                            
                            dpg.add_separator()
                            dpg.add_text("Portfolio Composition:")
                            
                            # Holdings pie chart data
                            dpg.add_text("Cash: 75%")
                            dpg.add_text("Stocks: 25%")
                            dpg.add_text("Crypto: 0%")
                            
                            dpg.add_separator()
                            dpg.add_button(label="📊 Generate Report", width=200, height=30)
                            dpg.add_button(label="📧 Email Report", width=200, height=30)
                        
                        # Analytics charts
                        with dpg.child_window(width=1000, height=600):
                            dpg.add_text("Advanced Analytics", color=[100, 200, 255])
                            
                            # Risk/Return scatter plot
                            with dpg.plot(label="Risk vs Return Analysis", height=250, width=450, tag="risk_return_plot"):
                                dpg.add_plot_axis(dpg.mvXAxis, label="Risk (Volatility %)", tag="risk_x_axis")
                                dpg.add_plot_axis(dpg.mvYAxis, label="Return (%)", tag="return_y_axis")
                                dpg.add_scatter_series([10, 15, 20, 25], [8, 12, 15, 18], 
                                                     label="Strategies", parent="return_y_axis", tag="risk_return_scatter")
                            
                            # Correlation heatmap (simplified)
                            with dpg.plot(label="Asset Correlation Matrix", height=250, width=450, tag="correlation_plot"):
                                dpg.add_plot_axis(dpg.mvXAxis, label="Assets", tag="corr_x_axis")
                                dpg.add_plot_axis(dpg.mvYAxis, label="Assets", tag="corr_y_axis")
                                # Add correlation data here
                            
                            # Performance attribution
                            dpg.add_text("Performance Attribution:")
                            with dpg.child_window(height=150):
                                with dpg.table(header_row=True):
                                    dpg.add_table_column(label="Factor")
                                    dpg.add_table_column(label="Contribution (%)")
                                    dpg.add_table_column(label="Weight")
                                    
                                    with dpg.table_row():
                                        dpg.add_text("Market Beta")
                                        dpg.add_text("4.2%")
                                        dpg.add_text("0.85")
                                    
                                    with dpg.table_row():
                                        dpg.add_text("Alpha Generation")
                                        dpg.add_text("2.1%")
                                        dpg.add_text("N/A")
                                    
                                    with dpg.table_row():
                                        dpg.add_text("Sector Selection")
                                        dpg.add_text("1.3%")
                                        dpg.add_text("0.15")
        
        # Set main window as primary
        dpg.set_primary_window("main_window", True)
        
        # Start market data thread
        self.YOUR_CLIENT_SECRET_HERE()
    
    def YOUR_CLIENT_SECRET_HERE(self):
        """Add technical indicator to current strategy"""
        indicator_name = dpg.get_value("indicator_combo")
        period = dpg.get_value("indicator_period")
        
        # Add to strategy components list
        components = dpg.get_value("strategy_components")
        new_component = f"{indicator_name}({period})"
        components.append(new_component)
        dpg.set_value("strategy_components", components)
    
    def YOUR_CLIENT_SECRET_HERE(self):
        """Start the market data update thread"""
        def update_data():
            while True:
                if self.is_running:
                    # Generate new market data
                    new_data = self.market_generator.generate_tick()
                    self.market_data_history.append(new_data)
                    
                    # Keep only last 500 points for real-time display
                    if len(self.market_data_history) > 1000:
                        self.market_data_history = self.market_data_history[-500:]
                    
                    # Update charts
                    self.update_real_time_charts()
                    
                    # Check for trading signals
                    if self.paper_trading:
                        self.check_trading_signals()
                
                time.sleep(0.1)  # 100ms updates for smooth animation
        
        thread = threading.Thread(target=update_data, daemon=True)
        thread.start()
    
    def update_real_time_charts(self):
        """Update real-time chart displays"""
        if len(self.market_data_history) < 2:
            return
            
        # Get recent data for display
        recent_data = self.market_data_history[-100:]  # Last 100 points
        times = list(range(len(recent_data)))
        prices = [data.close for data in recent_data]
        volumes = [data.volume for data in recent_data]
        
        # Calculate moving averages
        sma_fast = TechnicalIndicators.sma(prices, 10)
        sma_slow = TechnicalIndicators.sma(prices, 20)
        
        # Update price chart
        dpg.set_value("price_line", [times, prices])
        dpg.set_value("sma_fast_line", [times, sma_fast])
        dpg.set_value("sma_slow_line", [times, sma_slow])
        
        # Update volume chart
        dpg.set_value("volume_bars", [times, volumes])
        
        # Update portfolio value
        dpg.set_value("portfolio_value", f"${self.portfolio_value:,.2f}")
        
        # Auto-scale charts
        if prices:
            dpg.set_axis_limits("price_y_axis", min(prices) * 0.99, max(prices) * 1.01)
            dpg.set_axis_limits("price_x_axis", 0, len(times))
        
        if volumes:
            dpg.set_axis_limits("volume_y_axis", 0, max(volumes) * 1.1)
            dpg.set_axis_limits("volume_x_axis", 0, len(times))
    
    def check_trading_signals(self):
        """Check for trading signals from current strategy"""
        if len(self.market_data_history) < 25:
            return
            
        current_data = self.market_data_history[-1]
        signal = self.current_strategy.generate_signal(current_data, self.market_data_history)
        
        if signal:
            # Add to signals list
            signals = dpg.get_value("signals_list")
            timestamp = current_data.timestamp.strftime("%H:%M:%S")
            signal_text = f"{timestamp}: {signal.value} at ${current_data.close:.2f}"
            signals.append(signal_text)
            
            # Keep only last 10 signals
            if len(signals) > 10:
                signals = signals[-10:]
            
            dpg.set_value("signals_list", signals)
            
            print(f"Trading Signal: {signal.value} at {current_data.close:.2f}")
    
    def start_trading(self):
        """Start live/paper trading"""
        self.is_running = True
        print("Trading started in paper mode")
    
    def stop_trading(self):
        """Stop trading"""
        self.is_running = False
        print("Trading stopped")
    
    def run_backtest(self):
        """Run quick backtest with current strategy"""
        print("Running backtest...")
        
        # Use historical data for backtest
        if len(self.market_data_history) > 100:
            test_data = self.market_data_history[-252:]  # Last year of data
        else:
            test_data = self.market_data_history
        
        results = self.backtest_engine.run_backtest(self.current_strategy, test_data)
        
        # Update metrics table
        dpg.delete_item("metrics_table", children_only=True)
        
        with dpg.table_row(parent="metrics_table"):
            dpg.add_text("Metric")
            dpg.add_text("Value")
        
        for metric, value in results.items():
            with dpg.table_row(parent="metrics_table"):
                dpg.add_text(metric)
                dpg.add_text(str(value))
        
        # Update equity curve
        if self.backtest_engine.equity_curve:
            times = list(range(len(self.backtest_engine.equity_curve)))
            dpg.set_value("equity_line", [times, self.backtest_engine.equity_curve])
            
            # Calculate and display drawdown
            peak = self.backtest_engine.initial_capital
            drawdowns = []
            for equity in self.backtest_engine.equity_curve:
                if equity > peak:
                    peak = equity
                drawdown = (peak - equity) / peak * 100
                drawdowns.append(-drawdown)  # Negative for display
            
            dpg.set_value("drawdown_line", [times, drawdowns])
        
        print(f"Backtest completed. Results: {results}")
    
    def run_full_backtest(self):
        """Run comprehensive backtest with full historical data"""
        print("Running full backtest with historical data...")
        
        # Use all historical data
        results = self.backtest_engine.run_backtest(self.current_strategy, self.market_data_history)
        
        # Update all displays
        self.run_backtest()  # Reuse the display update logic
        
        # Update trade history table
        dpg.delete_item("trades_table", children_only=True)
        
        with dpg.table_row(parent="trades_table"):
            dpg.add_text("Time")
            dpg.add_text("Type") 
            dpg.add_text("Quantity")
            dpg.add_text("Price")
            dpg.add_text("P&L")
        
        # Show last 20 trades
        recent_trades = self.backtest_engine.trades[-20:] if self.backtest_engine.trades else []
        for trade in recent_trades:
            with dpg.table_row(parent="trades_table"):
                dpg.add_text(trade.timestamp.strftime("%Y-%m-%d %H:%M"))
                dpg.add_text(trade.order_type.value)
                dpg.add_text(f"{trade.quantity:.0f}")
                dpg.add_text(f"${trade.price:.2f}")
                color = [100, 255, 100] if trade.pnl > 0 else [255, 100, 100]
                dpg.add_text(f"${trade.pnl:.2f}", color=color)
    
    def run(self):
        """Start the trading platform"""
        self.setup_ui()
        dpg.show_viewport()
        
        # Main application loop
        while dpg.is_dearpygui_running():
            dpg.render_dearpygui_frame()
        
        dpg.destroy_context()

# Run the trading platform
if __name__ == "__main__":
    print("🚀 Starting Advanced Algorithmic Trading Platform...")
    print("Features:")
    print("- Real-time market data simulation")
    print("- Visual strategy builder")  
    print("- Comprehensive backtesting engine")
    print("- Performance analytics")
    print("- Paper trading mode")
    print("- Professional trading interface")
    print()
    
    platform = TradingPlatform()
    platform.run()
