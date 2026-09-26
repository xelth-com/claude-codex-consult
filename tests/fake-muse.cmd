@echo off
set "FAKE_MUSE_ARGS=%*"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0fake-muse.ps1"
exit /b %ERRORLEVEL%
