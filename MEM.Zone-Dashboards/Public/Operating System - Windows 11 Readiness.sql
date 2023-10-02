/*
.SYNOPSIS
    Gets the windows 11 readiness.
.DESCRIPTION
    Gets the windows 11 readiness by checking multiple components.
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
--DECLARE @CollectionID             AS NVARCHAR(10)  = 'VIT007AF';
--DECLARE @CompatibleProcessorsList AS NVARCHAR(MAX) = '835;2600;2700;3100;3500;3600;3900;5800;5900;6305;6805;7252;7262;7272;7282;7302;7313;7343;7352;7402;7413;7443;7452;7453;7502;7513;7532;7542;7543;7552;7642;7643;7662;7663;7702;7713;7742;7763;2300X;2500X;2600E;2600X;2700E;2700X;2920X;2950X;2970WX;2990WX;3000G;300GE;300U;3015e;3020e;3200G;3200G with Radeon™ Vega 8 Graphics;3200GE;3200U;320GE;3250C;3250U;3300U;3350U;3400G;3400G with Radeon™ RX Vega 11 Graphics;3400GE;3450U;3500C;3500U;3550H;3580U Microsoft Surface® Edition;3600X;3600XT;3700C;3700U;3700X;3750H;3780U Microsoft Surface® Edition;3800X;3800XT;3867U;3900X;3900XT;3945WX;3950X;3955WX;3960X;3970X;3975WX;3990X;3995WX;4205U;4300G;4300GE;4300U;4305U;4305UE;4350G;4350GE;4450U;4500U;4600G;4600GE;4600H;4600U;4650G;4650GE;4650U;4700G;4700GE;4700U;4750G;4750GE;4750U;4800H;4800HS;4800U;4900H;4900HS;5205U;5300G;5300GE;5300U;5305U;5350G;5350GE;5400U;5450U;5500U;5600G;5600GE;5600H;5600HS;5600U;5600X;5650G;5650GE;5650U;5700G;5700GE;5700U;5750G;5750GE;5800H;5800HS;5800U;5800X;5850U;5900HS;5900HX;5900X;5950X;5980HS;5980HX;6305E;7232P;72F3;7302P;7313P;73F3;7402P;7443P;74F3;7502P;7543P;75F3;7702P;7713P;7F32;7F52;7F72;7H12;Bronze 3104;Bronze 3106;Bronze 3204;Bronze 3206R;E-2124;E-2124G;E-2126G;E-2134;E-2136;E-2144G;E-2146G;E-2174G;E-2176G;E-2176M;E-2186G;E-2186M;E-2224;E-2224G;E-2226G;E-2226GE;E-2234;E-2236;E-2244G;E-2246G;E-2254ME;E-2254ML;E-2274G;E-2276G;E-2276M;E-2276ME;E-2276ML;E-2278G;E-2278GE;E-2278GEL;E-2286G;E-2286M;E-2288G;G4900;G4900T;G4920;G4930;G4930E;G4930T;G4932E;G4950;G5900;G5900E;G5900T;G5900TE;G5905;G5905T;G5920;G5925;Gold 3150C;Gold 3150G;Gold 3150GE;Gold 3150U;Gold 4417U;Gold 4425Y;Gold 5115;Gold 5118;Gold 5119T;Gold 5120;Gold 5120T;Gold 5122;Gold 5215;Gold 5215L;Gold 5217;Gold 5218;Gold 5218B;Gold 5218N;Gold 5218R;Gold 5218T;Gold 5220;Gold 5220R;Gold 5220S;Gold 5220T;Gold 5222;Gold 5315Y;Gold 5317;Gold 5318N;Gold 5318S;Gold 5320;Gold 5320T;Gold 5405U;Gold 6126;Gold 6126F;Gold 6126T;Gold 6128;Gold 6130;Gold 6130F;Gold 6130T;Gold 6132;Gold 6134;Gold 6136;Gold 6138;Gold 6138F;Gold 6138P;Gold 6138T;Gold 6140;Gold 6142;Gold 6142F;Gold 6144;Gold 6146;Gold 6148;Gold 6148F;Gold 6150;Gold 6152;Gold 6154;Gold 6208U;Gold 6209U;Gold 6210U;Gold 6212U;Gold 6222V;Gold 6226;Gold 6226R;Gold 6230;Gold 6230N;Gold 6230R;Gold 6230T;Gold 6234;Gold 6238;Gold 6238L;Gold 6238R;Gold 6238T;Gold 6240;Gold 6240L;Gold 6240R;Gold 6240Y;Gold 6242;Gold 6242R;Gold 6244;Gold 6246;Gold 6246R;Gold 6248;Gold 6248R;Gold 6250;Gold 6250L;Gold 6252;Gold 6252N;Gold 6254;Gold 6256;Gold 6258R;Gold 6262V;Gold 6312U;Gold 6314U;Gold 6326;Gold 6330;Gold 6330N;Gold 6334;Gold 6336Y;Gold 6338;Gold 6338N;Gold 6338T;Gold 6342;Gold 6346;Gold 6348;Gold 6354;Gold 6405U;Gold 6500Y;Gold 7505;Gold G5400;Gold G5400T;Gold G5420;Gold G5420T;Gold G5500;Gold G5500T;Gold G5600;Gold G5600T;Gold G5620;Gold G6400;Gold G6400E;Gold G6400T;Gold G6400TE;Gold G6405;Gold G6405T;Gold G6500;Gold G6500T;Gold G6505;Gold G6505T;Gold G6600;Gold G6605;Gold Gold 5318Y;i3-1000G1;i3-1000G4;i3-1005G1;i3-10100;i3-10100E;i3-10100F;i3-10100T;i3-10100TE;i3-10100Y;i3-10105;i3-10105F;i3-10105T;i3-10110U;i3-10110Y;i3-10300;i3-10300T;i3-10305;i3-10305T;i3-10320;i3-10325;i3-1110G4;i3-1115G4;i3-1115G4E;i3-1115GRE;i3-1120G4;i3-1125G4;i3-8100;i3-8100B;i3-8100H;i3-8100T;i3-8109U;i3-8130U;i3-8140U;i3-8145U;i3-8145UE;i3-8300;i3-8300T;i3-8350K;i3-9100;i3-9100E;i3-9100F;i3-9100HL;i3-9100T;i3-9100TE;i3-9300;i3-9300T;i3-9320;i3-9350K;i3-9350KF;i3-L13G4;i5-10200H;i5-10210U;i5-10210Y;i5-10300H;i5-1030G4;i5-1030G7;i5-10310U;i5-10310Y;i5-1035G1;i5-1035G4;i5-1035G7;i5-1038NG7;i5-10400;i5-10400F;i5-10400H;i5-10400T;i5-10500;i5-10500E;i5-10500H;i5-10500T;i5-10500TE;i5-10505;i5-10600;i5-10600K;i5-10600KF;i5-10600T;i5-11260H;i5-11300H;i5-1130G7;i5-11320H;i5-1135G7;i5-11400;i5-11400F;i5-11400H;i5-11400T;i5-1140G7;i5-1145G7;i5-1145G7E;i5-1145GRE;i5-11500;i5-11500H;i5-11500T;i5-1155G7;i5-11600;i5-11600K;i5-11600KF;i5-11600T;i5-8200Y;i5-8210Y;i5-8250U;i5-8257U;i5-8259U;i5-8260U;i5-8265U;i5-8269U;i5-8279U;i5-8300H;i5-8305G;i5-8310Y;i5-8350U;i5-8365U;i5-8365UE;i5-8400;i5-8400B;i5-8400H;i5-8400T;i5-8500;i5-8500B;i5-8500T;i5-8600;i5-8600K;i5-8600T;i5-9300H;i5-9300HF;i5-9400;i5-9400F;i5-9400H;i5-9400T;i5-9500;i5-9500E;i5-9500F;i5-9500T;i5-9500TE;i5-9600;i5-9600K;i5-9600KF;i5-9600T;i5-L16G7;i7-10510U;i7-10510Y;i7-1060G7;i7-10610U;i7-1065G7;i7-1068NG7;i7-10700;i7-10700E;i7-10700F;i7-10700K;i7-10700KF;i7-10700T;i7-10700TE;i7-10710U;i7-10750H;i7-10810U;i7-10850H;i7-10870H;i7-10875H;i7-11370H;i7-11375H;i7-11390H;i7-11600H;i7-1160G7;i7-1165G7;i7-11700;i7-11700F;i7-11700K;i7-11700KF;i7-11700T;i7-11800H;i7-1180G7;i7-11850H;i7-1185G7;i7-1185G7E;i7-1185GRE;i7-1195G7;i7-7800X;i7-7820HQ[1];i7-7820X;i7-8086K;i7-8500Y;i7-8550U;i7-8557U;i7-8559U;i7-8565U;i7-8569U;i7-8650U;i7-8665U;i7-8665UE;i7-8700;i7-8700B;i7-8700K;i7-8700T;i7-8705G;i7-8706G;i7-8709G;i7-8750H;i7-8809G;i7-8850H;i7-9700;i7-9700E;i7-9700F;i7-9700K;i7-9700KF;i7-9700T;i7-9700TE;i7-9750H;i7-9750HF;i7-9800X;i7-9850H;i7-9850HE;i7-9850HL;i9-10850K;i9-10885H;i9-10900;i9-10900E;i9-10900F;i9-10900K;i9-10900KF;i9-10900T;i9-10900TE;i9-10900X;i9-10920X;i9-10940X;i9-10980HK;i9-10980XE;i9-11900;i9-11900F;i9-11900H;i9-11900K;i9-11900KF;i9-11900T;i9-11950H;i9-11980HK;i9-7900X;i9-7920X;i9-7940X;i9-7960X;i9-7980XE;i9-8950HK;i9-9820X;i9-9880H;i9-9900;i9-9900K;i9-9900KF;i9-9900KS;i9-9900T;i9-9900X;i9-9920X;i9-9940X;i9-9960X;i9-9980HK;i9-9980XE;J4005;J4025;J4105;J4115;J4125;J6412;J6413;J6426;m3-8100Y;N4000;N4020;N4100;N4120;N4500;N4505;N5100;N5105;N6210;N6211;N6415;Platinum 8153;Platinum 8156;Platinum 8158;Platinum 8160;Platinum 8160F;Platinum 8160T;Platinum 8164;Platinum 8168;Platinum 8170;Platinum 8176;Platinum 8176F;Platinum 8180;Platinum 8253;Platinum 8256;Platinum 8260;Platinum 8260L;Platinum 8260Y;Platinum 8268;Platinum 8270;Platinum 8276;Platinum 8276L;Platinum 8280;Platinum 8280L;Platinum 8351N;Platinum 8352M;Platinum 8352S;Platinum 8352V;Platinum 8352Y;Platinum 8358;Platinum 8358P;Platinum 8360Y;Platinum 8362;Platinum 8368;Platinum 8368Q;Platinum 8380;Platinum 9221;Platinum 9222;Platinum 9242;Platinum 9282;Silver 3050C;Silver 3050e;Silver 3050GE;Silver 3050U;Silver 4108;Silver 4109T;Silver 4110;Silver 4112;Silver 4114;Silver 4114T;Silver 4116;Silver 4116T;Silver 4208;Silver 4209T;Silver 4210;Silver 4210R;Silver 4210T;Silver 4214;Silver 4214R;Silver 4214Y;Silver 4215;Silver 4215R;Silver 4216;Silver 4309Y;Silver 4310;Silver 4310T;Silver 4314;Silver 4316;Silver J5005;Silver J5040;Silver N5000;Silver N5030;Silver N6000;Silver N6005;W-10855M;W-10885M;W-11855M;W-11955M;W-1250;W-1250E;W-1250P;W-1250TE;W-1270;W-1270E;W-1270P;W-1270TE;W-1290;W-1290E;W-1290P;W-1290T;W-1290TE;W-2102;W-2104;W-2123;W-2125;W-2133;W-2135;W-2145;W-2155;W-2175;W-2195;W-2223;W-2225;W-2235;W-2245;W-2255;W-2265;W-2275;W-2295;W-3175X;W-3223;W-3225;W-3235;W-3245;W-3245M;W-3265;W-3265M;W-3275;W-3275M;x6200FE;x6211E;x6212RE;x6413E;x6414RE;x6425E;x6425RE;x6427FE;Snapdragon 850;Snapdragon 7c;Snapdragon 8c;Snapdragon 8cx;Snapdragon 8cx (Gen2);Microsoft SQ1;Microsoft SQ2';
--DECLARE @Thresholds               AS NVARCHAR(20)  = '4,1000,2,64';

/* Initialize memory tables */
DECLARE @CompatibleProcessors TABLE (ProcessorName NVARCHAR(250));
DECLARE @ReadinessStates      TABLE (BitMask INT, StateName NVARCHAR(250));
DECLARE @ThresholdVariables   TABLE (ID INT IDENTITY(1,1), Threshold INT);

