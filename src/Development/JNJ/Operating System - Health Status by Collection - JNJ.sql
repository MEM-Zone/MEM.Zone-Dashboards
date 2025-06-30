
/*
.SYNOPSIS
    Gets the operating system health status for a Collection in ConfigMgr.
.DESCRIPTION
    Gets the operating system  health status, and general troubleshoting information for a Collection in ConfigMgr.
.NOTES
    Requires SQL 2016.
    Part of a report should not be run separately
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
--DECLARE @UserSIDs           AS NVARCHAR(10)  = 'SMS0001';
--DECLARE @CollectionID       AS NVARCHAR(10)  = 'SMS0001';
--DECLARE @ExclusionNameMatch AS NVARCHAR(100) = 'SMS0001';
--DECLARE @Locale             AS INT           = 2;
--DECLARE @HealthThresholds   AS NVARCHAR(20)  = 'SMS0001';

/* Variable declaration */
USE CM_JNJ; -- Stupidity Wokaround
-- DECLARE @LCID                       AS INT = dbo.fn_LShortNameToLCID(@Locale);
DECLARE @LCID                     AS INT = 1033; -- Stupidity Wokaround
DECLARE @Win10_2021_LTSC_EOS      AS DATETIME = '2027-01-12'

/* Perform cleanup */
IF OBJECT_ID(N'tempdb..#ClientState', N'U')             IS NOT NULL DROP TABLE #ClientState;
IF OBJECT_ID(N'tempdb..#OSServicingState', N'U')        IS NOT NULL DROP TABLE #OSServicingState;
IF OBJECT_ID(N'tempdb..#OSServicing', N'U')             IS NOT NULL DROP TABLE #OSServicing;
IF OBJECT_ID(N'tempdb..#ExclusionCollectionList', N'U') IS NOT NULL DROP TABLE #ExclusionCollectionList;
IF OBJECT_ID(N'tempdb..#ExclusionCollections', N'U')    IS NOT NULL DROP TABLE #ExclusionCollections;

/* Initialize variable tables */
DECLARE @HealthThresholdVariables AS TABLE (ID INT IDENTITY(1,1), Threshold INT);
DECLARE @HealthState              AS TABLE (BitMask INT, StateName NVARCHAR(250));

/* Create temporary tables */
CREATE TABLE #ClientState (BitMask INT, StateName NVARCHAR(100));
CREATE TABLE #OSServicingState (Build NVARCHAR(10), Branch INT, Version NVARCHAR(20), ServicingState INT);
CREATE TABLE #OSServicing (StateNumber INT, StateName NVARCHAR(20));
CREATE TABLE #ExclusionCollectionList (CollectionID NVARCHAR(10), CollectionName NVARCHAR(100));
CREATE TABLE #ExclusionCollections (ResourceID INT, CollectionName NVARCHAR(100));

/* Create indexes for performance */
CREATE CLUSTERED INDEX ix_tempCIndexAft ON #ClientState (BitMask);
CREATE CLUSTERED INDEX ix_tempCIndexAft ON #OSServicingState (Build, Branch);
CREATE CLUSTERED INDEX ix_tempCIndexAft ON #OSServicing (StateNumber);
CREATE CLUSTERED INDEX ix_tempCIndexAft ON #ExclusionCollectionList (CollectionID, CollectionName);
CREATE CLUSTERED INDEX ix_tempCIndexAft ON #ExclusionCollections (ResourceID, CollectionName);

/* Populate @HealthThresholdVariables table */
INSERT INTO @HealthThresholdVariables (Threshold)
--SELECT VALUE FROM STRING_SPLIT(@HealthThresholds, N',')
SELECT SubString FROM fn_SplitString(@HealthThresholds, N','); -- Stupidity Wokaround

/* Set Health Threshold variables */
DECLARE @HT_LastScanTime          AS INT = (SELECT Threshold FROM @HealthThresholdVariables WHERE ID = 1); -- Days
DECLARE @HT_Uptime                AS INT = (SELECT Threshold FROM @HealthThresholdVariables WHERE ID = 2); -- Days
DECLARE @HT_FreeSpace             AS INT = (SELECT Threshold FROM @HealthThresholdVariables WHERE ID = 3); -- GB

