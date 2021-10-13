/*
.SYNOPSIS
    Gets the Bitlocker (MBAM) compliance.
.DESCRIPTION
    Gets the Bitlocker (MBAM) compliance for a Collection in MEMCM.
.NOTES
    Requires SQL 2016.
    Part of a report should not be run separately.
.LINK
    https://MEM.Zone/Dashboards
.LINK
    https://MEM.Zone/Dashboards-HELP
.LINK
    https://MEM.Zone/Dashboards-ISSUES
*/

/*##=============================================*/
/*## QUERY BODY                                  */
/*##=============================================*/
/* #region QueryBody */

/* Testing variables !! Need to be commented for Production !! */
--DECLARE @UserSIDs           AS NVARCHAR(10) = 'Disabled';
--DECLARE @CollectionID       AS NVARCHAR(10) = 'VIT00984';
--DECLARE @VolumeTypes        AS INT          = 1;
--DECLARE @Locale             AS INT          = 2;

/* Perform cleanup */
IF OBJECT_ID(N'tempdb..#BitlockerResult', N'U') IS NOT NULL
    DROP TABLE #BitlockerResult;

/* Variable declaration */
DECLARE @Noncompliant       AS INT          = 0;
DECLARE @Compliant          AS INT          = 1;
DECLARE @NotApplicable      AS INT          = 2;


/* Initialize memory tables */
DECLARE @ComplianceStates        TABLE(BitMask INT, StateName NVARCHAR(250));
DECLARE @ReasonsForNonCompliance TABLE(BitMask INT, StateName NVARCHAR(250));

/* Populate ReasonsForNonCompliance table */
INSERT INTO @ReasonsForNonCompliance (BitMask, StateName)
VALUES
    (0,       N'N/A')
    , (1,     N'Cypher strength not AES 256')
    , (2,     N'Volume encrypted')
    , (4,     N'Volume decrypted')
    , (8,     N'TPM protector required')
    , (16,    N'No TPM+PIN protectors required')
    , (32,    N'Non-TPM reports as compliant')
    , (64,    N'TPM is not visible')
    , (128,   N'Password protector required')
    , (256,   N'Password protector not required')
    , (512,   N'Auto-unlock protector required')
    , (1024,  N'Auto-unlock protector not required')
    , (2048,  N'Policy conflict detected')
    , (4096,  N'System volume is needed for encryption')
    , (8192,  N'Protection is suspended')
    , (16384, N'AutoUnlock unsafe unless the OS volume is encrypted')
    , (32768, N'Minimum cypher strength XTS-AES-128 bit required')
    , (65536, N'Minimum cypher strength XTS-AES-256 bit required')

/* Populate ComplianceStates table */
INSERT INTO @ComplianceStates (BitMask, StateName)
VALUES
    (0,     N'Compliant')
    , (1,   N'Unprotected')
    , (2,   N'Partially Protected')
    , (4,   N'Bitlocker Exemption')
    , (8,   N'OS Drive Noncompliant')
    , (16,  N'Data Drive Noncompliant')
    , (32,  N'Encryption in Progress')
    , (64,  N'Decryption in Progress')
    , (128, N'Encryption Paused')
    , (256, N'Decryption Paused')
    , (512, N'Policy not Evaluated')

