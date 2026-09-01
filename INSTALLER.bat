@echo off
title GTA IV - RTX Remix : installation
cd /d "%~dp0"

if not exist "%~dp0Install-GTA4RTX.ps1" (
    echo.
    echo   ERREUR : Install-GTA4RTX.ps1 introuvable.
    echo   Garde les deux fichiers dans le meme dossier.
    echo.
    pause
    exit /b 1
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Install-GTA4RTX.ps1" %*
