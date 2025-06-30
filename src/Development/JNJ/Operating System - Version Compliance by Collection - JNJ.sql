/*
.SYNOPSIS
    This SQL Query is used to get the Package Deployments for a Collection.
.DESCRIPTION
    This SQL Query is used to get the Package Deployments for a Device or User Collection.
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
DECLARE @UserSIDs     NVARCHAR(16) = 'Disabled';
DECLARE @CollectionID NVARCHAR(16) = 'JNJ0AA4D';
DECLARE @PackageID    NVARCHAR(16) = 'JNJ01B7D';
DECLARE @Locale       INT          = 2;

USE CM_JNJ --Stupidity Workaround

/* Perform cleanup */
IF OBJECT_ID(N'tempdb..#DeploymentStatus', N'U')  IS NOT NULL DROP TABLE #DeploymentStatus;

/* Create temporary tables */
CREATE TABLE #DeploymentStatus (
    ResourceID               INT
    , PackageName            NVARCHAR(250)
    , ProgramName            NVARCHAR(250)
    , DeploymentStatus       NVARCHAR(250)
    , DeploymentStatusDetail NVARCHAR(250)
    , DeploymentStatusTime   DATE
);

/* Get AdvertisementID for Collection */
DECLARE @AdvertisementID NVARCHAR(16) = (
    SELECT Advertisement.AdvertisementID FROM v_AdvertisementInfo AS Advertisement
    WHERE Advertisement.CollectionID = @CollectionID
)

/* Device collection query */
INSERT #DeploymentStatus (ResourceID, PackageName, ProgramName, DeploymentStatus, DeploymentStatusDetail, DeploymentStatusTime)
SELECT
    ResourceID               = AdvertisementStatus.ResourceID
    , PackageName            = Package.Name
    , ProgramName            = Advertisement.ProgramName
    , DeploymentStatus       = AdvertisementStatus.LastStateName
    , DeploymentStatusDetail = AdvertisementStatus.LastStatusMessageIDName
    , DeploymentStatusTime   = CONVERT(NVARCHAR(16), AdvertisementStatus.LastStatusTime, 120)
FROM fn_rbac_Advertisement(@UserSIDs) AS Advertisement
    INNER JOIN fn_rbac_Package2(@UserSIDs) Package ON Package.PackageID = Advertisement.PackageID
    INNER JOIN fn_rbac_ClientAdvertisementStatus(@UserSIDs) AS AdvertisementStatus ON AdvertisementStatus.AdvertisementID = Advertisement.AdvertisementID
    INNER JOIN fn_rbac_FullCollectionMembership(@UserSIDs) AS CollectionMembers ON CollectionMembers.ResourceID = AdvertisementStatus.ResourceID
    INNER JOIN vClassicDeployments AS Deployments ON Deployments.CollectionID = Advertisement.CollectionID
        AND Advertisement.ProgramName <> '*' --Only Programs
WHERE CollectionMembers.CollectionID  = @CollectionID
    AND Advertisement.PackageID       = @PackageID
    AND Advertisement.AdvertisementID = @AdvertisementID

SELECT
    CASE
        WHEN DeploymentStatus.DeploymentStatus = 'Succeeded' THEN 'Yes'
        WHEN ISNULL(DeploymentStatus.DeploymentStatus, 'Unknown') IN ('No Status', 'Unknown') THEN 'Unknown'
        ELSE 'No'
    END AS Compliant
    , ClientState           = IIF(Systems.Client0 = 1, ISNULL(ClientSummary.ClientStateDescription, 'Unknown'), 'Unmanaged')
    , ClientVersion         = CombinedResources.ClientVersion
    , Device                = (
      IIF (
          SystemNames.Resource_Names0 IS NULL
          , IIF(Systems.Full_Domain_Name0 IS NULL, Systems.Name0, Systems.Name0 + N'.' + Systems.Full_Domain_Name0)
          , UPPER(SystemNames.Resource_Names0)
      )
    )
    , PackageName            = DeploymentStatus.PackageName
    , ProgramName            = DeploymentStatus.ProgramName
    , DeploymentStatus       = DeploymentStatus.DeploymentStatus
    , DeploymentStatusDetail = DeploymentStatus.DeploymentStatusDetail
    , DeploymentStatusTime   = DeploymentStatus.DeploymentStatusTime
FROM fn_rbac_R_System(@UserSIDs) AS Systems
    INNER JOIN fn_rbac_FullCollectionMembership(@UserSIDs) AS CollectionMembers ON CollectionMembers.ResourceID = Systems.ResourceID
    LEFT JOIN fn_rbac_RA_System_ResourceNames(@UserSIDs) AS SystemNames ON SystemNames.ResourceID = CollectionMembers.ResourceID
    LEFT JOIN fn_rbac_CH_ClientSummary(@UserSIDs) AS ClientSummary ON ClientSummary.ResourceID = CollectionMembers.ResourceID
    LEFT JOIN #DeploymentStatus AS DeploymentStatus ON DeploymentStatus.ResourceID = CollectionMembers.ResourceID
WHERE
    CollectionMembers.CollectionID  = @CollectionID

/* #endregion */
/*##=============================================*/
/*## END QUERY BODY                              */
/*##=============================================*/