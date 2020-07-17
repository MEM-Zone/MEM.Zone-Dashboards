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
-- DECLARE @UserSIDs             AS NVARCHAR(10) = 'Disabled';
-- DECLARE @CollectionID         AS NVARCHAR(10) = 'SMS00001';
-- DECLARE @Locale               AS INT          = 2;
-- DECLARE @Categories           AS NVARCHAR(50) = 'Security Updates';
-- DECLARE @Vendors              AS NVARCHAR(50) = 'Microsoft';
-- DECLARE @Compliant            AS INT          = 0;
-- DECLARE @Targeted             AS INT          = 1;
-- DECLARE @Superseded           AS INT          = 0;
-- DECLARE @ArticleID            AS NVARCHAR(10) = '';
-- DECLARE @ExcludeArticleIDs    AS NVARCHAR(50) = '';
-- DECLARE @HealthThresholds     AS NVARCHAR(20) = '45,120,14,40,8';

/* Perform cleanup */
IF OBJECT_ID('tempdb..#MaintenanceInfo', 'U') IS NOT NULL
    DROP TABLE #MaintenanceInfo;

/* Check for helper function */
DECLARE @HelperFunctionExists     AS INT = 0;
IF OBJECT_ID('[dbo].[ufn_CM_GetNextMaintenanceWindow]') IS NOT NULL
    SET @HelperFunctionExists = 1;

/* Variable declaration */
DECLARE @LCID                     AS INT = dbo.fn_LShortNameToLCID(@Locale);

/* Initialize memory tables */
DECLARE @HealthThresholdVariables TABLE (ID INT IDENTITY(1,1), Threshold INT);
DECLARE @HealthState              TABLE (BitMask INT, StateName NVARCHAR(250));
DECLARE @ClientState              TABLE (BitMask INT, StateName NVARCHAR(100));

/* Populate @HealthThresholdVariables table */
INSERT INTO @HealthThresholdVariables (Threshold)
SELECT VALUE FROM STRING_SPLIT(@HealthThresholds, ',')

/* Set Health Threshold variables */
DECLARE @HT_DistantMW             AS INT = (SELECT Threshold FROM @HealthThresholdVariables WHERE ID = 1); -- Days
DECLARE @HT_ShortMW               AS INT = (SELECT Threshold FROM @HealthThresholdVariables WHERE ID = 2); -- Minutes
DECLARE @HT_LastScanTime          AS INT = (SELECT Threshold FROM @HealthThresholdVariables WHERE ID = 3); -- Days
DECLARE @HT_Uptime                AS INT = (SELECT Threshold FROM @HealthThresholdVariables WHERE ID = 4); -- Days
DECLARE @HT_FreeSpace             AS INT = (SELECT Threshold FROM @HealthThresholdVariables WHERE ID = 5); -- GB

/* Populate HealthState table */
INSERT INTO @HealthState (BitMask, StateName)
VALUES
    (0,      N'Healthy')
    , (1,    N'Unmanaged')
    , (2,    N'Inactive')
    , (4,    N'Health Evaluation Failed')
    , (8,    N'Pending Restart')
    , (16,   N'Update Scan Failed')
    , (32,   N'Update Scan Late')
    , (64,   N'No Maintenance Window')
    , (128,  N'Distant Maintenance Window')
    , (256,  N'Short Maintenance Window')
    , (512,  N'Expired Maintenance Window')
    , (1024, N'Disabled Maintenance Window')
    , (2048, N'Uptime Threshold Exeeded')
    , (4096, N'Required VS Uptime')
    , (8192, N'Free Space Threshold Exeeded')

/* Populate ClientState table */
INSERT INTO @ClientState (BitMask, StateName)
VALUES
    (0, N'No Reboot')
    , (1, N'Configuration Manager')
    , (2, N'File Rename')
    , (4, N'Windows Update')
    , (8, N'Add or Remove Feature')

/* Create MaintenanceInfo table */
CREATE TABLE #MaintenanceInfo (
    ResourceID              INT
    , NextServiceWindow     DATETIME
    , ServiceWindowStart    DATETIME
    , ServiceWindowDuration INT
    , ServiceWindowEnabled  INT
)

