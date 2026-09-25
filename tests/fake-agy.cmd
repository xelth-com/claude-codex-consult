@echo off
set "FAKE_AGY_ARGS=%*"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0fake-agy.ps1"
exit /b %ERRORLEVEL%
