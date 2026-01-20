#!/usr/bin/env bash

# ZSH Startup Benchmark
# Runs multiple tests to measure average startup time

echo "╔════════════════════════════════════════════════════════════════════╗"
echo "║                 ZSH Startup Benchmark Tool                         ║"
echo "╚════════════════════════════════════════════════════════════════════╝"
echo ""

RUNS=10
echo "Running $RUNS startup tests..."
echo ""

total=0
for i in $(seq 1 $RUNS); do
    # Measure time for zsh to start and exit
    time_ms=$(zsh -i -c exit 2>&1 | grep real | awk '{print $2}')
    echo "Run $i: $time_ms"
    
    # Extract seconds (works with both 0m0.123s and 0.123s formats)
    seconds=$(echo $time_ms | sed 's/.*m//' | sed 's/s//')
    total=$(echo "$total + $seconds" | bc)
done

average=$(echo "scale=3; $total / $RUNS" | bc)

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Results:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Total runs: $RUNS"
echo "Average startup time: ${average}s"
echo ""

if (( $(echo "$average < 0.1" | bc -l) )); then
    echo "✓ Excellent! (< 100ms)"
elif (( $(echo "$average < 0.3" | bc -l) )); then
    echo "✓ Good (< 300ms)"
elif (( $(echo "$average < 0.5" | bc -l) )); then
    echo "⚠ Acceptable (< 500ms)"
elif (( $(echo "$average < 1.0" | bc -l) )); then
    echo "⚠ Slow (< 1s) - Consider optimization"
else
    echo "✗ Very slow (> 1s) - Optimization recommended"
fi

echo ""
echo "Tip: Run './utils/profile-zsh-startup.sh' to see detailed breakdown"
