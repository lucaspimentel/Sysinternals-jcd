# JCD PowerShell Function - Enhanced Directory Navigation
# Usage: Add ". /path/to/jcd_function.ps1" to your PowerShell profile

function Show-JcdUsage {
    Write-Host "Usage:"
    Write-Host "  jcd [-i] [-x] <directory_pattern>   - Changes directory according to the pattern"
    Write-Host "  jcd -h | --help                     - Display this help message"
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  -i               Case-insensitive matching"
    Write-Host "  -x               Bypass ignore patterns (search all directories)"
    Write-Host ""
    Write-Host "directory_pattern:"
    Write-Host "  jcd <substring>        # Navigate to directory matching substring"
    Write-Host "  jcd <absolute_path>    # Navigate to absolute path"
    Write-Host "  jcd <path/pattern>     # Navigate using path-like patterns"
    Write-Host ""
    Write-Host "Examples:"
    Write-Host "  jcd src              # Navigate to directory matching 'src'"
    Write-Host "  jcd -i DOC           # Case-insensitive search for 'doc'"
    Write-Host "  jcd ../foo           # Navigate relative to parent directory"
    Write-Host "  jcd ..               # Navigate to parent directory"
}

function jcd {
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [string]$SearchTerm,

        [switch]$i,  # Case-insensitive
        [switch]$x,  # Bypass ignore patterns
        [switch]$h,  # Help
        [switch]$help
    )

    # Show help if requested
    if ($h -or $help) {
        Show-JcdUsage
        return
    }

    # Validate search term
    if ([string]::IsNullOrEmpty($SearchTerm)) {
        Show-JcdUsage
        return
    }

    # Locate the JCD binary
    $jcdBinary = $null
    if ($env:JCD_BINARY -and (Test-Path $env:JCD_BINARY)) {
        $jcdBinary = $env:JCD_BINARY
    }
    else {
        # Try default locations
        $defaultLocations = @(
            "/usr/bin/jcd",                           # Linux standard location
            "/usr/local/bin/jcd",                     # Linux local installation
            "/opt/homebrew/bin/jcd",                  # macOS Homebrew (Apple Silicon)
            "/usr/local/opt/jcd/bin/jcd"              # macOS Homebrew (Intel)
        )

        foreach ($location in $defaultLocations) {
            if (Test-Path $location) {
                $jcdBinary = $location
                break
            }
        }
    }

    if (-not $jcdBinary -or -not (Test-Path $jcdBinary)) {
        Write-Error "Error: JCD binary not found. Set `$env:JCD_BINARY or install jcd to a standard location."
        return
    }

    # Handle simple directory navigation cases directly in PowerShell for better performance
    switch ($SearchTerm) {
        ".." {
            try {
                Set-Location ".."
                return
            }
            catch {
                Write-Error "Cannot navigate to parent directory: $_"
                return
            }
        }
        "../.." {
            try {
                Set-Location "../.."
                return
            }
            catch {
                Write-Error "Cannot navigate to ../../: $_"
                return
            }
        }
        "../../.." {
            try {
                Set-Location "../../.."
                return
            }
            catch {
                Write-Error "Cannot navigate to ../../../: $_"
                return
            }
        }
        "../../../.." {
            try {
                Set-Location "../../../.."
                return
            }
            catch {
                Write-Error "Cannot navigate to ../../../../: $_"
                return
            }
        }
        "." {
            # Stay in current directory
            return
        }
    }

    # Handle trailing slash - navigate to directory directly
    if ($SearchTerm.EndsWith("/") -or $SearchTerm.EndsWith("\")) {
        $dirWithoutSlash = $SearchTerm.TrimEnd("/", "\")
        if (Test-Path -Path $dirWithoutSlash -PathType Container) {
            try {
                Set-Location $dirWithoutSlash
                return
            }
            catch {
                Write-Error "Cannot navigate to '$dirWithoutSlash': $_"
                return
            }
        }
        # If directory doesn't exist, fall through to search logic
    }

    # Build arguments for the JCD binary
    $jcdArgs = @()

    # Always use --quiet in PowerShell to suppress the progress indicator
    # (PowerShell doesn't handle stderr output well for inline animations)
    $jcdArgs += "--quiet"

    if ($i) {
        $jcdArgs += "-i"
    }

    if ($x) {
        $jcdArgs += "-x"
    }

    # Add search term and index 0 (first match)
    $jcdArgs += $SearchTerm
    $jcdArgs += "0"

    # Call the JCD binary to get the best match
    try {
        # Call binary with --quiet flag to suppress progress indicator
        # Use Out-String to capture output reliably, then trim whitespace
        $dest = (& $jcdBinary @jcdArgs | Out-String).Trim()

        # Check exit code
        if ($LASTEXITCODE -ne 0) {
            Write-Host "No directories found matching '$SearchTerm'"
            return
        }

        # Check if we got a valid result
        if ([string]::IsNullOrWhiteSpace($dest)) {
            Write-Host "No directories found matching '$SearchTerm'"
            return
        }

        # Navigate to the destination
        Set-Location $dest
    }
    catch {
        Write-Error "Error calling JCD binary: $_"
        return
    }
}

# ============================================================================
# Tab Completion Support
# ============================================================================

# Helper function to get all matches for a pattern
function Get-JcdAllMatches {
    param(
        [string]$Pattern,
        [bool]$CaseInsensitive,
        [string]$BinaryPath
    )

    $matches = @()
    $idx = 0

    # Call binary with increasing index until we get no results
    while ($idx -lt 100) {  # Safety limit
        $args = @("--quiet")

        if ($CaseInsensitive) {
            $args += "-i"
        }

        $args += $Pattern
        $args += $idx.ToString()

        $match = (& $BinaryPath @args | Out-String).Trim()

        if ([string]::IsNullOrWhiteSpace($match) -or $LASTEXITCODE -ne 0) {
            break
        }

        $matches += $match
        $idx++
    }

    return $matches
}

# Register native argument completer for jcd
Register-ArgumentCompleter -Native -CommandName jcd -ScriptBlock {
    param($wordToComplete, $commandAst, $cursorPosition)

    # Parse the command line to extract flags and pattern
    $tokens = $commandAst.ToString() -split '\s+'
    $hasIFlag = $tokens -contains '-i'
    $pattern = $wordToComplete

    # Locate the JCD binary
    $jcdBinary = $null
    if ($env:JCD_BINARY -and (Test-Path $env:JCD_BINARY)) {
        $jcdBinary = $env:JCD_BINARY
    }
    else {
        # Try default locations
        $defaultLocations = @(
            "/usr/bin/jcd",
            "/usr/local/bin/jcd",
            "/opt/homebrew/bin/jcd",
            "/usr/local/opt/jcd/bin/jcd"
        )

        foreach ($location in $defaultLocations) {
            if (Test-Path $location) {
                $jcdBinary = $location
                break
            }
        }
    }

    if (-not $jcdBinary) {
        return @()
    }

    # Get all matches for the pattern
    $matches = Get-JcdAllMatches -Pattern $pattern -CaseInsensitive $hasIFlag -BinaryPath $jcdBinary

    # If no matches, return empty
    if ($matches.Count -eq 0) {
        return @()
    }

    # Return all matches as completion results
    # For MenuComplete, all results are displayed at once
    $results = @()
    foreach ($match in $matches) {
        # CompletionText is what gets inserted when selected
        # ListItemText is what's shown in the menu
        # ToolTip is shown in detailed view
        $results += [System.Management.Automation.CompletionResult]::new(
            $match,                                                    # CompletionText
            (Split-Path -Leaf $match),                                # ListItemText (just directory name)
            [System.Management.Automation.CompletionResultType]::ParameterValue,
            $match                                                     # ToolTip (full path)
        )
    }

    return $results
}

# Note: When dot-sourced, the function is automatically available.
# Export-ModuleMember is only needed for .psm1 module files.
