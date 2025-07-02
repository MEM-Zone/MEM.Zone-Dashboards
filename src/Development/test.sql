DECLARE @UserSIDs VARCHAR(16)= 'Disabled';
DECLARE @CollectionID VARCHAR(16)= 'SMS0001';

/* Get Assignment Info for Collection */
WITH #CTE_AssignmentInfo AS (
    SELECT
        AssignmentID     = ApplicationAssignment.AssignmentID
        , AssignmentName = ApplicationAssignment.AssignmentName
        , DisplayName    = ApplicationAssignment.ApplicationName
        , CollectionName = ApplicationAssignment.CollectionName
        , Action         = (
            CASE
                WHEN ApplicationAssignment.OfferTypeID = 0 THEN N'Required'
                WHEN ApplicationAssignment.OfferTypeID = 2 THEN N'Available'
                ELSE N'Unknown'
            END
        )
        , Purpose        = (
            CASE
                WHEN ApplicationAssignment.DesiredConfigType = 1 THEN N'Install'
                WHEN ApplicationAssignment.DesiredConfigType = 2 THEN N'Uninstall'
                ELSE N'Unknown'
            END
        )
        , StartTime     = CONVERT(NVARCHAR(16), ApplicationAssignment.StartTime, 120)
        , Deadline      = CONVERT(NVARCHAR(16), ApplicationAssignment.EnforcementDeadline, 120)
    FROM fn_rbac_ApplicationAssignment(@UserSIDs) AS ApplicationAssignment
    WHERE ApplicationAssignment.CollectionID = @CollectionID
)
SELECT
    AssignmentID     = AssignmentInfo.AssignmentID
    , AssignmentName = AssignmentInfo.AssignmentName
    , DisplayName    = AssignmentInfo.DisplayName + N' - ' + AssignmentInfo.Purpose + N' (' + AssignmentInfo.Action + N')'
    , CollectionName = AssignmentInfo.CollectionName
    , Action         = AssignmentInfo.Action
    , Purpose        = AssignmentInfo.Purpose
    , StartTime      = AssignmentInfo.StartTime
    , Deadline       = AssignmentInfo.Deadline
FROM #CTE_AssignmentInfo AS AssignmentInfo
ORDER BY AssignmentInfo.DisplayName