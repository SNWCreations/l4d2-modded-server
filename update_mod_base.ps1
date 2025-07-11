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
        [string]$Prefix = ""
    )
    Write-Host "Fetching release page: $PageUrl"
    $html = Invoke-WebRequest -Uri $PageUrl -UseBasicParsing
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
    } else {
        Write-Host "No match for pattern: $Pattern"
        throw "Could not find download URL on $PageUrl"
    }
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
    # Return all matches (all available builds for this platform)
    $urls = @()
    foreach ($m in $accelMatches) {
        $relUrl = $m.Groups[1].Value
        $fullUrl = if ($relUrl -match "^https?://") { $relUrl } else { $BaseUrl + $relUrl }
        $urls += $fullUrl
    }
    return $urls
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
        [string]$Url
    )
    $resolvedUrl = $Url
    try {
        $head = Invoke-WebRequest -Uri $Url -Method Head -MaximumRedirection 5 -ErrorAction Stop
        if ($head.BaseResponse -and $head.BaseResponse.ResponseUri) {
            $resolvedUrl = $head.BaseResponse.ResponseUri.AbsoluteUri
        } elseif ($head.Headers.Location) {
            $resolvedUrl = $head.Headers.Location
        }
    } catch {
        # fallback to original
    }
    return $resolvedUrl
}

function Update-Mod {
    param (
        [string]$ResolvedUrl,
        [string]$ModKey,
        [string]$OsKey = $null
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
    Invoke-WebRequest -Uri $resolvedUrl -OutFile $TempFile

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
        [string[]]$ResolvedUrls
    )
    foreach ($resolvedUrl in $ResolvedUrls) {
        if (-not $resolvedUrl) { continue }
        $TempExtract = Join-Path $TempRoot "extract_accel"
        if (Test-Path $TempExtract) { Remove-Item $TempExtract -Recurse -Force }

        # Download
        if ($resolvedUrl -match "\.zip($|\?)") {
            $ext = ".zip"
        } else {
            throw "Unknown archive format: $resolvedUrl"
        }
        $TempFile = Join-Path $TempRoot ("accel" + $ext)
        if (Test-Path $TempFile) { Remove-Item $TempFile -Force }

        Write-Host "Downloading Accelerator $resolvedUrl..."
        Invoke-WebRequest -Uri $resolvedUrl -OutFile $TempFile

        Write-Host "Extracting Accelerator to $TempExtract..."
        Expand-Archive -Path $TempFile -DestinationPath $TempExtract

        # Merge extracted addons/* into $L4D2Dir/addons
        $srcAddons = Join-Path $TempExtract "addons"
        $dstAddons = Join-Path $L4D2Dir "addons"
        if (Test-Path $srcAddons) {
            Write-Host "Copying Accelerator files to $dstAddons ..."
            Copy-Item -Path "$srcAddons\*" -Destination $dstAddons -Recurse -Force
        } else {
            Write-Host "WARNING: Accelerator archive did not contain an addons folder."
        }

        Remove-Item $TempFile -Force
        Remove-Item $TempExtract -Recurse -Force
    }
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
$accelHtml = (Invoke-WebRequest -Uri $AcceleratorPage -UseBasicParsing).Content
$accelWinUrls = Get-Accelerator-LatestUrl $accelHtml $AcceleratorWinPattern $AcceleratorBase
$accelLinuxUrls = Get-Accelerator-LatestUrl $accelHtml $AcceleratorLinuxPattern $AcceleratorBase
$script:ResolvedUrls["accelerator.win"] = $accelWinUrls
$script:ResolvedUrls["accelerator.linux"] = $accelLinuxUrls

# Get Accelerator versions for both platforms (use first url for each if array)
$accelWinVer = $null
$accelLinuxVer = $null
if ($accelWinUrls -is [array] -and $accelWinUrls.Count -gt 0) {
    $accelWinVer = Get-Accelerator-Version $accelWinUrls[0]
} elseif ($accelWinUrls) {
    $accelWinVer = Get-Accelerator-Version $accelWinUrls
}
if ($accelLinuxUrls -is [array] -and $accelLinuxUrls.Count -gt 0) {
    $accelLinuxVer = Get-Accelerator-Version $accelLinuxUrls[0]
} elseif ($accelLinuxUrls) {
    $accelLinuxVer = Get-Accelerator-Version $accelLinuxUrls
}

# Get current and latest versions
$readmePath = Join-Path $BaseDir "README.md"
$currentVersions = Get-CurrentModVersions $readmePath
$latestSM = Get-SourceMod-Version $ResolvedUrls["sourcemod.win"]
$latestMM = Get-MetaMod-Version $ResolvedUrls["metamod.win"]
$latestStripper = Get-Stripper-Version $ResolvedUrls["stripper.win"]

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
                Update-Accelerator -ResolvedUrls $ResolvedUrls["accelerator.win"]
            }
        }
        "accelerator.linux" {
            if ($ResolvedUrls["accelerator.linux"]) {
                Update-Accelerator -ResolvedUrls $ResolvedUrls["accelerator.linux"]
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
