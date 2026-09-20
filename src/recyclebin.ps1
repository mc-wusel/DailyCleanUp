function Clear-RecycleBin {
  try {
    Microsoft.PowerShell.Management\Clear-RecycleBin -DriveLetter C -Force -Confirm:$false -ErrorAction Stop
    return $true
  }
  catch {

    return $false
  }
}