/* Get compliance data data */
;
WITH Bitlocker_CTE AS (
SELECT
    ResourceID                = Systems.ResourceID
    , EncodedDeviceName       = MBAMPolicy.EncodedComputerName0
    , Domain                  = LOWER(Systems.Full_Domain_Name0)
    , UserName                = SystemValid.User_Domain0 + N'\' + SystemValid.User_Name0
    , Compliant               = BitlockerDetails.Compliant0
    , Exemption               = ( --ComplianceState: 0 = 'N/A', 1 = 'Compliant', 2 = 'NonCompliant'
        CASE
            WHEN MBAMPolicy.MBAMPolicyEnforced0 IS NULL                                             THEN -1 -- When outer join returns null: N/A
            WHEN BitlockerDetails.Compliant0 = @Noncompliant AND MBAMPolicy.MBAMPolicyEnforced0 = 3 THEN 1  -- Temporary user exempt
            WHEN BitlockerDetails.Compliant0 = @Compliant    AND MBAMPolicy.MBAMPolicyEnforced0 = 2 THEN 2  -- User exempt
            ELSE 0 -- Not Exempted
        END
    )
    , VolumeName              = BitlockerDetails.DriveLetter0
    , ComplianceStatus        = BitlockerDetails.Compliant0
    , VolumeType              = BitlockerDetails.MbamVolumeType0
    , ProtectionStatus        = BitlockerDetails.ProtectionStatus0
    , EncryptionStatus        = BitlockerDetails.ConversionStatus0
    , EncryptionMethod        = BitlockerDetails.EncryptionMethod0
    , ComplianceStatusDetails = ( --ComplianceState: 0 = 'N/A', 1 = 'Compliant', 2 = 'NonCompliant'
        CASE
            WHEN BitlockerDetails.Compliant0 = @Compliant    AND MBAMPolicy.MBAMPolicyEnforced0           = 0 THEN 50                           -- Policy not enforced
            WHEN BitlockerDetails.Compliant0 = @Compliant    AND MBAMPolicy.MBAMPolicyEnforced0           = 1 THEN 0                            -- No Error
            WHEN BitlockerDetails.Compliant0 = @Noncompliant AND MBAMPolicy.MBAMMachineError0 IS NOT NULL     THEN MBAMPolicy.MBAMMachineError0 -- MBAM agent error status
            ELSE -1 -- No Details or Errors
        END
    )
    , ReasonsForNonCompliance = IIF(CHARINDEX(N'1,', BitlockerDetails.ReasonsForNonCompliance0) > 0, N'1', BitlockerDetails.ReasonsForNonCompliance0)
    , LastPolicyEvaluation    = CONVERT(NVARCHAR(19), MAX(BitlockerDetails.TimeStamp), 120)
    , LastHWIScan             = CONVERT(NVARCHAR(19), MAX(WorkstationStatus.LastHWScan), 120)
    , DiskVolumes             = (
            DENSE_RANK() OVER(PARTITION BY MBAMPolicy.EncodedComputerName0 ORDER BY BitlockerDetails.MbamPersistentVolumeId0)
            +
            DENSE_RANK() OVER(PARTITION BY MBAMPolicy.EncodedComputerName0 ORDER BY BitlockerDetails.MbamPersistentVolumeId0 DESC)
            - 1
    )
    , ProtectedVolumes        = (
            COUNT(IIF(BitlockerDetails.ProtectionStatus0 = 1, N'*', NULL)) OVER(PARTITION BY MBAMPolicy.EncodedComputerName0)
    )
FROM fn_rbac_ClientCollectionMembers(@UserSIDs) AS ClientCollectionMembers
    INNER JOIN fn_rbac_R_System_Valid(@UserSIDs) AS SystemValid ON SystemValid.ResourceID = ClientCollectionMembers.ResourceID
    INNER JOIN fn_rbac_R_System(@UserSIDs) AS Systems ON Systems.ResourceID = SystemValid.ResourceID
    INNER JOIN fn_rbac_GS_MBAM_POLICY(@UserSIDs) AS MBAMPolicy ON MBAMPolicy.ResourceID = SystemValid.ResourceID
        AND MBAMPolicy.EncodedComputerName0 IS NOT NULL
    INNER JOIN fn_rbac_GS_BITLOCKER_DETAILS(@UserSIDs) AS BitlockerDetails ON BitlockerDetails.ResourceID = SystemValid.ResourceID
        AND BitlockerDetails.MbamVolumeType0 IN (@VolumeTypes)      -- 1 = OS, 2 = Fixed Data Volumes
    LEFT OUTER JOIN fn_rbac_GS_WORKSTATION_STATUS(@UserSIDs) AS WorkstationStatus ON WorkstationStatus.ResourceID = SystemValid.ResourceID
WHERE ClientCollectionMembers.CollectionID = @CollectionID
GROUP BY
    Systems.ResourceID
    , MBAMPolicy.EncodedComputerName0
    , BitlockerDetails.Compliant0
    , BitlockerDetails.MbamVolumeType0
    , BitlockerDetails.DriveLetter0
    , BitlockerDetails.EncryptionMethod0
    , BitlockerDetails.ConversionStatus0
    , BitlockerDetails.ReasonsForNonCompliance0
    , WorkstationStatus.LastHWScan
    , SystemValid.User_Name0
    , SystemValid.User_Domain0
    , Systems.Full_Domain_Name0
    , BitlockerDetails.ProtectionStatus0
    , BitlockerDetails.MbamPersistentVolumeId0
    , MBAMPolicy.MBAMPolicyEnforced0
    , MBAMMachineError0
)

