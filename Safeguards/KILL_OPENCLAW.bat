@echo off
title OPENCLAW KILL SWITCH
color 0C

echo ============================================
echo     OPENCLAW EMERGENCY KILL SWITCH
echo ============================================
echo.
echo Terminating all Node.js processes...
taskkill /F /IM node.exe /T 2>nul
if %errorlevel%==0 (
    echo [OK] node.exe processes terminated.
) else (
    echo [--] No node.exe processes found (already stopped).
)

echo.
echo Terminating npm processes...
taskkill /F /IM npm.exe /T 2>nul
taskkill /F /IM npm.cmd /T 2>nul
echo [OK] npm cleanup done.

echo.
echo Killing any process on common OpenClaw ports (3000, 8080, 8888)...
for %%P in (3000 8080 8888) do (
    for /f "tokens=5" %%i in ('netstat -aon ^| findstr ":%%P " 2^>nul') do (
        if not "%%i"=="" (
            taskkill /F /PID %%i 2>nul
            echo [OK] Killed process on port %%P (PID: %%i)
        )
    )
)

echo.
echo ============================================
echo  OpenClaw has been terminated.
echo  Double-check Task Manager to be sure.
echo ============================================
echo.
pause
