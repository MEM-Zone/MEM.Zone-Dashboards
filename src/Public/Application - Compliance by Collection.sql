/*
.SYNOPSIS
    Lists the Application Deployments for a Collection.
.DESCRIPTION
    Lists the Application Deployments for a Device or User Collection.
.NOTES
    Created by Ioan Popovici
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
/*##========;=====================================*/

/* Testing variables !! Need to be commented for Production !! */

USE CM_JNJ;

--DECLARE @UserSIDs NVARCHAR(16)= 'Disabled';
--DECLARE @AssignmentID NVARCHAR(10) = '232';
--DECLARE @CollectionID NVARCHAR(16)= 'SMS0001';
--DECLARE @CollectionID NVARCHAR(16)= 'SMS0001';


DECLARE @SelectBy NVARCHAR(16);
DECLARE @CollectionType NVARCHAR(16);
SELECT @SelectBy = ResourceID
FROM fn_rbac_FullCollectionMembership(@UserSIDs) AS CollectionMembers
WHERE CollectionMembers.CollectionID = @CollectionID
    AND CollectionMembers.ResourceType = 5; --Device collection
IF @SelectBy > 0
    SET @CollectionType = 2;
ELSE
    SET @CollectionType = 1;

/* User collection query */
IF @CollectionType = 1
    BEGIN
        WITH #CTE_UserData AS (
            SELECT DISTINCT
                ResourceID         = Users.ResourceID
                , ClientState      = IIF(Systems.Client0 = 1, ISNULL(ClientSummary.ClientStateDescription, 'Unknown'), 'Unmanaged')
                , ClientVersion    = Systems.Client_Version0
                , Device           = (
                    IIF (
                        SystemNames.Resource_Names0 IS NULL
                        , IIF(Systems.Full_Domain_Name0 IS NULL, Systems.Name0, Systems.Name0 + N'.' + Systems.Full_Domain_Name0)
                        , UPPER(SystemNames.Resource_Names0)
                    )
                )
                , UserName         = Users.Unique_User_Name0
                , InstalledBy      = AssetData.UserName
                , EnforcementState = dbo.fn_GetAppState(AssetData.ComplianceState, AssetData.EnforcementState, Assignments.OfferTypeID, 1, AssetData.DesiredState, AssetData.IsApplicable)
            FROM fn_rbac_R_User(@UserSIDs) AS Users
                INNER JOIN fn_rbac_FullCollectionMembership(@UserSIDs) AS CollectionMembers ON CollectionMembers.ResourceID = Users.ResourceID
                INNER JOIN v_DeploymentSummary AS Deployments ON Deployments.CollectionID = CollectionMembers.CollectionID
                    AND Deployments.FeatureType = 1
                INNER JOIN v_AppIntentAssetData AS AssetData ON AssetData.UserName = Users.Unique_User_Name0
                    AND AssetData.AssignmentID = @AssignmentID
                INNER JOIN v_CIAssignment AS Assignments ON Assignments.AssignmentID = @AssignmentID
                LEFT  JOIN fn_rbac_R_System(@UserSIDs) AS Systems ON Systems.ResourceID = AssetData.MachineID
                LEFT  JOIN fn_rbac_RA_System_ResourceNames(@UserSIDs) AS SystemNames ON SystemNames.ResourceID = Systems.ResourceID
                LEFT  JOIN fn_rbac_CH_ClientSummary(@UserSIDs) AS ClientSummary ON ClientSummary.ResourceID = Systems.ResourceID
            WHERE CollectionMembers.CollectionID = @CollectionID
                AND CollectionMembers.ResourceType = 4 --Ony Users
        )
        SELECT
            ResourceID         = UserData.ResourceID
            , ClientState      = UserData.ClientState
            , ClientVersion    = UserData.ClientVersion
            , Device           = UserData.Device
            , UserName         = UserData.UserName
            , InstalledBy      = UserData.InstalledBy
            , EnforcementState = UserData.EnforcementState
            , Compliant = (
                CASE
                    WHEN UserData.EnforcementState BETWEEN 1000 AND 1999 THEN N'Yes'
                    WHEN ISNULL(UserData.EnforcementState, 4000 ) = 4000 THEN N'Unknown'
                    ELSE N'No'
                END
            )
        FROM #CTE_UserData AS UserData
        WHERE (
            CASE
                WHEN UserData.EnforcementState BETWEEN 1000 AND 1999 THEN N'Yes'
                WHEN ISNULL(UserData.EnforcementState, 4000 ) = 4000 THEN N'Unknown'
                ELSE N'No'
            END
        ) IN (@Compliant)
    END;

