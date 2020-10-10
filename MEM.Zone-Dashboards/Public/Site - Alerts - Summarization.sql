/*
.SYNOPSIS
    Summarizes MEMCM Alerts.
.DESCRIPTION
    Summarizes MEMCM Alerts by Feature Area and Alert State.
.NOTES
    Requires SQL 2016.
    Requires SELECT access on dbo.fnListAlerts() function for smsschm_users (MEMCM Reporting).
    RBAC Disabled in order to get all alerts.
    Part of a report should not be run separately.
.LINK
    https://MEM.Zone/Dashboards
.LINK
    https://MEM.Zone/Dashboards-HELP
.LINK
    https://MEM.Zone/Dashboards-ISSUES
*/

/*##=============================================*/
/*## QUERY BODY                                  */
/*##=============================================*/
/* #region QueryBody */

/* Testing variables !! Need to be commented for Production !! */
DECLARE @UserSIDs         AS NVARCHAR(10) = 'Disabled';
--DECLARE @AlertFeatureArea AS NVARCHAR(25) = 'ALERT_FEATUREAREA_4'; -- Software Update Area
--DECLARE @AlertState       AS INT          = 0;                     -- 0 = Active, 1 = Postponed, 2 = Canceled, 3 = Unknown, 4 = Disabled, 5 = Never Triggered

/* Variable declaration */
DECLARE @LCID             AS INT = dbo.fn_LShortNameToLCID(@Locale);

SELECT
    NoActionNeeded      = SUM(IIF(Alert.AlertState NOT IN (0, 3) OR Alert.Severity = 3, 1, 0))
    , Active            = SUM(IIF(Alert.AlertState      = 0, 1, 0))
    , NeverTriggered    = SUM(IIF(Alert.AlertState      = 5, 1, 0))
    , Unknown           = SUM(IIF(Alert.AlertState      = 3, 1, 0))
    , Critical          = SUM(IIF(Alert.Severity        = 1, 1, 0))
    , Warning           = SUM(IIF(Alert.Severity        = 2, 1, 0))
    , Informational     = SUM(IIF(Alert.Severity        = 3, 1, 0))
    , Reoccurring       = SUM(IIF(Alert.OccurrenceCount > 0, 1, 0))
    , ActiveLessThan24h = SUM(
        IIF(
            Alert.AlertState = 0 AND Alert.AlertStateChangeTime > DATEADD(dd, -1, CURRENT_TIMESTAMP)
        , 1, 0
        )
    )
    , TotalAlerts       = COUNT(*)
FROM fnListAlerts(@LCID, @UserSIDs) AS Alert
WHERE Alert.FeatureArea IN (@AlertFeatureArea)
   AND Alert.AlertState IN (@AlertState)

/* #endregion */
/*##=============================================*/
/*## END QUERY BODY                              */
/*##=============================================*/