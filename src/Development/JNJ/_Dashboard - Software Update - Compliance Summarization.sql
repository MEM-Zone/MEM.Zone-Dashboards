/*
.SYNOPSIS
    Summarizes the software update compliance.
.DESCRIPTION
    Summarizes the software update compliance for a Collection in ConfigMgr.
.NOTES
    Requires SQL 2016.
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
--DECLARE @UserSIDs          AS NVARCHAR(10) = 'Disabled';
--DECLARE @CollectionID      AS NVARCHAR(10) = 'SMS0001';
--DECLARE @Locale            AS INT          = 2;
--DECLARE @Categories        AS INT          = 16777247; -- Security Updates
--DECLARE @Vendors           AS INT          = 16777254; -- Microsoft
--DECLARE @Targeted          AS INT          = 1;
--DECLARE @Superseded        AS INT          = 0;
--DECLARE @Enabled           AS INT          = 1;
--DECLARE @ExcludeArticleIDs AS NVARCHAR(50) = NULL;

/* Perform cleanup */
USE CM_JNJ; -- Stupidity Wokaround
IF OBJECT_ID(N'tempdb..#SummarizationInfo', N'U') IS NOT NULL
    DROP TABLE #SummarizationInfo;

/* Variable declaration */
--DECLARE @LCID                  AS INT = dbo.fn_LShortNameToLCID(@Locale);
DECLARE @LCID                  AS INT = 1033; -- Stupidity Wokaround
DECLARE @Clients               AS INT = (
    SELECT COUNT(ResourceID)
    FROM fn_rbac_ClientCollectionMembers(@UserSIDs) AS ClientCollectionMembers
    WHERE ClientCollectionMembers.CollectionID = @CollectionID
);
DECLARE @TotalDevices          AS INT = (
    SELECT COUNT(ResourceID)
    FROM fn_rbac_FullCollectionMembership(@UserSIDs) AS CollectionMembership
    WHERE CollectionMembership.CollectionID = @CollectionID
        AND CollectionMembership.ResourceType = 5 -- Select devices only
);
DECLARE @Unmanaged             AS INT = @TotalDevices - @Clients;

/* Get compliance data data */
;
WITH SummarizationInfo_CTE AS (
    SELECT
        ResourceID          = Systems.ResourceID
        , CI_ID             = UpdateCIs.CI_ID
        , ArticleID         = UpdateCIs.ArticleID
        , CategoryID        = CICategoryClassification.CategoryInstanceID
        , Category          = CICategoryClassification.CategoryInstanceName
        , VendorID          = CICategoryCompany.CategoryInstanceID
        , UpdatesByCategory = (
            DENSE_RANK() OVER(PARTITION BY CICategoryClassification.CategoryInstanceID ORDER BY UpdateCIs.CI_ID)
            +
            DENSE_RANK() OVER(PARTITION BY CICategoryClassification.CategoryInstanceID ORDER BY UpdateCIs.CI_ID DESC)
            - 1
        )
        , TotalUpdates      = (
            DENSE_RANK() OVER(PARTITION BY CollectionMembers.CollectionID ORDER BY ComplianceStatus.Status, UpdateCIs.CI_ID)
            +
            DENSE_RANK() OVER(PARTITION BY CollectionMembers.CollectionID ORDER BY ComplianceStatus.Status, UpdateCIs.CI_ID DESC)
            - 1
        )
        , NonCompliant      = (
            DENSE_RANK() OVER(PARTITION BY CollectionMembers.CollectionID ORDER BY ComplianceStatus.Status, ComplianceStatus.ResourceID)
            +
            DENSE_RANK() OVER(PARTITION BY CollectionMembers.CollectionID ORDER BY ComplianceStatus.Status, ComplianceStatus.ResourceID DESC)
            - 1
        )
FROM fn_rbac_R_System(@UserSIDs) AS Systems
    JOIN fn_rbac_UpdateComplianceStatus(@UserSIDs) AS ComplianceStatus ON ComplianceStatus.ResourceID = Systems.ResourceID
        AND ComplianceStatus.Status = 2                                  -- Filter on 'Required' (0 = Unknown, 1 = NotRequired, 2 = Required, 3 = Installed)
    JOIN fn_rbac_ClientCollectionMembers(@UserSIDs) AS CollectionMembers ON CollectionMembers.ResourceID = ComplianceStatus.ResourceID
    JOIN fn_rbac_UpdateInfo(@LCID, @UserSIDs) AS UpdateCIs ON UpdateCIs.CI_ID = ComplianceStatus.CI_ID
        AND UpdateCIs.IsExpired = 0                                      -- Filter on Expired
        AND UpdateCIs.IsSuperseded IN (@Superseded)                      -- Filter on Superseded
        AND UpdateCIs.IsEnabled IN (@Enabled)                            -- Filter on Deployment Enabled
        AND UpdateCIs.CIType_ID IN (1, 8)                                -- Filter on 1 Software Updates, 8 Software Update Bundle (v_CITypes)
        AND UpdateCIs.ArticleID NOT IN (                                 -- Filter on ArticleID csv list
                --SELECT VALUE FROM STRING_SPLIT(@ExcludeArticleIDs, N',')
                SELECT SubString FROM fn_SplitString(@ExcludeArticleIDs, N',') -- Stupidity Wokaround
            )
    JOIN fn_rbac_CICategoryInfo_All(@LCID, @UserSIDs) AS CICategoryCompany ON CICategoryCompany.CI_ID = UpdateCIs.CI_ID
        AND CICategoryCompany.CategoryTypeName = N'Company'
        AND CICategoryCompany.CategoryInstanceID IN (@Vendors)           -- Filter on Selected Update Vendors
    JOIN fn_rbac_CICategoryInfo_All(@LCID, @UserSIDs) AS CICategoryClassification ON CICategoryClassification.CI_ID = UpdateCIs.CI_ID
        AND CICategoryClassification.CategoryTypeName = N'UpdateClassification'
        AND CICategoryClassification.CategoryInstanceID IN (@Categories) -- Filter on Selected Update Classification Categories
    LEFT JOIN fn_rbac_CITargetedMachines(@UserSIDs) AS Targeted ON Targeted.CI_ID = ComplianceStatus.CI_ID
        AND Targeted.ResourceID = ComplianceStatus.ResourceID
WHERE CollectionMembers.CollectionID = @CollectionID
    AND IIF(Targeted.ResourceID IS NULL, 0, 1) IN (@Targeted)            -- Filter on 'Targeted' or 'NotTargeted'
)

