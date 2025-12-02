#!/bin/bash
# =============================================================================
# dbquery - Unified Database Query Tool
# =============================================================================
# A reusable, robust database interface for Claude and shell usage
#
# Features:
#   - Named aliases with credential storage
#   - Auto-detection of CakePHP database configs
#   - Multiple output formats (table, csv, json, vertical)
#   - Connection testing
#   - Query from file or stdin
#
# Usage:
#   dbquery <alias|database> [options] [query]
#   dbquery verity "SELECT * FROM users LIMIT 5"
#   dbquery lyk -o csv "SHOW TABLES"
#   echo "SELECT 1" | dbquery verity
#
# =============================================================================

set -euo pipefail

# Configuration
CONFIG_FILE="${HOME}/.claude/db-config.sh"
CAKEPHP_PATHS=(
    "/mnt/d/MikesDev/www"
)

# Defaults
DEFAULT_HOST="127.0.0.1"
DEFAULT_PORT="3306"
DEFAULT_USER="root"
DEFAULT_PASS="mike"

# Runtime vars
HOST=""
PORT=""
USER=""
PASS=""
DATABASE=""
QUERY=""
SQL_FILE=""
OUTPUT_FORMAT=""  # table (default), csv, json, vertical
TEST_ONLY=false
VERBOSE=false
SHOW_ALIASES=false
EXTRA_ARGS=()

