function Find-AppManifest {
    param (
        [Parameter(Mandatory)]
        [string]$Game,

        [Parameter(Mandatory)]
        [string[]]$Libraries
    )

    foreach ($path in $libraries) {

        if (-not (Test-Path $path)) {
            continue
        }

        $manifestFiles = (Get-ChildItem -Path $path -Filter "appmanifest_*.acf" -File -Recurse)

        foreach ($manifest in $manifestFiles) {

            #$content = (Get-Content $manifest.FullName -TotalCount 8)[-1]
            $content = (Get-Content $manifest.FullName -TotalCount 12)

            foreach ($line in $content) {

                if ($line -match "installdir" -and
                    $line -like "*`"$game`"*") {

                    return [PSCustomObject]@{
                        Game                = $game
                        ManifestName        = $manifest.Name
                        ManifestFullName    = $manifest.FullName
                        Library             = $manifest.Directory.FullName.Replace("steamapps","")
                    }
                }
            }
        }
    }

    return $null
}
function Get-SteamLibraries {
    $steamDir = (Get-ItemProperty -Path "HKCU:\Software\Valve\Steam").SteamPath
    $vdfPath = Join-Path -Path $steamDir -ChildPath "steamapps\libraryfolders.vdf"
    $content = Get-Content $vdfPath

    $libraries = foreach($line in $content) {
        if ($line -like '*"path"*') {
            $path = $line.Replace("path", "").Replace('"', '').Replace('\\', '\').Trim()
            if (Test-Path $path) {
                $path
            }
        }
    }

    return $libraries
}
function Get-SteamGames {
    param (
        [string[]]$gameFolders
    )

    #return Get-ChildItem -Path $gameFolders -Directory | Select-Object -ExpandProperty Name
    Get-ChildItem -Path $gameFolders -Directory | ForEach-Object {
        [PSCustomObject]@{
            Name      = $_.Name
            FullName  = $_.FullName
            Library   = ($_.Parent.FullName).Replace("steamapps\common", "")
            Directory = $_.Parent.FullName
        }
    }
}
function Stop-ProcessAndWait {
    param (
        [Parameter(Mandatory)]
        [System.Diagnostics.Process]$Process,

        [int]$TimeoutInSeconds = 15
    )

    if (-not $process) {
        return $true;
    }

    try {
        if ($Process.HasExited) {
            return $true
        }
        $Process | Stop-Process -ErrorAction Stop
        $Process.Refresh()
        $null = $Process.WaitForExit($TimeoutInSeconds * 1000)

        return $Process.HasExited
    }
    catch {
        try {
            return $Process.HasExited
        }
        catch {
            return $true
        }
    }
}
function Resolve-NormalizedPath {
    param([string]$Path)

    [System.IO.Path]::GetFullPath($Path).TrimEnd('\').ToLower()
}
<#
.SYNOPSIS
Move Steam Games from one Steam-Library to another.

.DESCRIPTION
Discovers all Steam Libraries, lets the user choose one of the games therein and a Library to move the game to.
Then moves the game-files and the appmanifest_*.vdf-file to the selected Steam-Library.

.EXAMPLE
Move-SteamGame

.NOTES
No idea if this works on network drives, but why would you install a game there.

#>
function Move-SteamGame {
    $libraries = Get-SteamLibraries
    $gameFolders = Join-Path -Path $libraries -ChildPath "steamapps\common"
    $games = Get-SteamGames -gameFolders $gameFolders

    # SELECT THE GAME
    $selected = $games | Out-GridView -Title "Select the game to move" -OutputMode Single
    if (-not $selected) {
        Write-Host "Cancelled selection"
        return
    }

    # FIND MANIFEST-FILE
    $appManifest = Find-AppManifest -Game $selected.Name -Libraries $libraries
    if (-not $appManifest) {
        Write-Host "Could not find appManifest for $($selected.Name). Maybe the game got uninstalled?"
        return
    }
    $selectedGameLibrary = Resolve-NormalizedPath -Path $selected.Library
    $appManifestLibrary = Resolve-NormalizedPath -Path $appManifest.Library
    if ($selectedGameLibrary -ne $appManifestLibrary) {
        throw "Manifest File and Game Files are in different directories"
    }

    # SELECT THE DESTINATION LIBRARY
    $targetLibrary = $libraries | Out-GridView -Title "Select the destination library" -OutputMode Single
    $targetLibrary = Resolve-NormalizedPath -Path $targetLibrary
    if (-not $targetLibrary) {
        Write-Host "Cancelled selection"
        return
    }
    if ($targetLibrary -eq $selectedGameLibrary) {
        Write-Host "Game '$($selected.Name)' is already in library '$targetLibrary'."
        return
    }
    $destinationManifestFolder = Join-Path $targetLibrary "steamapps"
    $destinationGameFolder = Join-Path $destinationManifestFolder "common\$($selected.Name)"

    # EXIT STEAM
    $steamProcess = Get-Process -Name steam -ErrorAction SilentlyContinue
    if ($steamProcess) {

        $confirm = $Host.UI.PromptForChoice(
            "Confirm",
            "Stop process '$($steamProcess.Name)' (PID $($steamProcess.Id))?",
            @("&Yes", "&No", "&Cancel"),
            2
        )

        if ($confirm -eq 0) {
            #Write-Host "STOPPING STEAM IS DISABLED WHILE DEVELOPING"
            Stop-ProcessAndWait -Process $steamProcess -TimeoutInSeconds 45
        } elseif ($confirm -eq 1) {
            Write-Host "Cancelled. Try Again when Steam can be closed."
            return
        }
    }

    # MOVE THE GAME FOLDER & MANIFEST-FILE
    robocopy $selected.FullName $destinationGameFolder /move /e /ETA /FP /BYTES
    Move-Item -Path $appManifest.ManifestFullName -Destination $destinationManifestFolder
}

Move-SteamGame 


