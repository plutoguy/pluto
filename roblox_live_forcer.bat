:: Credit @aprllfools on discord

@echo off
:: Self-elevate if not running as administrator
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Requesting administrative privileges...
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

setlocal EnableDelayedExpansion
title Force Roblox Version to LIVE

echo Fetching latest version info...
for /f "usebackq delims=" %%A in (`powershell -NoProfile -Command "$json = (Invoke-WebRequest -Uri 'https://clientsettings.roblox.com/v2/client-version/WindowsPlayer/channel/LIVE').Content | ConvertFrom-Json; $json.clientVersionUpload"`) do (
    set "robloxVersion=%%A"
)

:: Add error checking for version fetch
if not defined robloxVersion (
    echo Failed to get Roblox version info. Report this message to @aprllfools or support.
    pause
    exit /b 1
)

set "version_hash=%robloxVersion:version-=%"

echo.
echo Auto-upgrading to: %version_hash%
echo.

:: Detect existing installs and prioritize Roblox
set "selected_base_path="
set "selected_name="

if exist "%localappdata%\Roblox\Versions" (
    set "selected_base_path=%localappdata%\Roblox"
    set "selected_name=Roblox (Existing)"
    echo Found existing Roblox installation
) else if exist "%localappdata%\Bloxstrap\Versions" (
    set "selected_base_path=%localappdata%\Bloxstrap"
    set "selected_name=Bloxstrap (Existing)"
    echo Found existing Bloxstrap installation
) else if exist "%localappdata%\Fishstrap\Versions" (
    set "selected_base_path=%localappdata%\Fishstrap"
    set "selected_name=Fishstrap (Existing)"
    echo Found existing Fishstrap installation
) else (
    set "selected_base_path=%localappdata%\Roblox"
    set "selected_name=Roblox (New Install)"
    echo No existing installation found, creating new Roblox installation
)

echo Using: !selected_name! - !selected_base_path!

:: Create directories if they don't exist
set "versions_path=!selected_base_path!\Versions"
if not exist "!selected_base_path!" (
    echo Creating directory: !selected_base_path!
    mkdir "!selected_base_path!" >nul 2>&1
    if %errorlevel% neq 0 (
        echo Failed to create directory: !selected_base_path!
        pause
        exit /b 1
    )
)
if not exist "!versions_path!" (
    echo Creating versions directory: !versions_path!
    mkdir "!versions_path!" >nul 2>&1
    if %errorlevel% neq 0 (
        echo Failed to create versions directory: !versions_path!
        pause
        exit /b 1
    )
)

:: Check and fix Roblox channel
for /f "tokens=1,2,3*" %%A in ('reg query "HKCU\Software\ROBLOX Corporation\Environments\RobloxPlayer\Channel" /v "www.roblox.com" 2^>nul') do (
    if /I "%%A"=="www.roblox.com" (
        set "channel=%%C"
        if /I not "!channel!"=="production" (
            set /p "choice=Detected that your Roblox Channel is not production. Do you want to switch to production? (y/n): "
            if /I "!choice!"=="y" (
                reg add "HKCU\Software\ROBLOX Corporation\Environments\RobloxPlayer\Channel" /v "www.roblox.com" /t REG_SZ /d "production" /f >nul
                echo Channel changed to production.
            ) else (
                echo Skipping channel fix.
            )
        )
    )
)

:: Define paths based on selection
set "extract_path=!versions_path!\version-%version_hash%"
set "download_url=https://rdd.weao.xyz/?channel=LIVE^&binaryType=WindowsPlayer^&version=%version_hash%"

echo.
echo Downloading version: %version_hash%
echo.

start "" %download_url%

echo Waiting for download to finish...

set "download_folder=%USERPROFILE%\Downloads"
set "zip_filename=WEAO-LIVE-WindowsPlayer-version-%version_hash%.zip"

set "timeout_counter=0"
set "timeout_limit=60"

:waitForDownload
timeout /t 1 >nul
set /a "timeout_counter+=1"

if exist "%download_folder%\%zip_filename%.crdownload" goto waitForDownload
if exist "%download_folder%\%zip_filename%.part" goto waitForDownload
if exist "%download_folder%\%zip_filename%.download" goto waitForDownload
if exist "%download_folder%\%zip_filename%.tmp" goto waitForDownload

if exist "%download_folder%\%zip_filename%" goto downloadComplete

if %timeout_counter% geq %timeout_limit% (
    echo.
    echo Download timeout reached after %timeout_limit% seconds.
    echo The file was not found in the default download location.
    echo.
    
    :askDownloadPath
    set /p custom_download_folder="Please enter your download folder path (e.g. D:\Downloads): "
    
    if not exist "!custom_download_folder!" (
        echo The specified folder does not exist. Please try again.
        goto askDownloadPath
    )
    
    set "download_folder=!custom_download_folder!"
    echo Checking for download in: !download_folder!
    
    if exist "!download_folder!\%zip_filename%" (
        echo Found the file in the specified location.
        goto downloadComplete
    ) else (
        echo.
        echo File not found in the specified location either, you should contact @aprllfools or support.
        pause
        exit /b 1
    )
)

goto waitForDownload

:downloadComplete
echo Download found at: %download_folder%\%zip_filename%

for %%A in ("%download_folder%\%zip_filename%") do set "size=%%~zA"
echo Download successful (Size: %size% bytes)

echo.
echo Removing old versions from !versions_path!...
if exist "!versions_path!\" (
    for /d %%d in ("!versions_path!\version-*") do (
        if /i not "%%~nxd"=="version-%version_hash%" (
            echo Deleting: "%%~fd"
            rmdir /s /q "%%d" >nul 2>&1
        ) else (
            echo Keeping current target version folder: "%%~fd"
        )
    )
)

set "download_zip=%download_folder%\%zip_filename%"

:: Extract
echo.
echo Extracting to: !extract_path!
if not exist "!extract_path!" mkdir "!extract_path!" >nul 2>&1

:: Check for 7-Zip via registry
for /f "delims=" %%A in ('powershell -NoProfile -Command "Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* | Where-Object { $_.DisplayName -like '7-Zip*' } | Select-Object -ExpandProperty InstallLocation"') do (
    set "sevenzip=%%A"
)

:: Check for WinRAR via registry
for /f "delims=" %%A in ('powershell -NoProfile -Command "Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* | Where-Object { $_.DisplayName -like 'WinRAR*' } | Select-Object -ExpandProperty InstallLocation"') do (
    set "winrar=%%A"
)

if defined sevenzip (
    echo Found 7-Zip in registry. Extracting...
    call "!sevenzip!\7z.exe" x "%download_zip%" -o"!extract_path!" -y
) else if defined winrar (
    echo Found WinRAR in registry. Extracting...
    call "!winrar!\WinRAR.exe" x -y "%download_zip%" "!extract_path!\"
) else (
    echo Neither 7-Zip nor WinRAR found in registry. Falling back to PowerShell...
    powershell -NoProfile -Command "Expand-Archive -Path '%download_zip%' -DestinationPath '!extract_path!' -Force"
    if %errorlevel% neq 0 (
        echo Extraction failed. Error code: %errorlevel%
        pause
        exit /b 1
    )
)

:: Cleanup downloaded zip
echo Cleaning up temp files...
del "%download_zip%" >nul 2>&1

echo.
echo Installation complete to version-%version_hash%
echo Files installed to: !extract_path!
echo Opening versions folder...
explorer "!versions_path!"
pause
exit /b 0