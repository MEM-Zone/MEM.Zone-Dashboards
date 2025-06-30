/*
.SYNOPSIS
    Lists the installed software.
.DESCRIPTION
    Lists the installed software by user selection (Device, Publisher or Name).
    Supports filtering and exclusions by multiple software names using comma separated values and sql wildcards.
.NOTES
    Created by Ioan Popovici.
    Requires SQL 2016
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
--DECLARE @UserSIDs            AS NVARCHAR(10)  = 'SMS0001';
--DECLARE @CollectionID        AS NVARCHAR(250) = 'SMS0001';
--DECLARE @SoftwareNameLike    AS NVARCHAR(250) = 'SMS0001';
--DECLARE @SoftwareNameNotLike AS NVARCHAR(250) = 'SMS0001';
--DECLARE @SoftwareVersionLike AS NVARCHAR(20)  = 'SMS0001';

USE CM_JNJ; -- Stupidity Wokaround

/* Perform cleanup */
IF OBJECT_ID(N'tempdb..#InstalledSoftware', N'U') IS NOT NULL
    DROP TABLE #InstalledSoftware;

/* Initialize SoftwareLike table */
DECLARE @SoftwareLike TABLE (
    SoftwareName NVARCHAR(250)
)

/* Initialize SoftwareNotLike table */
DECLARE @SoftwareNotLike TABLE (
    SoftwareName NVARCHAR(250)
)

/* Populate SoftwareLike table */
INSERT INTO @SoftwareLike (SoftwareName)
SELECT SubString FROM fn_SplitString(@SoftwareNameLike, N',');

/* Populate SoftwareNotLike table */
INSERT INTO @SoftwareNotLike (SoftwareName)
SELECT SubString FROM fn_SplitString(@SoftwareNameNotLike, N',');

/* Populate InstalledSoftware table */
SELECT DISTINCT
    Device              = Systems.Netbios_Name0
    , Manufacturer      = Enclosure.Manufacturer0
    , DeviceType        = (
        CASE
            WHEN Enclosure.ChassisTypes0 IN (8 , 9, 10, 11, 12, 14, 18, 21, 31, 32) THEN N'Laptop'
            WHEN Enclosure.ChassisTypes0 IN (3, 4, 5, 6, 7, 15, 16)                 THEN N'Desktop'
            WHEN Enclosure.ChassisTypes0 IN (17, 23, 28, 29)                        THEN N'Servers'
            WHEN Enclosure.ChassisTypes0 = N'30'                                    THEN N'Tablet'
            ELSE 'Unknown'
        END
    )
    , SerialNumber      = Enclosure.SerialNumber0
    , Publisher         = (
        CASE
            WHEN Software.Publisher0 IS NULL                THEN N'<No Publisher>'
            WHEN Software.Publisher0 = N''                  THEN N'<No Publisher>'
            WHEN Software.Publisher0 = N'<no manufacturer>' THEN N'<No Publisher>'
            ELSE Software.Publisher0
        END
    )
    , SoftwareName      = COALESCE(NULLIF(Software.DisplayName0, N''), N'Unknown')
    , Version           = COALESCE(NULLIF(Software.Version0, N''), N'Unknown')
    , DomainOrWorkgroup = Systems.Resource_Domain_OR_Workgr0
    , UserName          = Systems.User_Name0
	, UserEmail         = Users.Mail0
    , OperatingSystem   = OS.Caption0
INTO #InstalledSoftware
FROM fn_rbac_Add_Remove_Programs(@UserSIDs) AS Software
    JOIN fn_rbac_R_System(@UserSIDs) AS Systems ON Systems.ResourceID = Software.ResourceID
    JOIN fn_rbac_ClientCollectionMembers(@UserSIDs) AS CollectionMembers ON CollectionMembers.ResourceID = Systems.ResourceID
    JOIN fn_rbac_GS_OPERATING_SYSTEM(@UserSIDs) AS OS ON OS.ResourceID = Systems.ResourceID
    LEFT JOIN fn_rbac_GS_SYSTEM_ENCLOSURE(@UserSIDs) AS Enclosure ON Enclosure.ResourceID = Systems.ResourceID
	LEFT JOIN fn_rbac_R_User(@UserSIDs) AS Users ON Users.User_Name0 = Systems.User_Name0
WHERE CollectionMembers.CollectionID = @CollectionID
    AND EXISTS (
        SELECT SoftwareName
        FROM @SoftwareLike AS SoftwareLike
        WHERE Software.DisplayName0 LIKE SoftwareLike.SoftwareName
			AND Software.Version0 LIKE @SoftwareVersionLike
    );

/* Use NOT LIKE if needed */
IF EXISTS (SELECT SoftwareName FROM @SoftwareNotLike)
BEGIN
    SELECT
        Device
        , Manufacturer
        , DeviceType
        , SerialNumber
        , Publisher
        , SoftwareName
        , Version
        , DomainOrWorkgroup
        , UserName
		, UserEmail
        , OperatingSystem
    FROM #InstalledSoftware AS InstalledSoftware
        WHERE NOT EXISTS (
            SELECT SoftwareName
            FROM @SoftwareNotLike AS SoftwareNotLike
            WHERE InstalledSoftware.SoftwareName LIKE SoftwareNotLike.SoftwareName
        )
END;

/* Otherwise perform a normal select */
ELSE
BEGIN
    SELECT
        Device
        , Manufacturer
        , DeviceType
        , SerialNumber
        , Publisher
        , SoftwareName
        , Version
        , DomainOrWorkgroup
        , UserName
		, UserEmail
        , OperatingSystem
    FROM #InstalledSoftware
END;

/* Perform cleanup */
IF OBJECT_ID(N'tempdb..#InstalledSoftware', N'U') IS NOT NULL
    DROP TABLE #InstalledSoftware;

/* #endregion */
/*##=============================================*/
/*## END QUERY BODY                              */
/*##=============================================*/