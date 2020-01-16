
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

/* Gets WUA Scan state names */
SELECT
    StateID
    , StateName
FROM fn_rbac_StateNames(@UserSIDs) AS StateNames
WHERE StateNames.TopicType = 501
ORDER BY StateName