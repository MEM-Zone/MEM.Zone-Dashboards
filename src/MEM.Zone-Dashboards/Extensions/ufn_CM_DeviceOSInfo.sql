/*
.SYNOPSIS
    Gets the operating system information for a device in Configuration Manager.
.DESCRIPTION
    Gets the operating system version and servicing status for a specified device ResourceID in Configuration Manager.
.PARAMETER ResourceID
    Specifies the ResourceID of the device it will query against.
.PARAMETER OSBuild
    Specifies the operating system build.
.PARAMETER OSBranch
    Specifies the operating system branch.
.EXAMPLE
    SELECT dbo.ufn_CM_DeviceOSInfo(@UserSIDs, 16777216, N'10.0.10240', 1)
.NOTES
    Requires SQL 2016.
    Requires SELECT access for smsschm_users (SCCM Reporting).
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
--IF OBJECT_ID('[dbo].[ufn_CM_DeviceOSInfo]') IS NOT NULL
--    BEGIN
--        DROP FUNCTION [dbo].[ufn_CM_DeviceOSInfo]
--    END
--GO
/* #endregion */

/* #region create ufn_CM_GetNextMaintenanceWindowForDevice */
CREATE FUNCTION [dbo].[ufn_CM_DeviceOSInfo] (
    @ResourceID AS INT
    , @OSBuild    AS NVARCHAR(10)
    , @OSBranch   AS INT
)
RETURNS @OSInfo TABLE (
    ResourceID             INT
    , Version              NVARCHAR(15)
    , ServicingStateNumber INT
    , ServicingStateName   NVARCHAR(20)

)
    BEGIN

        /* Variable declaration */
        DECLARE @Win10_2021_LTSC_EOS AS DATETIME = '2027-01-12'

        /* Declare tempory tables */
        DECLARE @OSServicing      AS TABLE (StateNumber INT, StateName NVARCHAR(20));
        DECLARE @OSServicingState AS TABLE (Build NVARCHAR(10), Branch INT, Version NVARCHAR(20), StateNumber INT, StateName NVARCHAR(20));

        /* Populate OSServicing table */
        INSERT INTO @OSServicing (StateNumber, StateName)
        VALUES
            (0, N'Internal')
            , (1, N'Insider')
            , (2, N'Current')
            , (3, N'Expiring Soon')
            , (4, N'Expired')
            , (5, N'Unknown')

        /* Populate OSServicingState table */
        INSERT INTO @OSServicingState (Build, Branch, Version, StateNumber, StateName)
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
                , IIF(
                    DATEDIFF(dd, CURRENT_TIMESTAMP, @Win10_2021_LTSC_EOS) > 180
                    , N'Current'
                    , IIF(
                        DATEDIFF(dd, CURRENT_TIMESTAMP, @Win10_2021_LTSC_EOS) >= 0
                        , N'Expiring Soon', N'Expired'
                    )
                )
            )
            , (N'6.1.7601', 1, NULL, 4, N'Expired')

        INSERT INTO @OSInfo (ResourceID, Version, ServicingStateNumber, ServicingStateName)
            SELECT
                ResourceID = @ResourceID
                , Version = OSLocalizedNames.Value
                , ServicingStateNumber = OSServicingStates.State
                , ServicingStateName = ISNULL(
                    (
                        SELECT StateName FROM @OSServicing AS OSServicing
                        WHERE OSServicing.StateNumber = OSServicingStates.State
                    ), N'Unknown'
                )
            FROM [dbo].[fn_GetWindowsServicingStates]() AS OSServicingStates
                JOIN [dbo].[fn_GetWindowsServicingLocalizedNames]() AS OSLocalizedNames ON OSLocalizedNames.Name = OSServicingStates.Name
            WHERE OSServicingStates.Build = @OSBuild
                AND OSServicingStates.Branch = @OSBranch
            UNION
            SELECT
                ResourceID = @ResourceID
                , Version
                , OSServicingState.StateNumber
                , OSServicingState.StateName
            FROM @OSServicingState AS OSServicingState
            WHERE  OSServicingState.Build =  @OSBuild
                AND OSServicingState.Branch = IIF(@OSBranch = N'', 1, @OSBranch)

        /* Return result */
        RETURN
    END
    /* #endregion */

/* #endregion */
/*##=============================================*/
/*## END QUERY BODY                              */
/*##=============================================*/