/*
.SYNOPSIS
    Gets the update scan status for a MEMCM Collection.
.DESCRIPTION
    Gets the windows update agent scan status for a MEMCM Collection by Scan State.
.NOTES
    Requires SQL 2016.
    Part of a report should not be run separately.LINK
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
--DECLARE @UserSIDs             AS NVARCHAR(10)  = 'Disabled';
--DECLARE @CollectionID         AS NVARCHAR(10)  = 'SMS00001';
--DECLARE @ScanStates           AS INT           = 3; -- Completed
--DECLARE @HealthThresholds     AS NVARCHAR(20) = '14,14';

/* Variable declaration */
DECLARE @UpdateSearchID INT   = (
    SELECT TOP 1 UpdateSource.UpdateSource_ID
    FROM fn_rbac_SoftwareUpdateSource(@UserSIDs) AS UpdateSource
    WHERE IsPublishingEnabled = 1 -- Get only the UpdateSource_ID where publishing is enabled
)

/* Initialize memory tables */
DECLARE @HealthThresholdVariables TABLE (ID INT IDENTITY(1,1), Threshold INT);
DECLARE @HealthState              TABLE (BitMask INT, StateName NVARCHAR(250))

/* Populate @HealthThresholdVariables table */
INSERT INTO @HealthThresholdVariables (Threshold)
SELECT VALUE FROM STRING_SPLIT(@HealthThresholds, ',')

/* Set Health Threshold variables */
DECLARE @HT_LastScanTime          AS INT = (SELECT Threshold FROM @HealthThresholdVariables WHERE ID = 1); -- Days
DECLARE @HT_SyncCatalog           AS INT = (SELECT Threshold FROM @HealthThresholdVariables WHERE ID = 2); -- Days

/* Populate HealthState table */
INSERT INTO @HealthState (BitMask, StateName)
VALUES
    (0,     N'Healthy')
    , (1,   N'Unmanaged')
    , (2,   N'Inactive')
    , (4,   N'Health Evaluation Failed')
    , (8,   N'Update Scan Completed with Errors')
    , (16,  N'Update Scan Failed')
    , (32,  N'Update Scan Unknown')
    , (64,  N'Update Scan Late')
    , (128, N'Update Sync Catalog is Outdated')

