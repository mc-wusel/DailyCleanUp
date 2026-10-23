function IsThunderbirdInstalled {
  if (Get-Command 'thunderbird.exe' -ErrorAction SilentlyContinue) {
    return $true
  }

  $RegistryPaths = @(
    'HKLM:\SOFTWARE\Mozilla\Mozilla Thunderbird'
    'HKLM:\SOFTWARE\WOW6432Node\Mozilla\Mozilla Thunderbird'
  )

  foreach ($Path in $RegistryPaths) {
    if (Test-Path -LiteralPath $Path) {
      return $true
    }
  }

  return $false
}

function IsThunderbirdRunning {
  $Process = Get-Process -Name 'thunderbird' -ErrorAction SilentlyContinue

  return ($null -ne $Process)
}

function CloseThunderbird {
  try {
    $Processes = @(
      Get-Process -Name 'thunderbird' -ErrorAction SilentlyContinue
    )

    if ($Processes.Count -eq 0) {
      return $true
    }

    # Request a normal window close.
    # Never terminate the process forcibly.
    foreach ($Process in $Processes) {
      if (-not $Process.HasExited) {
        if (-not $Process.CloseMainWindow()) {
          throw "Thunderbird process $($Process.Id) cannot be closed gracefully."
        }
      }
    }

    # Wait at most 15 seconds per process.
    foreach ($Process in $Processes) {
      if (-not $Process.HasExited) {
        if (-not $Process.WaitForExit(15000)) {
          throw "Thunderbird process $($Process.Id) did not exit."
        }
      }
    }

    # Include any processes that may have started meanwhile.
    return (-not (IsThunderbirdRunning))
  }
  catch {
    Write-Warning "Thunderbird shutdown failed: $($_.Exception.Message)"
    return $false
  }
}

function Get-ThunderbirdProfilePath {
  param(
    [string]$DefaultFolder = "$env:APPDATA\Thunderbird\Profiles"
  )

  try {
    if (-not (Test-Path -LiteralPath $DefaultFolder -PathType Container)) {
      return @()
    }

    $Profiles = @(
      Get-ChildItem -LiteralPath $DefaultFolder -Directory ` -Force -ErrorAction Stop
    )

    return $Profiles | ForEach-Object {
      $_.FullName
    }
  }
  catch {
    Write-Warning "Cannot retrieve Thunderbird profiles: $($_.Exception.Message)"
    return @()
  }
}

function CompressProfileToDestinationFolder {
  param(
    [Parameter(Mandatory = $true)]
    [string[]]$Paths,

    [string]$BackupFolder = $Config.BackUp.eMail.Thunderbird.BackupFolder
  )

  try {
    if ([string]::IsNullOrWhiteSpace($BackupFolder)) {
      throw "Backup destination is not configured."
    }

    $BackupFolder = [Environment]::ExpandEnvironmentVariables($BackupFolder)

    if (-not [IO.Path]::IsPathRooted($BackupFolder)) {
      throw "Backup destination must be an absolute path."
    }

    $BackupFolder = [IO.Path]::GetFullPath($BackupFolder)

    # Required for .NET Framework / Windows PowerShell 5.1.
    if ($PSVersionTable.PSVersion.Major -le 5) {
      Add-Type -AssemblyName System.IO.Compression.FileSystem `
        -ErrorAction Stop
    }

    # Create the backup destination if necessary.
    New-Item -ItemType Directory -Path $BackupFolder `
      -Force -ErrorAction Stop | Out-Null
  }
  catch {
    Write-Warning "Cannot prepare Thunderbird backup: $($_.Exception.Message)"
    return $false
  }

  $AllSucceeded = $true

  foreach ($Path in $Paths) {
    $TemporaryZip = $null

    try {
      if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
        throw "Profile does not exist: $Path"
      }

      $ProfilePath = [IO.Path]::GetFullPath($Path).TrimEnd([char]'\')
      $DestinationPath = $BackupFolder.TrimEnd([char]'\')

      # Avoid creating an archive inside its own source directory.
      if (
        $DestinationPath -ieq $ProfilePath -or
        $DestinationPath.StartsWith(
          $ProfilePath + '\',
          [StringComparison]::OrdinalIgnoreCase
        )
      ) {
        throw "Backup destination is inside the profile."
      }

      $ProfileName = Split-Path -Path $ProfilePath -Leaf
      $Timestamp = Get-Date -Format 'yyyyMMdd-HHmmss-fff'
      $UniqueId = [guid]::NewGuid().ToString('N').Substring(0, 8)

      $ZipFileName = '{0}_{1}_{2}.zip' -f (
        $Timestamp, $ProfileName, $UniqueId
      )

      $ZipFilePath = Join-Path $BackupFolder $ZipFileName
      $TemporaryZip = Join-Path $BackupFolder "$ZipFileName.partial.zip"

      # .NET compression includes hidden Thunderbird files.
      [IO.Compression.ZipFile]::CreateFromDirectory(
        $ProfilePath,
        $TemporaryZip,
        [IO.Compression.CompressionLevel]::Optimal,
        $true
      )

      # Include Thunderbird profile registration metadata.
      $ThunderbirdRoot = Join-Path $env:APPDATA 'Thunderbird'

      $Archive = [IO.Compression.ZipFile]::Open(
        $TemporaryZip,
        [IO.Compression.ZipArchiveMode]::Update
      )

      try {
        foreach ($FileName in @('profiles.ini', 'installs.ini')) {
          $MetadataFile = Join-Path $ThunderbirdRoot $FileName

          if (Test-Path -LiteralPath $MetadataFile -PathType Leaf) {
            [IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
              $Archive,
              $MetadataFile,
              $FileName
            ) | Out-Null
          }
        }

        if ($Archive.Entries.Count -eq 0) {
          throw "Created archive contains no entries."
        }
      }
      finally {
        $Archive.Dispose()
      }

      # Publish only completed archives.
      Move-Item -LiteralPath $TemporaryZip ` -Destination $ZipFilePath -ErrorAction Stop

      $CreatedFile = Get-Item -LiteralPath $ZipFilePath -ErrorAction Stop

      if ($CreatedFile.Length -le 0) {
        throw "Created backup archive is empty."
      }

      Write-Host "Backup created: $ZipFilePath" -ForegroundColor Green
    }
    catch {
      Write-Warning "Thunderbird profile backup failed '$Path': $($_.Exception.Message)"
      $AllSucceeded = $false

      # Never leave a partial archive presented as a valid backup.
      if (
        $null -ne $TemporaryZip -and
        (Test-Path -LiteralPath $TemporaryZip)
      ) {
        Remove-Item -LiteralPath $TemporaryZip -Force ` -ErrorAction SilentlyContinue
      }
    }
  }

  return $AllSucceeded
}