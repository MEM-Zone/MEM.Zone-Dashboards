DECLARE @CollectionID AS NVARCHAR(10) = 'SMS0001' DECLARE @AuthListID AS NVARCHAR(500) -- = 'ScopeId_4D51D8C1-3063-4A98-8F54-AECDCB932E04/AuthList_DF4D41EE-A491-4050-9F34-E3403EE273CD 98853'
 DECLARE @CI_ID INT = '98853'
SELECT  CollectionID = @CollectionID
       ,Status = sn.StateName
       ,cs.NumberOfComputers
       ,PComputers = convert(float,isnull(cs.NumberOfComputers,0)*100.00) / isnull(nullif(cs.NumTotal,0),1)
       ,AuthListID = @AuthListID
FROM
(
	SELECT  CI_ID
	       ,NumTotal
	       ,[0] = NumUnknown
	       ,[1] = NumPresent+NumNotApplicable
	       ,[2] = NumMissing
	FROM v_UpdateSummaryPerCollection
	WHERE CI_ID = @CI_ID
	AND CollectionID = @CollectionID
) Total UNPIVOT (NumberOfComputers for [Status] IN ([0], [1], [2])) cs
LEFT JOIN v_StateNames sn
ON sn.TopicType = 300 AND sn.StateID = cs.Status
WHERE cs.NumberOfComputers > 0
ORDER BY cs.NumberOfComputers DESC


DECLARE @StateID0 INT = 0
DECLARE @StateID1 INT = 1
DECLARE @StateID2 INT = 2
SELECT  ccm.ResourceID
       , rs.Name0                  AS MachineName
       , asite.SMS_Assigned_Sites0 AS AssignedSite
       , rs.Client_Version0        AS ClientVersion
       , 'Compliant'               AS CurrState
FROM v_ClientCollectionMembers ccm
    JOIN v_Update_ComplianceStatusAll cs ON cs.CI_ID = '98853'
        AND cs.ResourceID = ccm.ResourceID
        AND (@StateID1 = 0 AND cs.Status = 0 or @StateID1 = 1 AND cs.Status IN (1, 3) or @StateID1 = 2 AND cs.Status = 2)
JOIN v_R_System rs
ON rs.ResourceID = ccm.ResourceID
LEFT JOIN v_RA_System_SMSAssignedSites asite
ON asite.ResourceID = ccm.ResourceID
WHERE ccm.CollectionID = 'JNJ09113'
ORDER BY MachineName




declare @StateID0 int = 0 declare @StateID1 int = 1 declare @StateID2 int = 2
SELECT  ccm.ResourceID
       ,rs.Name0+isnull('.'+rs.Resource_Domain_or_Workgr0,'') AS MachineName
       ,asite.SMS_Assigned_Sites0                             AS AssignedSite
       ,rs.Client_Version0                                    AS ClientVersion
       ,'Non-Compliant'                                       AS CurrState
FROM v_ClientCollectionMembers ccm
JOIN v_Update_ComplianceStatusAll cs
ON cs.CI_ID = @CI_ID AND cs.ResourceID = ccm.ResourceID AND (@StateID2 = 0 AND cs.Status = 0 or @StateID2 = 1 AND cs.Status IN (1, 3) or @StateID2 = 2 AND cs.Status = 2)
JOIN v_R_System rs
ON rs.ResourceID = ccm.ResourceID
LEFT JOIN v_RA_System_SMSAssignedSites asite
ON asite.ResourceID = ccm.ResourceID
WHERE ccm.CollectionID = @CollID
ORDER BY MachineName
