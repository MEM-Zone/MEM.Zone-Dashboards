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
'    https://SCCM.Zone/
'.LINK
'    https://SCCM.Zone/CM-SRS-Dashboards-GIT
'.LINK
'    https://SCCM.Zone/CM-SRS-Dashboards-ISSUES
'
'/*##=============================================*/
'/*## SCRIPT BODY                                 */
'/*##=============================================*/
'/* #region FunctionBody */

Function GetHealthStates (ByVal intBitMask As Integer, blnDetailed As Boolean) As String
    Dim astrHealthStates() As String = {
        "Healthy", "Unmanaged", "Inactive", "Health Evaluation Failed", "Scan Completed with Errors", "Scan Failed",
        "Scan Unknown", "Scan Late", "Sync Catalog Outdated"
    }
    Dim astrHealthStatesDetailed() As String = {
        "Healthy", "Unmanaged", "Client Inactive", "Client Health Evaluation Failed", "Update Scan Completed with Errors",
        "Update Scan Failed", "Update Scan Unknown", "Update Scan Late", "Update Sync Catalog is Outdated"
    }
    Dim iaHealthStates As Integer
    Dim intStep As Integer
    Dim strResolvedHealthStates As String = ""
    Try
        If blnDetailed Then astrHealthStates = astrHealthStatesDetailed
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