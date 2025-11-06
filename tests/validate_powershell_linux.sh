#!/bin/bash

# Validation script for PowerShell jcd module on Linux
# This script runs PowerShell tests and validates output

echo "=== PowerShell jcd Validation (Linux) ==="

# Check if we're on Windows (Git Bash/MSYS)
if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "win32" || "$OSTYPE" == "cygwin" ]]; then
    echo "✗ This script is for Linux/WSL only. Use validate_powershell_windows.sh instead."
    exit 1
fi

# Check if PowerShell is available
if ! command -v pwsh &> /dev/null; then
    echo "✗ PowerShell (pwsh) not found. Please install PowerShell."
    exit 1
fi

# Determine script location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
JCD_BINARY="$REPO_ROOT/target/release/jcd"
PS_MODULE="$REPO_ROOT/target/release/jcd_function.ps1"

# Check if binary exists
if [[ ! -x "$JCD_BINARY" ]]; then
    echo "✗ Binary not found or not executable at $JCD_BINARY"
    echo "  Please run: cargo build --release"
    exit 1
fi

# Check if PowerShell module exists
if [[ ! -f "$PS_MODULE" ]]; then
    echo "✗ PowerShell module not found at $PS_MODULE"
    echo "  Please run: cargo build --release"
    exit 1
fi

echo "✓ Binary exists: $JCD_BINARY"
echo "✓ PowerShell module exists: $PS_MODULE"
echo ""

# Create test directory structure
TEST_DIR="/tmp/jcd_ps_test_$$"
mkdir -p "$TEST_DIR"/{src,tests,docs,build/{debug,release}}
echo "Created test directory: $TEST_DIR"
echo ""

# Test counter
PASSED=0
FAILED=0

