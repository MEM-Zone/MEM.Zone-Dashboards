'#region Function ExtractCSV
Public Function ExtractCSV(ByVal astrSource As String, ByVal astrPosition As Integer) As String
'<#
'.SYNOPSIS
'    Extracts a value from a coma sepatated string.
'.DESCRIPTION
'    Extracts a value from a coma sepatated string at the position specified.
'.PARAMETER astrSource
'    Specifies the string to parse.
'.PARAMETER astrPosition
'    Specifies the split string position to get.
'.EXAMPLE
'    Code.ExtractCSV(Fields!SomeField.Value, 2) (SSRS)
'.EXAMPLE
'    ExtractCSV(Fields!SomeField.Value, 2) (VB.Net)
'.NOTES
'    Created by MEMCM product team.
'    Modified by Ioan Popovici.
'.LINK
'    https://MEM.Zone/Dashboards
'.LINK
'    https://MEM.Zone/Dashboards-HELP
'.LINK
'    https://MEM.Zone/Dashboards-ISSUES
'#>

    Dim strResutl As String = ""
    Try
        If (Split(astrSource, ",").Length >= astrPosition) Then
            strResutl = Split(astrSource, ",").GetValue(astrPosition -1)
        End If
    Catch
        strResutl = "Could not find string at specified position."
    End Try
    ExtractCSV = strResutl
End Function
'#endregion