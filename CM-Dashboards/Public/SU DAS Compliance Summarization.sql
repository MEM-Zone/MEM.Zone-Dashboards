/*
.SYNOPSIS
    Summarizes the software update compliance for a Collection in SCCM.
.DESCRIPTION
    Summarizes the software update compliance in SCCM by Collection and All Updates.
.NOTES
    Requires SQL 2012 R2.
    Part of a report should not be run separately.
*/

/*##=============================================*/
/*## QUERY BODY                                  */
/*##=============================================*/
/* #region QueryBody */

/* Testing variables !! Need to be commented for Production !! */
--DECLARE @UserSIDs          AS NVARCHAR(10)  = 'Disabled';
--DECLARE @CollectionID      AS NVARCHAR(10)  = 'SMS00001';
--DECLARE @Locale            AS INT           = 2;
--DECLARE @Categories        AS NVARCHAR(250) = 'Tools';
--DECLARE @Targeted          AS INT           = 1;
--DECLARE @Superseded        AS INT           = 0;
--DECLARE @ExcludeArticleIDs AS NVARCHAR(250) = '';

/* Perform cleanup */
IF OBJECT_ID('tempdb..#SummarizationInfo', 'U') IS NOT NULL
    DROP TABLE #SummarizationInfo;

/* Variable declaration */
DECLARE @LCID           AS INT = dbo.fn_LShortNameToLCID(@Locale);
DECLARE @Clients        AS INT = (
    SELECT COUNT(ResourceID)
    FROM fn_rbac_ClientCollectionMembers(@UserSIDs) AS ClientCollectionMembers
    WHERE ClientCollectionMembers.CollectionID = @CollectionID
)
DECLARE @TotalDevices   AS INT = (
    SELECT COUNT(ResourceID)
    FROM fn_rbac_FullCollectionMembership(@UserSIDs) AS CollectionMembership
    WHERE CollectionMembership.CollectionID = @CollectionID
        AND CollectionMembership.ResourceType = 5                        --Select devices only
)
DECLARE @Unmanaged AS INT      = @TotalDevices - @Clients

/* Get compliance data data */
;
WITH SummarizationInfo_CTE AS (
    SELECT DISTINCT
        ResourceID             = Systems.ResourceID
        , ArticleID            = UpdateCIs.ArticleID
        , Title                = UpdateCIs.DisplayName
        , Category             = CICategory.CategoryInstanceName
        , InformationURL       = UpdateCIs.CIInformativeURL
        , UpdatesByCategory    = (
            DENSE_RANK() OVER(PARTITION BY CICategory.CategoryInstanceName ORDER BY UpdateCIs.ArticleID)
            +
            DENSE_RANK() OVER(PARTITION BY CICategory.CategoryInstanceName ORDER BY UpdateCIs.ArticleID DESC)
            -1
        )
        , TotalUniqueUpdates   = (
            DENSE_RANK() OVER(PARTITION BY CollectionMembers.CollectionID ORDER BY ComplianceStatus.Status, UpdateCIs.ArticleID)
            +
            DENSE_RANK() OVER(PARTITION BY CollectionMembers.CollectionID ORDER BY ComplianceStatus.Status, UpdateCIs.ArticleID DESC)
            - 16
        )
        , NonCompliant         = (
            DENSE_RANK() OVER(PARTITION BY CollectionMembers.CollectionID ORDER BY ComplianceStatus.Status, ComplianceStatus.ResourceID)
            +
            DENSE_RANK() OVER(PARTITION BY CollectionMembers.CollectionID ORDER BY ComplianceStatus.Status, ComplianceStatus.ResourceID DESC)
            - 1
        )

 FROM fn_rbac_R_System(@UserSIDs) AS Systems
        JOIN fn_rbac_UpdateComplianceStatus(@UserSIDs) AS ComplianceStatus ON ComplianceStatus.ResourceID = Systems.ResourceID
            AND ComplianceStatus.Status = 2                              --Filter on 'Required' (0 = Unknown, 1 = NotRequired, 2 = Required, 3 = Installed)
        JOIN fn_rbac_ClientCollectionMembers(@UserSIDs) AS CollectionMembers ON CollectionMembers.ResourceID = ComplianceStatus.ResourceID
        JOIN fn_ListUpdateCIs(@LCID) AS UpdateCIs ON UpdateCIs.CI_ID = ComplianceStatus.CI_ID
            AND UpdateCIs.IsExpired = 0
            AND UpdateCIs.IsSuperseded IN (@Superseded)
            AND UpdateCIs.CIType_ID IN (1, 8)                            --Filter on 1 Software Updates, 8 Software Update Bundle (v_CITypes)
            AND UpdateCIs.ArticleID NOT IN (                             --Filter on ArticleID csv list
                SELECT VALUE FROM STRING_SPLIT(@ExcludeArticleIDs, ',')
            )
            AND UpdateCIs.DisplayName NOT LIKE (                         --Filter Preview updates
                '[1-9][0-9][0-9][0-9]-[0-9][0-9]_Preview_of_%'
            )
        JOIN fn_rbac_CICategoryInfo_All(@LCID, @UserSIDs) AS CICategory ON CICategory.CI_ID = ComplianceStatus.CI_ID
            AND CICategory.CategoryTypeName = 'UpdateClassification'
            AND CICategory.CategoryInstanceName IN (@Categories)         --Filter on Selected Update Classification Categories
        LEFT JOIN fn_rbac_CITargetedMachines(@UserSIDs) AS Targeted ON Targeted.ResourceID = ComplianceStatus.ResourceID
            AND Targeted.CI_ID = ComplianceStatus.CI_ID
    WHERE CollectionMembers.CollectionID = @CollectionID
        AND IIF(Targeted.ResourceID IS NULL, 0, 1) IN (@Targeted)        --Filter on 'Targeted' or 'NotTargeted'
)

