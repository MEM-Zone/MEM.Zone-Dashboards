/*
.SYNOPSIS
    Gets the top 100 unpatched devices for a Collection in SCCM.
.DESCRIPTION
    Gets the top 100 unpatched devices in SCCM by Collection and All Updates.
.NOTES
    Requires SQL 2012 R2.
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
-- DECLARE @UserSIDs              AS NVARCHAR(10)  = 'Disabled';
-- DECLARE @CollectionID          AS NVARCHAR(10)  = 'SMS00001';
-- DECLARE @Locale                AS INT           = '2';
-- DECLARE @UpdateClassifications AS NVARCHAR(250) = 'Security Updates';
-- DECLARE @ExcludeArticleIDs     AS NVARCHAR(250) = '' --('915597,2267602,2461484') -- AV Definitions;

/* Variable declaration */
DECLARE @LCID AS INT = dbo.fn_LShortNameToLCID (@Locale)

/* Get update data */
;
WITH UpdateInfo_CTE
AS (
    SELECT
        ResourceID       = Systems.ResourceID
        , IsUnknown      = COUNT(IIF(ComplianceStatus.Status = 0, '*', NULL))
        , IsMissing      = COUNT(IIF(UpdateCIs.IsExpired     = 0, '*', NULL))
        , IsRequired     = COUNT(*)
        , IsSuperseded   = COUNT(IIF(UpdateCIs.IsSuperseded  = 1 AND UpdateCIs.IsExpired = 0, '*', NULL))
        , IsExpired      = COUNT(IIF(UpdateCIs.IsExpired     = 1, '*', NULL))
        , IsDeployed     = COUNT(IIF(UpdateCIs.IsDeployed    = 1, '*', NULL))
        , IsTargeted     = COUNT(IIF(UpdateCIs.IsExpired     = 0 AND Targeted.ResourceID IS NOT NULL, '*', NULL))
        , IsEnabled      = COUNT(IIF(UpdateCIs.IsEnabled     = 1, '*', NULL))
        , Classification = CICategory.CategoryInstanceName
    FROM fn_rbac_R_System(@UserSIDs) AS Systems
        JOIN v_UpdateComplianceStatus AS ComplianceStatus ON ComplianceStatus.ResourceID = Systems.ResourceID
            AND ComplianceStatus.Status IN (0, 2)                           -- Unknown Required
        JOIN v_ClientCollectionMembers AS CollectionMembers ON CollectionMembers.ResourceID = ComplianceStatus.ResourceID
        JOIN fn_ListUpdateCIs(@LCID) AS UpdateCIs ON UpdateCIs.CI_ID = ComplianceStatus.CI_ID
            AND UpdateCIs.CIType_ID IN (1, 8)                               -- 1 Software Updates, 8 Software Update Bundle (v_CITypes)
            AND UpdateCIs.ArticleID NOT IN (                                -- Exclude Updates based on ArticleID
                SELECT VALUE FROM STRING_SPLIT(@ExcludeArticleIDs, ',')
            )
        JOIN v_CICategoryInfo_All AS CICategory ON CICategory.CI_ID = ComplianceStatus.CI_ID
            AND CICategory.CategoryTypeName = 'UpdateClassification'
            AND CICategory.CategoryInstanceName IN (@UpdateClassifications) -- Join only selected Update Classifications
        LEFT JOIN v_CITargetedMachines AS Targeted ON Targeted.ResourceID = ComplianceStatus.ResourceID
            AND Targeted.CI_ID = ComplianceStatus.CI_ID
    WHERE CollectionMembers.CollectionID = @CollectionID
    GROUP BY
        Systems.ResourceID
        , Systems.Netbios_Name0
        , CICategory.CategoryInstanceName
)

/* Get device info */
SELECT TOP 100
    Systems.ResourceID
    , Device             = IIF(Systems.Full_Domain_Name0 IS NOT NULL, Systems.Name0 + '.' + Systems.Full_Domain_Name0, Systems.Name0)
    , OperatingSystem    = (
        CASE
            WHEN OperatingSystem.Caption0 != '' THEN
                CONCAT(
                    REPLACE(OperatingSystem.Caption0, 'Microsoft ', ''),         -- Remove 'Microsoft ' from OperatingSystem
                    REPLACE(OperatingSystem.CSDVersion0, 'Service Pack ', ' SP') -- Replace 'Service Pack ' with ' SP' in OperatingSystem
                )
            ELSE (

            /* Workaround for systems not in GS_OPERATING_SYSTEM table */
                CASE
                    WHEN CombinedResources.DeviceOS LIKE '%Workstation 6.1%'    THEN 'Windows 7'
                    WHEN CombinedResources.DeviceOS LIKE '%Workstation 6.2%'    THEN 'Windows 8'
                    WHEN CombinedResources.DeviceOS LIKE '%Workstation 6.3%'    THEN 'Windows 8.1'
                    WHEN CombinedResources.DeviceOS LIKE '%Workstation 10.0%'   THEN 'Windows 10'
                    WHEN CombinedResources.DeviceOS LIKE '%Server 6.0'          THEN 'Windows Server 2008'
                    WHEN CombinedResources.DeviceOS LIKE '%Server 6.1'          THEN 'Windows Server 2008R2'
                    WHEN CombinedResources.DeviceOS LIKE '%Server 6.2'          THEN 'Windows Server 2012'
                    WHEN CombinedResources.DeviceOS LIKE '%Server 6.3'          THEN 'Windows Server 2012 R2'
                    WHEN Systems.Operating_System_Name_And0 LIKE '%Server 10%'  THEN (
                        CASE
                            WHEN CAST(REPLACE(Build01, '.', '') AS INTEGER) > 10017763 THEN 'Windows Server 2019'
                            ELSE 'Windows Server 2016'
                        END
                    )
                    ELSE Systems.Operating_System_Name_And0
                END
            )
        END
    )
    , ClientState        = (
        CASE CombinedResources.IsClient
            WHEN 1 THEN ClientSummary.ClientStateDescription
            ELSE 'Unmanaged'
        END
    )
    , Classification     = UpdateInfo.Classification
    , IsMissing          = UpdateInfo.IsMissing
    , IsSuperseded       = UpdateInfo.IsSuperseded
    , IsExpired          = UpdateInfo.IsExpired
    , IsUnknown          = UpdateInfo.IsUnknown
    , IsDeployed         = UpdateInfo.IsDeployed
    , IsTargeted         = UpdateInfo.IsTargeted
    , IsEnabled          = UpdateInfo.IsEnabled
FROM fn_rbac_R_System(@UserSIDs) AS Systems
    JOIN v_CombinedDeviceResources AS CombinedResources ON CombinedResources.MachineID = Systems.ResourceID
    LEFT JOIN v_GS_OPERATING_SYSTEM AS OperatingSystem ON OperatingSystem.ResourceID = Systems.ResourceID
    LEFT JOIN v_CH_ClientSummary AS ClientSummary ON ClientSummary.ResourceID = Systems.ResourceID
    JOIN UpdateInfo_CTE AS UpdateInfo ON UpdateInfo.ResourceID = Systems.ResourceID
    JOIN fn_rbac_FullCollectionMembership(@UserSIDs) AS CollectionMembers ON CollectionMembers.ResourceID = Systems.ResourceID
WHERE CollectionMembers.CollectionID = @CollectionID

/* #endregion */
/*##=============================================*/
/*## END QUERY BODY                              */
/*##=============================================*/