/*
.SYNOPSIS
    Lists the Package Deployments for a Collection.
.DESCRIPTION
    Lists the Package Deployments for a Device or User Collection.
.NOTES
    Created by Ioan Popovici
    Part of a report should not be run separately.
.LINK
    https://MEMZ.one/DE-Deployments-by-Device-or-User
.LINK
    https://MEMZ.one/DE-Deployments-by-Device-or-User-CHANGELOG
.LINK
    https://MEMZ.one/DE-Deployments-by-Device-or-User-GIT
.LINK
    https://MEM.Zone/ISSUES
*/

/*##=============================================*/
/*## QUERY BODY                                  */
/*##=============================================*/

/* Testing variables !! Need to be commented for Production !! */

DECLARE @UserSIDs VARCHAR(16)= 'Disabled';
DECLARE @CollectionID VARCHAR(16)= 'SMS0001';
--DECLARE @CollectionID VARCHAR(16)= 'SMS0001';
DECLARE @SelectBy VARCHAR(16);
DECLARE @CollectionType VARCHAR(16);
SELECT @SelectBy = ResourceID
FROM fn_rbac_FullCollectionMembership(@UserSIDs) AS CollectionMembers
WHERE CollectionMembers.CollectionID = @CollectionID
    AND CollectionMembers.ResourceType = 5; --Device collection
IF @SelectBy > 0
    SET @CollectionType = 2;
ELSE
    SET @CollectionType = 1;


/* Initialize CollectionMembers table */
DECLARE @CollectionMembers TABLE (
    ResourceID     INT
    , ResourceType INT
    , SMSID        NVARCHAR(100)
)

/* Populate CollectionMembers table */
INSERT INTO @CollectionMembers (ResourceID, ResourceType, SMSID)
SELECT ResourceID, ResourceType, SMSID
FROM fn_rbac_FullCollectionMembership(@UserSIDs) AS CollectionMembers
WHERE CollectionMembers.CollectionID = @CollectionID
    AND CollectionMembers.ResourceType IN (4, 5); --Only Users or Devices

/* User collection query */
IF @CollectionType = 1
    BEGIN
        SELECT DISTINCT
            UserName         = CollectionMembership.SMSID
            , PackageName    = Package.Name
            , ProgramName    = Advertisment.ProgramName
            , CollectionName = Deployment.CollectionName
            , Purpose        = (
                CASE
                    WHEN Advertisment.AssignedScheduleEnabled = 0
                    THEN 'Available'
                    ELSE 'Required'
                END
            )
            , LastStateName  = AdvertismentStatus.LastStateName
            , Device         = 'Device'         -- Needed in order to be able to save the report.
        FROM v_Advertisement AS Advertisment
            INNER JOIN v_Package AS Package ON Package.PackageID = Advertisment.PackageID
            LEFT JOIN v_ClientAdvertisementStatus AS AdvertismentStatus ON AdvertismentStatus.AdvertisementID = Advertisment.AdvertisementID
            INNER JOIN vClassicDeployments AS Deployment ON Deployment.DeploymentID = Advertisment.AdvertisementID
            INNER JOIN fn_rbac_FullCollectionMembership(@UserSIDs) AS CollectionMembership ON CollectionMembership.CollectionID = Advertisment.CollectionID
                AND ResourceType = 4 -- Ony Users
        WHERE CollectionMembership.SMSID IN (
            SELECT SMSID
            FROM @CollectionMembers
            WHERE ResourceType = 4 -- Ony Users
        )
    END;

/* Device collection query */
IF @CollectionType = 2
    BEGIN
		WITH ProgramInfo_CTE
		AS (
			SELECT DISTINCT
				ResourceID = CombinedResources.MachineID
				, PackageName    = Package.Name
				, ProgramName    = Advertisment.ProgramName
				, CollectionName = Deployment.CollectionName
				, Purpose        = (
					CASE
						WHEN Deployment.Purpose = 0
						THEN 'Available'
						ELSE 'Required'
					END
				)
				, LastStateName  = AdvertismentStatus.LastStateName
			FROM v_Advertisement AS Advertisment
				JOIN v_Package AS Package ON Package.PackageID = Advertisment.PackageID
				JOIN v_ClientAdvertisementStatus AS AdvertismentStatus ON AdvertismentStatus.AdvertisementID = Advertisment.AdvertisementID
				JOIN v_CombinedDeviceResources AS CombinedResources ON CombinedResources.MachineID = AdvertismentStatus.ResourceID
				JOIN vClassicDeployments AS Deployment ON Deployment.CollectionID = Advertisment.CollectionID
					AND Advertisment.ProgramName = 'Install-AP0048549-0'
			WHERE CombinedResources.isClient = 1
				AND CombinedResources.MachineID IN (
					SELECT ResourceID
					FROM @CollectionMembers
					WHERE ResourceType = 5 -- Only Devices
				)
		)

		SELECT
			CollectionMembers.ResourceID
			, Device = CombinedResources.Name
			, ClientState           = IIF(CombinedResources.IsClient = 1, ClientSummary.ClientStateDescription, 'Unmanaged')
			, ClientVersion         = CombinedResources.ClientVersion
			, PackageName
			, ProgramName
			, CollectionName
			, Purpose
			, LastStateName

			FROM @CollectionMembers AS CollectionMembers
				LEFT JOIN ProgramInfo_CTE AS ProgramInfo ON ProgramInfo.ResourceID = CollectionMembers.ResourceID
				LEFT JOIN [fn_rbac_CH_ClientSummary](@UserSIDs) AS ClientSummary ON ClientSummary.ResourceID = CollectionMembers.ResourceID
				LEFT JOIN v_CombinedDeviceResources AS CombinedResources ON CombinedResources.MachineID = CollectionMembers.ResourceID
			ORDER BY LastStateName, Device


    END;


/*##=============================================*/
/*## END QUERY BODY                              */
/*##=============================================*/s