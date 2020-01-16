/*
.SYNOPSIS
    Summarizes the software update group compliance in SCCM.
.DESCRIPTION
    Summarizes the software update group compliance for a Collection in SCCM.
.NOTES
    Part of a report should not be run separately.
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

/* Testing variables !! Need to be commented for Production !! */
-- DECLARE @UserSIDs     AS NVARCHAR(10) = 'Disabled';
-- DECLARE @CollectionID AS NVARCHAR(10) = 'ULB00022';
-- DECLARE @Locale       AS INT          = 2;

/* Variable declaration */
DECLARE @LCID         AS INT = dbo.fn_LShortNameToLCID(@Locale);

SELECT
   AuthList.Title

   /* 0 = Unknown, 1 = Installed, 2 = Required, 3 = Not Required */
   , Compliant    = SUM(IIF(ComplianceStatus.Status = 3 OR ComplianceStatus.Status = 1, 1, 0))
   , NonCompliant = SUM(IIF(ComplianceStatus.Status = 2, 1, 0))
   , Unknown      = SUM(IIF(ComplianceStatus.Status = 0, 1, 0))
   , TotalDevices = Count(*)
FROM fn_rbac_Update_ComplianceStatusAll(@UserSIDs) AS ComplianceStatus
    JOIN fn_rbac_AuthListInfo(@LCID, @UserSIDs) AS AuthList ON AuthList.CI_ID = ComplianceStatus.CI_ID
    JOIN fn_rbac_FullCollectionMembership(@UserSIDs) AS CollectionMembers ON CollectionMembers.ResourceID = ComplianceStatus.ResourceID
WHERE CollectionMembers.CollectionID = @CollectionID
GROUP BY
    Title
    , ComplianceStatus.CI_ID

/* #endregion */
/*##=============================================*/
/*## END QUERY BODY                              */
/*##=============================================*/