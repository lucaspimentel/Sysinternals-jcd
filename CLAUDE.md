# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

`jcd` (jump change directory) is a Rust-based Sysinternals command-line tool that provides enhanced directory navigation with substring matching, tab completion, and intelligent search. It consists of:
- A Rust binary (`src/main.rs`) that performs directory search and matching
- A bash shell wrapper (`src/jcd_function.sh`) that provides tab completion and actually changes directories
- **PowerShell support in progress** - see `TODO.md` for implementation plan

The tool works in two parts because a compiled binary cannot change its parent shell's directory - this is a fundamental limitation that requires the shell wrapper.

## Common Development Commands

### Building
```bash
# Standard debug build
cargo build

# Release build (recommended for testing performance)
cargo build --release

# Quick build test for a single target
cargo build --release

# The build.rs script automatically copies jcd_function.sh to target/release/ or target/debug/
```

### Testing
```bash
# Run all tests (recommended)
./tests/run_all_tests.sh

# Individual test suites (Bash)
./tests/validate_jcd.sh              # Basic validation
./tests/validate_shift_tab.sh        # Shift+Tab cycling validation
./tests/test_relative_comprehensive.sh   # Comprehensive relative path tests
./tests/test_ignore_functionality.sh # Ignore pattern tests
./tests/simple_test.sh               # Simple functionality test
./tests/quick_regression_test.sh     # Quick regression check

# PowerShell test suite
pwsh -NoProfile tests/test_powershell_basic.ps1  # Basic PowerShell functionality

# Manual testing after build (Bash)
export JCD_BINARY="$(pwd)/target/release/jcd"
source src/jcd_function.sh
jcd <pattern>  # Test navigation

# Manual testing after build (PowerShell)
$env:JCD_BINARY = "$(pwd)/target/release/jcd"
. ./target/release/jcd_function.ps1
jcd <pattern>  # Test navigation
```

### Package Building
```bash
# Debian package
./makePackages.sh . target/release jcd <VERSION> 0 deb "$(dpkg --print-architecture)"

# RPM package
./makePackages.sh "$(pwd)" target/release jcd <VERSION> 0 rpm "$(rpm --eval '%_arch')"
```

### Debugging
Enable debug output to see search behavior:
```bash
export JCD_DEBUG=1
jcd <pattern>  # Will show detailed search information on stderr
```

## Architecture

### Two-Part Design
1. **Rust Binary** (`src/main.rs`, ~1500 lines):
   - Performs directory search and matching logic
   - Returns matching directory paths to stdout
   - Supports indexing to cycle through matches
   - Cannot change the parent shell's directory (fundamental OS limitation)

2. **Bash Wrapper** (`src/jcd_function.sh`):
   - Provides the `jcd` shell function users interact with
   - Handles tab completion with forward (Tab) and backward (Shift+Tab) cycling
   - Shows animated loading indicators during search
   - Calls the Rust binary and executes `cd` based on output
   - Implements fast-path shell navigation for simple cases like `..`, `../..`

### Search Algorithm (src/main.rs)
The search follows this process:
1. **Ignore Pattern Loading**: Loads regex patterns from `.jcdignore` files (unless `-x` flag)
2. **Relative Path Resolution**: Handles `..`, `../..`, `../pattern` before searching
3. **Bidirectional Search**:
   - Search up: Traverses parent directories for matches
   - Search down: Recursively searches subdirectories (max 8 levels deep)
4. **Match Quality Classification**:
   - `ExactUp`: Exact match in parent directories (highest priority)
   - `PartialUp`: Partial match in parent directories
   - `ExactDown`: Exact match in subdirectories
   - `PrefixDown`: Prefix match in subdirectories
   - `PartialDown`: Partial match in subdirectories (lowest priority)
5. **Sorting**: By match quality, then by proximity (depth from current directory)
6. **Performance Limits**: Stops after 20 matches or 500ms search time

### Ignore Pattern System (src/main.rs:18-119)
Supports `.jcdignore` files with regex patterns. File precedence (first found wins):
1. Project-local: `./.jcdignore`
2. User XDG config: `~/.config/jcd/ignore`
3. Legacy user: `~/.jcdignore`
4. System-wide: `/etc/jcd/ignore`

Performance limits: Max 100 patterns, max 1MB compiled regex size per pattern.

