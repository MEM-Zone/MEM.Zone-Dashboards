/* Get Update Classification Categories */



/* Variable declaration */

DECLARE @LCID AS INT = 1033;



SELECT DISTINCT

    CategoryInstanceID

    , CategoryInstanceName

FROM fn_CICategoryInfo(@LCID)

WHERE CategoryTypeName = N'UpdateClassification'

ORDER BY CategoryInstanceName



/*
.SYNOPSIS
    Gets the top 100 unpatched devices for a Collection in ConfigMgr.
.DESCRIPTION
    Gets the top 100 unpatched devices in ConfigMgr by Collection and All Updates.
.NOTES
    Requires SQL 2016.
    Part of a report should not be run separately.
.LINK
    https://MEM.Zone/Dashboards
.LINK
    https://MEM.Zone/Dashboards-HELP
.LINK
    https://MEM.Zone/Dashboards-ISSUES
*/

/*##=============================================*/
/*## QUERY BODY                                  */
/*##=============================================*/
/* #region QueryBody */

/* Testing variables !! Need to be commented for Production !! */
 DECLARE @UserSIDs              AS NVARCHAR(10)  = 'SMS0001';
 DECLARE @CollectionID          AS NVARCHAR(10)  = 'SMS0001';
 DECLARE @Locale                AS INT           = '2';
 DECLARE @UpdateClassifications AS NVARCHAR(250) = 'SMS0001';
 DECLARE @ExcludeArticleIDs     AS NVARCHAR(250) = 'SMS0001' --('915597,2267602,2461484') -- AV Definitions;

/* Variable declaration */
DECLARE @LCID AS INT = 1033;

/* Get update data */
;
WITH UpdateInfo_CTE
AS (
    SELECT
        ResourceID       = Systems.ResourceID
        , IsUnknown      = COUNT(IIF(ComplianceStatus.Status = 0, '*', NULL))
        , IsMissing      = COUNT(IIF(UpdateCIs.IsExpired     = 0, '*', NULL))
        , IsRequired     = COUNT(*)
        , IsSuperseded   = COUNT(IIF(UpdateCIs.IsSuperseded  = 1 AND UpdateCIs.IsExpired = 0, '*', NULL))
        , IsExpired      = COUNT(IIF(UpdateCIs.IsExpired     = 1, '*', NULL))
        , IsDeployed     = COUNT(IIF(UpdateCIs.IsDeployed    = 1, '*', NULL))
        , IsTargeted     = COUNT(IIF(UpdateCIs.IsExpired     = 0 AND Targeted.ResourceID IS NOT NULL, '*', NULL))
        , IsEnabled      = COUNT(IIF(UpdateCIs.IsEnabled     = 1, '*', NULL))
        , Classification = CICategory.CategoryInstanceName
    FROM fn_rbac_R_System(@UserSIDs) AS Systems
        JOIN v_UpdateComplianceStatus AS ComplianceStatus ON ComplianceStatus.ResourceID = Systems.ResourceID
            AND ComplianceStatus.Status IN (0, 2)                           -- Unknown Required
        JOIN v_ClientCollectionMembers AS CollectionMembers ON CollectionMembers.ResourceID = ComplianceStatus.ResourceID
        JOIN fn_ListUpdateCIs(@LCID) AS UpdateCIs ON UpdateCIs.CI_ID = ComplianceStatus.CI_ID
            AND UpdateCIs.CIType_ID IN (1, 8)                               -- 1 Software Updates, 8 Software Update Bundle (v_CITypes)
          --  AND UpdateCIs.ArticleID NOT IN (                                -- Exclude Updates based on ArticleID
            --    SELECT VALUE FROM STRING_SPLIT(@ExcludeArticleIDs, ',')
          --  )
        JOIN v_CICategoryInfo_All AS CICategory ON CICategory.CI_ID = ComplianceStatus.CI_ID
            AND CICategory.CategoryTypeName = 'UpdateClassification'
            AND CICategory.CategoryInstanceName IN (@UpdateClassifications) -- Join only selected Update Classifications
        LEFT JOIN v_CITargetedMachines AS Targeted ON Targeted.ResourceID = ComplianceStatus.ResourceID
            AND Targeted.CI_ID = ComplianceStatus.CI_ID
    WHERE CollectionMembers.CollectionID = @CollectionID
    GROUP BY
        Systems.ResourceID
        , Systems.Netbios_Name0
        , CICategory.CategoryInstanceName
)

