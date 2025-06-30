/*
.SYNOPSIS
    Gets the software update compliance for a Collection in ConfigMgr.
.DESCRIPTION
    Gets the software update compliance in ConfigMgr by Collection and All Updates.
.NOTES
    Requires SQL 2016.
    Requires ufn_CM_GetNextMaintenanceWindow sql helper function in order to display the next maintenance window.
    Requires SELECT access on vSMS_AutoDeployments for smsschm_users (ConfigMgr Reporting).
    Part of a report should not be run separately
.LINK
    https://MEM.Zone
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
DECLARE @UserSIDs          AS NVARCHAR(10) = 'SMS0001';
DECLARE @CollectionID      AS NVARCHAR(10) = 'SMS0001';
DECLARE @Locale            AS INT          = 2;
DECLARE @Groups            AS INT          = 97508;
DECLARE @Categories        AS INT          = 31; -- Security Updates
DECLARE @Vendors           AS INT          = 37; -- Microsoft
DECLARE @Compliant         AS INT          = 0;
DECLARE @Targeted          AS INT          = 1;
DECLARE @Enabled           AS INT          = 1;
DECLARE @Superseded        AS INT          = 0;
DECLARE @ArticleID         AS NVARCHAR(50) = NULL;
DECLARE @ExcludeArticleIDs AS NVARCHAR(50) = NULL;
DECLARE @HealthThresholds  AS NVARCHAR(20) = 'SMS0001';


/* Variable declaration */
--DECLARE @LCID                     AS INT = dbo.fn_LShortNameToLCID(@Locale);
DECLARE @LCID                     AS INT = 1033; -- Stupidity Workaround
DECLARE @Win10_2021_LTSC_EOS      AS DATETIME = '2027-01-12'
USE CM_JNJ; -- Stupidity Workaround

/* Perform cleanup */
IF OBJECT_ID(N'tempdb..#MaintenanceInfo', N'U')  IS NOT NULL DROP TABLE #MaintenanceInfo;
IF OBJECT_ID(N'tempdb..#ClientState', N'U')      IS NOT NULL DROP TABLE #ClientState;
IF OBJECT_ID(N'tempdb..#OSServicingState', N'U') IS NOT NULL DROP TABLE #OSServicingState;
IF OBJECT_ID(N'tempdb..#OSServicing', N'U')      IS NOT NULL DROP TABLE #OSServicing;
IF OBJECT_ID(N'tempdb..#GroupCIs', N'U')         IS NOT NULL DROP TABLE #GroupCIs;

/* Initialize variable tables */
DECLARE @HealthThresholdVariables AS TABLE (ID INT IDENTITY(1,1), Threshold INT);
DECLARE @HealthState              AS TABLE (BitMask INT, StateName NVARCHAR(250))

/* Create temporary tables */
CREATE TABLE #ClientState (BitMask INT, StateName NVARCHAR(100));
CREATE TABLE #OSServicingState (Build NVARCHAR(10), Branch INT, Version NVARCHAR(20), ServicingState INT);
CREATE TABLE #OSServicing (StateNumber INT, StateName NVARCHAR(20));
CREATE TABLE #GroupCIs (CI_ID INT);

/* Create indexes for performance */
CREATE CLUSTERED INDEX ix_tempCIndexAft ON #ClientState (BitMask);
CREATE CLUSTERED INDEX ix_tempCIndexAft ON #OSServicingState (Build, Branch);
CREATE CLUSTERED INDEX ix_tempCIndexAft ON #OSServicing (StateNumber);
CREATE CLUSTERED INDEX ix_tempCIndexAft ON #GroupCIs (CI_ID);

/* Check for helper function */
DECLARE @HelperFunctionExists     AS INT = 0;
--IF OBJECT_ID(N'[dbo].[ufn_CM_GetNextMaintenanceWindowForDevice]') IS NOT NULL -- Stupidity Workaround
IF OBJECT_ID(N'[CM_Custom].[dbo].[ufn_CM_GetNextMaintenanceWindowForDevice]') IS NOT NULL
    SET @HelperFunctionExists = 1;

/* Populate @HealthThresholdVariables table */
INSERT INTO @HealthThresholdVariables (Threshold)
--SELECT VALUE FROM STRING_SPLIT(@HealthThresholds, N',')
SELECT SubString FROM fn_SplitString(@HealthThresholds, N',') -- Stupidity Workaround

