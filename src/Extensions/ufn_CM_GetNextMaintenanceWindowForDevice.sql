/*
.SYNOPSIS
    Gets the next maintenance window for a device in ConfigMgr.
.DESCRIPTION
    Gets the next maintenance window for a specified device ResourceID in ConfigMgr.
.PARAMETER ResourceID
    Specifies the ResourceID of the device it will query against.
.EXAMPLE
    SELECT dbo.ufn_CM_GetNextMaintenanceWindowForDevice(16777216)
.NOTES
    Requires SQL 2016.
    Requires ufn_CM_GetNextMaintenanceWindow sql helper function in order to display the next maintenance window.
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
--USE [CM_<SITE_CODE>]s

/* Drop function if it exists */
--IF OBJECT_ID('[dbo].[ufn_CM_GetNextMaintenanceWindowForDevice]') IS NOT NULL
--    BEGIN
--        DROP FUNCTION [dbo].[ufn_CM_GetNextMaintenanceWindowForDevice]
--    END
--GO
/* #endregion */

/* #region create ufn_CM_GetNextMaintenanceWindowForDevice */
CREATE FUNCTION [dbo].[ufn_CM_GetNextMaintenanceWindowForDevice] (
    @UserSIDs AS NVARCHAR(10)
    , @ResourceID AS INT
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
        IF OBJECT_ID(N'[dbo].[ufn_CM_GetNextMaintenanceWindow]') IS NOT NULL
            SET @HelperFunctionExists = 1;

        /* Get maintenance data */
        IF @HelperFunctionExists = 1
            BEGIN
                WITH Maintenance_CTE AS (
                    SELECT
                        ResourceID               = Systems.ResourceID
                        , NextServiceWindow      = NextServiceWindow.NextServiceWindow
                        , ServiceWindowStart     = NextServiceWindow.StartTime
                        , ServiceWindowDuration  = NextServiceWindow.Duration
                        , IsServiceWindowEnabled = ServiceWindow.Enabled
                        , IsServiceWindowOpen    = NextServiceWindow.IsServiceWindowOpen
                        , IsUTCTime              = NextServiceWindow.IsUTCTime
                        , RowNumber              = DENSE_RANK() OVER (PARTITION BY Systems.ResourceID ORDER BY IIF(
                            NextServiceWindow.NextServiceWindow IS NULL, 1, 0), NextServiceWindow.NextServiceWindow, ServiceWindow.ServiceWindowID
                        )                                                        -- Order by NextServiceWindow with NULL Values last
                    FROM [dbo].[fn_rbac_R_System](@UserSIDs) AS Systems -- This join links Devices to ServiceWindow Collections
                        JOIN [dbo].[fn_rbac_FullCollectionMembership](@UserSIDs) AS SWCollectionMembers ON SWCollectionMembers.ResourceID = Systems.ResourceID
                        JOIN [dbo].[vSMS_ServiceWindow] AS ServiceWindow ON ServiceWindow.SiteID = SWCollectionMembers.CollectionID
                        CROSS APPLY [dbo].[ufn_CM_GetNextMaintenanceWindow](ServiceWindow.Schedules, ServiceWindow.RecurrenceType) AS NextServiceWindow
                    WHERE ServiceWindowType != 5                                  -- OSD Maintenance Windows
                        AND Systems.ResourceID   = @ResourceID                    -- Filters on ResourceID
                        AND Systems.ResourceType = 5                              -- Select devices only
                )

                /* Populate MaintenanceInfo table and remove duplicates */
                INSERT INTO @MaintenanceInfo(ResourceID, NextServiceWindow, ServiceWindowStart, ServiceWindowDuration, IsServiceWindowEnabled, IsServiceWindowOpen, IsUTCTime)
                    SELECT
                        ResourceID
                        , NextServiceWindow
                        , ServiceWindowStart
                        , ServiceWindowDuration
                        , IsServiceWindowEnabled
                        , IsServiceWindowOpen
                        , IsUTCTime
                    FROM Maintenance_CTE
                    WHERE RowNumber = 1 -- Remove duplicates
            END

        /* Return result */
        RETURN
    END
/* #endregion */

/* #endregion */
/*##=============================================*/
/*## END QUERY BODY                              */
/*##=============================================*/