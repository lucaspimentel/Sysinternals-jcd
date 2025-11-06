# TODO - PowerShell Support and Future Enhancements

## Phased Approach

To reduce complexity, PowerShell support will be added in two major phases:
1. **Phase A: PowerShell on Linux** - Build PowerShell module using existing Rust binary (already works on Linux)
2. **Phase B: PowerShell on Windows** - Add Windows-specific path support to Rust binary, then test PowerShell on Windows

This approach allows us to develop and test the PowerShell module in a familiar Linux environment before tackling Windows-specific challenges.

---

## Phase A: PowerShell Support on Linux ✓ PRIORITY

### Phase A1: PowerShell Module - Basic Functionality ✅ COMPLETED
**Goal**: Create `jcd_function.ps1` that works on Linux with existing Rust binary

- [x] Create `src/jcd_function.ps1`:
  - [x] Implement basic `jcd` function that calls the Rust binary
  - [x] Add `-i` flag support for case-insensitive matching
  - [x] Add `-x` flag support for bypassing ignore patterns
  - [x] Add help message (`-h`, `--help`)
  - [x] Implement fast-path for simple navigation (`..`, `../..`, `.`, etc.)
  - [x] Locate binary via `$env:JCD_BINARY` or default locations (Linux paths: `/usr/bin/jcd`, Homebrew paths)
  - [x] Handle errors when no matches found
  - [x] Change directory with `Set-Location` based on binary output

### Phase A2: PowerShell Module - Basic Tab Completion ✅ COMPLETED
**Goal**: Tab completion showing all matches (MenuComplete compatible)

- [x] Implement `Get-JcdAllMatches` helper function:
  - [x] Call binary with increasing index (0, 1, 2...) until no results
  - [x] Handle case-insensitive flag (`-i`)
  - [x] Safety limit of 100 matches

- [x] Implement `Register-ArgumentCompleter` with `-Native` for `jcd`:
  - [x] Detect case-insensitive flag (`-i`) from command line
  - [x] Get all matches from binary
  - [x] Return all matches at once (MenuComplete compatible)
  - [x] Show directory names in menu, insert full paths
  - [x] Handle no matches (return empty array)

- [x] Manual testing:
  - [x] Test with relative patterns (`jcd src<TAB>`)
  - [x] Test with case-insensitive flag (`jcd -i SRC<TAB>`)
  - [x] Verified MenuComplete compatibility

### Phase A3: Build System Updates ✅ COMPLETED
**Goal**: Automatically copy PowerShell module during build

- [x] Update `build.rs:1-31`:
  - [x] Copy `src/jcd_function.ps1` to `target/release/` and `target/debug/`
  - [x] Add `println!("cargo:rerun-if-changed=src/jcd_function.ps1");`

### Phase A4: Testing on Linux ✅ COMPLETED
**Goal**: Verify PowerShell functionality on Linux

**Status**: All basic tests passing (7/7)

- [x] Manual testing on Linux with PowerShell:
  - [x] Basic navigation works
  - [ ] Tab completion works (Phase A2 not yet complete)
  - [x] Ignore patterns work (inherited from Rust binary)
  - [x] Case-insensitive search works
  - [x] `-x` flag works (inherited from Rust binary)

- [x] Create `tests/test_powershell_basic.ps1`:
  - [x] Basic test framework
  - [x] Test help flag
  - [x] Test navigation (.., ../.. patterns)
  - [x] Test case-insensitive flag
  - [x] Test error handling
  - [x] Fixed tests to use proper PowerShell patterns (Write-Host vs Write-Output)
  - [ ] Port additional tests from bash test suite (future enhancement)
  - [ ] Test ignore file loading from `~/.config/jcd/ignore` (future enhancement)

### Phase A5: Documentation for Linux ✅ COMPLETED
**Goal**: Document PowerShell usage on Linux

- [ ] Update `README.md`:
  - [ ] Deferred - waiting for packaged installation method
  - [ ] Will add PowerShell section when package managers support it

- [x] Update `CLAUDE.md`:
  - [x] Update PowerShell support status to COMPLETE
  - [x] Add installation instructions (build from source)
  - [x] Add usage examples
  - [x] Document tab completion (MenuComplete compatible)
  - [x] Note Phase A completion

---

## Phase B: PowerShell Support on Windows

### Phase B1: Rust Binary - Windows Path Support ✅ COMPLETED
**Goal**: Make the Rust binary work correctly on Windows

- [x] Update `get_ignore_file_paths()` in `src/main.rs:18-83`:
  - [x] Add `#[cfg(windows)]` and `#[cfg(not(windows))]` conditional compilation
  - [x] Use `%USERPROFILE%\.config\jcd\ignore` on Windows
  - [x] Use `%USERPROFILE%\.jcdignore` (legacy) on Windows
  - [x] Use `%PROGRAMDATA%\jcd\ignore` (system-wide, not hardcoded C:\ProgramData)
  - [x] Keep project-local `.jcdignore` (works as-is on all platforms)
  - [x] Unix paths unchanged (HOME, XDG_CONFIG_HOME, /etc/jcd/ignore)

