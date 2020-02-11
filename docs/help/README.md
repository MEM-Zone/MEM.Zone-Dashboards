# Readme for CM SRS Dashboards

## Latest release

See [releases](https://SCCM.Zone/CM-SRS-Dashboards-RELEASES).

## Changelog

See [changelog](https://SCCM.Zone/CM-SRS-Dashboards-CHANGELOG).

## Dashboards and Reports

* SU DAS Overall Compliance (Main Dashboard Report)
* AL Alerts
* SU Compliance by Collection
* SU Compliance by Device
* SU Scan Status
* SU SUP Sync Status

>**Notes**
> Reports can be run independently.

## Credit

* Adam Weigert [`ufn_CM_GetNextMaintenanceWindow`](https://social.technet.microsoft.com/wiki/contents/articles/7870.sccm-2007-create-report-of-upcoming-maintenance-windows-by-client.aspx)

## Prerequisites

### Software

* Microsoft Endpoint Management Configuration Manager (MEMCM) with Windows Update Services (WSUS) integration.
* Microsoft SQL Server Reporting Services (SSRS) 2017 or above.

### SQL User Defined Funtions (UDF)

* `ufn_CM_GetNextMaintenanceWindow` helper function (Optional)

### SQL SELECT Rights for smsschm_users (CM Reporting)

* `ufn_CM_GetNextMaintenanceWindow`
* `fnListAlerts`
* `vSMS_ServiceWindow`
* `vSMS_SUPSyncStatus`

>**Notes**
> You can find the code that automatically grants SELECT rights to the functions and tables above in the `perm_CMDatabase.sql`  file.

## Installation - Automatic

Use the provided powershell installer.

```PowerShell
## Get syntax help
Get-Help .\Install-CMSRSReports.ps1

## Typical installation example
#  With extensions
.\Install-CMSRSReports.ps1 -ReportServerUri 'http://CM-SQL-RS-01A/ReportServer' -ReportFolder '/ConfigMgr_XXX/SRSDashboards' -ServerInstance 'CM-SQL-RS-01A' -Database 'CM_XXX' -Overwrite -Verbose
#  Without extensions (Permissions will still be granted on prerequisite views and tables)
.\Install-CMSRSReports.ps1 -ReportServerUri 'http://CM-SQL-RS-01A/ReportServer' -ReportFolder '/ConfigMgr_XXX/SRSDashboards' -ServerInstance 'CM-SQL-RS-01A' -Database 'CM_XXX' -ExcludeExtensions -Verbose
#  Extensions only
.\Install-CMSRSReports.ps1 -ServerInstance 'CM-SQL-RS-01A' -Database 'CM_XXX' -ExtensionsOnly -Overwrite -Verbose
```

>**Notes**
> If you don't use `Windows Authentication` (you should!) in your SQL server you can use the `-UseSQLAuthentication` switch.
> PowerShell script needs to be run as administrator.

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
> You need to have access to add the function and grant SELECT on `ufn_CM_GetNextMaintenanceWindow`, `fnListAlerts`, `vSMS_ServiceWindow` and `vSMS_SUPSyncStatus` for the `smsschm_users` (SCCM reporting).
> If the `ufn_CM_GetNextMaintenanceWindow` is not present you will get a 'Missing helper function!' instead of the next maintenance window.
> To resolve the error codes, see the restart reason or health states just hover over the table cell.
