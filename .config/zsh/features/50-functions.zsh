#==========================================================#
#                    ZSH FUNCTIONS                         #
#==========================================================#
# File: features/50-functions.zsh
# Purpose: Define functions for use with ZSH
# Dependencies: Core ZSH configuration
# Last Updated: 2026-03-19
# Documentation: Custom functions for daily workflow
#==========================================================#

#========# Hyprland Session Management #===================#
#==========================================================#
 
# Start Hyprland via uwsm
hip() {
    if uwsm check may-start; then
        exec uwsm start hyprland.desktop
    fi
}

#========# Dotfiles Management #===========================#
#==========================================================#

# List all untracked files recursively, no filtering
dotua() {
    dotu '*/*'
}

# List untracked files and filter via excludes file
dotu() {
    local excludes_file="${HOME}/.config/dotfiles/excludes"
    local exclude_patterns=()

    # Read pathspec exclusion patterns
    if [[ -f "$excludes_file" ]]; then
        while IFS= read -r pattern; do
            [[ -n "$pattern" && ! "$pattern" =~ ^[[:space:]]*# ]] && \
                exclude_patterns+=("$pattern")
        done < "$excludes_file"
    fi

    git ls-files --others --exclude-standard "${exclude_patterns[@]}" "$@"
}

#========# Gamescope & Game Launcher #=====================#
#==========================================================#

# Gamescope wrapper with resolution presets
# Usage: gscope <resolution> [-- command...]
# Resolutions: 720p, 1080p, 1440p, 4k, or WxH (e.g. 2560x1440)
gscope() {
    local res="$1"
    shift 2>/dev/null

    local w h
    case "$res" in
        720p)  w=1280;  h=720  ;;
        1080p) w=1920;  h=1080 ;;
        1440p) w=2560;  h=1440 ;;
        4k)    w=3840;  h=2160 ;;
        *x*)   w="${res%%x*}"; h="${res%%;*}"; h="${h##*x}" ;;
        *)
            echo "Usage: gscope <resolution> [-- command...]"
            echo "  Resolutions: 720p, 1080p, 1440p, 4k, or WxH"
            echo "  Example: gscope 1440p -- steam steam://rungameid/12345"
            return 1
            ;;
    esac

    gamescope --force-windows-fullscreen \
        -w "$w" -h "$h" -W "$w" -H "$h" \
        -f -r 120 -F nis --adaptive-sync \
        "$@" 2>/dev/null
    true
}

