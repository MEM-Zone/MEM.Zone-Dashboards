/*
.SYNOPSIS
    Lists the installed software.
.DESCRIPTION
    Lists the installed software by user selection (Device, Publisher or Name).
    Supports filtering and exclusions by multiple software names using comma separated values and sql wildcards.
.NOTES
    Created by Ioan Popovici.
    Requires SQL 2016.
    Part of a report should not be run separately.
.LINK
    https://MEMZ.one/SW-Installed-Software-by-User-Selection
.LINK
    https://MEMZ.one/SW-Installed-Software-by-User-Selection-CHANGELOG
.LINK
    https://MEMZ.one/SW-Installed-Software-by-User-Selection-GIT
.LINK
    https://MEM.Zone/ISSUES
*/

/*##=============================================*/
/*## QUERY BODY                                  */
/*##=============================================*/
/* #region QueryBody */

/* Testing variables !! Need to be commented for Production !! */
DECLARE @UserSIDs            AS NVARCHAR(10)  = 'SMS0001';
DECLARE @CollectionID        AS NVARCHAR(250) = 'SMS0001';
DECLARE @SoftwareNameLike    AS NVARCHAR(250) = 'SMS0001';

USE CM_JNJ;

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


SELECT DISTINCT
    Device              = (
        IIF(
            SystemNames.Resource_Names0 IS NULL
            , IIF(Systems.Full_Domain_Name0 IS NULL, Systems.Name0, Systems.Name0 + N'.' + Systems.Full_Domain_Name0)
            , UPPER(SystemNames.Resource_Names0)
        )
    )
    , Publisher         = (
        CASE
            WHEN Software.Publisher0 IS NULL THEN '<No Publisher>'
            WHEN Software.Publisher0 = '' THEN '<No Publisher>'
            WHEN Software.Publisher0 = '<no manufacturer>' THEN '<No Publisher>'
            ELSE Software.Publisher0
        END
    )
    , SoftwareName      = COALESCE(NULLIF(Software.DisplayName0, ''), 'Unknown')
    , Version           = COALESCE(NULLIF(Software.Version0, ''), 'Unknown')
    , UserName          = Systems.User_Name0
    , ADSite            = Systems.AD_Site_Name0
    , OperatingSystem   = (
        IIF(
            OperatingSystem.Caption0 = N''
            , Systems.Operating_System_Name_And0
            , CONCAT(
                REPLACE(OperatingSystem.Caption0, N'Microsoft ', N''),         --Remove 'Microsoft ' from OperatingSystem
                REPLACE(OperatingSystem.CSDVersion0, N'Service Pack ', N' SP') --Replace 'Service Pack ' with ' SP' in OperatingSystem
            )
        )
    )
    , MacAddress        = MacAddresses.MAC_Addresses0
FROM fn_rbac_Add_Remove_Programs(@UserSIDs) AS Software
    JOIN fn_rbac_R_System(@UserSIDs) AS Systems ON Systems.ResourceID = Software.ResourceID
    JOIN fn_rbac_FullCollectionMembership(@UserSIDs) AS CollectionMembers ON CollectionMembers.ResourceID = Systems.ResourceID
    LEFT JOIN fn_rbac_GS_OPERATING_SYSTEM(@UserSIDs) AS OperatingSystem ON OperatingSystem.ResourceID = Systems.ResourceID
    LEFT JOIN fn_rbac_RA_System_MACAddresses(@UserSIDs) AS MacAddresses ON MacAddresses.ResourceID = Systems.ResourceID
    LEFT JOIN fn_rbac_RA_System_ResourceNames(@UserSIDs) AS SystemNames ON SystemNames.ResourceID = Systems.ResourceID
WHERE CollectionMembers.CollectionID = @CollectionID
    AND EXISTS (
        SELECT SoftwareName
        FROM @SoftwareLike AS SoftwareLike
        WHERE Software.DisplayName0 LIKE SoftwareLike.SoftwareName
    )