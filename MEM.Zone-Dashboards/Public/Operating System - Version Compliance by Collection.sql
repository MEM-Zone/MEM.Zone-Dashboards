/*
.SYNOPSIS
    Gets the operating system version compliance for a Collection in MEMCM.
.DESCRIPTION
    Gets the operating system compliance in MEMCM by Collection, operating system version and operating system type.
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
--DECLARE @UserSIDs            AS NVARCHAR(10) = 'Disabled';
--DECLARE @CollectionID        AS NVARCHAR(10) = 'VIT00984';
--DECLARE @Locale              AS INT          = 2;
--DECLARE @OSComplianceType    AS NVARCHAR(20) = 5; --'Professional'
--DECLARE @OSComplianceVersion AS NVARCHAR(50) = '20H2';
--DECLARE @HealthThresholds    AS NVARCHAR(20) = '14,40,8';
--DECLARE @Compliant           AS INT          = 1; --'Compliant'
--DECLARE @ServicingState      AS INT          = 2; --'Current'

/* Variable declaration */
DECLARE @LCID                       AS INT = dbo.fn_LShortNameToLCID(@Locale);
DECLARE @LastSupportedLegacyOSBuild AS INT = 9600;

/* Initialize memory tables */
DECLARE @HealthThresholdVariables TABLE (ID INT IDENTITY(1,1), Threshold INT);
DECLARE @HealthState              TABLE (BitMask INT, StateName NVARCHAR(250));
DECLARE @ClientState              TABLE (BitMask INT, StateName NVARCHAR(100));
DECLARE @OSNamesNormalized        TABLE (OSName  NVARCHAR(100), OSType INT);

/* Populate @HealthThresholdVariables table */
INSERT INTO @HealthThresholdVariables (Threshold)
SELECT VALUE FROM STRING_SPLIT(@HealthThresholds, N',')

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
    , (64,  N'Uptime Threshold Exeeded')
    , (128, N'Free Space Threshold Exeeded')
    , (256, N'Servicing Expired')

/* Populate ClientState table */
INSERT INTO @ClientState (BitMask, StateName)
VALUES
    (0, N'No Reboot')
    , (1, N'Configuration Manager')
    , (2, N'File Rename')
    , (4, N'Windows Update')
    , (8, N'Add or Remove Feature')

/* Populate OSNamesNormalized table */
INSERT INTO @OSNamesNormalized (OSName, OSType)
SELECT DISTINCT
    OperatingSystem.Caption0,
    CASE
        WHEN RIGHT(OperatingSystem.Caption0, 7) = 'Preview' THEN 1 --1 Insider Preview
        WHEN OperatingSystem.Caption0 LIKE '%Dat%'          THEN 2 --2 Datacenter
        WHEN OperatingSystem.Caption0 LIKE '%Sta%'          THEN 3 --3 Standard
        WHEN OperatingSystem.Caption0 LIKE '%Ent%'          THEN 4 --4 Enterprise
        WHEN OperatingSystem.Caption0 LIKE '%Pro%'          THEN 5 --5 Professional
        WHEN OperatingSystem.Caption0 LIKE '%Edu%'          THEN 6 --6 Education
        ELSE 0                                                     --0 Unknown/NA
    END
FROM fn_rbac_GS_OPERATING_SYSTEM(@UserSIDs) AS OperatingSystem