/* Populate CompatibleProcessors table */
INSERT INTO @CompatibleProcessors (ProcessorName)
    SELECT VALUE FROM STRING_SPLIT(@CompatibleProcessorsList, ';');

/* Populate ReadinessStates table */
INSERT INTO @ReadinessStates (BitMask, StateName)
VALUES
    (0,      N'Ready')
    , (1,    N'Unknown')
    , (2,    N'Processor Type')
    , (4,    N'Processor Cores')
    , (8,    N'Processor Speed')
    , (16,   N'Memory')
    , (32,   N'UEFI')
    , (64,   N'Secure Boot')
    , (128,  N'TPM Version')
    , (256,  N'TPM Enabled')
    , (512,  N'TPM Activated')
    , (1024, N'TPM Owned')
    , (2048, N'Free Space')

/* Populate @ThresholdVariables table */
INSERT INTO @ThresholdVariables (Threshold)
SELECT VALUE FROM STRING_SPLIT(@Thresholds, N',')

/* Set Threshold variables */
DECLARE @HT_Memory         AS INT = (SELECT Threshold FROM @ThresholdVariables WHERE ID = 1); -- GB
DECLARE @HT_ProcessorSpeed AS INT = (SELECT Threshold FROM @ThresholdVariables WHERE ID = 2); -- Ghz
DECLARE @HT_ProcessorCores AS INT = (SELECT Threshold FROM @ThresholdVariables WHERE ID = 3); -- No
DECLARE @HT_FreeSpace      AS INT = (SELECT Threshold FROM @ThresholdVariables WHERE ID = 4); -- GB