/* Insert into SummarizationInfo */
SELECT
    ArticleID
    , Title
    , Category
    , InformationURL
    , UpdatesByCategory
    , TotalUniqueUpdates
    , NonCompliant
    , NonCompliantByCategory          = Count(*)
INTO #SummarizationInfo
FROM SummarizationInfo_CTE
GROUP BY
   ArticleID
    , Title
    , Category
    , InformationURL
    , UpdatesByCategory
    , TotalUniqueUpdates
    , NonCompliant

/* Display summarized result */
IF (SELECT COUNT(1) FROM #SummarizationInfo) = 0                         --If compliant (null result)
    BEGIN
        SELECT
            ArticleID                 = NULL
            , Title                   = NULL
            , Category                = 'Selected Categories'
            , CategorySummarization   = 'Selected Categories'
            , InformationURL          = NULL
            , UpdatesByCategory       = NULL
            , TotalUniqueUpdates      = NULL
            , Compliant               = @Clients
            , NonCompliant            = NULL
            , CompliantByCategory     = @Clients
            , NonCompliantByCategory  = NULL
            , Clients                 = @Clients
            , Unmanaged               = @Unmanaged
            , TotalDevices            = @TotalDevices
    END
ELSE
    BEGIN
        SELECT
            ArticleID                 = ArticleID
            , Title                   = Title
            , Category                = Category
            , CategorySummarization   = IIF(
                Category IN ('Critical Updates', 'Security Updates', 'Feature Packs')
                , Category, 'Others'
            )
            , InformationURL          = InformationURL
            , UpdatesByCategory       = UpdatesByCategory
            , TotalUniqueUpdates      = TotalUniqueUpdates
            , Compliant               = @Clients - NonCompliant
            , NonCompliant            = NonCompliant
            , CompliantByCategory     = @Clients - NonCompliantByCategory
            , NonCompliantByCategory  = NonCompliantByCategory
            , Clients                 = @Clients
            , Unmanaged               = @Unmanaged
            , TotalDevices            = @TotalDevices
        FROM #SummarizationInfo
        GROUP BY
            ArticleID
            , Title
            , Category
            , InformationURL
            , UpdatesByCategory
            , TotalUniqueUpdates
            , NonCompliant
            , NonCompliantByCategory
    END

/* Perform cleanup */
IF OBJECT_ID('tempdb..#SummarizationInfo', 'U') IS NOT NULL
    DROP TABLE #SummarizationInfo;

/* #endregion */
/*##=============================================*/
/*## END QUERY BODY                              */
/*##=============================================*/