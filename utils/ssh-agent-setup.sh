#!/usr/bin/env bash
# =============================================================================
# SSH AGENT AUTO-START AND KEY LOADING
# =============================================================================
# This script automatically starts ssh-agent and loads all SSH keys from ~/.ssh
# Works cross-platform: macOS, Linux, WSL

# SSH agent environment file
SSH_ENV="$HOME/.ssh/agent.env"

# Function to start ssh-agent
start_ssh_agent() {
    echo "Starting new ssh-agent..."
    ssh-agent | sed 's/^echo/#echo/' > "$SSH_ENV"
    chmod 600 "$SSH_ENV"
    . "$SSH_ENV" > /dev/null
}

# Function to check if agent is running and accessible
is_agent_running() {
    if [[ -n "$SSH_AGENT_PID" ]]; then
        # Check if the process actually exists
        ps -p "$SSH_AGENT_PID" > /dev/null 2>&1
        return $?
    fi
    return 1
}

# Function to discover and add SSH keys
add_ssh_keys() {
    local ssh_dir="$HOME/.ssh"
    local keys_added=0
    
    # Check if .ssh directory exists
    if [[ ! -d "$ssh_dir" ]]; then
        return 0
    fi
    
    # Find all potential private key files
    # Exclude: .pub files, known_hosts, config, authorized_keys, *.env, directories
    while IFS= read -r -d '' keyfile; do
        local basename=$(basename "$keyfile")
        
        # Skip non-key files
        case "$basename" in
            *.pub|known_hosts*|config|authorized_keys*|*.env|*.old|*.bak)
                continue
                ;;
        esac
        
        # Check if file looks like a private key (starts with correct header)
        if head -n 1 "$keyfile" 2>/dev/null | grep -q "BEGIN.*PRIVATE KEY"; then
            # Try to add the key (silently if already added)
            ssh-add -l 2>/dev/null | grep -q "$(ssh-keygen -lf "$keyfile" 2>/dev/null | awk '{print $2}')" 2>/dev/null
            if [[ $? -ne 0 ]]; then
                # Key not already added, add it
                if [[ -n "$SSH_AGENT_VERBOSE" ]]; then
                    echo "Adding SSH key: $basename"
                fi
                ssh-add "$keyfile" 2>/dev/null
                if [[ $? -eq 0 ]]; then
                    ((keys_added++))
                fi
            fi
        fi
    done < <(find "$ssh_dir" -maxdepth 1 -type f -print0 2>/dev/null)
    
    if [[ -n "$SSH_AGENT_VERBOSE" ]] && [[ $keys_added -gt 0 ]]; then
        echo "Added $keys_added SSH key(s) to agent"
    fi
}

# Main logic
main() {
    # Check if ssh-agent env file exists and is valid
    if [[ -f "$SSH_ENV" ]]; then
        . "$SSH_ENV" > /dev/null
    fi
    
    # Start agent if not running or not accessible
    if ! is_agent_running; then
        start_ssh_agent
    fi
    
    # Add SSH keys
    add_ssh_keys
}

# Run main function
main

