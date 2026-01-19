# Update SourceMod, MetaMod: Source, and Stripper, then commit changes

$ErrorActionPreference = "Stop"

# Prepare temp folder for downloads and extraction
$TempRoot = Join-Path $PSScriptRoot "temp"
if (-not (Test-Path $TempRoot)) { New-Item -ItemType Directory -Path $TempRoot | Out-Null }

# Cleanup function to remove temp files and exit with code
function Remove-TempAndExit {
    param (
        [int]$exitCode = 0
    )
    Write-Host "Cleaning up temporary files..."
    if (Test-Path $TempRoot) {
        Remove-Item $TempRoot -Recurse -Force
    }
    exit $exitCode
}

# SourceMod direct API URLs
$SourceModWinUrl   = "https://sourcemod.net/latest.php?os=windows&version=1.12"
$SourceModLinuxUrl = "https://sourcemod.net/latest.php?os=linux&version=1.12"

# MetaMod:Source direct API URLs
$MetaModWinUrl   = "https://metamodsource.net/latest.php?os=windows&version=2.0"
$MetaModLinuxUrl = "https://metamodsource.net/latest.php?os=linux&version=2.0"

# Stripper (parse Apache directory listing, match all git builds, pick latest by version and build)
$StripperSnapshotPage = "https://www.bailopan.net/stripper/snapshots/1.2/"
$StripperWinPattern = 'href="(stripper-(\d+\.\d+\.\d+)-git(\d+)-windows\.zip)"'
$StripperLinuxPattern = 'href="(stripper-(\d+\.\d+\.\d+)-git(\d+)-linux\.tar\.gz)"'
function Get-LatestReleaseUrlRegex {
    param (
        [string]$PageUrl,
        [string]$Pattern,
        [string]$Prefix = "",
        [int]$MaxRetries = 3,
        [int]$RetryDelaySeconds = 2
    )
    for ($attempt = 1; $attempt -le $MaxRetries; $attempt++) {
        try {
            Write-Host "Fetching release page: $PageUrl (attempt $attempt)"
            $html = Invoke-WebRequest -Uri $PageUrl -UseBasicParsing -TimeoutSec 30
            $releaseMatches = [regex]::Matches($html.Content, $Pattern)
            Write-Host "Found $($releaseMatches.Count) matches"
            if ($releaseMatches.Count -gt 0) {
                # Sort matches by version and git build number
                $matchesWithBuild = $releaseMatches | ForEach-Object {
                    $match = $_
                    $url = $match.Groups[1].Value
                    $ver = $match.Groups[2].Value
                    $build = [int]$match.Groups[3].Value
                    # Convert version to array of ints for sorting
                    $verArr = $ver -split '\.' | ForEach-Object { [int]$versionPart = $_; $versionPart }
                    [PSCustomObject]@{
                        Url = $url
                        Version = $ver
                        VersionArr = $verArr
                        Build = $build
                    }
                }
                $latest = $matchesWithBuild | Sort-Object -Property @{Expression = { $_.VersionArr }; Descending = $true}, @{Expression = { $_.Build }; Descending = $true} | Select-Object -First 1
                $url = $latest.Url
                if ($Prefix -and $url -notmatch "^https?://") {
                    $url = $Prefix + $url
                }
                Write-Host "Selected URL: $url (version $($latest.Version), git build $($latest.Build))"
                return $url
            }
        } catch {
            Write-Host "Attempt $attempt failed: $($_.Exception.Message)"
            if ($attempt -lt $MaxRetries) {
                Write-Host "Waiting $RetryDelaySeconds seconds before retry..."
                Start-Sleep -Seconds $RetryDelaySeconds
            }
        }
    }
    Write-Host "No match for pattern: $Pattern"
    throw "Could not find download URL on $PageUrl after $MaxRetries attempts"
}
$StripperWinUrl = Get-LatestReleaseUrlRegex -PageUrl $StripperSnapshotPage -Pattern $StripperWinPattern -Prefix $StripperSnapshotPage
$StripperLinuxUrl = Get-LatestReleaseUrlRegex -PageUrl $StripperSnapshotPage -Pattern $StripperLinuxPattern -Prefix $StripperSnapshotPage

