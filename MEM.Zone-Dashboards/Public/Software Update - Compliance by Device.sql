/*
.SYNOPSIS
    Gets the software update compliance for a device in MEMCM.
.DESCRIPTION
    Gets the software update compliance in MEMCM by Device and All Updates.
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
--DECLARE @Locale            AS INT          = 2;
--DECLARE @NameOrResourceID  AS NVARCHAR(50) = 'no-swi-sc-0006';
--DECLARE @Categories        AS INT          = 16777247; -- Security Updates
--DECLARE @Vendors           AS INT          = 16777254; -- Microsoft
--DECLARE @Status            AS INT          = 2;
--DECLARE @Targeted          AS INT          = 1;
--DECLARE @Superseded        AS INT          = 0;
--DECLARE @Enabled           AS INT          = 1;
--DECLARE @ArticleID         AS NVARCHAR(50) = '';
--DECLARE @ExcludeArticleIDs AS NVARCHAR(50) = '';


/* Variable declaration */
DECLARE @LCID              AS INT           = dbo.fn_LShortNameToLCID (@Locale);
DECLARE @DeviceFQDN        AS NVARCHAR(50);
DECLARE @ResourceID        AS INT;

/* Check if @NameOrResourceID is positive Integer (ResourceID) */
IF @NameOrResourceID LIKE N'%[^0-9]%'
    BEGIN

        /* Get ResourceID from Device Name */
        SET @ResourceID = (
            SELECT TOP 1 ResourceID
            FROM fn_rbac_R_System(@UserSIDs) AS Systems
            WHERE Systems.Name0 = @NameOrResourceID
        )
    END
ELSE
    BEGIN
        SET @ResourceID = @NameOrResourceID
    END

/* Get Device FQDN from ResourceID */
SET @DeviceFQDN = (
    SELECT
        IIF(
            SystemNames.Resource_Names0 IS NOT NULL, UPPER(SystemNames.Resource_Names0)
            , IIF(Systems.Full_Domain_Name0 IS NOT NULL, Systems.Name0 + N'.' + Systems.Full_Domain_Name0, Systems.Name0)
        )
    FROM fn_rbac_R_System(@UserSIDs) AS Systems
        JOIN fn_rbac_RA_System_ResourceNames(@UserSIDs) AS SystemNames ON SystemNames.ResourceID = Systems.ResourceID
    WHERE Systems.ResourceID = @ResourceID
)

SELECT DISTINCT
    DeviceFQDN            = @DeviceFQDN
    , IPAddresses         = REPLACE(IPAddresses.Value, N' ', N',')
    , Title               = UpdateCIs.Title
    , Classification      = CICategoryClassification.CategoryInstanceName
    , Vendor              = CICategoryCompany.CategoryInstanceName
    , ArticleID           = UpdateCIs.ArticleID
    , IsTargeted          = IIF(Targeted.ResourceID IS NOT NULL      , N'*', NULL)
    , IsDeployed          = IIF(UpdateCIs.IsDeployed              = 1, N'*', NULL)
    , IsRequired          = IIF(ComplianceStatus.Status           = 2, N'*', NULL)
    , IsEnabled           = IIF(UpdateCIs.IsEnabled               = 1, N'*', NULL)
    , IsDownloaded        = IIF(UpdateContents.ContentProvisioned = 1, N'*', NULL)
    , IsInstalled         = IIF(ComplianceStatus.Status           = 3, N'*', NULL)
    , IsSuperseded        = IIF(UpdateCIs.IsSuperseded            = 1, N'*', NULL)
    , IsExpired           = IIF(UpdateCIs.IsExpired               = 1, N'*', NULL)
    , EnforcementDeadline = CONVERT(NVARCHAR(16), EnforcementDeadline, 120)
    , EnforcementSource   = (
        CASE ComplianceStatus.EnforcementSource
            WHEN 0 THEN 'NONE'
            WHEN 1 THEN 'SMS'
            WHEN 2 THEN 'USER'
        END
    )
    , LastErrorCode       = ComplianceStatus.LastErrorCode
    , MaxExecutionTime    = UpdateCIs.MaxExecutionTime / 60
    , DateRevised         = CONVERT(NVARCHAR(16), UpdateCIs.DateRevised, 120)
    , UpdateUniqueID      = UpdateCIs.CI_UniqueID
    , InformationUrl      = UpdateCIs.InfoURL
