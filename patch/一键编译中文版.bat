@echo off
chcp 65001 >nul
echo ============================================================
echo   OpenWorker v0.1.6 Chinese Build - Windows
echo ============================================================
echo.

REM Repo root = parent folder of this script (patch\..)
set "REPO_ROOT=%~dp0.."

REM Check for non-ASCII characters in the repo root path
set "HAS_NONASCII="
for /f "delims=" %%a in ('echo %REPO_ROOT% ^| findstr /r "[^a-zA-Z0-9 _.\-\\:/]"') do set "HAS_NONASCII=1"

if defined HAS_NONASCII (
    echo [WARN] Current folder path has non-English characters.
    echo     Copying project to English path: E:\ow-zh-build ...
    echo.
    if exist "E:\ow-zh-build" rd /s /q "E:\ow-zh-build"
    mkdir "E:\ow-zh-build"
    xcopy /E /Y /I "%REPO_ROOT%\*" "E:\ow-zh-build\" >nul
    set "WORKDIR=E:\ow-zh-build\patch"
) else (
    set "WORKDIR=%~dp0"
)

REM --- Find VS vcvarsall.bat ---
set "VCVARS="
if exist "%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe" (
    for /f "usebackq tokens=*" %%i in (`"%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe" -latest -property installationPath`) do set "VSINSTALL=%%i"
)
if defined VSINSTALL (
    if exist "%VSINSTALL%\VC\Auxiliary\Build\vcvars64.bat" set "VCVARS=%VSINSTALL%\VC\Auxiliary\Build\vcvars64.bat"
    if exist "%VSINSTALL%\VC\Auxiliary\Build\vcvarsall.bat" set "VCVARS=%VSINSTALL%\VC\Auxiliary\Build\vcvarsall.bat"
    if exist "%VSINSTALL%\BuildTools\VC\Auxiliary\Build\vcvars64.bat" set "VCVARS=%VSINSTALL%\BuildTools\VC\Auxiliary\Build\vcvars64.bat"
    if exist "%VSINSTALL%\BuildTools\VC\Auxiliary\Build\vcvarsall.bat" set "VCVARS=%VSINSTALL%\BuildTools\VC\Auxiliary\Build\vcvarsall.bat"
)
if not defined VCVARS (
    for %%p in (
        "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat"
        "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvarsall.bat"
        "C:\Program Files\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat"
        "C:\Program Files\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvarsall.bat"
        "C:\Program Files\Microsoft Visual Studio\18\Community\VC\Auxiliary\Build\vcvars64.bat"
        "C:\Program Files\Microsoft Visual Studio\18\Community\VC\Auxiliary\Build\vcvarsall.bat"
        "C:\Program Files\Microsoft Visual Studio\18\BuildTools\VC\Auxiliary\Build\vcvars64.bat"
        "C:\Program Files\Microsoft Visual Studio\18\BuildTools\VC\Auxiliary\Build\vcvarsall.bat"
    ) do if exist %%p set "VCVARS=%%~p"
)
if defined VCVARS (
    echo [OK] Found VS dev environment:
    echo     %VCVARS%
    echo Loading VS C++ environment ...
    call "%VCVARS%" x64 >nul 2>&1
) else (
    echo [WARNING] VS vcvarsall.bat not found! CMake builds may fail.
    echo.
)

echo.
echo Starting build script ...
echo Work dir: %WORKDIR%
echo.
powershell -ExecutionPolicy Bypass -File "%WORKDIR%build_zh.ps1"
pause
