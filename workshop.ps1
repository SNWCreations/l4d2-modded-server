# Generated by GitHub Copilot
# Script to download Left 4 Dead 2 workshop items using SteamCMD
<#
.SYNOPSIS
    Downloads Left 4 Dead 2 workshop items or collections using SteamCMD.
.DESCRIPTION
    This script allows you to download single workshop items or entire collections from the Left 4 Dead 2 Steam Workshop.
    It can be run with a Steam Workshop URL, a single item ID, or a collection ID.
.PARAMETER WorkshopUrl
    The URL of the Steam Workshop item or collection to download.
.PARAMETER Single
    The ID of a single workshop item to download.
.PARAMETER Collection
    The ID of a workshop collection to download.
.PARAMETER VerboseDebug
    Enables debug logging for troubleshooting.
.PARAMETER UserName
    The Steam username to log in with. This is required for downloading workshop items.
    If you have Steam Guard enabled, you will need to handle login request while running the script.
    Do not use your password here; it will prompt for it securely.
    Do not use anonymous login, as it will not work for workshop downloads.
.PARAMETER Keep
    If specified, keeps the original downloaded files after copying them to the workshop directory.
.EXAMPLE
    .\workshop.ps1 "https://steamcommunity.com/sharedfiles/filedetails/?id=123456789"
    Downloads the workshop item with ID 123456789.
.EXAMPLE
    .\workshop.ps1 -Single 123456789
    Downloads the single workshop item with ID 123456789.
.EXAMPLE
    .\workshop.ps1 -Collection 987654321
    Downloads the workshop collection with ID 987654321.
.EXAMPLE
    .\workshop.ps1 -WorkshopUrl "https://steamcommunity.com/sharedfiles/filedetails/?id=123456789" -Debug
    Downloads the workshop item with ID 123456789 and enables debug logging.
#>
# Requires: PowerShell 5.0 or later
# Requires: steamcmd.exe to be available in the steamcmd directory or downloaded via steamcmd-dl.ps1
# Requires: steamcmd-dl.ps1 to download steamcmd.exe if not present
# Requires: Internet access to download workshop items
# Requires: Left 4 Dead 2 app ID (550) to be used with SteamCMD

param(
    [string]$WorkshopUrl,
    [string]$Single,
    [string]$Collection,
    [switch]$VerboseDebug,
    [Parameter(Mandatory=$true)][string]$UserName,
    [switch]$Keep = $false
)

function DebugLog($msg) {
    if ($VerboseDebug) { Write-Host "[DEBUG] $msg" -ForegroundColor Yellow }
}

if ($Single) {
    $isCollection = $false
    $itemId = $Single
    DebugLog "Single item mode. Item ID: $itemId"
} elseif ($Collection) {
    $isCollection = $true
    $collectionId = $Collection
    DebugLog "Collection mode. Collection ID: $collectionId"
} elseif ($WorkshopUrl) {
    DebugLog "Parsing Workshop URL: $WorkshopUrl"
    if ($WorkshopUrl -match "\?id=(\d+)") {
        $possibleId = $matches[1]
        DebugLog "Extracted ID from URL: $possibleId"
        # Query Steam API to check if it's a collection or single item
        $detailsApiUrl = "https://api.steampowered.com/ISteamRemoteStorage/GetCollectionDetails/v1/"
        $body = @{ "collectioncount" = 1; "publishedfileids[0]" = $possibleId }
        try {
            $response = Invoke-RestMethod -Uri $detailsApiUrl -Method Post -Body $body
            $collectionDetails = $response.response.collectiondetails
            $children = $null
            if ($collectionDetails -and $collectionDetails[0] -and $collectionDetails[0].children) {
                $isCollection = $true
                $collectionId = $possibleId
                $children = $collectionDetails[0].children
                DebugLog "Steam API indicates this is a collection. Collection ID: $collectionId"
            } else {
                $isCollection = $false
                $itemId = $possibleId
                DebugLog "Steam API indicates this is a single item. Item ID: $itemId"
            }
        } catch {
            Write-Error "Failed to query Steam API to determine if the ID is a collection or item."
            exit 1
        }
    } else {
        Write-Error "Could not parse Workshop URL. Please provide a valid collection or item URL."
        exit 1
    }
} else {
    Write-Output "Usage:"
    Write-Output "  .\workshop.ps1 <Steam Workshop URL>"
    Write-Output "  .\workshop.ps1 -Single <itemId>"
    Write-Output "  .\workshop.ps1 -Collection <collectionId>"
    Write-Output "  .\workshop.ps1 ... -Debug"
    exit 1
}

# Detect platform
$IsWinPlatform = $false
if ($PSVersionTable.PSVersion -and $PSVersionTable.Platform) {
    $IsWinPlatform = $PSVersionTable.Platform -eq "Win32NT"
} elseif ($env:OS -eq "Windows_NT") {
    $IsWinPlatform = $true
} elseif ($env:OSTYPE -like "*win*") {
    $IsWinPlatform = $true
}