/* Set Health Threshold variables */
DECLARE @HT_DistantMW             AS INT = (SELECT Threshold FROM @HealthThresholdVariables WHERE ID = 1); -- Days
DECLARE @HT_ShortMW               AS INT = (SELECT Threshold FROM @HealthThresholdVariables WHERE ID = 2); -- Minutes
DECLARE @HT_LastScanTime          AS INT = (SELECT Threshold FROM @HealthThresholdVariables WHERE ID = 3); -- Days
DECLARE @HT_Uptime                AS INT = (SELECT Threshold FROM @HealthThresholdVariables WHERE ID = 4); -- Days
DECLARE @HT_FreeSpace             AS INT = (SELECT Threshold FROM @HealthThresholdVariables WHERE ID = 5); -- GB

/* Populate HealthState table */
INSERT INTO @HealthState (BitMask, StateName)
VALUES
    (0,       N'Healthy')
    , (1,     N'Unmanaged')
    , (2,     N'Inactive')
    , (4,     N'Health Evaluation Failed')
    , (8,     N'Pending Restart')
    , (16,    N'Update Scan Failed')
    , (32,    N'Update Scan Late')
    , (64,    N'No Maintenance Window')
    , (128,   N'Distant Maintenance Window')
    , (256,   N'Short Maintenance Window')
    , (512,   N'Expired Maintenance Window')
    , (1024,  N'Disabled Maintenance Window')
    , (2048,  N'Uptime Threshold Exceeded')
    , (4096,  N'Required VS Uptime')
    , (8192,  N'Free Space Threshold Exceeded')
    , (16384, N'Servicing Expired')

/* Populate ClientState table */
INSERT INTO #ClientState (BitMask, StateName)
VALUES
    (0, N'No Reboot')
    , (1, N'Configuration Manager')
    , (2, N'File Rename')
    , (4, N'Windows Update')
    , (8, N'Add or Remove Feature')

/* Populate OSServicing table */
INSERT INTO #OSServicing (StateNumber, StateName)
VALUES
    (0, N'Internal')
    , (1, N'Insider')
    , (2, N'Current')
    , (3, N'Expiring Soon')
    , (4, N'Expired')
    , (5, N'Unknown')

/* Populate OSServicingState table */
INSERT INTO #OSServicingState (Build, Branch, Version, ServicingState)
VALUES
    (N'10.0.19044', 2, N'Win10 2021 LTSC'
        , IIF(
            DATEDIFF(dd, CURRENT_TIMESTAMP, @Win10_2021_LTSC_EOS) > 180
            , 2
            , IIF(
                DATEDIFF(dd, CURRENT_TIMESTAMP, @Win10_2021_LTSC_EOS) >= 0
                , 3, 4
            )
        )
    )
    , (N'6.1.7601', 1, NULL, 4)

/* Populate GroupCIs table */
INSERT INTO #GroupCIs (CI_ID)
    SELECT
        CI_ID = CIRelation.ReferencedCI_ID
    FROM fn_rbac_CIRelation_All(@UserSIDs) AS CIRelation
        JOIN fn_rbac_AuthListInfo(@LCID, @UserSIDs) AS AuthList ON AuthList.CI_ID = CIRelation.CI_ID
    WHERE CIRelation.RelationType = 1
        AND AuthList.CI_ID IN (@Groups)
    ORDER BY CIRelation.ReferencedCI_ID

