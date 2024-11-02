$OutputEncoding = [System.Text.Encoding]::UTF8

$ConfigFile = "$PSScriptroot\config.json"
$Config = Get-Content -Path $ConfigFile | ConvertFrom-Json

$LblOK = "OK"
$LblYes = "Yes"
$LblNo = "No"
$LblNoPermission = "no permission"
$LblNotAvailable = "not available"

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

Clear-Host

#region folders whose content will be deleted
Write-Host "Systemfolder cleanup check... " -nonewline -ForegroundColor magenta
if ($Config.Folder.Check -eq $true) {
  Write-Host $LblYes -ForegroundColor green

  $CleanupFolders = @(
    $env:TEMP,
    "$env:SystemDrive\Windows\Temp",
    "$env:SystemDrive\Windows\Prefetch",
    "$env:SystemDrive\Windows\Logs\CBS",
    "$env:SystemDrive\Windows\SoftwareDistribution\Download\"
  )

  if ($Config.Folder.AdditionalFolders.Count -gt 0) {
    $CleanupFolders += $Config.Folder.AdditionalFolders
  }

  foreach ($Folder in $CleanupFolders) {
    Write-Host "`tFolder: " -NoNewline -ForegroundColor Magenta
    # check Folder
    Write-Host $Folder
    if (Test-Path -Path $Folder -PathType Container) {
      Write-Host "`tSize: " -NoNewline -ForegroundColor Magenta

      $FolderSize = GetFolderDataSize -Folder $Folder

      if ($FolderSize -ne $false) {
        Write-Host "$(GetFolderDataSize -Folder $Folder) MB" -ForegroundColor Yellow
      }
      else {
        Write-Host $LblNoPermission -ForegroundColor Red
      }
    }
    else {
      Write-Host "`tStatus... " -NoNewline -ForegroundColor Magenta
      Write-Host $LblNotAvailable -ForegroundColor Red
    }
  }
}
else {
  Write-Host $LblNo -ForegroundColor red
}

Write-Host "Systemfolder cleanup desired... " -NoNewline -ForegroundColor Magenta

if ($config.Folder.Delete -eq $true) {
  Write-Host $LblYes -ForegroundColor Green
  foreach ($Folder in $CleanupFolders) {
    Write-Host "`t`tDelete Folder: " -NoNewline -ForegroundColor Magenta
    Write-Host $Folder
    Write-Host "`t`tStatus... " -NoNewline -ForegroundColor Magenta

    $State = CleanupFolder -Folder $Folder
    if ($State -ne $false) {
      Write-Host $LblOK -ForegroundColor Green
    }
    else {
      Write-Host $LblNoPermission -ForegroundColor Red
    }
  }
}
else {
  Write-Host $LblNo -ForegroundColor Red
}