/* Gets the device update scan states */
SELECT
    ResourceID                = Systems.ResourceID
    , HealthStates            = (
        -- Unmanaged
        IIF(CombinedResources.IsClient != 1, POWER(1, 1), 0)
        -- Inactive
        +
        IIF(
            ClientSummary.ClientStateDescription = N'Inactive/Pass'
                OR ClientSummary.ClientStateDescription = N'Inactive/Fail'
                OR ClientSummary.ClientStateDescription = N'Inactive/Unknown'
            , POWER(2, 1), 0)
        -- Health Evaluation Failed
        +
        IIF(
            ClientSummary.ClientStateDescription = N'Active/Fail'
                OR ClientSummary.ClientStateDescription = N'Inactive/Fail'
            , POWER(4, 1), 0
        )
        -- Scan Completed with errors
        +
        IIF(StateNames.StateID = 6, POWER(8, 1), 0)
        -- Scan failed
        +
        IIF(StateNames.StateID = 5, POWER(16, 1), 0)
        -- Scan state unknown
        +
        IIF(StateNames.StateID = 0 OR StateNames.StateID IS NULL, POWER(32, 1), 0)
        -- Scan Late
        +
        IIF(UpdateScan.LastScanTime < (SELECT DATEADD(dd, -@HT_LastScanTime, CURRENT_TIMESTAMP)), POWER(64, 1), 0)
        -- Update Sync Catalog is Outdated
        +
        IIF(
            NULLIF(SyncSourceInfo.SyncCatalogVersion, '') IS NULL
                OR SyncSourceInfo.SyncCatalogVersion - UpdateScan.LastScanPackageVersion > @HT_SyncCatalog
            , POWER(128, 1), 0)
    )
    , ScanState               = (
        CASE
            WHEN StateNames.StateID = 0 THEN 'Unkown'
            WHEN StateNames.StateID = 1 THEN 'Waiting'
            WHEN StateNames.StateID = 2 THEN 'Running'
            WHEN StateNames.StateID = 3 THEN 'Completed'
            WHEN StateNames.StateID = 4 THEN 'Retry'
            WHEN StateNames.StateID = 5 THEN 'Failed'
            WHEN StateNames.StateID = 6 THEN 'Error'
            ELSE 'Unknown'
        END
    )
    , ScanStateDescription    = ISNULL(StateNames.StateName, 'Scan state unknown')
    , Device                  = IIF(Systems.Full_Domain_Name0 IS NOT NULL, Systems.Name0 + '.' + Systems.Full_Domain_Name0, Systems.Name0)
    , OperatingSystem = (
        IIF(
            OperatingSystem.Caption0 != N''
            , CONCAT(
                REPLACE(OperatingSystem.Caption0, N'Microsoft ', N''),         --Remove 'Microsoft ' from OperatingSystem
                REPLACE(OperatingSystem.CSDVersion0, N'Service Pack ', N' SP') --Replace 'Service Pack ' with ' SP' in OperatingSystem
            )
            , Systems.Operating_System_Name_And0
        )
    )
    , ClientState             = (
        CASE CombinedResources.IsClient
            WHEN 1 THEN ClientSummary.ClientStateDescription
            ELSE N'Unmanaged'
        END
    )
    , ClientVersion           = Systems.Client_Version0
    , WUAVersion              = UpdateScan.LastWUAVersion
    , LastUpdateScan          = DATEDIFF(dd, UpdateScan.LastScanTime, CURRENT_TIMESTAMP)
    , LastUpdateScanTime      = CONVERT(NVARCHAR(16), UpdateScan.LastScanTime, 120)
    , LastScanPackageLocation = NULLIF(UpdateScan.LastScanPackageLocation, '')
    , LastScanPackageVersion  = UpdateScan.LastScanPackageVersion
    , SyncCatalogVersion      = SyncSourceInfo.SyncCatalogVersion
    , CatalogVersionsBehind   = IIF(NULLIF(SyncSourceInfo.SyncCatalogVersion, '') IS NULL, NULL, SyncSourceInfo.SyncCatalogVersion - UpdateScan.LastScanPackageVersion)
    , LastScanError           = NULLIF(UpdateScan.LastErrorCode, 0)
FROM fn_rbac_FullCollectionMembership(@UserSIDs) AS CollectionMembers
    JOIN fn_rbac_R_System(@UserSIDs) AS Systems ON Systems.ResourceID = CollectionMembers.ResourceID
    LEFT JOIN fn_rbac_CombinedDeviceResources(@UserSIDs) AS CombinedResources ON CombinedResources.MachineID = Systems.ResourceID
    LEFT JOIN fn_rbac_GS_OPERATING_SYSTEM(@UserSIDs) AS OperatingSystem ON OperatingSystem.ResourceID = Systems.ResourceID
    LEFT JOIN fn_rbac_CH_ClientSummary(@UserSIDs) AS ClientSummary ON ClientSummary.ResourceID = Systems.ResourceID
    LEFT JOIN fn_rbac_UpdateScanStatus(@UserSIDs) AS UpdateScan ON UpdateScan.ResourceID = CollectionMembers.ResourceID
        AND (
            @UpdateSearchID = UpdateScan.UpdateSource_ID OR @UpdateSearchID IS NULL
        )
    LEFT JOIN fn_rbac_StateNames(@UserSIDs) AS StateNames ON StateNames.StateID = UpdateScan.LastScanState
        AND StateNames.TopicType = 501                                             -- Update source scan summarization TopicTypeID
    OUTER APPLY (
        SELECT TOP 1 SUPSyncStatus.SyncCatalogVersion
        FROM vSMS_SUPSyncStatus AS SUPSyncStatus
        WHERE SUPSyncStatus.WSUSSourceServer = 'Microsoft Update'                  -- Select a WSUS Server that syncs directly with Microsoft
    ) AS SyncSourceInfo
WHERE CollectionMembers.CollectionID   = @CollectionID
    AND CollectionMembers.ResourceType = 5                                         -- Select devices only
    AND ISNULL(StateNames.StateID, 0) IN (@ScanStates)

/* #endregion */
/*##=============================================*/
/*## END QUERY BODY                              */
/*##=============================================*/