/* Get device info */
SELECT TOP 100
    Systems.ResourceID
    , Device             = IIF(Systems.Full_Domain_Name0 IS NOT NULL, Systems.Name0 + '.' + Systems.Full_Domain_Name0, Systems.Name0)
    , OperatingSystem    = (
        CASE
            WHEN OperatingSystem.Caption0 != '' THEN
                CONCAT(
                    REPLACE(OperatingSystem.Caption0, 'Microsoft ', ''),         -- Remove 'Microsoft ' from OperatingSystem
                    REPLACE(OperatingSystem.CSDVersion0, 'Service Pack ', ' SP') -- Replace 'Service Pack ' with ' SP' in OperatingSystem
                )
            ELSE (

            /* Workaround for systems not in GS_OPERATING_SYSTEM table */
                CASE
                    WHEN CombinedResources.DeviceOS LIKE '%Workstation 6.1%'    THEN 'Windows 7'
                    WHEN CombinedResources.DeviceOS LIKE '%Workstation 6.2%'    THEN 'Windows 8'
                    WHEN CombinedResources.DeviceOS LIKE '%Workstation 6.3%'    THEN 'Windows 8.1'
                    WHEN CombinedResources.DeviceOS LIKE '%Workstation 10.0%'   THEN 'Windows 10'
                    WHEN CombinedResources.DeviceOS LIKE '%Server 6.0'          THEN 'Windows Server 2008'
                    WHEN CombinedResources.DeviceOS LIKE '%Server 6.1'          THEN 'Windows Server 2008R2'
                    WHEN CombinedResources.DeviceOS LIKE '%Server 6.2'          THEN 'Windows Server 2012'
                    WHEN CombinedResources.DeviceOS LIKE '%Server 6.3'          THEN 'Windows Server 2012 R2'
                    WHEN Systems.Operating_System_Name_And0 LIKE '%Server 10%'  THEN (
                        CASE
                            WHEN CAST(REPLACE(Build01, '.', '') AS INTEGER) > 10017763 THEN 'Windows Server 2019'
                            ELSE 'Windows Server 2016'
                        END
                    )
                    ELSE Systems.Operating_System_Name_And0
                END
            )
        END
    )
    , ClientState        = (
        CASE CombinedResources.IsClient
            WHEN 1 THEN ClientSummary.ClientStateDescription
            ELSE 'Unmanaged'
        END
    )
    , Classification     = UpdateInfo.Classification
    , IsMissing          = UpdateInfo.IsMissing
    , IsSuperseded       = UpdateInfo.IsSuperseded
    , IsExpired          = UpdateInfo.IsExpired
    , IsUnknown          = UpdateInfo.IsUnknown
    , IsDeployed         = UpdateInfo.IsDeployed
    , IsTargeted         = UpdateInfo.IsTargeted
    , IsEnabled          = UpdateInfo.IsEnabled
FROM fn_rbac_R_System(@UserSIDs) AS Systems
    JOIN v_CombinedDeviceResources AS CombinedResources ON CombinedResources.MachineID = Systems.ResourceID
    LEFT JOIN v_GS_OPERATING_SYSTEM AS OperatingSystem ON OperatingSystem.ResourceID = Systems.ResourceID
    LEFT JOIN v_CH_ClientSummary AS ClientSummary ON ClientSummary.ResourceID = Systems.ResourceID
    JOIN UpdateInfo_CTE AS UpdateInfo ON UpdateInfo.ResourceID = Systems.ResourceID
    JOIN fn_rbac_FullCollectionMembership(@UserSIDs) AS CollectionMembers ON CollectionMembers.ResourceID = Systems.ResourceID
WHERE CollectionMembers.CollectionID = @CollectionID AND CombinedResources.DeviceOS LIKE '%Workstation 10.0%'
ORDER BY IsMissing DESC

/* #endregion */
/*##=============================================*/
/*## END QUERY BODY                              */
/*##=============================================*/



/*
.SYNOPSIS
    Summarizes the update scan states for a Collection in ConfigMgr.
.DESCRIPTION
    Summarizes the window update scan states in ConfigMgr by Collection and Status Name.
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
DECLARE @UserSIDs     AS NVARCHAR(10)  = 'SMS0001';
DECLARE @CollectionID AS NVARCHAR(10) = 'SMS0001';

/* Variable declaration */
DECLARE @UpdateSearchID INT  = (
    SELECT TOP 1 UpdateSource.UpdateSource_ID
    FROM fn_rbac_SoftwareUpdateSource(@UserSIDs) AS UpdateSource
    WHERE IsPublishingEnabled = 1                 -- Get only the UpdateSource_ID where publishing is enabled
)
DECLARE @TotalDevices AS INT = (
    SELECT COUNT(CollectionMembership.ResourceID)
    FROM fn_rbac_FullCollectionMembership(@UserSIDs) AS CollectionMembership
    WHERE CollectionMembership.CollectionID = @CollectionID
        AND CollectionMembership.ResourceType = 5 -- Select devices only
)

