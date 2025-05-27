<#
.SYNOPSIS
    Compare files in two folders.

.PARAMETER Folders

.PARAMETER Recurse

FT: add parameter [regEx?]$Pattern, only compare matching items
#>
function Compare-FolderContents {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string[]]$Folders,

        [switch]$Recurse
    )

    foreach ($folder in $Folders) {
        if (-not (Test-Path $folder -PathType Container)) {
            throw "Folder does not exist: $folder"
        }
    }

    $files = @()
    foreach ($folder in $Folders) {
        if ($Recurse) {
            $files += Get-ChildItem -Path $folder -File -Recurse
        } else {
            $files += Get-ChildItem -Path $folder -File
        }
    }

    $hashes = foreach ($file in $files) {
        [PSCustomObject]@{
            FullName    = $file.FullName
            Name        = $file.Name
            Folder      = $file.DirectoryName
            Hash        = ($file | Get-FileHash -Algorithm SHA1).Hash
        }
    }

    $hashesNameGroups = $hashes | Group-Object -Property Name
    $hashesHashGroups = $hashes | Group-Object -Property Hash

    $duplicateNames = $hashesNameGroups | Where-Object { $_.Count -gt 1 } | ForEach-Object { $_.Name }
    $duplicateHash = $hashesHashGroups | Where-Object { $_.Count -gt 1 } | ForEach-Object { $_.Group } | Select-Object -ExpandProperty Name


    $comparison = foreach ($item in $hashes) {
        [PSCustomObject]@{
            FullName        = $item.FullName
            Name            = $item.Name
            Folder          = $item.Folder
            Hash            = $item.Hash
            NameDuplicates  = ($duplicateNames -contains $item.Name)
            HashDuplicates  = ($duplicateHash -contains $item.Hash)
        }
    }

    return $comparison
}

function Show-FolderComparison {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Folders,

        [switch]$Recurse,

        [switch]$JustDuplicates,

        [string]$ExportCsvPath
    )

    $results = Compare-FolderContents -Folders $Folders -Recurse:$Recurse

    if ($JustDuplicates) {
        $results = $results |
            Group-Object -Property Hash |
            Where-Object { $_.Count -gt 1 } |
            Select-Object -ExpandProperty Group
    }

    $results = $results | Sort-Object HashDuplicates, Hash, Folder, Name

    if ($ExportCsvPath) {
        $results | Export-Csv -Path $ExportCsvPath -NoTypeInformation
        Write-Host "Results exported to: $ExportCsvPath" -ForegroundColor Green
    }
    
    $results | Format-Table -GroupBy Hash -Property Name, Folder, NameDuplicates
}