SELECT
    ResourceID
    , Compliant
    , ComplianceStates        = (
        -- Policy not Evaluated
        IIF(
            ISNULL(ComplianceStatusDetails, 50) = 50
            , POWER(512, 1),
            -- Unprotected
            IIF(
                ProtectedVolumes = 0
                , POWER(1, 1), 0
            )
            -- Partially Protected
            +
            IIF(
                ISNULL(ProtectedVolumes, 0) != 0 AND ProtectedVolumes < DiskVolumes
                , POWER(2, 1), 0
            )
            -- Bitlocker Exemption
            +
            IIF(
                ISNULL(Exemption, 0) != 0
                , POWER(4, 1), 0
            )
            -- OS Drive Noncompliant
            +
            IIF(
                VolumeType = 1 AND ComplianceStatus = 0 AND ISNULL(ProtectedVolumes, 0) != 0
                , POWER(8, 1), 0
            )
            -- Data Drive Noncompliant
            +
            IIF(
                VolumeType = 2 AND ComplianceStatus = 0 AND ISNULL(ProtectedVolumes, 0) != 0
                , POWER(16, 1), 0
            )
            -- Encryption in Progress
            +
            IIF(
                EncryptionStatus = 2
                , POWER(32, 1), 0
            )
            -- Decryption in Progress
            +
            IIF(
                EncryptionStatus = 3
                , POWER(64, 1), 0
            )
            -- Encryption Paused
            +
            IIF(
                EncryptionStatus = 4
                , POWER(128, 1), 0
            )
            -- Decryption Paused
            +
            IIF(
                EncryptionStatus = 5
                , POWER(256, 1), 0
            )
        )
    )
    , EncodedDeviceName
    , Domain
    , UserName
    , Protected               = (
        IIF(
            ProtectedVolumes = DiskVolumes
            , N'Yes', IIF(ProtectedVolumes = 0, N'No', N'Partial')
        )
    )
    , Exemption
    , VolumeName
    , VolumeType
    , ComplianceStatus
    , ProtectionStatus
    , EncryptionStatus
    , EncryptionMethod
    , ComplianceStatusDetails
    , ReasonsForNonCompliance = (
        -- Cypher strength not AES 256'
        IIF('0'  IN (SELECT VALUE = LTRIM(RTRIM(VALUE)) FROM STRING_SPLIT(ReasonsForNonCompliance, N',')), POWER(1, 1), 0)
        +
        -- Volume encrypted
        IIF('1'  IN (SELECT VALUE = LTRIM(RTRIM(VALUE)) FROM STRING_SPLIT(ReasonsForNonCompliance, N',')), POWER(2, 1), 0)
        +
        -- Volume decrypted
        IIF('2'  IN (SELECT VALUE = LTRIM(RTRIM(VALUE)) FROM STRING_SPLIT(ReasonsForNonCompliance, N',')), POWER(4, 1), 0)
        +
        -- TPM protector required
        IIF('3'  IN (SELECT VALUE = LTRIM(RTRIM(VALUE)) FROM STRING_SPLIT(ReasonsForNonCompliance, N',')), POWER(8, 1), 0)
        +
        -- No TPM+PIN protectors required
        IIF('4'  IN (SELECT VALUE = LTRIM(RTRIM(VALUE)) FROM STRING_SPLIT(ReasonsForNonCompliance, N',')), POWER(16, 1), 0)
        +
        -- Non-TPM reports as compliant
        IIF('5'  IN (SELECT VALUE = LTRIM(RTRIM(VALUE)) FROM STRING_SPLIT(ReasonsForNonCompliance, N',')), POWER(32, 1), 0)
        +
        -- TPM is not visible
        IIF('6'  IN (SELECT VALUE = LTRIM(RTRIM(VALUE)) FROM STRING_SPLIT(ReasonsForNonCompliance, N',')), POWER(64, 1), 0)
        +
        -- Password protector required
        IIF('7'  IN (SELECT VALUE = LTRIM(RTRIM(VALUE)) FROM STRING_SPLIT(ReasonsForNonCompliance, N',')), POWER(128, 1), 0)
        +
        -- Password protector not required
        IIF('8'  IN (SELECT VALUE = LTRIM(RTRIM(VALUE)) FROM STRING_SPLIT(ReasonsForNonCompliance, N',')), POWER(256, 1), 0)
        +
        -- Auto-unlock protector required
        IIF('9'  IN (SELECT VALUE = LTRIM(RTRIM(VALUE)) FROM STRING_SPLIT(ReasonsForNonCompliance, N',')), POWER(512, 1), 0)
        +
        -- Auto-unlock protector not required
        IIF('10' IN (SELECT VALUE = LTRIM(RTRIM(VALUE)) FROM STRING_SPLIT(ReasonsForNonCompliance, N',')), POWER(1024, 1), 0)
        +
        -- Policy conflict detected
        IIF('11' IN (SELECT VALUE = LTRIM(RTRIM(VALUE)) FROM STRING_SPLIT(ReasonsForNonCompliance, N',')), POWER(2048, 1), 0)
        +
        -- System volume is needed for encryption
        IIF('12' IN (SELECT VALUE = LTRIM(RTRIM(VALUE)) FROM STRING_SPLIT(ReasonsForNonCompliance, N',')), POWER(4096, 1), 0)
        +
        -- Protection is suspended
        IIF('13' IN (SELECT VALUE = LTRIM(RTRIM(VALUE)) FROM STRING_SPLIT(ReasonsForNonCompliance, N',')), POWER(8192, 1), 0)
        +
        -- AutoUnlock unsafe unless the OS volume is encrypted
        IIF('14' IN (SELECT VALUE = LTRIM(RTRIM(VALUE)) FROM STRING_SPLIT(ReasonsForNonCompliance, N',')), POWER(16384, 1), 0)
        +
        -- Minimum cypher strength XTS-AES-128 bit required
        IIF('15' IN (SELECT VALUE = LTRIM(RTRIM(VALUE)) FROM STRING_SPLIT(ReasonsForNonCompliance, N',')), POWER(32768, 1), 0)
        +
        -- Minimum cypher strength XTS-AES-256 bit required
        IIF('16' IN (SELECT VALUE = LTRIM(RTRIM(VALUE)) FROM STRING_SPLIT(ReasonsForNonCompliance, N',')), POWER(65536, 1), 0)
    )
    , LastPolicyEvaluation
    , LastHWIScan
    , DiskVolumes
    , ProtectedVolumes