/* Summarize device update scan states */
SELECT
    ScanStateID              = ISNULL(StateNames.StateID, 0)
    , ScanState              = ISNULL(StateNames.StateName, N'Scan state unknown')
    , DevicesByScanState     = COUNT(*)
    , TotalDevices           = @TotalDevices
FROM fn_rbac_FullCollectionMembership(@UserSIDs) AS CollectionMembers
    LEFT JOIN fn_rbac_UpdateScanStatus(@UserSIDs) AS UpdateScanStatus ON UpdateScanStatus.ResourceID = CollectionMembers.ResourceID
        AND (
            @UpdateSearchID = UpdateScanStatus.UpdateSource_ID OR @UpdateSearchID IS NULL
        )
    LEFT JOIN fn_rbac_StateNames(@UserSIDs) AS StateNames ON StateNames.StateID = UpdateScanStatus.LastScanState
        AND StateNames.TopicType       = 501      -- Update source scan summarization TopicTypeID
WHERE CollectionMembers.CollectionID   = @CollectionID
    AND CollectionMembers.ResourceType = 5        -- Select devices only
GROUP BY
    StateNames.StateID
    , StateNames.StateName

/* #endregion */
/*##=============================================*/
/*## END QUERY BODY                              */
/*##=============================================*/

/*
.SYNOPSIS
    Summarizes the software update group compliance in ConfigMgr.
.DESCRIPTION
    Summarizes the software update group compliance for a Collection in ConfigMgr.
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
DECLARE @UserSIDs     AS NVARCHAR(10) = 'SMS0001';
DECLARE @CollectionID AS NVARCHAR(10) = 'SMS0001';
DECLARE @Locale       AS INT          = 2;

/* Variable declaration */
DECLARE @LCID         AS INT = 1033;

/* Get Software Update Groups Compliance */
SELECT
   Title = 'Software Updates - LMW - All - 2023 - 08 and older'

   /* 0 = Unknown, 1 = Installed, 2 = Required, 3 = Not Required */
   , Compliant    = SUM(IIF(ComplianceStatus.Status = 3 OR ComplianceStatus.Status = 1, 1, 0))
   , NonCompliant = SUM(IIF(ComplianceStatus.Status = 2, 1, 0))
   , Unknown      = SUM(IIF(ComplianceStatus.Status = 0, 1, 0))
   , TotalDevices = Count(*)
FROM fn_rbac_Update_ComplianceStatusAll(@UserSIDs) AS ComplianceStatus
    --JOIN fn_rbac_AuthListInfo(@LCID, @UserSIDs) AS AuthList ON AuthList.CI_ID = ComplianceStatus.CI_ID
    JOIN fn_rbac_ClientCollectionMembers(@UserSIDs) AS CollectionMembers ON CollectionMembers.ResourceID = ComplianceStatus.ResourceID
WHERE CollectionMembers.CollectionID = @CollectionID
	AND  ComplianceStatus.CI_ID = 100698
GROUP BY
    ComplianceStatus.CI_ID

/* #endregion */
/*##=============================================*/
/*## END QUERY BODY                              */
/*##=============================================*/


/*
.SYNOPSIS
    Gets the software update compliance for a device in ConfigMgr.
.DESCRIPTION
    Gets the software update compliance in ConfigMgr by Device and All Updates.
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
DECLARE @UserSIDs          AS NVARCHAR(10) = 'SMS0001';
DECLARE @Locale            AS INT          = 2;
DECLARE @NameOrResourceID  AS NVARCHAR(50) = 'SMS0001';
DECLARE @Categories        AS INT          = 31; -- Security Updates; 264 FU
DECLARE @Vendors           AS INT          = 37; -- Microsoft
DECLARE @Status            AS INT          = 2;
DECLARE @Targeted          AS INT          = 1;
DECLARE @Superseded        AS INT          = 0;
DECLARE @Enabled           AS INT          = 1;
DECLARE @ArticleID         AS NVARCHAR(50) = 'SMS0001';
DECLARE @ExcludeArticleIDs AS NVARCHAR(50) = 'SMS0001';


/* Variable declaration */
DECLARE @LCID              AS INT           = 1033;
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
        --AND UpdateCIs.ArticleID NOT IN (             -- Filter on ArticleID csv list
        --    SELECT VALUE FROM STRING_SPLIT(@ExcludeArticleIDs, N',')
        --)
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