### Command-Line Arguments (src/main.rs:325-404)
- `-i`: Case-insensitive matching (default is case-sensitive)
- `-x`: Bypass ignore patterns (search all directories)
- `--quiet`: Disable progress indicator
- `<search_term>`: Directory pattern to match
- `[tab_index]`: Internal parameter for tab completion cycling

### Shell Function Integration (src/jcd_function.sh)
- Provides inline tab completion that cycles through matches
- Tab: cycle forward, Shift+Tab: cycle backward
- Shows animated dots during search operations
- Fast-paths for common patterns (`..`, `../..`, etc.) avoid calling Rust binary
- Uses `JCD_BINARY` environment variable to locate binary (falls back to `/usr/bin/jcd` on Linux or Homebrew path on Mac)

## Key Code Locations

- Main entry point: `src/main.rs:325` (fn main)
- Search logic: `src/main.rs:find_matching_directories()` and helper functions
- Match quality enum: `src/main.rs:125-132`
- Ignore pattern loading: `src/main.rs:18-112`
- Relative path resolution: `src/main.rs:168` (resolve_search_context)
- Tab completion: `src/jcd_function.sh:_jcd_complete_inline()` function
- Performance constants: `src/main.rs:12-16` (MAX_MATCHES, MAX_SEARCH_TIME_MS, etc.)

## Installation & Distribution

The tool is distributed via:
- Homebrew (Mac): `brew install microsoft/sysinternalstap/jcd`
- Debian/Ubuntu: Via Microsoft package repository
- RPM (Fedora/Azure Linux): Via Microsoft package repository

Users must source the shell function after installation:
```bash
source /usr/bin/jcd_function.sh  # Or /opt/homebrew/bin/jcd_function.sh on Mac
```

## PowerShell Support

PowerShell support is being added in two phases. See `TODO.md` for the complete implementation plan.

**Development Approach:**
- **Phase A: PowerShell on Linux** ✅ COMPLETE - Build and test PowerShell module using existing Rust binary on Linux
- **Phase B: PowerShell on Windows** (Future) - Add Windows-specific path support to Rust binary, then test on Windows

**Phase A Status (PowerShell on Linux) - ✅ COMPLETE:**
- ✅ Rust binary works correctly on Linux (no changes needed)
- ✅ PowerShell module (`jcd_function.ps1`) with full functionality
- ✅ Build system automatically copies `.ps1` file during build
- ✅ All basic tests pass (7/7 tests in `tests/test_powershell_basic.ps1`)
- ✅ Tab completion implemented with `Register-ArgumentCompleter -Native`
- ✅ MenuComplete compatible (shows all matches, PSReadLine handles Tab/Shift+Tab)
- ✅ Case-insensitive search with `-i` flag
- ✅ Ignore patterns work (inherited from Rust binary)

**Installation (Build from Source - Linux/WSL):**
```bash
# Build
cargo build --release

# Add to PowerShell profile ($PROFILE)
$env:JCD_BINARY = "/path/to/Sysinternals-jcd/target/release/jcd"
. /path/to/Sysinternals-jcd/target/release/jcd_function.ps1
```

**Usage:**
```powershell
jcd src              # Navigate to directory matching 'src'
jcd -i DOC           # Case-insensitive search
jcd dd<TAB>          # Tab completion shows all matches
jcd ..               # Navigate to parent
```

**Phase B Status (PowerShell on Windows) - Future:**
- ❌ Rust binary does not yet support Windows-specific ignore file paths
- ❌ PowerShell module not yet tested on Windows
- ❌ Windows path separators (`\`) not yet validated

**Key Design Decisions:**
- Develop PowerShell module on Linux first to simplify testing and iteration
- Use existing Rust binary on Linux (already works with standard Unix paths)
- Tab completion handled by PSReadLine (Tab/Shift+Tab cycling automatic)
- Use `--quiet` flag to suppress progress animation in PowerShell
- Future: `%USERPROFILE%\.config\jcd\ignore` on Windows (keeping `~/.config` pattern)
- Future: Accept both `/` and `\` as path separators on Windows
- Build-from-source installation for now; packaged installation (Scoop, etc.) will come later

## Important Notes

- The `build.rs` script copies `jcd_function.sh` to the build output directory
- All line references use format: `file_path:line_number`
- Version is managed in `Cargo.toml` and can be set with `cargo set-version`
- The tool was developed using GitHub Copilot Agent and Claude Sonnet 4
- See `TODO.md` for planned features and PowerShell support roadmap
