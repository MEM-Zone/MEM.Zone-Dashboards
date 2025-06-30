/*
.SYNOPSIS
    Gets the Device Hardware info.
.DESCRIPTION
    Gets the Device Hardware info of a device collection.
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
--DECLARE @UserSIDs                 AS NVARCHAR(10)  = 'Disabled';
--DECLARE @CollectionID             AS NVARCHAR(10)  = 'SMS0001';
--DECLARE @Thresholds               AS NVARCHAR(20)  = '14,14';
--DECLARE @ExcludeVirtualMachines   AS VARCHAR(3)    = 'YES'

/* Initialize memory tables */
DECLARE @VirtualMachines      TABLE (Model  NVARCHAR(50));
DECLARE @ReadinessStates      TABLE (BitMask INT, StateName NVARCHAR(250));
DECLARE @ThresholdVariables   TABLE (ID INT IDENTITY(1,1), Threshold INT);

/* Populate VirtualMachines table */
INSERT INTO @VirtualMachines (Model)
VALUES
    ('VMware Virtual Platform')
    , ('Virtual Machine')
	, ('VMware7,1')

/* Get compliance data data */
SELECT
    ResourceID = Systems.ResourceID
    , Device                  = (
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
    , OSVersion               = ISNULL(OSInfo.Version, IIF(RIGHT(OperatingSystem.Caption0, 7) = N'Preview', N'Insider Preview', NULL))
    , ProcessorName           = (
        CASE
            WHEN CHARINDEX('CPU @', Processor.Name0) > 0 THEN LEFT(Processor.Name0, CHARINDEX('CPU @', Processor.Name0)-1)
            WHEN CHARINDEX('@', Processor.Name0) > 0 THEN LEFT(Processor.Name0, CHARINDEX('@', Processor.Name0)-1)
            ELSE Processor.Name0
        END
    )
    , ProcessorSpeed          = Processor.NormSpeed0
    , ProcessorCores          = Processor.NumberOfCores0
    , MemorySize              = Memory.Size
    , FreeSpace               = CONVERT(DECIMAL(10, 2), LogicalDisk.FreeSpace0 / 1024.0)
    , Manufacturer            = ComputerSystem.Manufacturer0
    , DeviceModel             = ComputerSystem.Model0
    , SerialNumber            = BIOS.SerialNumber0
    , SecureBoot              = (
        CASE
            WHEN Firmware.SecureBoot0 = 1 THEN N'Enabled'
            WHEN Firmware.SecureBoot0 = 0 THEN N'Disabled'
            ELSE NULL
        END
    )
    , BootMode                = (
        CASE
            WHEN Firmware.UEFI0 = 1 THEN N'UEFI'
            WHEN Firmware.UEFI0 = 0 THEN N'BIOS'
            ELSE NULL
        END
    )
    , TPMVersion              = IIF(TPM.SpecVersion0 = 'Not Supported', 'Not Supported', LEFT(TPM.SpecVersion0, CHARINDEX(',',TPM.SpecVersion0 )-1))
/*
    , TPMEnabled              = (
        CASE
            WHEN TPM.IsEnabled_InitialValue0 = 1 THEN N'Enabled'
            WHEN TPM.IsEnabled_InitialValue0 = 0 THEN N'Disabled'
            ELSE NULL
        END
    )
    , TPMActivated            = (
        CASE
            WHEN TPM.IsActivated_InitialValue0 = 1 THEN N'Yes'
            WHEN TPM.IsActivated_InitialValue0 = 0 THEN N'No'
            ELSE NULL
        END
    )
    , TPMOwned                = (
        CASE
            WHEN TPM.IsOwned_InitialValue0 = 1 THEN N'Yes'
            WHEN TPM.IsOwned_InitialValue0 = 0 THEN N'No'
            ELSE NULL
        END
    )
*/
    , TPMPhysicalPresence     = TPM.PhysicalPresenceVersionInfo0
    , TPMSpecVersion          = TPM.SpecVersion0
    , Domain			      = Systems.User_Domain0
    , UserName		          = Systems.User_Name0
    , ClientState             = IIF(Systems.Client0 = 1, ClientSummary.ClientStateDescription, 'Unmanaged')
    , ClientVersion           = Systems.Client_Version0
	, ComputerSystem.Model0
FROM fn_rbac_R_System(@UserSIDs) AS Systems
    INNER JOIN fn_rbac_FullCollectionMembership(@UserSIDs) AS CollectionMembers ON CollectionMembers.ResourceID = Systems.ResourceID
    LEFT JOIN fn_rbac_GS_PROCESSOR(@UserSIDs) AS Processor ON Processor.ResourceID = CollectionMembers.ResourceID
    LEFT JOIN fn_rbac_RA_System_ResourceNames(@UserSIDs) AS SystemNames ON SystemNames.ResourceID = CollectionMembers.ResourceID
    LEFT JOIN fn_rbac_GS_OPERATING_SYSTEM(@UserSIDs) AS OperatingSystem ON OperatingSystem.ResourceID = CollectionMembers.ResourceID
    LEFT JOIN fn_rbac_GS_COMPUTER_SYSTEM(@UserSIDs) AS ComputerSystem ON ComputerSystem.ResourceID = CollectionMembers.ResourceID
    LEFT JOIN fn_rbac_GS_PC_BIOS(@UserSIDs) AS BIOS ON BIOS.ResourceID = CollectionMembers.ResourceID
    LEFT JOIN fn_rbac_GS_FIRMWARE(@UserSIDs) AS Firmware ON Firmware.ResourceID = CollectionMembers.ResourceID
    LEFT JOIN fn_rbac_GS_TPM(@UserSIDs) AS TPM ON TPM.ResourceID = CollectionMembers.ResourceID
    LEFT JOIN fn_rbac_GS_LOGICAL_DISK(@UserSIDs) AS LogicalDisk ON LogicalDisk.ResourceID = CollectionMembers.ResourceID
        AND LogicalDisk.DriveType0 = 3     --Local Disk
        AND LogicalDisk.Name0      = N'C:' --System Drive Only
    LEFT JOIN fn_rbac_CH_ClientSummary(@UserSIDs) AS ClientSummary ON ClientSummary.ResourceID = CollectionMembers.ResourceID
    OUTER APPLY (
        SELECT
            Version = OSLocalizedNames.Value
            , ServicingState = OSServicingStates.State
        FROM fn_GetWindowsServicingLocalizedNames() AS OSLocalizedNames
            INNER JOIN fn_GetWindowsServicingStates() AS OSServicingStates ON OSServicingStates.Build = Systems.Build01
        WHERE OSLocalizedNames.Name = OSServicingStates.Name
            AND Systems.OSBranch01 = OSServicingStates.Branch --Select only the branch of the installed OS
        ) AS OSInfo
    OUTER APPLY (
        SELECT DISTINCT
            Size = SUM(Memory.Capacity0) OVER(PARTITION BY Memory.ResourceID) / 1000
        FROM v_GS_PHYSICAL_MEMORY AS Memory
        WHERE Memory.ResourceID = CollectionMembers.ResourceID
    ) AS Memory
WHERE CollectionMembers.CollectionID = @CollectionID
	AND ComputerSystem.Model0 NOT IN (SELECT Model FROM @VirtualMachines)

/* #endregion */
/*##=============================================*/
/*## END QUERY BODY                              */
/*##=============================================*/