INTO #BitlockerResult
FROM Bitlocker_CTE AS Bitlocker

/* CompliantState summarization */
SELECT DISTINCT
    Compliant           = IIF(
        BitlockerResult.Compliant IS NULL
        , N'3'
        , BitlockerResult.Compliant
    )
    , ComplianceStates  = IIF(
        CompliantStatesSummarization.Value IS NULL
        , N'2048'
        , CompliantStatesSummarization.Value
    )
    , EncodedDeviceName = IIF(
        BitlockerResult.EncodedDeviceName IS NULL
        , ClientCollectionMembers.Name
        , BitlockerResult.EncodedDeviceName
    )
    , Domain            = IIF(
        BitlockerResult.Domain IS NULL
        , LOWER(Systems.Full_Domain_Name0)
        , BitlockerResult.Domain
    )
    , UserName          = IIF(
        BitlockerResult.UserName IS NULL
        , Systems.User_Domain0 + N'\' + Systems.User_Name0
        , BitlockerResult.UserName
    )
    , Protected
    , Exemption
    , VolumeName
    , VolumeType
    , ComplianceStatus
    , ProtectionStatus
    , EncryptionStatus
    , EncryptionMethod
    , ComplianceStatusDetails
    , ReasonsForNonCompliance
    , LastPolicyEvaluation
    , LastHWIScan
    , DiskVolumes
    , ProtectedVolumes
FROM fn_rbac_ClientCollectionMembers(@UserSIDs) AS ClientCollectionMembers
    JOIN fn_rbac_R_System(@UserSIDs) AS Systems ON Systems.ResourceID = ClientCollectionMembers.ResourceID
    LEFT JOIN #BitlockerResult AS BitlockerResult ON BitlockerResult.ResourceID = ClientCollectionMembers.ResourceID
    OUTER APPLY (
        SELECT
            Value = SUM(ComplianceStates)
        FROM (
            SELECT DISTINCT OuterBitlockerResult.ComplianceStates
            FROM #BitlockerResult AS OuterBitlockerResult
            WHERE OuterBitlockerResult.EncodedDeviceName = BitlockerResult.EncodedDeviceName
        ) AS Result
    ) AS CompliantStatesSummarization
WHERE ClientCollectionMembers.CollectionID = @CollectionID

/* Perform cleanup */
IF OBJECT_ID(N'tempdb..#BitlockerResult', N'U') IS NOT NULL
    DROP TABLE #BitlockerResult;

/* #endregion */
/*##=============================================*/
/*## END QUERY BODY                              */
/*##=============================================*/