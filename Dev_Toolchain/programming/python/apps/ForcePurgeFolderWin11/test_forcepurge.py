#!/usr/bin/env python3
"""
Unit tests for ForcePurge - Advanced Windows File/Folder Deletion Tool
Tests various scenarios including locked files, long paths, and privilege adjustments
"""
import os
import sys
import time
import shutil
import tempfile
import unittest
import threading
from pathlib import Path
from unittest.mock import patch, MagicMock

# Add the current directory to Python path to import app
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from app import ForcePurge

class TestForcePurge(unittest.TestCase):
    """Test cases for ForcePurge class."""
    
    def setUp(self):
        """Set up test environment with temporary directory."""
        self.test_dir = tempfile.mkdtemp(prefix='forcepurge_test_')
        self.test_file = os.path.join(self.test_dir, 'test_file.txt')
        self.test_subdir = os.path.join(self.test_dir, 'subdir')
        self.test_subfile = os.path.join(self.test_subdir, 'subfile.txt')
        
        # Create test files and directories
        os.makedirs(self.test_subdir, exist_ok=True)
        with open(self.test_file, 'w') as f:
            f.write('test content')
        with open(self.test_subfile, 'w') as f:
            f.write('subdir content')
        
        self.purger = ForcePurge(verbose=True)
    
    def tearDown(self):
        """Clean up test environment."""
        try:
            # Ensure test directory is completely removed
            if os.path.exists(self.test_dir):
                shutil.rmtree(self.test_dir, ignore_errors=True)
        except:
            pass
    
    def test_initialization(self):
        """Test ForcePurge initialization."""
        purger = ForcePurge()
        self.assertFalse(purger.verbose)
        self.assertFalse(purger.dry_run)
        self.assertFalse(purger.force_reboot)
        
        purger_verbose = ForcePurge(verbose=True, dry_run=True, force_reboot=True)
        self.assertTrue(purger_verbose.verbose)
        self.assertTrue(purger_verbose.dry_run)
        self.assertTrue(purger_verbose.force_reboot)
    
    def test_is_admin(self):
        """Test admin privilege check."""
        result = self.purger.is_admin()
        # This will be True if running as admin, False otherwise
        self.assertIsInstance(result, bool)
    
    def test_handle_long_path(self):
        """Test long path handling."""
        # Normal path should remain unchanged
        normal_path = r"C:\test\file.txt"
        result = self.purger.handle_long_path(normal_path)
        self.assertEqual(result, normal_path)
        
        # Long path should be prefixed
        long_path = r"C:\test" + r"\a" * 260 + r"\file.txt" # Over 260 chars
        result = self.purger.handle_long_path(long_path)
        self.assertTrue(result.startswith('\\\\?\\'))
        self.assertIn(long_path, result or result[4:])  # Either original or without prefix
    
    def test_remove_attributes(self):
        """Test attribute removal."""
        # Set read-only attribute on test file
        os.chmod(self.test_file, 0o444)  # Read-only
        
        # Remove attributes
        result = self.purger.remove_attributes(self.test_file)
        self.assertTrue(result)
        
        # Verify file is now writable
        try:
            with open(self.test_file, 'a') as f:
                f.write('append test')
        except PermissionError:
            self.fail("File should be writable after attribute removal")
    
    def test_dry_run_mode(self):
        """Test dry-run mode."""
        purger = ForcePurge(dry_run=True)
        
        # Should return True but not actually delete
        result = purger.delete(self.test_file)
        self.assertTrue(result)
        
        # File should still exist
        self.assertTrue(os.path.exists(self.test_file))
    
    def test_delete_single_file(self):
        """Test deletion of a single file."""
        # Verify file exists initially
        self.assertTrue(os.path.exists(self.test_file))
        
        # Delete the file
        result = self.purger.delete(self.test_file)
        self.assertTrue(result)
        
        # Verify file is deleted
        self.assertFalse(os.path.exists(self.test_file))
    
    def test_delete_directory_tree(self):
        """Test deletion of entire directory tree."""
        # Verify directory exists initially
        self.assertTrue(os.path.exists(self.test_dir))
        self.assertTrue(os.path.exists(self.test_file))
        self.assertTrue(os.path.exists(self.test_subfile))
        
        # Delete the entire directory
        result = self.purger.delete(self.test_dir)
        self.assertTrue(result)
        
        # Verify everything is deleted
        self.assertFalse(os.path.exists(self.test_dir))
    
    def test_delete_nonexistent_path(self):
        """Test deletion of non-existent path."""
        nonexistent = os.path.join(self.test_dir, 'nonexistent.txt')
        result = self.purger.delete(nonexistent)
        self.assertTrue(result)  # Should succeed (no error for non-existent)
    
    def test_verbose_logging(self):
        """Test verbose logging functionality."""
        purger = ForcePurge(verbose=True)
        
        # This should not raise any exceptions
        result = purger.delete(self.test_file)
        self.assertTrue(result)
        self.assertFalse(os.path.exists(self.test_file))
    
    @unittest.skipIf(sys.platform != 'win32', "Windows-specific test")
    def test_take_ownership_windows(self):
        """Test take ownership functionality on Windows."""
        # This test requires Windows and proper privileges
        # Just verify the method doesn't crash
        result = self.purger.take_ownership(self.test_file)
        # Result may be True/False depending on privileges, just ensure no exception
        
    def test_force_delete_item(self):
        """Test force delete single item."""
        # Verify file exists
        self.assertTrue(os.path.exists(self.test_file))
        
        # Force delete
        result = self.purger.force_delete_item(self.test_file)
        self.assertTrue(result)
        
        # Verify deletion
        self.assertFalse(os.path.exists(self.test_file))
    
    def test_traverse_and_delete_parallel(self):
        """Test parallel deletion of directory tree."""
        # Create more files for parallel processing
        for i in range(5):
            test_file = os.path.join(self.test_dir, f'test_file_{i}.txt')
            with open(test_file, 'w') as f:
                f.write(f'test content {i}')
        
        # Verify files exist
        for i in range(5):
            test_file = os.path.join(self.test_dir, f'test_file_{i}.txt')
            self.assertTrue(os.path.exists(test_file))
        
        # Delete with parallel processing
        result = self.purger.traverse_and_delete(self.test_dir, max_workers=2)
        self.assertTrue(result)
        
        # Verify all files are deleted
        self.assertFalse(os.path.exists(self.test_dir))
    
    def test_empty_directory_deletion(self):
        """Test deletion of empty directory."""
        empty_dir = os.path.join(self.test_dir, 'empty_dir')
        os.makedirs(empty_dir, exist_ok=True)
        
        self.assertTrue(os.path.exists(empty_dir))
        
        result = self.purger.delete(empty_dir)
        self.assertTrue(result)
        self.assertFalse(os.path.exists(empty_dir))
    
    def test_nested_directory_deletion(self):
        """Test deletion of deeply nested directory structure."""
        nested_path = self.test_dir
        for i in range(5):  # Create 5 levels deep
            nested_path = os.path.join(nested_path, f'level_{i}')
            os.makedirs(nested_path, exist_ok=True)
            # Create a file at each level
            with open(os.path.join(nested_path, f'file_{i}.txt'), 'w') as f:
                f.write(f'content at level {i}')
        
        # Verify structure exists
        final_path = os.path.join(self.test_dir, 'level_0', 'level_1', 'level_2', 'level_3', 'level_4')
        self.assertTrue(os.path.exists(final_path))
        
        # Delete entire nested structure
        result = self.purger.delete(self.test_dir)
        self.assertTrue(result)
        self.assertFalse(os.path.exists(self.test_dir))

