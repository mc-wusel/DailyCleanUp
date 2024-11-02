<#
.SYNOPSIS
This script performs a cleanup operation on system and temporary folders by deleting contents and checking the data size of specified directories.

.DESCRIPTION
The script is designed to manage system folder cleanup by checking the contents of specific directories, calculating their size, and optionally deleting their contents based on settings in a configuration file (`config.json`).

It performs the following steps:
1. **Check System Folders** - Checks for the existence of designated folders (e.g., temporary folders) and calculates the total size of data within each. The result is displayed in megabytes (MB).
2. **Delete Folder Contents** - If configured, the script will delete the contents of specified folders, such as the Windows Temp, Prefetch, and CBS Logs folders. Additional folders to clean can be specified in the `config.json` file.
3. **Configuration** - The script reads settings from `config.json`, which dictates whether to check and/or delete folder contents.
4. **Error Handling** - In cases where access is restricted, or a folder doesn't exist, the script gracefully handles the error and provides a "no permission" or "not available" message.

The script includes helper functions:
- `GetFolderDataSize`: Calculates the size of data in the specified folder.
- `CleanupFolder`: Deletes contents within the specified folder.

.PARAMETERS
- None directly required by the script itself; parameters are managed through `config.json` for setting up paths and enabling/disabling actions.

.NOTES
Requires PowerShell and permission to access and delete folder contents.

#>

$OutputEncoding = [System.Text.Encoding]::UTF8

$ConfigFile = "$PSScriptroot\config.json"
$Config = Get-Content -Path $ConfigFile | ConvertFrom-Json

$LblOK = "OK"
$LblYes = "Yes"
$LblNo = "No"
$LblNoPermission = "no permission"
$LblNotAvailable = "not available"

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