/* Get compliance data data */
;
WITH Processor_CTE
AS (
    SELECT DISTINCT
        ResourceID                = Processor.ResourceID
        , Compatible              = IIF(Processors.ProcessorName IS NULL, 0, 1)
    FROM fn_rbac_GS_PROCESSOR(@UserSIDs) AS Processor
        INNER JOIN fn_rbac_FullCollectionMembership(@UserSIDs) AS CollectionMembers ON CollectionMembers.ResourceID = Processor.ResourceID
        LEFT JOIN @CompatibleProcessors AS Processors ON Processor.Name0 LIKE '%' + Processors.ProcessorName + '%'
    WHERE CollectionMembers.CollectionID = @CollectionID
)
SELECT
    ResourceID = Systems.ResourceID
    , ReadinessStates           = (
        -- Unknown
        IIF(
            ProcessorCTE.Compatible IS NULL
            , POWER(1, 1),
            -- Processor Type: Supported Processor
            IIF(
                ProcessorCTE.Compatible = 0
                , POWER(2, 1), 0
            )
            -- Processor Cores: At least two cores
            +
            IIF(
                Processor.NumberOfCores0 < @HT_ProcessorCores
                , POWER(4, 1), 0
            )
            -- Processor Speed: At least 1000 Ghz
            +
            IIF(
                Processor.NormSpeed0 < @HT_ProcessorSpeed
                , POWER(8, 1), 0
            )
            -- Memory: At least 4 GB
            +
            IIF(
                Memory.Size < @HT_Memory
                , POWER(16, 1), 0
            )
            -- Boot Mode: UEFI
            +
            IIF(
                Firmware.UEFI0 = 0
                , POWER(32, 1), 0
            )
            -- Secure Boot: On
            +
            IIF(
                Firmware.SecureBoot0 = 0
                , POWER(64, 1), 0
            )
            -- TPM Version: 2.0
            +
            IIF(
                IIF(TPM.SpecVersion0 = N'Not Supported', N'Not Supported', LEFT(TPM.SpecVersion0, CHARINDEX(',',TPM.SpecVersion0 )-1)) != N'2.0'
                , POWER(128, 1), 0
            )
            -- TPM Enabled: True
            +
            IIF(
                TPM.IsEnabled_InitialValue0 != 1
                , POWER(256, 1), 0
            )
            -- TPM Activated: True
            +
            IIF(
                TPM.IsActivated_InitialValue0 != 1
                , POWER(512, 1), 0
            )
            -- TPM Owned: True
            +
            IIF(
                TPM.IsOwned_InitialValue0 != 1
                , POWER(1024, 1), 0
            )
            -- Free Space: At least 64 GB
            +
            IIF(
                ISNULL(LogicalDisk.FreeSpace0, -1) != -1 AND CONVERT(DECIMAL(10, 2), LogicalDisk.FreeSpace0 / 1024.0) < @HT_FreeSpace
                , POWER(2048, 1), 0
            )
        )
    )
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
    , CompatibleProcessor     = IIF(
        ProcessorCTE.Compatible IS NULL
        , 2 --'Unknown'
        , ProcessorCTE.Compatible
    )
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
    , TPMPhysicalPresence     = TPM.PhysicalPresenceVersionInfo0
    , TPMSpecVersion          = TPM.SpecVersion0
*/
    , Domain			      = Systems.User_Domain0
    , UserName		          = Systems.User_Name0
    , Country                 = Users.co
    , Location                = Users.l
    , ClientState             = IIF(Systems.Client0 = 1, ClientSummary.ClientStateDescription, 'Unmanaged')
    , ClientVersion           = Systems.Client_Version0
FROM fn_rbac_R_System(@UserSIDs) AS Systems
    INNER JOIN fn_rbac_FullCollectionMembership(@UserSIDs) AS CollectionMembers ON CollectionMembers.ResourceID = Systems.ResourceID
    LEFT JOIN fn_rbac_GS_PROCESSOR(@UserSIDs) AS Processor ON Processor.ResourceID = CollectionMembers.ResourceID
    LEFT JOIN Processor_CTE AS ProcessorCTE ON ProcessorCTE.ResourceID = CollectionMembers.ResourceID
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
    LEFT JOIN fn_rbac_R_User(@UserSIDs) AS Users ON Users.User_Name0 = Systems.User_Name0
        AND Users.Windows_NT_Domain0 = Systems.Resource_Domain_OR_Workgr0 --Select only users from the machine domain
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

/* #endregion */
/*##=============================================*/
/*## END QUERY BODY                              */
/*##=============================================*/