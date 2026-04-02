@echo off
chcp 65001 >nul 2>&1
title Portable Lobster AI - Uninstall
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\uninstall_windows.ps1"
