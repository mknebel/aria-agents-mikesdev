#!/bin/bash
#
# WSL Projects launcher for tmux + Codex/Claude workflow.
# Related configs:
#   - ~/.tmux.conf       (pane headers/footers, per-pane labels + tool)
#   - ~/.bashrc          (prompt + tmux metadata sync)
#   - ~/.project-menu.conf (project list)
#
# A snapshot of this script, tmux/bash config, and Windows Terminal settings
# is stored at:
#   /mnt/d/backups/tmux-wsl-20251203-0440
# See that folder's README.md for restore instructions.

CONFIG_FILE="$HOME/.project-menu.conf"
BOOKMARKS_FILE="$HOME/.project-menu.bookmarks"
RECENTS_FILE="$HOME/.project-menu.recents"
export PATH="$HOME/.npm-global/bin:$PATH"

CODEX_BIN="$HOME/.npm-global/bin/codex"
[[ -x "$CODEX_BIN" ]] || CODEX_BIN="$(command -v codex 2>/dev/null)"
CLAUDE_BIN="$HOME/.npm-global/bin/claude"
[[ -x "$CLAUDE_BIN" ]] || CLAUDE_BIN="$(command -v claude 2>/dev/null)"
DEFAULT_SHELL="${SHELL:-/bin/bash}"
SCRIPT_SELF="$(command -v realpath >/dev/null 2>&1 && realpath -m "$0" 2>/dev/null || readlink -f "$0" 2>/dev/null || printf '%s' "$0")"
SCRIPT_ARGS=("$@")
AUTO_RESUME_REQUEST="${PROJECT_MENU_AUTO_RESUME:-}"
LAST_USED_LABEL="${PROJECT_MENU_LAST_LABEL:-}"
LAST_USED_PATH="${PROJECT_MENU_LAST_PATH:-}"
LAST_USED_TOOL="${PROJECT_MENU_LAST_TOOL:-}"
unset PROJECT_MENU_AUTO_RESUME
export PROJECT_SESSION_TOOL="${PROJECT_SESSION_TOOL:-Other}"

# If tmux is available, run the project menu inside a fresh tmux session
# (do not re-attach to any existing sessions).
if command -v tmux >/dev/null 2>&1; then
    if [[ -z "$TMUX" && -t 1 && -z "${PROJECT_MENU_IN_TMUX:-}" ]]; then
        export PROJECT_MENU_IN_TMUX=1
        tmux new-session "$SCRIPT_SELF" "${SCRIPT_ARGS[@]}"
        # When the tmux session ends (e.g. via menu option), drop to a plain shell.
        exec "$DEFAULT_SHELL" -i
    fi
fi

# Colors
BOLD="\e[1m"
DIM="\e[2m"
RESET="\e[0m"
CYAN="\e[36m"
GREEN="\e[32m"
YELLOW="\e[33m"
RED="\e[31m"

declare -A PROJECTS
declare -A PROJECT_TOOLS
declare -A PROJECT_SOURCE
declare -a PROJECT_ORDER

declare -A BOOKMARKS
declare -A BOOKMARK_TOOLS
declare -a BOOKMARK_ORDER

declare -A RECENT_PATHS
declare -A RECENT_TOOLS
declare -a RECENT_ORDER

