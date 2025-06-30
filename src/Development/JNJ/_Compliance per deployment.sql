use cm_custom
truncate table LMW_Deploy_Data
insert into LMW_Deploy_Data
select			a.assignmentID,
                DeploymentID=a.Assignment_UniqueID,
                DeploymentName=a.AssignmentName,
                Available=a.StartTime,
                Deadline=a.EnforcementDeadline,
                LastEnforcementState=sn.StateName,
                NumberOfComputers=sc.StateCount,
                --select count(*) from cm_jnj.dbo.v_CIAssignmentTargetedMachines as pcomputers,
                DeploymentStateID=sc.StateType*10000 + sc.StateID
            from cm_jnj.dbo.v_CIAssignment  a
            cross apply(select StateType, StateID, StateCount=count(*) from cm_jnj.dbo.v_AssignmentState_Combined  where AssignmentID=a.AssignmentID and StateType in (300,301) group by StateType, StateID) sc
            left join cm_jnj.dbo.v_StateNames  sn on sn.TopicType=sc.StateType and sn.StateID=sc.StateID
            where a.AssignmentID in (select AssignmentID from cm_jnj.dbo.v_CIAssignment  where assignmentname like '%LMW-Global%')
            order by a.AssignmentName, sn.StateName


truncate table LMW_Deploy_MaintW
insert into LMW_Deploy_MaintW
Select DISTINCT(cm_jnj.dbo.v_R_System.Name0) as Computer_Name, cm_jnj.dbo.v_Collection.Name AS [Maintenance Window]
From cm_jnj.dbo.v_R_System
inner join cm_jnj.dbo.v_gS_JNJ_DISTINGUISHEDNAME on cm_jnj.dbo.v_R_System.ResourceID = cm_jnj.dbo.v_gS_JNJ_DISTINGUISHEDNAME.ResourceID
--inner join v_GS_System on v_R_System.ResourceID = v_GS_System.ResourceID
inner join cm_jnj.dbo.v_ClientCollectionMembers on cm_jnj.dbo.v_R_System.ResourceID = cm_jnj.dbo.v_ClientCollectionMembers.ResourceID
inner join cm_jnj.dbo.v_Collection on cm_jnj.dbo.v_Collection.CollectionID = cm_jnj.dbo.v_ClientCollectionMembers.CollectionID
--inner join v_RA_System_SMSAssignedSites on v_R_System.ResourceID = v_RA_System_SMSAssignedSites.ResourceID
--inner join v_GS_OPERATING_SYSTEM on v_R_System.ResourceID = v_GS_OPERATING_SYSTEM.ResourceID
Where (cm_jnj.dbo.v_Collection.Name like 'LMw-All-%')
and cm_jnj.dbo.v_R_System.Client0 = '1'
and cm_jnj.dbo.v_R_System.Obsolete0 = '0'
and cm_jnj.dbo.v_gS_JNJ_DISTINGUISHEDNAME.distinguishedname0 like '%REGULATEDWORKSTATIONS%'



--declare @asnid int = (select AssignmentID from v_CIAssignment  where Assignment_UniqueID=@DeploymentID and AssignmentType in (1,5))
 select distinct
            --s.ResourceID,
            m.Name0 as ComputerName0,
            --m.User_Domain0+'\'+m.User_Name0 as LastLoggedOnUser,
            --asite.SMS_Assigned_Sites0 as AssignedSite,
            --m.Client_Version0 as ClientVersion,
            --s.StateTime as DeploymentStateTime,
            --(s.LastStatusMessageID&0x0000FFFF) as ErrorStatusID,
            sn.StateName as Status,
[Pending Restart] =case uss.LastErrorCode
when '2359301' then 'Pending System Restart'
else 'No Pending Restart' end,
ldw.[Maintenance Window],
a.DeploymentName
--a.DeploymentStateID,
           -- a.DeploymentID
            --statusinfo.MessageName as ErrorStatusName
          from

				cm_custom.dbo.LMW_Deploy_Data  a
			         left join (
            select ac.AssignmentID, ResourceID, StateType, StateID, StateTime, LastStatusMessageID from cm_jnj.dbo.v_AssignmentState_Combined ac right join cm_custom.dbo.LMW_Deploy_Data ldd
on ac.assignmentid=ldd.assignmentid
  where ldd.DeploymentStateID/10000 in (300,301)
            union
            select at.AssignmentID, ResourceID, TopicType, StateID, StateTime, LastStatusMessageID from cm_jnj.dbo.v_AssignmentStatePerTopic at right join cm_custom.dbo.LMW_Deploy_Data ldd
on at.assignmentid=ldd.assignmentid

  where ldd.DeploymentStateID/10000 in (302)
            ) s on s.AssignmentID=a.AssignmentID and s.StateType=a.DeploymentStateID/10000 and s.StateID = a.DeploymentStateID%10000
          left join cm_jnj.dbo.v_StateNames  sn on sn.TopicType=s.StateType and sn.StateID=isnull(s.StateID, 0)
          join cm_jnj.dbo.v_r_system  m on m.ResourceType=5 and m.ResourceID=s.ResourceID and isnull(m.Obsolete0,0)=0
left join cm_custom.dbo.LMW_Deploy_MaintW ldw on m.name0=ldw.Computer_Name
			join cm_jnj.dbo.v_UpdateScanStatus   uss  on (uss.ResourceID=m.ResourceID)
          left join cm_jnj.dbo.v_RA_System_SMSAssignedSites  asite on m.ResourceID = asite.ResourceID
          left join cm_jnj.dbo.v_AdvertisementStatusInformation  statusinfo on statusinfo.MessageID=nullif(s.LastStatusMessageID&0x0000FFFF, 0)
          --where a.Assignment_UniqueID in(select DeploymentID from LMW_Deploy_Data)
          order by m.Name0