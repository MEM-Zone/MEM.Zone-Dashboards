/*
.SYNOPSIS
    Gets the missing software updates for a device in ConfigMgr.
.DESCRIPTION
    Gets the missing software updates for a device in ConfigMgr by Software update grpup.
.PARAMETER UserSIDs
    Specifies the UserSIDs for RBAC.
.PARAMETER Collection
    Specifies the Collection ID or Collection Name of the collection queried collection.
    Available ID Values:
        SELECT CollectionID, Name FROM v_Collection
.PARAMETER UpdateGroup
    Specifies the Group ID or Group Name for the software updates.
    Available Name Values:
        'All'
        '<UpdateGroupName>'
    Available ID Values:
        SELECT CI_ID, Title FROM v_AuthListInfo AS AuthList
    Default is 'All'.
.PARAMETER UpdateCategory
    Specifies the Category ID or Category Name for the software updates.
    Available Name Values:
        'Critical Updates'
        'Definition Updates'
        'Feature Packs'
        'Security Updates'
        'Service Packs'
        'Update Rollups'
        'Updates'
        'Upgrades'
        'All'
    Available ID Values:
        SELECT CategoryInstanceID, CategoryInstanceName FROM v_CICategoryInfo WHERE CategoryTypeName = 'UpdateClassification'
    Default is 'Security Updates'.
.PARAMETER UpdateVendor
    Specifies the Vendor ID or Vendor Name for the software updates.
    AvailableValues
        'Microsoft'
        '<VendorName>'
        ...
        'All'
    Available ID Values:
        SELECT CategoryInstanceID, CategoryInstanceName FROM v_CICategoryInfo WHERE CategoryTypeName = 'Company'
    Default is 'Microsoft'.
.PARAMETER IsTargeted
    Specifies the targeted state to filter.
    Available values:
        0 - No
        1 - Yes
    Default is '1'.
.PARAMETER IsEnabled
    Specifies the enabled state to filter.
    Available values:
        0 - No
        1 - Yes
    Default is '1'.
.PARAMETER IsSuperseded
    Specifies the superseded state to filter.
    Available values:
        0 - No
        1 - Yes
    Default is '0'.
.EXAMPLE
    SELECT * FROM dbo.ufn_CM_MissingSoftwareUpdates(@UserSIDs, N'DEV08EEB', 'All', N'Security Updates', N'Microsoft', 1, 1, 0)
.EXAMPLE
    SELECT * FROM dbo.ufn_CM_MissingSoftwareUpdates('Disabled', N'DEV08EEB', NULL, NULL, NULL, NULL, NULL, NULL)
.NOTES
    Requires SQL 2016.
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
--USE [<CM_SITE>]

/* Drop function if it exists */
--IF OBJECT_ID('[dbo].[ufn_CM_MissingSoftwareUpdates]') IS NOT NULL
--    BEGIN
--        DROP FUNCTION [dbo].[ufn_CM_MissingSoftwareUpdates]
--    END
--GO
/* #endregion */

