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

# Windows is required for the maintenance commands.
if ([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT) {
  throw "DailyCleanUp requires Windows."
}

$OutputEncoding = [System.Text.Encoding]::UTF8
$ConfigFile = Join-Path $PSScriptRoot 'config.json'

try {
  $Config = Get-Content -LiteralPath $ConfigFile -Raw -Encoding UTF8 -ErrorAction Stop |
  ConvertFrom-Json -ErrorAction Stop
}
catch {
  throw "Cannot load configuration '$ConfigFile': $($_.Exception.Message)"
}

# ------------------------------------------------------------
# Common labels
# ------------------------------------------------------------
$LblOK = "OK"
$LblYes = "Yes"
$LblNo = "No"
$LblNoPermission = "no permission"
$LblNotAvailable = "not available"
$LblWarning = "WARNING"
$LblError = "ERROR"
$LblSkipped = "SKIPPED"
$LblRequested = "REQUESTED"



# Reject missing or incorrectly typed Boolean settings.
# This also prevents a string such as "false" from enabling a task.
$BooleanSettings = @{
  'Disk.Check'                   = $Config.Disk.Check
  'RestorePoint.Create'          = $Config.RestorePoint.Create
  'DNSCache.Clear'               = $Config.DNSCache.Clear
  'SystemHealthRepair.Check'     = $Config.SystemHealthRepair.Check
  'Updates.Check'                = $Config.Updates.Check
  'Folder.Check'                 = $Config.Folder.Check
  'Folder.Delete'                = $Config.Folder.Delete
  'RecycleBin.Delete'            = $Config.RecycleBin.Delete
  'BackUp.Thunderbird.Activated' = $Config.BackUp.eMail.Thunderbird.Activated
  'Restart'                      = $Config.Restart
}

foreach ($Setting in $BooleanSettings.Keys) {
  if ($BooleanSettings[$Setting] -isnot [bool]) {
    throw "Invalid or missing Boolean configuration: $Setting"
  }
}

if ($Config.Folder.PSObject.Properties.Name -contains 'AdditionalFolders') {
  $AdditionalFolders = $Config.Folder.AdditionalFolders
}
else {
  $AdditionalFolders = @()
}

if ($AdditionalFolders -isnot [array]) {
  throw "Folder.AdditionalFolders must be an array."
}

# Build the folder list independently of Folder.Check.
$CleanupFolders = @(
  $env:TEMP
  (Join-Path $env:SystemRoot 'Temp')
  (Join-Path $env:SystemRoot 'Prefetch')
  (Join-Path $env:SystemRoot 'Logs\CBS')
  (Join-Path $env:SystemRoot 'SoftwareDistribution\Download')
)

$CleanupFolders += $AdditionalFolders

# Normalize paths, reject relative paths and remove duplicates.
$CleanupFolders = @(
  $CleanupFolders | ForEach-Object {
    if ($_ -isnot [string] -or [string]::IsNullOrWhiteSpace($_)) {
      throw "Cleanup folders must contain non-empty paths."
    }

    $ExpandedPath = [Environment]::ExpandEnvironmentVariables($_)

    if (-not [IO.Path]::IsPathRooted($ExpandedPath)) {
      throw "Cleanup path must be absolute: $ExpandedPath"
    }

    [IO.Path]::GetFullPath($ExpandedPath)
  } | Select-Object -Unique
)

# Verify that Thunderbird backups cannot be deleted by cleanup.
if ($Config.BackUp.eMail.Thunderbird.Activated) {
  $BackupFolder = [string]$Config.BackUp.eMail.Thunderbird.BackupFolder

  if ([string]::IsNullOrWhiteSpace($BackupFolder)) {
    throw "Thunderbird backup folder is not configured."
  }

  $BackupFolder = [Environment]::ExpandEnvironmentVariables($BackupFolder)

  if (-not [IO.Path]::IsPathRooted($BackupFolder)) {
    throw "Thunderbird backup folder must be absolute."
  }

  $BackupFolder = [IO.Path]::GetFullPath($BackupFolder).TrimEnd([char]'\')

  if ($Config.Folder.Delete) {
    foreach ($Folder in $CleanupFolders) {
      $CleanupPath = $Folder.TrimEnd([char]'\')

      if (
        $BackupFolder.Equals(
          $CleanupPath,
          [StringComparison]::OrdinalIgnoreCase
        ) -or
        $BackupFolder.StartsWith(
          $CleanupPath + '\',
          [StringComparison]::OrdinalIgnoreCase
        )
      ) {
        throw "Backup destination is inside cleanup folder: $Folder"
      }
    }
  }
}

# Load existing modules.
. (Join-Path $PSScriptRoot 'src\core.ps1')
. (Join-Path $PSScriptRoot 'src\thunderbird.ps1')
. (Join-Path $PSScriptRoot 'src\recyclebin.ps1')



function Add-TaskLog {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Task,
    [Parameter(Mandatory = $true)]
    [bool]$Success
  )

  $Status = if ($Success) { "OK" } else { "ERROR" }
  $Date = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
  Add-Content -Path $Script:TaskLogFile -Value "$Date | $Task | $Status" -Encoding UTF8
}

# Check if the script is running with administrator privileges
function IsAdministrator {
  $Identity = [Security.Principal.WindowsIdentity]::GetCurrent()
  $Principal = [Security.Principal.WindowsPrincipal]::new($Identity)

  return $Principal.IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator
  )
}

# Elevate only when a configured task requires administrator rights.
$RequiresAdministrator = (
  $Config.RestorePoint.Create -or
  $Config.DNSCache.Clear -or
  $Config.SystemHealthRepair.Check -or
  $Config.Folder.Delete -or
  $Config.RecycleBin.Delete
)

Clear-Host

if ($RequiresAdministrator -and -not (IsAdministrator)) {
  if (-not [Environment]::UserInteractive) {
    throw "Administrator privileges are required. Configure the scheduled task to run with highest privileges."
  }

  try {
    $Executable = (Get-Process -Id $PID -ErrorAction Stop).Path

    if ([string]::IsNullOrWhiteSpace($Executable)) {
      throw "Cannot determine the current PowerShell executable."
    }

    $Arguments = '-NoProfile -ExecutionPolicy Bypass -File "{0}"' -f $PSCommandPath

    Start-Process -FilePath $Executable -ArgumentList $Arguments -Verb RunAs -ErrorAction Stop |
    Out-Null

    return
  }
  catch {
    throw "Administrator elevation failed: $($_.Exception.Message)"
  }
}


$Script:AllSucceeded = $true

$Script:TaskLogFile = Join-Path $PSScriptRoot (
  'DailyCleanUp-Report-{0}.md' -f (Get-Date -Format 'yyyyMMdd-HHmmss-fff')
)

@(
  '# DailyCleanUp Report'
  ''
  '| Date | Task | Status | Details |'
  '|---|---|---|---|'
) | Set-Content -LiteralPath $Script:TaskLogFile -Encoding UTF8 -ErrorAction Stop


function Write-TaskSelection {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Task,

    [Parameter(Mandatory = $true)]
    [bool]$Enabled
  )

  Write-Host "${Task}... " -NoNewline -ForegroundColor Magenta

  if ($Enabled) {
    Write-Host $LblYes -ForegroundColor Green
  }
  else {
    Write-Host $LblNo -ForegroundColor Red
  }
}

