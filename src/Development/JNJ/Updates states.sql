    SELECT v_CIAssignment.AssignmentID, v_CIAssignment.AssignmentName,
    v_UpdateInfo.ArticleID, v_UpdateInfo.BulletinID, v_UpdateInfo.Title,
    v_CIAssignment.CollectionName, v_CIAssignment.CollectionID
    FROM v_UpdateInfo INNER JOIN v_CIAssignmentToCI ON
    v_UpdateInfo.CI_ID = v_CIAssignmentToCI.CI_ID INNER JOIN v_CIAssignment ON
    v_CIAssignmentToCI.AssignmentID = v_CIAssignment.AssignmentID
    ORDER BY v_CIAssignment.AssignmentID, v_UpdateInfo.ArticleID



SELECT  v_R_System.Name0, v_UpdateInfo.ArticleID, v_UpdateInfo.BulletinID, v_UpdateInfo.Title,
v_StateNames.StateName, v_UpdateComplianceStatus.LastStatusCheckTime,
v_UpdateComplianceStatus.LastEnforcementMessageTime
FROM v_R_System INNER JOIN v_UpdateComplianceStatus ON
v_R_System.ResourceID = v_UpdateComplianceStatus.ResourceID INNER JOIN v_UpdateInfo ON
v_UpdateComplianceStatus.CI_ID = v_UpdateInfo.CI_ID INNER JOIN v_StateNames ON
v_UpdateComplianceStatus.LastEnforcementMessageID = v_StateNames.StateID
WHERE (v_StateNames.TopicType = 402)


 select
          a.AssignmentName as 'Deployment Name',
		  a.AssignmentID,
		  ugi.Title as 'SUG Name',
          a.CollectionName as 'Collection Name',
          a.CollectionID as 'Collection ID',
          a.StartTime as Available,
          a.EnforcementDeadline as Deadline,
          a.Assignment_UniqueID as DeploymentID,
          a.LastModificationTime as LastModificationTime
          from v_CIAssignmentToGroup atg
          join v_AuthListInfo ugi on ugi.CI_ID=atg.AssignedUpdateGroup
          join v_CIAssignment a on a.AssignmentID=atg.AssignmentID
          where ugi.Title = 'Software Updates - LMW - All - 2024 - 01 and older'
          order by a.AssignmentName