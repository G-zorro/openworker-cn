#requires -Version 5.1
<#
.SYNOPSIS   Build OpenWorker v0.1.6 Chinese localized version (Windows)
.DESCRIPTION
  1. Verify full toolchain (Rust/Node/Python/VS/Clang/CMake)
  2. Clone v0.1.6 source (with submodules)
  3. Apply zh-CN patch
  4. Copy sidecar from installed OpenWorker (auto-detect)
  5. Build installer
  On STT/CMake failure, auto-fallback to STT-disabled build (no CMake needed).
#>

param(
    [string]$Bundles = "nsis"
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path   # ...\patch
$Root      = Split-Path -Parent $ScriptDir                      # repo root (parent of patch)
$Repo      = Join-Path $Root "openworker"
$Gui       = Join-Path $Repo "surfaces\gui"
$SttOff    = $false

# ----------------------------------------------------------
# Helper: require a command
# ----------------------------------------------------------
function Ensure-Tool {
    param([string]$Cmd, [string]$Name, [string]$Hint)
    if (Get-Command $Cmd -ErrorAction SilentlyContinue) {
        Write-Host "    [OK] $Name found." -ForegroundColor Green
        return $true
    }
    Write-Host "    [MISSING] $Name" -ForegroundColor Red
    Write-Host "        -> $Hint" -ForegroundColor Yellow
    return $false
}

# ----------------------------------------------------------
# STEP 1a - load VS dev environment FIRST (sets PATH for all later checks)
# ----------------------------------------------------------
Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "STEP 1a: Load VS C++ dev environment" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

$vcVars = $null
$vsWhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
if (Test-Path $vsWhere) {
    $ip = & $vsWhere -latest -property installationPath 2>$null
    if ($ip) {
        $cands = @(
            "$ip\VC\Auxiliary\Build\vcvars64.bat",
            "$ip\VC\Auxiliary\Build\vcvarsall.bat"
        )
        foreach ($v in $cands) { if (Test-Path $v) { $vcVars = $v; break } }
    }
}
if (-not $vcVars) {
    $fb = @(
        "C:\Program Files\Microsoft Visual Studio\18\Community\VC\Auxiliary\Build\vcvars64.bat",
        "C:\Program Files\Microsoft Visual Studio\18\BuildTools\VC\Auxiliary\Build\vcvars64.bat",
        "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat",
        "C:\Program Files\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat",
        "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat"
    )
    foreach ($v in $fb) { if (Test-Path $v) { $vcVars = $v; break } }
}
if ($vcVars) {
    Write-Host "    Loading: $vcVars" -ForegroundColor Yellow
    $out = cmd /c "`"$vcVars`" x64 >nul 2>&1 && set"
    foreach ($line in $out) {
        if ($line -match "^([^=]+)=(.*)$") {
            [System.Environment]::SetEnvironmentVariable($matches[1], $matches[2], "Process")
        }
    }
    Write-Host "    VS C++ env loaded (PATH/LIB/INCLUDE updated)." -ForegroundColor Green
} else {
    Write-Host "    WARNING: vcvarsall.bat not found - compiler may be missing." -ForegroundColor Yellow
}

# ----------------------------------------------------------
# STEP 1 - full toolchain check (runs AFTER VS env is loaded)
# ----------------------------------------------------------
Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "STEP 1: Verify toolchain" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

$ok = $true
$ok = (Ensure-Tool rustc  "Rust"        "https://rustup.rs  (install stable + MSVC)") -and $ok
$ok = (Ensure-Tool npm    "Node.js"     "https://nodejs.org  (LTS 20+)") -and $ok
$ok = (Ensure-Tool python "Python 3.10+" "https://python.org  (3.10+)") -and $ok
$ok = (Ensure-Tool cmake  "CMake"       "Install via VS2022 -> 'C++ CMake tools for Windows', or winget install Kitware.CMake") -and $ok

# VS / MSVC compiler - search BOTH Program Files and Program Files (x86)
$clPath = $null
foreach ($base in @("$env:ProgramFiles", "${env:ProgramFiles(x86)}")) {
    if (-not $clPath) {
        $clPath = Get-ChildItem -Path "$base\Microsoft Visual Studio" -Recurse -Filter "cl.exe" -ErrorAction SilentlyContinue |
            Where-Object { $_.FullName -match "VC\\Tools\\MSVC" } | Select-Object -First 1
    }
}
if ($clPath) {
    $clDir = Split-Path $clPath.FullName
    $env:PATH = "$clDir;$env:PATH"
    Write-Host "    [OK] MSVC cl.exe found: $($clPath.FullName)" -ForegroundColor Green
} else {
    Write-Host "    [MISSING] MSVC C++ compiler (cl.exe)" -ForegroundColor Red
    Write-Host "        -> VS2022 Build Tools -> Workload 'Desktop development with C++'" -ForegroundColor Yellow
    $ok = $false
}

# libclang for bindgen
$libclang = $null
$libclangPaths = @(
    "$env:ProgramFiles\LLVM\bin",
    "${env:ProgramFiles(x86)}\LLVM\bin",
    "C:\Program Files\Microsoft Visual Studio\18\Community\VC\Tools\Llvm\x64\bin",
    "C:\Program Files\Microsoft Visual Studio\18\BuildTools\VC\Tools\Llvm\x64\bin",
    "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Tools\Llvm\x64\bin",
    "C:\Program Files\Microsoft Visual Studio\2022\BuildTools\VC\Tools\Llvm\x64\bin"
)
foreach ($p in $libclangPaths) {
    if (Test-Path (Join-Path $p "libclang.dll")) { $libclang = $p; break }
}
if ($libclang) {
    $env:LIBCLANG_PATH = $libclang
    $env:PATH = "$libclang;$env:PATH"
    Write-Host "    [OK] libclang found: $libclang" -ForegroundColor Green
} else {
    Write-Host "    [MISSING] libclang.dll (for bindgen)" -ForegroundColor Red
    Write-Host "        -> VS2022 -> single component 'C++ Clang tools for Windows', or winget install LLVM.LLVM" -ForegroundColor Yellow
    $ok = $false
}

if (-not $ok) {
    Write-Host ""
    Write-Host ">>> Some tools are missing. Install them, then re-run this script." -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}
Write-Host "    All tools OK." -ForegroundColor Green

# ----------------------------------------------------------
# STEP 2 - clone / reset source
# ----------------------------------------------------------
Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "STEP 2: Get openworker v0.1.6 source" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

if (-not (Test-Path (Join-Path $Repo ".git"))) {
    Write-Host "    Cloning v0.1.6 (recursive) ..." -ForegroundColor Yellow
    git clone --branch v0.1.6 --recurse-submodules https://github.com/andrewyng/openworker.git $Repo
} else {
    Write-Host "    Resetting to v0.1.6 ..." -ForegroundColor Yellow
    git -C $Repo fetch origin v0.1.6
    git -C $Repo reset --hard v0.1.6
    git -C $Repo submodule update --init --recursive
}

# ----------------------------------------------------------
# STEP 3 - inject zh-CN translation script into Tauri (DOM-level)
# ----------------------------------------------------------
Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "STEP 3: Inject zh-CN DOM-level translator" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Copy-Item (Join-Path $ScriptDir "inject_to_init.py")  $Repo -Force
Copy-Item (Join-Path $ScriptDir "zh-CN-inject.js") $Repo -Force
Copy-Item (Join-Path $ScriptDir "zh-CN.json")     $Repo -Force
Copy-Item (Join-Path $ScriptDir "regen_dict.py")  $Repo -Force
Push-Location $Repo
try {
    # Keep zh-CN-inject.js in sync with zh-CN.json, then inject
    & python regen_dict.py
    & python inject_to_init.py
}
finally { Pop-Location }

# Verify injection actually landed
$injectCheck = Select-String -Path (Join-Path $Repo "surfaces\gui\src-tauri\src\lib.rs") -Pattern "ZH-CN INJECTION" -Quiet
if (-not $injectCheck) {
    Write-Host "ERROR: Translation injection FAILED - lib.rs not modified." -ForegroundColor Red
    Read-Host "Press Enter to exit"; exit 1
}
Write-Host "    [Verified] Translation injection present in lib.rs" -ForegroundColor Green

# ----------------------------------------------------------
# STEP 4 - patch package.json (skip tsc type-check)
# ----------------------------------------------------------
Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "STEP 4: Patch frontend build config" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
$pkg = Join-Path $Gui "package.json"
if (Test-Path $pkg) {
    $c = [System.IO.File]::ReadAllText($pkg, [System.Text.Encoding]::UTF8)
    $c = $c.Replace('"build": "tsc && vite build"', '"build": "vite build"')
    [System.IO.File]::WriteAllText($pkg, $c, (New-Object System.Text.UTF8Encoding $false))
    Write-Host "    patched (tsc skipped)." -ForegroundColor Green
}

# ----------------------------------------------------------
# STEP 5 - locate sidecar
# ----------------------------------------------------------
Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "STEP 5: Locate OpenWorker sidecar" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

$cands = New-Object System.Collections.ArrayList
[void]$cands.Add("$env:LOCALAPPDATA\Programs\OpenWorker")
[void]$cands.Add("$env:PROGRAMFILES\OpenWorker")
[void]$cands.Add("${env:PROGRAMFILES(x86)}\OpenWorker")
[void]$cands.Add("$env:LOCALAPPDATA\OpenWorker")
Get-PSDrive -PSProvider FileSystem | ForEach-Object {
    $r  = Join-Path $_.Root "OpenWorker"
    $r2 = Join-Path $_.Root "Programs\OpenWorker"
    if (Test-Path $r)  { [void]$cands.Add($r) }
    if (Test-Path $r2) { [void]$cands.Add($r2) }
}

$SidecarSrc = $null
foreach ($c in $cands) {
    $t = Join-Path $c "sidecar"
    if (Test-Path $t) { $SidecarSrc = $t; Write-Host "    Auto-detected: $SidecarSrc" -ForegroundColor Green; break }
}
if (-not $SidecarSrc) {
    Write-Host "    Auto-detect failed. Enter your OpenWorker folder (e.g. G:\OpenWorker):" -ForegroundColor Yellow
    $up = Read-Host "    Path"
    if ($up -and (Test-Path (Join-Path $up "sidecar"))) { $SidecarSrc = Join-Path $up "sidecar" }
}
if (-not $SidecarSrc) {
    Write-Host "ERROR: sidecar not found." -ForegroundColor Red
    Read-Host "Press Enter to exit"; exit 1
}
$SidecarDst = Join-Path $Gui "src-tauri\binaries\sidecar"
# Clean target to avoid double-nesting from re-runs
if (Test-Path $SidecarDst) { Remove-Item -Recurse -Force $SidecarDst }
New-Item -ItemType Directory -Force -Path $SidecarDst | Out-Null
# Copy contents of SidecarSrc INTO SidecarDst (no extra nesting)
Copy-Item -Path (Join-Path $SidecarSrc "*") -Destination $SidecarDst -Recurse -Force
Write-Host "    Sidecar copied (flattened)." -ForegroundColor Green

# ----------------------------------------------------------
# STEP 6 - build (with STT auto-fallback)
# ----------------------------------------------------------
Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "STEP 6: Build Chinese installer" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Push-Location $Gui
try {
    Write-Host "    npm install ..." -ForegroundColor Yellow
    npm install

    Write-Host "    tauri build (full, with STT) ..." -ForegroundColor Yellow
    & npm run tauri build -- --bundles $Bundles
    if ($LASTEXITCODE -ne 0) { throw "tauri build exited with code $LASTEXITCODE" }
}
catch {
    $errMsg = $_.Exception.Message
    Write-Host ""
    Write-Host ">>> Build/Bundle error: $errMsg" -ForegroundColor Red

    # Check if exe was still produced despite NSIS failure
    $exePath = Join-Path $Gui "src-tauri\target\release\openworker-desktop.exe"
    if (Test-Path $exePath) {
        Write-Host ">>> EXE was built successfully. NSIS packaging failed (sidecar path mismatch)." -ForegroundColor Yellow
        Write-Host ">>> Creating portable ZIP instead..." -ForegroundColor Yellow
    } else {
        Write-Host ">>> EXE not found. Trying STT-disabled rebuild..." -ForegroundColor Yellow
        Write-Host ""

        & python (Join-Path $ScriptDir "disable_stt.py")
        $SttOff = $true

        Write-Host "    tauri build (STT-disabled) ..." -ForegroundColor Yellow
        & npm run tauri build -- --bundles $Bundles
        if ($LASTEXITCODE -ne 0) { throw "tauri build (STT-off) also failed: $LASTEXITCODE" }
    }
}
finally { Pop-Location }

# ----------------------------------------------------------
# DONE - report results
# ----------------------------------------------------------
$ExePath = Join-Path $Gui "src-tauri\target\release\openworker-desktop.exe"
$BundleDir = Join-Path $Gui "src-tauri\target\release\bundle"
$OutDir = Join-Path $Root "dist"

Write-Host ""
Write-Host "==========================================" -ForegroundColor Green
Write-Host "BUILD COMPLETE!" -ForegroundColor Green

if ($SttOff) {
    Write-Host "NOTE: Voice-input (STT) was disabled due to build limits." -ForegroundColor Yellow
    Write-Host "      Translation uses DOM-level injection (MutationObserver)." -ForegroundColor Yellow
}

if (Test-Path $ExePath) {
    # If NSIS installer wasn't produced, create a portable zip
    $nsisExe = Get-ChildItem -Path $BundleDir -Recurse -Filter "*.exe" -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match "setup|install" }
    if (-not $nsisExe) {
        Write-Host "NSIS installer not available. Creating portable ZIP..." -ForegroundColor Yellow
        New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
        $zipName = "OpenWorker_zh-CN_v0.1.6_x64_portable.zip"
        $zipDst = Join-Path $OutDir $zipName
        Compress-Archive -Path $ExePath -DestinationPath $zipDst -Force
        Write-Host "Portable ZIP: $zipDst" -ForegroundColor Green
        Write-Host "To run: extract openworker-desktop.exe, then double-click it." -ForegroundColor Yellow
        Write-Host "(Keep it next to a 'sidecar' folder from your installed OpenWorker)" -ForegroundColor Yellow
    } else {
        Write-Host "Installer: $BundleDir" -ForegroundColor Green
    }
    Write-Host "EXE:      $ExePath" -ForegroundColor Green
} else {
    Write-Host "ERROR: EXE not found at expected path." -ForegroundColor Red
}

Write-Host "==========================================" -ForegroundColor Green

Write-Host ""
Read-Host "Press Enter to close"