function Add-TaskLog {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Task,

    [Parameter(Mandatory = $true)]
    [ValidateSet('OK', 'ERROR', 'SKIPPED', 'REQUESTED')]
    [string]$Status,

    [string]$Details = ''
  )

  # Keep the Markdown table valid.
  $Task = $Task.Replace('|', '/').Replace("`r", ' ').Replace("`n", ' ')
  $Details = $Details.Replace('|', '/').Replace("`r", ' ').Replace("`n", ' ')

  $Line = '| {0} | {1} | {2} | {3} |' -f (
    Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
  ), $Task, $Status, $Details

  Add-Content -LiteralPath $Script:TaskLogFile -Value $Line -Encoding UTF8 -ErrorAction Stop

  if ($Status -eq $LblError) {
    $Script:AllSucceeded = $false
  }
}

function Invoke-MaintenanceTask {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Task,

    [Parameter(Mandatory = $true)]
    [scriptblock]$Action
  )

  try {
    $Result = & $Action

    if ($Result -ne $true) {
      throw "The operation did not report success."
    }

    Add-TaskLog -Task $Task -Status $LblOK
    Write-Host "${LblOK}: $Task" -ForegroundColor Green

    return $true
  }
  catch {
    $Message = $_.Exception.Message

    if ($_.Exception -is [UnauthorizedAccessException]) {
      Write-Host "${Task}: $LblNoPermission" -ForegroundColor Red
    }
    else {
      Write-Warning "${Task}: $Message"
    }

    Add-TaskLog -Task $Task -Status $LblError -Details $Message

    return $false
  }
}

