'#region Function GetValueBeweenStrings
Public Function GetValueBeweenStrings(ByVal astrSource As String, ByVal astrSearchFirst As String, ByVal astrSearchLast As String) As String
'<#
'.SYNOPSIS
'    Gets the value between two strings.
'.DESCRIPTION
'    Gets the value between two search strings.
'.PARAMETER astrSource
'    Specifies the string to search.
'.PARAMETER astrSearchFirst
'    Specifies the first search value.
'.PARAMETER astrSearchLast
'    Specifies the last search value.
'.EXAMPLE
'    Code.GetValueBeweenStrings(Fields!SomeField.Value, "first", "last") (SSRS)
'.EXAMPLE
'    GetHealthStates(16) (VB.Net)
'.NOTES
'    Created by MacLeod.broad.
'    Modified by Ioan Popovici.
'.LINK
'    https://www.freevbcode.com/ShowCode.asp?ID=9116
'.LINK
'    https://MEM.Zone/Dashboards
'.LINK
'    https://MEM.Zone/Dashboards-HELP
'.LINK
'    https://MEM.Zone/Dashboards-ISSUES
'#>
    If astrSearchLast.Length < 1 Then
        GetValueBeweenStrings = astrSource.Substring(astrSource.IndexOf(astrSearchFirst))
    End If
    If astrSearchFirst.Length < 1 Then
        GetValueBeweenStrings = astrSource.Substring(0, (astrSource.IndexOf(astrSearchLast)))
    End If
    Try
        GetValueBeweenStrings = ((astrSource.Substring(astrSource.IndexOf(astrSearchFirst), (astrSource.IndexOf(astrSearchLast) - astrSource.IndexOf(astrSearchFirst)))).Replace(astrSearchFirst, "")).Replace(astrSearchLast, "")
    Catch ArgumentOutOfRangeException As Exception
    End Try
End Function
'#endregion