/* Get update data */
;
WITH UpdateInfo_CTE
AS (
    SELECT
        ResourceID          = Systems.ResourceID
        , Missing           = COUNT(*)
    FROM fn_rbac_R_System(@UserSIDs) AS Systems
        JOIN fn_rbac_UpdateComplianceStatus(@UserSIDs) AS ComplianceStatus ON ComplianceStatus.ResourceID = Systems.ResourceID
            AND ComplianceStatus.Status = 2                                   -- Filter on 'Required' (0 = Unknown, 1 = NotRequired, 2 = Required, 3 = Installed)
            AND ComplianceStatus.CI_ID IN (SELECT CI_ID FROM @GroupCIs)       -- Filter on Selected Update Groups
        JOIN fn_rbac_ClientCollectionMembers(@UserSIDs) AS CollectionMembers ON CollectionMembers.ResourceID = Systems.ResourceID
        JOIN fn_rbac_UpdateInfo(@LCID, @UserSIDs) AS UpdateCIs ON UpdateCIs.CI_ID = ComplianceStatus.CI_ID
            AND UpdateCIs.IsExpired = 0                                       -- Filter on Expired
            AND UpdateCIs.IsSuperseded IN (@Superseded)                       -- Filter on Superseded
            AND UpdateCIs.IsEnabled IN (@Enabled)                             -- Filter on Deployment Enabled
            AND UpdateCIs.CIType_ID IN (1, 8)                                 -- Filter on 1 Software Updates, 8 Software Update Bundle (v_CITypes)
            AND UpdateCIs.ArticleID NOT IN (                                  -- Filter on ArticleID csv list
                --SELECT VALUE FROM STRING_SPLIT(@ExcludeArticleIDs, N',')
                SELECT SubString FROM fn_SplitString(@ExcludeArticleIDs, N',') -- Stupidity Workaround
            )
        JOIN fn_rbac_CICategoryInfo_All(@LCID, @UserSIDs) AS CICategoryCompany ON CICategoryCompany.CI_ID = UpdateCIs.CI_ID
            AND CICategoryCompany.CategoryTypeName = N'Company'
            AND CICategoryCompany.CategoryInstanceID IN (@Vendors)            -- Filter on Selected Update Vendors
        JOIN fn_rbac_CICategoryInfo_All(@LCID, @UserSIDs) AS CICategoryClassification ON CICategoryClassification.CI_ID = UpdateCIs.CI_ID
            AND CICategoryClassification.CategoryTypeName = N'UpdateClassification'
            AND CICategoryClassification.CategoryInstanceID IN (@Categories)  -- Filter on Selected Update Classification Categories
        LEFT JOIN fn_rbac_CITargetedMachines(@UserSIDs) AS Targeted ON Targeted.CI_ID = ComplianceStatus.CI_ID
            AND Targeted.ResourceID = ComplianceStatus.ResourceID
    WHERE CollectionMembers.CollectionID = @CollectionID
        AND Systems.Client0 = 1                                               -- Filter on Managed Clients
        AND IIF(Targeted.ResourceID IS NULL, 0, 1) IN (@Targeted)             -- Filter on 'Targeted' or 'NotTargeted'
        AND IIF(
            NULLIF(@ArticleID, N'') IS NULL
            , UpdateCIs.ArticleID, @ArticleID
        ) = UpdateCIs.ArticleID                                               -- Filter by ArticleID
/*        AND UpdateCIs.ArticleID IN (
            -- Filter on ArticleID csv list
            SELECT VALUE FROM STRING_SPLIT(
                IIF(NULLIF(@ArticleID, N'') IS NULL
                , UpdateCIs.ArticleID
                , @ArticleID)
            , N',')
        )
*/
    GROUP BY Systems.ResourceID
)

