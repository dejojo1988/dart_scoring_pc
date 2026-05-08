@echo off
setlocal

set "VERSION=1.0.3.4-beta"
set "INSTALLER_NAME=DartScoringPC-Setup-%VERSION%.exe"
set "INNO_EXE="

echo.
echo ==========================================
echo  Dart Scoring PC - Installer Build
echo  Version: %VERSION%
echo ==========================================
echo.

echo [0/4] Suche Inno Setup Compiler...

where iscc >nul 2>nul
if not errorlevel 1 (
    set "INNO_EXE=iscc"
)

if "%INNO_EXE%"=="" (
    if exist "%LOCALAPPDATA%\Programs\Inno Setup 6\ISCC.exe" (
        set "INNO_EXE=%LOCALAPPDATA%\Programs\Inno Setup 6\ISCC.exe"
    )
)

if "%INNO_EXE%"=="" (
    if exist "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" (
        set "INNO_EXE=C:\Program Files (x86)\Inno Setup 6\ISCC.exe"
    )
)

if "%INNO_EXE%"=="" (
    if exist "C:\Program Files\Inno Setup 6\ISCC.exe" (
        set "INNO_EXE=C:\Program Files\Inno Setup 6\ISCC.exe"
    )
)

if "%INNO_EXE%"=="" (
    echo.
    echo FEHLER: Inno Setup Compiler ISCC.exe wurde nicht gefunden.
    echo Bitte Inno Setup installieren:
    echo winget install --id JRSoftware.InnoSetup -e -s winget -i
    echo.
    pause
    exit /b 1
)

echo Gefunden:
echo "%INNO_EXE%"

echo.
echo [1/4] Flutter Windows Release Build...
call flutter build windows --release
if errorlevel 1 (
    echo.
    echo FEHLER: Flutter Build fehlgeschlagen.
    pause
    exit /b 1
)

echo.
echo [2/4] Alte Installer-Datei entfernen...
if exist "dist\%INSTALLER_NAME%" (
    del "dist\%INSTALLER_NAME%"
)

echo.
echo [3/4] Inno Setup Installer bauen...
"%INNO_EXE%" /DMyAppVersion=%VERSION% "installer\dart_scoring_pc.iss"
if errorlevel 1 (
    echo.
    echo FEHLER: Inno Setup Build fehlgeschlagen.
    pause
    exit /b 1
)

echo.
echo [4/4] Fertig.
echo Erwartete Datei:
echo dist\%INSTALLER_NAME%
echo.

pause
endlocal