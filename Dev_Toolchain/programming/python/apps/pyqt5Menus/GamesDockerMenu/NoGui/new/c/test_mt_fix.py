#!/usr/bin/env python3
"""
Test script to verify MT menu choice handling
"""

import sys
import os

# Add the current directory to the path so we can import from a.py
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

# Import the helper functions from a.py
from a import handle_tag_name_input, is_valid_menu_choice

def test_mt_choice():
    """Test that MT choice is not intercepted as a tag name"""
    print("Testing MT menu choice handling...")
    
    # Test with uppercase MT
    result = handle_tag_name_input("MT", None)
    print(f"MT (uppercase): {result} - Expected: False")
    
    # Test with lowercase mt
    result = handle_tag_name_input("mt", None)
    print(f"mt (lowercase): {result} - Expected: False")
    
    # Test with other valid menu choices
    valid_choices = ["NT", "ET", "DT", "VT", "BM", "G", "R", "S", "O", "M", "T", "Y", "A", "P", "X", "B", "C", "D", "E", "8", "9", "J", "DC", "0", "Q", "TD", "TR"]
    
    print("\nTesting other valid menu choices:")
    for choice in valid_choices:
        result = handle_tag_name_input(choice, None)
        print(f"{choice}: {result} - Expected: False")
    
    # Test with actual tag names
    print("\nTesting actual tag names (should be True):")
    tag_names = ["witcher3", "eldenring", "fallout4", "escapefromtarkov"]
    for tag in tag_names:
        result = handle_tag_name_input(tag, None)
        print(f"{tag}: {result} - Expected: True")
    
    print("\nTest completed!")

if __name__ == "__main__":
    test_mt_choice() 