/* Get device info */
SELECT Systems.ResourceID

    /* Set Health states. You can find the corresponding values in the HealthState table above */
    , HealthStates          = (
        -- Client Unmanaged
        IIF(
            CombinedResources.IsClient != 1
            , POWER(1, 1)
            , 0
        )
        -- Client Inactive
        +
        IIF(
            ClientSummary.ClientStateDescription        = N'Inactive/Pass'
                OR ClientSummary.ClientStateDescription = N'Inactive/Fail'
                OR ClientSummary.ClientStateDescription = N'Inactive/Unknown'
            , POWER(2, 1)
            , 0
        )
        -- Client Health Evaluation Failed
        +
        IIF(
            ClientSummary.ClientStateDescription = N'Active/Fail'
                OR ClientSummary.ClientStateDescription = N'Inactive/Fail'
            , POWER(4, 1)
            , 0
        )
        -- Pending Restart
        +
        IIF(
            CombinedResources.ClientState != 0
            , POWER(8, 1)
            , 0
        )
        -- Update Scan Failed
        +
        IIF(
            UpdateScan.LastErrorCode != 0
            , POWER(16, 1)
            , 0
        )
        -- Update Scan Late
        +
        IIF(
            UpdateScan.LastScanTime < (SELECT DATEADD(dd, -@HT_LastScanTime, CURRENT_TIMESTAMP))
            , POWER(32, 1)
            , 0
        )
        -- No Maintenance Window
        +
        IIF(
            ISNULL(Maintenance.NextServiceWindow, 0) = 0
                AND @HelperFunctionExists = 1
                AND Maintenance.ServiceWindowStart IS NULL
                AND CombinedResources.IsClient = 1
            , POWER(64, 1)
            , 0
        )
        -- Distant Maintenance Window
        +
        IIF(
            DATEADD(mi, Maintenance.ServiceWindowDuration, Maintenance.NextServiceWindow) > (SELECT DATEADD(dd, @HT_DistantMW, CURRENT_TIMESTAMP))
            , POWER(128, 1)
            , 0
        )
        -- Short Maintenance Window
        +
        IIF(
            ServiceWindowDuration BETWEEN 0 AND @HT_ShortMW
            , POWER(256, 1)
            , 0
        )
        -- Expired Maintenance Window
        +
        IIF(
            DATEADD(mi, Maintenance.ServiceWindowDuration, ISNULL(Maintenance.NextServiceWindow, Maintenance.ServiceWindowStart)) <= CURRENT_TIMESTAMP
                AND Maintenance.ServiceWindowStart IS NOT NULL
                AND CombinedResources.IsClient = 1
            , POWER(512, 1)
            , 0
        )
        -- Disabled Maintenance Window
        +
        IIF(
            Maintenance.IsServiceWindowEnabled != 1
            , POWER(1024, 1)
            , 0
        )
        -- High Uptime
        +
        IIF(
            DATEDIFF(dd, OperatingSystem.LastBootUpTime0, CURRENT_TIMESTAMP) > @HT_Uptime
            , POWER(2048, 1)
            , 0
        )
        -- Required VS Uptime
        +
        IIF(
            DATEDIFF(dd, OperatingSystem.LastBootUpTime0, CURRENT_TIMESTAMP) > @HT_Uptime
                AND ISNULL(Missing, (IIF(CombinedResources.IsClient = 1, 0, NULL))) = 0
            , POWER(4096, 1)
            , 0
        )
        -- Free Space Threshold Exceeded
        +
        IIF(
            CONVERT(DECIMAL(10, 2), LogicalDisk.FreeSpace0 / 1024.0) < @HT_FreeSpace
            , POWER(8192, 1), 0
        )
        -- Servicing Expired
        +
        IIF(
            OSInfo.ServicingState = 4
            , POWER(16384, 1)
            , 0
        )
    )
    , Missing               = ISNULL(Missing, (IIF(CombinedResources.IsClient = 1, 0, NULL)))
    , Device                = (
        IIF(
            SystemNames.Resource_Names0 IS NULL
            , IIF(Systems.Full_Domain_Name0 IS NULL, Systems.Name0, Systems.Name0 + N'.' + Systems.Full_Domain_Name0)
            , UPPER(SystemNames.Resource_Names0)
        )
    )
    , OperatingSystem       = (
        IIF(
            OperatingSystem.Caption0 = N''
            , Systems.Operating_System_Name_And0
            , REPLACE(OperatingSystem.Caption0, N'Microsoft ', N'')         --Remove 'Microsoft ' from OperatingSystem
        )
    )
    , OSVersion             = ISNULL(OSInfo.Version, IIF(RIGHT(OperatingSystem.Caption0, 7) = 'Preview', 'Insider Preview', NULL))
    , OSBuild               = Systems.Build01
    , OSServicingState      = ISNULL((SELECT StateName FROM #OSServicing AS OSServicing WHERE OSServicing.StateNumber = OSInfo.ServicingState), N'Unknown')
    , IPAddresses           = REPLACE(IPAddresses.Value, N' ', N',')
    , Uptime                = DATEDIFF(dd, OperatingSystem.LastBootUpTime0, CURRENT_TIMESTAMP)
    , LastBootTime          = CONVERT(NVARCHAR(16), OperatingSystem.LastBootUpTime0, 120)
    , PendingRestart        = (
        STUFF(
            REPLACE(
                (
                    SELECT N'#!' + LTRIM(RTRIM(StateName)) AS [data()]
                    FROM #ClientState
                    WHERE BitMask & CombinedResources.ClientState <> 0
                    FOR XML PATH(N'')
                ),
                N' #!', N', '
            ),
            1, 2, N''
        )
    )
    , FreeSpace             = CONVERT(DECIMAL(10, 2), LogicalDisk.FreeSpace0 / 1024.0)
    , ClientState           = IIF(Systems.Client0 = 1, ISNULL(ClientSummary.ClientStateDescription, 'Unknown'), 'Unmanaged')
    , ClientVersion         = CombinedResources.ClientVersion
    , LastUpdateScan        = DATEDIFF(dd, UpdateScan.LastScanTime, CURRENT_TIMESTAMP)
    , LastUpdateScanTime    = CONVERT(NVARCHAR(16), UpdateScan.LastScanTime, 120)
    , LastScanLocation      = NULLIF(UpdateScan.LastScanPackageLocation, N'')
    , LastScanError         = NULLIF(UpdateScan.LastErrorCode, 0)
    , NextServiceWindow     = CONVERT(NVARCHAR(16), Maintenance.NextServiceWindow, 120)
    , ServiceWindowDuration = Maintenance.ServiceWindowDuration
    , ServiceWindowOpen     = Maintenance.IsServiceWindowOpen
    , IsUTCTime             = IsUTCTime
FROM fn_rbac_R_System(@UserSIDs) AS Systems
    JOIN fn_rbac_CombinedDeviceResources(@UserSIDs) AS CombinedResources ON CombinedResources.MachineID = Systems.ResourceID
    JOIN fn_rbac_FullCollectionMembership(@UserSIDs) AS CollectionMembers ON CollectionMembers.ResourceID = Systems.ResourceID
    LEFT JOIN fn_rbac_RA_System_ResourceNames(@UserSIDs) AS SystemNames ON SystemNames.ResourceID = CollectionMembers.ResourceID
    LEFT JOIN fn_rbac_GS_OPERATING_SYSTEM(@UserSIDs) AS OperatingSystem ON OperatingSystem.ResourceID = CollectionMembers.ResourceID
    LEFT JOIN fn_rbac_GS_LOGICAL_DISK(@UserSIDs) AS LogicalDisk ON LogicalDisk.ResourceID = CollectionMembers.ResourceID
        AND LogicalDisk.DriveType0 = 3     -- Local Disk
        AND LogicalDisk.Name0      = N'C:' -- System Drive Only
    OUTER APPLY (
        SELECT Value =  (
            SELECT LTRIM(RTRIM(IP.IP_Addresses0)) AS [data()]
            FROM fn_rbac_RA_System_IPAddresses(@UserSIDs) AS IP
            WHERE IP.ResourceID = Systems.ResourceID
            -- Exclude IPv6 and 169.254.0.0 Class
                AND IIF(CHARINDEX(N':', IP.IP_Addresses0) > 0 OR CHARINDEX(N'169.254', IP.IP_Addresses0) = 1, 1, 0) = 0
            -- Aggregate results to one row
            FOR XML PATH('')
        )
    ) AS IPAddresses
    LEFT JOIN fn_rbac_CH_ClientSummary(@UserSIDs) AS ClientSummary ON ClientSummary.ResourceID = CollectionMembers.ResourceID
    LEFT JOIN fn_rbac_UpdateScanStatus(@UserSIDs) AS UpdateScan ON UpdateScan.ResourceID = CollectionMembers.ResourceID
    OUTER APPLY [CM_Custom].[dbo].[ufn_CM_GetNextMaintenanceWindowForDevice](@UserSIDs,CollectionMembers.ResourceID) AS Maintenance
    LEFT JOIN UpdateInfo_CTE AS UpdateInfo ON UpdateInfo.ResourceID = CollectionMembers.ResourceID
    OUTER APPLY (
            SELECT
                Version = OSLocalizedNames.Value
                , ServicingState = OSServicingStates.State
            FROM fn_GetWindowsServicingStates() AS OSServicingStates
                JOIN fn_GetWindowsServicingLocalizedNames() AS OSLocalizedNames ON OSLocalizedNames.Name = OSServicingStates.Name
            WHERE OSServicingStates.Build = Systems.Build01
                AND OSServicingStates.Branch = Systems.OSBranch01
            UNION
            SELECT
                Version
                , ServicingState
            FROM #OSServicingState AS OSServicingState
            WHERE  OSServicingState.Build =  Systems.Build01
                AND OSServicingState.Branch = IIF(Systems.OSBranch01 = N'', 1, Systems.OSBranch01)
    ) AS OSInfo

WHERE CollectionMembers.CollectionID = @CollectionID
    AND (
        CASE
            WHEN Missing = 0 OR (Missing IS NULL AND Systems.Client0 = 1) THEN 1 -- Yes
            WHEN Missing > 0 AND Missing IS NOT NULL                      THEN 0 -- No
            ELSE 2                                                               -- Unknown
        END
    ) IN (@Compliant) -- Compliant (0 = No, 1 = Yes, 2 = Unknown)

/* Perform cleanup */
IF OBJECT_ID(N'tempdb..#MaintenanceInfo', N'U')  IS NOT NULL DROP TABLE #MaintenanceInfo;
IF OBJECT_ID(N'tempdb..#ClientState', N'U')      IS NOT NULL DROP TABLE #ClientState;
IF OBJECT_ID(N'tempdb..#OSServicingState', N'U') IS NOT NULL DROP TABLE #OSServicingState;
IF OBJECT_ID(N'tempdb..#OSServicing', N'U')      IS NOT NULL DROP TABLE #OSServicing;
IF OBJECT_ID(N'tempdb..#GroupCIs', N'U')         IS NOT NULL DROP TABLE #GroupCIs;

/* #endregion */
/*##=============================================*/
/*## END QUERY BODY                              */
/*##=============================================*/