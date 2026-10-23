# Calculate the size of data in the specified folder
function GetFolderDataSize {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Folder
  )

  try {
    $TotalBytes = [long]0

    # Explicit traversal avoids following directory links.
    $Directories = New-Object 'System.Collections.Generic.Stack[string]'
    $Directories.Push($Folder)

    while ($Directories.Count -gt 0) {
      $CurrentDirectory = $Directories.Pop()

      $Items = Get-ChildItem -LiteralPath $CurrentDirectory `
        -Force -ErrorAction Stop

      foreach ($Item in $Items) {
        # Links are not included in the folder size.
        if ($Item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
          continue
        }

        if ($Item -is [IO.DirectoryInfo]) {
          $Directories.Push($Item.FullName)
        }
        else {
          $TotalBytes += [long]$Item.Length
        }
      }
    }

    return [math]::Round($TotalBytes / 1MB, 2)
  }
  catch {
    Write-Warning "Cannot calculate folder size '$Folder': $($_.Exception.Message)"
    return $null
  }
}

function Test-SafeCleanupPath {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Folder
  )

  try {
    if ([string]::IsNullOrWhiteSpace($Folder)) {
      throw "Empty cleanup path."
    }

    $ExpandedPath = [Environment]::ExpandEnvironmentVariables($Folder)

    if (-not [IO.Path]::IsPathRooted($ExpandedPath)) {
      throw "Relative cleanup paths are not permitted."
    }

    $FullPath = [IO.Path]::GetFullPath($ExpandedPath).TrimEnd([char]'\')
    $DriveRoot = [IO.Path]::GetPathRoot($FullPath).TrimEnd([char]'\')

    # Never delete the contents of a drive root or network share.
    if ($FullPath -ieq $DriveRoot -or $FullPath.StartsWith('\\')) {
      throw "Drive roots and network paths are protected."
    }

    $WindowsRoot = [IO.Path]::GetFullPath($env:SystemRoot).TrimEnd([char]'\')

    # Only the five predefined cleanup destinations and TEMP
    # are permitted inside the Windows installation directory.
    $AllowedSystemPaths = @(
      $env:TEMP
      (Join-Path $env:SystemRoot 'Temp')
      (Join-Path $env:SystemRoot 'Prefetch')
      (Join-Path $env:SystemRoot 'Logs\CBS')
      (Join-Path $env:SystemRoot 'SoftwareDistribution\Download')
    )

    $AllowedSystemPaths = @(
      $AllowedSystemPaths | ForEach-Object {
        [IO.Path]::GetFullPath($_).TrimEnd([char]'\')
      }
    )

    if (
      $FullPath -ieq $WindowsRoot -or
      (
        $FullPath.StartsWith(
          $WindowsRoot + '\',
          [StringComparison]::OrdinalIgnoreCase
        ) -and
        $FullPath -notin $AllowedSystemPaths
      )
    ) {
      throw "Protected Windows system directory."
    }

    # Protect important directory roots.
    $ProtectedFolders = @(
      $env:ProgramFiles
      ${env:ProgramFiles(x86)}
      $env:ProgramData
      $env:USERPROFILE
      (Join-Path $env:SystemDrive 'Users')
      $PSScriptRoot
    )

    foreach ($ProtectedFolder in $ProtectedFolders) {
      if ([string]::IsNullOrWhiteSpace($ProtectedFolder)) {
        continue
      }

      $ProtectedPath = [IO.Path]::GetFullPath(
        $ProtectedFolder
      ).TrimEnd([char]'\')

      if (
        $FullPath -ieq $ProtectedPath -or
        $ProtectedPath.StartsWith(
          $FullPath + '\',
          [StringComparison]::OrdinalIgnoreCase
        )
      ) {
        throw "Protected directory or parent: $ProtectedPath"
      }
    }

    # Never clean Thunderbird profile data.
    $ThunderbirdRoot = Join-Path $env:APPDATA 'Thunderbird'

    $ThunderbirdRoot = [IO.Path]::GetFullPath(
      $ThunderbirdRoot
    ).TrimEnd([char]'\')

    if (
      $FullPath -ieq $ThunderbirdRoot -or
      $FullPath.StartsWith(
        $ThunderbirdRoot + '\',
        [StringComparison]::OrdinalIgnoreCase
      )
    ) {
      throw "Thunderbird profile data is protected."
    }

    # A folder or one of its parents must not be a junction
    # or symbolic link.
    $CurrentPath = $FullPath

    while (-not [string]::IsNullOrWhiteSpace($CurrentPath)) {
      $Item = Get-Item -LiteralPath $CurrentPath -Force -ErrorAction Stop

      if ($Item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
        throw "Reparse point in cleanup path: $CurrentPath"
      }

      $ParentPath = [IO.Path]::GetDirectoryName($CurrentPath)

      if ([string]::IsNullOrEmpty($ParentPath) -or $ParentPath -eq $CurrentPath) {
        break
      }

      $CurrentPath = $ParentPath
    }

    return $true
  }
  catch {
    Write-Warning "Unsafe cleanup path '$Folder': $($_.Exception.Message)"
    return $false
  }
}

function Remove-CleanupItem {
  param(
    [Parameter(Mandatory = $true)]
    [System.IO.FileSystemInfo]$Item
  )

  # Never follow or remove reparse points.
  if ($Item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
    throw "Reparse point skipped: $($Item.FullName)"
  }

  if ($Item -is [IO.DirectoryInfo]) {
    $Children = Get-ChildItem -LiteralPath $Item.FullName `
      -Force -ErrorAction Stop

    foreach ($Child in $Children) {
      Remove-CleanupItem -Item $Child
    }

    # Avoid recursively deleting newly added content.
    $Remaining = @(
      Get-ChildItem -LiteralPath $Item.FullName -Force -ErrorAction Stop
    )

    if ($Remaining.Count -gt 0) {
      throw "Directory still contains files: $($Item.FullName)"
    }
  }

  Remove-Item -LiteralPath $Item.FullName -Force -ErrorAction Stop
}

