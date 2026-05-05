@echo off
setlocal enabledelayedexpansion

REM Dart Scoring PC - Build + Installer
REM Diese Datei im Projektroot ausführen:
REM C:\Work\Dev\VSCode_Projects\Tools\DartScoringNeu\dart_scoring_pc

set APP_VERSION=1.0.0.3-beta

echo.
echo ========================================
echo Dart Scoring PC - Installer Build
echo Version: %APP_VERSION%
echo ========================================
echo.

where flutter >nul 2>nul
if errorlevel 1 (
    echo FEHLER: Flutter wurde nicht gefunden.
    echo Starte das Script in einer Flutter/VS-Code Umgebung oder pruefe PATH.
    pause
    exit /b 1
)

echo [1/4] Flutter Dependencies laden...
call flutter pub get
if errorlevel 1 (
    echo FEHLER: flutter pub get ist fehlgeschlagen.
    pause
    exit /b 1
)

echo.
echo [2/4] Windows Release Build erstellen...
call flutter build windows --release
if errorlevel 1 (
    echo FEHLER: flutter build windows --release ist fehlgeschlagen.
    pause
    exit /b 1
)

echo.
echo [3/4] Inno Setup Compiler suchen...

set ISCC_EXE=

REM 1) Standard-Installationen
if exist "%ProgramFiles(x86)%\Inno Setup 6\ISCC.exe" (
    set "ISCC_EXE=%ProgramFiles(x86)%\Inno Setup 6\ISCC.exe"
    goto found_iscc
)

if exist "%ProgramFiles%\Inno Setup 6\ISCC.exe" (
    set "ISCC_EXE=%ProgramFiles%\Inno Setup 6\ISCC.exe"
    goto found_iscc
)

REM 2) User-Installation über winget/App Installer
if exist "%LOCALAPPDATA%\Programs\Inno Setup 6\ISCC.exe" (
    set "ISCC_EXE=%LOCALAPPDATA%\Programs\Inno Setup 6\ISCC.exe"
    goto found_iscc
)

if exist "%LOCALAPPDATA%\Inno Setup 6\ISCC.exe" (
    set "ISCC_EXE=%LOCALAPPDATA%\Inno Setup 6\ISCC.exe"
    goto found_iscc
)

REM 3) PATH prüfen
for /f "delims=" %%I in ('where ISCC.exe 2^>nul') do (
    set "ISCC_EXE=%%I"
    goto found_iscc
)

REM 4) AppData grob durchsuchen
for /f "delims=" %%I in ('where /r "%LOCALAPPDATA%" ISCC.exe 2^>nul') do (
    set "ISCC_EXE=%%I"
    goto found_iscc
)

REM 5) ProgramData grob durchsuchen
for /f "delims=" %%I in ('where /r "%ProgramData%" ISCC.exe 2^>nul') do (
    set "ISCC_EXE=%%I"
    goto found_iscc
)

echo FEHLER: ISCC.exe wurde nicht gefunden.
echo.
echo Flutter-Build war erfolgreich. Es fehlt nur der Inno Setup Compiler-Pfad.
echo Suche manuell mit:
echo where /r "%LOCALAPPDATA%" ISCC.exe
echo where /r "C:\Program Files (x86)" ISCC.exe
echo where /r "C:\Program Files" ISCC.exe
echo.
echo Wenn du den Pfad findest, schick ihn mir oder trage ihn oben bei ISCC_EXE ein.
pause
exit /b 1

:found_iscc
echo Gefunden: "%ISCC_EXE%"

if not exist "dist" mkdir "dist"

echo.
echo [4/4] Installer bauen...
"%ISCC_EXE%" /DMyAppVersion=%APP_VERSION% "installer\dart_scoring_pc.iss"
if errorlevel 1 (
    echo FEHLER: Inno Setup konnte den Installer nicht bauen.
    pause
    exit /b 1
)

echo.
echo ========================================
echo Fertig.
echo Installer liegt in:
echo dist\DartScoringPC-Setup-%APP_VERSION%.exe
echo ========================================
echo.
pause
endlocal
