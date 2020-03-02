/*
.SYNOPSIS
    Gets the software update compliance for a Collection in SCCM.
.DESCRIPTION
    Gets the software update compliance in SCCM by Collection and All Updates.
.NOTES
    Requires SQL 2012 R2.
    Requires ufn_CM_GetNextMaintenanceWindow sql helper function in order to display the next maintenance window.
    Requires SELECT access on vSMS_AutoDeployments for smsschm_users (SCCM Reporting).
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
-- DECLARE @Locale                AS INT           = 2;
-- DECLARE @Categories            AS NVARCHAR(250) = 'Tools';
-- DECLARE @Compliant             AS INT           = 0;
-- DECLARE @Targeted              AS INT           = 1;
-- DECLARE @Superseded            AS INT           = 0;
-- DECLARE @ArticleID             AS NVARCHAR(10)  = '';
-- DECLARE @ExcludeArticleIDs     AS NVARCHAR(250) = '';

/* Variable declaration */
DECLARE @LCID                  AS INT = dbo.fn_LShortNameToLCID(@Locale);
DECLARE @HelperFunctionExists  AS INT = 0;

/* Perform cleanup */
IF OBJECT_ID('tempdb..#MaintenanceInfo', 'U') IS NOT NULL
    DROP TABLE #MaintenanceInfo;

/* Check for helper function */
IF OBJECT_ID('[dbo].[ufn_CM_GetNextMaintenanceWindow]') IS NOT NULL
    SET @HelperFunctionExists = 1;

/* Initialize HealthState descriptor table */
DECLARE @HealthState TABLE (
    BitMask     INT
    , StateName NVARCHAR(250)
)

/* Populate HealthState table */
INSERT INTO @HealthState (BitMask, StateName)
VALUES
    ('0',     'Healthy')
    , ('1',   'Unmanaged')
    , ('2',   'Inactive')
    , ('4',   'Health Evaluation Failed')
    , ('8',   'Pending Restart')
    , ('16',  'Update Scan Failed')
    , ('32',  'Update Scan Late')
    , ('64',  'No Maintenance Window')
    , ('128', 'Distant Maintenance Window')

/* Initialize ClientState descriptor table */
DECLARE @ClientState TABLE (
    BitMask     INT
    , StateName NVARCHAR(100)
)

/* Populate ClientState table */
INSERT INTO @ClientState (BitMask, StateName)
VALUES
    ('0', 'No Reboot')
    , ('1', 'Configuration Manager')
    , ('2', 'File Rename')
    , ('4', 'Windows Update')
    , ('8', 'Add or Remove Feature')

CREATE TABLE #MaintenanceInfo (
    ResourceID          INT
    , NextServiceWindow DATETIME
)

/* Get maintenance data */
IF @HelperFunctionExists = 1
    BEGIN
        WITH Maintenance_CTE AS (
            SELECT
                CollectionMembers.ResourceID
                , NextServiceWindow.Duration
                , NextServiceWindow.NextServiceWindow
                , RowNumber             = DENSE_RANK() OVER (PARTITION BY ResourceID ORDER BY NextServiceWindow.NextServiceWindow)
                , ServiceWindowType
                , ServiceWindow.Enabled
            FROM vSMS_ServiceWindow AS ServiceWindow
                JOIN fn_rbac_FullCollectionMembership(@UserSIDs) AS CollectionMembers ON CollectionMembers.CollectionID = ServiceWindow.SiteID
                JOIN fn_rbac_Collection(@UserSIDs) AS Collections ON Collections.CollectionID = CollectionMembers.CollectionID
                    AND Collections.CollectionType = 2                           -- Device Collections
                CROSS APPLY ufn_CM_GetNextMaintenanceWindow(ServiceWindow.Schedules, ServiceWindow.RecurrenceType) AS NextServiceWindow
            WHERE  NextServiceWindow.NextServiceWindow IS NOT NULL
                AND ServiceWindowType <> 5 -- OSD Service
        )

        /* Populate MaintenanceInfo table and remove duplicates */
        INSERT INTO #MaintenanceInfo(ResourceID, NextServiceWindow)
        SELECT
            ResourceID
            , NextServiceWindow
        FROM Maintenance_CTE
        WHERE RowNumber = 1
    END