# Colors (disabled if not tty)
if [ -t 1 ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    NC='\033[0m'
else
    RED='' GREEN='' YELLOW='' NC=''
fi

log_error() { echo -e "${RED}Error:${NC} $*" >&2; }
log_success() { echo -e "${GREEN}✓${NC} $*" >&2; }
log_info() { $VERBOSE && echo -e "${YELLOW}→${NC} $*" >&2 || true; }

# =============================================================================
# Configuration Loading
# =============================================================================

load_config() {
    # Declare associative arrays if not already declared (allows config to pre-define)
    declare -gA DB_ALIASES 2>/dev/null || true
    declare -gA DB_HOSTS 2>/dev/null || true
    declare -gA DB_PORTS 2>/dev/null || true
    declare -gA DB_USERS 2>/dev/null || true
    declare -gA DB_PASSES 2>/dev/null || true

    # Load main config file FIRST (so config takes precedence)
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
        log_info "Loaded config from $CONFIG_FILE"
    fi

    # Apply defaults if not set in config
    HOST="${DB_HOST:-$DEFAULT_HOST}"
    PORT="${DB_PORT:-$DEFAULT_PORT}"
    USER="${DB_USER:-$DEFAULT_USER}"
    PASS="${DB_PASS:-$DEFAULT_PASS}"
}

# Auto-detect CakePHP/Laravel database configs
# Priority: config/app_local.php > config/app.php > .env (project root)
detect_cakephp_databases() {
    for base_path in "${CAKEPHP_PATHS[@]}"; do
        [ -d "$base_path" ] || continue

        # Find project directories (those with a config/ folder)
        while IFS= read -r -d '' config_dir; do
            local project_dir=$(dirname "$config_dir")
            local project_name=$(basename "$project_dir")

            # Skip if already defined in db-config.sh
            [ -n "${DB_ALIASES[$project_name]:-}" ] && continue

            local db_name=""

            # Priority 1: config/app_local.php (CakePHP local overrides)
            if [ -f "$config_dir/app_local.php" ]; then
                db_name=$(grep -oP "'database'\s*=>\s*'[^']+'" "$config_dir/app_local.php" 2>/dev/null | head -1 | grep -oP "'\K[^']+(?='$)" || true)
                [ -n "$db_name" ] && log_info "Auto-detected from config/app_local.php: $project_name -> $db_name"
            fi

            # Priority 2: config/app.php (CakePHP main config)
            if [ -z "$db_name" ] && [ -f "$config_dir/app.php" ]; then
                db_name=$(grep -oP "'database'\s*=>\s*'[^']+'" "$config_dir/app.php" 2>/dev/null | head -1 | grep -oP "'\K[^']+(?='$)" || true)
                [ -n "$db_name" ] && log_info "Auto-detected from config/app.php: $project_name -> $db_name"
            fi

            # Priority 3: .env in project root (Laravel, generic PHP)
            if [ -z "$db_name" ] && [ -f "$project_dir/.env" ]; then
                # Try common .env patterns: DATABASE_NAME, DB_DATABASE, DB_NAME, DATABASE
                db_name=$(grep -oP '^(DATABASE_NAME|DB_DATABASE|DB_NAME|DATABASE)\s*=\s*\K[^\s#"'\'']+' "$project_dir/.env" 2>/dev/null | head -1 || true)
                [ -n "$db_name" ] && log_info "Auto-detected from .env: $project_name -> $db_name"
            fi

            # Register if found
            [ -n "$db_name" ] && DB_ALIASES[$project_name]="$db_name"

        done < <(find "$base_path" -maxdepth 3 -type d -name "config" 2>/dev/null | tr '\n' '\0')
    done
}

# =============================================================================
# Alias Resolution
# =============================================================================

resolve_alias() {
    local alias="$1"

    # Check if it's a known alias
    if [ -n "${DB_ALIASES[$alias]:-}" ]; then
        DATABASE="${DB_ALIASES[$alias]}"

        # Check for per-alias credential overrides
        [ -n "${DB_HOSTS[$alias]:-}" ] && HOST="${DB_HOSTS[$alias]}"
        [ -n "${DB_PORTS[$alias]:-}" ] && PORT="${DB_PORTS[$alias]}"
        [ -n "${DB_USERS[$alias]:-}" ] && USER="${DB_USERS[$alias]}"
        [ -n "${DB_PASSES[$alias]:-}" ] && PASS="${DB_PASSES[$alias]}"

        log_info "Resolved alias '$alias' -> database '$DATABASE'"
        return 0
    fi

    # Not an alias, use as direct database name
    DATABASE="$alias"
    return 0
}

# =============================================================================
# MySQL Execution
# =============================================================================

build_mysql_cmd() {
    local cmd="mysql"
    cmd+=" -h '$HOST'"
    cmd+=" -P '$PORT'"
    cmd+=" -u '$USER'"
    cmd+=" '-p$PASS'"
    cmd+=" '$DATABASE'"

    # Output format
    case "$OUTPUT_FORMAT" in
        csv)     cmd+=" --batch --raw" ;;
        json)    cmd+=" --raw" ;;  # Will need post-processing
        vertical) cmd+=" -E" ;;
        *)       ;; # Default table format
    esac

    # Extra args
    for arg in "${EXTRA_ARGS[@]}"; do
        cmd+=" '$arg'"
    done

    echo "$cmd"
}

test_connection() {
    log_info "Testing connection to $HOST:$PORT as $USER..."

    local cmd="mysql -h '$HOST' -P '$PORT' -u '$USER' '-p$PASS' -e 'SELECT 1' 2>&1"
    local result
    result=$(eval "$cmd") && {
        log_success "Connected to $HOST:$PORT"

        # Test database access
        cmd="mysql -h '$HOST' -P '$PORT' -u '$USER' '-p$PASS' '$DATABASE' -e 'SELECT 1' 2>&1"
        result=$(eval "$cmd") && {
            log_success "Database '$DATABASE' accessible"
            return 0
        } || {
            log_error "Cannot access database '$DATABASE'"
            return 1
        }
    } || {
        log_error "Connection failed: $result"
        return 1
    }
}

execute_query() {
    local query="$1"
    local mysql_cmd=$(build_mysql_cmd)

    log_info "Executing query on $DATABASE"

    if [ "$OUTPUT_FORMAT" = "json" ]; then
        # Convert to JSON using mysql's native JSON output or jq
        eval "$mysql_cmd -e \"$query\"" | {
            if command -v jq &>/dev/null; then
                # Convert tab-separated to JSON array
                awk -F'\t' '
                    NR==1 { for(i=1;i<=NF;i++) h[i]=$i; next }
                    {
                        printf "{";
                        for(i=1;i<=NF;i++) {
                            gsub(/"/, "\\\"", $i);
                            printf "\"%s\":\"%s\"", h[i], $i;
                            if(i<NF) printf ",";
                        }
                        print "}"
                    }
                ' | jq -s '.'
            else
                cat
            fi
        }
    else
        eval "$mysql_cmd -e \"$query\""
    fi
}

