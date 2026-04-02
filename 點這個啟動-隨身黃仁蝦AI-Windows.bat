@echo off
chcp 65001 >nul 2>&1
title Portable Lobster AI - Launch
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\launcher_windows_entry.ps1"
echo.
pause
