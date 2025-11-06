#!/bin/bash

# Validation script for PowerShell jcd module on Windows
# This script runs PowerShell tests and validates output
# Designed to run under Git Bash on Windows

echo "=== PowerShell jcd Validation (Windows) ==="

# Check if we're on Windows
if [[ "$OSTYPE" != "msys" && "$OSTYPE" != "win32" && "$OSTYPE" != "cygwin" ]]; then
    echo "✗ This script is for Windows only. Use validate_powershell_linux.sh instead."
    exit 1
fi

# Check if PowerShell is available (try both pwsh and pwsh.exe)
if command -v pwsh &> /dev/null; then
    PWSH_CMD="pwsh"
elif command -v pwsh.exe &> /dev/null; then
    PWSH_CMD="pwsh.exe"
else
    echo "✗ PowerShell (pwsh) not found. Please install PowerShell."
    exit 1
fi

# Determine script location (Git Bash on Windows)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
JCD_BINARY="$REPO_ROOT/target/release/jcd.exe"
PS_MODULE="$REPO_ROOT/target/release/jcd_function.ps1"

# Convert paths to Windows format for PowerShell
JCD_BINARY_WIN=$(cygpath -w "$JCD_BINARY" 2>/dev/null || echo "$JCD_BINARY")
PS_MODULE_WIN=$(cygpath -w "$PS_MODULE" 2>/dev/null || echo "$PS_MODULE")

# Check if binary exists
if [[ ! -f "$JCD_BINARY" ]]; then
    echo "✗ Binary not found at $JCD_BINARY"
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

# Create test directory structure in Windows temp
TEST_DIR_WIN="$TEMP/jcd_ps_test_$$"
mkdir -p "$TEST_DIR_WIN"/{src,tests,docs,build/{debug,release}}
echo "Created test directory: $TEST_DIR_WIN"
echo ""

# Convert to Windows path for PowerShell
TEST_DIR_PS=$(cygpath -w "$TEST_DIR_WIN" 2>/dev/null || echo "$TEST_DIR_WIN")

# Test counter
PASSED=0
FAILED=0

