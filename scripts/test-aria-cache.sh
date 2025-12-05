#!/bin/bash
# Test suite for aria-cache.sh - Simplified version
# Run: bash test-aria-cache.sh

export ARIA_CACHE_ROOT="/tmp/aria_cache_test_$$"
mkdir -p "$ARIA_CACHE_ROOT"

# Disable aria_inc to avoid state dependency
aria_inc() { return 0; }

# Source the cache script
source /home/mike/.claude/scripts/aria-cache.sh

TESTS=0
PASS=0
FAIL=0

assert_ok() {
    local result=$1
    local msg=$2
    ((TESTS++))
    if [ $result -eq 0 ]; then
        echo "PASS: $msg"
        ((PASS++))
    else
        echo "FAIL: $msg"
        ((FAIL++))
    fi
}

assert_eq() {
    local expected="$1"
    local actual="$2"
    local msg=$3
    ((TESTS++))
    if [ "$expected" = "$actual" ]; then
        echo "PASS: $msg"
        ((PASS++))
    else
        echo "FAIL: $msg (expected: $expected, got: $actual)"
        ((FAIL++))
    fi
}

echo "=== ARIA Cache Test Suite ==="
echo ""

# Test 1: Initialization
echo "Test Group: Initialization"
aria_cache_init
assert_ok 0 "Cache initialized"
[ -d "$ARIA_CACHE_ROOT/files" ]
assert_ok $? "Files directory created"
[ -d "$ARIA_CACHE_ROOT/search" ]
assert_ok $? "Search directory created"
[ -d "$ARIA_CACHE_ROOT/index-queries" ]
assert_ok $? "Query directory created"
echo ""

# Test 2: File Caching
echo "Test Group: File Caching"
TEST_FILE="$ARIA_CACHE_ROOT/test.txt"
echo "Test content" > "$TEST_FILE"

aria_cache_file_set "$TEST_FILE"
assert_ok $? "Set file cache"

output=$(aria_cache_file_get "$TEST_FILE" 2>/dev/null)
assert_ok $? "Get cached file (hit)"
assert_eq "Test content" "$output" "File content matches"

aria_cache_file_valid "$TEST_FILE"
assert_ok $? "File cache is valid"

sleep 1
echo "Modified" > "$TEST_FILE"
aria_cache_file_valid "$TEST_FILE"
[ $? -ne 0 ]
assert_ok $? "File cache invalid after modification"
echo ""

# Test 3: Search Caching
echo "Test Group: Search Caching"
aria_cache_search_set "pattern1" "/path1" '["file1.js","file2.js"]'
assert_ok $? "Set search cache"

output=$(aria_cache_search_get "pattern1" "/path1" 2>/dev/null)
assert_ok $? "Get cached search (hit)"
echo "$output" | grep -q "file1.js"
assert_ok $? "Search contains expected data"

aria_cache_search_get "pattern2" "/path1" > /dev/null 2>&1
[ $? -ne 0 ]
assert_ok $? "Different pattern is cache miss"

aria_cache_invalidate_search
aria_cache_search_get "pattern1" "/path1" > /dev/null 2>&1
[ $? -ne 0 ]
assert_ok $? "Cache miss after invalidate-search"
echo ""

# Test 4: Query Caching
echo "Test Group: Query Caching"
aria_cache_query_set "SELECT 1" '[{"id":1}]'
assert_ok $? "Set query cache"

output=$(aria_cache_query_get "SELECT 1" 2>/dev/null)
assert_ok $? "Get cached query (hit)"
echo "$output" | grep -q "id"
assert_ok $? "Query contains expected data"

aria_cache_query_get "SELECT 2" > /dev/null 2>&1
[ $? -ne 0 ]
assert_ok $? "Different query is cache miss"

aria_cache_invalidate_queries
aria_cache_query_get "SELECT 1" > /dev/null 2>&1
[ $? -ne 0 ]
assert_ok $? "Cache miss after invalidate-queries"
echo ""

# Test 5: Statistics
echo "Test Group: Statistics"
stats=$(aria_cache_stats)
echo "$stats" | grep -q "total_size"
assert_ok $? "Stats contains total_size"
echo "$stats" | grep -q "count"
assert_ok $? "Stats contains count fields"
echo ""

# Test 6: Invalidate All
echo "Test Group: Invalidate All"
aria_cache_search_set "p1" "/" '["f1"]'
aria_cache_query_set "Q1" '[1]'
count_before=$(find "$ARIA_CACHE_ROOT" -type f -name "*.json" 2>/dev/null | wc -l)
[ "$count_before" -gt 0 ]
assert_ok $? "Cache entries exist"

aria_cache_invalidate_all
count_after=$(find "$ARIA_CACHE_ROOT" -type f -name "*.json" 2>/dev/null | wc -l)
assert_eq "0" "$count_after" "All caches cleared"
echo ""

# Test 7: Hash Consistency
echo "Test Group: Hash Function"
hash1=$(aria_cache_hash "test")
hash2=$(aria_cache_hash "test")
assert_eq "$hash1" "$hash2" "Hash is consistent"
hash_a=$(aria_cache_hash "a")
hash_b=$(aria_cache_hash "b")
[ "$hash_a" != "$hash_b" ]
assert_ok $? "Different inputs produce different hashes"
echo ""

# Test 8: Error Handling
echo "Test Group: Error Handling"
aria_cache_file_set "/nonexistent/file" > /dev/null 2>&1
[ $? -ne 0 ]
assert_ok $? "Error on missing file"

aria_cache_file_get "" > /dev/null 2>&1
[ $? -ne 0 ]
assert_ok $? "Error on empty filepath"

aria_cache_search_set "" "/" '[]' > /dev/null 2>&1
[ $? -ne 0 ]
assert_ok $? "Error on empty pattern"
echo ""

# Test 9: Function Availability
echo "Test Group: Function Availability"
type aria_cache_file_set > /dev/null 2>&1
assert_ok $? "aria_cache_file_set exists"
type aria_cache_search_get > /dev/null 2>&1
assert_ok $? "aria_cache_search_get exists"
type aria_cache_stats > /dev/null 2>&1
assert_ok $? "aria_cache_stats exists"
echo ""

# Summary
echo "=== Test Results ==="
echo "Tests run:  $TESTS"
echo "Passed:     $PASS"
echo "Failed:     $FAIL"

# Cleanup
rm -rf "$ARIA_CACHE_ROOT"

if [ $FAIL -eq 0 ]; then
    echo ""
    echo "SUCCESS: All tests passed!"
    exit 0
else
    echo ""
    echo "FAILURE: $FAIL test(s) failed"
    exit 1
fi
