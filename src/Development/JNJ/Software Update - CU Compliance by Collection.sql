/*
.SYNOPSIS
    Gets the cumulative update compliance for a Collection in ConfigMgr.
.DESCRIPTION
    Gets the cumulative update compliance in ConfigMgr for a Collection by Date Range.
.NOTES
    Requires SQL 2016.
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
--DECLARE @UserSIDs            AS NVARCHAR(10)  = 'SMS0001';
--DECLARE @CollectionID        AS NVARCHAR(10)  = 'SMS0001';
--DECLARE @DateRange           AS NVARCHAR(22)  = 'SMS0001';
--DECLARE @Compliant           AS NVARCHAR(8)   = 'SMS0001'; -- 'Yes', 'No', 'Unknown'
--DECLARE @Locale              AS NVARCHAR(10)  = 2;

/* Variable declaration */
--DECLARE @LCID                AS INT = dbo.fn_LShortNameToLCID(@Locale);
DECLARE @LCID                AS NVARCHAR(5)  = 'SMS0001';                -- Stupidity Workaround
DECLARE @Year                AS NVARCHAR(4)  = LEFT(@DateRange, 4);   -- First 4 characters  represent the year;
DECLARE @StartDate           AS NVARCHAR(10) = LEFT(@DateRange, 10);  -- First 10 characters represent the start date;
DECLARE @EndDate             AS NVARCHAR(10) = RIGHT(@DateRange, 10); -- Last 10 characters represent the end date;
DECLARE @Win10_2021_LTSC_EOS AS DATETIME = '2027-01-12'
USE CM_JNJ; -- Stupidity Workaround

/* Cleanup temporary tables */
IF OBJECT_ID(N'tempdb..#UpdateCompliance', N'U') IS NOT NULL DROP TABLE #UpdateCompliance;
IF OBJECT_ID(N'tempdb..#ClientState', N'U')      IS NOT NULL DROP TABLE #ClientState;
IF OBJECT_ID(N'tempdb..#OSServicingState', N'U') IS NOT NULL DROP TABLE #OSServicingState;
IF OBJECT_ID(N'tempdb..#OSServicing', N'U')      IS NOT NULL DROP TABLE #OSServicing;

/* Create temporary tables */
CREATE TABLE #ClientState (BitMask INT, StateName NVARCHAR(100));
CREATE TABLE #OSServicingState (Build NVARCHAR(10), Branch INT, Version NVARCHAR(20), ServicingState INT);
CREATE TABLE #OSServicing (StateNumber INT, StateName NVARCHAR(20));

/* Create indexes for performance */
CREATE CLUSTERED INDEX ix_tempCIndexAft ON #ClientState (BitMask);
CREATE CLUSTERED INDEX ix_tempCIndexAft ON #OSServicingState (Build, Branch);
CREATE CLUSTERED INDEX ix_tempCIndexAft ON #OSServicing (StateNumber);

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
;

/* Get compliance info */
WITH UpdateCompliance_CTE
AS (
    SELECT
        ResourceID    = Systems.ResourceID
        , Device      = Systems.Name0
        , Compliant   = (
            CASE
                WHEN ComplianceStatus.Status = 0 THEN N'Unknown'
                WHEN ComplianceStatus.Status = 2 THEN N'No'
                WHEN ComplianceStatus.Status = 3 THEN N'Yes'
                ELSE 'Unknown'
            END
        )
        , UpdateTitle = UpdateCIs.Title
        , ReleaseDate = UpdateCIs.DateCreated
        , RowRank     = ROW_NUMBER() OVER (PARTITION BY Systems.ResourceID ORDER BY ComplianceStatus.Status DESC, UpdateCIs.DateCreated ASC)
    FROM fn_rbac_UpdateComplianceStatus(@UserSIDs) AS ComplianceStatus
        INNER JOIN fn_rbac_R_System(@UserSIDs) AS Systems ON Systems.ResourceID = ComplianceStatus.ResourceID
        INNER JOIN fn_rbac_UpdateInfo(@LCID, @UserSIDs) AS UpdateCIs ON UpdateCIs.CI_ID = ComplianceStatus.CI_ID
            AND UpdateCIs.CIType_ID = 8                                             -- Filter by Update Bundles
            AND UpdateCIs.Title LIKE @Year + '-__ Cumulative Update for Windows 1%' -- Filter by Cumulative Update
        INNER JOIN fn_rbac_ClientCollectionMembers(@UserSIDs) AS CollectionMembers ON CollectionMembers.ResourceID = Systems.ResourceID
    WHERE
        UpdateCIs.DateCreated >= @StartDate                -- Filter by Date Range
        AND UpdateCIs.DateCreated <= @EndDate              -- Filter by Date Range
        AND CollectionMembers.CollectionID = @CollectionID -- Filter by CollectionID
        AND ComplianceStatus.Status != 1                   -- Not Required
)
SELECT
  ResourceID    = UpdateCompliance.ResourceID
  , Device      = UpdateCompliance.Device
  , UpdateTitle = UpdateCompliance.UpdateTitle
  , ReleaseDate = CONVERT(NVARCHAR(10), UpdateCompliance.ReleaseDate, 126) -- Convert to ISO 8601 Date Format
  , Compliant   = UpdateCompliance.Compliant