/* Get update data */
;
WITH UpdateInfo_CTE
AS (
    SELECT
        ResourceID      = Systems.ResourceID
        , Missing       = COUNT(*)
    FROM fn_rbac_R_System(@UserSIDs) AS Systems
        JOIN fn_rbac_UpdateComplianceStatus(@UserSIDs) AS ComplianceStatus ON ComplianceStatus.ResourceID = Systems.ResourceID
            AND ComplianceStatus.Status = 2                                      -- Filter on 'Required' (0 = Unknown, 1 = NotRequired, 2 = Required, 3 = Installed)
        JOIN fn_rbac_ClientCollectionMembers(@UserSIDs) AS CollectionMembers ON CollectionMembers.ResourceID = ComplianceStatus.ResourceID
        JOIN fn_rbac_UpdateInfo(@LCID, @UserSIDs) AS UpdateCIs ON UpdateCIs.CI_ID = ComplianceStatus.CI_ID
            AND UpdateCIs.IsSuperseded IN (@Superseded)
            AND UpdateCIs.CIType_ID IN (1, 8)                                    -- Filter on 1 Software Updates, 8 Software Update Bundle (v_CITypes)
            AND UpdateCIs.ArticleID NOT IN (                                     -- Filter on ArticleID csv list
                SELECT VALUE FROM STRING_SPLIT(@ExcludeArticleIDs, ',')
            )
            AND UpdateCIs.Title NOT LIKE (                                       -- Filter Preview updates
                '[1-9][0-9][0-9][0-9]-[0-9][0-9]_Preview_of_%'
            )
        JOIN fn_rbac_CICategoryInfo_All(@LCID, @UserSIDs) AS CICategory ON CICategory.CI_ID = ComplianceStatus.CI_ID
            AND CICategory.CategoryTypeName = 'UpdateClassification'
            AND CICategory.CategoryInstanceName IN (@Categories)                 -- Filter on Selected Update Classification Categories
        LEFT JOIN fn_rbac_CITargetedMachines(@UserSIDs) AS Targeted ON Targeted.ResourceID = ComplianceStatus.ResourceID
            AND Targeted.CI_ID = ComplianceStatus.CI_ID
    WHERE CollectionMembers.CollectionID = @CollectionID
        AND IIF(Targeted.ResourceID IS NULL, 0, 1) IN (@Targeted)                -- Filter on 'Targeted' or 'NotTargeted'
        AND IIF(UpdateCIs.ArticleID = @ArticleID, 1, 0) = IIF(@ArticleID <> '', 1, 0)
    GROUP BY
        Systems.ResourceID
)