class TestForcePurgeEdgeCases(unittest.TestCase):
    """Test edge cases and special scenarios."""
    
    def setUp(self):
        self.test_dir = tempfile.mkdtemp(prefix='forcepurge_edge_test_')
        self.purger = ForcePurge(verbose=True)
    
    def tearDown(self):
        try:
            if os.path.exists(self.test_dir):
                shutil.rmtree(self.test_dir, ignore_errors=True)
        except:
            pass
    
    def test_special_characters_in_path(self):
        """Test paths with special characters."""
        special_path = os.path.join(self.test_dir, 'special chars & symbols!.txt')
        with open(special_path, 'w') as f:
            f.write('special chars test')
        
        self.assertTrue(os.path.exists(special_path))
        
        result = self.purger.delete(special_path)
        self.assertTrue(result)
        self.assertFalse(os.path.exists(special_path))
    
    def test_unicode_paths(self):
        """Test paths with Unicode characters."""
        unicode_path = os.path.join(self.test_dir, 'тест_файл.txt')  # Russian characters
        with open(unicode_path, 'w', encoding='utf-8') as f:
            f.write('unicode content')
        
        self.assertTrue(os.path.exists(unicode_path))
        
        result = self.purger.delete(unicode_path)
        self.assertTrue(result)
        self.assertFalse(os.path.exists(unicode_path))
    
    def test_very_long_filename(self):
        """Test very long filename."""
        very_long_name = 'a' * 100 + '.txt'  # 100 char filename + .txt
        long_path = os.path.join(self.test_dir, very_long_name)
        
        with open(long_path, 'w') as f:
            f.write('long filename test')
        
        self.assertTrue(os.path.exists(long_path))
        
        result = self.purger.delete(long_path)
        self.assertTrue(result)
        self.assertFalse(os.path.exists(long_path))