/* Populate HealthState table */
INSERT INTO @HealthState (BitMask, StateName)
VALUES
    (0,     N'Healthy')
    , (1,   N'Unmanaged')
    , (2,   N'Inactive')
    , (4,   N'Health Evaluation Failed')
    , (8,   N'Pending Restart')
    , (16,  N'Update Scan Failed')
    , (32,  N'Update Scan Late')
    , (64,  N'Uptime Threshold Exceeded')
    , (128, N'Free Space Threshold Exceeded')
    , (256, N'Servicing Expired')
    , (512, N'Excluded')

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

/* Populate ExclusionCollectionList table */
INSERT INTO #ExclusionCollectionList (CollectionID, CollectionName)
    SELECT
        CollectionID = SiteID
        , CollectionName
    FROM fn_rbac_Collections(@UserSIDs)
    WHERE CollectionType = 2 AND CollectionName LIKE @ExclusionNameMatch
    ORDER BY CollectionID

/* Populate ExclusionCollections table */
INSERT INTO #ExclusionCollections (ResourceID, CollectionName)
    SELECT
        Systems.ResourceID
        , CollectionName = (
            STUFF(
                REPLACE(
                    (
                        SELECT N'#!' + LTRIM(RTRIM(ExclusionCollectionList.CollectionName)) AS [data()]
                        FROM fn_rbac_FullCollectionMembership(@UserSIDs) AS CollectionMembers
                            JOIN #ExclusionCollectionList AS ExclusionCollectionList ON ExclusionCollectionList.CollectionID = CollectionMembers.CollectionID
                        WHERE CollectionMembers.ResourceID = Systems.ResourceID
                        FOR XML PATH(N'')
                    ),
                    N' #!', N', '
                )
                , 1, 2, N''
            )
        )
    FROM fn_rbac_R_System(@UserSIDs) AS Systems
        JOIN fn_rbac_FullCollectionMembership(@UserSIDs) AS CollectionMembers ON CollectionMembers.ResourceID = Systems.ResourceID
    WHERE CollectionMembers.CollectionID = @CollectionID

