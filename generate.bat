@echo off
:: =============================================================
:: generate.bat — Windows launcher for generate.sh
:: Works by converting the Windows path to WSL mount path
:: and delegating all logic to generate.sh (requires WSL + python3)
::
:: Usage (from Windows terminal or double-click):
::   generate.bat --all
::   generate.bat --product itechgenie
::   generate.bat --new --slug dodl --name "Dodl" --accent "#f97316" --cta "Launch Dodl"
:: =============================================================

setlocal EnableDelayedExpansion

:: ---------- Check WSL is available ----------
where wsl >nul 2>&1
if errorlevel 1 (
    echo ERROR: WSL ^(Windows Subsystem for Linux^) is not installed or not in PATH.
    echo Please install WSL: https://learn.microsoft.com/en-us/windows/wsl/install
    pause
    exit /b 1
)

:: ---------- Convert Windows path to WSL path ----------
:: e.g. D:\Projects\0it.in  ->  /mnt/d/Projects/0it.in
set "WIN_DIR=%~dp0"
:: Remove trailing backslash
if "%WIN_DIR:~-1%"=="\" set "WIN_DIR=%WIN_DIR:~0,-1%"

:: Extract drive letter (lowercase), strip colon, replace backslashes
set "DRIVE=%WIN_DIR:~0,1%"
:: Lowercase the drive letter
for %%a in (a b c d e f g h i j k l m n o p q r s t u v w x y z) do (
    if /i "%DRIVE%"=="%%a" set "DRIVE_LC=%%a"
)
set "REST=%WIN_DIR:~2%"
set "REST=%REST:\=/%"
set "WSL_DIR=/mnt/%DRIVE_LC%%REST%"

:: ---------- Pass all arguments straight through ----------
echo Running: bash generate.sh %*
echo.
wsl bash "%WSL_DIR%/generate.sh" %*

if errorlevel 1 (
    echo.
    echo Generation failed. See error above.
    pause
    exit /b 1
)

echo.
pause
endlocal
