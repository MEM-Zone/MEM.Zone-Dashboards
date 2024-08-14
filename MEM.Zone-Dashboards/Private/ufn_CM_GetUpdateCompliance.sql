/*
.SYNOPSIS
    Gets the software update compliance for a Collection in ConfigMgr.
.DESCRIPTION
    Gets the software update compliance in ConfigMgr by Collection and All Updates.
.PARAMETER UserSIDs
    Specifies the Users SID.
.PARAMETER CollectionID
    Specifies CollectionID.
.PARAMETER Locale
    Specifies the system Locale.
.PARAMETER Category
    Specifies the update Category(s) to query.
.PARAMETER Targeted
    Specifies to query Targeted or all updates.
PARAMETER Enabled
    Specifies to query Enabled or all updates.
PARAMETER Superseded
    Specifies to query Superseded or all updates.
PARAMETER HealthThresholds
    Specifies to the HealthThresholds for setting a system healthy or unhealthy.
.EXAMPLE
    SELECT ResourceID, Missing FROM dbo.ufn_CM_GetUpdateCompliance('Disabled', 'SMS00001', 2, '16777247,16777248', 1, 1, 0, '45,120,14,40,8')
.NOTES
    Requires SQL 2016.
    Requires SELECT access on dbo.vSMS_ServiceWindow and on itself for smsschm_users (SCCM Reporting).
    Replace the <SITE_CODE> with your CM Site Code and uncomment SSMS region if running directly from SSMS.
    Run the code in SQL Server Management Studio.
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
-- USE [CM_<SITE_CODE>]

/* Drop function if it exists */
-- IF OBJECT_ID('[dbo].[ufn_CM_GetUpdateCompliance]') IS NOT NULL
--    BEGIN
--        DROP FUNCTION [dbo].[ufn_CM_GetUpdateCompliance]
--    END
-- GO
/* #endregion */

/* #region create ufn_CM_GetUpdateCompliance */
CREATE FUNCTION [dbo].[ufn_CM_GetUpdateCompliance] (
    @UserSIDs           AS NVARCHAR(10)
    , @CollectionID     AS NVARCHAR(10)
    , @Locale           AS INT
    , @Category         AS NVARCHAR(200)
    , @Targeted         AS INT
    , @Enabled          AS INT
    , @Superseded       AS INT
    , @HealthThresholds AS NVARCHAR(20)
)

