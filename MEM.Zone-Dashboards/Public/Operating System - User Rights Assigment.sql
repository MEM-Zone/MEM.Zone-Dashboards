/*
.SYNOPSIS
    Gets the operating system user rights assigment.
.DESCRIPTION
    Gets the operating system user rights assigment in Configuration Manager by Collection
.NOTES
    Requires SQL 2016.
    Part of a report should not be run separately
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
--DECLARE @UserSIDs     AS NVARCHAR(10) = 'Disabled';
--DECLARE @CollectionID AS NVARCHAR(10) = 'VID00426';
--DECLARE @Privileges   AS BIGINT       = 38654705676;

/* Check for Hwi Extension */
DECLARE @IsHwiExtended   AS INT = 0;
IF OBJECT_ID(N'[dbo].[fn_rbac_GS_USER_RIGHTS_ASSIGNMENT]') IS NOT NULL
    SET @IsHwiExtended = 1;

/* Compute Bitmask from multi-selection dropdown */
DECLARE @PrivilegeBitMask AS BIGINT = (
    SELECT SUM(CAST(Value AS BIGINT)) FROM STRING_SPLIT(
        (SELECT CONCAT_WS(N',', N'0', @Privileges))
        , N','
    )
);

/* Initialize UserPrivileges table */
DECLARE @UserPrivilegeFlags TABLE (BitMask BIGINT, Privilege NVARCHAR(50));

/* Populate UserPrivileges table */
INSERT INTO @UserPrivilegeFlags (BitMask, Privilege)
VALUES
    (0,                N'None')
    , (1,              N'SeAssignPrimaryTokenPrivilege')
    , (2,              N'SeAuditPrivilege')
    , (4,              N'SeBackupPrivilege')
    , (8,              N'SeBatchLogonRight')
    , (16,             N'SeChangeNotifyPrivilege')
    , (32,             N'SeCreateGlobalPrivilege')
    , (64,             N'SeCreatePagefilePrivilege')
    , (128,            N'SeCreatePermanentPrivilege')
    , (256,            N'SeCreateSymbolicLinkPrivilege')
    , (512,            N'SeCreateTokenPrivilege')
    , (1024,           N'SeDebugPrivilege')
    , (2048,           N'SeDelegateSessionUserImpersonatePrivilege')
    , (4096,           N'SeDenyBatchLogonRight')
    , (8192,           N'SeDenyInteractiveLogonRight')
    , (16384,          N'SeDenyNetworkLogonRight')
    , (32768,          N'SeDenyRemoteInteractiveLogonRight')
    , (65536,          N'SeDenyServiceLogonRight')
    , (131072,         N'SeEnableDelegationPrivilege')
    , (262144,         N'SeImpersonatePrivilege')
    , (524288,         N'SeIncreaseBasePriorityPrivilege')
    , (1048576,        N'SeIncreaseQuotaPrivilege')
    , (2097152,        N'SeIncreaseWorkingSetPrivilege')
    , (4194304,        N'SeInteractiveLogonRight')
    , (8388608,        N'SeLoadDriverPrivilege')
    , (16777216,       N'SeLockMemoryPrivilege')
    , (33554432,       N'SeMachineAccountPrivilege')
    , (67108864,       N'SeManageVolumePrivilege')
    , (134217728,      N'SeNetworkLogonRight')
    , (268435456,      N'SeProfileSingleProcessPrivilege')
    , (536870912,      N'SeRelabelPrivilege')
    , (1073741824,     N'SeRemoteInteractiveLogonRight')
    , (2147483648,     N'SeRemoteShutdownPrivilege')
    , (4294967296,     N'SeRestorePrivilege')
    , (8589934592,     N'SeSecurityPrivilege')
    , (17179869184,    N'SeServiceLogonRight')
    , (34359738368,    N'SeShutdownPrivilege')
    , (68719476736,    N'SeSyncAgentPrivilege')
    , (137438953472,   N'SeSystemEnvironmentPrivilege')
    , (274877906944,   N'SeSystemProfilePrivilege')
    , (549755813888,   N'SeSystemtimePrivilege')
    , (1099511627776,  N'SeTakeOwnershipPrivilege')
    , (2199023255552,  N'SeTcbPrivilege')
    , (4398046511104,  N'SeTimeZonePrivilege')
    , (8796093022208,  N'SeTrustedCredManAccessPrivilege')
    , (17592186044416, N'SeUndockPrivilege')

/* Get device info */
IF @IsHwiExtended = 1
    BEGIN
        SELECT
            DeviceName        = (
                IIF(
                    SystemNames.Resource_Names0 IS NOT NULL, UPPER(SystemNames.Resource_Names0)
                    , IIF(Systems.Full_Domain_Name0 IS NOT NULL, Systems.Name0 + N'.' + Systems.Full_Domain_Name0, Systems.Name0)
                )
            )
            , OperatingSystem = (
                IIF(
                    OperatingSystem.Caption0 != N''
                    , CONCAT(
                        REPLACE(OperatingSystem.Caption0, N'Microsoft ', N''),         --Remove 'Microsoft ' from OperatingSystem
                        REPLACE(OperatingSystem.CSDVersion0, N'Service Pack ', N' SP') --Replace 'Service Pack ' with ' SP' in OperatingSystem
                    )
                    , Systems.Operating_System_Name_And0
                )
            )
            , Domain          = Systems.Resource_Domain_OR_Workgr0
            , PrincipalName   = UserRightsAssignment.PrincipalName0
            , PrincipalSID    = UserRightsAssignment.PrincipalSID0
            , Privilege       = (
                STUFF(
                    REPLACE(
                        (
                            SELECT N'#!' + LTRIM(RTRIM(UserPrivilegeFlags.Privilege)) AS [data()]
                            FROM @UserPrivilegeFlags AS UserPrivilegeFlags
                            WHERE UserPrivilegeFlags.BitMask & CAST(UserRightsAssignment.PrivilegeBitMask0 AS BIGINT) <> 0
                            FOR XML PATH(N'')
                        ),
                        N' #!', N', '
                    ),
                    1, 2, N''
                )
            )
            , LastCollected   = CONVERT(NVARCHAR(16), UserRightsAssignment.TimeStamp, 120)
        FROM fn_rbac_FullCollectionMembership(@UserSIDs) AS CollectionMembers
            LEFT OUTER JOIN fn_rbac_GS_USER_RIGHTS_ASSIGNMENT(@UserSIDs) AS UserRightsAssignment ON UserRightsAssignment.ResourceID = CollectionMembers.ResourceID
            LEFT OUTER JOIN fn_rbac_RA_System_ResourceNames(@UserSIDs) AS SystemNames ON SystemNames.ResourceID = CollectionMembers.ResourceID
            LEFT OUTER JOIN fn_rbac_GS_OPERATING_SYSTEM(@UserSIDs) AS OperatingSystem ON OperatingSystem.ResourceID = CollectionMembers.ResourceID
            LEFT OUTER JOIN fn_rbac_R_System(@UserSIDs) AS Systems ON Systems.ResourceID = CollectionMembers.ResourceID
        WHERE CollectionMembers.CollectionID = @CollectionID
            AND (@PrivilegeBitMask & CAST(UserRightsAssignment.PrivilegeBitMask0 AS BIGINT) <> 0 OR UserRightsAssignment.PrivilegeBitMask0 IS NULL)
    END

/* #endregion */
/*##=============================================*/
/*## END QUERY BODY                              */
/*##=============================================*/