# Ensure steamcmd exists and select correct executable for platform
$RootDir = Split-Path -Parent $MyInvocation.MyCommand.Definition

if ($IsWinPlatform) {
    $SteamCmdDl = Join-Path $RootDir "steamcmd-dl.ps1"
    DebugLog "Calling steamcmd-dl.ps1: $SteamCmdDl"
    powershell -ExecutionPolicy Bypass -File $SteamCmdDl
    $steamcmd = Join-Path $RootDir "steamcmd\steamcmd.exe"
    DebugLog "Detected Windows platform."
} else {
    $SteamCmdDlSh = Join-Path $RootDir "steamcmd-dl.sh"
    DebugLog "Calling steamcmd-dl.sh: $SteamCmdDlSh"
    bash $SteamCmdDlSh
    $steamcmd = Join-Path $RootDir "steamcmd/steamcmd.sh"
    DebugLog "Detected non-Windows platform."
}
DebugLog "Looking for SteamCMD executable at: $steamcmd"

if (-not (Test-Path $steamcmd)) {
    Write-Error "steamcmd executable not found after attempting download: $steamcmd"
    exit 1
}

DebugLog "Using SteamCMD: $steamcmd"

# Set download folder for VPKs
$WorkshopDir = Join-Path $RootDir "custom_files\addons\workshop"
DebugLog "Workshop VPK target directory: $WorkshopDir"
if (-not (Test-Path $WorkshopDir)) {
    DebugLog "Creating workshop directory: $WorkshopDir"
    New-Item -Path $WorkshopDir -ItemType Directory -Force | Out-Null
}

# Prepare SteamCMD script
$appid = 550 # Left 4 Dead 2
$cmdFile = [System.IO.Path]::GetTempFileName() + ".txt"
DebugLog "SteamCMD script file: $cmdFile"

# Prepare SteamCMD login command
$loginCmd = "+login $UserName"
DebugLog "Using Steam login for user: $UserName"

if ($isCollection) {
    # Use $children from earlier if available, otherwise fetch
    if (-not $children) {
        $collectionApiUrl = "https://api.steampowered.com/ISteamRemoteStorage/GetCollectionDetails/v1/"
        $body = @{ "collectioncount" = 1; "publishedfileids[0]" = $collectionId }
        $response = Invoke-RestMethod -Uri $collectionApiUrl -Method Post -Body $body
        $children = $response.response.collectiondetails[0].children
    }
    if (-not $children) {
        Write-Error "No items found in the collection."
        exit 1
    }
    $items = $children | ForEach-Object { $_.publishedfileid }
    $cmds = @()
    foreach ($id in $items) {
        $cmds += "workshop_download_item $appid $id"
    }
    $cmds += "quit"
} else {
    $cmds = @(
        "workshop_download_item $appid $itemId"
        "quit"
    )
}
DebugLog "SteamCMD commands:`n$($cmds -join "`n")"
Set-Content -Path $cmdFile -Value $cmds
DebugLog "Running SteamCMD for collection..."
if ($IsWinPlatform) {
    & $steamcmd $loginCmd +runscript "$cmdFile"
} else {
    bash $steamcmd $loginCmd +runscript "$cmdFile"
}

DebugLog "Removing temporary SteamCMD script: $cmdFile"
Remove-Item $cmdFile -Force

# Move and convert downloaded files
$WorkshopContentDir = Join-Path $RootDir "steamcmd\steamapps\workshop\content\$appid"
if (Test-Path $WorkshopContentDir) {
    # Move .vpk files (flatten structure)
    $vpkFiles = Get-ChildItem -Path $WorkshopContentDir -Recurse -Filter *.vpk -ErrorAction SilentlyContinue
    foreach ($vpk in $vpkFiles) {
        $dest = Join-Path $WorkshopDir $vpk.Name
        DebugLog "Moving $($vpk.FullName) to $dest"
        if (-not $Keep) {
            Move-Item -Path $vpk.FullName -Destination $dest -Force
        } else {
            Copy-Item -Path $vpk.FullName -Destination $dest -Force
        }
    }

    # Convert .bin _legacy files to .vpk (flatten structure)
    $binFiles = Get-ChildItem -Path $WorkshopContentDir -Recurse -Filter *.bin -ErrorAction SilentlyContinue | Where-Object { $_.Name -like "*_legacy*" }
    foreach ($bin in $binFiles) {
        $newName = $bin.Name -replace '_legacy', ''
        $newName = [System.IO.Path]::ChangeExtension($newName, ".vpk")
        $dest = Join-Path $WorkshopDir $newName
        DebugLog "Converting $($bin.FullName) to $dest"
        if (-not $Keep) {
            Move-Item -Path $bin.FullName -Destination $dest -Force
        } else {
            Copy-Item -Path $bin.FullName -Destination $dest -Force
        }
    }
} else {
    DebugLog "Workshop content directory not found: $WorkshopContentDir"
}

Write-Output "Download(s) complete. Check '$WorkshopDir' for your addons."