/* Get device info */
SELECT Systems.ResourceID

    /* Set Health states. You can find the corresponding values in the HealthState table above */
    , HealthStates          = (
        --Client Unmanaged
        IIF(
            CombinedResources.IsClient != 1
            , POWER(1, 1)
            , 0
        )
        --Client Inactive
        +
        IIF(
            ClientSummary.ClientStateDescription        = N'Inactive/Pass'
                OR ClientSummary.ClientStateDescription = N'Inactive/Fail'
                OR ClientSummary.ClientStateDescription = N'Inactive/Unknown'
            , POWER(2, 1)
            , 0
        )
        --Client Health Evaluation Failed
        +
        IIF(
            ClientSummary.ClientStateDescription        = N'Active/Fail'
                OR ClientSummary.ClientStateDescription = N'Inactive/Fail'
            , POWER(4, 1)
            , 0
        )
        --Pending Restart
        +
        IIF(
            CombinedResources.ClientState != 0
            , POWER(8, 1)
            , 0
        )
        --Update Scan Failed
        +
        IIF(
            UpdateScan.LastErrorCode != 0
            , POWER(16, 1)
            , 0
        )
        --Update Scan Late
        +
        IIF(
            UpdateScan.LastScanTime < (SELECT DATEADD(dd, -@HT_LastScanTime, CURRENT_TIMESTAMP))
            , POWER(32, 1)
            , 0
        )
        --High Uptime
        +
        IIF(
            DATEDIFF(dd, OperatingSystem.LastBootUpTime0, CURRENT_TIMESTAMP) > @HT_Uptime
            , POWER(64, 1)
            , 0
        )
        --Free Space Threshold Exeeded
        +
        IIF(
            CONVERT(DECIMAL(10, 2), LogicalDisk.FreeSpace0 / 1024.0) < @HT_FreeSpace
            , POWER(128, 1)
            , 0
        )
        --Servicing Expired
        +
        IIF(
            OSInfo.ServicingState = 4
            , POWER(256, 1)
            , 0
        )
        --Excluded
        +
        IIF(
            ExclusionCollections.CollectionName IS NOT NULL
            , POWER(512, 1)
            , 0
        )
    )
    , Excluded              = IIF(ExclusionCollections.CollectionName IS NULL, N'No', N'Yes')
    , ExclusionCollection   = ExclusionCollections.CollectionName
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
            , CONCAT(
                REPLACE(OperatingSystem.Caption0, N'Microsoft ', N''),         --Remove 'Microsoft ' from OperatingSystem
                REPLACE(OperatingSystem.CSDVersion0, N'Service Pack ', N' SP') --Replace 'Service Pack ' with ' SP' in OperatingSystem
            )
        )
    )
    , OSVersion             = ISNULL(OSInfo.Version, IIF(RIGHT(OperatingSystem.Caption0, 7) = N'Preview', N'Insider Preview', NULL))
    , OSBuildNumber         = Systems.Build01
    , OSServicingState      = ISNULL((SELECT StateName FROM #OSServicing AS OSServicing WHERE OSServicing.StateNumber = OSInfo.ServicingState), N'Unknown')
    , Domain                = Systems.Resource_Domain_OR_Workgr0
    , ADSite                = Systems.AD_Site_Name0
    --, LastLogonUser         = IIF(CombinedResources.UserDomainName IS NULL, CombinedResources.LastLogonUser, CONCAT(CombinedResources.UserDomainName, N'\', CombinedResources.LastLogonUser))
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
    , SiteCode              = CombinedResources.SiteCode
    , ClientState           = IIF(CombinedResources.IsClient = 1, ClientSummary.ClientStateDescription, N'Unmanaged')
    , ClientVersion         = CombinedResources.ClientVersion
    , LastUpdateScan        = DATEDIFF(dd, UpdateScan.LastScanTime, CURRENT_TIMESTAMP)
    , LastUpdateScanTime    = CONVERT(NVARCHAR(16), UpdateScan.LastScanTime, 120)
    , LastScanError         = NULLIF(UpdateScan.LastErrorCode, 0)
FROM fn_rbac_R_System(@UserSIDs) AS Systems
    JOIN fn_rbac_CombinedDeviceResources(@UserSIDs) AS CombinedResources ON CombinedResources.MachineID = Systems.ResourceID
    JOIN fn_rbac_FullCollectionMembership(@UserSIDs) AS CollectionMembers ON CollectionMembers.ResourceID = CombinedResources.MachineID
    LEFT JOIN fn_rbac_RA_System_ResourceNames(@UserSIDs) AS SystemNames ON SystemNames.ResourceID = CombinedResources.MachineID
    LEFT JOIN fn_rbac_GS_OPERATING_SYSTEM(@UserSIDs) AS OperatingSystem ON OperatingSystem.ResourceID = CombinedResources.MachineID
    LEFT JOIN fn_rbac_GS_LOGICAL_DISK(@UserSIDs) AS LogicalDisk ON LogicalDisk.ResourceID = CombinedResources.MachineID
        AND LogicalDisk.DriveType0 = 3     --Local Disk
        AND LogicalDisk.Name0      = N'C:' --System Drive Only
    LEFT JOIN fn_rbac_CH_ClientSummary(@UserSIDs) AS ClientSummary ON ClientSummary.ResourceID = CombinedResources.MachineID
    LEFT JOIN fn_rbac_UpdateScanStatus(@UserSIDs) AS UpdateScan ON UpdateScan.ResourceID = CombinedResources.MachineID
    LEFT JOIN #ExclusionCollections AS ExclusionCollections ON ExclusionCollections.ResourceID = CombinedResources.MachineID
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
WHERE CollectionMembers.ResourceType = 5 AND CollectionMembers.CollectionID = @CollectionID

/* Perform cleanup */
IF OBJECT_ID(N'tempdb..#ClientState', N'U')              IS NOT NULL DROP TABLE #ClientState;
IF OBJECT_ID(N'tempdb..#OSServicingState', N'U')         IS NOT NULL DROP TABLE #OSServicingState;
IF OBJECT_ID(N'tempdb..#OSServicing', N'U')              IS NOT NULL DROP TABLE #OSServicing;
IF OBJECT_ID(N'tempdb..#ExclusionCollectionList', N'U')  IS NOT NULL DROP TABLE #ExclusionCollectionList;
IF OBJECT_ID(N'tempdb..#ExclusionCollections', N'U')     IS NOT NULL DROP TABLE #ExclusionCollections;

/* #endregion */
/*##=============================================*/
/*## END QUERY BODY                              */
/*##=============================================*/