# Find and launch a Steam game by partial name
# Usage: game [resolution] <search_term>
# Examples: game 1440p rogue | game 1080p rogue | game rogue
game() {
    local res="1440p"
    local search=""
    local steamapps="${HOME}/.steam/steam/steamapps"
    local skip_pattern="Proton|Steam Linux Runtime|Steamworks"

    # Parse args: if first arg looks like a resolution, use it
    case "$1" in
        720p|1080p|1440p|4k|*x*) res="$1"; shift ;;
    esac

    search="$*"
    if [[ -z "$search" ]]; then
        echo "game [resolution] <search>"
        echo "  resolutions: 720p 1080p 1440p 4k (default: 1440p)"
        echo ""

        local names=() statuses=()
        local id name size
        for manifest in "$steamapps"/appmanifest_*.acf(N); do
            id=$(grep -oP '"appid"\s+"\K[^"]+' "$manifest")
            name=$(grep -oP '"name"\s+"\K[^"]+' "$manifest")
            size=$(grep -oP '"SizeOnDisk"\s+"\K[^"]+' "$manifest")
            [[ "$name" =~ $skip_pattern ]] && continue
            names+=("$name")
            statuses+=("$([[ "$size" -gt 0 ]] && echo "ready" || echo "not installed")")
        done

        if (( ${#names[@]} == 0 )); then
            echo "  No games found."
            return 0
        fi

        local maxlen=0
        for n in "${names[@]}"; do (( ${#n} > maxlen )) && maxlen=${#n}; done

        for i in {1..${#names[@]}}; do
            printf "  %-${maxlen}s  %s\n" "${names[$i]}" "${statuses[$i]}"
        done
        return 0
    fi

    # Search manifests for matching game (case-insensitive)
    local match_ids=() match_names=()
    local id name

    for manifest in "$steamapps"/appmanifest_*.acf(N); do
        id=$(grep -oP '"appid"\s+"\K[^"]+' "$manifest")
        name=$(grep -oP '"name"\s+"\K[^"]+' "$manifest")
        [[ "$name" =~ $skip_pattern ]] && continue

        if [[ "${name:l}" == *"${search:l}"* ]]; then
            match_ids+=("$id")
            match_names+=("$name")
        fi
    done

    if (( ${#match_ids[@]} == 0 )); then
        echo "No games matching '$search'. Run 'game' to list installed games."
        return 1
    elif (( ${#match_ids[@]} > 1 )); then
        echo "Multiple matches:"
        for i in {1..${#match_ids[@]}}; do
            printf "  %d) %s\n" "$i" "${match_names[$i]}"
        done
        echo -n "Select [1-${#match_ids[@]}]: "
        read -r choice
        if (( choice < 1 || choice > ${#match_ids[@]} )); then
            echo "Cancelled."
            return 1
        fi
        local app_id="${match_ids[$choice]}"
        local app_name="${match_names[$choice]}"
    else
        local app_id="${match_ids[1]}"
        local app_name="${match_names[1]}"
    fi

    echo "Launching: $app_name @ $res"
    gscope "$res" -- steam "steam://rungameid/$app_id"
}

#========# Search & Analysis Functions #===================#
#==========================================================#

# Search for string in files using ripgrep
find_string() {
    if (( $# != 2 )); then
        echo "Usage: find_string <directory> <search_term>"
        return 1
    fi
    rg -nw "$2" -e "$1"
}

# Enhanced process search and kill
murder() {
    if [[ -z "$1" ]]; then
        echo "Usage: murder <process_name>"
        return 1
    fi

    local search="$1"
    local pids

    echo "Searching for processes matching '$search'..."

    # Find matching processes (excluding grep and current shell)
    pids=$(ps -ef | grep "$search" | grep -v grep | grep -v "murder $search" | awk '{print $2}')

    if [[ -z "$pids" ]]; then
        echo "No processes found matching '$search'"
        return 1
    fi

    echo "Found processes:"
    ps -ef | grep "$search" | grep -v grep | grep -v "murder $search"

    echo -n "Kill these processes? [y/N]: "
    read -r response

    if [[ "$response" =~ ^[Yy]$ ]]; then
        for pid in $pids; do
            echo "Killing PID $pid..."
            kill -9 "$pid" 2>/dev/null || echo "Failed to kill PID $pid"
        done
        echo "Process termination complete."
    else
        echo "Operation cancelled."
    fi
}

#========# Security & Password Functions #=================#
#==========================================================#

# Generate secure password
generate_secure_password() {
    local length="${1:-32}"
    local min_length=16
    local max_length=64

    # Validate length parameter
    if (( length < min_length || length > max_length )); then
        echo "Error: Length must be between $min_length and $max_length" >&2
        return 1
    fi

    # Use /dev/urandom for cryptographically secure random data
    # Base64 encoding ensures compatibility with various uses
    # Remove problematic characters for shell compatibility
    openssl rand -base64 "$length" | tr -d "=+/" | cut -c1-"$length"
}

#========# Log Analysis Functions #========================#
#==========================================================#

# Follow log file with syntax highlighting
flog() {
    if [[ -z "$1" ]]; then
        echo "Usage: flog <logfile>"
        return 1
    fi

    if [[ ! -f "$1" ]]; then
        echo "Error: File '$1' not found" >&2
        return 1
    fi

    tail --lines="50" --follow "$1" | bat --paging=never -l log
}

# Analyze log file for common patterns
analyze_log() {
    local logfile="$1"

    if [[ -z "$logfile" || ! -f "$logfile" ]]; then
        echo "Usage: analyze_log <logfile>"
        return 1
    fi

    echo "Log Analysis for: $logfile"
    echo "================================"
    echo "Total lines: $(wc -l < "$logfile")"
    echo "File size: $(du -sh "$logfile" | cut -f1)"
    echo ""
    echo "Top error patterns:"
    grep -i "error\|fail\|exception" "$logfile" | head -10 | cut -c1-80
    echo ""
    echo "Recent entries (last 10):"
    tail -10 "$logfile"
}

#========# Archive Functions #=============================#
#==========================================================#

# Unzip all zip files in a directory
unzipall() {
    if (( $# > 1  )); then
        find "$1" -name "*.zip" -exec unzip -P "$2" {} \;
    else
        find "$1" -name "*.zip" -exec unzip {} \;
    fi
}

#========# System Maintenance Functions #==================#
#==========================================================#

# Clean up system caches and temporary files
cleanup_system() {
    echo "System cleanup options:"
    echo ""
    echo "  1. Package cache (paru -Sc) - cleans uninstalled packages"
    echo "  2. AUR clone cache (~/.cache/paru/clone) - can fix git errors"
    echo "  3. User caches (yarn, npm, pip, go-build)"
    echo "  4. Systemd journals (older than 7 days)"
    echo "  5. All of the above"
    echo ""
    echo -n "Select option [1-5] or 'q' to quit: "
    read -r choice

    case "$choice" in
        1)
            echo ""
            echo "Cleaning package cache..."
            paru -Sc
            ;;
        2)
            local cache_size=$(du -sh "$HOME/.cache/paru/clone" 2>/dev/null | cut -f1)
            echo ""
            echo "AUR clone cache size: ${cache_size:-unknown}"
            echo -n "Remove entire AUR cache? This is safe, paru will re-clone as needed [y/N]: "
            read -r response
            if [[ "$response" =~ ^[Yy]$ ]]; then
                rm -rf "$HOME/.cache/paru/clone"
                echo "AUR cache removed"
            else
                echo "Skipped AUR cache cleanup"
            fi
            ;;
        3)
            echo ""
            echo "Cleaning user caches..."
            rm -rf "$XDG_CACHE_HOME"/{yarn,npm,pip,go-build}/* 2>/dev/null
            echo "Removed: yarn, npm, pip, go-build caches"
            ;;
        4)
            echo ""
            echo "Cleaning systemd journals..."
            sudo journalctl --vacuum-time=7d
            ;;
        5)
            echo ""
            echo "Running full system cleanup..."

            echo ""
            echo "1/4: Cleaning package cache..."
            paru -Sc

            echo ""
            local cache_size=$(du -sh "$HOME/.cache/paru/clone" 2>/dev/null | cut -f1)
            echo "2/4: AUR clone cache size: ${cache_size:-unknown}"
            echo -n "Remove entire AUR cache? Recommended to avoid git errors [Y/n]: "
            read -r response
            if [[ ! "$response" =~ ^[Nn]$ ]]; then
                rm -rf "$HOME/.cache/paru/clone"
                echo "AUR cache removed"
            else
                echo "Skipped AUR cache cleanup"
            fi

            echo ""
            echo "3/4: Cleaning user caches..."
            rm -rf "$XDG_CACHE_HOME"/{yarn,npm,pip,go-build}/* 2>/dev/null
            echo "Removed: yarn, npm, pip, go-build caches"

            echo ""
            echo "4/4: Cleaning systemd journals..."
            sudo journalctl --vacuum-time=7d

            echo ""
            echo "Full system cleanup complete!"
            ;;
        q|Q)
            echo "Cleanup cancelled."
            return 0
            ;;
        *)
            echo "Invalid option. Cleanup cancelled."
            return 1
            ;;
    esac
}

#========# Media Conversion Functions #===================#
#==========================================================#

# Convert MP4 to GIF using ffmpeg with palette optimization
# Usage: mp4togif <input.mp4> <output.gif> [fps] [scale]
# fps defaults to 30, scale defaults to 320 (width; height auto-scaled)
mp4togif() {
    if (( $# < 2 )); then
        echo "Usage: mp4togif <input.mp4> <output.gif> [fps] [scale]"
        echo "  fps:   frames per second (default: 30)"
        echo "  scale: output width in px, height auto-scaled (default: 320)"
        return 1
    fi

    local input="$1"
    local output="$2"
    local fps="${3:-30}"
    local scale="${4:-320}"

    if [[ ! -f "$input" ]]; then
        echo "Error: input file '$input' not found" >&2
        return 1
    fi

    # Two-pass palette approach: generates optimal palette from source,
    # then applies it — avoids ffmpeg's default 256-color dithering artifacts
    ffmpeg -i "$input" \
        -vf "fps=${fps},scale=${scale}:-1:flags=lanczos,split[s0][s1];[s0]palettegen[p];[s1][p]paletteuse" \
        -loop 0 \
        "$output"
}

# Convert MP4 to animated WebP using ffmpeg/libwebp
# Usage: mp4towebp <input.mp4> <output.webp> [fps] [scale] [quality]
# fps defaults to source rate (-1), scale defaults to -1 (native width),
# quality defaults to 75 (0-100, higher = better quality, larger file)
# WebP yields ~10x smaller files than GIF at equivalent quality with full color
mp4towebp() {
    if (( $# < 2 )); then
        echo "Usage: mp4towebp <input.mp4> <output.webp> [fps] [scale] [quality]"
        echo "  fps:     frames per second (default: source rate)"
        echo "  scale:   output width in px, height auto-scaled (default: native)"
        echo "  quality: 0-100, higher = better/larger (default: 75)"
        return 1
    fi

    local input="$1"
    local output="$2"
    local fps="${3:--1}"
    local scale="${4:--1}"
    local quality="${5:-75}"

    if [[ ! -f "$input" ]]; then
        echo "Error: input file '$input' not found" >&2
        return 1
    fi

    # Build filter chain conditionally so defaults preserve source properties
    local vf=""
    if [[ "$fps" != "-1" ]]; then
        vf="fps=${fps}"
    fi
    if [[ "$scale" != "-1" ]]; then
        [[ -n "$vf" ]] && vf="${vf},"
        vf="${vf}scale=${scale}:-1:flags=lanczos"
    fi

    # compression_level 6 = max effort, preset picture = photographic content,
    # -vsync 0 preserves variable frame timing, -an drops audio (WebP has no audio)
    local ffmpeg_args=(-y -i "$input" -vcodec libwebp -lossless 0
        -compression_level 6 -q:v "$quality" -loop 0 -preset picture -an -vsync 0)
    if [[ -n "$vf" ]]; then
        ffmpeg_args+=(-filter:v "$vf")
    fi
    ffmpeg_args+=("$output")

    ffmpeg "${ffmpeg_args[@]}"
}

#========# Dynamic Function Loading #======================#
#==========================================================#

# Load additional functions from functions.d directory
load_function_extensions() {
    local functions_dir="$XDG_CONFIG_HOME/zsh/functions.d"

    if [[ -d "$functions_dir" ]]; then
        # Use safe globbing to avoid errors
        local func_files=("$functions_dir"/*.{sh,zsh}(N))
        for func_file in "${func_files[@]}"; do
            [[ -r "$func_file" ]] && source "$func_file"
        done
    fi
}

# Load function extensions
load_function_extensions
