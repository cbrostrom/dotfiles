#!/usr/bin/env zsh

# ZSH Startup Profiler
# Measures startup time for each component in .zshrc

echo "╔════════════════════════════════════════════════════════════════════╗"
echo "║              ZSH Startup Performance Profiler                      ║"
echo "╚════════════════════════════════════════════════════════════════════╝"
echo ""

# Enable profiling
zmodload zsh/zprof

# Source .zshrc
source ~/.zshrc

# Show profiling results
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Profiling Results (Top 10 slowest operations):"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
zprof | head -20