/* Get device info */
;
WITH DeviceInfo_CTE
AS (
    SELECT Systems.ResourceID

        /* Set Health states. You can find the coresponding values in the HealthState table above */
        , HealthStates          = (
            --Client Unmanaged
            IIF(
                CombinedResources.IsClient != 1
                , POWER(1, 1), 0
            )
            --Client Inactive
            +
            IIF(
                ClientSummary.ClientStateDescription        = N'Inactive/Pass'
                    OR ClientSummary.ClientStateDescription = N'Inactive/Fail'
                    OR ClientSummary.ClientStateDescription = N'Inactive/Unknown'
                , POWER(2, 1), 0
            )
            --Client Health Evaluation Failed
            +
            IIF(
                ClientSummary.ClientStateDescription        = N'Active/Fail'
                    OR ClientSummary.ClientStateDescription = N'Inactive/Fail'
                , POWER(4, 1), 0
            )
            --Pending Restart
            +
            IIF(
                CombinedResources.ClientState != 0
                , POWER(8, 1), 0
            )
            --Update Scan Failed
            +
            IIF(
                UpdateScan.LastErrorCode != 0
                , POWER(16, 1), 0
            )
            --Update Scan Late
            +
            IIF(
                UpdateScan.LastScanTime < (SELECT DATEADD(dd, -@HT_LastScanTime, CURRENT_TIMESTAMP))
                , POWER(32, 1), 0
            )
            --High Uptime
            +
            IIF(
                DATEDIFF(dd, OperatingSystem.LastBootUpTime0, CURRENT_TIMESTAMP) > @HT_Uptime
                , POWER(64, 1), 0
            )
            --Free Space Threshold Exeeded
            +
            IIF(
                CONVERT(DECIMAL(10, 2), LogicalDisk.FreeSpace0 / 1024.0) < @HT_FreeSpace
                    AND OSInfo.Version NOT IN (@OSComplianceVersion)
                , POWER(128, 1), 0
            )
            --Servicing Expired
            +
            IIF(
                OSInfo.ServicingState = 4 OR (Systems.Build01 = '6.3.9600' AND CURRENT_TIMESTAMP > CONVERT(DATETIME, '2023-01-10'))
                , POWER(256, 1)
                , IIF(
                    CONVERT(
                        INT
                        , (SELECT SUBSTRING(
                                (SELECT CAST('<t>' + REPLACE(Systems.Build01, '.','</t><t>') + '</t>' AS XML).value('/t[3]','NVARCHAR(500)'))
                                , 0, 6
                            )
                        )
                    ) < @LastSupportedLegacyOSBuild
                    , POWER(256, 1), 0
                )
            )
        )
        , Compliant             = (
            CASE
                WHEN ISNULL(OSInfo.Version, 'N/A') IN (@OSComplianceVersion)
                    AND ISNULL(OSNamesNormalized.OSType, 0)                          IN (@OSComplianceType) THEN 1 --'Compliant'
                WHEN OSInfo.Version IS NULL
                    AND IIF(RIGHT(OperatingSystem.Caption0, 7) = 'Preview', 1, NULL) IN (@OSComplianceType) THEN 1 --'Compliant'
            ELSE
                IIF(
                    OSInfo.Version IS NULL
                    , IIF(
                        CONVERT(
                            INT
                            , (SELECT SUBSTRING(
                                    (SELECT CAST('<t>' + REPLACE(Systems.Build01, '.','</t><t>') + '</t>' AS XML).value('/t[3]','NVARCHAR(500)'))
                                    , 0, 6
                                )
                            ) --Select only patch version from build number
                        ) <= @LastSupportedLegacyOSBuild OR ISNULL(OSNamesNormalized.OSType, 0) NOT IN (@OSComplianceType)
                    , 2, 0    --'NonCompliant', 'Unknown'
                    )
                , 2
                ) --'NonCompliant'
            END
        )
        , Device                = (
            IIF(
                SystemNames.Resource_Names0 IS NOT NULL, UPPER(SystemNames.Resource_Names0)
                , IIF(Systems.Full_Domain_Name0 IS NOT NULL, Systems.Name0 + N'.' + Systems.Full_Domain_Name0, Systems.Name0)
            )
        )
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
        , OSVersion             = ISNULL(OSInfo.Version, IIF(RIGHT(OperatingSystem.Caption0, 7) = 'Preview', 'Insider Preview', NULL))
        , OSBuildNumber         = Systems.Build01
        , OSServicingState      = (
            ISNULL(OSInfo.ServicingState,
                CASE
                    WHEN Systems.Build01       = '6.3.9600'
                        AND CURRENT_TIMESTAMP <= CONVERT(DATETIME, '2023-01-10') THEN 3 --'Expiring Soon'
                    WHEN Systems.Build01       = '6.3.9600'
                        AND CURRENT_TIMESTAMP >  CONVERT(DATETIME, '2023-01-10') THEN 4 --'Expired'
                    ELSE
                        IIF(
                            CONVERT(
                                INT
                                , (SELECT SUBSTRING(
                                        (SELECT CAST('<t>' + REPLACE(Systems.Build01, '.','</t><t>') + '</t>' AS XML).value('/t[3]','NVARCHAR(500)'))
                                        , 0, 6 --Last 6 characters
                                    )
                                )
                            ) < @LastSupportedLegacyOSBuild
                            , 4, 5             --'Expired', 'Unknown'
                        )
                END
            )
        ) --0 = 'Internal', 1 = 'Insider', 2 = 'Current', 3 = 'Expiring Soon', 4 = 'Expired', 5 = 'Unknown'
        , UserDeviceAffinity    = UserDeviceAffinityInfo.AssignedUser
        , Domain                = Systems.Resource_Domain_OR_Workgr0
        , Country               = Users.co
        , Location              = Users.l
        , Uptime                = DATEDIFF(dd, OperatingSystem.LastBootUpTime0, CURRENT_TIMESTAMP)
        , LastBootTime          = CONVERT(NVARCHAR(16), OperatingSystem.LastBootUpTime0, 120)
        , PendingRestart        = (
            CASE
                WHEN CombinedResources.IsClient      = 0
                    OR CombinedResources.ClientState = 0
                THEN NULL
                ELSE (
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
            END
        )
        , FreeSpace             = CONVERT(DECIMAL(10, 2), LogicalDisk.FreeSpace0 / 1024.0)
        , ClientState           = IIF(CombinedResources.IsClient = 1, ClientSummary.ClientStateDescription, 'Unmanaged')
        , ClientVersion         = CombinedResources.ClientVersion
        , LastUpdateScan        = DATEDIFF(dd, UpdateScan.LastScanTime, CURRENT_TIMESTAMP)
        , LastUpdateScanTime    = CONVERT(NVARCHAR(16), UpdateScan.LastScanTime, 120)
        , LastScanError         = NULLIF(UpdateScan.LastErrorCode, 0)
    FROM fn_rbac_R_System(@UserSIDs) AS Systems
        JOIN fn_rbac_CombinedDeviceResources(@UserSIDs) AS CombinedResources ON CombinedResources.MachineID = Systems.ResourceID
        JOIN fn_rbac_FullCollectionMembership(@UserSIDs) AS CollectionMembers ON CollectionMembers.ResourceID = CombinedResources.MachineID
        LEFT JOIN fn_rbac_RA_System_ResourceNames(@UserSIDs) AS SystemNames ON SystemNames.ResourceID = CollectionMembers.ResourceID
        LEFT JOIN fn_rbac_GS_OPERATING_SYSTEM(@UserSIDs) AS OperatingSystem ON OperatingSystem.ResourceID = CollectionMembers.ResourceID
        LEFT JOIN fn_rbac_GS_LOGICAL_DISK(@UserSIDs) AS LogicalDisk ON LogicalDisk.ResourceID = CollectionMembers.ResourceID
            AND LogicalDisk.DriveType0 = 3     --Local Disk
            AND LogicalDisk.Name0      = N'C:' --System Drive Only
        LEFT JOIN fn_rbac_CH_ClientSummary(@UserSIDs) AS ClientSummary ON ClientSummary.ResourceID = CollectionMembers.ResourceID
        LEFT JOIN fn_rbac_UpdateScanStatus(@UserSIDs) AS UpdateScan ON UpdateScan.ResourceID = CollectionMembers.ResourceID
        LEFT JOIN fn_rbac_R_User(@UserSIDs) AS Users ON Users.User_Name0 = Systems.User_Name0
            AND Users.Windows_NT_Domain0 = Systems.Resource_Domain_OR_Workgr0 --Select only users from the machine domain
        LEFT JOIN @OSNamesNormalized AS OSNamesNormalized ON OSNamesNormalized.OSName = OperatingSystem.Caption0
        OUTER APPLY (
            SELECT
                Version = OSLocalizedNames.Value
                , ServicingState = OSServicingStates.State
            FROM fn_GetWindowsServicingLocalizedNames() AS OSLocalizedNames
                JOIN fn_GetWindowsServicingStates() AS OSServicingStates ON OSServicingStates.Build = Systems.Build01
            WHERE OSLocalizedNames.Name = OSServicingStates.Name
                AND Systems.OSBranch01 = OSServicingStates.Branch --Select only the branch of the installed OS
        ) AS OSInfo
        OUTER APPLY (
            SELECT
                AssignedUser = UserMachineRelationship.UniqueUserName
            FROM fn_rbac_UserMachineRelationship(@UserSIDs) AS UserMachineRelationship
            WHERE UserMachineRelationship.MachineResourceID = CollectionMembers.ResourceID
                AND UserMachineRelationship.CreationTime = (
                    SELECT MAX(UserMachineRelationshipInner.CreationTime) FROM fn_rbac_UserMachineRelationship(@UserSIDs) AS UserMachineRelationshipInner
                    WHERE UserMachineRelationshipInner.MachineResourceID = CollectionMembers.ResourceID
                ) --Select only the newest User Device Affinity
        ) AS UserDeviceAffinityInfo
    WHERE CollectionMembers.CollectionID = @CollectionID
)

SELECT
    DeviceInfo.ResourceID
    , DeviceInfo.HealthStates
    , DeviceInfo.Compliant
    , DeviceInfo.Device
    , DeviceInfo.OperatingSystem
    , DeviceInfo.OSVersion
    , DeviceInfo.OSBuildNumber
    , DeviceInfo.OSServicingState
    , DeviceInfo.UserDeviceAffinity
    , DeviceInfo.Domain
    , DeviceInfo.Country
    , DeviceInfo.Location
    , DeviceInfo.Uptime
    , DeviceInfo.LastBootTime
    , DeviceInfo.PendingRestart
    , DeviceInfo.FreeSpace
    , DeviceInfo.ClientState
    , DeviceInfo.ClientVersion
    , DeviceInfo.LastUpdateScan
    , DeviceInfo.LastUpdateScanTime
    , DeviceInfo.LastScanError
FROM DeviceInfo_CTE AS DeviceInfo
    WHERE Compliant IN (@Compliant)
        AND OSServicingState IN (@ServicingState)

/* #endregion */
/*##=============================================*/
/*## END QUERY BODY                              */
/*##=============================================*/