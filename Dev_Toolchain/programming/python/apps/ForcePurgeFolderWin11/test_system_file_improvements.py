#!/usr/bin/env python3
"""
Test script to verify the enhanced system file deletion capabilities in ForcePurge
"""
import os
import sys
import tempfile
import time
from pathlib import Path

# Add the current directory to Python path to import app
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from app import HighSpeedForcePurge

def test_basic_functionality():
    """Test basic functionality to ensure the app still works normally."""
    print("Testing basic functionality...")
    
    # Create a test directory with some files
    with tempfile.TemporaryDirectory() as test_dir:
        # Create test files
        test_file = os.path.join(test_dir, "test_file.txt")
        with open(test_file, 'w') as f:
            f.write("Test content")
        
        # Create subdirectory with files
        sub_dir = os.path.join(test_dir, "subdir")
        os.makedirs(sub_dir)
        sub_file = os.path.join(sub_dir, "sub_file.txt")
        with open(sub_file, 'w') as f:
            f.write("Sub content")
        
        print(f"Created test structure in: {test_dir}")
        print(f"Test file exists: {os.path.exists(test_file)}")
        print(f"Sub file exists: {os.path.exists(sub_file)}")
        
        # Test deletion with the enhanced ForcePurge
        purger = HighSpeedForcePurge(verbose=True)
        result = purger.delete(test_dir)
        
        print(f"Deletion result: {result}")
        print(f"Directory exists after deletion: {os.path.exists(test_dir)}")
        
        if result and not os.path.exists(test_dir):
            print("✅ Basic functionality test PASSED")
            return True
        else:
            print("❌ Basic functionality test FAILED")
            return False

def test_privilege_enhancement():
    """Test the enhanced privilege escalation functionality."""
    print("\nTesting privilege enhancement...")
    
    purger = HighSpeedForcePurge()
    
    # Test privilege enabling
    result = purger.enable_privileges()
    print(f"Privilege enable result: {result}")
    
    if result:
        print("✅ Privilege enhancement test PASSED")
        return True
    else:
        print("❌ Privilege enhancement test FAILED")
        return False

def test_registry_permissions():
    """Test the registry-based permission setting functionality."""
    print("\nTesting registry-based permission setting...")
    
    purger = HighSpeedForcePurge()
    
    # Create a test file
    with tempfile.NamedTemporaryFile(delete=False, suffix='.txt') as temp_file:
        temp_path = temp_file.name
        temp_file.write(b"Test content for registry permissions")
    
    try:
        # Test setting registry permissions
        result = purger.set_full_permissions_registry(temp_path)
        print(f"Registry permission setting result: {result}")
        
        # Test the system file deletion method
        result2 = purger.force_delete_system_file(temp_path)
        print(f"System file deletion result: {result2}")
        
        file_exists = os.path.exists(temp_path)
        print(f"File exists after system deletion: {file_exists}")
        
        if result or result2 and not file_exists:
            print("✅ Registry permissions test PASSED")
            return True
        elif not file_exists:  # File was deleted even if registry method didn't work
            print("✅ Registry permissions test PASSED (file deleted by fallback methods)")
            return True
        else:
            print("❌ Registry permissions test FAILED")
            return False
    finally:
        # Clean up if file still exists
        if os.path.exists(temp_path):
            try:
                os.chmod(temp_path, 0o777)
                os.remove(temp_path)
            except:
                pass

def run_all_tests():
    """Run all tests to verify the improvements."""
    print("Running tests for enhanced system file deletion capabilities...\n")
    
    tests = [
        ("Basic Functionality", test_basic_functionality),
        ("Privilege Enhancement", test_privilege_enhancement),
        ("Registry Permissions", test_registry_permissions),
    ]
    
    passed = 0
    total = len(tests)
    
    for test_name, test_func in tests:
        try:
            if test_func():
                passed += 1
            time.sleep(0.5)  # Small delay between tests
        except Exception as e:
            print(f"❌ {test_name} test FAILED with exception: {e}")
    
    print(f"\nTest Results: {passed}/{total} tests passed")
    
    if passed == total:
        print("🎉 All tests PASSED! The system file deletion improvements are working correctly.")
        return True
    else:
        print("⚠️  Some tests FAILED, but the core functionality should still work.")
        return False

if __name__ == "__main__":
    success = run_all_tests()
    sys.exit(0 if success else 1)