# Accelerator download page and patterns
$AcceleratorBase = "https://builds.limetech.io/"
$AcceleratorPage = "${AcceleratorBase}?p=accelerator"
$AcceleratorWinPattern = '<a href="(files/accelerator-[^"]+-windows\.zip)">'
$AcceleratorLinuxPattern = '<a href="(files/accelerator-[^"]+-linux\.zip)">'

function Get-Accelerator-LatestUrl {
    param([string]$HtmlContent, [string]$Pattern, [string]$BaseUrl)
    $accelMatches = [regex]::Matches($HtmlContent, $Pattern)
    if ($accelMatches.Count -eq 0) {
        Write-Host "WARNING: No Accelerator build found for this platform."
        return $null
    }
    # Sort matches by version and git build number to pick the latest
    $matchesWithBuild = $accelMatches | ForEach-Object {
        $match = $_
        $url = $match.Groups[1].Value
        $fullUrl = if ($url -match "^https?://") { $url } else { $BaseUrl + $url }
        # Extract version: accelerator-x.y.z-gitNNN-hash-platform.zip
        $versionPattern = 'accelerator-([0-9]+\.[0-9]+\.[0-9]+)-git([0-9]+)-([a-f0-9]+)-'
        if ($fullUrl -match $versionPattern) {
            $ver = $Matches[1]
            $build = [int]$Matches[2]
            $hash = $Matches[3]
            # Convert version to array of ints for sorting
            $verArr = $ver -split '\.' | ForEach-Object { [int]$_ }
            [PSCustomObject]@{
                Url = $fullUrl
                Version = $ver
                VersionArr = $verArr
                Build = $build
                Hash = $hash
            }
        } else {
            # If no match, put at end
            [PSCustomObject]@{
                Url = $fullUrl
                Version = "0.0.0"
                VersionArr = @(0,0,0)
                Build = 0
                Hash = ""
            }
        }
    }
    $latest = $matchesWithBuild | Sort-Object -Property @{Expression = { $_.VersionArr }; Descending = $true}, @{Expression = { $_.Build }; Descending = $true} | Select-Object -First 1
    Write-Host "Selected Accelerator URL: $($latest.Url) (version $($latest.Version), git build $($latest.Build))"
    return $latest.Url
}

# Target directories (relative to script location)
$BaseDir = $PSScriptRoot
$L4D2Dir = Join-Path $BaseDir "left4dead2"

# Download and extract, capturing resolved URLs for version extraction
if (-not $script:ResolvedUrls) {
    $script:ResolvedUrls = @{
    }
}

function Resolve-DownloadUrl {
    param (
        [string]$Url,
        [int]$MaxRetries = 3,
        [int]$RetryDelaySeconds = 2
    )
    $resolvedUrl = $Url
    for ($attempt = 1; $attempt -le $MaxRetries; $attempt++) {
        try {
            Write-Host "Resolving URL (attempt $attempt): $Url"
            # Try HEAD request first to follow redirects
            $head = Invoke-WebRequest -Uri $Url -Method Head -MaximumRedirection 10 -TimeoutSec 30 -ErrorAction Stop
            if ($head.BaseResponse -and $head.BaseResponse.ResponseUri) {
                $resolvedUrl = $head.BaseResponse.ResponseUri.AbsoluteUri
                Write-Host "HEAD resolved to: $resolvedUrl"
                break
            } elseif ($head.Headers.Location) {
                $resolvedUrl = $head.Headers.Location
                Write-Host "HEAD location header: $resolvedUrl"
                break
            }
        } catch {
            Write-Host "HEAD request attempt $attempt failed: $($_.Exception.Message)"
            # Try GET request as fallback
            try {
                Write-Host "Trying GET request as fallback..."
                $get = Invoke-WebRequest -Uri $Url -Method Get -MaximumRedirection 10 -TimeoutSec 30 -ErrorAction Stop
                if ($get.BaseResponse -and $get.BaseResponse.ResponseUri) {
                    $resolvedUrl = $get.BaseResponse.ResponseUri.AbsoluteUri
                    Write-Host "GET resolved to: $resolvedUrl"
                    break
                }
            } catch {
                Write-Host "GET request fallback also failed: $($_.Exception.Message)"
            }

            if ($attempt -lt $MaxRetries) {
                Write-Host "Waiting $RetryDelaySeconds seconds before retry..."
                Start-Sleep -Seconds $RetryDelaySeconds
            } else {
                Write-Host "Using original URL after all attempts failed"
            }
        }
    }
    return $resolvedUrl
}

