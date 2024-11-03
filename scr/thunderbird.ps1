$CurrentDir = Split-Path -Path $MyInvocation.MyCommand.Path -Parent

$ConfigFile = Join-Path -Path $CurrentDir -ChildPath "..\config.json"
$Config = Get-Content -Path $ConfigFile -Raw | ConvertFrom-Json

# Check if Thunderbird is installed
function IsThunderbirdInstalled() {
  $RegistryPath = @(
    "HKLM:\SOFTWARE\Mozilla\Mozilla Thunderbird",
    "HKLM:\SOFTWARE\WOW6432Node\Mozilla\Mozilla Thunderbird"
  )

  foreach ($Path in $RegistryPath) {
    if (Test-Path $Path) {
      return $true
    }
  }
  return $false
}

# Check if Thunderbird is running
function IsThunderbirdRunning {
  $Process = Get-Process -Name "thunderbird" -ErrorAction SilentlyContinue
  if ( $null -eq $Process ) {
    return $false
  }
  return $true
}

# Close Thunderbird
function CloseThunderbird {
  if (IsThunderbirdRunning) {
    Stop-Process -Name "thunderbird" -Force
  }
}

# Get Thunderbird profile path
function Get-ThunderbirdProfilePath {
  param(
    [string]$DefaultFolder = "$env:APPDATA\Thunderbird\Profiles"
  )

  $Results = @()

  # is default folder available
  if ( -not (Test-Path -Path $DefaultFolder)) {
    return $null
  }

  # return all profiles
  $Results = Get-ChildItem -Path $DefaultFolder -Directory
  return $Results | ForEach-Object { $_.FullName }
}

function CompressProfileToDestinationFolder {
  param (
    [string[]]$Paths
  )

  $BackUpFolder = $Config.BackUp.eMail.Thunderbird.BackupFolder

  foreach ( $Path in $Paths ) {
    if ( Test-Path -Path $Path ) {
      $Timestamp = Get-Date -Format "yyyy-MM-dd_HHmmss"
      $ProfilName = Split-Path -Path $Path -Leaf
      $ZipFileName = $Timestamp + "_" + $ProfilName + ".zip"
      $ZipFilePath = Join-Path -Path $BackUpFolder -ChildPath $zipFileName

      # compress
      Compress-Archive -Path $Path -DestinationPath $ZipFilePath -CompressionLevel Optimal -Force -ErrorAction Stop -ErrorVariable CompressError | Out-Null

      $results += " $ZipFilePath successful."
    }
    else {
      $results += "Profile $Path not found. Skipping compression."
    }
  }
  return $Results
}