# Delete contents within the specified folder
function CleanupFolder {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Folder
  )

  if (-not (Test-SafeCleanupPath -Folder $Folder)) {
    return $false
  }

  try {
    $AllDeleted = $true

    # Delete contents only. Preserve the selected directory.
    $Items = Get-ChildItem -LiteralPath $Folder -Force -ErrorAction Stop

    foreach ($Item in $Items) {
      try {
        Remove-CleanupItem -Item $Item
      }
      catch {
        Write-Warning "Cannot delete '$($Item.FullName)': $($_.Exception.Message)"
        $AllDeleted = $false
      }
    }

    # A successful operation must leave the folder empty.
    $Remaining = @(
      Get-ChildItem -LiteralPath $Folder -Force -ErrorAction Stop
    )

    if ($Remaining.Count -gt 0) {
      Write-Warning "Cleanup incomplete: $Folder ($($Remaining.Count) remaining items)"
      return $false
    }

    return $AllDeleted
  }
  catch {
    Write-Warning "Cleanup failed '$Folder': $($_.Exception.Message)"
    return $false
  }
}

function Check_SMART_State {
  try {
    $PhysicalDisks = @(
      Get-CimInstance -ClassName Win32_DiskDrive -ErrorAction Stop
    )

    if ($PhysicalDisks.Count -eq 0) {
      throw "No physical disks found."
    }

    $AllHealthy = $true

    foreach ($Disk in $PhysicalDisks) {
      Write-Host "Disk: $($Disk.Model)"
      Write-Host "Status: $($Disk.Status)"

      if ($Disk.Status -ne 'OK') {
        Write-Warning "Disk reports an unhealthy or unknown status: $($Disk.Model)"
        $AllHealthy = $false
      }
    }

    return $AllHealthy
  }
  catch {
    Write-Warning "Disk diagnostics failed: $($_.Exception.Message)"
    return $false
  }
}

function SystemDiskSpace {
  try {
    # Use the actual Windows system drive.
    $DriveName = $env:SystemDrive.TrimEnd([char]':')

    $SystemDrive = Get-PSDrive -Name $DriveName -ErrorAction Stop

    if ($null -eq $SystemDrive.Free -or $null -eq $SystemDrive.Used) {
      throw "Disk space information is unavailable."
    }

    $FreeSpaceGB = [math]::Round($SystemDrive.Free / 1GB, 2)
    $UsedSpaceGB = [math]::Round($SystemDrive.Used / 1GB, 2)
    $TotalSpaceGB = [math]::Round(
      ($SystemDrive.Free + $SystemDrive.Used) / 1GB, 2
    )

    Write-Host "System drive: $DriveName"

    if ($FreeSpaceGB -lt 10) {
      Write-Host "Free: $FreeSpaceGB GB" -ForegroundColor Red
    }
    elseif ($FreeSpaceGB -lt 20) {
      Write-Host "Free: $FreeSpaceGB GB" -ForegroundColor Yellow
    }
    else {
      Write-Host "Free: $FreeSpaceGB GB" -ForegroundColor Green
    }

    Write-Host "Used: $UsedSpaceGB GB"
    Write-Host "Total: $TotalSpaceGB GB"

    return $true
  }
  catch {
    Write-Warning "Disk space check failed: $($_.Exception.Message)"
    return $false
  }
}

