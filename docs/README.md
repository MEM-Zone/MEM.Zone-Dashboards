# Readme for CM SRS Dashboards

## Latest release

See [releases](https://SCCM.Zone/CM-SRS-Dashboards-RELEASES).

## Project Tree

Will be added one a later date

## Dashboards and Reports

* SU DAS Overall Compliance
* AL Alerts
* SU Compliance by Collection
* SU Compliance by Device
* SU Scan Status
* SU SUP Sync Status

>**Notes**
> Reports must be placed in the same folder.
> Reports can be run independently.

## Credit

* Adam Weigert [`ufn_CM_GetNextMaintenanceWindow`](https://social.technet.microsoft.com/wiki/contents/articles/7870.sccm-2007-create-report-of-upcoming-maintenance-windows-by-client.aspx)

## Prerequisites

### User Defined Funtions (UDF)

* `ufn_CM_GetNextMaintenanceWindow` helper function (Optional)

### SELECT Rights for smsschm_users (CM Reporting)

* `ufn_CM_GetNextMaintenanceWindow`
* `fnListAlerts`
* `vSMS_ServiceWindow`
* `vSMS_SUPSyncStatus`

>**Notes**
> You can find the code that automatically grants SELECT rights to the functions and tables above at the end of the `ufn_CM_GetNextMaintenanceWindow` helper function.

## Installation

### Upload Reports to SSRS

* Start Internet Explorer and navigate to [`http://<YOUR_REPORT_SERVER_FQDN>/Reports`](http://en.wikipedia.org/wiki/Fully_qualified_domain_name)
* Choose a path and upload the three report files.

### Configure Imported Report

* Replace the [`DataSource`](https://joshheffner.com/how-to-import-additional-software-update-reports-in-sccm/) in the reports.

### Create the SQL Helper Function

The `ufn_CM_GetNextMaintenanceWindow` is needed in order to display the next maintenance window.

* Copy paste the `ufn_CM_GetNextMaintenanceWindow` in [`SSMS`](https://docs.microsoft.com/en-us/sql/ssms/sql-server-management-studio-ssms?view=sql-server-2017)
* Change the `<SITE_CODE>` in the `USE` statement to match your Site Code.
* Click `Execute` to add the `ufn_CM_GetNextMaintenanceWindow` function to your database.

> **Notes**
> You need to have access to add the function and grant SELECT on `ufn_CM_GetNextMaintenanceWindow`, `fnListAlerts`, `vSMS_ServiceWindow` and `vSMS_SUPSyncStatus` for the smsschm_users (SCCM reporting).
> If the `ufn_CM_GetNextMaintenanceWindow` is not present you will get a 'Missing helper function!' instead of the next maintenance window.
> To resolve the error codes, see the restart reason or health states just hover over the table cell.