FROM fn_rbac_UpdateComplianceStatus(@UserSIDs) AS ComplianceStatus
    JOIN fn_rbac_UpdateInfo(@LCID, @UserSIDs) AS UpdateCIs ON UpdateCIs.CI_ID = ComplianceStatus.CI_ID
        AND UpdateCIs.IsSuperseded IN (@Superseded)  -- Filter on Superseeded
        AND UpdateCIs.IsEnabled IN (@Enabled)        -- Filter on Deployment Enabled
        AND UpdateCIs.CIType_ID IN (1, 8)            -- Filter on 1 Software Updates, 8 Software Update Bundle (v_CITypes)
        AND UpdateCIs.ArticleID NOT IN (             -- Filter on ArticleID csv list
            SELECT VALUE FROM STRING_SPLIT(@ExcludeArticleIDs, N',')
        )
    JOIN fn_rbac_UpdateContents(@UserSIDs) AS UpdateContents ON UpdateContents.CI_ID = UpdateCIs.CI_ID
    JOIN fn_rbac_CICategoryInfo_All(@LCID, @UserSIDs) AS CICategoryCompany ON CICategoryCompany.CI_ID = UpdateCIs.CI_ID
        AND CICategoryCompany.CategoryTypeName = N'Company'
        AND CICategoryCompany.CategoryInstanceID IN (@Vendors)           -- Filter on Selected Update Vendors
    JOIN fn_rbac_CICategoryInfo_All(@LCID, @UserSIDs) AS CICategoryClassification ON CICategoryClassification.CI_ID = UpdateCIs.CI_ID
        AND CICategoryClassification.CategoryTypeName = N'UpdateClassification'
        AND CICategoryClassification.CategoryInstanceID IN (@Categories) -- Filter on Selected Update Classification Categories
    LEFT JOIN fn_rbac_CITargetedMachines(@UserSIDs) AS Targeted ON Targeted.CI_ID = UpdateCIs.CI_ID
        AND Targeted.ResourceID = ComplianceStatus.ResourceID
    OUTER APPLY (
        SELECT EnforcementDeadline = MIN(Assignment.EnforcementDeadline)
        FROM fn_rbac_CIAssignment(@UserSIDs) AS Assignment
            JOIN fn_rbac_CIAssignmentToCI(@UserSIDs) AS AssignmentToCI ON AssignmentToCI.AssignmentID = Assignment.AssignmentID
                AND AssignmentToCI.CI_ID = UpdateCIs.CI_ID
    ) AS EnforcementDeadline
    OUTER APPLY (
        SELECT Value =  (
            SELECT LTRIM(RTRIM(IP.IP_Addresses0)) AS [data()]
            FROM fn_rbac_RA_System_IPAddresses(@UserSIDs) AS IP
            WHERE IP.ResourceID = ComplianceStatus.ResourceID
            -- Exclude IPv6 and 169.254.0.0 Class
                AND IIF(CHARINDEX(N':', IP.IP_Addresses0) > 0 OR CHARINDEX(N'169.254', IP.IP_Addresses0) = 1, 1, 0) = 0
            -- Aggregate results to one row
            FOR XML PATH(N'')
        )
    ) AS IPAddresses
WHERE ComplianceStatus.ResourceID = @ResourceID
    AND ComplianceStatus.Status IN (@Status)                  -- Filter on 'Unknown', 'Required' or 'Installed' (0 = Unknown, 1 = NotRequired, 2 = Required, 3 = Installed)
    AND IIF(Targeted.ResourceID IS NULL, 0, 1) IN (@Targeted) -- Filter on 'Targeted' or 'NotTargeted'
    AND IIF(
            NULLIF(@ArticleID, N'') IS NULL
            , UpdateCIs.ArticleID, @ArticleID
        ) = UpdateCIs.ArticleID                               -- Filter by ArticleID

/* #endregion */
/*##=============================================*/
/*## END QUERY BODY                              */
/*##=============================================*/