/* Device collection query */
IF @CollectionType = 2
    BEGIN
        WITH #CTE_DeviceData AS (
            SELECT DISTINCT
                ResourceID         = Systems.ResourceID
                , Device           = Systems.Name0
                , UserName         = Systems.User_Name0
                , InstalledBy      = AssetData.UserName
                , EnforcementState = dbo.fn_GetAppState(AssetData.ComplianceState, AssetData.EnforcementState, Assignments.OfferTypeID, 1, AssetData.DesiredState, AssetData.IsApplicable)
            FROM fn_rbac_R_System(@UserSIDs) AS Systems
                INNER JOIN fn_rbac_FullCollectionMembership(@UserSIDs) AS CollectionMembers ON CollectionMembers.ResourceID = Systems.ResourceID
                INNER JOIN v_DeploymentSummary AS Deployments ON Deployments.CollectionID = CollectionMembers.CollectionID
                    AND Deployments.FeatureType = 1
                INNER JOIN v_AppIntentAssetData AS AssetData ON AssetData.MachineID = CollectionMembers.ResourceID
                    AND AssetData.AssignmentID = @AssignmentID
                INNER JOIN v_CIAssignment AS Assignments ON Assignments.AssignmentID = @AssignmentID
            WHERE CollectionMembers.CollectionID = @CollectionID
                AND CollectionMembers.ResourceType = 5 --Only Devices
        )
        SELECT
            ResourceID         = ISNULL(DeviceData.ResourceID, Systems.ResourceID)
            , ClientState      = IIF(Systems.Client0 = 1, ISNULL(ClientSummary.ClientStateDescription, 'Unknown'), 'Unmanaged')
            , ClientVersion    = Systems.Client_Version0
            , Device           = (
                IIF (
                    SystemNames.Resource_Names0 IS NULL
                    , IIF(Systems.Full_Domain_Name0 IS NULL, Systems.Name0, Systems.Name0 + N'.' + Systems.Full_Domain_Name0)
                    , UPPER(SystemNames.Resource_Names0)
                )
            )
            , UserName         = DeviceData.UserName
            , InstalledBy      = DeviceData.InstalledBy
            , EnforcementState = DeviceData.EnforcementState
            , Compliant = (
                CASE
                    WHEN DeviceData.EnforcementState BETWEEN 1000 AND 1999 THEN N'Yes'
                    WHEN ISNULL(DeviceData.EnforcementState, 4000 ) = 4000 THEN N'Unknown'
                    ELSE N'No'
                END
            )
        FROM fn_rbac_R_System(@UserSIDs) AS Systems
            INNER JOIN fn_rbac_FullCollectionMembership(@UserSIDs) AS CollectionMembers ON CollectionMembers.ResourceID = Systems.ResourceID
            LEFT  JOIN fn_rbac_RA_System_ResourceNames(@UserSIDs) AS SystemNames ON SystemNames.ResourceID = Systems.ResourceID
            LEFT  JOIN fn_rbac_CH_ClientSummary(@UserSIDs) AS ClientSummary ON ClientSummary.ResourceID = Systems.ResourceID
            LEFT  JOIN #CTE_DeviceData AS DeviceData ON DeviceData.ResourceID = Systems.ResourceID
        WHERE CollectionMembers.CollectionID = @CollectionID
            AND CollectionMembers.ResourceType = 5 --Only Devices
            AND (
                CASE
                    WHEN DeviceData.EnforcementState BETWEEN 1000 AND 1999 THEN N'Yes'
                    WHEN ISNULL(DeviceData.EnforcementState, 4000 ) = 4000 THEN N'Unknown'
                    ELSE N'No'
                END
            ) IN (@Compliant)
    END;

/*##=============================================*/
/*## END QUERY BODY                              */
/*##=============================================*/