@echo off
set "FAKE_CODEX_ARGS=%*"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0fake-codex.ps1"
exit /b %ERRORLEVEL%
