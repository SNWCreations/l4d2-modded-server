@echo off
SetLocal EnableDelayedExpansion

title Left 4 Dead 2 Update

cls

:: Perform git pull
git pull

:: Check if the git pull was successful
if %errorlevel% neq 0 (
    echo Git pull failed!
    echo Was this folder cloned from git?
    echo git clone https://github.com/SNWCreations/l4d2-modded-server.git
    pause

) else (
    :: Wait for a few seconds
    timeout /t 3 /nobreak > NUL

    :: Run start.bat script
    start start.bat
)

EndLocal