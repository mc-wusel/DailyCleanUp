[![Release](https://img.shields.io/github/v/release/mc-wusel/DailyCleanUp)](https://github.com/mc-wusel/DailyCleanUp/releases)
[![Stars](https://img.shields.io/github/stars/mc-wusel/DailyCleanUp)](https://github.com/mc-wusel/DailyCleanUp/stargazers)
[![Issues](https://img.shields.io/github/issues/mc-wusel/DailyCleanUp)](https://github.com/mc-wusel/DailyCleanUp/issues)
![Last commit](https://img.shields.io/github/last-commit/mc-wusel/DailyCleanUp)
![Repo size](https://img.shields.io/github/repo-size/mc-wusel/DailyCleanUp)
![Top language](https://img.shields.io/github/languages/top/mc-wusel/DailyCleanUp)

# 🧹 DailyCleanUp

**DailyCleanUp** is a configurable **PowerShell system maintenance script** that automates Windows cleanup, diagnostics, optional backups, and restart operations.

All behavior is controlled via a **`config.json` configuration file**, allowing you to enable or disable each maintenance task individually.

The script can be executed **manually or automatically via Windows Task Scheduler**.

---

# 🚀 Download

Download the latest version from the releases page:

➡ **[Download Latest Release](https://github.com/mc-wusel/DailyCleanUp/releases/latest)**

---

# 📖 Overview

DailyCleanUp provides a **structured and automated way to maintain Windows systems**.

It combines:

* System diagnostics
* Cleanup operations
* Optional backups
* Automatic restart functionality

All functionality is **modular and configurable** through a single configuration file.

---

# ⚙️ Features

## 🔍 System Diagnostics

### S.M.A.R.T Disk Health Check

Checks the health status of physical disks and displays system disk usage information.

### System Health Repair *(optional)*

Runs Windows system repair commands to verify and restore system integrity.

### Windows Update Check *(optional)*

Checks for available Windows updates and installs them if configured.

---

## 🧹 System Maintenance

### Create System Restore Point *(optional)*

Creates a restore point before executing cleanup tasks.

### Clear DNS Cache *(optional)*

Flushes the Windows DNS cache.

### Folder Size Analysis

Calculates and displays the size of important system folders.

### System Folder Cleanup *(optional)*

Deletes contents of predefined Windows system folders and optional custom directories.

Default folders:

* `%TEMP%`
* `C:\Windows\Temp`
* `C:\Windows\Prefetch`
* `C:\Windows\Logs\CBS`
* `C:\Windows\SoftwareDistribution\Download`

Additional folders can be configured in `config.json`.

### Recycle Bin Cleanup *(optional)*

Empties the Windows Recycle Bin.

---

## 📧 Thunderbird Profile Backup *(optional)*

If enabled:

* Detects installed Thunderbird profiles
* Closes Thunderbird if running
* Compresses profile data
* Saves backups to a defined folder

This protects **emails, contacts, and configuration data** before cleanup operations.

---

## 🔄 Automatic Restart

If enabled, the script **automatically restarts the system after execution** with a countdown timer.

---

# ⚙️ Configuration

All features are controlled through the `config.json` file.

## Configuration Options

| Setting                               | Description                                         |
| ------------------------------------- | --------------------------------------------------- |
| Disk.Check                            | Enables S.M.A.R.T disk check and disk space display |
| RestorePoint.Create                   | Creates a Windows restore point                     |
| DNSCache.Clear                        | Clears the DNS cache                                |
| SystemHealthRepair.Check              | Runs system repair commands                         |
| Updates.Check                         | Executes Windows update checks                      |
| Folder.Check                          | Calculates folder sizes                             |
| Folder.Delete                         | Deletes folder contents                             |
| Folder.AdditionalFolders              | Additional folders for cleanup                      |
| RecycleBin.Delete                     | Empties the recycle bin                             |
| Restart                               | Automatically restarts the system                   |
| BackUp.eMail.Thunderbird.Activated    | Enables Thunderbird backup                          |
| BackUp.eMail.Thunderbird.BackupFolder | Backup destination folder                           |

---

## Example Configuration

```json
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

---

# 💾 Installation

Clone the repository:

```bash
git clone https://github.com/mc-wusel/DailyCleanUp.git
```

Or download the latest release from the releases page.

Adjust the configuration file:

```
config.json
```

---

# ▶️ Usage

Run the script from PowerShell:

```powershell
.\DailyCleanUp.ps1
```

---

# 🔐 Administrator Behavior

Some operations require **administrator privileges**, including:

* Creating restore points
* Cleaning system folders
* Running Windows updates
* Emptying the recycle bin
* Restarting the system

If required, the script **automatically relaunches itself with elevated permissions**.

---

# 🖥 Requirements

* Windows OS
* PowerShell **5.x or newer**
* Administrator privileges (for system-level tasks)
* Thunderbird *(only if backup feature is enabled)*

---

# 🤖 Automation (Task Scheduler)

DailyCleanUp can run automatically using **Windows Task Scheduler**.

Typical setup:

1. Open **Task Scheduler**
2. Create a **Basic Task**
3. Set trigger (daily / weekly)
4. Execute:

```
powershell.exe
```

Arguments:

```
-ExecutionPolicy Bypass -File "C:\Path\To\DailyCleanUp.ps1"
```

---

# 🌟 Benefits

**Modular Design**
Enable only the features you need.

**Automated Maintenance**
Perfect for scheduled maintenance tasks.

**Safe Backup Option**
Protect Thunderbird profiles.

---

# 🤝 Contributing

Contributions, suggestions, and bug reports are welcome.

1. Fork the repository
2. Create a feature branch
3. Submit a pull request

---

# 📄 License

This project is licensed under the repository's license.

---

# ⭐ Support the Project

If you find this project useful:

* ⭐ Star the repository
* 🐛 Report issues
* 💡 Suggest improvements