Write-TaskSelection -Task 'Disk diagnostics' -Enabled $Config.Disk.Check

if ($Config.Disk.Check) {
  $null = Invoke-MaintenanceTask -Task 'Disk diagnostics' -Action {
    $DiskHealthy = Check_SMART_State
    $DiskSpaceAvailable = SystemDiskSpace

    return ($DiskHealthy -and $DiskSpaceAvailable)
  }
}

$PrerequisitesSucceeded = $true

Write-TaskSelection -Task 'Create system restore point' -Enabled $Config.RestorePoint.Create

if ($Config.RestorePoint.Create) {
  $Result = Invoke-MaintenanceTask -Task 'Create restore point' -Action {
    CreateSystemRestorePoint
  }

  if (-not $Result) {
    $PrerequisitesSucceeded = $false
  }
}

Write-TaskSelection -Task 'Thunderbird backup' -Enabled $Config.BackUp.eMail.Thunderbird.Activated

# Back up Thunderbird before destructive maintenance.
if ($Config.BackUp.eMail.Thunderbird.Activated) {
  $Result = Invoke-MaintenanceTask -Task 'Thunderbird backup' -Action {
    if (-not (IsThunderbirdInstalled)) {
      throw "Thunderbird installation not found."
    }

    # Never force-close Thunderbird.
    if (-not (CloseThunderbird)) {
      throw "Thunderbird could not be closed gracefully."
    }

    $Profiles = @(Get-ThunderbirdProfilePath)

    if ($Profiles.Count -eq 0) {
      throw "No Thunderbird profiles found."
    }

    CompressProfileToDestinationFolder ` -Paths $Profiles ` -BackupFolder $Config.BackUp.eMail.Thunderbird.BackupFolder
  }

  if (-not $Result) {
    $PrerequisitesSucceeded = $false
  }
}

Write-TaskSelection -Task 'System health repair' -Enabled $Config.SystemHealthRepair.Check

if ($Config.SystemHealthRepair.Check) {
  if ($PrerequisitesSucceeded) {
    $null = Invoke-MaintenanceTask -Task 'System health repair' -Action {
      RunSystemHealthRepair
    }
  }
  else {
    Add-TaskLog -Task 'System health repair' -Status $LblSkipped ` -Details 'Required restore point or backup failed.'
  }
}

Write-TaskSelection -Task 'Winget application updates' -Enabled $Config.Updates.Check

if ($Config.Updates.Check) {
  if ($PrerequisitesSucceeded) {
    $null = Invoke-MaintenanceTask -Task 'Winget application updates' -Action {
      RunUpdates
    }
  }
  else {
    Add-TaskLog -Task 'Winget application updates' -Status $LblSkipped ` -Details 'Required restore point or backup failed.'
  }
}

Write-TaskSelection -Task 'System folder cleanup check' -Enabled $Config.Folder.Check

