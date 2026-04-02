@echo off
chcp 65001 >nul 2>&1
title Portable Lobster AI - Install
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\install_bundle_windows_v2.ps1"
echo.
pause
