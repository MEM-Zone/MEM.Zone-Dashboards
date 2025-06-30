/*
.SYNOPSIS
    Gets the next maintenance window for a collection in ConfigMgr.
.DESCRIPTION
    Gets the next maintenance window for each device in a specified collection in ConfigMgr.
.PARAMETER UserSIDs
    Specifies the UserSIDs for RBAC.
.PARAMETER CollectionID
    Specifies the CollectionName of the collection it will query against.
.EXAMPLE
    SELECT dbo.ufn_CM_GetNextMaintenanceWindowForCollection(N'DEV08EEB')
.NOTES
    Requires SQL 2016.
    Requires ufn_CM_GetNextMaintenanceWindowForDevice sql helper function in order to display the next maintenance window.
    Requires SELECT access on dbo.vSMS_ServiceWindow and on itself for smsschm_users (SCCM Reporting).
    Replace the <SITE_CODE> with your CM Site Code and uncomment SSMS region if running directly from SSMS.
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
--USE [CM_<SITE_CODE>]

--/* Drop function if it exists */
--IF OBJECT_ID('[dbo].[ufn_CM_GetNextMaintenanceWindowForCollection]') IS NOT NULL
--    BEGIN
--        DROP FUNCTION [dbo].[ufn_CM_GetNextMaintenanceWindowForCollection]
--    END
--GO
/* #endregion */

/* #region create ufn_CM_GetNextMaintenanceWindowForCollection */
CREATE FUNCTION [dbo].[ufn_CM_GetNextMaintenanceWindowForCollection] (
    @UserSIDs AS NVARCHAR(10)
    , @CollectionID AS NVARCHAR(10)
)
RETURNS @MaintenanceInfo TABLE (
    ResourceID               INT
    , NextServiceWindow      DATETIME
    , ServiceWindowStart     DATETIME
    , ServiceWindowDuration  INT
    , IsServiceWindowOpen    BIT
    , IsServiceWindowEnabled BIT
    , IsUTCTime              BIT
)

AS
    BEGIN

        /* Check for helper function */
        DECLARE @HelperFunctionExists AS INT = 0;
        IF OBJECT_ID(N'[dbo].[ufn_CM_GetNextMaintenanceWindowForDevice]') IS NOT NULL
            SET @HelperFunctionExists = 1;

        /* Get maintenance data */
        IF @HelperFunctionExists = 1
            BEGIN
                INSERT INTO @MaintenanceInfo(ResourceID, NextServiceWindow, ServiceWindowStart, ServiceWindowDuration, IsServiceWindowEnabled, IsServiceWindowOpen, IsUTCTime)
                    SELECT
                        ResourceID               = CollectionMembers.ResourceID
                        , NextServiceWindow      = NextServiceWindow.NextServiceWindow
                        , ServiceWindowStart     = NextServiceWindow.ServiceWindowStart
                        , ServiceWindowDuration  = NextServiceWindow.ServiceWindowDuration
                        , IsServiceWindowEnabled = NextServiceWindow.IsServiceWindowEnabled
                        , IsServiceWindowOpen    = NextServiceWindow.IsServiceWindowOpen
                        , IsUTCTime              = NextServiceWindow.IsUTCTime
                    FROM [CM_JNJ].[dbo].[fn_rbac_FullCollectionMembership](@UserSIDs) AS CollectionMembers
                        OUTER APPLY [dbo].[ufn_CM_GetNextMaintenanceWindowForDevice](@UserSIDs,CollectionMembers.ResourceID) AS NextServiceWindow
                    WHERE CollectionMembers.CollectionID = @CollectionID -- Filters on CollectionID
                        AND CollectionMembers.ResourceType = 5           -- Select devices only
            END

        /* Return result */
        RETURN
    END
    /* #endregion */

/* #endregion */
/*##=============================================*/
/*## END QUERY BODY                              */
/*##=============================================*/