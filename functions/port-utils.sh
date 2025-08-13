# =============================================================================
# PORT UTILITY FUNCTIONS
# =============================================================================
# Cross-platform port management utilities

# Function to kill processes by port(s)
# Usage: killport 3000 or killport 3000,3001,3002
killport() {
    if [[ -z "$1" ]]; then
        echo "Missing argument! Usage: killport <PORT> or killport <PORT1,PORT2,PORT3>"
        return 1
    fi

    # Split comma-separated ports (zsh compatible)
    local ports=(${=1//,/ })
    local killed_count=0

    for port in "${ports[@]}"; do
        # Trim whitespace from port
        port=$(echo "$port" | xargs)
        # Validate port number
        if ! [[ "$port" =~ ^[0-9]+$ ]] || [[ "$port" -lt 1 ]] || [[ "$port" -gt 65535 ]]; then
            echo "Invalid port: $port (must be 1-65535)"
            continue
        fi

        # Find processes using the port
        local pids=""
        if $IS_MACOS; then
            # macOS: use lsof with -ti to get just the PIDs
            pids=$(lsof -ti tcp:"$port" 2>/dev/null)
        else
            # Linux: use lsof with awk to extract PIDs
            pids=$(lsof -ti tcp:"$port" 2>/dev/null)
        fi

        if [[ -n "$pids" ]]; then
            echo "Killing processes on port $port: $pids"
            # Kill all processes found on this port
            echo "$pids" | xargs kill -9 2>/dev/null
            if [[ $? -eq 0 ]]; then
                echo "✓ Successfully killed processes on port $port"
                ((killed_count++))
            else
                echo "✗ Failed to kill some processes on port $port"
            fi
        else
            echo "No processes found on port $port"
        fi
    done

    if [[ $killed_count -gt 0 ]]; then
        echo "Total ports processed: ${#ports[@]}, processes killed: $killed_count"
    fi
}

# Alias for backward compatibility
alias kill-by-port='killport'
alias kp='killport'

# Function to list processes using a specific port
portinfo() {
    if [[ -z "$1" ]]; then
        echo "Missing argument! Usage: portinfo <PORT>"
        return 1
    fi

    local port="$1"
    
    # Validate port number
    if ! [[ "$port" =~ ^[0-9]+$ ]] || [[ "$port" -lt 1 ]] || [[ "$port" -gt 65535 ]]; then
        echo "Invalid port: $port (must be 1-65535)"
        return 1
    fi

    echo "Processes using port $port:"
    if $IS_MACOS; then
        lsof -i tcp:"$port" 2>/dev/null || echo "No processes found on port $port"
    else
        lsof -i tcp:"$port" 2>/dev/null || echo "No processes found on port $port"
    fi
}

# Function to find which port a process is using
findport() {
    if [[ -z "$1" ]]; then
        echo "Missing argument! Usage: findport <PROCESS_NAME_OR_PID>"
        return 1
    fi

    local process="$1"
    
    echo "Ports used by process '$process':"
    if $IS_MACOS; then
        lsof -i tcp -P | grep "$process" 2>/dev/null || echo "No TCP ports found for process '$process'"
    else
        lsof -i tcp -P | grep "$process" 2>/dev/null || echo "No TCP ports found for process '$process'"
    fi
} 