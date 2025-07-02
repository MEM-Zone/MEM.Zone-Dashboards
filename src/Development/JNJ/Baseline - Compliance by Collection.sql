/*
.SYNOPSIS
    This SQL Query is used to get the Compliance of a Configuration Baseline.
.DESCRIPTION
    This SQL Query is used to get the Compliance of a Configuration Baseline by Collection.
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
--DECLARE @UserSIDs     NVARCHAR(16) = 'Disabled';
--DECLARE @CollectionID NVARCHAR(16) = 'SMS0001';
--DECLARE @Compliant    NVARCHAR(10) = 'Yes';
--DECLARE @LocaleID     INT          = 2;
--DECLARE @BaselineID   INT          = 558758

USE CM_JNJ --Stupidity Workaround

/* Perform cleanup */
IF OBJECT_ID(N'tempdb..#CIComplianceStatusDetails', N'U')  IS NOT NULL DROP TABLE #CIComplianceStatusDetails;

/* Get configuration item current value for collection members and insert the result in a temporary table */
;
WITH ComplianceDetails_CTE
AS (
    SELECT DISTINCT
        ResourceID              = CIComplianceStatusDetails.ResourceID
        , CBVersion             = CIComplianceStatusDetails.CIVersion
        , CurrentValue          = CIComplianceStatusDetails.CurrentValue
        , LastStatusMessageTime = CIComplianceStatusDetails.LastComplianceMessageTime
    FROM fn_rbac_CIComplianceStatusDetail(@UserSIDs) AS CIComplianceStatusDetails
    WHERE
        CIComplianceStatusDetails.CI_ID IN (
            SELECT CIRelation.ReferencedCI_ID
            FROM dbo.fn_rbac_CIRelation_All(@UserSIDs) AS CIRelation
            WHERE CI_ID = @BaselineID
                AND CIRelation.RelationType NOT IN ('7', '0') --Exclude itself and no relation
    )
)
SELECT
    ComplianceDetails_CTE.ResourceID,
    ComplianceDetails_CTE.CBVersion,
    ComplianceDetails_CTE.CurrentValue,
    ComplianceDetails_CTE.LastStatusMessageTime
INTO #CIComplianceStatusDetails
FROM ComplianceDetails_CTE
    JOIN fn_rbac_ClientCollectionMembers(@UserSIDs) AS CollectionMembers ON CollectionMembers.ResourceID = ComplianceDetails_CTE.ResourceID
WHERE
    CollectionMembers.CollectionID = @CollectionID

/* Get the other details and join with them with the temporary table based on ResourceID */
;
WITH ComplianceStatus_CTE
AS (
    SELECT
        Systems.ResourceID
        , Compliant        = (
            CASE
                WHEN CIComplianceState.ComplianceStateName = 'Compliant'     THEN 'Yes'
                WHEN CIComplianceState.ComplianceStateName = 'Non-Compliant' THEN 'No'
                WHEN CIComplianceState.ComplianceStateName = 'Error'         THEN 'Error'
                ELSE 'Unknown'
            END
        )
        , Device           = (
            IIF(
                SystemNames.Resource_Names0 IS NULL
                , IIF(Systems.Full_Domain_Name0 IS NULL, Systems.Name0, Systems.Name0 + N'.' + Systems.Full_Domain_Name0)
                , UPPER(SystemNames.Resource_Names0)
            )
        )
        , ADSite           = Systems.AD_Site_Name0
        , CIVersion        = CIComplianceState.CIVersion
        , CurrentValue     = CIComplianceStatusDetails.CurrentValue
        , ClientState      = IIF(Systems.Client0 = 1, ISNULL(ClientSummary.ClientStateDescription, 'Unknown'), 'Unmanaged')
        , ClientVersion    = Systems.Client_Version0
        , LastStatusTime   = CONVERT(NVARCHAR(16), CIComplianceState.LastComplianceMessageTime, 120)
    FROM fn_rbac_FullCollectionMembership(@UserSIDs) AS CollectionMembers
        LEFT JOIN fn_rbac_RA_System_ResourceNames(@UserSIDs) AS SystemNames ON SystemNames.ResourceID = CollectionMembers.ResourceID
        LEFT JOIN fn_rbac_R_System(@UserSIDs) AS Systems ON Systems.ResourceID = CollectionMembers.ResourceID
        LEFT JOIN v_GS_WORKSTATION_STATUS AS ComputerStatus ON ComputerStatus.ResourceID = CollectionMembers.ResourceID
        LEFT JOIN fn_rbac_CH_ClientSummary(@UserSIDs) AS ClientSummary ON ClientSummary.ResourceID = CollectionMembers.ResourceID
        FULL JOIN dbo.fn_rbac_ListCI_ComplianceState(@Locale, @UserSIDs) AS CIComplianceState ON CIComplianceState.ResourceID = CollectionMembers.ResourceID
            AND CIComplianceState.CI_ID = @BaselineID
        FULL JOIN #CIComplianceStatusDetails AS CIComplianceStatusDetails ON CIComplianceStatusDetails.ResourceID = CollectionMembers.ResourceID
    WHERE
        CollectionMembers.CollectionID = @CollectionID
)
SELECT
    ComplianceStatus_CTE.ResourceID
    , ComplianceStatus_CTE.Compliant
    , ComplianceStatus_CTE.Device
    , ComplianceStatus_CTE.ADSite
    , ComplianceStatus_CTE.CIVersion
    , ComplianceStatus_CTE.CurrentValue
    , ComplianceStatus_CTE.ClientState
    , ComplianceStatus_CTE.ClientVersion
    , ComplianceStatus_CTE.LastStatusTime
FROM ComplianceStatus_CTE
WHERE
    ComplianceStatus_CTE.Compliant IN (@Compliant)

/* Perform cleanup */
DROP TABLE #CIComplianceStatusDetails;

/* #endregion */
/*##=============================================*/
/*## END QUERY BODY                              */
/*##=============================================*/