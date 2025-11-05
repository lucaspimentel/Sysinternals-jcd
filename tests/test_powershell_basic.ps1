#!/usr/bin/env pwsh

# Basic test script for PowerShell jcd module
# This tests the core functionality without tab completion

$ErrorActionPreference = "Stop"

# Determine script location
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent $scriptDir

# Set up environment
$env:JCD_BINARY = Join-Path $repoRoot "target/release/jcd"
$modulePath = Join-Path $repoRoot "target/release/jcd_function.ps1"

# Verify binary exists
if (-not (Test-Path $env:JCD_BINARY)) {
    Write-Error "JCD binary not found at: $env:JCD_BINARY"
    Write-Error "Please run: cargo build --release"
    exit 1
}

# Verify module exists
if (-not (Test-Path $modulePath)) {
    Write-Error "PowerShell module not found at: $modulePath"
    Write-Error "Please run: cargo build --release"
    exit 1
}

# Import the module
Write-Host "Importing jcd PowerShell module from: $modulePath"
. $modulePath

# Test variables
$testsPassed = 0
$testsFailed = 0

function Test-JcdFunction {
    param(
        [string]$TestName,
        [scriptblock]$TestCode,
        [scriptblock]$Validation
    )

    Write-Host -NoNewline "Testing: $TestName ... "
    try {
        $originalLocation = Get-Location

        # Run the test
        & $TestCode

        # Validate
        $result = & $Validation

        if ($result) {
            Write-Host "PASS" -ForegroundColor Green
            $script:testsPassed++
        } else {
            Write-Host "FAIL" -ForegroundColor Red
            $script:testsFailed++
        }

        # Restore location
        Set-Location $originalLocation
    }
    catch {
        Write-Host "ERROR: $_" -ForegroundColor Red
        $script:testsFailed++
        Set-Location $originalLocation
    }
}

Write-Host "`n=== Basic PowerShell jcd Tests ===`n"

# Test 1: Help flag - verify it doesn't throw an error
Test-JcdFunction -TestName "jcd -h shows help" -TestCode {
    jcd -h
    $script:helpWorked = $true
} -Validation {
    $script:helpWorked -eq $true
}

# Test 2: Navigate to parent directory
Test-JcdFunction -TestName "jcd .. navigates to parent" -TestCode {
    Set-Location $repoRoot
    jcd ..
} -Validation {
    (Get-Location).Path -eq (Split-Path -Parent $repoRoot)
}

# Test 3: Navigate to current directory (no-op)
Test-JcdFunction -TestName "jcd . stays in current directory" -TestCode {
    Set-Location $repoRoot
    $before = Get-Location
    jcd .
    $script:after = Get-Location
    $script:before = $before
} -Validation {
    $script:before.Path -eq $script:after.Path
}

# Test 4: Navigate to src directory (if it exists)
if (Test-Path (Join-Path $repoRoot "src")) {
    Test-JcdFunction -TestName "jcd src navigates to src directory" -TestCode {
        Set-Location $repoRoot
        jcd src
    } -Validation {
        (Get-Location).Path -like "*src"
    }
}

# Test 5: Case-insensitive search with -i flag
if (Test-Path (Join-Path $repoRoot "src")) {
    Test-JcdFunction -TestName "jcd -i SRC navigates to src (case-insensitive)" -TestCode {
        Set-Location $repoRoot
        jcd -i SRC
    } -Validation {
        (Get-Location).Path -like "*src"
    }
}

# Test 6: Navigate with ../.. pattern
Test-JcdFunction -TestName "jcd ../.. navigates up two levels" -TestCode {
    Set-Location $repoRoot
    jcd ../..
} -Validation {
    (Get-Location).Path -eq (Split-Path -Parent (Split-Path -Parent $repoRoot))
}

# Test 7: Error handling - non-existent pattern (verify directory doesn't change)
Test-JcdFunction -TestName "jcd <invalid> stays in current directory" -TestCode {
    Set-Location $repoRoot
    $script:beforeErrorLocation = Get-Location
    jcd "xyzzy_nonexistent_pattern_12345"
    $script:afterErrorLocation = Get-Location
} -Validation {
    $script:beforeErrorLocation.Path -eq $script:afterErrorLocation.Path
}

# Summary
Write-Host "`n=== Test Summary ==="
Write-Host "Passed: $testsPassed" -ForegroundColor Green
Write-Host "Failed: $testsFailed" -ForegroundColor Red
Write-Host "Total:  $($testsPassed + $testsFailed)"

if ($testsFailed -eq 0) {
    Write-Host "`nAll tests passed!" -ForegroundColor Green
    exit 0
} else {
    Write-Host "`nSome tests failed." -ForegroundColor Red
    exit 1
}