/* Get maintenance data */
IF @HelperFunctionExists = 1
    BEGIN
        WITH Maintenance_CTE AS (
            SELECT
                ResourceID              = CollectionMembers.ResourceID
                , NextServiceWindow     = NextServiceWindow.NextServiceWindow
                , ServiceWindowStart    = NextServiceWindow.StartTime
                , ServiceWindowDuration = NextServiceWindow.Duration
                , ServiceWindowEnabled  = ServiceWindow.Enabled
                , RowNumber             = DENSE_RANK() OVER (PARTITION BY ResourceID ORDER BY IIF(
                    NextServiceWindow.NextServiceWindow IS NULL, 1, 0), NextServiceWindow.NextServiceWindow, ServiceWindow.ServiceWindowID
                )                                                              -- Order by NextServiceWindow with NULL Values last
            FROM vSMS_ServiceWindow AS ServiceWindow
                JOIN fn_rbac_FullCollectionMembership(@UserSIDs) AS CollectionMembers ON CollectionMembers.CollectionID = ServiceWindow.SiteID
                JOIN fn_rbac_Collection(@UserSIDs) AS Collections ON Collections.CollectionID = CollectionMembers.CollectionID
                    AND Collections.CollectionType = 2                         -- Device Collections
                CROSS APPLY ufn_CM_GetNextMaintenanceWindow(ServiceWindow.Schedules, ServiceWindow.RecurrenceType) AS NextServiceWindow
            WHERE ServiceWindowType <> 5                                       -- OSD Maintenance Windows
        )

        /* Populate MaintenanceInfo table and remove duplicates */
        INSERT INTO #MaintenanceInfo(ResourceID, NextServiceWindow, ServiceWindowStart, ServiceWindowDuration, ServiceWindowEnabled)
            SELECT
                ResourceID
                , NextServiceWindow
                , ServiceWindowStart
                , ServiceWindowDuration = IIF(NextServiceWindow IS NULL, NULL, ServiceWindowDuration)
                , ServiceWindowEnabled  = IIF(NextServiceWindow IS NULL, NULL, ServiceWindowEnabled)
            FROM Maintenance_CTE
            WHERE RowNumber = 1
    END

/* Get update data */
;
WITH UpdateInfo_CTE
AS (
    SELECT
        ResourceID       = Systems.ResourceID
        , Missing        = COUNT(*)
    FROM fn_rbac_R_System(@UserSIDs) AS Systems
        JOIN fn_rbac_UpdateComplianceStatus(@UserSIDs) AS ComplianceStatus ON ComplianceStatus.ResourceID = Systems.ResourceID
            AND ComplianceStatus.Status = 2                                    -- Filter on 'Required' (0 = Unknown, 1 = NotRequired, 2 = Required, 3 = Installed)
        JOIN fn_rbac_ClientCollectionMembers(@UserSIDs) AS CollectionMembers ON CollectionMembers.ResourceID = ComplianceStatus.ResourceID
        JOIN fn_rbac_UpdateInfo(@LCID, @UserSIDs) AS UpdateCIs ON UpdateCIs.CI_ID = ComplianceStatus.CI_ID
            AND UpdateCIs.IsSuperseded IN (@Superseded)
            AND UpdateCIs.CIType_ID IN (1, 8)                                  -- Filter on 1 Software Updates, 8 Software Update Bundle (v_CITypes)
            AND UpdateCIs.ArticleID NOT IN (                                   -- Filter on ArticleID csv list
                SELECT VALUE FROM STRING_SPLIT(@ExcludeArticleIDs, ',')
            )
            AND UpdateCIs.Title NOT LIKE (                                     -- Filter Preview updates
                N'[1-9][0-9][0-9][0-9]-[0-9][0-9]_Preview_of_%'
            )
        JOIN fn_rbac_CICategoryInfo_All(@LCID, @UserSIDs) AS CICategoryCompany ON CICategoryCompany.CI_ID = UpdateCIs.CI_ID
            AND CICategoryCompany.CategoryTypeName = N'Company'
            AND CICategoryCompany.CategoryInstanceName IN (@Vendors)           -- Filter on Selected Update Vendors
        JOIN fn_rbac_CICategoryInfo_All(@LCID, @UserSIDs) AS CICategory ON CICategory.CI_ID = UpdateCIs.CI_ID
            AND CICategory.CategoryTypeName = N'UpdateClassification'
            AND CICategory.CategoryInstanceName IN (@Categories)               -- Filter on Selected Update Classification Categories
        LEFT JOIN fn_rbac_CITargetedMachines(@UserSIDs) AS Targeted ON Targeted.ResourceID = ComplianceStatus.ResourceID
            AND Targeted.CI_ID = ComplianceStatus.CI_ID
    WHERE CollectionMembers.CollectionID = @CollectionID
        AND IIF(Targeted.ResourceID IS NULL, 0, 1) IN (@Targeted)              -- Filter on 'Targeted' or 'NotTargeted'
        AND IIF(UpdateCIs.ArticleID = @ArticleID, 1, 0) = IIF(@ArticleID <> '', 1, 0)
    GROUP BY Systems.ResourceID
)

