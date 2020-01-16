/*
.SYNOPSIS
    Gets SCCM Alerts.
.DESCRIPTION
    Gets SCCM Alerts by Feature Area and Alert State.
.NOTES
    Requires SELECT access on dbo.fnListAlerts() function for smsschm_users (SCCM Reporting).
    RBAC Disabled in order to get all alerts.
    Part of a report should not be run separately.
.LINK
    https://SCCM.Zone/
.LINK
    https://SCCM.Zone/CM-SRS-Dashboards-GIT
.LINK
    https://SCCM.Zone/CM-SRS-Dashboards-ISSUES
*/

/*##=============================================*/
/*## QUERY BODY                                  */
/*##=============================================*/
/* #region QueryBody */

/* Testing variables !! Need to be commented for Production !! */
DECLARE @UserSIDs         AS NVARCHAR(10) = 'Disabled';
-- DECLARE @AlertFeatureArea AS NVARCHAR(25) = 'ALERT_FEATUREAREA_4'; -- Software Update Area
-- DECLARE @AlertState       AS INT          = 0;                     -- 0 = Active, 1 = Postponed, 2 = Canceled, 3 = Unknown, 4 = Disabled, 5 = Never Triggered
-- DECLARE @Locale           AS INT          = 2;

/* Variable declaration */
DECLARE @LCID                  AS INT = dbo.fn_LShortNameToLCID(@Locale);

SELECT
    Alert.TypeID
    , Alert.TypeInstanceID
    , Name                       = (
        CASE
            WHEN Alert.Name = '$SUMCompliance2UpdateGroupDeploymentName' THEN Alert.InstanceNameParam1
            WHEN Alert.Name = '$AntimalwareClientVersionAlertName'       THEN 'Antimalware clients out of date'
            ELSE Alert.Name
        END
    )
    , Alert.FeatureArea
    , Alert.FeatureGroup
    , Alert.Severity
    , AlertState                 = (
        CASE Alert.AlertState
            WHEN 0 THEN 'Active'
            WHEN 1 THEN 'Postponed'
            WHEN 2 THEN 'Canceled'
            WHEN 3 THEN 'Unknown'
            WHEN 4 THEN 'Disabled'
            WHEN 5 THEN 'Never Triggered'
            ELSE 'Not Defined'
        END
    )
    , CreationTime               = CONVERT(NVARCHAR(16), Alert.CreationTime, 120)
    , PostponedTime              = CONVERT(NVARCHAR(16), Alert.SkipUntil, 120)
    , FirstRaisedTime            = CONVERT(NVARCHAR(16), FirstRaisedTime, 120)
    , LastChangeTime             = CONVERT(NVARCHAR(16), Alert.LastChangeTime, 120)
    , AlertStateChangeTime       = CONVERT(NVARCHAR(16), Alert.AlertStateChangeTime, 120)
    , Alert.CreatedBy
    , Alert.ModifiedBy
    , Alert.ClosedBy
    , Alert.OccurrenceCount
FROM fnListAlerts(@LCID, @UserSIDs) AS Alert
WHERE Alert.FeatureArea IN (@AlertFeatureArea)
   AND Alert.AlertState IN (@AlertState)

/* #endregion */
/*##=============================================*/
/*## END QUERY BODY                              */
/*##=============================================*/