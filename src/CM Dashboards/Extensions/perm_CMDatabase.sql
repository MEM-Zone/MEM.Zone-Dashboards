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
    https://SCCM.Zone/
.LINK
    https://SCCM.Zone/CM-SRS-Dashboards-GIT
.LINK
    https://SCCM.Zone/CM-SRS-Dashboards-ISSUES
*/

/*##=============================================*/
/*## QUERY BODY                                  */
/*##=============================================*/
/* #region QueryBody */

/* #region SSMS */
-- USE [CM_<SITE_CODE>]
-- GO
/* #endregion */

/* #region Grant Permissions */
/* Grant select rights for this function to CM reporting users */
GRANT SELECT ON OBJECT::dbo.ufn_CM_GetNextMaintenanceWindow TO smsschm_users;

/* Grant select right for the fnListAlerts function to CM reporting users */
GRANT SELECT ON OBJECT::dbo.fnListAlerts TO smsschm_users;

/* Grant select right for the vSMS_ServiceWindow view to CM reporting users */
GRANT SELECT ON OBJECT::dbo.vSMS_ServiceWindow TO smsschm_users;

/* Grant select right for the vSMS_SUPSyncStatus view to CM reporting users */
GRANT SELECT ON OBJECT::dbo.vSMS_SUPSyncStatus TO smsschm_users;
/* #endregion */

/* #endregion */
/*##=============================================*/
/*## END QUERY BODY                              */
/*##=============================================*/