execute_file() {
    local file="$1"
    local mysql_cmd=$(build_mysql_cmd)

    log_info "Executing SQL file: $file"
    eval "$mysql_cmd < '$file'"
}

# =============================================================================
# Usage & Help
# =============================================================================

show_aliases() {
    echo "Available database aliases:"
    echo ""
    for alias in "${!DB_ALIASES[@]}"; do
        local db="${DB_ALIASES[$alias]}"
        local host="${DB_HOSTS[$alias]:-$HOST}"
        printf "  %-15s -> %-20s (%s)\n" "$alias" "$db" "$host"
    done | sort
}

usage() {
    cat <<EOF
Usage: dbquery [options] <database|alias> [query]

Options:
  -h HOST       Database host (default: $DEFAULT_HOST)
  -P PORT       Database port (default: $DEFAULT_PORT)
  -u USER       Database user (default: $DEFAULT_USER)
  -p PASS       Database password
  -e QUERY      Execute query (alternative syntax)
  -f FILE       Execute SQL file
  -o FORMAT     Output format: table, csv, json, vertical
  -t, --test    Test connection only
  -l, --list    List available aliases
  -v, --verbose Verbose output
  --help        Show this help

Examples:
  dbquery verity "SELECT * FROM users LIMIT 5"
  dbquery lyk -o csv "SHOW TABLES"
  dbquery verity -t                    # Test connection
  dbquery -l                           # List aliases
  echo "SELECT 1" | dbquery verity     # Pipe query

EOF
    exit 0
}

# =============================================================================
# Main
# =============================================================================

main() {
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --help) usage ;;
            -h)     HOST="$2"; shift 2 ;;
            -P)     PORT="$2"; shift 2 ;;
            -u)     USER="$2"; shift 2 ;;
            -p)     PASS="$2"; shift 2 ;;
            -e)     QUERY="$2"; shift 2 ;;
            -f)     SQL_FILE="$2"; shift 2 ;;
            -o)     OUTPUT_FORMAT="$2"; shift 2 ;;
            -t|--test) TEST_ONLY=true; shift ;;
            -l|--list) SHOW_ALIASES=true; shift ;;
            -v|--verbose) VERBOSE=true; shift ;;
            -*)
                EXTRA_ARGS+=("$1")
                shift
                ;;
            *)
                if [ -z "$DATABASE" ]; then
                    DATABASE="$1"
                elif [ -z "$QUERY" ]; then
                    QUERY="$1"
                fi
                shift
                ;;
        esac
    done

    # Load configuration
    load_config
    detect_cakephp_databases

    # Handle --list
    if $SHOW_ALIASES; then
        show_aliases
        exit 0
    fi

    # Validate database
    if [ -z "$DATABASE" ]; then
        log_error "No database specified"
        echo "Use 'dbquery --list' to see available aliases"
        exit 1
    fi

    # Resolve alias
    resolve_alias "$DATABASE"

    # Handle --test
    if $TEST_ONLY; then
        test_connection
        exit $?
    fi

    # Execute query
    if [ -n "$SQL_FILE" ]; then
        if [ ! -f "$SQL_FILE" ]; then
            log_error "SQL file not found: $SQL_FILE"
            exit 1
        fi
        execute_file "$SQL_FILE"
    elif [ -n "$QUERY" ]; then
        execute_query "$QUERY"
    elif [ ! -t 0 ]; then
        # Read query from stdin
        local stdin_query=$(cat)
        execute_query "$stdin_query"
    else
        # Interactive mode
        local mysql_cmd=$(build_mysql_cmd)
        eval "$mysql_cmd"
    fi
}

main "$@"
