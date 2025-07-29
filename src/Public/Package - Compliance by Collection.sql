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
--DECLARE @UserSIDs        NVARCHAR(16) = 'Disabled';
--DECLARE @CollectionID    NVARCHAR(16) = 'SMS0001';
--DECLARE @Compliant       NVARCHAR(10) = 'Yes';
--DECLARE @Locale          INT          = 2;
--DECLARE @AdvertisementID NVARCHAR(16) = (
--    SELECT Advertisement.AdvertisementID FROM v_AdvertisementInfo AS Advertisement
--    WHERE Advertisement.CollectionID = @CollectionID
--)

/* Perform cleanup */
IF OBJECT_ID(N'tempdb..#DeploymentStatus', N'U')  IS NOT NULL DROP TABLE #DeploymentStatus;

/* Create temporary tables */
CREATE TABLE #DeploymentStatus (
    ResourceID         INT
    , Compliant        NVARCHAR(10)
    , LastStatus       NVARCHAR(250)
    , LastStatusDetail NVARCHAR(250)
    , LastStatusTime   DATETIME
);

/* Deployment status information query */
INSERT #DeploymentStatus (ResourceID, Compliant, LastStatus, LastStatusDetail, LastStatusTime)
SELECT
    ResourceID         = AdvertisementStatus.ResourceID
    , Compliant        = (
        CASE
            WHEN AdvertisementStatus.LastStateName = N'Succeeded' THEN N'Yes'
            WHEN ISNULL(AdvertisementStatus.LastStateName, N'Unknown') IN (N'No Status', N'Unknown') THEN N'Unknown'
            ELSE N'No'
        END
    )
    , LastStatus       = AdvertisementStatus.LastStateName
    , LastStatusDetail = AdvertisementStatus.LastStatusMessageIDName
    , LastStatusTime   = AdvertisementStatus.LastStatusTime
FROM fn_rbac_Advertisement(@UserSIDs) AS Advertisement
    INNER JOIN fn_rbac_Package2(@UserSIDs) Package ON Package.PackageID = Advertisement.PackageID
    INNER JOIN fn_rbac_ClientAdvertisementStatus(@UserSIDs) AS AdvertisementStatus ON AdvertisementStatus.AdvertisementID = Advertisement.AdvertisementID
    INNER JOIN fn_rbac_FullCollectionMembership(@UserSIDs) AS CollectionMembers ON CollectionMembers.ResourceID = AdvertisementStatus.ResourceID
    INNER JOIN vClassicDeployments AS Deployments ON Deployments.CollectionID = Advertisement.CollectionID
        AND Advertisement.ProgramName <> N'*' --Only Programs
WHERE CollectionMembers.CollectionID  = @CollectionID
    AND Advertisement.AdvertisementID = @AdvertisementID

/* Device information query */
SELECT DISTINCT
    ResourceID         = Systems.ResourceID
    , Compliant        = ISNULL(DeploymentStatus.Compliant, N'Unknown')
    , ClientState      = IIF(Systems.Client0 = 1, ISNULL(ClientSummary.ClientStateDescription, N'Unknown'), N'Unmanaged')
    , ClientVersion    = Systems.Client_Version0
    , Device           =  Systems.Name0 + N'.' + Systems.Full_Domain_Name0
    , LastStatus        = DeploymentStatus.LastStatus
    , LastStatusDetail  = DeploymentStatus.LastStatusDetail
    , LastStatusTime    = CONVERT(NVARCHAR(16), DeploymentStatus.LastStatusTime, 120)
FROM fn_rbac_R_System(@UserSIDs) AS Systems
    INNER JOIN fn_rbac_FullCollectionMembership(@UserSIDs) AS CollectionMembers ON CollectionMembers.ResourceID = Systems.ResourceID
    LEFT JOIN fn_rbac_RA_System_ResourceNames(@UserSIDs) AS SystemNames ON SystemNames.ResourceID = CollectionMembers.ResourceID
    LEFT JOIN fn_rbac_CH_ClientSummary(@UserSIDs) AS ClientSummary ON ClientSummary.ResourceID = CollectionMembers.ResourceID
    LEFT JOIN #DeploymentStatus AS DeploymentStatus ON DeploymentStatus.ResourceID = CollectionMembers.ResourceID
WHERE
    CollectionMembers.CollectionID = @CollectionID
        AND DeploymentStatus.Compliant IN (@Compliant) -- Compliant (Yes, No, Unknown)

/* #endregion */
/*##=============================================*/
/*## END QUERY BODY                              */
/*##=============================================*/