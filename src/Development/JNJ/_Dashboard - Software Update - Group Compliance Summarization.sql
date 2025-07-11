/*
.SYNOPSIS
    Summarizes the software update group compliance in ConfigMgr.
.DESCRIPTION
    Summarizes the software update group compliance for a Collection in ConfigMgr.
.NOTES
    Requires SQL 2016.
    Part of a report should not be run separately.
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

/* Testing variables !! Need to be commented for Production !! */
--DECLARE @UserSIDs     AS NVARCHAR(10) = 'SMS0001';
--DECLARE @CollectionID AS NVARCHAR(10) = 'SMS0001';
--DECLARE @Locale       AS INT          = 2;

/* Variable declaration */
USE CM_JNJ; -- Stupidity Workaround
--DECLARE @LCID         AS INT = dbo.fn_LShortNameToLCID(@Locale);
DECLARE @LCID         AS INT = 1033; -- Stupidity Workaround

/* Get Software Update Groups Compliance */
SELECT
   AuthList.Title

   /* 0 = Unknown, 1 = Installed, 2 = Required, 3 = Not Required */
   , Compliant    = SUM(IIF(ComplianceStatus.Status = 3 OR ComplianceStatus.Status = 1, 1, 0))
   , NonCompliant = SUM(IIF(ComplianceStatus.Status = 2, 1, 0))
   , Unknown      = SUM(IIF(ComplianceStatus.Status = 0, 1, 0))
   , TotalDevices = Count(*)
FROM fn_rbac_Update_ComplianceStatusAll(@UserSIDs) AS ComplianceStatus
    JOIN fn_rbac_AuthListInfo(@LCID, @UserSIDs) AS AuthList ON AuthList.CI_ID = ComplianceStatus.CI_ID
    JOIN fn_rbac_ClientCollectionMembers(@UserSIDs) AS CollectionMembers ON CollectionMembers.ResourceID = ComplianceStatus.ResourceID
WHERE CollectionMembers.CollectionID = @CollectionID
GROUP BY
    Title
    , ComplianceStatus.CI_ID

/* #endregion */
/*##=============================================*/
/*## END QUERY BODY                              */
/*##=============================================*/