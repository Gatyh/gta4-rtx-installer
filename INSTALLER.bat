@echo off
title GTA IV - RTX Remix
cd /d "%~dp0"

if not exist "%~dp0Install-GTA4RTX.ps1" (
    echo.
    echo   ERREUR : Install-GTA4RTX.ps1 introuvable.
    echo   ERROR  : Install-GTA4RTX.ps1 not found.
    echo.
    echo   Garde les deux fichiers dans le meme dossier.
    echo   Keep both files in the same folder.
    echo.
    pause
    exit /b 1
)

rem  Sans argument : interface graphique, sans fenetre de console.
rem  Avec "console" : ancien menu texte.  Ex :  INSTALLER.bat console
if /i "%~1"=="console" goto :console

powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%~dp0Install-GTA4RTX.ps1"
exit /b

:console
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Install-GTA4RTX.ps1" -Console
exit /b
