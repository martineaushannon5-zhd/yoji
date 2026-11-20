@echo off
chcp 65001 >nul
rem Yoji. bootstrap: restores remotes, proxy, server/.env and dependencies.
rem Usage: setup.cmd [-GithubProxy http://127.0.0.1:10090] [-SkipInstall]
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\bootstrap.ps1" %*