#!/bin/bash
# =============================================================================
# Database Configuration for Claude
# =============================================================================
# This file is sourced by dbquery.sh
# Edit credentials and aliases here
#
# You can also set environment variables to override:
#   DB_HOST, DB_PORT, DB_USER, DB_PASS
# =============================================================================

# Default connection settings (can be overridden by environment)
DB_HOST="${DB_HOST:-127.0.0.1}"
DB_PORT="${DB_PORT:-3306}"
DB_USER="${DB_USER:-root}"
DB_PASS="${DB_PASS:-mike}"

# =============================================================================
# Database Aliases
# =============================================================================
# Format: DB_ALIASES[alias]="database_name"
#
# These are shortcuts so you can type:
#   dbquery lyk "SELECT * FROM users"
# Instead of:
#   dbquery behrens_lyklive "SELECT * FROM users"

# Note: Use individual assignments, not declare -A DB_ALIASES=(...)
# so we don't overwrite auto-detected databases

# LaunchYourKid
DB_ALIASES[lyk]="behrens_lyklive"
DB_ALIASES[lykdb]="behrens_lyklive"
DB_ALIASES[lyktest]="behrens_lyktest"

# VerityCom
DB_ALIASES[verity]="verity_veritycom"
DB_ALIASES[veritydb]="verity_veritycom"

# Add more as needed:
# DB_ALIASES[myalias]="database_name"

# =============================================================================
# Per-Database Credential Overrides (Optional)
# =============================================================================
# If a specific database needs different credentials, set them here.
# Format:
#   DB_HOSTS[alias]="hostname"
#   DB_PORTS[alias]="port"
#   DB_USERS[alias]="username"
#   DB_PASSES[alias]="password"
#
# Example for a remote database:
#   DB_HOSTS[remote]="db.example.com"
#   DB_USERS[remote]="appuser"
#   DB_PASSES[remote]="securepassword"
#   DB_ALIASES[remote]="production_db"

# =============================================================================
# CakePHP Auto-Detection Paths
# =============================================================================
# The script will scan these directories for CakePHP projects and
# automatically detect their database names from config files

CAKEPHP_PATHS=(
    "/mnt/d/MikesDev/www"
)

# =============================================================================
# Custom Configurations
# =============================================================================
# Add any additional database configurations below

# Example: Production server with different credentials
# DB_ALIASES[prod]="production_database"
# DB_HOSTS[prod]="prod-db.example.com"
# DB_USERS[prod]="readonly"
# DB_PASSES[prod]="readonly_password"
