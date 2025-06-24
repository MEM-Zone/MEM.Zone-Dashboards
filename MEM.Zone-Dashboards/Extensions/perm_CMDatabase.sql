/*
.SYNOPSIS
    Grants SQL permissions for report prerequisites.
.DESCRIPTION
    Grants SQL permissions for report prerequisites.
.EXAMPLE
    Run in SQL Server Management Studio (SSMS).
.NOTES
    Created by Ioan Popovici
    Replace the <SITE_CODE> with your CM Site Code and uncomment SSMS region if running directly from SSMS.
.LINK
    https://MEMZ.one/Dashboards
.LINK
    https://MEMZ.one/Dashboards-HELP
.LINK
    https://MEMZ.one/Dashboards-ISSUES
*/

/*##=============================================*/
/*## QUERY BODY                                  */
/*##=============================================*/
/* #region QueryBody */

/* #region SSMS */
--USE [CM_<SITE_CODE>]
--GO
/* #endregion */

/* #region Grant Permissions */
/* Grant select rights to CM reporting users */
GRANT SELECT ON OBJECT::dbo.ufn_CM_GetNextMaintenanceWindow TO smsschm_users;
GRANT SELECT ON OBJECT::dbo.ufn_CM_GetNextMaintenanceWindowForDevice TO smsschm_users;
GRANT SELECT ON OBJECT::dbo.ufn_CM_GetNextMaintenanceWindowForCollection TO smsschm_users;
GRANT SELECT ON OBJECT::dbo.ufn_CM_DeviceIPAddress TO smsschm_users;
GRANT SELECT ON OBJECT::dbo.ufn_CM_DeviceOSInfo TO smsschm_users;
GRANT SELECT ON OBJECT::dbo.fnListAlerts TO smsschm_users;
GRANT SELECT ON OBJECT::dbo.vSMS_ServiceWindow TO smsschm_users;
GRANT SELECT ON OBJECT::dbo.vSMS_SUPSyncStatus TO smsschm_users;
/* #endregion */

/* #endregion */
/*##=============================================*/
/*## END QUERY BODY                              */
/*##=============================================*/