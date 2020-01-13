/*
.SYNOPSIS
    Gets the update scan status for a MEMCM Collection.
.DESCRIPTION
    Gets the windows update scan status for a MEMCM Collection by Scan State.
.NOTES
    Requires SQL 2012 R2.
    Part of a report should not be run separately.
*/

/*##=============================================*/
/*## QUERY BODY                                  */
/*##=============================================*/
/* #region QueryBody */

/* Testing variables !! Need to be commented for Production !! */
-- DECLARE @UserSIDs     AS NVARCHAR(10)  = 'Disabled';
-- DECLARE @CollectionID AS NVARCHAR(10)  = 'SMS00001';

/* Variable declaration */
DECLARE @UpdateSearchID INT   = (
    SELECT TOP 1 UpdateSource.UpdateSource_ID
    FROM fn_rbac_SoftwareUpdateSource(@UserSIDs) AS UpdateSource
    WHERE IsPublishingEnabled = 1 -- Get only the UpdateSource_ID where publishing is enabled
)

/* Gets the device update scan states */
SELECT
    ResourceID                = Systems.ResourceID
    , ScanState               = ISNULL(StateNames.StateName, 'Unknown')
    , Device                  = IIF(Systems.Full_Domain_Name0 IS NOT NULL, Systems.Name0 + '.' + Systems.Full_Domain_Name0, Systems.Name0)
    , OperatingSystem         = (
        CASE
            WHEN OperatingSystem.Caption0 != '' THEN
                CONCAT(
                    REPLACE(OperatingSystem.Caption0, 'Microsoft ', ''),         -- Remove 'Microsoft ' from OperatingSystem
                    REPLACE(OperatingSystem.CSDVersion0, 'Service Pack ', ' SP') -- Replace 'Service Pack ' with ' SP' in OperatingSystem
                )
            ELSE (

            /* Workaround for systems not in GS_OPERATING_SYSTEM table */
                CASE
                    WHEN CombinedResources.DeviceOS LIKE '%Workstation 6.1%'    THEN 'Windows 7'
                    WHEN CombinedResources.DeviceOS LIKE '%Workstation 6.2%'    THEN 'Windows 8'
                    WHEN CombinedResources.DeviceOS LIKE '%Workstation 6.3%'    THEN 'Windows 8.1'
                    WHEN CombinedResources.DeviceOS LIKE '%Workstation 10.0%'   THEN 'Windows 10'
                    WHEN CombinedResources.DeviceOS LIKE '%Server 6.0'          THEN 'Windows Server 2008'
                    WHEN CombinedResources.DeviceOS LIKE '%Server 6.1'          THEN 'Windows Server 2008R2'
                    WHEN CombinedResources.DeviceOS LIKE '%Server 6.2'          THEN 'Windows Server 2012'
                    WHEN CombinedResources.DeviceOS LIKE '%Server 6.3'          THEN 'Windows Server 2012 R2'
                    WHEN Systems.Operating_System_Name_And0 LIKE '%Server 10%'  THEN (
                        CASE
                            WHEN CAST(REPLACE(Build01, '.', '') AS INTEGER) > 10017763 THEN 'Windows Server 2019'
                            ELSE 'Windows Server 2016'
                        END
                    )
                    ELSE Systems.Operating_System_Name_And0
                END
            )
        END
    )
    , ClientState             = (
        CASE CombinedResources.IsClient
            WHEN 1 THEN ClientSummary.ClientStateDescription
            ELSE 'Unmanaged'
        END
    )
    , ClientVersion           = Systems.Client_Version0
    , WUAVersion              = UpdateScan.LastWUAVersion
    , LastScanTime            = (
        CONVERT(NVARCHAR(16), UpdateScan.LastScanTime, 120)
    )
    , LastScanPackageLocation = NULLIF(UpdateScan.LastScanPackageLocation, '')
    , LastScanPackageVersion  = UpdateScan.LastScanPackageVersion
    , SyncCatalogVersion      = SyncSourceInfo.SyncCatalogVersion
    , CatalogVersionsBehind   = SyncSourceInfo.SyncCatalogVersion - UpdateScan.LastScanPackageVersion
    , LastScanError           = NULLIF(UpdateScan.LastErrorCode, 0)
FROM fn_rbac_FullCollectionMembership(@UserSIDs) AS CollectionMembers
    JOIN fn_rbac_R_System(@UserSIDs) AS Systems ON Systems.ResourceID = CollectionMembers.ResourceID
    LEFT JOIN fn_rbac_CombinedDeviceResources(@UserSIDs) AS CombinedResources ON CombinedResources.MachineID = Systems.ResourceID
    LEFT JOIN fn_rbac_GS_OPERATING_SYSTEM(@UserSIDs) AS OperatingSystem ON OperatingSystem.ResourceID = Systems.ResourceID
    LEFT JOIN fn_rbac_CH_ClientSummary(@UserSIDs) AS ClientSummary ON ClientSummary.ResourceID = Systems.ResourceID
    LEFT JOIN fn_rbac_UpdateScanStatus(@UserSIDs) AS UpdateScan ON UpdateScan.ResourceID = CollectionMembers.ResourceID
        AND (
            @UpdateSearchID = UpdateScan.UpdateSource_ID OR @UpdateSearchID IS NULL
        )
    LEFT JOIN fn_rbac_StateNames(@UserSIDs) AS StateNames ON StateNames.StateID = UpdateScan.LastScanState
        AND StateNames.TopicType       = 501 -- Update source scan summarization TopicTypeID
    CROSS APPLY (
        SELECT SUPSyncStatus.SyncCatalogVersion
        FROM vSMS_SUPSyncStatus AS SUPSyncStatus
        WHERE (
            SELECT SUBSTRING(
                UpdateScan.LastScanPackageLocation
                , CHARINDEX('/', UpdateScan.LastScanPackageLocation) + 2
                ,
                (
                    (
                        (LEN(UpdateScan.LastScanPackageLocation)) - CHARINDEX(':', REVERSE(UpdateScan.LastScanPackageLocation))
                    ) - CHARINDEX(':',UpdateScan.LastScanPackageLocation)
                ) - 2
            )
        ) = SUPSyncStatus.WSUSServerName
    ) AS SyncSourceInfo
WHERE CollectionMembers.CollectionID   = @CollectionID
    AND CollectionMembers.ResourceType = 5   -- Select devices only

/* #endregion */
/*##=============================================*/
/*## END QUERY BODY                              */
/*##=============================================*/