function CreateSystemRestorePoint {
  try {
    if ($PSVersionTable.PSVersion.Major -le 5) {
      Checkpoint-Computer `
        -Description 'DailyCleanUp Restore Point' `
        -RestorePointType 'MODIFY_SETTINGS' `
        -ErrorAction Stop
    }
    else {
      # Checkpoint-Computer is unavailable in PowerShell 7.
      # Use the built-in Windows PowerShell 5.1 executable.
      $WindowsPowerShell = Join-Path $env:SystemRoot `
        'System32\WindowsPowerShell\v1.0\powershell.exe'

      if (-not (Test-Path -LiteralPath $WindowsPowerShell -PathType Leaf)) {
        throw "Windows PowerShell 5.1 executable not found."
      }

      $Command = '$ErrorActionPreference = "Stop"; Checkpoint-Computer -Description "DailyCleanUp Restore Point" -RestorePointType "MODIFY_SETTINGS" -ErrorAction Stop'

      $EncodedCommand = [Convert]::ToBase64String(
        [Text.Encoding]::Unicode.GetBytes($Command)
      )

      $Process = Start-Process `
        -FilePath $WindowsPowerShell `
        -ArgumentList @(
        '-NoProfile'
        '-NonInteractive'
        '-EncodedCommand'
        $EncodedCommand
      ) `
        -NoNewWindow `
        -Wait `
        -PassThru `
        -ErrorAction Stop

      if ($Process.ExitCode -ne 0) {
        throw "Restore point creation failed with exit code $($Process.ExitCode)."
      }
    }

    return $true
  }
  catch {
    Write-Warning "Restore point creation failed: $($_.Exception.Message)"
    return $false
  }
}

function ClearDNSCache {
  try {
    Clear-DnsClientCache -ErrorAction Stop
    return $true
  }
  catch {
    Write-Warning "DNS cache cleanup failed: $($_.Exception.Message)"
    return $false
  }
}

function RunSystemHealthRepair {
  try {
    $DismExe = Join-Path $env:SystemRoot 'System32\dism.exe'
    $SfcExe = Join-Path $env:SystemRoot 'System32\sfc.exe'

    Write-Host "Running DISM RestoreHealth..."

    $DismOutput = & $DismExe /Online /Cleanup-Image /RestoreHealth 2>&1 |
    Out-String

    $DismExitCode = $LASTEXITCODE

    if ($DismExitCode -ne 0) {
      throw "DISM failed (exit code $DismExitCode): $DismOutput"
    }

    Write-Host "DISM completed successfully." -ForegroundColor Green
    Write-Host "Running SFC..."

    $SfcOutput = & $SfcExe /scannow 2>&1 |
    Out-String

    $SfcExitCode = $LASTEXITCODE

    if ($SfcExitCode -ne 0) {
      throw "SFC failed (exit code $SfcExitCode): $SfcOutput"
    }

    Write-Host "SFC completed successfully." -ForegroundColor Green

    return $true
  }
  catch {
    Write-Warning "System health repair failed: $($_.Exception.Message)"
    return $false
  }
}

function RunUpdates {
  try {
    # Winget updates applications, not Windows operating system updates.
    $WingetCommand = Get-Command 'winget.exe' `
      -CommandType Application -ErrorAction Stop

    Write-Host "Running winget upgrades..."

    $Output = & $WingetCommand.Source upgrade --all --include-unknown `
      --accept-source-agreements `
      --accept-package-agreements `
      --disable-interactivity 2>&1 |
    Out-String

    $ExitCode = $LASTEXITCODE

    if ($ExitCode -ne 0) {
      throw "Winget failed (exit code $ExitCode): $Output"
    }

    Write-Host "Winget completed successfully." -ForegroundColor Green

    return $true
  }
  catch {
    Write-Warning "Application updates failed: $($_.Exception.Message)"
    return $false
  }
}