if ($Config.Folder.Check) {
  foreach ($Folder in $CleanupFolders) {
    $Task = "Check folder $Folder"

    Write-Host "`tFolder: $Folder" -ForegroundColor Magenta

    try {
      if (-not (Test-Path -LiteralPath $Folder -PathType Container -ErrorAction Stop)) {
        Write-Host "`tStatus: $LblNotAvailable" -ForegroundColor Red

        Add-TaskLog -Task $Task -Status $LblSkipped ` -Details $LblNotAvailable

        continue
      }

      $FolderSize = GetFolderDataSize -Folder $Folder

      if ($null -eq $FolderSize) {
        Write-Host "`tStatus: $LblError" -ForegroundColor Red

        Add-TaskLog -Task $Task -Status $LblError ` -Details 'Folder size could not be calculated.'

        continue
      }

      Write-Host "`tSize: $FolderSize MB" -ForegroundColor Yellow
      Write-Host "`tStatus: $LblOK" -ForegroundColor Green

      Add-TaskLog -Task $Task -Status $LblOK ` -Details "$FolderSize MB"
    }
    catch {
      $Message = $_.Exception.Message

      if ($_.Exception -is [UnauthorizedAccessException]) {
        Write-Host "`tStatus: $LblNoPermission" -ForegroundColor Red
      }
      else {
        Write-Host "`tStatus: $LblError" -ForegroundColor Red
      }

      Add-TaskLog -Task $Task -Status $LblError -Details $Message
    }
  }
}

Write-TaskSelection -Task 'System folder cleanup desired' -Enabled $Config.Folder.Delete

if ($Config.Folder.Delete) {
  if (-not $PrerequisitesSucceeded) {
    Add-TaskLog -Task 'Folder cleanup' -Status $LblSkipped ` -Details 'Required restore point or backup failed.'
  }
  else {
    foreach ($Folder in $CleanupFolders) {
      $Task = "Cleanup folder $Folder"

      Write-Host "`tFolder: $Folder" -ForegroundColor Magenta

      try {
        if (-not (Test-Path -LiteralPath $Folder -PathType Container -ErrorAction Stop)) {
          Write-Host "`tStatus: $LblNotAvailable" -ForegroundColor Red

          Add-TaskLog -Task $Task -Status $LblSkipped ` -Details $LblNotAvailable

          continue
        }

        $null = Invoke-MaintenanceTask -Task $Task -Action {
          CleanupFolder -Folder $Folder
        }
      }
      catch {
        $Message = $_.Exception.Message

        if ($_.Exception -is [UnauthorizedAccessException]) {
          Write-Host "`tStatus: $LblNoPermission" -ForegroundColor Red
        }
        else {
          Write-Host "`tStatus: $LblError" -ForegroundColor Red
        }

        Add-TaskLog -Task $Task -Status $LblError -Details $Message
      }
    }
  }
}

Write-TaskSelection -Task 'Empty recycle bin desired' -Enabled $Config.RecycleBin.Delete

if ($Config.RecycleBin.Delete) {
  if ($PrerequisitesSucceeded) {
    $null = Invoke-MaintenanceTask -Task 'Empty recycle bin' -Action {
      Clear-RecycleBin
    }
  }
  else {
    Add-TaskLog -Task 'Empty recycle bin' -Status $LblSkipped ` -Details 'Required restore point or backup failed.'
  }
}

if ($Script:AllSucceeded) {
  Write-Host "All enabled maintenance tasks succeeded: $LblOK" -ForegroundColor Green
}
else {
  Write-Warning "One or more maintenance tasks failed: $LblError"
}

Write-Host "Report: $Script:TaskLogFile"

Write-TaskSelection -Task 'Restart computer' -Enabled $Config.Restart

if ($Config.Restart) {
  if ($Script:AllSucceeded) {
    $Delay = 5

    Write-Host "Restarting Windows in $Delay seconds..." -ForegroundColor Yellow

    for ($i = $Delay; $i -gt 0; $i--) {
      Write-Host "$i..."
      Start-Sleep -Seconds 1
    }

    # Record the requested restart, not an unverified completion.
    Add-TaskLog -Task 'Restart' -Status $LblRequested ` -Details 'Submitting forced restart. Completion not verified.'

    try {
      Restart-Computer -Force -ErrorAction Stop
    }
    catch {
      Add-TaskLog -Task 'Restart' -Status $LblError ` -Details $_.Exception.Message

      Write-Warning "Restart failed: $($_.Exception.Message)"
    }
  }
  else {
    Add-TaskLog -Task 'Restart' -Status $LblSkipped ` -Details 'At least one enabled maintenance task failed.'
  }
}

if (-not $Script:AllSucceeded) {
  exit 1
}