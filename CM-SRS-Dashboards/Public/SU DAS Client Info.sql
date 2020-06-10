/* Testing variables !! Need to be commented for Production !! */
 DECLARE @UserSIDs     AS NVARCHAR(10) = 'Disabled';
 DECLARE @CollectionID AS NVARCHAR(10) = 'SMS00001'
 DECLARE @OnInternet   AS NVARCHAR(3)  = '0' --You could make this into a multiselection in the report

SELECT
    Device            = (
        IIF(
            SystemNames.Resource_Names0 IS NOT NULL, UPPER(SystemNames.Resource_Names0)
            , IIF(Systems.Full_Domain_Name0 IS NOT NULL, ClientBaseline.Name + '.' + Systems.Full_Domain_Name0, ClientBaseline.Name)
        )
    )
    , ClientBaseline.SiteCode
    , ClientBaseline.ClientVersion
    , ClientBaseline.LastPolicyRequest
    , ClientBaseline.LastDDR
    , ClientBaseline.LastHardwareScan
    , LastOnlineTime = MAX(ClientBaseline.CNLastOnlinetime)
    , LastOfflineTime = MAX(ClientBaseline.CNLastOfflineTime)
    , AccessMP = CNAccessMP
    , IsOnInternet = IIF(ClientBaseline.CNIsOnInternet = 1, 'Yes', 'No')
FROM
    v_CollectionMemberClientBaselineStatus AS ClientBaseline
    JOIN fn_rbac_R_System_Valid(@UserSIDs) AS SystemValid ON SystemValid.ResourceID = ClientBaseline.MachineID
    JOIN fn_rbac_R_System(@UserSIDs) AS Systems ON Systems.ResourceID = SystemValid.ResourceID
    JOIN fn_rbac_ClientCollectionMembers(@UserSIDs) AS CollectionMembers ON CollectionMembers.ResourceID = SystemValid.ResourceID
    LEFT JOIN fn_rbac_RA_System_ResourceNames(@UserSIDs) AS SystemNames ON SystemNames.ResourceID = SystemValid.ResourceID
WHERE
    CollectionMembers.CollectionID = @CollectionID
        AND ClientBaseline.CNIsOnInternet IN (@OnInternet)
GROUP BY
    ClientBaseline.Name
    , ClientBaseline.SiteCode
    , ClientBaseline.ClientVersion
    , ClientBaseline.LastPolicyRequest
    , ClientBaseline.LastDDR
    , ClientBaseline.LastHardwareScan
    , ClientBaseline.CNLastOnlinetime
    , ClientBaseline.CNLastOfflineTime
    , ClientBaseline.CNAccessMP
    , ClientBaseline.CNIsOnInternet
    , SystemNames.Resource_Names0
    , Systems.Full_Domain_Name0
ORDER BY
    ClientBaseline.Name
    , ClientBaseline.CNLastOnlineTime DESC