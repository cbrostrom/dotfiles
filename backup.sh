#!/usr/bin/env bash

# Dotfiles Backup Script
# Creates a timestamped backup of your dotfiles before updates

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Logging functions
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Backup directory with timestamp
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="$HOME/.dotfiles-backups/$TIMESTAMP"

# Function to create backup
create_backup() {
    log_info "=== Dotfiles Backup ===" 
    log_info "Creating backup at: $BACKUP_DIR"
    
    # Create backup directory
    mkdir -p "$BACKUP_DIR"
    
    # List of files to backup
    local files_to_backup=(
        "$HOME/.zshrc"
        "$HOME/.gitconfig"
        "$HOME/.gitignore_global"
        "$HOME/.local-aliases"
        "$HOME/.local-secrets"
        "$HOME/.config/starship.toml"
        "$HOME/.config/ghostty"
    )
    
    local backup_count=0
    
    # Backup each file/directory
    for file in "${files_to_backup[@]}"; do
        if [[ -e "$file" ]] || [[ -L "$file" ]]; then
            local basename=$(basename "$file")
            
            # Check if it's a symlink
            if [[ -L "$file" ]]; then
                local link_target=$(readlink "$file")
                log_info "Backing up symlink: $basename -> $link_target"
                echo "$link_target" > "$BACKUP_DIR/$basename.symlink"
            elif [[ -d "$file" ]]; then
                log_info "Backing up directory: $basename"
                cp -r "$file" "$BACKUP_DIR/$basename"
            else
                log_info "Backing up file: $basename"
                cp "$file" "$BACKUP_DIR/$basename"
            fi
            
            ((backup_count++))
        fi
    done
    
    # Create backup manifest
    cat > "$BACKUP_DIR/MANIFEST.txt" <<EOF
Dotfiles Backup Manifest
========================
Backup Date: $(date)
Backup Location: $BACKUP_DIR
Total Files Backed Up: $backup_count

Files Backed Up:
EOF
    
    ls -lah "$BACKUP_DIR" >> "$BACKUP_DIR/MANIFEST.txt"
    
    log_success "✓ Backup complete!"
    log_info "Backup saved to: $BACKUP_DIR"
    log_info "Total files backed up: $backup_count"
}

# Function to list backups
list_backups() {
    log_info "=== Available Backups ==="
    
    if [[ ! -d "$HOME/.dotfiles-backups" ]]; then
        log_warning "No backups found"
        return 0
    fi
    
    local backup_dirs=($(ls -dt "$HOME/.dotfiles-backups"/*/ 2>/dev/null))
    
    if [[ ${#backup_dirs[@]} -eq 0 ]]; then
        log_warning "No backups found"
        return 0
    fi
    
    for backup_dir in "${backup_dirs[@]}"; do
        local backup_name=$(basename "$backup_dir")
        local backup_date=$(echo "$backup_name" | sed 's/_/ /')
        local file_count=$(ls -1 "$backup_dir" | wc -l)
        
        echo -e "${CYAN}$backup_date${NC} - $file_count files"
        echo "  Location: $backup_dir"
    done
}

# Function to restore from backup
restore_backup() {
    local backup_timestamp="$1"
    
    if [[ -z "$backup_timestamp" ]]; then
        log_error "Please specify a backup timestamp to restore"
        log_info "Usage: ./backup.sh restore <timestamp>"
        log_info "Run './backup.sh list' to see available backups"
        return 1
    fi
    
    local backup_path="$HOME/.dotfiles-backups/$backup_timestamp"
    
    if [[ ! -d "$backup_path" ]]; then
        log_error "Backup not found: $backup_path"
        log_info "Run './backup.sh list' to see available backups"
        return 1
    fi
    
    log_warning "This will restore files from backup: $backup_timestamp"
    log_warning "Current files will be backed up first"
    
    read -p "Continue? (y/N): " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Restore cancelled"
        return 0
    fi
    
    # Create a backup of current state first
    create_backup
    
    # Restore files
    log_info "Restoring files from backup..."
    
    for file in "$backup_path"/*; do
        local basename=$(basename "$file")
        
        # Skip manifest
        if [[ "$basename" == "MANIFEST.txt" ]]; then
            continue
        fi
        
        # Handle symlinks
        if [[ "$basename" == *.symlink ]]; then
            local target_name="${basename%.symlink}"
            local link_target=$(cat "$file")
            log_info "Restoring symlink: $target_name -> $link_target"
            rm -f "$HOME/$target_name"
            ln -sf "$link_target" "$HOME/$target_name"
        elif [[ -d "$file" ]]; then
            log_info "Restoring directory: $basename"
            rm -rf "$HOME/.config/$basename"
            cp -r "$file" "$HOME/.config/$basename"
        else
            log_info "Restoring file: $basename"
            cp "$file" "$HOME/$basename"
        fi
    done
    
    log_success "✓ Restore complete!"
}

# Function to clean old backups
clean_backups() {
    local keep_count="${1:-5}"
    
    log_info "=== Cleaning Old Backups ==="
    log_info "Keeping the $keep_count most recent backups"
    
    if [[ ! -d "$HOME/.dotfiles-backups" ]]; then
        log_warning "No backups found"
        return 0
    fi
    
    local backup_dirs=($(ls -dt "$HOME/.dotfiles-backups"/*/ 2>/dev/null))
    
    if [[ ${#backup_dirs[@]} -le $keep_count ]]; then
        log_success "No old backups to clean (found ${#backup_dirs[@]} backups)"
        return 0
    fi
    
    local delete_count=$((${#backup_dirs[@]} - $keep_count))
    
    log_warning "Will delete $delete_count old backup(s)"
    
    read -p "Continue? (y/N): " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Clean cancelled"
        return 0
    fi
    
    # Delete old backups
    local deleted=0
    for ((i=$keep_count; i<${#backup_dirs[@]}; i++)); do
        local backup_dir="${backup_dirs[$i]}"
        log_info "Deleting: $(basename "$backup_dir")"
        rm -rf "$backup_dir"
        ((deleted++))
    done
    
    log_success "✓ Deleted $deleted old backup(s)"
}

# Function to show help
show_help() {
    cat <<'EOF'
Dotfiles Backup Script

Usage: ./backup.sh [COMMAND] [OPTIONS]

Commands:
  create              Create a new backup (default)
  list                List all available backups
  restore <timestamp> Restore from a specific backup
  clean [count]       Clean old backups (keep most recent [count], default: 5)
  help                Show this help message

Examples:
  ./backup.sh                      # Create a backup
  ./backup.sh create               # Create a backup
  ./backup.sh list                 # List all backups
  ./backup.sh restore 20250104_120000  # Restore from specific backup
  ./backup.sh clean 3              # Keep only 3 most recent backups

Backups are stored in: ~/.dotfiles-backups/

EOF
}

# Main function
main() {
    local command="${1:-create}"
    
    case "$command" in
        create)
            create_backup
            ;;
        list)
            list_backups
            ;;
        restore)
            restore_backup "$2"
            ;;
        clean)
            clean_backups "$2"
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            log_error "Unknown command: $command"
            show_help
            exit 1
            ;;
    esac
}

# Run main function
main "$@"

