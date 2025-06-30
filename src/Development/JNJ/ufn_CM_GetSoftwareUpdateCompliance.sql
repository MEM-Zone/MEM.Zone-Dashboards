/*
.SYNOPSIS
    Gets the software update compliance for a device in ConfigMgr.
.DESCRIPTION
    Gets the software update compliance in ConfigMgr by Device and All Updates.
.PARAMETER UserSIDs
    Specifies the UserSIDs for RBAC.
.PARAMETER Collection
    Specifies the Collection ID or Collection Name of the collection it will query against.
.PARAMETER UpdateGroup
    Specifies the Group ID or Group Name for the software updates.
    Available Name Values:
        'All'
        '<UpdateGroupName>'
    Available ID Values:
        SELECT CI_ID, Title FROM v_AuthListInfo AS AuthList
    Default is 'All'.
.PARAMETER UpdateCategory
    Specifies the Update Category ID Or Udate Category Name for the software updates.
    Available Name Values:
        'Critical Updates'
        'Definition Updates'
        'Feature Packs'
        'Security Updates'
        'Service Packs'
        'Update Rollups'
        'Updates'
        'Upgrades'
        'All'
    Available ID Values:
        SELECT DISTINCT CategoryInstanceID FROM V_CICategoryInfo_All WHERE CategoryTypeName = N'UpdateClassification'
    Default is 'Security Updates'.
.PARAMETER UpdateVendor
    Specifies the Update Vendor ID or Vendor Name for the software updates.
    AvailableValues
        'Microsoft'
        '<VendorName>'
        ...
        'All'
    Available ID Values:
        SELECT DISTINCT CategoryInstanceID FROM V_CICategoryInfo_All WHERE CategoryTypeName = N'Company'
    Default is 'Microsoft'.
.PARAMETER IsTargeted
    Specifies the targeted state to filter.
    Available values:
        0 - No
        1 - Yes
    Default is '1'.
.PARAMETER IsEnabled
    Specifies the enabled state to filter.
    Available values:
        0 - No
        1 - Yes
    Default is '1'.
.PARAMETER IsSuperseded
    Specifies the superseded state to filter.
    Available values:
        0 - No
        1 - Yes
    Default is '0'.
.PARAMETER Compliant
    Specifies the compliance state to filter.
    Available values:
        0 - No
        1 - Yes
        2 - Unknown
        3 - All
    Default is '3'.
.PARAMETER HealthThresholds
    Specifies the health thresholds for the devices.
    Parameter values:
        '<Days>'    - Distant Maintenance Window
        '<Minutes>' - Short Maintenance Window
        '<Days>'    - Last Update Scan Time
        '<Days>'    - Uptime
        '<GB>'      - Free Space
    Default is '45,120,14,40,8'.
.EXAMPLE
    SELECT * FROM dbo.ufn_CM_GetSoftwareUpdateCompliance(@UserSIDs, N'DEV08EEB', N'Security Updates', N'Microsoft', 1, 1, 0, 1, '45,120,14,40,8')
.EXAMPLE
    SELECT * FROM dbo.ufn_CM_GetSoftwareUpdateCompliance('Disabled', N'DEV08EEB', NULL, NULL, NULL, NULL, NULL, NULL, NULL)
.NOTES
    Requires SQL 2016.
    Requires ufn_CM_GetNextMaintenanceWindowForDevice sql helper function in order to display the next maintenance window.
    Requires SELECT access on dbo.vSMS_ServiceWindow and on itself for smsschm_users (SCCM Reporting).
    Replace the <SITE_CODE> with your CM Site Code and uncomment SSMS region if running directly from SSMS.
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

/* #region SSMS */
--USE [<CM_SITE>]

/* Drop function if it exists */
--IF OBJECT_ID('[dbo].[ufn_CM_GetSoftwareUpdateCompliance]') IS NOT NULL
--    BEGIN
--        DROP FUNCTION [dbo].[ufn_CM_GetSoftwareUpdateCompliance]
--    END
--GO
/* #endregion */