/* Get device info */
SELECT Systems.ResourceID

    /* Set Health states. You can find the coresponding values in the HealthState table above */
    , HealthStates       = (
        -- Client Unmanaged
        IIF(CombinedResources.IsClient != 1, POWER(1, 1), 0)
        -- Client Inactive
        +
        IIF(
            ClientSummary.ClientStateDescription = N'Inactive/Pass'
                OR ClientSummary.ClientStateDescription = N'Inactive/Fail'
                OR ClientSummary.ClientStateDescription = N'Inactive/Unknown'
            , POWER(2, 1), 0
        )
        -- Client Health Evaluation Failed
        +
        IIF(
            ClientSummary.ClientStateDescription = N'Active/Fail'
                OR ClientSummary.ClientStateDescription = N'Inactive/Fail'
            , POWER(4, 1), 0
        )
        -- Pending Restart
        +
        IIF(CombinedResources.ClientState != 0, POWER(8, 1), 0)
        -- Update Scan Failed
        +
        IIF(UpdateScan.LastErrorCode != 0, POWER(16, 1), 0)
        -- Update Scan Late
        +
        IIF(UpdateScan.LastScanTime < (SELECT DATEADD(dd, -@HT_LastScanTime, CURRENT_TIMESTAMP)), POWER(32, 1), 0)
        -- No Maintenance Window
        +
        IIF(
            ISNULL(NextServiceWindow, 0) = 0
                AND @HelperFunctionExists = 1
                AND ServiceWindowStart IS NULL
                AND CombinedResources.IsClient = 1
            , POWER(64, 1), 0
        )
        -- Distant Maintenace Window
        +
        IIF(NextServiceWindow > (SELECT DATEADD(dd, @HT_DistantMW, CURRENT_TIMESTAMP)), POWER(128, 1), 0)
        -- Short Maintenace Window
        +
        IIF(ServiceWindowDuration BETWEEN 0 AND @HT_ShortMW, POWER(256, 1), 0)
        -- Expired Maintenance Window
        +
        IIF(
            ServiceWindowStart <= (CURRENT_TIMESTAMP)
                AND CombinedResources.IsClient = 1
            , POWER(512, 1), 0)
        -- Disabled Maintenance Window
        +
        IIF(ServiceWindowEnabled != 1, POWER(1024, 1), 0)
        -- High Uptime
        +
        IIF(DATEDIFF(dd, OperatingSystem.LastBootUpTime0, CURRENT_TIMESTAMP) > @HT_Uptime, POWER(2048, 1), 0)
        -- Required VS Uptime
        +
        IIF(
            DATEDIFF(dd, OperatingSystem.LastBootUpTime0, CURRENT_TIMESTAMP) > @HT_Uptime
                AND ISNULL(Missing, (IIF(CombinedResources.IsClient = 1, 0, NULL))) = 0
            , POWER(4096, 1), 0
        )
        -- Free Space Threshold Exeeded
        +
        IIF(CONVERT(DECIMAL(10, 2), LogicalDisk.FreeSpace0 / 1024.0) < @HT_FreeSpace, POWER(8192, 1), 0)
    )
    , Missing            = ISNULL(Missing, (IIF(CombinedResources.IsClient = 1, 0, NULL)))
    , Device             = (
            IIF(
                SystemNames.Resource_Names0 IS NOT NULL, UPPER(SystemNames.Resource_Names0)
                , IIF(Systems.Full_Domain_Name0 IS NOT NULL, Systems.Name0 + N'.' + Systems.Full_Domain_Name0, Systems.Name0)
            )
    )
    , OperatingSystem    = (
        CASE
            WHEN OperatingSystem.Caption0 != N'' THEN
                CONCAT(
                    REPLACE(OperatingSystem.Caption0, N'Microsoft ', N''),         -- Remove 'Microsoft ' from OperatingSystem
                    REPLACE(OperatingSystem.CSDVersion0, N'Service Pack ', N' SP') -- Replace 'Service Pack ' with ' SP' in OperatingSystem
                )
            ELSE (

            /* Workaround for systems not in GS_OPERATING_SYSTEM table */
                CASE
                    WHEN CombinedResources.DeviceOS LIKE N'%Workstation 6.1%'   THEN N'Windows 7'
                    WHEN CombinedResources.DeviceOS LIKE N'%Workstation 6.2%'   THEN N'Windows 8'
                    WHEN CombinedResources.DeviceOS LIKE N'%Workstation 6.3%'   THEN N'Windows 8.1'
                    WHEN CombinedResources.DeviceOS LIKE N'%Workstation 10.0%'  THEN N'Windows 10'
                    WHEN CombinedResources.DeviceOS LIKE N'%Server 6.0'         THEN N'Windows Server 2008'
                    WHEN CombinedResources.DeviceOS LIKE N'%Server 6.1'         THEN N'Windows Server 2008R2'
                    WHEN CombinedResources.DeviceOS LIKE N'%Server 6.2'         THEN N'Windows Server 2012'
                    WHEN CombinedResources.DeviceOS LIKE N'%Server 6.3'         THEN N'Windows Server 2012 R2'
                    WHEN Systems.Operating_System_Name_And0 LIKE N'%Server 10%' THEN (
                        CASE
                            WHEN CAST(REPLACE(Build01, N'.', N'') AS INTEGER) > 10017763 THEN N'Windows Server 2019'
                            ELSE N'Windows Server 2016'
                        END
                    )
                    ELSE Systems.Operating_System_Name_And0
                END
            )
        END
    )
    , Uptime             = DATEDIFF(dd, OperatingSystem.LastBootUpTime0, CURRENT_TIMESTAMP)
    , LastBootTime       = CONVERT(NVARCHAR(16), OperatingSystem.LastBootUpTime0, 120)
    , PendingRestart     = (
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
    , FreeSpace          = CONVERT(DECIMAL(10, 2), LogicalDisk.FreeSpace0 / 1024.0)
    , ClientState        = IIF(CombinedResources.IsClient = 1, ClientSummary.ClientStateDescription, 'Unmanaged')
    , ClientVersion      = CombinedResources.ClientVersion
    , LastUpdateScan     = DATEDIFF(dd, UpdateScan.LastScanTime, CURRENT_TIMESTAMP)
    , LastUpdateScanTime = CONVERT(NVARCHAR(16), UpdateScan.LastScanTime, 120)
    , LastScanLocation   = NULLIF(UpdateScan.LastScanPackageLocation, '')
    , LastScanError      = NULLIF(UpdateScan.LastErrorCode, 0)
    , NextServiceWindow  = CONVERT(NVARCHAR(16), NextServiceWindow, 120)
FROM fn_rbac_R_System(@UserSIDs) AS Systems
    JOIN fn_rbac_CombinedDeviceResources(@UserSIDs) AS CombinedResources ON CombinedResources.MachineID = Systems.ResourceID
    LEFT JOIN fn_rbac_RA_System_ResourceNames(@UserSIDs) AS SystemNames ON SystemNames.ResourceID = Systems.ResourceID
    LEFT JOIN fn_rbac_GS_OPERATING_SYSTEM(@UserSIDs) AS OperatingSystem ON OperatingSystem.ResourceID = Systems.ResourceID
    LEFT JOIN fn_rbac_GS_LOGICAL_DISK(@UserSIDs) AS LogicalDisk ON LogicalDisk.ResourceID = Systems.ResourceID
        AND LogicalDisk.DriveType0 = 3                                           -- Local Disk
        AND LogicalDisk.Name0 = 'C:'                                             -- System Drive Only
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
IF OBJECT_ID(N'tempdb..#MaintenanceInfo', N'U') IS NOT NULL
    DROP TABLE #MaintenanceInfo;

/* #endregion */
/*##=============================================*/
/*## END QUERY BODY                              */
/*##=============================================*/