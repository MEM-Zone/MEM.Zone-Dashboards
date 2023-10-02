'#region Function DecodeString
Public Function DecodeString(ByVal astrToDecode As String) As String
'<#
'.SYNOPSIS
'    Decodes an ecrypted string.
'.DESCRIPTION
'    Decodes an ecrypted string using buitin GetString() function.
'.PARAMETER astrToDecode
'    Specifies the string to decode.
'.EXAMPLE
'    Code.DecodeString(Fields!SomeField.Value) (SSRS)
'.EXAMPLE
'    DecodeString(Fields!SomeField.Value) (VB.Net)
'.NOTES
'    Created by MEMCM product team.
'    Modified by Ioan Popovici.
'.LINK
'    https://MEMZ.one/Dashboards
'.LINK
'    https://MEMZ.one/Dashboards-HELP
'.LINK
'    https://MEMZ.one/Dashboards-ISSUES
'#>
    On Error GoTo ErrorExit
    Dim bytDecodedBytes As Byte() = System.Convert.FromBase64String(astrToDecode)
    Dim astrDecodedValue As String = System.Text.UnicodeEncoding.Unicode.GetString(bytDecodedBytes)
    Return astrDecodedValue
ErrorExit:
    Return ""
End Function
'#endregion