RETURNS @UpdateCompliance TABLE (
    ResourceID              INT
    , HealthStates          INT
    , Missing               INT
    , Compliant             NVARCHAR(7)
    , DeviceFQDN            NVARCHAR(100)
    , DeviceName            NVARCHAR(15)
    , PendingRestart        NVARCHAR(100)
    , FreeSpace             NVARCHAR(15)
    , ClientState           NVARCHAR(30)
    , ClientVersion         NVARCHAR(20)
    , LastUpdateScan        INT
    , LastUpdateScanTime    DATETIME
    , LastScanError         INT
    , NextServiceWindow     DATETIME
    , ServiceWindowDuration INT
    , ServiceWindowOpen     BIT
    , SerialNumber          NVARCHAR(100)
)
AS
    BEGIN

        /* Check for helper function */
        DECLARE @HelperFunctionExists     AS INT = 0;
        IF OBJECT_ID(N'[dbo].[ufn_CM_GetNextMaintenanceWindow]') IS NOT NULL
            SET @HelperFunctionExists = 1;

        /* Variable declaration */
        DECLARE @LCID                     AS INT = dbo.fn_LShortNameToLCID(@Locale);

        /* Initialize memory tables */
        DECLARE @HealthThresholdVariables TABLE (ID INT IDENTITY(1,1), Threshold INT);
        DECLARE @HealthState              TABLE (BitMask INT, StateName NVARCHAR(250));
        DECLARE @ClientState              TABLE (BitMask INT, StateName NVARCHAR(100));
        DECLARE @Categories               TABLE (Category INT);
        DECLARE @MaintenanceInfo          TABLE (
            ResourceID              INT
            , NextServiceWindow     DATETIME
            , ServiceWindowStart    DATETIME
            , ServiceWindowDuration INT
            , ServiceWindowEnabled  BIT
            , IsUTCTime             BIT
        )

        /* Populate @HealthThresholdVariables table */
        INSERT INTO @HealthThresholdVariables (Threshold)
        SELECT VALUE FROM STRING_SPLIT(@HealthThresholds, N',')

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

        /* Populate @Categories table */
        INSERT INTO @Categories (Category)
        SELECT VALUE FROM STRING_SPLIT(@Category, N',')

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
                        , IsUTCTime             = NextServiceWindow.IsUTCTime
                        , RowNumber             = DENSE_RANK() OVER (PARTITION BY CollectionMembers.ResourceID ORDER BY IIF(
                            NextServiceWindow.NextServiceWindow IS NULL, 1, 0), NextServiceWindow.NextServiceWindow, ServiceWindow.ServiceWindowID
                        )                                                  -- Order by NextServiceWindow with NULL Values last
                    FROM fn_rbac_FullCollectionMembership(@UserSIDs) AS CollectionMembers
                        -- This join links Devices to ServiceWindow Collections
                        JOIN fn_rbac_FullCollectionMembership(@UserSIDs) AS SWCollectionMembers ON SWCollectionMembers.ResourceID = CollectionMembers.ResourceID
                        JOIN vSMS_ServiceWindow AS ServiceWindow ON ServiceWindow.SiteID = SWCollectionMembers.CollectionID
                        CROSS APPLY ufn_CM_GetNextMaintenanceWindow(ServiceWindow.Schedules, ServiceWindow.RecurrenceType) AS NextServiceWindow
                    WHERE ServiceWindowType <> 5                           -- OSD Maintenance Windows
                        AND CollectionMembers.CollectionID = @CollectionID -- Filters on CollectionID
                        AND CollectionMembers.ResourceType = 5             -- Select devices only
                )

                /* Populate MaintenanceInfo table and remove duplicates */
                INSERT INTO @MaintenanceInfo(ResourceID, NextServiceWindow, ServiceWindowStart, ServiceWindowDuration, ServiceWindowEnabled, IsUTCTime)
                    SELECT
                        ResourceID
                        , NextServiceWindow
                        , ServiceWindowStart
                        , ServiceWindowDuration
                        , ServiceWindowEnabled
                        , IsUTCTime
                    FROM Maintenance_CTE
                    WHERE RowNumber = 1 -- Remove duplicates
            END

        /* Get update data */
        ;
        WITH UpdateInfo_CTE
        AS (
            SELECT
                ResourceID          = Systems.ResourceID
                , Missing           = COUNT(*)
            FROM fn_rbac_R_System(@UserSIDs) AS Systems
                JOIN fn_rbac_UpdateComplianceStatus(@UserSIDs) AS ComplianceStatus ON ComplianceStatus.ResourceID = Systems.ResourceID
                    AND ComplianceStatus.Status = 2                                  -- Filter on 'Required' (0 = Unknown, 1 = NotRequired, 2 = Required, 3 = Installed)
                JOIN fn_rbac_ClientCollectionMembers(@UserSIDs) AS CollectionMembers ON CollectionMembers.ResourceID = ComplianceStatus.ResourceID
                JOIN fn_rbac_UpdateInfo(@LCID, @UserSIDs) AS UpdateCIs ON UpdateCIs.CI_ID = ComplianceStatus.CI_ID
                    AND UpdateCIs.IsExpired = 0                                      -- Filter on Expired
                    AND UpdateCIs.IsSuperseded IN (@Superseded)                      -- Filter on Superseeded
                    AND UpdateCIs.IsEnabled IN (@Enabled)                            -- Filter on Deployment Enabled
                    AND UpdateCIs.CIType_ID IN (1, 8)                                -- Filter on 1 Software Updates, 8 Software Update Bundle (v_CITypes)
                JOIN fn_rbac_CICategoryInfo_All(@LCID, @UserSIDs) AS CICategoryCompany ON CICategoryCompany.CI_ID = UpdateCIs.CI_ID
                    AND CICategoryCompany.CategoryTypeName = N'Company'
                JOIN fn_rbac_CICategoryInfo_All(@LCID, @UserSIDs) AS CICategoryClassification ON CICategoryClassification.CI_ID = UpdateCIs.CI_ID
                    AND CICategoryClassification.CategoryTypeName = N'UpdateClassification'
                    -- Filter on Selected Update Classification Categories
                    AND CICategoryClassification.CategoryInstanceID IN (SELECT Category FROM @Categories)
                LEFT JOIN fn_rbac_CITargetedMachines(@UserSIDs) AS Targeted ON Targeted.CI_ID = ComplianceStatus.CI_ID
                    AND Targeted.ResourceID = ComplianceStatus.ResourceID
            WHERE CollectionMembers.CollectionID = @CollectionID
                AND IIF(Targeted.ResourceID IS NULL, 0, 1) IN (@Targeted)            -- Filter on 'Targeted' or 'NotTargeted'
            GROUP BY Systems.ResourceID
        )

        /* Create result table */
        INSERT INTO @UpdateCompliance(ResourceID, HealthStates, Missing, Compliant, DeviceFQDN, DeviceName, PendingRestart, FreeSpace, ClientState, ClientVersion, LastUpdateScan, LastUpdateScanTime, LastScanError, NextServiceWindow, ServiceWindowDuration, ServiceWindowOpen, SerialNumber)

        /* Get device info */
        SELECT Systems.ResourceID

            /* Set Health states. You can find the coresponding values in the HealthState table above */
            , HealthStates          = (
                -- Client Unmanaged
                IIF(
                    CombinedResources.IsClient != 1
                    , POWER(1, 1), 0
                )
                -- Client Inactive
                +
                IIF(
                    ClientSummary.ClientStateDescription        = N'Inactive/Pass'
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
                IIF(
                    CombinedResources.ClientState != 0
                    , POWER(8, 1), 0
                )
                -- Update Scan Failed
                +
                IIF(
                    UpdateScan.LastErrorCode != 0
                    , POWER(16, 1), 0
                )
                -- Update Scan Late
                +
                IIF(
                    UpdateScan.LastScanTime < (SELECT DATEADD(dd, -@HT_LastScanTime, CURRENT_TIMESTAMP))
                    , POWER(32, 1), 0
                )
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
                IIF(
                    DATEADD(mi, ServiceWindowDuration, NextServiceWindow) > (SELECT DATEADD(dd, @HT_DistantMW, CURRENT_TIMESTAMP))
                    , POWER(128, 1), 0
                )
                -- Short Maintenace Window
                +
                IIF(
                    ServiceWindowDuration BETWEEN 0 AND @HT_ShortMW
                    , POWER(256, 1), 0
                )
                -- Expired Maintenance Window
                +
                IIF(
                    DATEADD(mi, ServiceWindowDuration, ISNULL(NextServiceWindow, ServiceWindowStart)) <= CURRENT_TIMESTAMP
                        AND ServiceWindowStart IS NOT NULL
                        AND CombinedResources.IsClient = 1
                    , POWER(512, 1), 0
                )
                -- Disabled Maintenance Window
                +
                IIF(
                    ServiceWindowEnabled != 1
                    , POWER(1024, 1), 0
                )
                -- High Uptime
                +
                IIF(
                    DATEDIFF(dd, OperatingSystem.LastBootUpTime0, CURRENT_TIMESTAMP) > @HT_Uptime
                    , POWER(2048, 1), 0
                )
                -- Required VS Uptime
                +
                IIF(
                    DATEDIFF(dd, OperatingSystem.LastBootUpTime0, CURRENT_TIMESTAMP) > @HT_Uptime
                        AND ISNULL(Missing, (IIF(CombinedResources.IsClient = 1, 0, NULL))) = 0
                    , POWER(4096, 1), 0
                )
                -- Free Space Threshold Exeeded
                +
                IIF(
                    CONVERT(DECIMAL(10, 2), LogicalDisk.FreeSpace0 / 1024.0) < @HT_FreeSpace
                    , POWER(8192, 1), 0
                )
            )
            , Missing               = ISNULL(Missing, (IIF(CombinedResources.IsClient = 1, 0, NULL)))
            , Compliant             = (
                CASE ISNULL(Missing, (IIF(CombinedResources.IsClient = 1, 0, NULL)))
                    WHEN NULL THEN 'Unknown'
                    WHEN 0    THEN 'Yes'
                    ELSE 'No'
                END
            )
            , DeviceFQDN            = (
                IIF(
                    SystemNames.Resource_Names0 IS NOT NULL, UPPER(SystemNames.Resource_Names0)
                    , IIF(Systems.Full_Domain_Name0 IS NOT NULL, Systems.Name0 + N'.' + Systems.Full_Domain_Name0, Systems.Name0)
                )
            )
            , DeviceName            = Systems.Name0
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
            , NextServiceWindow     = CONVERT(NVARCHAR(16), NextServiceWindow, 120)
            , ServiceWindowDuration = ServiceWindowDuration
            , ServiceWindowOpen     = IIF(
                DATEADD(mi, ServiceWindowDuration, NextServiceWindow) > CURRENT_TIMESTAMP
                        AND NextServiceWindow < CURRENT_TIMESTAMP
                        , 1, 0 -- 1 = Open, 2 = Closed
            )
            , SerialNumber = BIOS.SerialNumber0
        FROM fn_rbac_R_System(@UserSIDs) AS Systems
            JOIN fn_rbac_GS_PC_BIOS(@UserSIDs) AS BIOS ON BIOS.ResourceID = Systems.ResourceID
            JOIN fn_rbac_CombinedDeviceResources(@UserSIDs) AS CombinedResources ON CombinedResources.MachineID = Systems.ResourceID
            JOIN fn_rbac_FullCollectionMembership(@UserSIDs) AS CollectionMembers ON CollectionMembers.ResourceID = Systems.ResourceID
            LEFT JOIN fn_rbac_RA_System_ResourceNames(@UserSIDs) AS SystemNames ON SystemNames.ResourceID = CollectionMembers.ResourceID
            LEFT JOIN fn_rbac_GS_OPERATING_SYSTEM(@UserSIDs) AS OperatingSystem ON OperatingSystem.ResourceID = CollectionMembers.ResourceID
            LEFT JOIN fn_rbac_GS_LOGICAL_DISK(@UserSIDs) AS LogicalDisk ON LogicalDisk.ResourceID = CollectionMembers.ResourceID
                AND LogicalDisk.DriveType0 = 3     -- Local Disk
                AND LogicalDisk.Name0      = N'C:' -- System Drive Only
            LEFT JOIN fn_rbac_CH_ClientSummary(@UserSIDs) AS ClientSummary ON ClientSummary.ResourceID = CollectionMembers.ResourceID
            LEFT JOIN fn_rbac_UpdateScanStatus(@UserSIDs) AS UpdateScan ON UpdateScan.ResourceID = CollectionMembers.ResourceID
            LEFT JOIN @MaintenanceInfo AS Maintenance ON Maintenance.ResourceID = CollectionMembers.ResourceID
            LEFT JOIN UpdateInfo_CTE AS UpdateInfo ON UpdateInfo.ResourceID = CollectionMembers.ResourceID
        WHERE CollectionMembers.CollectionID = @CollectionID

        /* Return result */
        RETURN
    END
/* #endregion */

/* #endregion */
/*##=============================================*/
/*## END QUERY BODY                              */
/*##=============================================*/

--CREATE VIEW v_CM_GetUpdateCompliance
--AS (
--SELECT
--	UpdateCompliance.ResourceID
--	, UpdateCompliance.HealthStates
--	, UpdateCompliance.Missing
--	, UpdateCompliance.Compliant
--  , UpdateCompliance.DeviceFQDN
--	, UpdateCompliance.DeviceName
--	, UpdateCompliance.PendingRestart
--	, UpdateCompliance.FreeSpace
--	, UpdateCompliance.ClientState
--	, UpdateCompliance.ClientVersion
--	, UpdateCompliance.LastUpdateScan
--	, UpdateCompliance.LastUpdateScanTime
--	, UpdateCompliance.LastScanError
--	, UpdateCompliance.NextServiceWindow
--	, UpdateCompliance.ServiceWindowDuration
--	, UpdateCompliance.ServiceWindowOpen
--	, UpdateCompliance.SerialNumber
--FROM dbo.ufn_CM_GetUpdateCompliance('Disabled', 'SMS00001', 2, '16777247', 1, 1, 0, '45,120,14,40,8') AS UpdateCompliance
--)