class TestForcePurgeIntegration(unittest.TestCase):
    """Integration tests for main functionality."""
    
    def setUp(self):
        self.test_dir = tempfile.mkdtemp(prefix='forcepurge_integration_test_')
        self.purger = ForcePurge()
    
    def tearDown(self):
        try:
            if os.path.exists(self.test_dir):
                shutil.rmtree(self.test_dir, ignore_errors=True)
        except:
            pass
    
    def test_large_directory_deletion(self):
        """Test deletion of directory with many files."""
        # Create a directory with many small files
        for i in range(50):  # 50 files
            file_path = os.path.join(self.test_dir, f'large_test_file_{i:03d}.txt')
            with open(file_path, 'w') as f:
                f.write(f'Large test file content {i}' * 100)  # Larger content
        
        # Verify files exist
        files = os.listdir(self.test_dir)
        self.assertEqual(len(files), 50)
        
        # Time the deletion
        start_time = time.time()
        result = self.purger.delete(self.test_dir)
        end_time = time.time()
        
        self.assertTrue(result)
        self.assertFalse(os.path.exists(self.test_dir))
        
        # Deletion should be reasonably fast
        deletion_time = end_time - start_time
        print(f"Large directory deletion time: {deletion_time:.2f} seconds for 50 files")
    
    def test_performance_with_subdirectories(self):
        """Test performance with nested subdirectories."""
        # Create nested structure: dir/level1/level2/.../level5/file.txt
        current_path = self.test_dir
        for level in range(5):
            current_path = os.path.join(current_path, f'level_{level}')
            os.makedirs(current_path, exist_ok=True)
            # Create multiple files at each level
            for file_num in range(3):
                with open(os.path.join(current_path, f'file_{file_num}.txt'), 'w') as f:
                    f.write(f'File {file_num} at level {level}')
        
        # Total: 5 levels × 3 files = 15 files + 5 directories
        start_time = time.time()
        result = self.purger.delete(self.test_dir)
        end_time = time.time()
        
        self.assertTrue(result)
        self.assertFalse(os.path.exists(self.test_dir))
        
        deletion_time = end_time - start_time
        print(f"Nested structure deletion time: {deletion_time:.2f} seconds")

def run_tests():
    """Run all tests and return results."""
    # Create test suite
    loader = unittest.TestLoader()
    suite = loader.loadTestsFromModule(sys.modules[__name__])
    
    # Run tests
    runner = unittest.TextTestRunner(verbosity=2)
    result = runner.run(suite)
    
    return result.wasSuccessful()

if __name__ == '__main__':
    print("Running ForcePurge unit tests...")
    success = run_tests()
    
    if success:
        print("\n✅ All tests passed!")
        sys.exit(0)
    else:
        print("\n❌ Some tests failed!")
        sys.exit(1)
