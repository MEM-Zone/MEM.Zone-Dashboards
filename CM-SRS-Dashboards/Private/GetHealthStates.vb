'.SYNOPSIS
'    Gets statically defined health states.
'.DESCRIPTION
'    Gets statically defined health states for a specified bitmask.
'.PARAMETER intBitMask
'    Specifies the bitmask to apply.
'.EXAMPLE
'    Code.GetHealthStates(Fields!SomeField.Value) (SSRS)
'.EXAMPLE
'    GetHealthStates(16) (VB.Net)
'.NOTES
'    Created by Ioan Popovici.
'.LINK
'    https://SCCM.Zone
'.LINK
'    https://SCCM.Zone/Issues
'
'/*##=============================================*/
'/*## SCRIPT BODY                                 */
'/*##=============================================*/
'/* #region FunctionBody */

Function GetHealthStates (ByVal intBitMask As Integer) As String
    Dim astrHealthStates() As String = {
        "Healthy", "Unmanaged", "Inactive", "Health Evaluation Failed", "Pending Restart", "Update Scan Failed",
        "Update Scan Late", "No Service Window", "Distant Service Window"
    }
    Dim iaHealthStates As Integer
    Dim intStep As Integer
    Dim strResolvedHealthStates As String = ""
    Try
        If intBitMask <> 0 Then
            For iaHealthStates = 0 To UBound(astrHealthStates)
                If intBitMask And intStep Then
                    If strResolvedHealthStates <> "" Then
                        strResolvedHealthStates = strResolvedHealthStates + ", "
                    End If
                    strResolvedHealthStates = strResolvedHealthStates + astrHealthStates(iaHealthStates)
                End If
                intStep = 2 ^ iaHealthStates
            Next
        Else
            strResolvedHealthStates = "Healthy"
        End If
    Catch
        strResolvedHealthStates = "Could not resolve health states."
    End Try
    GetHealthStates = strResolvedHealthStates
End Function

'/* #endregion */
'/*##=============================================*/
'/*## END SCRIPT BODY                             */
'/*##=============================================*/