INTO #UpdateCompliance
FROM
    UpdateCompliance_CTE AS UpdateCompliance
WHERE
   UpdateCompliance.RowRank = 1 -- Filter on Overall Compliance for Each Device

SELECT
    Systems.ResourceID
    , Device            = (
        IIF(
            SystemNames.Resource_Names0 IS NULL
            , IIF(Systems.Full_Domain_Name0 IS NULL, Systems.Name0, Systems.Name0 + N'.' + Systems.Full_Domain_Name0)
            , UPPER(SystemNames.Resource_Names0)
        )
    )
    , UpdateTitle      = UpdateCompliance.UpdateTitle
    , ReleaseDate      = UpdateCompliance.ReleaseDate
    , Compliant        = IIF(OSInfo.ServicingState = 4, N'No', ISNULL(UpdateCompliance.Compliant, N'Unknown'))
    , OSBuild          = Systems.Build01
    , OSServicingState = ISNULL((SELECT StateName FROM #OSServicing AS OSServicing WHERE OSServicing.StateNumber = OSInfo.ServicingState), N'Unknown')
    , OSVersion        = OSInfo.Version
    , ClientState      = IIF(Systems.Client0 = 1, ISNULL(ClientSummary.ClientStateDescription, 'Unknown'), 'Unmanaged')
    , LastUpdateScan   = DATEDIFF(dd, UpdateScan.LastScanTime, CURRENT_TIMESTAMP)
    , LastScanError    = UpdateScan.LastErrorCode
FROM fn_rbac_R_System(@UserSIDs) AS Systems
    INNER JOIN fn_rbac_FullCollectionMembership(@UserSIDs)  AS CollectionMembers ON CollectionMembers.ResourceID = Systems.ResourceID
    LEFT  JOIN fn_rbac_RA_System_ResourceNames(@UserSIDs) AS SystemNames ON SystemNames.ResourceID = CollectionMembers.ResourceID
    LEFT  JOIN #UpdateCompliance AS UpdateCompliance ON UpdateCompliance.ResourceID = CollectionMembers.ResourceID
    LEFT  JOIN fn_rbac_CH_ClientSummary(@UserSIDs) AS ClientSummary ON ClientSummary.ResourceID = CollectionMembers.ResourceID
    LEFT  JOIN fn_rbac_UpdateScanStatus(@UserSIDs) AS UpdateScan ON UpdateScan.ResourceID = CollectionMembers.ResourceID
    OUTER APPLY (
        SELECT
            Version = OSLocalizedNames.Value
            , ServicingState = OSServicingStates.State
        FROM fn_GetWindowsServicingStates() AS OSServicingStates
            INNER JOIN fn_GetWindowsServicingLocalizedNames() AS OSLocalizedNames ON OSLocalizedNames.Name = OSServicingStates.Name
        WHERE OSServicingStates.Build = Systems.Build01
            AND OSServicingStates.Branch = Systems.OSBranch01
        UNION
        SELECT
            Version
            , ServicingState
        FROM #OSServicingState AS OSServicingState
        WHERE OSServicingState.Build =  Systems.Build01
            AND OSServicingState.Branch = IIF(Systems.OSBranch01 = N'', 1, Systems.OSBranch01)
    ) AS OSInfo
WHERE
    CollectionMembers.CollectionID = @CollectionID
    AND ISNULL(UpdateCompliance.Compliant, N'Unknown') IN (@Compliant)

/* Cleanup temporary tables */
IF OBJECT_ID(N'tempdb..#UpdateCompliance', N'U') IS NOT NULL DROP TABLE #UpdateCompliance;
IF OBJECT_ID(N'tempdb..#ClientState', N'U')      IS NOT NULL DROP TABLE #ClientState;
IF OBJECT_ID(N'tempdb..#OSServicingState', N'U') IS NOT NULL DROP TABLE #OSServicingState;
IF OBJECT_ID(N'tempdb..#OSServicing', N'U')      IS NOT NULL DROP TABLE #OSServicing;

/* #endregion */
/*##=============================================*/
/*## END QUERY BODY                              */
/*##=============================================*/