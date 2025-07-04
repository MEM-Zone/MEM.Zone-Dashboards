[![Release version][release-version-badge]][release-version]
[![Release date][release-date-badge]][release-date]
[![Issues count][issues-badge]][issues]
[![Commits since release][commits-since-badge]][commits-since]
[![Chat on discord][discord-badge]][discord]
[![Follow on X][x-badge]][x]

# MEM.Zone Dashboards

This is a solution of dashboards and reports, for Microsoft Endpoint Configuration Manager.

* `_Dashboard - Software Updates` dashboard is navigable, independent of `Software Update Groups` and comes with an array of filtering options and sub-reports.
* `Application - Compliance by Collection` standalone report is used to monitor application compliance by collection.
* `Baseline - Compliance by Collection` standalone report is used to monitor baseline compliance by collection.
* `Bitlocker - Compliance by Collection (MBAM)` standalone report is used to monitor Bitlocker (MBAM) compliance and non-compliance reasons.
* `Bitlocker - Compliance by Collection` standalone report is used to monitor Bitlocker compliance, key upload and non-compliance reasons.
* `Operating System - Version Compliance by Collection` standalone report is used to monitor Feature Update or Windows Version Compliance.
* `Operating System - Windows 11 Readiness by Collection` standalone report is used to check Windows 11 Upgrade Readiness.
* `Package - Compliance by Collection` standalone report is used to monitor package compliance by collection.
* `Package - Compliance by Deployment` standalone report is used to monitor package compliance by deployment.
* `Site - Alerts` sub-report is used to monitor critical alerts.
* `Software Update - Compliance by Collection` sub-report is used to monitor software update compliance by collection.
* `Software Update - Compliance by Device` sub-report is used to monitor software update compliance by device.
* `Software Update - Scan Status by Collection` sub-report is used to monitor software update scan status by collection.
* `Software Update - Update Point Sync Status` sub-report is used to monitor software update update point sync status.
* `Software Update - CU Compliance by Collection` standalone report is used to monitor software update compliance by collection.

>**Notes**
>All sub-reports can be run standalone.
>The installation can be done manually or via the included PowerShell installer.

## Main page

