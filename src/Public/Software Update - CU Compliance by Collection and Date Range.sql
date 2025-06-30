DECLARE @UserSIDs          AS NVARCHAR(10) = 'Disabled';
DECLARE @LCID              AS NVARCHAR(5)  = '1033';
DECLARE @CollectionID      AS NVARCHAR(10) = 'SMS0001';
DECLARE @DateRange         AS NVARCHAR(22) = '2025-01-01 2025-06-30';
DECLARE @Year              AS NVARCHAR(4)  = LEFT(@DateRange, 4);   -- First 4 characters  represent the year;
DECLARE @StartDate         AS NVARCHAR(10) = LEFT(@DateRange, 10);  -- First 10 characters represent the start date;
DECLARE @EndDate           AS NVARCHAR(10) = RIGHT(@DateRange, 10); -- Last 10 characters represent the end date;

WITH DeviceCompliance_CTE
AS (
    SELECT
        Systems.ResourceID
        , Device = Systems.Name0
        , UpdateTitle = UpdateCIs.Title
        , ReleaseDate = UpdateCIs.DateCreated
        , ComplianceStatus = (
            CASE
                WHEN ComplianceStatus.Status = 0 THEN 'Unknown'
                WHEN ComplianceStatus.Status = 1 THEN 'NotRequired'
                WHEN ComplianceStatus.Status = 2 THEN 'NonCompliant'
                WHEN ComplianceStatus.Status = 3 THEN 'Compliant'
                ELSE 'Unknown'
            END
        )
        , RowRank = ROW_NUMBER() OVER (PARTITION BY Systems.ResourceID ORDER BY ComplianceStatus.Status DESC, UpdateCIs.DateCreated ASC)
    FROM fn_rbac_UpdateComplianceStatus(@UserSIDs) AS ComplianceStatus
        INNER JOIN fn_rbac_R_System(@UserSIDs) AS Systems ON Systems.ResourceID = ComplianceStatus.ResourceID
        INNER JOIN fn_rbac_UpdateInfo(@LCID, @UserSIDs) AS UpdateCIs ON UpdateCIs.CI_ID = ComplianceStatus.CI_ID
            AND UpdateCIs.CIType_ID = 8                                             -- Filter by Update Bundles
            AND UpdateCIs.Title LIKE @Year + '-__ Cumulative Update for Windows 1%' -- Filter by Cumulative Updates
    INNER JOIN fn_rbac_ClientCollectionMembers(@UserSIDs) AS CollectionMembers ON CollectionMembers.ResourceID = Systems.ResourceID
    WHERE
        UpdateCIs.DateCreated >= @StartDate                 -- Filter by Date Range
        AND UpdateCIs.DateCreated <= @EndDate               -- Filter by Date Range
        AND CollectionMembers.CollectionID = @CollectionID  -- Filter by CollectionID
)
SELECT
  Device
  , UpdateTitle
  , ReleaseDate = CONVERT(NVARCHAR(10),ReleaseDate, 126) -- Convert to ISO 8601 Date Format
  , ComplianceStatus
FROM
    DeviceCompliance_CTE
WHERE
   RowRank = 1 -- Get Overall Compliance for Each Device
ORDER BY
    Device, ReleaseDate DESC;