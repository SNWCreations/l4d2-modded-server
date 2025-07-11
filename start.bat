@echo off
SetLocal EnableDelayedExpansion

title Left 4 Dead 2

:: Set variables
set ROOT_DIR=%~dp0
if not exist server.ini copy NUL server.ini
for /f %%S in (server.ini) do set %%S

cls

echo If you want to quit, close the Left 4 Dead 2 window and type Y followed by Enter.

:: Ensure steamcmd exists using PowerShell script
powershell -ExecutionPolicy Bypass -File "%ROOT_DIR%steamcmd-dl.ps1"

:: Use SteamCMD to download L4D2
:: If you want to validate files, put validate before +quit so it reads "+app_update 222860 validate +quit"
echo Using SteamCMD to check for updates.
start /wait %ROOT_DIR%steamcmd\steamcmd.exe +force_install_dir ../server +login %STEAM_USER% +app_update 222860 +quit

:start

:: Deleting addons folder so no old plugins are left to cause issues
:: If you have modifications in your addons/ folder they should be in custom_files as these are merged at the end
echo Deleting addons folder.
rmdir /S /Q "%ROOT_DIR%server\left4dead2\addons\"

:: If you have modifications in your cfg/sourcemod/ folder they should be in custom_files as these are merged at the end
echo Deleting cfg/sourcemod folder.
rmdir /S /Q "%ROOT_DIR%server\left4dead2\cfg\sourcemod\"

:: Patch server with mod files
echo Copying mod files.
xcopy "%ROOT_DIR%left4dead2\*" "%ROOT_DIR%server\left4dead2\" /K /S /E /I /H /Y >NUL

:: Rename MetaMod-supplied metamod_x64.win.vdf to metamod_x64.vdf if present
if exist "%ROOT_DIR%server\left4dead2\addons\metamod_x64.win.vdf" (
    copy /Y "%ROOT_DIR%server\left4dead2\addons\metamod_x64.win.vdf" "%ROOT_DIR%server\left4dead2\addons\metamod_x64.vdf"
)

:: Fail if metamod_x64.vdf does not exist
if not exist "%ROOT_DIR%server\left4dead2\addons\metamod_x64.vdf" (
    echo ERROR: metamod_x64.vdf not found in server\left4dead2\addons. Startup aborted.
    pause
    exit /b 1
)

:: Merge your custom files in
echo Copying custom files.
xcopy "%ROOT_DIR%custom_files\*" "%ROOT_DIR%server\left4dead2\" /K /S /E /I /H /Y >NUL

:: Merge your custom files secrets in (if they exist)
if exist "%ROOT_DIR%custom_files_secret\" (
    echo Copying custom files secret from "custom_files_secret".
    xcopy "%ROOT_DIR%custom_files_secret\*" "%ROOT_DIR%server\left4dead2\" /K /S /E /I /H /Y >NUL
)

:: Start the server
echo Left 4 Dead 2 started.

:: Start server as seperate process
start /wait %ROOT_DIR%server\srcds.exe -console -game left4dead2 -port %PORT% -tickrate %TICKRATE% +log on +sv_setmax 31 +sv_maxplayers %MAXPLAYERS% +sv_visiblemaxplayers %MAXPLAYERS% +sv_lan %LAN% +map %MAP% +exec %EXEC%

echo WARNING: L4D2 closed or crashed.

:end
pause
EndLocal
