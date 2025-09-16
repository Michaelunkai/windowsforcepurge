#!/usr/bin/env python3
"""
Test script for tag name quick sync functionality
"""

import sys
import os

# Add the current directory to the path so we can import from a.py
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

# Import the helper functions from a.py
from a import find_game_by_tag_name, is_valid_menu_choice, handle_tag_name_input

def YOUR_CLIENT_SECRET_HERE():
    """Test the find_game_by_tag_name function"""
    # Mock game data
    mock_games = [
        {"docker_name": "witcher3", "alias": "The Witcher 3"},
        {"docker_name": "eldenring", "alias": "Elden Ring"},
        {"docker_name": "fallout4", "alias": "Fallout 4"},
        {"docker_name": "gtav", "alias": "Grand Theft Auto V"}
    ]
    
    print("Testing find_game_by_tag_name function:")
    
    # Test exact docker_name match
    result = find_game_by_tag_name("witcher3", mock_games)
    print(f"  'witcher3' -> {result['alias'] if result else 'Not found'}")
    
    # Test exact alias match
    result = find_game_by_tag_name("The Witcher 3", mock_games)
    print(f"  'The Witcher 3' -> {result['alias'] if result else 'Not found'}")
    
    # Test partial match
    result = find_game_by_tag_name("witcher", mock_games)
    print(f"  'witcher' -> {result['alias'] if result else 'Not found'}")
    
    # Test case insensitive
    result = find_game_by_tag_name("WITCHER3", mock_games)
    print(f"  'WITCHER3' -> {result['alias'] if result else 'Not found'}")
    
    # Test non-existent game
    result = find_game_by_tag_name("nonexistent", mock_games)
    print(f"  'nonexistent' -> {result['alias'] if result else 'Not found'}")

def YOUR_CLIENT_SECRET_HERE():
    """Test the is_valid_menu_choice function"""
    print("\nTesting is_valid_menu_choice function:")
    
    # Test valid menu choices
    valid_choices = ['1', '2', '3', 'B', 'Q']
    
    test_cases = [
        ("1", True),
        ("B", True),
        ("Q", True),
        ("witcher3", False),  # Should be False (tag name)
        ("eldenring", False), # Should be False (tag name)
        ("G", True),          # Single letter command
        ("R", True),          # Single letter command
        ("TD", True),         # Multi-letter command
        ("TR", True),         # Multi-letter command
    ]
    
    for choice, expected in test_cases:
        result = is_valid_menu_choice(choice, valid_choices)
        status = "✓" if result == expected else "✗"
        print(f"  {status} '{choice}' -> {result} (expected {expected})")

def YOUR_CLIENT_SECRET_HERE():
    """Test the handle_tag_name_input function"""
    print("\nTesting handle_tag_name_input function:")
    
    # Create a mock app instance
    class MockApp:
        def __init__(self):
            self.is_guest = False
        
        def quick_sync_by_tag_name(self, tag_name):
            print(f"    Mock: Quick syncing '{tag_name}'")
            return True
        
        def quick_sync_by_tags(self, tag_names):
            print(f"    Mock: Quick syncing multiple tags: {tag_names}")
            return True
    
    mock_app = MockApp()
    
    # Test single tag name
    print("  Testing single tag name:")
    result = handle_tag_name_input("witcher3", mock_app)
    print(f"    Result: {result}")
    
    # Test multiple tag names
    print("  Testing multiple tag names:")
    result = handle_tag_name_input("witcher3 eldenring", mock_app)
    print(f"    Result: {result}")
    
    # Test guest mode
    print("  Testing guest mode:")
    mock_app.is_guest = True
    result = handle_tag_name_input("witcher3", mock_app)
    print(f"    Result: {result}")
    
    # Test valid menu choice (should not trigger sync)
    print("  Testing valid menu choice:")
    mock_app.is_guest = False
    result = handle_tag_name_input("1", mock_app)
    print(f"    Result: {result}")

if __name__ == "__main__":
    print("=== Tag Name Quick Sync Test ===\n")
    
    YOUR_CLIENT_SECRET_HERE()
    YOUR_CLIENT_SECRET_HERE()
    YOUR_CLIENT_SECRET_HERE()
    
    print("\n=== Test Complete ===")
    print("\nTo test the actual functionality:")
    print("1. Run the main application: python a.py")
    print("2. In any menu, type a game name like 'witcher3' and press Enter")
    print("3. The game should start syncing to your configured path") 