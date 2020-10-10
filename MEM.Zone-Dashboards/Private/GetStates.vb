'#region Function GetStates
Function GetStates (ByVal intBitMask As Integer, astrCategory As String, blnDetailed As Boolean) As String
'<#
'.SYNOPSIS
'    Gets statically defined states.
'.DESCRIPTION
'    Gets statically defined states for a specified bitmask.
'.PARAMETER intBitMask
'    Specifies the bitmask to apply.
'.PARAMETER astrCategory
'    Specifies the state category to resolve. Available values: (BitlockerComplianceStates, BitlockerHealthStates, UpdateHealthStates, UpdateScanStates)
'.PARAMETER blnDetailed
'    Specifies if to return detailed information.
'.EXAMPLE
'    Code.GetStates(Fields!SomeField.Value, "UpdateHealthStates", true) (SSRS)
'.EXAMPLE
'    GetStates(16, "UpdateHealthStates", true) (VB.Net)
'.NOTES
'    Created by Ioan Popovici.
'.LINK
'    https://MEM.Zone/Dashboards
'.LINK
'    https://MEM.Zone/Dashboards-HELP
'.LINK
'    https://MEM.Zone/Dashboards-ISSUES
'#>
    Dim astrBitlockerComplianceStates() As String = {
        "N/A",
        "Cypher strength not AES 256",
        "Volume not encrypted",
        "Volume encrypted",
        "TPM protector required",
        "No TPM+PIN protectors required",
        "Non-TPM reports as compliant",
        "TPM is not visible",
        "Password protector required",
        "Password protector not required",
        "Auto-unlock protector required",
        "Auto-unlock protector not required",
        "Policy conflict detected",
        "System volume is needed for encryption",
        "Protection is suspended",
        "AutoUnlock unsafe unless the OS volume is encrypted",
        "Minimum cypher strength XTS-AES-128 bit required",
        "Minimum cypher strength XTS-AES-256 bit required"
    }
    Dim astrBitlockerComplianceStatesDetailed() As String = {
        "Healthy",
        "Cipher strength not AES 256",
        "MBAM Policy requires this volume to be encrypted but it is not",
        "MBAM Policy requires this volume to NOT be encrypted, but it is",
        "MBAM Policy requires this volume use a TPM protector, but it does not",
        "Policy requires this volume use a TPM+PIN protector, but it does not",
        "Policy does not allow non TPM machines to report as compliant",
        "Volume has a TPM protector but the TPM is not visible (booted with recover key after disabling TPM in BIOS?)",
        "Policy requires this volume use a password protector, but it does not have one",
        "Policy requires this volume NOT use a password protector, but it has one",
        "Policy requires this volume use an auto-unlock protector, but it does not have one",
        "Policy requires this volume NOT use an auto-unlock protector, but it has one",
        "Policy conflict detected preventing MBAM from reporting this volume as compliant",
        "A system volume is needed to encrypt the OS volume but it is not present",
        "Protection is suspended for the volume",
        "AutoUnlock unsafe unless the OS volume is encrypted",
        "Policy requires minimum cypher strength is XTS-AES-128 bit, actual cypher strength is weaker than that",
        "Policy requires minimum cypher strength is XTS-AES-256 bit, actual cypher strength is weaker than that"
    }

    Dim astrBitlockerHealthStates() As String = {
        "Healthy", "Unprotected", "Partially Protected", "Exemption", "OS Drive Noncompliant", "Data Drive Noncompliant",
        "Encryption in Progress", "Decryption in Progress", "Encryption Paused", "Decryption Paused", "Pending Key Upload", "Pending Key Rotation"
    }
    Dim astrBitlockerHealthStatesDetailed() As String = {
        "Healthy", "Unprotected", "Not all Drives Protected", "Bitlocker Exemption", "OS Drive is Noncompliant", "Data Drive is Noncompliant",
        "Encryption is in Progress", "Decryption is in Progress", "Encryption Paused", "Decryption Paused", "Pending Key Upload", "Pending Key Rotation"
    }

    Dim astrUpdateHealthStates() As String = {
        "Healthy", "Unmanaged", "Inactive", "Health Evaluation Failed", "Pending Restart", "Update Scan Failed",
        "Update Scan Late", "No MW", "Distant MW", "Short MW", "Expired MW", "Disabled MW", "High Uptime", "Check Required Updates", "Free Space Low"
    }
    Dim astrUpdateHealthStatesDetailed() As String = {
        "Healthy", "Unmanaged", "Client Inactive", "Client Health Evaluation Failed", "Pending Restart", "Update Scan Failed",
        "Update Scan Late", "No Maintenance Window", "Distant Maintenance Window", "Short Maintenace Window", "Expired Maintenance Window",
        "Disabled Maintenance Window", "Uptime Threshold Exeeded", "Required 0 While High Uptime", "Free Space Threshold Exeeded"
    }

    Dim astrUpdateScanStates() As String = {
        "Healthy", "Unmanaged", "Inactive", "Health Evaluation Failed", "Scan Completed with Errors", "Scan Failed",
        "Scan Unknown", "Scan Late", "Sync Catalog Outdated"
    }
    Dim astrUpdateScanStatesDetailed() As String = {
        "Healthy", "Unmanaged", "Client Inactive", "Client Health Evaluation Failed", "Update Scan Completed with Errors",
        "Update Scan Failed", "Update Scan Unknown", "Update Scan Late", "Update Sync Catalog is Outdated"
    }

    Dim iaStates As Long
    Dim intStep As Long
    Dim strResolvedStates As String = ""
    Dim astrStates As String()

    Try
        Select Case astrCategory
            Case "BitlockerComplianceStates"
                astrStates = astrBitlockerComplianceStates
            Case "BitlockerHealthStates"
                astrStates = astrBitlockerHealthStates
            Case "UpdateHealthStates"
                astrStates = astrUpdateHealthStates
            Case "UpdateScanStates"
                astrStates = astrUpdateScanStates
        End Select
        If blnDetailed Then
            Select Case astrCategory
                Case "BitlockerComplianceStates"
                    astrStates = astrBitlockerComplianceStatesDetailed
                Case "BitlockerHealthStates"
                    astrStates = astrBitlockerHealthStatesDetailed
                Case "UpdateHealthStates"
                    astrStates = astrUpdateHealthStatesDetailed
                Case "UpdateScanStates"
                    astrStates = astrUpdateScanStatesDetailed
            End Select
        End If
        If intBitMask <> 0 Then
            For iaStates = 0 To UBound(astrStates)
                If intBitMask And intStep Then
                    If strResolvedStates <> "" Then
                        strResolvedStates = strResolvedStates + ", "
                    End If
                    strResolvedStates = strResolvedStates + astrStates(iaStates)
                End If
                    intStep = 2 ^ iaStates
            Next
        Else
            If astrCategory = "BitlockerComplianceStates"
                strResolvedStates = "N/A"
            Else
                strResolvedStates = "Healthy"
            End If

        End If
    Catch
        strResolvedStates = "Could not resolve states."
    End Try
    GetStates = strResolvedStates
End Function
'#endregion