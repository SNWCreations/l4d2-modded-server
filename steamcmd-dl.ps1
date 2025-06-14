# This script downloads and extracts SteamCMD if it is not already present.
# Only for Windows platforms, as it finally produces `steamcmd.exe`.

$RootDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$SteamCmdDir = Join-Path $RootDir "steamcmd"
$SteamCmdExe = Join-Path $SteamCmdDir "steamcmd.exe"
$SteamCmdZip = Join-Path $SteamCmdDir "steamcmd.zip"
$SteamCmdUrl = "https://steamcdn-a.akamaihd.net/client/installer/steamcmd.zip"

if (-not (Test-Path $SteamCmdExe)) {
    if (-not (Test-Path $SteamCmdDir)) {
        New-Item -Path $SteamCmdDir -ItemType Directory | Out-Null
    }
    Write-Output "Downloading SteamCMD..."
    Invoke-WebRequest -Uri $SteamCmdUrl -OutFile $SteamCmdZip
    Write-Output "Extracting SteamCMD..."
    Expand-Archive -Path $SteamCmdZip -DestinationPath $SteamCmdDir -Force
    Remove-Item $SteamCmdZip -Force
    Write-Output "SteamCMD downloaded and extracted to $SteamCmdDir"
} else {
    Write-Output "SteamCMD already exists at $SteamCmdExe"
}