/* Insert into SummarizationInfo */
SELECT
    CI_ID
    , ArticleID
    , CategoryID
    , Category
    , CategorySummarization  =	 (
        CASE CategoryID
            WHEN 16777247 THEN 1 -- Security Updates
            WHEN 16777243 THEN 2 -- Critical Updates
            WHEN 16777252 THEN 3 -- Upgrades
            ELSE 4
        END
    )
    , VendorID
    , UpdatesByCategory
    , TotalUpdates
    , NonCompliant
    , NonCompliantByCategory = COUNT(*)
INTO #SummarizationInfo
FROM SummarizationInfo_CTE
GROUP BY
    CI_ID
    , ArticleID
    , CategoryID
    , Category
    , VendorID
    , UpdatesByCategory
    , TotalUpdates
    , NonCompliant

/* Display summarized result */
IF NOT EXISTS(SELECT 1 FROM #SummarizationInfo) -- If compliant (null result)
    BEGIN
        SELECT
            CI_ID                       = NULL
            , ArticleID                 = NULL
            , Title                     = NULL
            , CategoryIndex             = NULL
            , CategoryID                = NULL
            , Category                  = N'Selected Categories'
            , CategorySumIndex          = NULL
            , CategorySummarization     = N'Selected Categories'
            , VendorID                  = NULL
            , InformationURL            = NULL
            , UpdatesByCategory         = NULL
            , TotalUpdates              = NULL
            , Compliant                 = @Clients
            , NonCompliant              = NULL
            , CompliantByCategory       = @Clients
            , NonCompliantByCategory    = NULL
            , NonCompliantByCategorySum = NULL
            , Clients                   = @Clients
            , Unmanaged                 = @Unmanaged
            , TotalDevices              = @TotalDevices
    END
ELSE
    BEGIN
        SELECT
            CI_ID                       = UpdateInfo.CI_ID
            , ArticleID                 = UpdateInfo.ArticleID
            , Title                     = UpdateInfo.Title
            , CategoryIndex             = (     -- Used for Missing Updates by Classification Chart
                DENSE_RANK() OVER(PARTITION BY SummarizationInfo.CategoryID ORDER BY UpdateInfo.CI_ID)
            )
            , CategoryID                = SummarizationInfo.CategoryID
            , Category                  = Category
            , CategorySumIndex          = (     -- Used for Top 5 Devices with Missing Updates by Classification Chart
                DENSE_RANK() OVER(PARTITION BY SummarizationInfo.CategorySummarization ORDER BY SummarizationInfo.NonCompliantByCategory DESC, UpdateInfo.CI_ID)
            )
            , CategorySummarization     = SummarizationInfo.CategorySummarization
            , VendorID                  = SummarizationInfo.VendorID
            , InformationURL            = UpdateInfo.InfoURL
            , UpdatesByCategory         = SummarizationInfo.UpdatesByCategory
            , TotalUpdates              = SummarizationInfo.TotalUpdates
            , Compliant                 = @Clients - SummarizationInfo.NonCompliant
            , NonCompliant              = SummarizationInfo.NonCompliant
            , CompliantByCategory       = @Clients - SummarizationInfo.NonCompliantByCategory
            , NonCompliantByCategory    = SummarizationInfo.NonCompliantByCategory
            , NonCompliantByCategorySum = (
                SUM(NonCompliantByCategory) OVER(PARTITION BY SummarizationInfo.CategoryID, SummarizationInfo.ArticleID)
            )
            , Clients                   = @Clients
            , Unmanaged                 = @Unmanaged
            , TotalDevices              = @TotalDevices
        FROM #SummarizationInfo AS SummarizationInfo
            JOIN fn_rbac_UpdateInfo(@LCID, @UserSIDs) AS UpdateInfo ON UpdateInfo.CI_ID = SummarizationInfo.CI_ID
                AND UpdateInfo.ArticleID = SummarizationInfo.ArticleID
        GROUP BY
            UpdateInfo.CI_ID
            , UpdateInfo.ArticleID
            , SummarizationInfo.ArticleID
            , UpdateInfo.Title
            , SummarizationInfo.CategorySummarization
            , SummarizationInfo.CategoryID
            , SummarizationInfo.Category
            , SummarizationInfo.VendorID
            , UpdateInfo.InfoURL
            , SummarizationInfo.UpdatesByCategory
            , SummarizationInfo.TotalUpdates
            , SummarizationInfo.NonCompliant
            , SummarizationInfo.NonCompliantByCategory
        ORDER BY
            CategorySummarization
            , NonCompliantByCategorySum DESC
    END

/* Perform cleanup */
IF OBJECT_ID(N'tempdb..#SummarizationInfo', N'U') IS NOT NULL
    DROP TABLE #SummarizationInfo;

/* #endregion */
/*##=============================================*/
/*## END QUERY BODY                              */
/*##=============================================*/