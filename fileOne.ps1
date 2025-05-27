Function Convert-Pace {
    param(
        [int]$Minutes,

        [Parameter(Mandatory=$true)]
        [int32]$Seconds,
        
        [Parameter(Mandatory=$true)]
        [double]$Kilometers
    )
    if ($Kilometers -eq 0) {
        return "0"
    }
    
    $Seconds = (60 * $Minutes + $Seconds)
    $secPerKm = ($Seconds / $Kilometers)
    $minPerKm = [Math]::Floor($secPerKm / 60)
    $remainingSecondsPerKm = ($secPerKm / 60) % 1

    Write-Host "Pace: $minPerKm min $([Math]::Round($remainingSecondsPerKm * 60, 1)) sec per km"
}

Function Rename-Items {
    param(
        [string]$ContainerPath,
        
        [string]$NewName

    )
}