trim_whitespace() {
    local var="$1"
    var="${var#"${var%%[![:space:]]*}"}"
    var="${var%"${var##*[![:space:]]}"}"
    printf '%s' "$var"
}

resolve_path_gently() {
    local target="$1"
    if command -v realpath >/dev/null 2>&1; then
        realpath -m "$target" 2>/dev/null || printf '%s' "$target"
    else
        readlink -f "$target" 2>/dev/null || printf '%s' "$target"
    fi
}

wsl_to_windows_path() {
    local wsl_path="$1"
    if [[ "$wsl_path" =~ ^/mnt/([a-zA-Z])(.*)$ ]]; then
        local drive="${BASH_REMATCH[1]}"
        local rest="${BASH_REMATCH[2]}"
        rest="${rest//\\//}"
        rest="${rest##/}"
        if [[ -n "$rest" ]]; then
            echo "${drive^^}:/$rest"
        else
            echo "${drive^^}:/"
        fi
        return 0
    fi
    return 1
}

windows_to_wsl_path() {
    local win_path="$1"
    if [[ "$win_path" =~ ^([A-Za-z]):[\\/]?(.*)$ ]]; then
        local drive="${BASH_REMATCH[1],,}"
        local rest="${BASH_REMATCH[2]}"
        rest="${rest//\\//}"
        rest="${rest##/}"
        if [[ -n "$rest" ]]; then
            echo "/mnt/${drive}/$rest"
        else
            echo "/mnt/${drive}"
        fi
        return 0
    fi
    return 1
}

normalize_windows_path_input() {
    local raw="$1"
    local candidate
    candidate="$(trim_whitespace "$raw")"
    [[ -z "$candidate" ]] && return 1

    if [[ "$candidate" == ~* ]]; then
        candidate="${candidate/#~/$HOME}"
        candidate="$(resolve_path_gently "$candidate")"
    elif [[ "$candidate" == .* || "$candidate" == ..* || "$candidate" == . || "$candidate" == .. ]]; then
        candidate="$(resolve_path_gently "$candidate")"
    fi

    if [[ "$candidate" == /* ]]; then
        local as_win
        if as_win="$(wsl_to_windows_path "$candidate")"; then
            echo "$as_win"
            return 0
        fi
    fi

    if [[ "$candidate" =~ ^[A-Za-z]: ]]; then
        local drive="${candidate:0:1}"
        local rest="${candidate:2}"
        rest="${rest//\\//}"
        rest="${rest##/}"
        echo "${drive^^}:/$rest"
        return 0
    fi

    return 1
}

canonicalize_tool_key() {
    local raw="$(trim_whitespace "$1")"
    case "${raw,,}" in
        codex)
            echo "codex"
            ;;
        claude)
            echo "claude"
            ;;
        *)
            echo ""
            ;;
    esac
}

format_tool_label() {
    local canonical="$(canonicalize_tool_key "$1")"
    case "$canonical" in
        codex)
            echo "Codex"
            ;;
        claude)
            echo "Claude"
            ;;
        *)
            echo ""
            ;;
    esac
}

set_tab_title() {
    local title="$1"
    printf '\033]0;%s\007' "$title"
}

launch_interactive_shell() {
    local lock_title="${1:-}"
    if [[ "$DEFAULT_SHELL" == *bash || "$DEFAULT_SHELL" == *zsh ]]; then
        if [[ "$lock_title" == "lock" ]]; then
            export PROJECT_MENU_LOCK_TITLE=1
        else
            unset PROJECT_MENU_LOCK_TITLE
        fi
        export PROJECT_MENU_SKIP_AUTOSTART=1
        exec "$DEFAULT_SHELL" -i
    else
        exec "$DEFAULT_SHELL"
    fi
}

load_projects() {
    PROJECTS=()
    PROJECT_TOOLS=()
    PROJECT_SOURCE=()
    PROJECT_ORDER=()
    if [[ ! -f "$CONFIG_FILE" ]]; then
        echo -e "${RED}Config file not found:${RESET} $CONFIG_FILE"
        echo "Create it with lines like:"
        echo "Label|D:/MikesDev/www/SomeProject"
        read -p "Press Enter to exit..."
        exit 1
    fi

    while IFS='|' read -r name path tool extra; do
        [[ -z "$name" || -z "$path" ]] && continue
        PROJECTS["$name"]="$path"
        local tool_trimmed="$(canonicalize_tool_key "${tool:-}")"
        PROJECT_TOOLS["$name"]="$tool_trimmed"
        PROJECT_SOURCE["$name"]="config"
        PROJECT_ORDER+=("$name")
    done < "$CONFIG_FILE"

    add_special_entries
}

load_bookmarks() {
    BOOKMARKS=()
    BOOKMARK_TOOLS=()
    BOOKMARK_ORDER=()

    [[ -f "$BOOKMARKS_FILE" ]] || return

    while IFS='|' read -r name path tool extra; do
        [[ -z "$name" || -z "$path" ]] && continue
        BOOKMARKS["$name"]="$path"
        local tool_trimmed
        tool_trimmed="$(canonicalize_tool_key "${tool:-}")"
        BOOKMARK_TOOLS["$name"]="$tool_trimmed"
        BOOKMARK_ORDER+=("$name")
    done < "$BOOKMARKS_FILE"
}

load_recents() {
    RECENT_PATHS=()
    RECENT_TOOLS=()
    RECENT_ORDER=()

    [[ -f "$RECENTS_FILE" ]] || return

    while IFS='|' read -r name path tool extra; do
        [[ -z "$name" || -z "$path" ]] && continue
        RECENT_PATHS["$name"]="$path"
        local tool_trimmed
        tool_trimmed="$(canonicalize_tool_key "${tool:-}")"
        RECENT_TOOLS["$name"]="$tool_trimmed"
        RECENT_ORDER+=("$name")
    done < "$RECENTS_FILE"
}

add_special_entries() {
    local home_label="Home (~)"
    if [[ -z "${PROJECTS[$home_label]+x}" ]]; then
        PROJECTS["$home_label"]="$HOME"
        PROJECT_TOOLS["$home_label"]=""
        PROJECT_SOURCE["$home_label"]="special"
        PROJECT_ORDER+=("$home_label")
    fi
}

restart_menu() {
    echo -e "${CYAN}Refreshing project menu...${RESET}"
    sleep 0.5
    exec "$SCRIPT_SELF" "${SCRIPT_ARGS[@]}"
}

reload_bashrc() {
    local mode="$1"
    if [[ -f "$HOME/.bashrc" ]]; then
        # shellcheck disable=SC1090
        source "$HOME/.bashrc" >/dev/null 2>&1 || true
        echo -e "${GREEN}Reloaded ~/.bashrc in this session.${RESET}"
    else
        echo -e "${YELLOW}~/.bashrc not found.${RESET}"
    fi
    if [[ "$mode" == "quiet" ]]; then
        sleep 0.5
    else
        sleep 1
    fi
}

reload_bashrc_and_restart() {
    reload_bashrc quiet
    if [[ -n "$LAST_USED_LABEL" && ( "$LAST_USED_TOOL" == "codex" || "$LAST_USED_TOOL" == "claude" ) ]]; then
        export PROJECT_MENU_AUTO_RESUME=1
    else
        unset PROJECT_MENU_AUTO_RESUME
    fi
    restart_menu
}

browse_and_launch_tool() {
    local start_win_path="${1:-D:/MikesDev/www}"
    start_win_path="${start_win_path//\\//}"

    local current_win_path="$start_win_path"

    while true; do
        local current_wsl_path=""
        if ! current_wsl_path="$(windows_to_wsl_path "$current_win_path")"; then
            echo -e "${RED}Cannot convert Windows path to WSL path:${RESET} $current_win_path"
            sleep 2
            return
        fi

        if [[ ! -d "$current_wsl_path" ]]; then
            echo -e "${RED}Directory does not exist:${RESET} $current_win_path"
            sleep 2
            return
        fi

        clear
        echo -e "${BOLD}${CYAN}Browse folders to launch Codex/Claude${RESET}"
        echo
        echo "Current folder (Windows): $current_win_path"
        echo "Current folder (WSL)    : $current_wsl_path"
        echo

        local -a DIRS=()
        local d
        for d in "$current_wsl_path"/*/; do
            [[ -d "$d" ]] || continue
            local base="${d%/}"
            base="${base##*/}"
            DIRS+=("$base")
        done

        if ((${#DIRS[@]} == 0)); then
            echo "No subfolders."
        else
            echo "Subfolders:"
            local idx=1
            for base in "${DIRS[@]}"; do
                printf "  %2d) %s\n" "$idx" "$base"
                ((idx++))
            done
        fi

        echo
        echo "Options:"
        echo "  0) Go up to parent folder"
        echo "  C) Run Codex here (--yolo)"
        echo "  L) Run Claude here (--dangerously-skip-permissions)"
        echo "  S) Save this folder as bookmark"
        echo "  B) Back to Tools menu"
        echo
        read -rp "Enter choice (number/C/L/S/B): " BROWSE_CHOICE

        case "$BROWSE_CHOICE" in
            0)
                local parent="$current_win_path"
                if [[ "$current_win_path" == *"/"* ]]; then
                    parent="${current_win_path%/*}"
                fi
                if [[ "$parent" == "$current_win_path" || -z "$parent" ]]; then
                    echo -e "${YELLOW}Already at top-level for this drive.${RESET}"
                    sleep 1
                else
                    current_win_path="$parent"
                fi
                ;;
            [0-9]*)
                if [[ ! "$BROWSE_CHOICE" =~ ^[0-9]+$ ]]; then
                    echo -e "${RED}Invalid choice.${RESET}"
                    sleep 1
                    continue
                fi
                local choice_num="$BROWSE_CHOICE"
                if (( choice_num < 1 || choice_num > ${#DIRS[@]} )); then
                    echo -e "${RED}Invalid folder number.${RESET}"
                    sleep 1
                    continue
                fi
                local next_name="${DIRS[choice_num-1]}"
                if [[ -z "$next_name" ]]; then
                    echo -e "${RED}Invalid folder name.${RESET}"
                    sleep 1
                    continue
                fi
                if [[ "$current_win_path" == */ ]]; then
                    current_win_path="${current_win_path}${next_name}"
                else
                    current_win_path="${current_win_path}/${next_name}"
                fi
                ;;
            [Cc])
                local label_path="${current_win_path//\\//}"
                label_path="${label_path%/}"
                local label="${label_path##*/}"
                [[ -z "$label" ]] && label="$current_win_path"
                launch_tool_for_project "codex" "$label" "$current_win_path" "[$label]" "browse"
                return
                ;;
            [Ll])
                local label_path="${current_win_path//\\//}"
                label_path="${label_path%/}"
                local label="${label_path##*/}"
                [[ -z "$label" ]] && label="$current_win_path"
                launch_tool_for_project "claude" "$label" "$current_win_path" "[$label]" "browse"
                return
                ;;
            [Ss])
                local label_path="${current_win_path//\\//}"
                label_path="${label_path%/}"
                local default_label="${label_path##*/}"
                [[ -z "$default_label" ]] && default_label="$current_win_path"

                echo
                read -rp "Bookmark name${default_label:+ [$default_label]}: " BM_LABEL_INPUT
                local BM_LABEL
                BM_LABEL="$(trim_whitespace "$BM_LABEL_INPUT")"
                [[ -z "$BM_LABEL" ]] && BM_LABEL="$default_label"

                if [[ -z "$BM_LABEL" ]]; then
                    echo -e "${RED}Bookmark name is required.${RESET}"
                    sleep 1.5
                    continue
                fi

                echo
                echo "You are about to bookmark:"
                echo "  Name : $BM_LABEL"
                echo "  Path : $current_win_path"
                echo
                read -rp "Save this bookmark to $BOOKMARKS_FILE ? [y/N]: " BM_CONFIRM

                if [[ "$BM_CONFIRM" =~ ^[Yy]$ ]]; then
                    if touch "$BOOKMARKS_FILE" 2>/dev/null; then
                        echo "${BM_LABEL}|${current_win_path}" >> "$BOOKMARKS_FILE"
                        echo -e "${GREEN}Bookmark saved.${RESET}"
                    else
                        echo -e "${RED}Cannot write to:${RESET} $BOOKMARKS_FILE"
                    fi
                else
                    echo -e "${YELLOW}Aborted.${RESET}"
                fi
                sleep 1.5
                ;;
            [Bb])
                return
                ;;
            *)
                echo -e "${RED}Invalid choice.${RESET}"
                sleep 1
                ;;
        esac
    done
}

prompt_add_project() {
    local current_wsl_path="$(resolve_path_gently "$PWD")"
    local detected_wpath=""
    if detected_wpath="$(wsl_to_windows_path "$current_wsl_path")"; then
        :
    else
        detected_wpath=""
    fi

    while true; do
        clear
        echo -e "${BOLD}${CYAN}Add a new project${RESET}"
        echo
        echo "Current WSL path : $current_wsl_path"
        if [[ -n "$detected_wpath" ]]; then
            echo "Detected Windows path: $detected_wpath"
            echo "Press Enter to use it or enter another Windows/WSL path."
        else
            echo -e "${YELLOW}Enter a Windows path (e.g. D:/Apps/NewProject) or a /mnt/... WSL path.${RESET}"
        fi
        echo
        read -rp "Windows path${detected_wpath:+ [$detected_wpath]}: " WPATH_INPUT
        [[ -z "$WPATH_INPUT" ]] && WPATH_INPUT="$detected_wpath"

        if [[ -z "$WPATH_INPUT" ]]; then
            echo -e "${RED}A path is required.${RESET}"
            sleep 1.5
            continue
        fi

        local NORMALIZED_WPATH
        if ! NORMALIZED_WPATH="$(normalize_windows_path_input "$WPATH_INPUT")"; then
            echo -e "${RED}Could not parse that path. Use a Windows path like D:/Apps/Proj or a /mnt/... path.${RESET}"
            sleep 2
            continue
        fi

        local WPATH="$NORMALIZED_WPATH"
        local default_label="$(basename "${WPATH//\\//}")"
        [[ -z "$default_label" ]] && default_label="Project"

        read -rp "Label${default_label:+ [$default_label]}: " LABEL_INPUT
        local LABEL="$(trim_whitespace "$LABEL_INPUT")"
        [[ -z "$LABEL" ]] && LABEL="$default_label"

        if [[ -z "$LABEL" ]]; then
            echo -e "${RED}Label is required.${RESET}"
            sleep 1.5
            continue
        fi

        local chosen_wsl_path=""
        if chosen_wsl_path="$(windows_to_wsl_path "$WPATH")"; then
            :
        fi

        echo
        echo "You entered:"
        echo "  Label       : $LABEL"
        echo "  Windows path: $WPATH"
        [[ -n "$chosen_wsl_path" ]] && echo "  WSL path    : $chosen_wsl_path"
        echo
        read -rp "Save this to $CONFIG_FILE ? [y/N]: " CONFIRM

        if [[ "$CONFIRM" =~ ^[Yy]$ ]]; then
            touch "$CONFIG_FILE"
            echo "${LABEL}|${WPATH}" >> "$CONFIG_FILE"
            echo -e "${GREEN}Saved.${RESET}"
        else
            echo -e "${YELLOW}Aborted.${RESET}"
        fi

        sleep 1.5
        return
    done
}

edit_projects_config() {
    touch "$CONFIG_FILE" 2>/dev/null || {
        echo -e "${RED}Cannot create or access:${RESET} $CONFIG_FILE"
        sleep 1.5
        return
    }

    local editor_setting="${EDITOR:-nano}"
    [[ -z "$editor_setting" ]] && editor_setting="nano"

    local -a editor_cmd=()
    IFS=' ' read -r -a editor_cmd <<<"$editor_setting"
    if [[ ${#editor_cmd[@]} -eq 0 ]]; then
        echo -e "${RED}No editor configured. Set \$EDITOR or install nano.${RESET}"
        sleep 1.5
        return
    fi

    if ! command -v "${editor_cmd[0]}" >/dev/null 2>&1; then
        if command -v nano >/dev/null 2>&1; then
            editor_cmd=(nano)
        else
            echo -e "${RED}Editor not found:${RESET} ${editor_cmd[0]}"
            sleep 1.5
            return
        fi
    fi

    echo -e "${CYAN}Opening $CONFIG_FILE with ${editor_cmd[0]}...${RESET}"
    sleep 0.3
    "${editor_cmd[@]}" "$CONFIG_FILE"
}

remove_project_from_config() {
    local label="$1"
    local path="$2"
    [[ -f "$CONFIG_FILE" ]] || return 1

    local tmp_file
    tmp_file="$(mktemp "${CONFIG_FILE}.XXXXXX")" || return 1

    if awk -F'|' -v label="$label" -v path="$path" '!( $1 == label && $2 == path )' "$CONFIG_FILE" > "$tmp_file"; then
        mv "$tmp_file" "$CONFIG_FILE"
        return 0
    else
        rm -f "$tmp_file"
        return 1
    fi
}

remove_bookmark_from_file() {
    local label="$1"
    local path="$2"
    [[ -f "$BOOKMARKS_FILE" ]] || return 1

    local tmp_file
    tmp_file="$(mktemp "${BOOKMARKS_FILE}.XXXXXX")" || return 1

    if awk -F'|' -v label="$label" -v path="$path" '!( $1 == label && $2 == path )' "$BOOKMARKS_FILE" > "$tmp_file"; then
        mv "$tmp_file" "$BOOKMARKS_FILE"
        return 0
    else
        rm -f "$tmp_file"
        return 1
    fi
}

record_recent_project() {
    local label="$1"
    local path="$2"
    local tool_raw="$3"
    local tool
    tool="$(canonicalize_tool_key "$tool_raw")"

    touch "$RECENTS_FILE" 2>/dev/null || return 1

    local tmp_file cut_file
    tmp_file="$(mktemp "${RECENTS_FILE}.XXXXXX")" || return 1
    cut_file="$(mktemp "${RECENTS_FILE}.XXXXXX.cut")" || {
        rm -f "$tmp_file"
        return 1
    }

    printf '%s|%s|%s\n' "$label" "$path" "$tool" > "$tmp_file"
    awk -F'|' -v label="$label" -v path="$path" '!( $1 == label && $2 == path )' "$RECENTS_FILE" >> "$tmp_file"

    head -n 20 "$tmp_file" > "$cut_file"
    mv "$cut_file" "$RECENTS_FILE"
    rm -f "$tmp_file"
}

set_project_tool() {
    local label="$1"
    local path="$2"
    local tool_raw="$3"
    local tool_value="$(canonicalize_tool_key "$tool_raw")"
    [[ -f "$CONFIG_FILE" ]] || return 1

    local tmp_file
    tmp_file="$(mktemp "${CONFIG_FILE}.XXXXXX")" || return 1

    if awk -F'|' -v label="$label" -v path="$path" -v tool="$tool_value" '
        BEGIN { OFS="|" }
        {
            if ($1 == label && $2 == path) {
                if (tool == "") {
                    print $1, $2
                } else {
                    print $1, $2, tool
                }
            } else {
                if (NF >= 3 && $3 != "") {
                    print $1, $2, $3
                } else {
                    print $1, $2
                }
            }
        }
    ' "$CONFIG_FILE" > "$tmp_file"; then
        mv "$tmp_file" "$CONFIG_FILE"
        return 0
    else
        rm -f "$tmp_file"
        return 1
    fi
}

record_last_tool() {
    local label="$1"
    local path="$2"
    local tool="$3"
    export PROJECT_MENU_LAST_LABEL="$label"
    export PROJECT_MENU_LAST_PATH="$path"
    export PROJECT_MENU_LAST_TOOL="$tool"
    LAST_USED_LABEL="$label"
    LAST_USED_PATH="$path"
    LAST_USED_TOOL="$tool"
}

prompt_for_session_label() {
    local default_label="$1"
    local label_input=""

    # If not an interactive terminal, just use the default.
    if [[ ! -t 0 ]]; then
        label_input="$default_label"
    else
        echo
        echo -e "${CYAN}Session label for header/footer${RESET}"
        read -rp "Label [${default_label}]: " label_input
    fi

    label_input="$(trim_whitespace "$label_input")"
    [[ -z "$label_input" ]] && label_input="$default_label"

    export PROJECT_SESSION_LABEL="$label_input"

    if command -v tmux >/dev/null 2>&1 && [[ -n "$TMUX" ]]; then
        # Store the label as a per-pane option so each pane can have its own label.
        tmux set-option -pt "${TMUX_PANE:-.}" @pane_label "$label_input"
    fi
}

launch_tool_for_project() {
    local tool="$1"
    local name="$2"
    local path_input="$3"
    local tab_label="$4"
    local source="${5:-config}"

    if [[ -z "$tool" || -z "$name" || -z "$path_input" ]]; then
        echo -e "${RED}Missing information to start tool.${RESET}"
        sleep 1
        return 1
    fi

    local path_wsl=""
    local using_wsl_path=0
    if [[ "$path_input" == /* ]]; then
        path_wsl="$path_input"
        using_wsl_path=1
    else
        if ! path_wsl="$(windows_to_wsl_path "$path_input")"; then
            echo -e "${RED}Cannot convert Windows path to WSL path:${RESET} $path_input"
            sleep 2
            return 1
        fi
    fi

    cd "$path_wsl" || {
        echo -e "${RED}Cannot cd into:${RESET} $path_input"
        echo "Resolved WSL path: $path_wsl"
        sleep 2
        return 1
    }

    # Ask for a short session label so headers/footers describe the work.
    local default_label="$name"
    prompt_for_session_label "$default_label"

    case "$tool" in
        codex)
            if [[ -x "$CODEX_BIN" ]]; then
                if [[ "$source" == "config" && $using_wsl_path -eq 0 ]]; then
                    set_project_tool "$name" "$path_input" "codex" || true
                fi
                PROJECT_TOOLS["$name"]="codex"
                record_last_tool "$name" "$path_input" "codex"
                record_recent_project "$name" "$path_input" "codex" || true
                export PROJECT_SESSION_TOOL="Codex"
                if command -v tmux >/dev/null 2>&1 && [[ -n "$TMUX" ]]; then
                    tmux set-option -pt "${TMUX_PANE:-.}" @pane_tool "Codex"
                fi
                set_tab_title "${tab_label} Codex"
                "$CODEX_BIN" --yolo
                launch_interactive_shell lock
            else
                echo -e "${RED}Codex CLI not found in PATH.${RESET}"
                sleep 2
                return 1
            fi
            ;;
        claude)
            if [[ -x "$CLAUDE_BIN" ]]; then
                if [[ "$source" == "config" && $using_wsl_path -eq 0 ]]; then
                    set_project_tool "$name" "$path_input" "claude" || true
                fi
                PROJECT_TOOLS["$name"]="claude"
                record_last_tool "$name" "$path_input" "claude"
                record_recent_project "$name" "$path_input" "claude" || true
                export PROJECT_SESSION_TOOL="Claude"
                if command -v tmux >/dev/null 2>&1 && [[ -n "$TMUX" ]]; then
                    tmux set-option -pt "${TMUX_PANE:-.}" @pane_tool "Claude"
                fi
                set_tab_title "${tab_label} Claude"
                # Auto-index project in background (non-blocking)
                "$HOME/.claude/scripts/index-v2/auto-index.sh" "$(pwd)" &
                "$CLAUDE_BIN" --dangerously-skip-permissions "use aria"
                launch_interactive_shell lock
            else
                echo -e "${RED}Claude CLI not found in PATH.${RESET}"
                sleep 2
                return 1
            fi
            ;;
        *)
            echo -e "${RED}Unsupported tool:${RESET} $tool"
            sleep 1
            return 1
            ;;
    esac
}

auto_resume_previous_tool_if_requested() {
    if [[ "$AUTO_RESUME_REQUEST" != "1" ]]; then
        return 1
    fi

    AUTO_RESUME_REQUEST=""
    local label="$LAST_USED_LABEL"
    local tool="$LAST_USED_TOOL"
    [[ -n "$label" && -n "$tool" ]] || return 1

    local path="${PROJECTS[$label]}"
    [[ -n "$path" ]] || path="$LAST_USED_PATH"
    [[ -n "$path" ]] || return 1
    local source="${PROJECT_SOURCE[$label]:-config}"

    case "$tool" in
        codex|claude)
            echo -e "${CYAN}Resuming ${tool^} for ${BOLD}$label${RESET}${CYAN}...${RESET}"
            sleep 0.5
            launch_tool_for_project "$tool" "$label" "$path" "[$label]" "$source"
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

tools_menu() {
    while true; do
        local current_wsl_path="$(resolve_path_gently "$PWD")"
        local current_win_path=""
        if current_win_path="$(wsl_to_windows_path "$current_wsl_path")"; then
            :
        else
            current_win_path=""
        fi

        clear
        echo -e "${BOLD}${CYAN}Tools${RESET}"
        echo
        echo "Current folder (WSL): $current_wsl_path"
        [[ -n "$current_win_path" ]] && echo "Current folder (Windows): $current_win_path"
        echo
        echo -e "${GREEN}1)${RESET} Add Current Folder as Project"
        echo -e "${GREEN}2)${RESET} Browse Folders and Launch Codex/Claude"
        echo -e "${GREEN}3)${RESET} Reload ~/.bashrc, Restart Menu (resume last Codex/Claude)"
        echo -e "${GREEN}4)${RESET} Edit Project List ($CONFIG_FILE)"
        echo -e "${GREEN}5)${RESET} Reload shell and exit to command line"
        echo -e "${GREEN}B)${RESET} Back to Project List"
        echo -e "${RED}0) Exit${RESET}"
        echo
        read -p "Enter choice: " TOOL_CHOICE

        case "$TOOL_CHOICE" in
            1)
                prompt_add_project
                ;;
            2)
                browse_and_launch_tool
                ;;
            3)
                reload_bashrc_and_restart
                ;;
            4)
                edit_projects_config
                ;;
            5)
                reload_bashrc quiet
                echo -e "${GREEN}Shell reloaded. Exiting to command line...${RESET}"
                sleep 0.5
                set_tab_title ""
                launch_interactive_shell
                ;;
            0)
                set_tab_title ""
                launch_interactive_shell
                ;;
            [Bb])
                return
                ;;
            *)
                echo -e "${RED}Invalid choice.${RESET}"
                sleep 1
                ;;
        esac
    done
}

show_bookmarks_menu() {
    set_tab_title "[Saved]"

    while true; do
        load_bookmarks

        clear
        echo -e "${BOLD}${CYAN}Saved / bookmarked folders${RESET}"
        echo

        if ((${#BOOKMARK_ORDER[@]} == 0)); then
            echo "No saved projects yet."
            echo
            echo -e "${GREEN}T)${RESET} Tools"
            echo -e "${GREEN}B)${RESET} Back to Project List"
            echo -e "${RED}0) Exit${RESET}"
            echo
            read -p "Enter choice: " CHOICE

            if [[ "$CHOICE" == "0" ]]; then
                set_tab_title ""
                launch_interactive_shell
            fi

            if [[ "$CHOICE" =~ ^[Tt]$ ]]; then
                tools_menu
                continue
            fi

            if [[ "$CHOICE" =~ ^[Bb]$ ]]; then
                set_tab_title "[Projects]"
                return
            fi

            echo -e "${RED}Invalid choice.${RESET}"
            sleep 1
            continue
        fi

        local i=1
        local -a OPTIONS=()
        local max_label=12
        for name in "${BOOKMARK_ORDER[@]}"; do
            (( ${#name} > max_label )) && max_label=${#name}
        done

        local header_label="Project"
        local header_path="Path"

        printf "%b%-4s%b | %b%-*s%b | %b%s%b\n" \
            "$BOLD" "#" "$RESET" \
            "$BOLD" "$max_label" "$header_label" "$RESET" \
            "$BOLD" "$header_path" "$RESET"
        printf "%s\n" "$(printf '%*s' $((max_label + ${#header_path} + 9)) '' | tr ' ' '-')"

        for name in "${BOOKMARK_ORDER[@]}"; do
            local path="${BOOKMARKS[$name]}"
            printf "%b%2d)%b | %b%-*s%b | %b%s%b\n" \
                "$GREEN" "$i" "$RESET" \
                "$YELLOW" "$max_label" "$name" "$RESET" \
                "$DIM" "$path" "$RESET"
            OPTIONS[$i]="$name"
            ((i++))
        done

        echo -e "${GREEN}B)${RESET} Back to Project List"
        echo -e "${GREEN}T)${RESET} Tools"
        echo -e "${RED}0) Exit${RESET}"
        echo
        read -p "Enter choice: " CHOICE

        if [[ "$CHOICE" == "0" ]]; then
            set_tab_title ""
            launch_interactive_shell
        fi

        if [[ "$CHOICE" =~ ^[Bb]$ ]]; then
            set_tab_title "[Projects]"
            return
        fi

        if [[ "$CHOICE" =~ ^[Tt]$ ]]; then
            tools_menu
            continue
        fi

        if [[ ! "$CHOICE" =~ ^[0-9]+$ ]]; then
            echo -e "${RED}Invalid choice.${RESET}"
            sleep 1
            continue
        fi

        if (( CHOICE < 1 || CHOICE > ${#BOOKMARK_ORDER[@]} )); then
            echo -e "${RED}Invalid choice.${RESET}"
            sleep 1
            continue
        fi

        local BOOKMARK_NAME="${OPTIONS[$CHOICE]}"
        local BOOKMARK_PATH="${BOOKMARKS[$BOOKMARK_NAME]}"

        if [[ -z "$BOOKMARK_PATH" ]]; then
            echo -e "${RED}Invalid choice.${RESET}"
            sleep 1
            continue
        fi

        local TAB_LABEL="[$BOOKMARK_NAME]"
        set_tab_title "$TAB_LABEL"
        project_actions_menu "$BOOKMARK_NAME" "$BOOKMARK_PATH" "$TAB_LABEL" "bookmark"
    done
}

show_recents_menu() {
    set_tab_title "[Recent]"

    while true; do
        load_recents

        clear
        echo -e "${BOLD}${CYAN}Recent folders (last 20)${RESET}"
        echo

        if ((${#RECENT_ORDER[@]} == 0)); then
            echo "No recent projects yet."
            echo
            echo -e "${GREEN}T)${RESET} Tools"
            echo -e "${GREEN}B)${RESET} Back to Project List"
            echo -e "${RED}0) Exit${RESET}"
            echo
            read -p "Enter choice: " CHOICE

            if [[ "$CHOICE" == "0" ]]; then
                set_tab_title ""
                launch_interactive_shell
            fi

            if [[ "$CHOICE" =~ ^[Tt]$ ]]; then
                tools_menu
                continue
            fi

            if [[ "$CHOICE" =~ ^[Bb]$ ]]; then
                set_tab_title "[Projects]"
                return
            fi

            echo -e "${RED}Invalid choice.${RESET}"
            sleep 1
            continue
        fi

        local i=1
        local -a OPTIONS=()
        local max_label=12
        for name in "${RECENT_ORDER[@]}"; do
            (( ${#name} > max_label )) && max_label=${#name}
        done

        local header_label="Project"
        local header_path="Path"

        printf "%b%-4s%b | %b%-*s%b | %b%s%b\n" \
            "$BOLD" "#" "$RESET" \
            "$BOLD" "$max_label" "$header_label" "$RESET" \
            "$BOLD" "$header_path" "$RESET"
        printf "%s\n" "$(printf '%*s' $((max_label + ${#header_path} + 9)) '' | tr ' ' '-')"

        for name in "${RECENT_ORDER[@]}"; do
            local path="${RECENT_PATHS[$name]}"
            printf "%b%2d)%b | %b%-*s%b | %b%s%b\n" \
                "$GREEN" "$i" "$RESET" \
                "$YELLOW" "$max_label" "$name" "$RESET" \
                "$DIM" "$path" "$RESET"
            OPTIONS[$i]="$name"
            ((i++))
        done

        echo -e "${GREEN}B)${RESET} Back to Project List"
        echo -e "${GREEN}T)${RESET} Tools"
        echo -e "${RED}0) Exit${RESET}"
        echo
        read -p "Enter choice: " CHOICE

        if [[ "$CHOICE" == "0" ]]; then
            set_tab_title ""
            launch_interactive_shell
        fi

        if [[ "$CHOICE" =~ ^[Bb]$ ]]; then
            set_tab_title "[Projects]"
            return
        fi

        if [[ "$CHOICE" =~ ^[Tt]$ ]]; then
            tools_menu
            continue
        fi

        if [[ ! "$CHOICE" =~ ^[0-9]+$ ]]; then
            echo -e "${RED}Invalid choice.${RESET}"
            sleep 1
            continue
        fi

        if (( CHOICE < 1 || CHOICE > ${#RECENT_ORDER[@]} )); then
            echo -e "${RED}Invalid choice.${RESET}"
            sleep 1
            continue
        fi

        local RECENT_NAME="${OPTIONS[$CHOICE]}"
        local RECENT_PATH="${RECENT_PATHS[$RECENT_NAME]}"

        if [[ -z "$RECENT_PATH" ]]; then
            echo -e "${RED}Invalid choice.${RESET}"
            sleep 1
            continue
        fi

        local TAB_LABEL="[$RECENT_NAME]"
        set_tab_title "$TAB_LABEL"
        project_actions_menu "$RECENT_NAME" "$RECENT_PATH" "$TAB_LABEL" "recent"
    done
}

show_projects_menu() {
    set_tab_title "[Projects]"
    local resume_checked=0

    while true; do
        load_projects

        if (( resume_checked == 0 )); then
            resume_checked=1
            if auto_resume_previous_tool_if_requested; then
                return
            fi
        fi
        clear
        echo -e "${BOLD}${CYAN}Which folder would you like to work in?${RESET}"
        echo

        local i=1
        local -a OPTIONS=()
        local max_label=12
        for name in "${PROJECT_ORDER[@]}"; do
            (( ${#name} > max_label )) && max_label=${#name}
        done

        local header_label="Project"
        local header_path="Path"

        printf "%b%-4s%b | %b%-*s%b | %b%s%b\n" \
            "$BOLD" "#" "$RESET" \
            "$BOLD" "$max_label" "$header_label" "$RESET" \
            "$BOLD" "$header_path" "$RESET"
        printf "%s\n" "$(printf '%*s' $((max_label + ${#header_path} + 9)) '' | tr ' ' '-')"

        for name in "${PROJECT_ORDER[@]}"; do
            local path="${PROJECTS[$name]}"
            printf "%b%2d)%b | %b%-*s%b | %b%s%b\n" \
                "$GREEN" "$i" "$RESET" \
                "$YELLOW" "$max_label" "$name" "$RESET" \
                "$DIM" "$path" "$RESET"
            OPTIONS[$i]="$name"
            ((i++))
        done

        echo -e "${GREEN}R)${RESET} Recent Folders"
        echo -e "${GREEN}S)${RESET} Saved / Bookmarked Folders"
        echo -e "${GREEN}T)${RESET} Tools"
        if [[ -n "$TMUX" ]]; then
            echo -e "${GREEN}X)${RESET} Exit tmux (plain shell)"
        fi
        echo -e "${RED}0) Exit${RESET}"
        echo
        read -p "Enter choice: " CHOICE

        if [[ "$CHOICE" == "0" ]]; then
            set_tab_title ""
            launch_interactive_shell
        fi

        if [[ "$CHOICE" =~ ^[Xx]$ ]]; then
            if command -v tmux >/dev/null 2>&1 && [[ -n "$TMUX" ]]; then
                tmux kill-session
                # When tmux exits, project-menu.sh's top-level tmux wrapper
                # will exec a plain shell, so just return here.
                return
            else
                set_tab_title ""
                launch_interactive_shell
            fi
        fi

        if [[ "$CHOICE" =~ ^[Rr]$ ]]; then
            show_recents_menu
            continue
        fi

        if [[ "$CHOICE" =~ ^[Ss]$ ]]; then
            show_bookmarks_menu
            continue
        fi

        if [[ "$CHOICE" =~ ^[Tt]$ ]]; then
            tools_menu
            continue
        fi

        if [[ ! "$CHOICE" =~ ^[0-9]+$ ]]; then
            echo -e "${RED}Invalid choice.${RESET}"
            sleep 1
            continue
        fi

        if (( CHOICE < 1 || CHOICE > ${#PROJECT_ORDER[@]} )); then
            echo -e "${RED}Invalid choice.${RESET}"
            sleep 1
            continue
        fi

        local PROJECT_NAME="${OPTIONS[$CHOICE]}"
        local PROJECT_PATH="${PROJECTS[$PROJECT_NAME]}"

        if [[ -z "$PROJECT_PATH" ]]; then
            echo -e "${RED}Invalid choice.${RESET}"
            sleep 1
        else
            local TAB_LABEL="[$PROJECT_NAME]"
            set_tab_title "$TAB_LABEL"
            local SOURCE="${PROJECT_SOURCE[$PROJECT_NAME]:-config}"
            project_actions_menu "$PROJECT_NAME" "$PROJECT_PATH" "$TAB_LABEL" "$SOURCE"
        fi
    done
}

project_actions_menu() {
    local NAME="$1"
    local PATH_SPEC="$2"
    local TAB_LABEL="$3"
    local SOURCE="${4:-config}"

    local PATH_WSL=""
    local IS_WSL_PATH=0
    if [[ "$PATH_SPEC" == /* ]]; then
        PATH_WSL="$PATH_SPEC"
        IS_WSL_PATH=1
    else
        if ! PATH_WSL="$(windows_to_wsl_path "$PATH_SPEC")"; then
            echo -e "${RED}Cannot convert Windows path to WSL path:${RESET} $PATH_SPEC"
            sleep 2
            return
        fi
    fi
    local ALLOW_REMOVE=0
    if [[ "$SOURCE" == "config" || "$SOURCE" == "bookmark" ]]; then
        ALLOW_REMOVE=1
    fi

    while true; do
        clear
        echo -e "${BOLD}${CYAN}Selected:${RESET} ${YELLOW}$NAME${RESET}"
        if (( IS_WSL_PATH )); then
            echo -e "${DIM}WSL path:${RESET} $PATH_WSL"
        else
            echo -e "${DIM}Windows path:${RESET} $PATH_SPEC"
            echo -e "${DIM}WSL path:${RESET} $PATH_WSL"
        fi
        echo
        echo "What do you want to do?"
        echo
        echo -e "${GREEN}1)${RESET} Start ${BOLD}Codex${RESET} (${DIM}--yolo${RESET})"
        echo -e "${GREEN}2)${RESET} Start ${BOLD}Claude${RESET} (${DIM}--dangerously-skip-permissions${RESET})"
        echo -e "${GREEN}3)${RESET} Enter Shell Here"
        if (( ALLOW_REMOVE )); then
            echo -e "${GREEN}4)${RESET} Remove This Project"
        fi
        echo -e "${GREEN}B)${RESET} Back to Project List"
        echo -e "${RED}0) Exit menu (stay in this folder)${RESET}"
        echo
        read -p "Enter choice: " ACTION

        case "$ACTION" in
            0)
                export PROJECT_SESSION_TOOL="Other"
                if command -v tmux >/dev/null 2>&1 && [[ -n "$TMUX" ]]; then
                    tmux set-option -gq @session_tool "Other"
                fi
                set_tab_title "$TAB_LABEL"
                launch_interactive_shell
                ;;
            [Bb])
                set_tab_title "[Projects]"
                return
                ;;
            4)
                if (( ALLOW_REMOVE )); then
                    echo
                    echo -e "${RED}This will remove:${RESET} ${BOLD}$NAME${RESET}"
                    echo "Windows path: $PATH_SPEC"
                    read -rp "Are you sure? [y/N]: " REMOVE_CONFIRM
                    if [[ "$REMOVE_CONFIRM" =~ ^[Yy]$ ]]; then
                        if [[ "$SOURCE" == "bookmark" ]]; then
                            if remove_bookmark_from_file "$NAME" "$PATH_SPEC"; then
                                echo -e "${GREEN}Removed bookmark. Returning to list...${RESET}"
                                sleep 1.5
                                set_tab_title "[Projects]"
                                return
                            else
                                echo -e "${RED}Failed to update $BOOKMARKS_FILE.${RESET}"
                                sleep 2
                            fi
                        else
                            if remove_project_from_config "$NAME" "$PATH_SPEC"; then
                                echo -e "${GREEN}Removed. Returning to list...${RESET}"
                                sleep 1.5
                                set_tab_title "[Projects]"
                                return
                            else
                                echo -e "${RED}Failed to update $CONFIG_FILE.${RESET}"
                                sleep 2
                            fi
                        fi
                    else
                        echo -e "${YELLOW}Aborted removal.${RESET}"
                        sleep 1
                    fi
                else
                    echo -e "${YELLOW}Removal not available for this entry.${RESET}"
                    sleep 1
                fi
                continue
                ;;
        esac

        case "$ACTION" in
            1)
                launch_tool_for_project "codex" "$NAME" "$PATH_SPEC" "$TAB_LABEL" "$SOURCE"
                ;;
            2)
                launch_tool_for_project "claude" "$NAME" "$PATH_SPEC" "$TAB_LABEL" "$SOURCE"
                ;;
            3)
                cd "$PATH_WSL" || {
                    echo -e "${RED}Cannot cd into:${RESET} $PATH_SPEC"
                    echo "Resolved WSL path: $PATH_WSL"
                    sleep 2
                    return
                }
                prompt_for_session_label "$NAME"
                export PROJECT_SESSION_TOOL="Other"
                if command -v tmux >/dev/null 2>&1 && [[ -n "$TMUX" ]]; then
                    tmux set-option -pt "${TMUX_PANE:-.}" @pane_tool "Other"
                fi
                set_tab_title "$TAB_LABEL"
                launch_interactive_shell
                ;;
            *)
                echo -e "${RED}Invalid choice.${RESET}"
                sleep 1
                ;;
        esac
    done
}

show_projects_menu
