#!/usr/bin/env bash

# Game Desktop File Sync
# Automatically creates and removes .desktop files for installed games
# Supports: Steam (native & Flatpak), Lutris, Heroic Launcher, Cartridges

set -euo pipefail

# Configuration
DESKTOP_DIR="$HOME/.local/share/applications"
GAMES_DESKTOP_DIR="$DESKTOP_DIR/games-auto"
MARKER_PREFIX="game-auto-"
LOG_FILE="$HOME/.local/share/game-desktop-sync.log"

# Ensure directories exist
mkdir -p "$GAMES_DESKTOP_DIR"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

# Track which games we've found (to clean up removed games later)
declare -A found_games

# Function to create a desktop file
create_desktop_file() {
    local game_id="$1"
    local game_name="$2"
    local exec_cmd="$3"
    local icon="${4:-applications-games}"
    local categories="${5:-Game;}"
    
    local desktop_file="$GAMES_DESKTOP_DIR/${MARKER_PREFIX}${game_id}.desktop"
    found_games["$game_id"]=1
    
    # Check if file already exists and is identical
    if [[ -f "$desktop_file" ]]; then
        local existing_exec existing_icon
        existing_exec=$(grep "^Exec=" "$desktop_file" | cut -d'=' -f2- || echo "")
        existing_icon=$(grep "^Icon=" "$desktop_file" | cut -d'=' -f2- || echo "")
        if [[ "$existing_exec" == "$exec_cmd" && "$existing_icon" == "$icon" ]]; then
            return 0  # Already exists and is correct
        fi
    fi
    
    log "Creating desktop file for: $game_name"
    
    cat > "$desktop_file" << EOF
[Desktop Entry]
Type=Application
Name=$game_name
Exec=$exec_cmd
Icon=$icon
Categories=$categories
Terminal=false
StartupNotify=true
EOF
    
    chmod +x "$desktop_file"
}

# Function to sanitize game ID for filename
sanitize_id() {
    echo "$1" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g' | sed 's/^-//' | sed 's/-$//'
}

