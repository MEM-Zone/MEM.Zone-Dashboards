/*
.SYNOPSIS
    Gets the IP address for a device in Configuration Manager.
.DESCRIPTION
    Gets the IP addresses for a specified device ResourceID in Configuration Manager.
.PARAMETER UserSIDs
    Specifies the UserSIDs for RBAC.
.PARAMETER ResourceID
    Specifies the ResourceID of the device it will query against.
.EXAMPLE
    SELECT dbo.ufn_CM_IPAddress(@UserSIDs,16777216)
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
--IF OBJECT_ID('[dbo].[ufn_CM_DeviceIPAddress]') IS NOT NULL
--    BEGIN
--        DROP FUNCTION [dbo].[ufn_CM_DeviceIPAddress]
--    END
--GO
/* #endregion */

/* #region create ufn_CM_GetNextMaintenanceWindowForDevice */
CREATE FUNCTION [dbo].[ufn_CM_DeviceIPAddress] (
    @UserSIDs AS NVARCHAR(10)
    , @ResourceID AS INT
)
RETURNS @IPAddress TABLE (
    ResourceID  INT
    , IPAddress NVARCHAR(500)
)
    BEGIN
        DECLARE @IPAddressValue AS NVARCHAR(500)
        SET @IPAddressValue = (
            SELECT REPLACE (
                (
                    SELECT LTRIM(RTRIM(IP.IP_Addresses0)) AS [data()]
                    FROM [CM_JNJ].[dbo].[fn_rbac_RA_System_IPAddresses](@UserSIDs) AS IP
                    WHERE IP.ResourceID = @ResourceID
                    -- Exclude IPv6 and 169.254.0.0 Class
                        AND IIF(CHARINDEX(N':', IP.IP_Addresses0) > 0 OR CHARINDEX(N'169.254', IP.IP_Addresses0) = 1, 1, 0) = 0
                    -- Aggregate results to one row
                    FOR XML PATH('')
                )
                , N' ', N','
            )
        )
        INSERT INTO @IPAddress Values (@ResourceID, @IPAddressValue)

        /* Return result */
        RETURN
    END
    /* #endregion */

/* #endregion */
/*##=============================================*/
/*## END QUERY BODY                              */
/*##=============================================*/