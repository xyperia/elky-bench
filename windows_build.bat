@echo off
setlocal enabledelayedexpansion

REM ==============================================================================
REM ElkyBench - Windows Build Script (x64 / AMD64 & ARM64)
REM ==============================================================================

echo ==========================================================
echo   ElkyBench - Windows Release Builder
echo ==========================================================

set TARGET_ARCH=%1
if "%TARGET_ARCH%"=="" (
    if "%PROCESSOR_ARCHITECTURE%"=="ARM64" (
        set TARGET_ARCH=arm64
    ) else (
        set TARGET_ARCH=x64
    )
)

echo [*] Target Architecture: %TARGET_ARCH%
echo [*] Host Processor Architecture: %PROCESSOR_ARCHITECTURE%

echo [*] Resolving Flutter dependencies...
call flutter pub get
if errorlevel 1 (
    echo [-] Failed to fetch dependencies.
    exit /b %errorlevel%
)

echo [*] Enabling Windows desktop support...
call flutter config --enable-windows-desktop >nul 2>&1

echo [*] Building Windows Release Application...
call flutter build windows --release
if errorlevel 1 (
    echo [-] Build failed. Make sure Visual Studio with C++ desktop workload is installed.
    exit /b %errorlevel%
)

set OUTPUT_DIR=build\windows\%TARGET_ARCH%\runner\Release
if not exist "%OUTPUT_DIR%" (
    set OUTPUT_DIR=build\windows\x64\runner\Release
)

echo ==========================================================
echo   BUILD SUCCESSFUL!
echo   Application path: %OUTPUT_DIR%\elky_bench.exe
echo ==========================================================

pause