# Test 1: Help flag
echo -n "Test 1: jcd -h shows help ... "
result=$(pwsh -NoProfile -Command "
    \$env:JCD_BINARY = '$JCD_BINARY'
    . '$PS_MODULE'
    jcd -h 2>&1
")
if [[ "$result" == *"Usage: jcd"* ]]; then
    echo "✓ PASS"
    ((PASSED++))
else
    echo "✗ FAIL"
    echo "  Output: $result"
    ((FAILED++))
fi

# Test 2: Navigate to parent directory
echo -n "Test 2: jcd .. navigates to parent ... "
result=$(pwsh -NoProfile -Command "
    \$env:JCD_BINARY = '$JCD_BINARY'
    . '$PS_MODULE'
    Set-Location '$TEST_DIR/src'
    jcd .. 2>&1 | Out-Null
    Get-Location | Select-Object -ExpandProperty Path
")
if [[ "$result" == "$TEST_DIR" ]]; then
    echo "✓ PASS"
    ((PASSED++))
else
    echo "✗ FAIL"
    echo "  Expected: $TEST_DIR"
    echo "  Got: $result"
    ((FAILED++))
fi

# Test 3: Navigate up two levels
echo -n "Test 3: jcd ../.. navigates up two levels ... "
result=$(pwsh -NoProfile -Command "
    \$env:JCD_BINARY = '$JCD_BINARY'
    . '$PS_MODULE'
    Set-Location '$TEST_DIR/build/debug'
    jcd ../.. 2>&1 | Out-Null
    Get-Location | Select-Object -ExpandProperty Path
")
if [[ "$result" == "$TEST_DIR" ]]; then
    echo "✓ PASS"
    ((PASSED++))
else
    echo "✗ FAIL"
    echo "  Expected: $TEST_DIR"
    echo "  Got: $result"
    ((FAILED++))
fi

# Test 4: Navigate to current directory (no-op)
echo -n "Test 4: jcd . stays in current directory ... "
result=$(pwsh -NoProfile -Command "
    \$env:JCD_BINARY = '$JCD_BINARY'
    . '$PS_MODULE'
    Set-Location '$TEST_DIR'
    jcd . 2>&1 | Out-Null
    Get-Location | Select-Object -ExpandProperty Path
")
if [[ "$result" == "$TEST_DIR" ]]; then
    echo "✓ PASS"
    ((PASSED++))
else
    echo "✗ FAIL"
    echo "  Expected: $TEST_DIR"
    echo "  Got: $result"
    ((FAILED++))
fi

# Test 5: Navigate to subdirectory by pattern
echo -n "Test 5: jcd src navigates to src directory ... "
result=$(pwsh -NoProfile -Command "
    \$env:JCD_BINARY = '$JCD_BINARY'
    . '$PS_MODULE'
    Set-Location '$TEST_DIR'
    jcd src 2>&1 | Out-Null
    Get-Location | Select-Object -ExpandProperty Path
")
if [[ "$result" == "$TEST_DIR/src" ]]; then
    echo "✓ PASS"
    ((PASSED++))
else
    echo "✗ FAIL"
    echo "  Expected: $TEST_DIR/src"
    echo "  Got: $result"
    ((FAILED++))
fi

# Test 6: Case-insensitive search with -i flag
echo -n "Test 6: jcd -i SRC navigates to src (case-insensitive) ... "
result=$(pwsh -NoProfile -Command "
    \$env:JCD_BINARY = '$JCD_BINARY'
    . '$PS_MODULE'
    Set-Location '$TEST_DIR'
    jcd -i SRC 2>&1 | Out-Null
    Get-Location | Select-Object -ExpandProperty Path
")
if [[ "$result" == "$TEST_DIR/src" ]]; then
    echo "✓ PASS"
    ((PASSED++))
else
    echo "✗ FAIL"
    echo "  Expected: $TEST_DIR/src"
    echo "  Got: $result"
    ((FAILED++))
fi

# Test 7: Navigate with relative pattern (../tests from src)
echo -n "Test 7: jcd ../tests navigates to sibling directory ... "
result=$(pwsh -NoProfile -Command "
    \$env:JCD_BINARY = '$JCD_BINARY'
    . '$PS_MODULE'
    Set-Location '$TEST_DIR/src'
    jcd ../tests 2>&1 | Out-Null
    Get-Location | Select-Object -ExpandProperty Path
")
if [[ "$result" == "$TEST_DIR/tests" ]]; then
    echo "✓ PASS"
    ((PASSED++))
else
    echo "✗ FAIL"
    echo "  Expected: $TEST_DIR/tests"
    echo "  Got: $result"
    ((FAILED++))
fi

# Test 8: Error handling - non-existent pattern stays in current directory
echo -n "Test 8: jcd <invalid> stays in current directory ... "
result=$(pwsh -NoProfile -Command "
    \$env:JCD_BINARY = '$JCD_BINARY'
    . '$PS_MODULE'
    Set-Location '$TEST_DIR'
    jcd 'xyzzy_nonexistent_12345' 2>&1 | Out-Null
    Get-Location | Select-Object -ExpandProperty Path
")
if [[ "$result" == "$TEST_DIR" ]]; then
    echo "✓ PASS"
    ((PASSED++))
else
    echo "✗ FAIL"
    echo "  Expected: $TEST_DIR (unchanged)"
    echo "  Got: $result"
    ((FAILED++))
fi

# Test 9: -x flag bypasses ignore patterns (verify flag is passed to binary)
echo -n "Test 9: jcd -x passes bypass flag to binary ... "
result=$(pwsh -NoProfile -Command "
    \$env:JCD_BINARY = '$JCD_BINARY'
    . '$PS_MODULE'
    Set-Location '$TEST_DIR'
    jcd -x build 2>&1 | Out-Null
    Get-Location | Select-Object -ExpandProperty Path
")
if [[ "$result" == "$TEST_DIR/build" ]]; then
    echo "✓ PASS"
    ((PASSED++))
else
    echo "✗ FAIL"
    echo "  Expected: $TEST_DIR/build"
    echo "  Got: $result"
    ((FAILED++))
fi

# Test 10: Binary location detection
echo -n "Test 10: Module finds binary via \$env:JCD_BINARY ... "
result=$(pwsh -NoProfile -Command "
    \$env:JCD_BINARY = '$JCD_BINARY'
    . '$PS_MODULE'
    # Module should load without errors
    if (Get-Command jcd -ErrorAction SilentlyContinue) {
        Write-Output 'SUCCESS'
    } else {
        Write-Output 'FAIL'
    }
")
if [[ "$result" == "SUCCESS" ]]; then
    echo "✓ PASS"
    ((PASSED++))
else
    echo "✗ FAIL"
    echo "  Output: $result"
    ((FAILED++))
fi

# Cleanup
rm -rf "$TEST_DIR"
echo ""

# Summary
echo "=== Test Summary ==="
echo "Passed: $PASSED"
echo "Failed: $FAILED"
echo "Total:  $((PASSED + FAILED))"
echo ""

if [[ $FAILED -eq 0 ]]; then
    echo "All tests passed! ✓"
    exit 0
else
    echo "Some tests failed. ✗"
    exit 1
fi
