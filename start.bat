@echo off
SetLocal EnableDelayedExpansion

title Left 4 Dead 2

:: Set variables
set ROOT_DIR=%~dp0
set "gameinfo=server\left4dead2\gameinfo.txt"
if not exist server.ini copy NUL server.ini
for /f %%S in (server.ini) do set %%S

cls

echo If you want to quit, close the Left 4 Dead 2 window and type Y followed by Enter.

:: Ensure steamcmd exists
if not exist "%ROOT_DIR%steamcmd\steamcmd.exe" (
    mkdir "%ROOT_DIR%steamcmd"
    echo Downloading SteamCMD
    powershell -Command "Invoke-WebRequest -Uri https://steamcdn-a.akamaihd.net/client/installer/steamcmd.zip -OutFile '%ROOT_DIR%steamcmd\steamcmd.zip'"
    powershell -Command "Expand-Archive -Path '%ROOT_DIR%steamcmd\steamcmd.zip' -DestinationPath '%ROOT_DIR%steamcmd'"
    del "%ROOT_DIR%steamcmd\steamcmd.zip"
)

:: Use SteamCMD to download L4D2
:: If you want to validate files, put validate before +quit so it reads "+app_update 222860 validate +quit"
echo Using SteamCMD to check for updates.
start /wait %ROOT_DIR%steamcmd\steamcmd.exe +force_install_dir ../server +login anonymous +app_update 222860 +quit

:start

:: Deleting addons folder so no old plugins are left to cause issues
:: If you have modifications in your addons/ folder they should be in custom_files as these are merged at the end
echo Deleting addons folder.
rmdir /S /Q "%ROOT_DIR%server\left4dead2\addons\"

:: If you have modifications in your cfg/settings/ folder they should be in custom_files as these are merged at the end
echo Deleting cfg/sourcemod folder.
rmdir /S /Q "%ROOT_DIR%server\left4dead2\cfg\sourcemod\"

:: Patch server with mod files
echo Copying mod files.
xcopy "%ROOT_DIR%left4dead2\*" "%ROOT_DIR%server\left4dead2\" /K /S /E /I /H /Y >NUL

:: Merge Windows specific files
echo Merging Windows specific files.
xcopy "%ROOT_DIR%left4dead2\addons\windows\*" "%ROOT_DIR%server\left4dead2\" /K /S /E /I /H /Y >NUL

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