/* Get device info */
SELECT
    Systems.ResourceID

    /* Set Health states. You can find the coresponding values in the HealthState table above */
    , HealthStates      = (
        IIF(CombinedResources.IsClient != 1, POWER(1, 1), 0)
        +
        IIF(
            ClientSummary.ClientStateDescription = 'Inactive/Pass'
            OR
            ClientSummary.ClientStateDescription = 'Inactive/Fail'
            OR
            ClientSummary.ClientStateDescription = 'Inactive/Unknown'
            , POWER(2, 1), 0)
        +
        IIF(
            ClientSummary.ClientStateDescription = 'Active/Fail'
            OR
            ClientSummary.ClientStateDescription = 'Inactive/Fail'
            , POWER(4, 1), 0
        )
        +
        IIF(CombinedResources.ClientState != 0, POWER(8, 1), 0)
        +
        IIF(UpdateScan.LastErrorCode != 0, POWER(16, 1), 0)
        +
        IIF(UpdateScan.LastScanTime < (SELECT DATEADD(dd, -14, CURRENT_TIMESTAMP)), POWER(32, 1), 0)
        +
        IIF(ISNULL(NextServiceWindow, 0) = 0 AND @HelperFunctionExists = 1, POWER(64, 1), 0)
        +
        IIF(NextServiceWindow > (SELECT DATEADD(dd, 30, CURRENT_TIMESTAMP)), POWER(128, 1), 0)
    )
    , Missing           = ISNULL(Missing, (IIF(CombinedResources.IsClient = 1, 0, NULL)))
    , Device            = (
            IIF(
                SystemNames.Resource_Names0 IS NOT NULL, UPPER(SystemNames.Resource_Names0)
                , IIF(Systems.Full_Domain_Name0 IS NOT NULL, Systems.Name0 + '.' + Systems.Full_Domain_Name0, Systems.Name0)
            )
    )
    , OperatingSystem   = (
        CASE
            WHEN OperatingSystem.Caption0 != '' THEN
                CONCAT(
                    REPLACE(OperatingSystem.Caption0, 'Microsoft ', ''),          -- Remove 'Microsoft ' from OperatingSystem
                    REPLACE(OperatingSystem.CSDVersion0, 'Service Pack ', ' SP')  -- Replace 'Service Pack ' with ' SP' in OperatingSystem
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
    , LastBootTime      = (
        CONVERT(NVARCHAR(16), OperatingSystem.LastBootUpTime0, 120)
    )
    , PendingRestart    = (
        CASE
            WHEN CombinedResources.IsClient      = 0
                OR CombinedResources.ClientState = 0
            THEN NULL
            ELSE (
                STUFF(
                    REPLACE(
                        (
                            SELECT '#!' + LTRIM(RTRIM(StateName)) AS [data()]
                            FROM @ClientState
                            WHERE BitMask & CombinedResources.ClientState <> 0
                            FOR XML PATH('')
                        ),
                        ' #!',', '
                    ),
                    1, 2, ''
                )
            )
        END
    )
    , ClientState       = (
        CASE CombinedResources.IsClient
            WHEN 1 THEN ClientSummary.ClientStateDescription
            ELSE 'Unmanaged'
        END
    )
    , ClientVersion     = CombinedResources.ClientVersion
    , LastUpdateScan    = (
        CONVERT(NVARCHAR(16), UpdateScan.LastScanTime, 120)
    )
    , LastScanLocation  = NULLIF(UpdateScan.LastScanPackageLocation, '')
    , LastScanError     = NULLIF(UpdateScan.LastErrorCode, 0)
    , NextServiceWindow = IIF(CombinedResources.IsClient != 1, NULL, CONVERT(NVARCHAR(16), NextServiceWindow, 120))
FROM fn_rbac_R_System(@UserSIDs) AS Systems
    JOIN fn_rbac_CombinedDeviceResources(@UserSIDs) AS CombinedResources ON CombinedResources.MachineID = Systems.ResourceID
    LEFT JOIN fn_rbac_RA_System_ResourceNames(@UserSIDs) AS SystemNames ON SystemNames.ResourceID = Systems.ResourceID
    LEFT JOIN fn_rbac_GS_OPERATING_SYSTEM(@UserSIDs) AS OperatingSystem ON OperatingSystem.ResourceID = Systems.ResourceID
    LEFT JOIN fn_rbac_CH_ClientSummary(@UserSIDs) AS ClientSummary ON ClientSummary.ResourceID = Systems.ResourceID
    LEFT JOIN fn_rbac_UpdateScanStatus(@UserSIDs) AS UpdateScan ON UpdateScan.ResourceID = Systems.ResourceID
    LEFT JOIN #MaintenanceInfo AS Maintenance ON Maintenance.ResourceID = Systems.ResourceID
    LEFT JOIN UpdateInfo_CTE AS UpdateInfo ON UpdateInfo.ResourceID = Systems.ResourceID
    JOIN fn_rbac_FullCollectionMembership(@UserSIDs) AS CollectionMembers ON CollectionMembers.ResourceID = Systems.ResourceID
WHERE CollectionMembers.CollectionID = @CollectionID
    AND (
        CASE                                                                     -- Compliant (0 = No, 1 = Yes, 2 = Unknown)
            WHEN Missing = 0 OR (Missing IS NULL AND Systems.Client0 = 1) THEN 1 -- Yes
            WHEN Missing > 0 AND Missing IS NOT NULL                      THEN 0 -- No
            ELSE 2                                                               -- Unknown
        END
    ) IN (@Compliant)

/* Perform cleanup */
IF OBJECT_ID('tempdb..#MaintenanceInfo', 'U') IS NOT NULL
    DROP TABLE #MaintenanceInfo;

/* #endregion */
/*##=============================================*/
/*## END QUERY BODY                              */
/*##=============================================*/