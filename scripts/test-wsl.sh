#!/bin/bash

# Simple test script to isolate WSL issue
set -e

echo "Test script starting..."

# Test basic functionality
echo "Testing basic echo..."
echo "Basic echo works"

# Test variable assignment
count=0
echo "Count: $count"

# Test arithmetic
((count++))
echo "Count after increment: $count"

# Test function definition and call
test_function() {
    echo "Function called with: $1"
    return 0
}

test_function "test argument"
echo "Function returned: $?"

# Test if statement
if [[ $count -eq 1 ]]; then
    echo "If statement works"
else
    echo "If statement failed"
fi

# Test while loop with file reading
echo "Testing file reading..."
while IFS=: read -r line1 line2; do
    echo "Read: '$line1' -> '$line2'"
    break # Only read first line for testing
done <scripts/dotfiles.conf

echo "Test script completed successfully"
