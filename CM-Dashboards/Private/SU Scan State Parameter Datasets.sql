
/* Gets state names */
SELECT
    StateID = -1
    , StateName = ''
UNION ALL
    SELECT
        StateID
        , StateName
    FROM fn_rbac_StateNames(@UserSIDs)
    WHERE TopicType = 501
    ORDER BY StateID

/* Gets site code and name */
SELECT
    SiteCode = ''
    , SiteName = '*'
UNION ALL
    SELECT
        SiteCode
        , SiteName = SiteCode + ' - ' + SiteName
    FROM fn_rbac_Site(@UserSIDs)
    ORDER BY SiteCode


          select sus.UpdateSource_UniqueID UpdateSourceID,
            sus.UpdateSourceName as UpdateSourceName
          from fn_rbac_SoftwareUpdateSource(@UserSIDs)  sus
          where sus.UpdateSourceName != 'WSUS Enterprise Server'
          or (sus.UpdateSourceName  = 'WSUS Enterprise Server' and IsPublishingEnabled =1)
          order by sus.UpdateSourceName
