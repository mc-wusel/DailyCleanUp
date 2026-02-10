# Calculate the size of data in the specified folder
function GetFolderDataSize {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Folder
  )

  try {
    $Items = Get-ChildItem -Path $Folder -Recurse -ErrorAction SilentlyContinue
    $SizeInByte = $Items | Measure-Object -Property Length -Sum
    $SizeInMB = [math]::Round($SizeInByte.Sum / 1MB, 2)
    return $SizeInMB
  }
  catch {
    return $false
  }
}

# Delete contents within the specified folder
function CleanupFolder {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Folder
  )

  try {
    if (Test-Path -Path $Folder -PathType Container) {
      Get-ChildItem $Folder  -ErrorAction Stop | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
      Start-Sleep -Milliseconds 200

    }
  }
  catch {
    return $false
  }
}

function Check_SMART_State {
  $PhysicalDisks = Get-CimInstance -ClassName Win32_DiskDrive | Select-Object Model, Status

  foreach ($Disk in $PhysicalDisks) {
    Write-Host "`tDisk: "  -NoNewline -ForegroundColor Magenta
    Write-Host $Disk.Model
    Write-Host "`tStatus: " -NoNewline -ForegroundColor Magenta
    if ($Disk.Status -eq "OK") {
      Write-Host $LblOK -ForegroundColor Green
    }
    else {
      Write-Host $LblWarning -ForegroundColor Yellow
    }
  }
}

function SystemDiskSpace {
  $SystemDrive = Get-PSDrive -Name C
  $FreeSpaceGB = [math]::Round($SystemDrive.Free / 1GB, 2)
  $UsedSpaceGB = [math]::Round(($SystemDrive.Used) / 1GB, 2)
  $TotalSpaceGB = [math]::Round(($SystemDrive.Used + $SystemDrive.Free) / 1GB, 2)

  Write-Host "`tFree Space: " -NoNewline -ForegroundColor Magenta
  if ($FreeSpaceGB -lt 10) {
    Write-Host "$FreeSpaceGB GB" -ForegroundColor Red
  }
  elseif ($FreeSpaceGB -lt 20) {
    Write-Host "$FreeSpaceGB GB" -ForegroundColor Yellow
  }
  else {
    Write-Host "$FreeSpaceGB GB" -ForegroundColor Green
  }
  Write-Host "`tUsed Space: " -NoNewline -ForegroundColor Magenta
  Write-Host "$UsedSpaceGB GB" 
  Write-Host "`tTotal Space: " -NoNewline -ForegroundColor Magenta
  Write-Host "$TotalSpaceGB GB" 
}

function CreateSystemRestorePoint {
  try {
    Checkpoint-Computer -Description "DailyCleanUp Restore Point" -RestorePointType "MODIFY_SETTINGS" -ErrorAction Stop
    return $true
  }
  catch {
    return $false
  }
}

function ClearDNSCache {
  try {
    Clear-DnsClientCache -ErrorAction Stop
    return $true
  }
  catch {
    return $false
  }
}

function RunSystemHealthRepair {
  try {
    Write-Host "`tDISM RestoreHealth running..." -NoNewLine -ForegroundColor Cyan

    $dismOutput = DISM /Online /Cleanup-Image /RestoreHealth 2>&1 | Out-String

    if ($LASTEXITCODE -ne 0) {
      Write-Host "DISM failed!" -ForegroundColor Red
      Write-Host "Output:`n$dismOutput" -ForegroundColor Red
      return $false
    }

    Write-Host "completed successfully" -ForegroundColor Green
    Write-Host "`tSFC scan running..." -NoNewLine -ForegroundColor Cyan
    
    $proc = Start-Process -FilePath "sfc.exe" `
      -ArgumentList "/scannow" `
      -WindowStyle Hidden `
      -PassThru `
      -Wait

    if ($proc.ExitCode -ne 0) {
      Write-Host " failed!" -ForegroundColor Red
      return $false
    }

    Write-Host " completed" -ForegroundColor Green
    return $true
  }
  catch {
    Write-Host "Unexpected error during system health repair!" -ForegroundColor Red
    Write-Host $_
    return $false
  }
}

function RunUpdates {
  try {
    $WinGetOutput = winget upgrade --all --include-unknown `
      --accept-source-agreements --accept-package-agreements `
      --disable-interactivity 2>&1 | Out-String
    if ($LASTEXITCODE -eq 0) {
      return $true
    }
    else {
      Write-Host "Error during updates: $WinGetOutput"
      return $false
    }
  }
  catch {
    Write-Host "Exception occurred: $_"
    return $false
  }
}