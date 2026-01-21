#!/usr/bin/env bash

# Test if cursor --install-extension actually works or hangs

echo "Testing cursor CLI installation..."
echo ""

# Test 1: Simple install with timeout
echo "Test 1: Installing albert.tabout with 10 second timeout"
timeout 10 bash -c "echo | cursor --install-extension albert.tabout --force 2>&1" || echo "TIMED OUT or FAILED"

echo ""
echo "Test 2: Check if it's installed now"
ls -1 ~/.cursor/extensions/ | grep albert

echo ""
echo "If Test 1 timed out, the CLI is hanging and we need a different approach"