/* #region create ufn_CM_MissingSoftwareUpdates */
CREATE FUNCTION [dbo].[ufn_CM_MissingSoftwareUpdates] (
    @UserSIDs           AS NVARCHAR(10)
    , @Collection       AS NVARCHAR(100)
    , @UpdateGroup      AS NVARCHAR(250)
    , @UpdateCategory   AS NVARCHAR(20)
    , @UpdateVendor     AS NVARCHAR(30)
    , @IsTargeted       AS BIT
    , @IsEnabled        AS BIT
    , @IsSuperseded     AS BIT
)
RETURNS @MissingSoftwareUpdates TABLE (
    ResourceID  INT
    , Missing   INT
    , Compliant INT
)
AS
    BEGIN

        /* Variable declaration */
        DECLARE @LCID                AS INT = 1033; -- English
        DECLARE @CollectionID        AS NVARCHAR(10);
        DECLARE @UseUpdateGroup      AS BIT = IIF(@UpdateGroup IS NOT NULL AND @UpdateGroup != 'All', 1, 0);

        /* Initialize variable tables */
        DECLARE @UpdateGroupCIsTable AS TABLE (CI_ID INT);
        DECLARE @UpdateCategoryTable AS TABLE (CategoryInstanceID INT);

        /* Set parameter values */
        -- CollectionID
        SET @CollectionID = (
            SELECT Collection.CollectionID
            FROM [CM_JNJ].[dbo].fn_rbac_Collection(@UserSIDs) AS Collection
            WHERE Collection.CollectionID = @Collection OR Collection.Name = @Collection
        );
        -- Update Group updates
        IF @UseUpdateGroup = 1 INSERT INTO @UpdateGroupCIsTable (CI_ID)
            SELECT
                CI_ID = CIRelation.ReferencedCI_ID
                FROM [CM_JNJ].[dbo].[fn_rbac_CIRelation_All](@UserSIDs) AS CIRelation
                JOIN [CM_JNJ].[dbo].[fn_rbac_AuthListInfo](@LCID, @UserSIDs) AS AuthList ON AuthList.CI_ID = CIRelation.CI_ID
            WHERE CIRelation.RelationType = 1
                AND AuthList.CI_ID = TRY_CAST(@UpdateGroup AS INT)
                OR AuthList.Title = @UpdateGroup
            GROUP BY CIRelation.ReferencedCI_ID
        ELSE INSERT INTO @UpdateGroupCIsTable (CI_ID)
            SELECT
                CI_ID = CIRelation.ReferencedCI_ID
                FROM [CM_JNJ].[dbo].[fn_rbac_CIRelation_All](@UserSIDs) AS CIRelation
                JOIN [CM_JNJ].[dbo].[fn_rbac_AuthListInfo](@LCID, @UserSIDs) AS AuthList ON AuthList.CI_ID = CIRelation.CI_ID
            WHERE CIRelation.RelationType = 1
            GROUP BY CIRelation.ReferencedCI_ID
        -- Update Category
        IF @UpdateCategory IS NULL SET @UpdateCategory = N'Security Updates'
        IF @UpdateCategory = 'All'
            INSERT INTO @UpdateCategoryTable (CategoryInstanceID)
            SELECT DISTINCT CategoryInstanceID
            FROM [CM_JNJ].[dbo].[fn_rbac_CICategoryInfo_All](@LCID, @UserSIDs)
            WHERE CategoryTypeName = N'UpdateClassification'
        ELSE
            INSERT INTO @UpdateCategoryTable (CategoryInstanceID)
            SELECT DISTINCT CategoryInstanceID
            FROM [CM_JNJ].[dbo].[fn_rbac_CICategoryInfo_All](@LCID, @UserSIDs)
            WHERE CategoryTypeName = N'UpdateClassification'
                AND CategoryInstanceID = TRY_CAST(@UpdateCategory AS INT)
                OR CategoryInstanceName = @UpdateCategory
        -- Update Vendor
        IF @UpdateVendor IS NULL SET @UpdateVendor = N'Microsoft'
        IF @UpdateVendor = 'All'
            INSERT INTO @UpdateCategoryTable (CategoryInstanceID)
            SELECT DISTINCT CategoryInstanceID
            FROM [CM_JNJ].[dbo].[fn_rbac_CICategoryInfo_All](@LCID, @UserSIDs)
            WHERE CategoryTypeName = N'Company'
        ELSE
            INSERT INTO @UpdateCategoryTable (CategoryInstanceID)
            SELECT DISTINCT CategoryInstanceID
            FROM [CM_JNJ].[dbo].[fn_rbac_CICategoryInfo_All](@LCID, @UserSIDs)
            WHERE CategoryTypeName = N'Company'
                AND CategoryInstanceID = TRY_CAST(@UpdateVendor AS INT)
                OR CategoryInstanceName = @UpdateVendor
        -- Targeted State
        IF @IsTargeted IS NULL SET @IsTargeted = 1
        -- Enabled State
        IF @IsEnabled IS NULL SET @IsEnabled = 1
        -- Superseded State
        IF @IsSuperseded IS NULL SET @IsSuperseded = 0

        /* Get missing software updates */
        ;
        WITH UpdateInfo_CTE AS (
           SELECT
                ResourceID          = Systems.ResourceID
                , Installed         = SUM(CASE WHEN ComplianceStatus.Status IN (1,3) THEN 1 ELSE 0 END)
                , Missing           = SUM(CASE WHEN ComplianceStatus.Status = 2 THEN 1 ELSE 0 END)
				, Unknown           = SUM(CASE WHEN ComplianceStatus.Status = 0 THEN 1 ELSE 0 END)
            FROM [CM_JNJ].[dbo].[fn_rbac_R_System](@UserSIDs) AS Systems
                JOIN [CM_JNJ].[dbo].[fn_rbac_UpdateComplianceStatus](@UserSIDs) AS ComplianceStatus ON ComplianceStatus.ResourceID = Systems.ResourceID
                    -- Filter on Required (0 = Unknown, 1 = NotRequired, 2 = Required, 3 = Installed)
                    AND ComplianceStatus.Status = 2
                JOIN @UpdateGroupCIsTable AS UpdateGroupCIsTable ON ComplianceStatus.CI_ID = UpdateGroupCIsTable.CI_ID
                JOIN [CM_JNJ].[dbo].[fn_rbac_ClientCollectionMembers](@UserSIDs) AS CollectionMembers ON CollectionMembers.ResourceID = Systems.ResourceID
                JOIN [CM_JNJ].[dbo].[fn_rbac_UpdateInfo](@LCID, @UserSIDs) AS UpdateCIs ON UpdateCIs.CI_ID = ComplianceStatus.CI_ID
                    -- Filter on Expired
                    AND UpdateCIs.IsExpired = 0
                    -- Filter on Superseded
                    AND UpdateCIs.IsSuperseded = @IsSuperseded
                    -- Filter on Deployment Enabled
                    AND UpdateCIs.IsEnabled = @IsEnabled
                    -- Filter on 1 Software Updates, 8 Software Update Bundle (v_CITypes)
                    AND UpdateCIs.CIType_ID IN (1, 8)
                JOIN [CM_JNJ].[dbo].[fn_rbac_CICategoryInfo_All](@LCID, @UserSIDs) AS CICategoryInfo ON CICategoryInfo.CI_ID = UpdateCIs.CI_ID
                    -- Filter on Selected Update Vendors
                    AND CICategoryInfo.CategoryTypeName IN (N'Company', N'UpdateClassification')
                    -- Filter on Selected Update Classification Categories
                JOIN @UpdateCategoryTable AS UpdateCategoryTable ON UpdateCategoryTable.CategoryInstanceID = CICategoryInfo.CategoryInstanceID
                LEFT JOIN [CM_JNJ].[dbo].[fn_rbac_CITargetedMachines](@UserSIDs) AS Targeted ON Targeted.CI_ID = ComplianceStatus.CI_ID
                    AND Targeted.ResourceID = ComplianceStatus.ResourceID
            WHERE CollectionMembers.CollectionID = @CollectionID
                -- Filter on Managed Clients
                -- Filter on Targeted
                AND IIF(Targeted.ResourceID IS NULL, 0, 1) = @IsTargeted
            GROUP BY Systems.ResourceID
        )

        /* Insert output into result table */
        INSERT INTO @MissingSoftwareUpdates (ResourceID, Missing, Compliant)
            SELECT
                Systems.ResourceID
                , Missing   = ISNULL(Missing, (IIF(Systems.Client0 = 1, 0, NULL)))
                , Compliant = (
                    CASE
                        WHEN Missing = 0 AND Installed > 0 THEN 1 -- Yes
						WHEN Missing > 0                   THEN 0 -- No
                        ELSE 2                                    -- Unknown
                    END
                )
            FROM [CM_JNJ].[dbo].[fn_rbac_R_System](@UserSIDs) AS Systems
                JOIN [CM_JNJ].[dbo].[fn_rbac_FullCollectionMembership](@UserSIDs) AS CollectionMembers ON CollectionMembers.ResourceID = Systems.ResourceID
                LEFT JOIN UpdateInfo_CTE AS UpdateInfo ON UpdateInfo.ResourceID = CollectionMembers.ResourceID
            WHERE CollectionMembers.CollectionID = @CollectionID

        /* Return result */
        RETURN
    END
    /* #endregion */

/* #endregion */
/*##=============================================*/
/*## END QUERY BODY                              */
/*##=============================================*/