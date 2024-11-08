function Clear-RecycleBin {
  try {
    Clear-RecycleBin -Driveletter C -confirm -ErrorAction Stop
    return $true
  }
  catch {

    return $false
  }
}