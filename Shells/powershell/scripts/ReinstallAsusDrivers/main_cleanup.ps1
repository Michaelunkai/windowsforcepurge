# Main Deep System Cleanup Script
# This script imports the cleanup module and executes the cleanup function

# Import the cleanup module
Import-Module "$PSScriptRoot\cleanup_module.psm1" -Force

# Execute the deep system cleanup with all confirmations skipped
Invoke-DeepSystemCleanup -SkipConfirmation