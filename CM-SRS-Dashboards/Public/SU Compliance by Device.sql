/*
.SYNOPSIS
    Gets the software update compliance for a device in SCCM.
.DESCRIPTION
    Gets the software update compliance in SCCM by Device and All Updates.
.NOTES
    Requires SQL 2012 R2.
    Part of a report should not be run separately.
.LINK
    https://SCCM.Zone/
.LINK
    https://SCCM.Zone/CM-SRS-Dashboards-GIT
.LINK
    https://SCCM.Zone/CM-SRS-Dashboards-ISSUES
*/

/*##=============================================*/
/*## QUERY BODY                                  */
/*##=============================================*/
/* #region QueryBody */

/* Testing variables !! Need to be commented for Production !! */
 --DECLARE @UserSIDs          AS NVARCHAR(10) = 'Disabled';
 --DECLARE @Locale            AS INT          = 2;
 --DECLARE @NameOrResourceID  AS NVARCHAR(50) = 'DCM-SRV-RDS-01';
 --DECLARE @Categories        AS NVARCHAR(50) = 'Updates';
 --DECLARE @Vendors           AS NVARCHAR(50) = 'Microsoft';
 --DECLARE @Status            AS INT          = 2;
 --DECLARE @Targeted          AS INT          = 1;
 --DECLARE @Superseded        AS INT          = 0;
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

SELECT
    DeviceFQDN            = @DeviceFQDN
    , Title               = UpdateCIs.Title
    , Classification      = CICategoryClassification.CategoryInstanceName
    , Vendor              = CICategoryCompany.CategoryInstanceName
    , ArticleID           = UpdateCIs.ArticleID
    , IsTargeted          = IIF(Targeted.ResourceID IS NOT NULL, '*', NULL)
    , IsDeployed          = IIF(UpdateCIs.IsDeployed    = 1, '*', NULL)
    , IsRequired          = IIF(ComplianceStatus.Status = 2, '*', NULL)
    , IsInstalled         = IIF(ComplianceStatus.Status = 3, '*', NULL)
    , IsSuperseded        = IIF(UpdateCIs.IsSuperseded  = 1, '*', NULL)
    , IsExpired           = IIF(UpdateCIs.IsExpired     = 1, '*', NULL)
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
        AND UpdateCIs.IsSuperseded IN (@Superseded)
        AND UpdateCIs.CIType_ID IN (1, 8)                                  -- Filter on 1 Software Updates, 8 Software Update Bundle (v_CITypes)
        AND UpdateCIs.ArticleID NOT IN (                                   -- Filter on ArticleID csv list
            SELECT VALUE FROM STRING_SPLIT(@ExcludeArticleIDs, ',')
        )
        AND UpdateCIs.Title NOT LIKE (                                     -- Filter Preview Updates
            N'[1-9][0-9][0-9][0-9]-[0-9][0-9]_Preview_of_%'
        )
    JOIN fn_rbac_CICategoryInfo_All(@LCID, @UserSIDs) AS CICategoryCompany ON CICategoryCompany.CI_ID = UpdateCIs.CI_ID
        AND CICategoryCompany.CategoryTypeName = N'Company'
        AND CICategoryCompany.CategoryInstanceName IN (@Vendors)           -- Filter on Selected Update Vendors
    JOIN fn_rbac_CICategoryInfo_All(@LCID, @UserSIDs) AS CICategoryClassification ON CICategoryClassification.CI_ID = UpdateCIs.CI_ID
        AND CICategoryClassification.CategoryTypeName = N'UpdateClassification'
        AND CICategoryClassification.CategoryInstanceName IN (@Categories) -- Filter on Selected Update Classification Categories
    LEFT JOIN fn_rbac_CITargetedMachines(@UserSIDs) AS Targeted ON Targeted.CI_ID = ComplianceStatus.CI_ID
        AND Targeted.ResourceID = ComplianceStatus.ResourceID
    OUTER APPLY (
        SELECT EnforcementDeadline = MIN(Assignment.EnforcementDeadline)
        FROM fn_rbac_CIAssignment(@UserSIDs) AS Assignment
            JOIN fn_rbac_CIAssignmentToCI(@UserSIDs) AS AssignmentToCI ON AssignmentToCI.AssignmentID = Assignment.AssignmentID
                AND AssignmentToCI.CI_ID = ComplianceStatus.CI_ID
    ) AS EnforcementDeadline
WHERE ComplianceStatus.ResourceID = @ResourceID
    AND ComplianceStatus.Status IN (@Status)                               -- Filter on 'Unknown', 'Required' or 'Installed' (0 = Unknown, 1 = NotRequired, 2 = Required, 3 = Installed)
    AND IIF(Targeted.ResourceID IS NULL, 0, 1) IN (@Targeted)              -- Filter on 'Targeted' or 'NotTargeted'
    AND IIF(UpdateCIs.ArticleID = @ArticleID, 1, 0) = IIF(@ArticleID <> '', 1, 0)

/* #endregion */
/*##=============================================*/
/*## END QUERY BODY                              */
/*##=============================================*/