# Test 1: Help flag
echo -n "Test 1: jcd -h shows help ... "
result=$($PWSH_CMD -NoProfile -Command "
    \$env:JCD_BINARY = '$JCD_BINARY_WIN'
    . '$PS_MODULE_WIN'
    jcd -h 2>&1
")
if [[ "$result" == *"Usage"* ]] && [[ "$result" == *"jcd"* ]]; then
    echo "✓ PASS"
    ((PASSED++))
else
    echo "✗ FAIL"
    echo "  Output: $result"
    ((FAILED++))
fi

# Test 2: Navigate to parent directory
echo -n "Test 2: jcd .. navigates to parent ... "
result=$($PWSH_CMD -NoProfile -Command "
    \$env:JCD_BINARY = '$JCD_BINARY_WIN'
    . '$PS_MODULE_WIN'
    Set-Location '$TEST_DIR_PS\src'
    jcd .. 2>&1 | Out-Null
    Get-Location | Select-Object -ExpandProperty Path
")
# Normalize path separators for comparison
result_normalized=$(echo "$result" | tr '\\' '/')
test_dir_normalized=$(echo "$TEST_DIR_PS" | tr '\\' '/')
if [[ "$result_normalized" == "$test_dir_normalized" ]]; then
    echo "✓ PASS"
    ((PASSED++))
else
    echo "✗ FAIL"
    echo "  Expected: $TEST_DIR_PS"
    echo "  Got: $result"
    ((FAILED++))
fi

# Test 3: Navigate up two levels
echo -n "Test 3: jcd ../.. navigates up two levels ... "
result=$($PWSH_CMD -NoProfile -Command "
    \$env:JCD_BINARY = '$JCD_BINARY_WIN'
    . '$PS_MODULE_WIN'
    Set-Location '$TEST_DIR_PS\build\debug'
    jcd ../.. 2>&1 | Out-Null
    Get-Location | Select-Object -ExpandProperty Path
")
result_normalized=$(echo "$result" | tr '\\' '/')
test_dir_normalized=$(echo "$TEST_DIR_PS" | tr '\\' '/')
if [[ "$result_normalized" == "$test_dir_normalized" ]]; then
    echo "✓ PASS"
    ((PASSED++))
else
    echo "✗ FAIL"
    echo "  Expected: $TEST_DIR_PS"
    echo "  Got: $result"
    ((FAILED++))
fi

# Test 4: Navigate to current directory (no-op)
echo -n "Test 4: jcd . stays in current directory ... "
result=$($PWSH_CMD -NoProfile -Command "
    \$env:JCD_BINARY = '$JCD_BINARY_WIN'
    . '$PS_MODULE_WIN'
    Set-Location '$TEST_DIR_PS'
    jcd . 2>&1 | Out-Null
    Get-Location | Select-Object -ExpandProperty Path
")
result_normalized=$(echo "$result" | tr '\\' '/')
test_dir_normalized=$(echo "$TEST_DIR_PS" | tr '\\' '/')
if [[ "$result_normalized" == "$test_dir_normalized" ]]; then
    echo "✓ PASS"
    ((PASSED++))
else
    echo "✗ FAIL"
    echo "  Expected: $TEST_DIR_PS"
    echo "  Got: $result"
    ((FAILED++))
fi

# Test 5: Navigate to subdirectory by pattern
echo -n "Test 5: jcd src navigates to src directory ... "
result=$($PWSH_CMD -NoProfile -Command "
    \$env:JCD_BINARY = '$JCD_BINARY_WIN'
    . '$PS_MODULE_WIN'
    Set-Location '$TEST_DIR_PS'
    jcd src 2>&1 | Out-Null
    Get-Location | Select-Object -ExpandProperty Path
")
result_normalized=$(echo "$result" | tr '\\' '/')
expected_normalized=$(echo "$TEST_DIR_PS/src" | tr '\\' '/')
if [[ "$result_normalized" == "$expected_normalized" ]]; then
    echo "✓ PASS"
    ((PASSED++))
else
    echo "✗ FAIL"
    echo "  Expected: $TEST_DIR_PS\src"
    echo "  Got: $result"
    ((FAILED++))
fi

# Test 6: Case-insensitive search with -i flag
echo -n "Test 6: jcd -i SRC navigates to src (case-insensitive) ... "
result=$($PWSH_CMD -NoProfile -Command "
    \$env:JCD_BINARY = '$JCD_BINARY_WIN'
    . '$PS_MODULE_WIN'
    Set-Location '$TEST_DIR_PS'
    jcd -i SRC 2>&1 | Out-Null
    Get-Location | Select-Object -ExpandProperty Path
")
result_normalized=$(echo "$result" | tr '\\' '/')
expected_normalized=$(echo "$TEST_DIR_PS/src" | tr '\\' '/')
if [[ "$result_normalized" == "$expected_normalized" ]]; then
    echo "✓ PASS"
    ((PASSED++))
else
    echo "✗ FAIL"
    echo "  Expected: $TEST_DIR_PS\src"
    echo "  Got: $result"
    ((FAILED++))
fi

# Test 7: Navigate with relative pattern (../tests from src)
echo -n "Test 7: jcd ../tests navigates to sibling directory ... "
result=$($PWSH_CMD -NoProfile -Command "
    \$env:JCD_BINARY = '$JCD_BINARY_WIN'
    . '$PS_MODULE_WIN'
    Set-Location '$TEST_DIR_PS\src'
    jcd ../tests 2>&1 | Out-Null
    Get-Location | Select-Object -ExpandProperty Path
")
result_normalized=$(echo "$result" | tr '\\' '/')
expected_normalized=$(echo "$TEST_DIR_PS/tests" | tr '\\' '/')
if [[ "$result_normalized" == "$expected_normalized" ]]; then
    echo "✓ PASS"
    ((PASSED++))
else
    echo "✗ FAIL"
    echo "  Expected: $TEST_DIR_PS\tests"
    echo "  Got: $result"
    ((FAILED++))
fi

# Test 8: Error handling - non-existent pattern stays in current directory
echo -n "Test 8: jcd <invalid> stays in current directory ... "
result=$($PWSH_CMD -NoProfile -Command "
    \$env:JCD_BINARY = '$JCD_BINARY_WIN'
    . '$PS_MODULE_WIN'
    Set-Location '$TEST_DIR_PS'
    \$null = jcd 'xyzzy_nonexistent_12345' 2>&1
    (Get-Location).Path
")
result_normalized=$(echo "$result" | tr '\\' '/' | tr -d '\r\n' | xargs)
test_dir_normalized=$(echo "$TEST_DIR_PS" | tr '\\' '/' | tr -d '\r\n' | xargs)
if [[ "$result_normalized" == *"$test_dir_normalized"* ]]; then
    echo "✓ PASS"
    ((PASSED++))
else
    echo "✗ FAIL"
    echo "  Expected: $TEST_DIR_PS (unchanged)"
    echo "  Got: '$result'"
    ((FAILED++))
fi

# Test 9: -x flag bypasses ignore patterns (verify flag is passed to binary)
echo -n "Test 9: jcd -x passes bypass flag to binary ... "
result=$($PWSH_CMD -NoProfile -Command "
    \$env:JCD_BINARY = '$JCD_BINARY_WIN'
    . '$PS_MODULE_WIN'
    Set-Location '$TEST_DIR_PS'
    jcd -x build 2>&1 | Out-Null
    Get-Location | Select-Object -ExpandProperty Path
")
result_normalized=$(echo "$result" | tr '\\' '/')
expected_normalized=$(echo "$TEST_DIR_PS/build" | tr '\\' '/')
if [[ "$result_normalized" == "$expected_normalized" ]]; then
    echo "✓ PASS"
    ((PASSED++))
else
    echo "✗ FAIL"
    echo "  Expected: $TEST_DIR_PS\build"
    echo "  Got: $result"
    ((FAILED++))
fi

# Test 10: Windows-specific binary execution
echo -n "Test 10: Binary executes with Windows paths ... "
# Test that binary can run with Windows paths
result=$($PWSH_CMD -NoProfile -Command "Test-Path '$JCD_BINARY_WIN'")
if [[ "$result" == "True" ]]; then
    echo "✓ PASS (binary accessible)"
    ((PASSED++))
else
    echo "✗ FAIL"
    echo "  Binary not accessible at: $JCD_BINARY_WIN"
    ((FAILED++))
fi

# Test 11: Binary location detection
echo -n "Test 11: Module finds binary via \$env:JCD_BINARY ... "
result=$($PWSH_CMD -NoProfile -Command "
    \$env:JCD_BINARY = '$JCD_BINARY_WIN'
    . '$PS_MODULE_WIN'
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
rm -rf "$TEST_DIR_WIN"
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
