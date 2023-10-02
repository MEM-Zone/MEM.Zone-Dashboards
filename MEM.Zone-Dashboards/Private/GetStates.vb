'#region Function GetStates
Function GetStates (ByVal intBitMask As Integer, ByVal astrStateList As String , ByVal astrDefaultState As String) As String
'<#
'.SYNOPSIS
'    Gets statically defined states.
'.DESCRIPTION
'    Gets statically defined states for a specified bitmask.
'.PARAMETER intBitMask
'    Specifies the bitmask to apply.
'.PARAMETER astrStateList
'    Specifies the state list to resolve.
'.PARAMETER astrDefaultState
'    Specifies the default state to return.
'.EXAMPLE
'    Code.GetStates(16, "State 1; State 2; State 3; Detailed State 1; Detailed State 2; Detailed State 3", "Compliant") (SSRS)
'.EXAMPLE
'    GetStates(16, "State 1; State 2; State 3; Detailed State 1; Detailed State 2; Detailed State 3", "Compliant") (VB.Net)
'.NOTES
'    Created by Ioan Popovici.
'.LINK
'    https://MEMZ.one/Dashboards
'.LINK
'    https://MEMZ.one/Dashboards-HELP
'.LINK
'    https://MEMZ.one/Dashboards-ISSUES
'#>

    Dim iaStates As Long
    Dim intStep As Long
    Dim strResolvedStates As String = ""
    Dim astrStates As String() = astrStateList.Split(";")

    Try
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
            strResolvedStates = astrDefaultState
        End If
    Catch
        strResolvedStates = "Could not resolve states."
    End Try
    GetStates = strResolvedStates
End Function
'#endregion