- [ ] Test path separator handling (requires Windows):
  - [ ] Verify `PathBuf` handles both `/` and `\` correctly on Windows
  - [ ] Test patterns like `jcd foo/bar` work with forward slashes on Windows
  - [ ] Test absolute Windows paths like `C:\Users\...`
  - [ ] Test UNC paths like `\\server\share` (if applicable)

- [x] Windows-specific dependencies:
  - [x] No additional dependencies needed - using stdlib env vars

### Phase B2: PowerShell Module - Windows Path Support ✅ COMPLETED
**Goal**: Update `jcd_function.ps1` to handle Windows paths

- [x] Update `src/jcd_function.ps1`:
  - [x] Add Windows default binary locations to search path
    - [x] %ProgramFiles%\jcd\jcd.exe
    - [x] %ProgramFiles(x86)%\jcd\jcd.exe
    - [x] %LOCALAPPDATA%\Programs\jcd\jcd.exe
  - [x] Update both main function and tab completion binary location
  - [x] Fast-path logic already works (PowerShell handles path separators)

### Phase B3: Testing on Windows
**Goal**: Verify PowerShell functionality on Windows

- [ ] Manual testing on Windows:
  - [ ] Basic navigation works
  - [ ] Tab completion works
  - [ ] Ignore patterns work with Windows paths
  - [ ] Case-insensitive search works
  - [ ] `-x` flag works

- [ ] Create `tests/validate_jcd_windows.ps1`:
  - [ ] Port tests from `validate_jcd_powershell.ps1`
  - [ ] Add Windows-specific path tests
  - [ ] Test ignore file loading from `%USERPROFILE%\.config\jcd\ignore`

### Phase B4: Documentation for Windows
**Goal**: Document PowerShell usage on Windows

- [ ] Update `README.md`:
  - [ ] Add PowerShell installation instructions for Windows
  - [ ] Add build-from-source instructions for Windows
  - [ ] Update PowerShell usage examples with Windows paths

- [ ] Update `DEVELOPMENT.md`:
  - [ ] Add Windows build instructions
  - [ ] Add PowerShell testing instructions for Windows

- [ ] Update `INSTALL.md`:
  - [ ] Add build-from-source instructions for Windows

- [ ] Update `CLAUDE.md`:
  - [ ] Note Phase B completion
  - [ ] Document full PowerShell support on both platforms

## Future Enhancements (Lower Priority)

### Tab Completion Notes
**Note**: Tab/Shift+Tab cycling and menu display are handled by PSReadLine automatically.
Our `Register-ArgumentCompleter` returns all matches, and PSReadLine handles:
- Tab: Forward cycling
- Shift+Tab: Backward cycling
- MenuComplete, InlineView, ListView modes
- All keyboard navigation

No additional implementation needed - it already works!

### Advanced Features
- [ ] **Animated loading indicators** in PowerShell (optional):
  - [ ] Use `Write-Host -NoNewline` with ANSI escape codes
  - [ ] Implement background job for animation
  - [ ] Note: Currently using `--quiet` flag, so no animation needed

### Installation & Packaging
- [ ] **Scoop package**:
  - [ ] Create scoop manifest JSON
  - [ ] Submit to scoop bucket
  - [ ] Document scoop installation in README

- [ ] **Chocolatey package**:
  - [ ] Create `.nuspec` file
  - [ ] Create installation script
  - [ ] Submit to chocolatey.org

- [ ] **winget package**:
  - [ ] Create winget manifest YAML
  - [ ] Submit to winget-pkgs repository

- [ ] **MSI installer**:
  - [ ] Create WiX toolset configuration
  - [ ] Build MSI package
  - [ ] Add to releases

### Cross-Platform Improvements
- [ ] Add cross-platform path handling crate (`dirs` or similar)
- [ ] Add Windows CI/CD pipeline to test builds
- [ ] Add automated testing for both bash and PowerShell implementations

### ZSH Support Improvements
- [ ] Review existing zsh support in `jcd_function.sh:989-1074`
- [ ] Test zsh tab completion more thoroughly
- [ ] Document zsh-specific features

## Notes
- PowerShell 7+ is required for best compatibility (especially for advanced features like `Set-PSReadLineKeyHandler`)
- Windows PowerShell 5.1 may have limited tab completion capabilities
- All paths should accept both `/` and `\` as separators on Windows
- Keep `~/.config/jcd/ignore` pattern for consistency across platforms (map to `%USERPROFILE%\.config\jcd\ignore` on Windows)
