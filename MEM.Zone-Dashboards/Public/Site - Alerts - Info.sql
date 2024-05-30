/*
.SYNOPSIS
    Gets ConfigMgr Alerts.
.DESCRIPTION
    Gets ConfigMgr Alerts by Feature Area and Alert State.
.NOTES
    Requires SQL 2016.
    Requires SELECT access on dbo.fnListAlerts() function for smsschm_users (ConfigMgr Reporting).
    RBAC Disabled in order to get all alerts.
    Part of a report should not be run separately.
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
DECLARE @UserSIDs         AS NVARCHAR(10) = 'Disabled';
--DECLARE @AlertFeatureArea AS NVARCHAR(25) = '4'; -- Software Update Area
--DECLARE @AlertState       AS INT          = 0;   -- 0 = Active, 1 = Postponed, 2 = Canceled, 3 = Unknown, 4 = Disabled, 5 = Never Triggered
--DECLARE @Locale           AS INT          = 2;

/* Variable declaration */
DECLARE @LCID                  AS INT = dbo.fn_LShortNameToLCID(@Locale);

SELECT
    Alert.ID
    , Alert.TypeID
    , Alert.TypeInstanceID
    , Name                       = (
        CASE
            WHEN Alert.Name = N'$SUMCompliance2UpdateGroupDeploymentName' THEN IIF(Alert.InstanceNameParam1 IS NULL, N'Update Group Deleted', Alert.InstanceNameParam1)
            WHEN Alert.Name = N'$AntimalwareClientVersionAlertName'       THEN N'Antimalware clients out of date'
            ELSE Alert.Name
        END
    )
    , Alert.FeatureArea
    , Alert.FeatureGroup
    , Alert.Severity
    , AlertState                 = (
        CASE Alert.AlertState
            WHEN 0 THEN N'Active'
            WHEN 1 THEN N'Postponed'
            WHEN 2 THEN N'Canceled'
            WHEN 3 THEN N'Unknown'
            WHEN 4 THEN N'Disabled'
            WHEN 5 THEN N'Never Triggered'
            ELSE N'Not Defined'
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

-- TODO: Check if we can use this
-- SELECT * FROM fnListGeneralAlerts(1033,'0x01050000000000051500000019A3885163E6C6B9E6C9C9E356040000') AS SMS_ALERT  where ((SMS_ALERT.AlertState = 0 AND SMS_ALERT.FeatureArea = 4) AND SMS_ALERT.IsIgnored = 0)

/* #endregion */
/*##=============================================*/
/*## END QUERY BODY                              */
/*##=============================================*/