function Update-Mod {
    param (
        [string]$ResolvedUrl,
        [string]$ModKey,
        [string]$OsKey = $null,
        [int]$MaxRetries = 3,
        [int]$RetryDelaySeconds = 5
    )
    $TempExtract = Join-Path $TempRoot "extract"
    if (Test-Path $TempExtract) { Remove-Item $TempExtract -Recurse -Force }

    $resolvedUrl = $ResolvedUrl

    # Use correct extension for temp file based on resolved URL
    if ($resolvedUrl -match "\.zip($|\?)") {
        $ext = ".zip"
    } elseif ($resolvedUrl -match "\.tar\.gz($|\?)") {
        $ext = ".tar.gz"
    } else {
        throw "Unknown archive format: $resolvedUrl"
    }
    $TempFile = Join-Path $TempRoot ("mod" + $ext)
    if (Test-Path $TempFile) { Remove-Item $TempFile -Force }

    Write-Host "Downloading $resolvedUrl..."

    # Download with retry logic
    $downloadSuccess = $false
    for ($attempt = 1; $attempt -le $MaxRetries; $attempt++) {
        try {
            Write-Host "  Download attempt $attempt of $MaxRetries..."
            Invoke-WebRequest -Uri $resolvedUrl -OutFile $TempFile -TimeoutSec 60
            $downloadSuccess = $true
            Write-Host "  Download successful on attempt $attempt"
            break
        } catch {
            Write-Host "  Attempt $attempt failed: $($_.Exception.Message)"
            if ($attempt -lt $MaxRetries) {
                Write-Host "  Waiting $RetryDelaySeconds seconds before retry..."
                Start-Sleep -Seconds $RetryDelaySeconds
            }
        }
    }

    if (-not $downloadSuccess) {
        throw "Failed to download $ModKey from $resolvedUrl after $MaxRetries attempts"
    }

    Write-Host "Extracting to $TempExtract..."
    if ($ext -eq ".zip") {
        Expand-Archive -Path $TempFile -DestinationPath $TempExtract
    } elseif ($ext -eq ".tar.gz") {
        if (-not (Test-Path $TempExtract)) { New-Item -ItemType Directory -Path $TempExtract | Out-Null }
        tar -xzf $TempFile -C $TempExtract
    }

    # Special handling for MetaMod's metamod_x64.vdf: rename to .win.vdf or .linux.vdf in addons dir after extract
    $isMetaMod = $ModKey -eq "metamod" -or ($resolvedUrl -match "metamod")
    if ($isMetaMod) {
        $mmVdfExtracted = Get-ChildItem -Path $TempExtract -Recurse -Filter "metamod_x64.vdf" | Where-Object { $_.PSIsContainer -eq $false }
        foreach ($vdf in $mmVdfExtracted) {
            $addonsDir = $vdf.Directory.FullName
            if ($resolvedUrl -match "windows") {
                Move-Item -Force $vdf.FullName (Join-Path $addonsDir "metamod_x64.win.vdf")
            } elseif ($resolvedUrl -match "linux") {
                Move-Item -Force $vdf.FullName (Join-Path $addonsDir "metamod_x64.linux.vdf")
            }
        }
    }

    # Move all contents from $TempExtract (not just top-level) to $L4D2Dir (preserving structure)
    Write-Host "Copying extracted files to $L4D2Dir ..."
    Get-ChildItem $TempExtract -Recurse -File | ForEach-Object {
        # For MetaMod, skip copying any metamod_x64.vdf (already renamed above)
        if ($isMetaMod -and $_.Name -eq "metamod_x64.vdf") { return }
        $relativePath = $_.FullName.Substring($TempExtract.Length).TrimStart('\','/')
        $destPath = Join-Path $L4D2Dir $relativePath
        $destDir = Split-Path $destPath -Parent
        if (-not (Test-Path $destDir)) { New-Item -ItemType Directory -Path $destDir -Force | Out-Null }
        Copy-Item -Path $_.FullName -Destination $destPath -Force
    }
    Get-ChildItem $TempExtract -Recurse -Directory | Sort-Object FullName -Descending | ForEach-Object {
        # Ensure empty directories are created if needed
        $relativePath = $_.FullName.Substring($TempExtract.Length).TrimStart('\','/')
        $destPath = Join-Path $L4D2Dir $relativePath
        if (-not (Test-Path $destPath)) { New-Item -ItemType Directory -Path $destPath -Force | Out-Null }
    }

    Remove-Item $TempFile -Force
    Remove-Item $TempExtract -Recurse -Force
}

# Helper to update mod versions in README.md
function Update-ReadmeModVersions {
    param (
        [string]$ReadmePath,
        [string]$SourceModVersion,
        [string]$MetaModVersion,
        [string]$StripperVersion,
        [string]$AcceleratorWinVersion,
        [string]$AcceleratorLinuxVersion
    )
    Write-Host "Updating README.md mod versions..."

    $lines = Get-Content $ReadmePath

    # Compose Accelerator version string for README
    $accelVerStr = ""
    if ($AcceleratorWinVersion -and $AcceleratorLinuxVersion) {
        if ($AcceleratorWinVersion -eq $AcceleratorLinuxVersion) {
            $accelVerStr = "$AcceleratorWinVersion (Windows/Linux)"
        } else {
            $accelVerStr = "$AcceleratorWinVersion (Windows), $AcceleratorLinuxVersion (Linux)"
        }
    } elseif ($AcceleratorWinVersion) {
        $accelVerStr = "$AcceleratorWinVersion (Windows)"
    } elseif ($AcceleratorLinuxVersion) {
        $accelVerStr = "$AcceleratorLinuxVersion (Linux)"
    }

    # Helper to update a line in the table
    function Update-ModLine {
        param($line, $modName, $newVersion)
        if ($line -match "^\|\s*$modName\s*\|") {
            # Replace the version (2nd column) but keep table formatting
            $cols = $line -split '\|'
            if ($cols.Count -ge 3) {
                $cols[2] = " $newVersion "
                return ($cols -join '|')
            }
        }
        return $line
    }

    $lines = $lines | ForEach-Object {
        $line = $_
        $line = Update-ModLine $line "SourceMod" $SourceModVersion
        $line = Update-ModLine $line "MetaMod:Source" $MetaModVersion
        $line = Update-ModLine $line "Stripper: Source" $StripperVersion
        $line = Update-ModLine $line "Accelerator" $accelVerStr
        $line
    }

    Set-Content -Path $ReadmePath -Value $lines -Encoding UTF8
    Write-Host "README.md updated."
}

# Helper to extract version from a file path or URL (generic)
function Get-Version {
    param([string]$url, [string]$prefix)
    # Match: prefix-x.y.z-gitNNNN-
    $pattern = "$prefix-([0-9]+\.[0-9]+\.[0-9]+-git[0-9]+)-"
    if ($url -match $pattern) {
        return $Matches[1]
    }
    throw "Failed to extract $prefix version from string: $url"
}

function Get-SourceMod-Version {
    param([string]$url)
    return Get-Version $url "sourcemod"
}
function Get-MetaMod-Version {
    param([string]$url)
    return Get-Version $url "mmsource"
}
function Get-Stripper-Version {
    param([string]$url)
    return Get-Version $url "stripper"
}
function Get-Accelerator-Version {
    param([string]$url)
    if (-not $url) { return $null }
    $pattern = 'accelerator-([0-9]+\.[0-9]+\.[0-9]+-git[0-9]+-[a-f0-9]+)-'
    if ($url -match $pattern) {
        return $Matches[1]
    }
    throw "Failed to extract Accelerator version from string: $url"
}

function Update-Accelerator {
    param (
        [string]$ResolvedUrl,
        [int]$MaxRetries = 3,
        [int]$RetryDelaySeconds = 5
    )
    if (-not $ResolvedUrl) { return }
    $TempExtract = Join-Path $TempRoot "extract_accel"
    if (Test-Path $TempExtract) { Remove-Item $TempExtract -Recurse -Force }

    # Download
    if ($ResolvedUrl -match "\.zip($|\?)") {
        $ext = ".zip"
    } else {
        throw "Unknown archive format: $ResolvedUrl"
    }
    $TempFile = Join-Path $TempRoot ("accel" + $ext)
    if (Test-Path $TempFile) { Remove-Item $TempFile -Force }

    Write-Host "Downloading Accelerator $ResolvedUrl..."

    # Download with retry logic
    $downloadSuccess = $false
    for ($attempt = 1; $attempt -le $MaxRetries; $attempt++) {
        try {
            Write-Host "  Download attempt $attempt of $MaxRetries..."
            Invoke-WebRequest -Uri $ResolvedUrl -OutFile $TempFile -TimeoutSec 60
            $downloadSuccess = $true
            Write-Host "  Download successful on attempt $attempt"
            break
        } catch {
            Write-Host "  Attempt $attempt failed: $($_.Exception.Message)"
            if ($attempt -lt $MaxRetries) {
                Write-Host "  Waiting $RetryDelaySeconds seconds before retry..."
                Start-Sleep -Seconds $RetryDelaySeconds
            }
        }
    }

    if (-not $downloadSuccess) {
        throw "Failed to download Accelerator from $ResolvedUrl after $MaxRetries attempts"
    }

    Write-Host "Extracting Accelerator to $TempExtract..."
    Expand-Archive -Path $TempFile -DestinationPath $TempExtract

    # Determine the OS subfolder based on the URL
    $osFolder = if ($ResolvedUrl -match "windows") { "windows" } elseif ($ResolvedUrl -match "linux") { "linux" } else { $null }

    # Check for addons folder: first try OS-specific, then direct
    $srcAddons = $null
    if ($osFolder -and (Test-Path (Join-Path $TempExtract "$osFolder\addons"))) {
        $srcAddons = Join-Path $TempExtract "$osFolder\addons"
    } elseif (Test-Path (Join-Path $TempExtract "addons")) {
        $srcAddons = Join-Path $TempExtract "addons"
    }

    $dstAddons = Join-Path $L4D2Dir "addons"
    if ($srcAddons) {
        Write-Host "Copying Accelerator files to $dstAddons ..."
        Copy-Item -Path "$srcAddons\*" -Destination $dstAddons -Recurse -Force
    } else {
        Write-Host "WARNING: Accelerator archive did not contain an addons folder."
    }

    Remove-Item $TempFile -Force
    Remove-Item $TempExtract -Recurse -Force
}

# Helper to read current versions from README.md
function Get-CurrentModVersions {
    param([string]$ReadmePath)
    $result = @{
        SourceMod = $null
        MetaMod = $null
        Stripper = $null
        AcceleratorWin = $null
        AcceleratorLinux = $null
    }
    if (-not (Test-Path $ReadmePath)) { return $result }
    $lines = Get-Content $ReadmePath
    foreach ($line in $lines) {
        if ($line -match '^\|\s*SourceMod\s*\|\s*([^\|]+)\|') {
            $result.SourceMod = $Matches[1].Trim()
        }
        if ($line -match '^\|\s*MetaMod:Source\s*\|\s*([^\|]+)\|') {
            $result.MetaMod = $Matches[1].Trim()
        }
        if ($line -match '^\|\s*Stripper: Source\s*\|\s*([^\|]+)\|') {
            $result.Stripper = $Matches[1].Trim()
        }
        if ($line -match '^\|\s*Accelerator\s*\|\s*([^\|]+)\|') {
            # Extract Windows and Linux versions separately
            $ver = $Matches[1]
            $win = $null; $linux = $null
            if ($ver -match '([0-9]+\.[0-9]+\.[0-9]+-git[0-9]+-[a-f0-9]+)\s*\(Windows\)') { $win = $Matches[1] }
            if ($ver -match '([0-9]+\.[0-9]+\.[0-9]+-git[0-9]+-[a-f0-9]+)\s*\(Linux\)') { $linux = $Matches[1] }
            if ($ver -match '([0-9]+\.[0-9]+\.[0-9]+-git[0-9]+-[a-f0-9]+)\s*\(Windows/Linux\)') {
                $win = $Matches[1]; $linux = $Matches[1]
            }
            $result.AcceleratorWin = $win
            $result.AcceleratorLinux = $linux
        }
    }
    return $result
}

# Resolve all download URLs first and store them
$script:ResolvedUrls["sourcemod.win"]   = Resolve-DownloadUrl $SourceModWinUrl
$script:ResolvedUrls["sourcemod.linux"] = Resolve-DownloadUrl $SourceModLinuxUrl
$script:ResolvedUrls["metamod.win"]     = Resolve-DownloadUrl $MetaModWinUrl
$script:ResolvedUrls["metamod.linux"]   = Resolve-DownloadUrl $MetaModLinuxUrl
$script:ResolvedUrls["stripper.win"]    = Resolve-DownloadUrl $StripperWinUrl
$script:ResolvedUrls["stripper.linux"]  = Resolve-DownloadUrl $StripperLinuxUrl

# Accelerator: fetch HTML once and extract both win/linux builds
$accelHtml = $null
for ($attempt = 1; $attempt -le 3; $attempt++) {
    try {
        Write-Host "Fetching Accelerator page (attempt $attempt)..."
        $accelHtml = (Invoke-WebRequest -Uri $AcceleratorPage -UseBasicParsing -TimeoutSec 30).Content
        break
    } catch {
        Write-Host "Accelerator page fetch attempt $attempt failed: $($_.Exception.Message)"
        if ($attempt -lt 3) {
            Start-Sleep -Seconds 2
        }
    }
}
if (-not $accelHtml) {
    throw "Failed to fetch Accelerator page after 3 attempts"
}
$accelWinUrls = Get-Accelerator-LatestUrl $accelHtml $AcceleratorWinPattern $AcceleratorBase
$accelLinuxUrls = Get-Accelerator-LatestUrl $accelHtml $AcceleratorLinuxPattern $AcceleratorBase
$script:ResolvedUrls["accelerator.win"] = $accelWinUrls
$script:ResolvedUrls["accelerator.linux"] = $accelLinuxUrls

# Get Accelerator versions for both platforms
$accelWinVer = if ($script:ResolvedUrls["accelerator.win"]) { Get-Accelerator-Version $script:ResolvedUrls["accelerator.win"] } else { $null }
$accelLinuxVer = if ($script:ResolvedUrls["accelerator.linux"]) { Get-Accelerator-Version $script:ResolvedUrls["accelerator.linux"] } else { $null }

# Get current and latest versions
$readmePath = Join-Path $BaseDir "README.md"
$currentVersions = Get-CurrentModVersions $readmePath
$latestSM = Get-SourceMod-Version $script:ResolvedUrls["sourcemod.win"]
$latestMM = Get-MetaMod-Version $script:ResolvedUrls["metamod.win"]
$latestStripper = Get-Stripper-Version $script:ResolvedUrls["stripper.win"]

# Output local and remote versions for each mod
Write-Host "SourceMod: local version = $($currentVersions.SourceMod), remote version = $latestSM"
Write-Host "MetaMod:  local version = $($currentVersions.MetaMod),  remote version = $latestMM"
Write-Host "Stripper: local version = $($currentVersions.Stripper), remote version = $latestStripper"
Write-Host "Accelerator: local version (Windows) = $($currentVersions.AcceleratorWin), remote version (Windows) = $accelWinVer"
Write-Host "Accelerator: local version (Linux) = $($currentVersions.AcceleratorLinux), remote version (Linux) = $accelLinuxVer"

# Track which mods are updated
$modsToUpdate = @()
if ($currentVersions.SourceMod -ne $latestSM) { $modsToUpdate += "sourcemod" }
if ($currentVersions.MetaMod -ne $latestMM) { $modsToUpdate += "metamod" }
if ($currentVersions.Stripper -ne $latestStripper) { $modsToUpdate += "stripper" }
if ($accelWinVer -and $currentVersions.AcceleratorWin -ne $accelWinVer) { $modsToUpdate += "accelerator.win" }
if ($accelLinuxVer -and $currentVersions.AcceleratorLinux -ne $accelLinuxVer) { $modsToUpdate += "accelerator.linux" }

# Only update mods that are outdated
if ($modsToUpdate.Count -eq 0) {
    Write-Host "All mods are up to date. No update needed."
    Remove-TempAndExit 0
}

# Update only outdated mods
foreach ($mod in $modsToUpdate) {
    switch ($mod) {
        "sourcemod" {
            Update-Mod -ResolvedUrl $ResolvedUrls["sourcemod.win"] -ModKey "sourcemod" -OsKey "win"
            Update-Mod -ResolvedUrl $ResolvedUrls["sourcemod.linux"] -ModKey "sourcemod" -OsKey "linux"
        }
        "metamod" {
            Update-Mod -ResolvedUrl $ResolvedUrls["metamod.win"] -ModKey "metamod" -OsKey "win"
            Update-Mod -ResolvedUrl $ResolvedUrls["metamod.linux"] -ModKey "metamod" -OsKey "linux"
        }
        "stripper" {
            Update-Mod -ResolvedUrl $ResolvedUrls["stripper.win"] -ModKey "stripper" -OsKey "win"
            Update-Mod -ResolvedUrl $ResolvedUrls["stripper.linux"] -ModKey "stripper" -OsKey "linux"
        }
        "accelerator.win" {
            if ($ResolvedUrls["accelerator.win"]) {
                Update-Accelerator -ResolvedUrl $ResolvedUrls["accelerator.win"]
            }
        }
        "accelerator.linux" {
            if ($ResolvedUrls["accelerator.linux"]) {
                Update-Accelerator -ResolvedUrl $ResolvedUrls["accelerator.linux"]
            }
        }
    }
}

# Update README.md mod versions before commit
$newSM = $currentVersions.SourceMod
$newMM = $currentVersions.MetaMod
$newStripper = $currentVersions.Stripper
$newAccelWin = $currentVersions.AcceleratorWin
$newAccelLinux = $currentVersions.AcceleratorLinux
if ($modsToUpdate -contains "sourcemod") { $newSM = $latestSM }
if ($modsToUpdate -contains "metamod") { $newMM = $latestMM }
if ($modsToUpdate -contains "stripper") { $newStripper = $latestStripper }
if ($modsToUpdate -contains "accelerator.win") { $newAccelWin = $accelWinVer }
if ($modsToUpdate -contains "accelerator.linux") { $newAccelLinux = $accelLinuxVer }
Update-ReadmeModVersions -ReadmePath $readmePath -SourceModVersion $newSM -MetaModVersion $newMM -StripperVersion $newStripper -AcceleratorWinVersion $newAccelWin -AcceleratorLinuxVersion $newAccelLinux

# Git add and commit
git add .\left4dead2\addons\*
git add $readmePath

# Build commit message with only updated mods
$commitParts = @()
if ($modsToUpdate -contains "sourcemod") { $commitParts += "SourceMod to $latestSM" }
if ($modsToUpdate -contains "metamod") { $commitParts += "MetaMod: Source to $latestMM" }
if ($modsToUpdate -contains "stripper") { $commitParts += "Stripper: Source to $latestStripper" }
if ($modsToUpdate -contains "accelerator.win") { $commitParts += "Accelerator (Windows) to $accelWinVer" }
if ($modsToUpdate -contains "accelerator.linux") { $commitParts += "Accelerator (Linux) to $accelLinuxVer" }
$CommitMessage = "update: " + ($commitParts -join ", ")
git commit -m $CommitMessage

Write-Host "Update complete and committed."
