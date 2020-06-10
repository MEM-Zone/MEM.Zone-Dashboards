/*
.SYNOPSIS
    Summarizes the update scan states for a Collection in SCCM.
.DESCRIPTION
    Summarizes the window update scan states in SCCM by Collection and Status Name.
.NOTES
    Requires SQL 2012 R2.
    Part of a report should not be run separately.
*/

/*##=============================================*/
/*## QUERY BODY                                  */
/*##=============================================*/
/* #region QueryBody */

/* Testing variables !! Need to be commented for Production !! */
-- DECLARE @UserSIDs     AS NVARCHAR(10)  = 'Disabled';
-- DECLARE @CollectionID AS NVARCHAR(10)  = 'SMS00001';

/* Variable declaration */
DECLARE @UpdateSearchID INT  = (
    SELECT TOP 1 UpdateSource.UpdateSource_ID
    FROM fn_rbac_SoftwareUpdateSource(@UserSIDs) AS UpdateSource
    WHERE IsPublishingEnabled = 1                 -- Get only the UpdateSource_ID where publishing is enabled
)
DECLARE @TotalDevices AS INT = (
    SELECT COUNT(CollectionMembership.ResourceID)
    FROM fn_rbac_FullCollectionMembership(@UserSIDs) AS CollectionMembership
    WHERE CollectionMembership.CollectionID = @CollectionID
        AND CollectionMembership.ResourceType = 5 -- Select devices only
)

/* Summarize device update scan states */
SELECT
    ScanStateID              = ISNULL(StateNames.StateID, 0)
    , ScanState              = ISNULL(StateNames.StateName, N'Scan state unknown')
    , DevicesByScanState     = COUNT(*)
    , TotalDevices           = @TotalDevices
FROM fn_rbac_FullCollectionMembership(@UserSIDs) AS CollectionMembers
    LEFT JOIN fn_rbac_UpdateScanStatus(@UserSIDs) AS UpdateScanStatus ON UpdateScanStatus.ResourceID = CollectionMembers.ResourceID
        AND (
            @UpdateSearchID = UpdateScanStatus.UpdateSource_ID OR @UpdateSearchID IS NULL
        )
    LEFT JOIN fn_rbac_StateNames(@UserSIDs) AS StateNames ON StateNames.StateID = UpdateScanStatus.LastScanState
        AND StateNames.TopicType       = 501      -- Update source scan summarization TopicTypeID
WHERE CollectionMembers.CollectionID   = @CollectionID
    AND CollectionMembers.ResourceType = 5        -- Select devices only
GROUP BY
    StateNames.StateID
    , StateNames.StateName

/* #endregion */
/*##=============================================*/
/*## END QUERY BODY                              */
/*##=============================================*/