# ============================================================================
# STEAM SUPPORT (Native Installation)
# ============================================================================
scan_steam_native() {
    log "Scanning Steam (native)..."
    
    local steam_paths=(
        "$HOME/.steam/steam"
        "$HOME/.local/share/Steam"
    )
    
    for steam_root in "${steam_paths[@]}"; do
        if [[ ! -d "$steam_root" ]]; then
            continue
        fi
        
        # Find all Steam library folders
        local library_folders=("$steam_root")
        
        if [[ -f "$steam_root/steamapps/libraryfolders.vdf" ]]; then
            while IFS= read -r line; do
                if [[ "$line" =~ \"path\"[[:space:]]*\"([^\"]+)\" ]]; then
                    library_folders+=("${BASH_REMATCH[1]}")
                fi
            done < "$steam_root/steamapps/libraryfolders.vdf"
        fi
        
        # Scan each library for installed games
        for library in "${library_folders[@]}"; do
            local steamapps="$library/steamapps"
            if [[ ! -d "$steamapps" ]]; then
                continue
            fi
            
            for acf_file in "$steamapps"/appmanifest_*.acf; do
                if [[ ! -f "$acf_file" ]]; then
                    continue
                fi
                
                local app_id game_name install_dir
                app_id=$(grep -oP '^\s*"appid"\s*"\K[^"]+' "$acf_file" || echo "")
                game_name=$(grep -oP '^\s*"name"\s*"\K[^"]+' "$acf_file" || echo "")
                install_dir=$(grep -oP '^\s*"installdir"\s*"\K[^"]+' "$acf_file" || echo "")
                
                if [[ -n "$app_id" && -n "$game_name" ]]; then
                    local game_id="steam-${app_id}"
                    local exec_cmd="steam steam://rungameid/${app_id}"
                    
                    # Try to find game icon
                    local icon="steam"
                    local icon_path="$steam_root/appcache/librarycache/${app_id}/logo.png"
                    if [[ -f "$icon_path" ]]; then
                        icon="$icon_path"
                    fi
                    
                    create_desktop_file "$game_id" "$game_name" "$exec_cmd" "$icon" "Game;"
                fi
            done
        done
        
        break  # Found Steam, no need to check other paths
    done
}

# ============================================================================
# STEAM SUPPORT (Flatpak)
# ============================================================================
scan_steam_flatpak() {
    if ! command -v flatpak &> /dev/null; then
        return
    fi
    
    if ! flatpak list --app | grep -q "com.valvesoftware.Steam"; then
        return
    fi
    
    log "Scanning Steam (Flatpak)..."
    
    local steam_root="$HOME/.var/app/com.valvesoftware.Steam/.local/share/Steam"
    if [[ ! -d "$steam_root" ]]; then
        return
    fi
    
    local library_folders=("$steam_root")
    
    if [[ -f "$steam_root/steamapps/libraryfolders.vdf" ]]; then
        while IFS= read -r line; do
            if [[ "$line" =~ \"path\"[[:space:]]*\"([^\"]+)\" ]]; then
                library_folders+=("${BASH_REMATCH[1]}")
            fi
        done < "$steam_root/steamapps/libraryfolders.vdf"
    fi
    
    for library in "${library_folders[@]}"; do
        local steamapps="$library/steamapps"
        if [[ ! -d "$steamapps" ]]; then
            continue
        fi
        
        for acf_file in "$steamapps"/appmanifest_*.acf; do
            if [[ ! -f "$acf_file" ]]; then
                continue
            fi
            
            local app_id game_name
            app_id=$(grep -oP '^\s*"appid"\s*"\K[^"]+' "$acf_file" || echo "")
            game_name=$(grep -oP '^\s*"name"\s*"\K[^"]+' "$acf_file" || echo "")
            
            if [[ -n "$app_id" && -n "$game_name" ]]; then
                local game_id="steam-flatpak-${app_id}"
                local exec_cmd="flatpak run com.valvesoftware.Steam steam://rungameid/${app_id}"
                
                # Try to find game icon
                local icon="steam"
                local icon_path="$steam_root/appcache/librarycache/${app_id}/logo.png"
                if [[ -f "$icon_path" ]]; then
                    icon="$icon_path"
                fi
                
                create_desktop_file "$game_id" "$game_name" "$exec_cmd" "$icon" "Game;"
            fi
        done
    done
}

# ============================================================================
# LUTRIS SUPPORT
# ============================================================================
scan_lutris() {
    if ! command -v lutris &> /dev/null; then
        return
    fi
    
    log "Scanning Lutris..."
    
    local lutris_db="$HOME/.local/share/lutris/pga.db"
    if [[ ! -f "$lutris_db" ]]; then
        return
    fi
    
    if ! command -v sqlite3 &> /dev/null; then
        log "Warning: sqlite3 not found, skipping Lutris scan"
        return
    fi
    
    while IFS='|' read -r slug name; do
        if [[ -n "$slug" && -n "$name" ]]; then
            local game_id="lutris-$(sanitize_id "$slug")"
            local exec_cmd="lutris lutris:rungame/${slug}"
            
            # Try to find game icon (Lutris stores icons with slug as filename)
            local icon="lutris"
            local icon_path="$HOME/.local/share/lutris/coverart/${slug}.png"
            if [[ ! -f "$icon_path" ]]; then
                icon_path="$HOME/.local/share/lutris/coverart/${slug}.jpg"
            fi
            if [[ -f "$icon_path" ]]; then
                icon="$icon_path"
            fi
            
            create_desktop_file "$game_id" "$name" "$exec_cmd" "$icon" "Game;"
        fi
    done < <(sqlite3 "$lutris_db" "SELECT slug, name FROM games WHERE installed = 1;" 2>/dev/null || true)
}

# ============================================================================
# HEROIC LAUNCHER SUPPORT (Epic Games & GOG)
# ============================================================================
scan_heroic() {
    if ! command -v heroic &> /dev/null; then
        return
    fi
    
    log "Scanning Heroic Launcher..."
    
    local heroic_config="$HOME/.config/heroic"
    if [[ ! -d "$heroic_config" ]]; then
        return
    fi
    
    # Scan Epic Games
    local epic_library="$heroic_config/legendaryConfig/legendary/installed.json"
    if [[ -f "$epic_library" ]] && command -v jq &> /dev/null; then
        while IFS='|' read -r app_name title; do
            if [[ -n "$app_name" && -n "$title" ]]; then
                local game_id="heroic-epic-$(sanitize_id "$app_name")"
                local exec_cmd="heroic --no-gui --launch ${app_name}"
                
                # Try to find game icon (Heroic stores icons in images folder)
                local icon="heroic"
                local icon_path="$heroic_config/images/${app_name}.jpg"
                if [[ ! -f "$icon_path" ]]; then
                    icon_path="$heroic_config/images/${app_name}.png"
                fi
                if [[ -f "$icon_path" ]]; then
                    icon="$icon_path"
                fi
                
                create_desktop_file "$game_id" "$title" "$exec_cmd" "$icon" "Game;"
            fi
        done < <(jq -r 'to_entries[] | "\(.key)|\(.value.title)"' "$epic_library" 2>/dev/null || true)
    fi
    
    # Scan GOG
    local gog_library="$heroic_config/gog_store/installed.json"
    if [[ -f "$gog_library" ]] && command -v jq &> /dev/null; then
        while IFS='|' read -r app_name title; do
            if [[ -n "$app_name" && -n "$title" ]]; then
                local game_id="heroic-gog-$(sanitize_id "$app_name")"
                local exec_cmd="heroic --no-gui --launch ${app_name}"
                
                # Try to find game icon (Heroic stores icons in images folder)
                local icon="heroic"
                local icon_path="$heroic_config/images/${app_name}.jpg"
                if [[ ! -f "$icon_path" ]]; then
                    icon_path="$heroic_config/images/${app_name}.png"
                fi
                if [[ -f "$icon_path" ]]; then
                    icon="$icon_path"
                fi
                
                create_desktop_file "$game_id" "$title" "$exec_cmd" "$icon" "Game;"
            fi
        done < <(jq -r 'to_entries[] | "\(.key)|\(.value.title)"' "$gog_library" 2>/dev/null || true)
    fi
}

# ============================================================================
# BOTTLES SUPPORT
# ============================================================================
scan_bottles() {
    if ! command -v bottles &> /dev/null && ! flatpak list --app | grep -q "com.usebottles.bottles"; then
        return
    fi
    
    log "Scanning Bottles..."
    
    local bottles_dir="$HOME/.var/app/com.usebottles.bottles/data/bottles/bottles"
    if [[ ! -d "$bottles_dir" ]]; then
        bottles_dir="$HOME/.local/share/bottles/bottles"
    fi
    
    if [[ ! -d "$bottles_dir" ]]; then
        return
    fi
    
    for bottle_dir in "$bottles_dir"/*; do
        if [[ ! -d "$bottle_dir" ]]; then
            continue
        fi
        
        local bottle_name=$(basename "$bottle_dir")
        local programs_file="$bottle_dir/bottle.yml"
        
        if [[ -f "$programs_file" ]] && command -v yq &> /dev/null; then
            # Extract programs from bottle.yml if yq is available
            # This is a simplified version - bottles structure can be complex
            continue
        fi
    done
}

# ============================================================================
# CARTRIDGES SUPPORT
# ============================================================================
scan_cartridges() {
    if ! flatpak list --app | grep -q "page.kramo.Cartridges"; then
        return
    fi
    
    log "Scanning Cartridges..."
    
    # Cartridges stores its data in a specific location
    local cartridges_data="$HOME/.var/app/page.kramo.Cartridges/data/cartridges"
    if [[ ! -d "$cartridges_data" ]]; then
        return
    fi
    
    # Cartridges uses a different approach - it may already create .desktop files
    # or store games in a database. This is a placeholder for future implementation.
    # For now, we'll skip as Cartridges typically manages its own launchers.
}

# ============================================================================
# CLEANUP REMOVED GAMES
# ============================================================================
cleanup_removed_games() {
    log "Cleaning up removed games..."
    
    local removed_count=0
    for desktop_file in "$GAMES_DESKTOP_DIR"/${MARKER_PREFIX}*.desktop; do
        if [[ ! -f "$desktop_file" ]]; then
            continue
        fi
        
        local filename=$(basename "$desktop_file")
        local game_id="${filename#$MARKER_PREFIX}"
        game_id="${game_id%.desktop}"
        
        if [[ -z "${found_games[$game_id]:-}" ]]; then
            log "Removing desktop file for uninstalled game: $game_id"
            rm -f "$desktop_file"
            ((removed_count++))
        fi
    done
    
    if [[ $removed_count -gt 0 ]]; then
        log "Removed $removed_count desktop file(s)"
    fi
}

# ============================================================================
# MAIN
# ============================================================================
main() {
    log "Starting game desktop sync..."
    
    # Scan all game sources
    scan_steam_native
    scan_steam_flatpak
    scan_lutris
    scan_heroic
    scan_bottles
    scan_cartridges
    
    # Clean up desktop files for games that are no longer installed
    cleanup_removed_games
    
    # Update desktop database
    if command -v update-desktop-database &> /dev/null; then
        log "Updating desktop database..."
        update-desktop-database "$DESKTOP_DIR" 2>/dev/null || true
    fi
    
    log "Game desktop sync completed. Found ${#found_games[@]} game(s)."
}

main "$@"
