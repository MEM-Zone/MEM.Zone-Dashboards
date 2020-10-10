/*
.SYNOPSIS
    Gets MEMCM SUP Sync Status.
.DESCRIPTION
    Gets MEMCM SUP Sync Status with state message details.
.NOTES
    Requires SQL 2016.
    Requires SELECT access on dbo.vSMS_SUPSyncStatus for smsschm_users (MEMCM Reporting).
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
--DECLARE @UserSIDs     AS NVARCHAR(10)  = 'Disabled';
--DECLARE @CollectionID AS NVARCHAR(10)  = 'SMS00001';

SELECT
    SUPSyncStatus.SiteCode
    , SUPSyncStatus.WSUSServerName
    , SUPSyncStatus.WSUSSourceServer
    , SUPSyncStatus.SyncCatalogVersion
    , LastSuccessfulSyncTime               = CONVERT(NVARCHAR(16), SUPSyncStatus.LastSuccessfulSyncTime, 120)
    , SUPSyncStatus.LastSyncState
    , LastSyncStateTime                    = CONVERT(NVARCHAR(16), SUPSyncStatus.LastSyncStateTime, 120)
    , StatusMessageDetails.Time
    , SUPSyncStatus.LastSyncErrorCode
    , SUPSyncStatus.ReplicationLinkStatus
    , LastReplicationLinkCheckTime         = CONVERT(NVARCHAR(16), SUPSyncStatus.LastReplicationLinkCheckTime, 120)
    , StatusMessageDetails.Severity
    , StatusMessageDetails.MsgDLLName
    , StatusMessageDetails.InsString1
    , StatusMessageDetails.InsString2
    , StatusMessageDetails.InsString3
    , StatusMessageDetails.InsString4
    , StatusMessageDetails.InsString5
    , StatusMessageDetails.InsString6
    , StatusMessageDetails.InsString7
    , StatusMessageDetails.InsString8
    , StatusMessageDetails.InsString9
    , StatusMessageDetails.InsString10
FROM vSMS_SUPSyncStatus AS SUPSyncStatus
    CROSS APPLY (
        SELECT
            StatusMessage.Severity
            , ModuleNames.MsgDLLName
            , StatusMessage.Time
            , StatusMessage.SiteCode
            , StatusMessageStrings.InsString1
            , StatusMessageStrings.InsString2
            , StatusMessageStrings.InsString3
            , StatusMessageStrings.InsString4
            , StatusMessageStrings.InsString5
            , StatusMessageStrings.InsString6
            , StatusMessageStrings.InsString7
            , StatusMessageStrings.InsString8
            , StatusMessageStrings.InsString9
            , StatusMessageStrings.InsString10
        FROM fn_rbac_StatusMessage(@UserSIDs) AS StatusMessage
            JOIN fn_rbac_StatMsgWithInsStrings(@UserSIDs) AS StatusMessageStrings ON StatusMessageStrings.RecordID = StatusMessage.RecordID
            JOIN fn_rbac_StatMsgModuleNames(@UserSIDs) AS ModuleNames ON ModuleNames.ModuleName = StatusMessage.ModuleName
        WHERE StatusMessage.MessageID = SUPSyncStatus.LastSyncState
            -- Workaround for the time difference between StatusMessage.Time and SUPSyncStatus.LastSyncStateTime (Should be equal in a perfect world)
            AND StatusMessage.Time >= DATEADD(MINUTE, -2, SUPSyncStatus.LastSyncStateTime)
            AND StatusMessage.SiteCode = SUPSyncStatus.SiteCode
    ) AS StatusMessageDetails

/* #endregion */
/*##=============================================*/
/*## END QUERY BODY                              */
/*##=============================================*/