See [main](https://MEMZ.one/Dashboards).

## Latest release

See [releases](https://MEMZ.one/Dashboards-RELEASES).

## Changelog

See [changelog](https://MEMZ.one/Dashboards-CHANGELOG).

## Help

See [help](https://MEMZ.one/Dashboards-Help).

## Credit

* Adam Weigert [`ufn_CM_GetNextMaintenanceWindow`](https://social.technet.microsoft.com/wiki/contents/articles/7870.sccm-2007-create-report-of-upcoming-maintenance-windows-by-client.aspx)

## Dashboards and Reports

* _Dashboard - Software Updates (Main Dashboard Report)
* Application - Compliance by Collection
* Baseline - Compliance by Collection
* Bitlocker - Compliance by Collection (MBAM)
* Bitlocker - Compliance by Collection
* Operating System - Version Compliance by Collection
* Operating System - Windows 11 Readiness by Collection
* Package - Compliance by Collection
* Package - Compliance by Deployment
* Site - Alerts
* Software Update - CU Compliance by Collection
* Software Update - Compliance by Collection
* Software Update - Compliance by Device
* Software Update - Scan Status by Collection
* Software Update - Update Point Sync Status

## Navigation Tree

```bash
.
+-- (D) _Dashboard - Software Updates
    +-- (C) Device Update Compliance
    |   +-- (R) Software Update - Compliance by Collection
    |       +-- (R) Software Update - Compliance by Device
    |
    +-- (C) Missing updates by Classification
    |   +-- (R) Software Update - Compliance by Collection
    |       +-- (R) Software Update - Compliance by Device
    |
    +-- (C) Device Update Agent Scan States
    |   +-- (R) Software Update - Scan Status by Collection
    |
    +-- (C) Overall Update Groups Compliance
    |
    +-- (C) Top 5 Devices with Missing Updates by Classification
    |   +-- (R) Software Update - Compliance by Collection
    |       +-- (R) Software Update - Compliance by Device
    |
    +-- (T) Critical Alerts
    |   +-- (R) Site - Alerts
    |
    +-- (T) Last Successful Synchronization Time
        +-- (R) Software Update - Update Point Sync Status
+-- (R) Application - Compliance by Collection
+-- (R) Baseline - Compliance by Collection
+-- (R) Bitlocker - Compliance by Collection * Bitlocker (MBAM)
+-- (R) Bitlocker - Compliance by Collection * Bitlocker
+-- (R) Operating System - Version Compliance by Collection
+-- (R) Operating System - Windows 11 Readiness by Collection
+-- (R) Package - Compliance by Collection
+-- (R) Package - Compliance by Deployment
+-- (R) Software Update - CU Compliance by Collection

## Legend
'()'  - 'to' or 'from' navigation element
'(D)' - Dashboard
'(R)' - Report
'(C)' - Chart
'(T)' - Text
```

## Preview (Not up-to-date)

This preview is not up-to-date, it represents version 2.0.0. A new preview will be available shortly.

[![](https://img.youtube.com/vi/3Ni-DZVA_40/0.jpg)](http://www.youtube.com/watch?v=3Ni-DZVA_40 "MEM.Zone Dashboards")

## Prerequisites

### Discovery

* `l` additional user and device discovery attribute
* `co` additional user and device discovery attribute

>**Notes**
>Run the user and device discovery after adding the `l` and `co` attributes.

### Software

* Microsoft Endpoint Management Configuration Manager (ConfigMgr) with Windows Update Services (WSUS) integration.
* Microsoft SQL Server Reporting Services (SSRS) 2017 or above.
* Microsoft SQL [Compatibility Level](https://docs.microsoft.com/en-us/sql/t-sql/statements/alter-database-transact-sql-compatibility-level?view=sql-server-ver15) 130 or above.

### SQL User Defined Functions (UDF)

* `ufn_CM_GetNextMaintenanceWindow` helper function (Optional)

### SQL SELECT Rights for smsschm_users (CM Reporting)

* `ufn_CM_GetNextMaintenanceWindow`
* `ufn_CM_GetNextMaintenanceWindowForDevice`
* `ufn_CM_GetNextMaintenanceWindowForCollection`
* `ufn_CM_DeviceIPAddress`
* `ufn_CM_DeviceOSInfo`
* `fnListAlerts`
* `vSMS_ServiceWindow`
* `vSMS_SUPSyncStatus`

>**Notes**
> You can find the code that automatically grants SELECT rights to the functions and tables above in the `perm_CMDatabase.sql`  file.

## Installation - Automatic

Use the provided PowerShell installer. You can find the standalone repository for the installer [here](https://MEMZ.one/Install-SRSReport-RELEASES).

```PowerShell
## Get syntax help
Get-Help .\Install-SRSReport.ps1

## Typical installation example
#  With extensions
.\Install-SRSReport.ps1 -ReportServerUri 'http://CM-SQL-RS-01A/ReportServer' -ReportFolder '/ConfigMgr_XXX/SRSDashboards' -ServerInstance 'CM-SQL-RS-01A' -Database 'CM_XXX' -Overwrite -Verbose
#  Without extensions (Permissions will still be granted on prerequisite views and tables)
.\Install-SRSReport.ps1 -ReportServerUri 'http://CM-SQL-RS-01A/ReportServer' -ReportFolder '/ConfigMgr_XXX/SRSDashboards' -ServerInstance 'CM-SQL-RS-01A' -Database 'CM_XXX' -ExcludeExtensions -Verbose
#  Extensions only
.\Install-SRSReport.ps1 -ServerInstance 'CM-SQL-RS-01A' -Database 'CM_XXX' -ExtensionsOnly -Overwrite -Verbose
```

>**Notes**
> If you don't use `Windows Authentication` (you should!) in your SQL server you can use the `-UseSQLAuthentication` switch.
> PowerShell script needs to be run as administrator.
> If you have problems installing the SQL extensions run the script on the SQL server directly and specify the `-ExtensionsOnly` switch. If this still doesn't work check out the [`Manual Installation Steps`](#Create-the-SQL-Helper-Function).

## Installation - Manual

Upload reports to SSRS, update the datasource, grant the necessary permissions and optionally install the helper function.

### Upload Reports to SSRS

* Start Internet Explorer and navigate to [`http://<YOUR_REPORT_SERVER_FQDN>/Reports`](http://en.wikipedia.org/wiki/Fully_qualified_domain_name)
* Choose a path and upload the three report files.

>**Notes**
> Reports must be placed in the same folder on the report server.

### Configure Imported Report

* Replace the [`DataSource`](https://joshheffner.com/how-to-import-additional-software-update-reports-in-sccm/) in the reports.

### Create the SQL Helper Function

The `ufn_CM_GetNextMaintenanceWindow` is needed in order to display the next maintenance window.

* Copy paste the `ufn_CM_GetNextMaintenanceWindow` in [`SSMS`](https://docs.microsoft.com/en-us/sql/ssms/sql-server-management-studio-ssms?view=sql-server-2017)
* Uncomment the `SMS region` and change the `<SITE_CODE>` in the `USE` statement to match your Site Code.
* Click `Execute` to add the `ufn_CM_GetNextMaintenanceWindow` function to your database.
* Copy paste the `perm_CMDatabase.sql` in [`SSMS`](https://docs.microsoft.com/en-us/sql/ssms/
* Click `Execute` to add the necessary permissions to your database.

> **Notes**
> You need to have access to add the function and grant SELECT on `ufn_CM_GetNextMaintenanceWindow`, `fnListAlerts`, `vSMS_ServiceWindow` and `vSMS_SUPSyncStatus` for the `smsschm_users` (ConfigMgr reporting).
> If the `ufn_CM_GetNextMaintenanceWindow` is not present you will get a 'Missing helper function!' instead of the next maintenance window.
> To resolve the error codes, or get more info, just hover over the table cell.

## Build

This repository includes a build script that automates the process of preparing the dashboards and reports for distribution

### Build Prerequisites

* PowerShell 5.0 or later
* Internet connection (for downloading latest `Install-SRSReport.ps1` and `Dependencies`)

### Instructions

* `build/Build-Script.ps1`  - The main build script
* `build/Build-Config.json` - Configuration file with build settings

### Build Script

This uses the default `Build-Config.json` configuration file and creates a versioned zip file in the `output/` directory.

```powershell
.\Build-Script.ps1

## Build with Custom Version override
.\Build-Script.ps1 -Version '6.2.0'
```

### Build Process

* Downloads `Install-SSRSReport.ps1` and `Dependencies` from the latest release
* Cleans sensitive data from reports and SQL files
* Updates version information in all report files and zip file
* Copies the docs folder
* Generates zip distribution file with format `MEM.Zone-Dashboards_v[Version].zip`

### Build Output

* `MEM.Zone-Dashboards/` - Distribution files
* `output/MEM.Zone-Dashboards_v[Version].zip` - Compressed distribution package

[release-version-badge]: https://img.shields.io/github/v/release/MEM-Zone/MEM.Zone-Dashboards
[release-version]: https://github.com/MEM-Zone/MEM.Zone-Dashboards/releases
[release-date-badge]: https://img.shields.io/github/release-date-pre/MEM-Zone/MEM.Zone-Dashboards
[release-date]: https://github.com/MEM-Zone/MEM.Zone-Dashboards/releases
[issues-badge]: https://img.shields.io/github/issues/MEM-Zone/MEM.Zone-Dashboards
[issues]: https://github.com/MEM-Zone/MEM.Zone-Dashboards/issues?q=is%3Aopen+is%3Aissue
[commits-since-badge]: https://img.shields.io/github/commits-since/MEM-Zone/MEM.Zone-Dashboards/latest.svg
[commits-since]: https://github.com/MEM-Zone/MEM.Zone-Dashboards/commits/master
[discord-badge]: https://img.shields.io/discord/666618982844989460?logo=discord
[discord]: https://discord.gg/ZCkVcmP
[x-badge]: https://img.shields.io/twitter/follow/ioanpopovici?style=social&logo=x
[x]: https://x.com/intent/follow?screen_name=ioanpopovici