/* #region create ufn_CM_GetSoftwareUpdateCompliance */
CREATE FUNCTION [dbo].[ufn_CM_GetSoftwareUpdateCompliance] (
    @UserSIDs           AS NVARCHAR(10)
    , @Collection       AS NVARCHAR(10)
    , @UpdateGroup      AS NVARCHAR(250)
    , @UpdateCategory   AS NVARCHAR(20)
    , @UpdateVendor     AS NVARCHAR(30)
    , @IsTargeted       AS BIT
    , @IsEnabled        AS BIT
    , @IsSuperseded     AS BIT
    , @Compliant        AS INT
    , @HealthThresholds AS NVARCHAR(20)
)
RETURNS @SoftwareUpdateCompliance TABLE (
    ResourceID              INT
    , HealthStates          INT
    , Missing               INT
    , Device                NVARCHAR(50)
    , OperatingSystem       NVARCHAR(100)
    , OSVersion             NVARCHAR(50)
    , OSBuild               NVARCHAR(10)
    , OSServicingState      NVARCHAR(20)
    , IPAddresses           NVARCHAR(500)
    , Uptime                INT
    , LastBootTime          NVARCHAR(16)
    , PendingRestart        NVARCHAR(100)
    , FreeSpace             DECIMAL(10, 2)
    , ClientState           NVARCHAR(50)
    , ClientVersion         NVARCHAR(50)
    , LastUpdateScan        INT
    , LastUpdateScanTime    NVARCHAR(16)
    , LastScanLocation      NVARCHAR(100)
    , LastScanError         INT
    , NextServiceWindow     NVARCHAR(16)
    , ServiceWindowDuration INT
    , ServiceWindowOpen     BIT
    , IsUTCTime             BIT
)
AS
    BEGIN

        /* Variable declaration */
        DECLARE @LCID                     AS INT = 1033; -- English

        /* Initialize variable tables */
        DECLARE @CompliantTable           AS TABLE (Compliant INT);
        DECLARE @HealthThresholdVariables AS TABLE (ID INT IDENTITY(1,1), Threshold INT);
        DECLARE @HealthState              AS TABLE (BitMask INT, StateName NVARCHAR(250));
        DECLARE @ClientState              AS TABLE (BitMask INT, StateName NVARCHAR(100));

        /* Check for helper function */
        DECLARE @HelperFunctionExists AS INT = 0;
        IF OBJECT_ID(N'[dbo].[ufn_CM_GetNextMaintenanceWindowForDevice]') IS NOT NULL
            SET @HelperFunctionExists = 1;

        /* Set parameter values */
        -- Compliant State
        IF ISNULL(@Compliant, 3) = 3 INSERT INTO @CompliantTable VALUES (0), (1), (2)
        ELSE INSERT INTO @CompliantTable VALUES (@Compliant)
        -- Health Thresholds
        IF @HealthThresholds IS NULL SET @HealthThresholds = N'45,120,14,40,8'

        /* Populate @HealthThresholdVariables table */
        INSERT INTO @HealthThresholdVariables (Threshold)
        --SELECT VALUE FROM STRING_SPLIT(@HealthThresholds, N',')
        SELECT SubString FROM [CM_JNJ].[dbo].[fn_SplitString](@HealthThresholds, N',') -- Stupidity Workaround

        /* Set Health Threshold variables */
        DECLARE @HT_DistantMW    AS INT = (SELECT Threshold FROM @HealthThresholdVariables WHERE ID = 1); -- Days
        DECLARE @HT_ShortMW      AS INT = (SELECT Threshold FROM @HealthThresholdVariables WHERE ID = 2); -- Minutes
        DECLARE @HT_LastScanTime AS INT = (SELECT Threshold FROM @HealthThresholdVariables WHERE ID = 3); -- Days
        DECLARE @HT_Uptime       AS INT = (SELECT Threshold FROM @HealthThresholdVariables WHERE ID = 4); -- Days
        DECLARE @HT_FreeSpace    AS INT = (SELECT Threshold FROM @HealthThresholdVariables WHERE ID = 5); -- GB

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
        INSERT INTO @ClientState (BitMask, StateName)
        VALUES
            (0, N'No Reboot')
            , (1, N'Configuration Manager')
            , (2, N'File Rename')
            , (4, N'Windows Update')
            , (8, N'Add or Remove Feature')

        /* Create result table */
        INSERT INTO @SoftwareUpdateCompliance (ResourceID, HealthStates, Missing, Device, OperatingSystem, OSVersion, OSBuild, OSServicingState, IPAddresses, Uptime, LastBootTime, PendingRestart, FreeSpace, ClientState, ClientVersion, LastUpdateScan, LastUpdateScanTime, LastScanLocation, LastScanError, NextServiceWindow, ServiceWindowDuration, ServiceWindowOpen, IsUTCTime)

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
                            AND UpdateCompliance.Compliant = 1
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
                        OSInfo.ServicingStateNumber = 4
                        , POWER(16384, 1)
                        , 0
                    )
                )
                , Missing               = UpdateCompliance.Missing
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
                , OSVersion             = ISNULL(OSInfo.Version, IIF(RIGHT(OperatingSystem.Caption0, 7) = 'Preview', 'Insider Preview', NULL))
                , OSBuild               = Systems.Build01
                , OSServicingState      = OSInfo.ServicingStateName
                , IPAddress             = IPAddress.Value
                , Uptime                = DATEDIFF(dd, OperatingSystem.LastBootUpTime0, CURRENT_TIMESTAMP)
                , LastBootTime          = CONVERT(NVARCHAR(16), OperatingSystem.LastBootUpTime0, 120)
                , PendingRestart        = (
                    STUFF(
                        REPLACE(
                            (
                                SELECT N'#!' + LTRIM(RTRIM(StateName)) AS [data()]
                                FROM @ClientState
                                WHERE BitMask & CombinedResources.ClientState <> 0
                                FOR XML PATH(N'')
                            ),
                            N' #!', N', '
                        ),
                        1, 2, N''
                    )
                )
                , FreeSpace             = CONVERT(DECIMAL(10, 2), LogicalDisk.FreeSpace0 / 1024.0)
                , ClientState           = IIF(CombinedResources.IsClient = 1, ClientSummary.ClientStateDescription, 'Unmanaged')
                , ClientVersion         = CombinedResources.ClientVersion
                , LastUpdateScan        = DATEDIFF(dd, UpdateScan.LastScanTime, CURRENT_TIMESTAMP)
                , LastUpdateScanTime    = CONVERT(NVARCHAR(16), UpdateScan.LastScanTime, 120)
                , LastScanLocation      = NULLIF(UpdateScan.LastScanPackageLocation, N'')
                , LastScanError         = NULLIF(UpdateScan.LastErrorCode, 0)
                , NextServiceWindow     = CONVERT(NVARCHAR(16), Maintenance.NextServiceWindow, 120)
                , ServiceWindowDuration = Maintenance.ServiceWindowDuration
                , ServiceWindowOpen     = Maintenance.IsServiceWindowOpen
                , IsUTCTime             = Maintenance.IsUTCTime
            FROM [CM_JNJ].[dbo].[fn_rbac_R_System](@UserSIDs) AS Systems
                JOIN [CM_JNJ].[dbo].[fn_rbac_CombinedDeviceResources](@UserSIDs) AS CombinedResources ON CombinedResources.MachineID = Systems.ResourceID
                JOIN [CM_JNJ].[dbo].[fn_rbac_FullCollectionMembership](@UserSIDs) AS CollectionMembers ON CollectionMembers.ResourceID = Systems.ResourceID
                JOIN [CM_JNJ].[dbo].[fn_rbac_RA_System_ResourceNames](@UserSIDs) AS SystemNames ON SystemNames.ResourceID = CollectionMembers.ResourceID
                JOIN [CM_JNJ].[dbo].[fn_rbac_GS_OPERATING_SYSTEM](@UserSIDs) AS OperatingSystem ON OperatingSystem.ResourceID = CollectionMembers.ResourceID
                JOIN [CM_JNJ].[dbo].[fn_rbac_GS_LOGICAL_DISK](@UserSIDs) AS LogicalDisk ON LogicalDisk.ResourceID = CollectionMembers.ResourceID
                    AND LogicalDisk.DriveType0 = 3     -- Local Disk
                    AND LogicalDisk.Name0      = N'C:' -- System Drive Only
                CROSS APPLY (
                    SELECT Value = IPAddress FROM [ufn_CM_DeviceIPAddress](@UserSIDs, Systems.ResourceID)
                ) AS IPAddress
                JOIN [CM_JNJ].[dbo].[fn_rbac_CH_ClientSummary](@UserSIDs) AS ClientSummary ON ClientSummary.ResourceID = CollectionMembers.ResourceID
                JOIN [CM_JNJ].[dbo].[fn_rbac_UpdateScanStatus](@UserSIDs) AS UpdateScan ON UpdateScan.ResourceID = CollectionMembers.ResourceID
                CROSS APPLY [dbo].[ufn_CM_GetNextMaintenanceWindowForDevice](@UserSIDs,CollectionMembers.ResourceID) AS Maintenance
                CROSS APPLY (
                    SELECT
                        Version
                        , ServicingStateNumber
                        , ServicingStateName
                    FROM [ufn_CM_DeviceOSInfo](Systems.ResourceID, Systems.Build01, Systems.OSBranch01)
                ) AS OSInfo
                LEFT JOIN  [dbo].[ufn_CM_MissingSoftwareUpdates](@UserSIDs, @Collection, @UpdateGroup, @UpdateCategory, @UpdateVendor, @IsTargeted, @IsEnabled, @IsSuperseded) AS UpdateCompliance ON UpdateCompliance.ResourceID = CollectionMembers.ResourceID
            WHERE CollectionMembers.CollectionID = @Collection
                AND EXISTS (SELECT Compliant FROM @CompliantTable WHERE UpdateCompliance.Compliant = Compliant) -- Compliant (0 = No, 1 = Yes, 2 = Unknown)

        /* Return result */
        RETURN
    END
    /* #endregion */

/* #endregion */
/*##=============================================*/
/*## END QUERY BODY                              */
/*##=============================================*/


