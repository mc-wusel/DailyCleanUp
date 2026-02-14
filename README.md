# DailyCleanUp

DailyCleanUp is a configurable PowerShell maintenance script that
automates Windows system cleanup, diagnostics, optional backups, and
restart operations.\
All behavior is controlled via a `config.json` file, allowing flexible
activation or deactivation of individual maintenance tasks.

The script is designed for regular system maintenance and can be
executed manually or via Windows Task Scheduler.

# Main Features

## System Diagnostics

-   **S.M.A.R.T Disk Health Check**\
    Checks the health status of physical disks and displays system disk
    space information.

-   **System Health Repair (optional)**\
    Runs Windows system health repair operations.

-   **Windows Update Check (optional)**\
    Executes update checks and installation procedures.

## System Maintenance

-   **Create System Restore Point (optional)**\
    Generates a Windows restore point before performing cleanup
    operations.

-   **Clear DNS Cache (optional)**\
    Flushes the Windows DNS cache.

-   **Folder Size Analysis**\
    Calculates and displays the size (in MB) of system and custom
    folders.

-   **System Folder Cleanup (optional)**\
    Deletes contents of predefined Windows system folders and
    user-defined directories.

Default system folders include:

-   `%TEMP%`
-   `C:\Windows\Temp`
-   `C:\Windows\Prefetch`
-   `C:\Windows\Logs\CBS`
-   `C:\Windows\SoftwareDistribution\Download`

Additional folders can be defined in the configuration file.

-   **Recycle Bin Cleanup (optional)**\
    Empties the Windows Recycle Bin.

## Thunderbird Profile Backup (optional)

If enabled in the configuration:

-   Detects whether Thunderbird is installed
-   Closes Thunderbird if currently running
-   Detects available profiles
-   Compresses profiles
-   Stores backups in a defined destination folder

This ensures email data, contacts, and settings are preserved before
performing cleanup operations.

## Automatic Restart

If enabled, the script automatically restarts the system after execution
(with a countdown timer).

# Configuration

All features are controlled via `config.json`.

## Configuration Overview

  ----------------------------------------------------------------------------------
  Setting                                   Description
  ----------------------------------------- ----------------------------------------
  `Disk.Check`                              Enables S.M.A.R.T disk check and disk
                                            space display

  `RestorePoint.Create`                     Creates a system restore point

  `DNSCache.Clear`                          Clears the Windows DNS cache

  `SystemHealthRepair.Check`                Runs system health repair

  `Updates.Check`                           Executes Windows update check

  `Folder.Check`                            Calculates folder sizes

  `Folder.Delete`                           Deletes folder contents

  `Folder.AdditionalFolders`                Adds custom folders for cleanup

  `RecycleBin.Delete`                       Empties the recycle bin

  `Restart`                                 Restarts the system after completion

  `BackUp.eMail.Thunderbird.Activated`      Enables Thunderbird backup

  `BackUp.eMail.Thunderbird.BackupFolder`   Destination folder for backups
  ----------------------------------------------------------------------------------

## Example Configuration

``` json
{
  "Disk": { "Check": true },
  "RestorePoint": { "Create": false },
  "DNSCache": { "Clear": true },
  "SystemHealthRepair": { "Check": false },
  "Updates": { "Check": false },
  "Folder": {
    "Check": true,
    "Delete": false,
    "AdditionalFolders": []
  },
  "RecycleBin": { "Delete": false },
  "Restart": true,
  "BackUp": {
    "eMail": {
      "Thunderbird": {
        "Activated": false,
        "BackupFolder": "D:\\ThunderBack"
      }
    }
  }
}
```

# Administrator Behavior

Some operations require administrator privileges:

-   Creating restore points\
-   Cleaning system folders\
-   Running updates\
-   Emptying the Recycle Bin\
-   Restarting the system

If required, the script automatically relaunches itself with elevated
permissions.

# Usage

## Installation

1.  Clone the repository or download the files.
2.  Adjust `config.json` according to your needs.
3.  Ensure PowerShell execution policy allows local scripts:

``` powershell
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
```

## Execution

``` powershell
.\DailyCleanUp.ps1
```

The script can also be configured as a scheduled task for automated
maintenance.

# Requirements

-   Windows OS\
-   PowerShell 5.x or newer\
-   Administrator privileges (for system-level tasks)\
-   Thunderbird (only required if backup feature is enabled)

# Benefits

-   **Modular** -- Enable only the features you need\
-   **Automated Maintenance** -- Suitable for scheduled execution\
-   **Safe Backup Option** -- Protect Thunderbird profiles before
    cleanup\
-   **Graceful Error Handling** -- Handles missing folders and
    permission issues safely

# Conclusion

**DailyCleanUp** provides a structured and configurable approach to
Windows system maintenance.\
It combines diagnostics, cleanup, optional backups, and restart
automation in a single script.
