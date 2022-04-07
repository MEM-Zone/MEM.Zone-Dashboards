<#
.SYNOPSIS
    Uploads reports on disk to a report server.
.DESCRIPTION
    Uploads reports in a folder on disk to a report server.
.PARAMETER Path
    Specifies the Path to a file or folder on disk to upload to a report server.
    Default is: 'Join-Path -Path $ScriptPath -ChildPath 'Reports'.
.PARAMETER ReportServerUri
    Specifies the SQL Server Reporting Services Instance URL.
.PARAMETER ReportFolder
    Specifies the Folder on report server to upload the item to. Must begin with an '/'.
.PARAMETER ServerInstance
    Specifies SQL Server Instance.
.PARAMETER Database
    Specifies SQL Database name.
.PARAMETER DataSourceRoot
    Specifies report server Data Sorce Root folder (/ConfigMgr_<SiteCode>).
.PARAMETER DataSourceName
    Specifies the Name of the Report Data Source to update.
.PARAMETER SetReportNodeValue
    Optionally specify report node info for which to modify the value in a hashtable format. Parameter is a hashtable.
    You can also specify a string but you must separate the name and value with a new line character (`n).
    If the 'Path' parameter is a folder, all reports in the folder will be modified.
    [hashtable]@{ NodeName  = 'ReportName'; NodeValue = 'NewValue'; NsPrefix  = 'NamespacePrefix' }.
.PARAMETER ExtensionsPath
    Specifies Extensions folder Path. Default is: 'Join-Path -Path $ScriptPath -ChildPath 'Extensions'.
.PARAMETER ExcludeExtensions
    Specifies to exclude optional extensions.
.PARAMETER ExtensionsOnly
    Specifies to install only optional extensions. Nothing else will be installed.
.PARAMETER UseSQLAuthentication
    Specifies to use SQL Server Authentication instead of Windows Authentication. You will be asked for credentials if this switch is used.
.PARAMETER Overwrite
    Specifies to overwrite the old report and/or extension, if an existing item with same name exists already exists.
.EXAMPLE
    [hashtable]$SetReportNodeValue = @{ NodeName  = 'ReportName'; NodeValue = '/ConfigMgr_XXX/SRSDashboards'; NsPrefix  = 'ns' }
    .\Install-SRSReport.ps1 -Path 'C:\DAS\Reports\SU Compliance by Collection.rdl' -ReportServerUri 'http://CM-SQL-RS-01A/ReportServer' -ReportFolder '/ConfigMgr_XXX/SRSDashboards' -ServerInstance 'CM-SQL-RS-01A' -Database 'CM_XXX' -SetReportNodeValue $SetReportNodeValue
.EXAMPLE
    .\Install-SRSReport.ps1 -Path 'C:\DAS\Reports\SU Compliance by Collection.rdl' -ReportServerUri 'http://CM-SQL-RS-01A/ReportServer' -ReportFolder '/ConfigMgr_XXX/SRSDashboards' -ServerInstance 'CM-SQL-RS-01A' -Database 'CM_XXX' -Overwrite
.EXAMPLE
    .\Install-SRSReport.ps1 -Path 'C:\DAS\Reports' -ReportServerUri 'http://CM-SQL-RS-01A/ReportServer' -ReportFolder '/ConfigMgr_XXX/SRSDashboards' -ServerInstance 'CM-SQL-RS-01A' -Database 'CM_XXX' -DataSourceRoot '/ConfigMgr_XXX/{DataSourceGUID}' -ExcludeExtensions -Overwrite
.EXAMPLE
    .\Install-SRSReport.ps1 -ServerInstance 'CM-SQL-RS-01A' -Database 'CM_XXX' -ExtensionsOnly -UseSQLAuthentication -Verbose
.INPUTS
    None.
.OUTPUTS
    System.String.
    System.Exception
.NOTES
    Created by Ioan Popovici
    The extension cleanup only supports 'FUNCTIONS'!
    Requirements
        ReportingServicesTools powerhshell module.
.LINK
    https://github.com/microsoft/ReportingServicesTools
.LINK
    https://MEM.Zone/
.LINK
    https://MEM.Zone/Install-SRSReport-RELEASES
.LINK
    https://MEM.Zone/Install-SRSReport-GIT
.LINK
    https://MEM.Zone/Install-SRSReport-ISSUES
.COMPONENT
    RS
.FUNCTIONALITY
    RS Catalog Item Installer
#>

## Set script requirements
#Requires -Version 5.0

##*=============================================
##* VARIABLE DECLARATION
##*=============================================
#region VariableDeclaration

## Get script parameters
[CmdletBinding(DefaultParameterSetName='IncludeExtensions')]
Param (
    [Parameter(Mandatory=$false,ParameterSetName='IncludeExtensions',HelpMessage='Report file or folder on disk',Position=0)]
    [Parameter(Mandatory=$false,ParameterSetName='ExcludeExtensions',HelpMessage='Report file or folder on disk',Position=0)]
    [ValidateNotNullorEmpty()]
    [Alias('FolderPath','FilePath','ItemPath')]
    [string]$Path,
    [Parameter(Mandatory=$true,ParameterSetName='IncludeExtensions',HelpMessage='URL to your SSRS instance',Position=1)]
    [Parameter(Mandatory=$true,ParameterSetName='ExcludeExtensions',HelpMessage='URL to your SSRS instance',Position=1)]
    [ValidateNotNullorEmpty()]
    [Alias('RS','RSUri','Uri')]
    [string]$ReportServerUri,
    [Parameter(Mandatory=$true,ParameterSetName='IncludeExtensions',HelpMessage='Destination folder on reporting server',Position=2)]
    [Parameter(Mandatory=$true,ParameterSetName='ExcludeExtensions',HelpMessage='Destination folder on reporting server',Position=2)]
    [ValidateNotNullorEmpty()]
    [Alias('Destination','RsFolder')]
    [string]$ReportFolder,
    [Parameter(Mandatory=$true,ParameterSetName='IncludeExtensions',HelpMessage='SQL server FQDN',Position=3)]
    [Parameter(Mandatory=$true,ParameterSetName='ExcludeExtensions',HelpMessage='SQL server FQDN',Position=3)]
    [Parameter(Mandatory=$true,ParameterSetName='ExtensionsOnly',HelpMessage='SQL server FQDN',Position=0)]
    [ValidateNotNullorEmpty()]
    [Alias('CMSQLServerInstance')]
    [string]$ServerInstance,
    [Parameter(Mandatory=$true,ParameterSetName='IncludeExtensions',HelpMessage='SQL database name',Position=4)]
    [Parameter(Mandatory=$true,ParameterSetName='ExcludeExtensions',HelpMessage='SQS database name',Position=4)]
    [Parameter(Mandatory=$true,ParameterSetName='ExtensionsOnly',HelpMessage='SQS database name',Position=1)]
    [ValidateNotNullorEmpty()]
    [Alias('dba')]
    [string]$Database,
    [Parameter(Mandatory=$false,ParameterSetName='IncludeExtensions',HelpMessage='RS datasource root folder',Position=5)]
    [Parameter(Mandatory=$false,ParameterSetName='ExcludeExtensions',HelpMessage='RS datasource root folder',Position=5)]
    [ValidateNotNullorEmpty()]
    [Alias('DSR')]
    [string]$DataSourceRoot,
    [Parameter(Mandatory=$false,ParameterSetName='IncludeExtensions',HelpMessage='Report datasource name',Position=6)]
    [Parameter(Mandatory=$false,ParameterSetName='ExcludeExtensions',HelpMessage='Report datasource name',Position=6)]
    [ValidateNotNullorEmpty()]
    [Alias('DSN')]
    [string]$DataSourceName,
    [Parameter(Mandatory=$false,ParameterSetName='IncludeExtensions',HelpMessage='[hashtable]@{ NodeName  = "ReportName"; NodeValue = "NewValue"; NsPrefix  = "NamespacePrefix" }',Position=7)]
    [Parameter(Mandatory=$false,ParameterSetName='ExcludeExtensions',HelpMessage='[hashtable]@{ NodeName  = "ReportName"; NodeValue = "NewValue"; NsPrefix  = "NamespacePrefix" }',Position=7)]
    [ValidateNotNullorEmpty()]
    [Alias('SetPropertyValue','SetNodeValue')]
    [hashtable]$SetReportNodeValue,
    [Parameter(Mandatory=$false,ParameterSetName='IncludeExtensions',HelpMessage='Extensions folder path',Position=8)]
    [Parameter(Mandatory=$false,ParameterSetName='ExcludeExtensions',HelpMessage='Extensions folder path',Position=8)]
    [Parameter(Mandatory=$false,ParameterSetName='ExtensionsOnly',HelpMessage='Extensions folder path',Position=2)]
    [ValidateNotNullorEmpty()]
    [Alias('ExtPath')]
    [string]$ExtensionsPath,
    [Parameter(Mandatory=$false,ParameterSetName='ExcludeExtensions',Position=9)]
    [Alias('NoExt')]
    [switch]$ExcludeExtensions,
    [Parameter(Mandatory=$false,ParameterSetName='ExtensionsOnly',Position=3)]
    [Alias('ExtOnly')]
    [switch]$ExtensionsOnly,
    [Parameter(Mandatory=$false,ParameterSetName='IncludeExtensions',Position=10)]
    [Parameter(Mandatory=$false,ParameterSetName='ExcludeExtensions',Position=10)]
    [Parameter(Mandatory=$false,ParameterSetName='ExtensionsOnly',Position=4)]
    [Alias('SQLAuth')]
    [switch]$UseSQLAuthentication,
    [Parameter(Mandatory=$false,ParameterSetName='IncludeExtensions',Position=11)]
    [Parameter(Mandatory=$false,ParameterSetName='ExcludeExtensions',Position=11)]
    [Parameter(Mandatory=$false,ParameterSetName='ExtensionsOnly',Position=5)]
    [Alias('Force')]
    [switch]$Overwrite
)

## Set variables
## Get script path and name
[string]$ScriptPath = [System.IO.Path]::GetDirectoryName($MyInvocation.MyCommand.Definition)
[string]$ScriptName = [System.IO.Path]::GetFileName($MyInvocation.MyCommand.Definition)
[string]$ScriptFullName = Join-Path -Path $ScriptPath -ChildPath $ScriptName
#  Set parameter defaults
[string]$FilterConnection = -join ('Catalog=', $Database, ';')
If (-not $Path) { $Path = Join-Path -Path $ScriptPath -ChildPath 'Reports' }
If (-not $ExtensionsPath) { $ExtensionsPath = Join-Path -Path $ScriptPath -ChildPath 'Extensions' }
If (-not $DependenciesPath) { $DependenciesPath = Join-Path -Path $ScriptPath -ChildPath 'Dependencies' }
If (-not $DataSourceRoot) {
    [string]$SiteCode = $($Database.Split('_')[1])
    $DataSourceRoot = -join ('/ConfigMgr_', $SiteCode)
}
If (-not $DataSourceName) { $DataSourceName = 'CMSQLDatabase' }
#  Get progress steps
$ProgressSteps = $(([System.Management.Automation.PsParser]::Tokenize($(Get-Content -Path $ScriptFullName), [ref]$null) | Where-Object { $_.Type -eq 'Command' -and $_.Content -eq 'Show-Progress' }).Count)
$ForEachSteps = $(([System.Management.Automation.PsParser]::Tokenize($(Get-Content -Path $ScriptFullName), [ref]$null) | Where-Object { $_.Type -eq 'Keyword' -and $_.Content -eq 'ForEach' }).Count)
#  Set progress steps
$Script:Steps = $ProgressSteps - $ForEachSteps
$Script:Step = 0

## Write debug message
Write-Debug  -Message "Path [$Path], Database [$Database], ScriptPath [$ScriptPath], ExtensionsPath [$ExtensionsPath], DataSourceRoot [$DataSourceRoot], DataSourceName [$DataSourceName], FilterConnection [$FilterConnection]"

#endregion
##*=============================================
##* END VARIABLE DECLARATION
##*=============================================

##*=============================================
##* FUNCTION LISTINGS
##*=============================================
#region FunctionListings

#region Function Show-Progress
Function Show-Progress {
<#
.SYNOPSIS
    Displays progress info.
.DESCRIPTION
    Displays progress info and maximizes code reuse.
.PARAMETER Actity
    Specifies the progress activity. Default: 'Running Install Please Wait...'.
.PARAMETER Status
    Specifies the progress status.
.PARAMETER CurrentOperation
    Specifies the current operation.
.PARAMETER Step
    Specifies the progress step. Default: $Global:Step ++.
.PARAMETER ID
    Specifies the progress bar id.
.PARAMETER Delay
    Specifies the progress delay in milliseconds. Default: 400.
.PARAMETER Loop
    Specifies if the call comes from a loop.
.EXAMPLE
    Show-Progress -Activity 'Running Install Please Wait' -Status 'Uploading Report' -Step ($Step++) -Delay 200
.INPUTS
    None.
.OUTPUTS
    None.
.NOTES
    This is an private function should tipically not be called directly.
    Credit to Adam Bertram.
.LINK
    https://adamtheautomator.com/building-progress-bar-powershell-scripts/
.LINK
    https://MEM.Zone/
.LINK
    https://MEM.Zone/Install-SRSReport-GIT
.LINK
    https://MEM.Zone/Install-SRSReport-ISSUES
.COMPONENT
    RS
.FUNCTIONALITY
    RS Catalog Item Installer
#>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$false,Position=0)]
        [ValidateNotNullorEmpty()]
        [Alias('act')]
        [string]$Activity = 'Running Install Please Wait...',
        [Parameter(Mandatory=$true,Position=1)]
        [ValidateNotNullorEmpty()]
        [Alias('sta')]
        [string]$Status,
        [Parameter(Mandatory=$false,Position=2)]
        [ValidateNotNullorEmpty()]
        [Alias('cro')]
        [string]$CurrentOperation,
        [Parameter(Mandatory=$false,Position=3)]
        [ValidateNotNullorEmpty()]
        [Alias('pid')]
        [int]$ID = 0,
        [Parameter(Mandatory=$false,Position=4)]
        [ValidateNotNullorEmpty()]
        [Alias('ste')]
        [int]$Step = $Script:Step ++,
        [Parameter(Mandatory=$false,Position=5)]
        [ValidateNotNullorEmpty()]
        [Alias('del')]
        [string]$Delay = 400,
        [Parameter(Mandatory=$false,Position=5)]
        [ValidateNotNullorEmpty()]
        [Alias('lp')]
        [switch]$Loop
    )
    Begin {
        If ($Loop) { $Script:Steps ++ }
        $PercentComplete = $($($Step / $Steps) * 100)
    }
    Process {
        Try {
            ##  Show progress
            Write-Progress -Activity $Activity -Status $Status -CurrentOperation $CurrentOperation -ID $ID -PercentComplete $PercentComplete
            Start-Sleep -Milliseconds $Delay
        }
        Catch {
            Throw (New-Object System.Exception("Could not Show progress status [$Status]! $($_.Exception.Message)", $_.Exception))
        }
    }
}
#endregion

#region Function Invoke-SQLCommand
Function Invoke-SQLCommand {
<#
.SYNOPSIS
    Runs an SQL query.
.DESCRIPTION
    Runs an SQL query without any dependencies except .net.
.PARAMETER ServerInstance
    Specifies a character string or SQL Server Management Objects (SMO) object that specifies the name of an instance of the Database Engine. For default instances, only specify the computer name: MyComputer. For named instances, use the format ComputerName\InstanceName.
.PARAMETER Database
    Specifies the name of a database. This cmdlet connects to this database in the instance that is specified in the ServerInstance parameter.
.PARAMETER Username
    Specifies the login ID for making a SQL Server Authentication connection to an instance of the Database Engine.
    If Username and Password are not specified, this cmdlet attempts a Windows Authentication connection using the Windows account running the Windows PowerShell session. When possible, use Windows Authentication.
.PARAMETER Password
    Specifies the password for the SQL Server Authentication login ID that was specified in the Username parameter.
    If Username and Password are not specified, this cmdlet attempts a Windows Authentication connection using the Windows account running the Windows PowerShell session. When possible, use Windows Authentication.
.PARAMETER Query
    Specifies one or more queries that this cmdlet runs.
.PARAMETER ConnectionTimeout
    Specifies the number of seconds when this cmdlet times out if it cannot successfully connect to an instance of the Database Engine. The timeout value must be an integer value between 0 and 65534. If 0 is specified, connection attempts does not time out.
    Default is: '0'.
.PARAMETER UseSQLAuthentication
    Specifies to use SQL Server Authentication instead of Windows Authentication. You will be asked for credentials if this switch is used.
.EXAMPLE
    Invoke-SQLCommand -ServerInstance 'CM-SQL-RS-01A' -Database 'CM_XXX' -Query 'SELECT * TOP 5 FROM v_UpdateInfo' -ConnectionTimeout 20
.EXAMPLE
    Invoke-SQLCommand -ServerInstance 'CM-SQL-RS-01A' -Database 'CM_XXX' -Query 'SELECT * TOP 5 FROM v_UpdateInfo' -ConnectionTimeout 20 -UseSQLAuthentication
.INPUTS
    None.
.OUTPUTS
    System.Data.DataRow
    System.String
    System.Exception
.NOTES
    This is an private function and should tipically not be called directly.
.LINK
    https://stackoverflow.com/questions/8423541/how-do-you-run-a-sql-server-query-from-powershell
.LINK
    https://MEM.Zone/
.LINK
    https://MEM.Zone/Install-SRSReport-GIT
.LINK
    https://MEM.Zone/Install-SRSReport-ISSUES
.COMPONENT
    RS
.FUNCTIONALITY
    RS Catalog Item Installer
#>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$true,HelpMessage='SQL server and instance name',Position=0)]
        [ValidateNotNullorEmpty()]
        [Alias('Server')]
        [string]$ServerInstance,
        [Parameter(Mandatory=$true,HelpMessage='Database name',Position=1)]
        [ValidateNotNullorEmpty()]
        [Alias('Dbs')]
        [string]$Database,
        [Parameter(Mandatory=$true,Position=4)]
        [ValidateNotNullorEmpty()]
        [Alias('Qry')]
        [string]$Query,
        [Parameter(Mandatory=$false,Position=5)]
        [ValidateNotNullorEmpty()]
        [Alias('Tmo')]
        [int]$ConnectionTimeout = 0,
        [Parameter(Mandatory=$false,Position=6)]
        [ValidateNotNullorEmpty()]
        [Alias('SQLAuth')]
        [switch]$UseSQLAuthentication
    )
    Begin {

        ## Assemble connection string
        [string]$ConnectionString = "Server=$ServerInstance; Database=$Database; "
        #  Set connection string for integrated or non-integrated authentication
        If ($UseSQLAuthentication) {
            # Get credentials if SQL Server Authentication is used
            $Credentials = Get-Credential -Message 'SQL Credentials'
            [string]$Username = $($Credentials.UserName)
            [securestring]$Password = $($Credentials.Password)
            # Set connection string
            $ConnectionString += "User ID=$Username; Password=$Password;"
        }
        Else { $ConnectionString += 'Trusted_Connection=Yes; Integrated Security=SSPI;' }
    }
    Process {
        Try {

            ## Connect to the database
            Write-Verbose -Message "Connecting to [$Database]..."
            $DBConnection = New-Object System.Data.SqlClient.SqlConnection($ConnectionString)
            $DBConnection.Open()

            ## Assemble query object
            $Command = $DBConnection.CreateCommand()
            $Command.CommandText = $Query
            $Command.CommandTimeout = $ConnectionTimeout

            ## Run query
            Write-Verbose -Message 'Running SQL query...'
            $DataAdapter = New-Object System.Data.SqlClient.SqlDataAdapter -ArgumentList $Command
            $DataSet = New-Object System.Data.DataSet
            $DataAdapter.Fill($DataSet) | Out-Null

            ## Return the first collection of results or an empty array
            If ($null -ne $($DataSet.Tables[0])) { $Table = $($DataSet.Tables[0]) }
            ElseIf ($($Table.Rows.Count) -eq 0) { $Table = New-Object System.Collections.ArrayList }

            ## Close database connection
            $DBConnection.Close()
        }
        Catch {
            Throw (New-Object System.Exception("Error running query! $($_.Exception.Message)", $_.Exception))
        }
        Finally {
            Write-Output $Table
        }
    }
}
#endregion

#region Function New-NamespaceManager
Function New-NamespaceManager {
<#
.SYNOPSIS
    Creates a report namespace manager.
.DESCRIPTION
    Creates a report item namespace manager
.PARAMETER Path
    Specifies the report item Path.
.EXAMPLE
    New-NamespaceManager -Path 'C:\DAS\SU Compliance by Collection.rdl'
.INPUTS
    None.
.OUTPUTS
    System.PsObject
    System.Exception
.NOTES
    This is an private function should tipically not be called directly.
.LINK
    https://MEM.Zone/
.LINK
    https://MEM.Zone/Install-SRSReport-GIT
.LINK
    https://MEM.Zone/Install-SRSReport-ISSUES
.COMPONENT
    RS
.FUNCTIONALITY
    RS Catalog Item Installer
#>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$true,Position=0)]
        [ValidateNotNullorEmpty()]
        [Alias('FilePath','ItemPath')]
        [string]$Path
    )

    Begin {

        ## Create Xml objects
        $ReportFile = New-Object -TypeName 'System.Xml.XmlDocument'
        $Namespaces = New-Object -TypeName 'System.Xml.XmlDocument'
    }
    Process {
        Try {
            Write-Verbose -Message 'Creating namespace manager...'

            ## Load report file
            $ReportFile.Load($Path)

            ## Get report namespaces
            $Namespaces = $ReportFile.SelectSingleNode('/*').Attributes | Where-Object -Property 'Prefix' -eq 'xmlns'

            ## Add namespaces to namespace manager
            $Namespaces | ForEach-Object {
                $NamespaceManager += @{$_.LocalName = $_.Value}
            }
            #  Add default namespace to namespace manager
            $NamespaceManager += @{ns = $ReportFile.DocumentElement.NamespaceURI}
        }
        Catch {
            Throw (New-Object System.Exception("Could not create report [$Path] Namespace Manager! $($_.Exception.Message)", $_.Exception))
        }
        Finally {
            Write-Output -InputObject $NamespaceManager
        }
    }
}
#endregion

#region Function Get-RINode
Function Get-RINode {
<#
.SYNOPSIS
    Gets a report node.
.DESCRIPTION
    Gets a report item node information.
.PARAMETER Path
    Specifies the report item Path.
.PARAMETER NodeName
    Specifies the node Name.
.PARAMETER NamespacePrefix
    Specifies the xml namespace prefix.
.EXAMPLE
    Get-RINode -Path 'C:\DAS\SU Compliance by Collection.rdl' -NodeName 'ReportName' -NamespacePrefix 'ns'
.INPUTS
    None.
.OUTPUTS
    System.Xml.XmlDocument
    System.Exception
.NOTES
    This is an public function and can be called directly.
.LINK
    https://MEM.Zone/
.LINK
    https://MEM.Zone/Install-SRSReport-GIT
.LINK
    https://MEM.Zone/Install-SRSReport-ISSUES
.COMPONENT
    RS
.FUNCTIONALITY
    RS Catalog Item Installer
#>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$true,Position=0)]
        [ValidateNotNullorEmpty()]
        [Alias('ReportPath','ItemPath')]
        [string]$Path,
        [Parameter(Mandatory=$true,Position=1)]
        [ValidateNotNullorEmpty()]
        [Alias('PropertyName','Node')]
        [string]$NodeName,
        [Parameter(Mandatory=$true,Position=2)]
        [ValidateNotNullorEmpty()]
        [Alias('Prefix','Ns','NsPrefix')]
        [string]$NamespacePrefix
    )
    Begin {

        ## Create NamespaceManager
        [hashtable]$NamespaceManager = New-NamespaceManager -Path $Path

        ## Assemble node name
        [string]$Node = "//${NamespacePrefix}:${NodeName}"
    }
    Process {
        Try {
            Write-Verbose -Message "Getting [$Node] info..."
            $Result = Select-Xml -Path $Path -XPath $Node -Namespace $NamespaceManager | Select-Object -Property *, @{Label="Value"; Expression={($_.Node.InnerXml).Trim()}}
        }
        Catch {
            Throw (New-Object System.Exception("Could not get report node [$Node]! $($_.Exception.Message)", $_.Exception))
        }
        Finally {
            Write-Output -InputObject $Result
        }
    }
}
#endregion

#region Function Set-RINodeValue
Function Set-RINodeValue {
<#
.SYNOPSIS
    Sets a report node value.
.DESCRIPTION
    Sets a report item node value.
.PARAMETER Path
    Specifies the report item Path.
.PARAMETER NodeName
    Specifies the node Name.
.PARAMETER NodeValue
    Specifies the node Value to be set.
.PARAMETER NamespacePrefix
    Specifies the xml namespace prefix.
.EXAMPLE
    Set-RINode -Path 'C:\DAS\SU Compliance by Collection.rdl' -NodeName 'ReportName' -NodeValue '\Reports\DAS' -NamespacePrefix 'ns'
.INPUTS
    None.
.OUTPUTS
    System.Xml.XmlDocument
    System.Exception
.NOTES
    This is an public function and can be called directly.
.LINK
    https://MEM.Zone/
.LINK
    https://MEM.Zone/Install-SRSReport-GIT
.LINK
    https://MEM.Zone/Install-SRSReport-ISSUES
.COMPONENT
    RS
.FUNCTIONALITY
    RS Catalog Item Installer
#>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$true,Position=0)]
        [ValidateNotNullorEmpty()]
        [Alias('FilePath','ItemPath')]
        [string]$Path,
        [Parameter(Mandatory=$true,Position=1)]
        [ValidateNotNullorEmpty()]
        [Alias('Node','PropertyName')]
        [string]$NodeName,
        [Parameter(Mandatory=$true,Position=2)]
        [ValidateNotNullorEmpty()]
        [Alias('Value','PropertyValue')]
        [string]$NodeValue,
        [Parameter(Mandatory=$true,Position=3)]
        [ValidateNotNullorEmpty()]
        [Alias('Prefix','Ns','NsPrefix')]
        [string]$NamespacePrefix
    )

    Begin {

        ## Set variables
        [bool]$SetNode = $false
        #  Assemble node name
        [string]$Node = "//${NamespacePrefix}:${NodeName}"
        #  Create report file object
        $ReportFile = New-Object -TypeName 'System.Xml.XmlDocument'
        #  Create Namespace Manager
        [hashtable]$NamespaceManager = New-NamespaceManager -Path $Path
    }
    Process {
        Try {
            Write-Verbose -Message "Setting node value to [$NodeValue]..."

            ## Load report file
            $ReportFile.Load($Path)

            ## Set Node Values
            $ReportFile | Select-Xml -XPath $Node -Namespace $NamespaceManager | ForEach-Object {
                $_.Node.Set_InnerText($NodeValue)
                $SetNode = $true
            }

            ## Save report file
            $ReportFile.Save($Path)

            If ($SetNode) {
                ## Set Result variable
                $Result = Select-Xml -Path $Path -XPath $Node -Namespace $NamespaceManager | Select-Object -Property *, @{Label="Value"; Expression= {($_.Node.InnerXml).Trim()}}
            }
            Else {
                $Result = $null
                Write-Verbose -Message "Node [$Node] does not exist!"
            }
        }
        Catch {
            Throw (New-Object System.Exception("Could not set report node [$Node] value [$NodeValue]! $($_.Exception.Message)", $_.Exception))
        }
        Finally {
            Write-Output -InputObject $Result
        }
    }
}
#endregion

#region Function Install-RIReport
Function Install-RIReport {
<#
.SYNOPSIS
    Uploads a report(s) on disk to a report server.
.DESCRIPTION
    Uploads a report or reports in a folder on disk to a report server.
.PARAMETER Path
    Specifies a path to a file or folder on disk to upload to a report server.
.PARAMETER ReportServerUri
    Specifies the SQL Server Reporting Services Instance URL.
.PARAMETER ReportFolder
    Specifies the report server Folder to upload the item to. Must begin with an '/'. Default is: '/'
.PARAMETER SetReportNodeValue
    Optionally specifies report node info for which to modify the value in a hashtable format. Parameter is a hashtable.
    You can also specify a string but you must separate the name and value with a new line character (`n).
    If the 'Path' parameter is a folder, all reports in the folder will be modified.
    [hashtable]@{ NodeName  = 'ReportName'; NodeValue = 'NewValue'; NsPrefix  = 'NamespacePrefix' }
.PARAMETER Overwrite
    Overwrite the old item(s), if an existing report with same name exists at the specified destination.
.EXAMPLE
    Install-RIReport -Path 'C:\DAS\Reports' -ReportServerUri 'http://CM-SQL-RS-01A/ReportServer' -ReportFolder '/ConfigMgr_XXX/SRSDashboards' -Overwrite
.EXAMPLE
    Install-RIReport -Path 'C:\DAS\Reports\SU Compliance by Collection.rdl' -ReportServerUri 'http://CM-SQL-RS-01A/ReportServer' -ReportFolder '/ConfigMgr_XXX/SRSDashboards' -Overwrite
.EXAMPLE
    [hashtable]$SetReportNodeValue = @{ NodeName  = 'ReportName'; NodeValue = '/ConfigMgr_XXX/SRSDashboards'; NsPrefix  = 'ns' }
    Install-RIReport -Path 'C:\DAS\Reports\SU Compliance by Collection.rdl' -ReportServerUri 'http://CM-SQL-RS-01A/ReportServer' -ReportFolder '/ConfigMgr_XXX/SRSDashboards' -SetReportNodeValue $SetReportNodeValue
.INPUTS
    None.
.OUTPUTS
    System.String
    System.Exception
.NOTES
    This is an public function and can be called directly.
.LINK
    https://MEM.Zone/
.LINK
    https://MEM.Zone/Install-SRSReport-GIT
.LINK
    https://MEM.Zone/Install-SRSReport-ISSUES
.COMPONENT
    RS
.FUNCTIONALITY
    RS Catalog Item Installer
#>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$true,HelpMessage='File or folder on disk',Position=0)]
        [ValidateNotNullorEmpty()]
        [Alias('FolderPath','FilePath','ItemPath')]
        [string]$Path,
        [Parameter(Mandatory=$true,HelpMessage='URL to your SQL Server Reporting Services Instance',Position=1)]
        [ValidateNotNullorEmpty()]
        [Alias('RS','RSUri','Uri')]
        [string]$ReportServerUri,
        [Parameter(Mandatory=$false,HelpMessage='Destination folder on report server (/RSFolder)',Position=2)]
        [ValidateNotNullorEmpty()]
        [Alias('Destination','RsFolder')]
        [string]$ReportFolder = '/',
        [Parameter(Mandatory=$false,HelpMessage='[hashtable]@{ NodeName  = "ReportName"; NodeValue = "NewValue"; NsPrefix  = "NamespacePrefix" }',Position=3)]
        [ValidateNotNullorEmpty()]
        [Alias('SetPropertyValue','SetNodeValue')]
        [hashtable]$SetReportNodeValue,
        [Parameter(Mandatory=$false,Position=4)]
        [Alias('Force')]
        [switch]$Overwrite
    )
    Begin {
        [bool]$RSFolderExists = $false
        Write-Debug -Message "Path [$Path], ReportServerUri [$ReportServerUri], ReportFolder [$ReportFolder], Overwrite [$Overwrite]"
    }
    Process {
        Try {
            ## Check if path is a folder
            If ($ReportFolder -ne '/') {
                [string]$RsFolderParent = (Split-Path -Path $ReportFolder -Parent).Replace('\', '/')
                [string]$RsFolderLeaf = (Split-Path -Path $ReportFolder -Leaf).Replace('\', '/')
                [string]$GetRSFolder = Get-RsFolderContent -ReportServerUri $ReportServerUri -RsFolder $RsFolderParent | Where-Object -Property 'Name' -eq $RsFolderLeaf -ErrorAction 'SilentlyContinue'
                $RsFolderExists = -not [string]::IsNullOrEmpty($GetRSFolder)
            }

            ## Get report file paths
            [string[]]$ReportFilePaths = Get-ChildItem -Path $Path -Recurse -Filter '*.rdl' | Select-Object -ExpandProperty 'FullName' -ErrorAction 'Stop'

            ## Set report value
            If ($SetReportNodeValue) {
                #  Process reports
                ForEach ($FilePath in $ReportFilePaths) {
                    [hashtable]$NodeParams = @{
                        Path      = $FilePath
                        NodeName  = $($SetReportNodeValue.NodeName)
                        NodeValue = $($SetReportNodeValue.NodeValue)
                        NsPrefix  = $($SetReportNodeValue.NsPrefix)
                    }
                    #  Show progress
                    Show-Progress -Status "Seting Report [$FilePath] Node [$($SetReportNodeValue.NodeName)] Value --> [$($SetReportNodeValue.NodeValue)]" -Loop
                    #  Set node value
                    [string]$NewNodeValue = Set-RINodeValue @NodeParams | Out-String
                    Write-Debug -Message $NewNodeValue
                }
            }

            ## If destination does not exists, create it.
            If (-not $RsFolderExists) {
                New-RsFolder -ReportServerUri $ReportServerUri -Path $RsFolderParent -Name $RsFolderLeaf
            }

            ## Upload report file(s)
            ForEach ($FilePath in $ReportFilePaths) {
                #  Show progress
                Show-Progress -Status "Uploading Report [$FilePath] --> [$ReportFolder]" -Loop
                # Upload report
                Write-RsCatalogItem -ReportServerUri $ReportServerUri -Path $FilePath -Destination $ReportFolder -Overwrite:$OverWrite #-WarningAction 'SilentlyContinue'
            }

            ## Save result
            $Result = 'Succesfully installed reports!'
        }
        Catch {
            If ($($_.Exception.Message) -notlike '*already exists*') {
                Throw (New-Object System.Exception("Could install report(s) [$Path] ! $($_.Exception.Message)", $_.Exception))
            }
        }
        Finally {
            Write-Output $Result
        }
    }
}
#endregion

#region Function Set-RIDataSourceReference
Function Set-RIDataSourceReference {
<#
.SYNOPSIS
    Updates the shared DataSource of report(s) on a report server.
.DESCRIPTION
    Updates the shared DataSource of a report or multiple reports on a report server.
.PARAMETER Path
    Specifies a report file or folder on report server. Must begin with an '/'.
.PARAMETER ReportServerUri
    Specifies the SQL Server Reporting Services Instance URL.
.PARAMETER DataSourceName
    Specifies a DataSource Name to set.
.PARAMETER DataSourcePath
    Specifies a DataSource Path to set. Must begin with an '/'.
.PARAMETER DataSourceRoot
    Specifies a DataSource Root from where to get DataSources to set. Must begin with an '/'.
.PARAMETER FilterConnection
    Specifies to filter DataSources based on DataSource Connection String. Supports wildcards.
.EXAMPLE
    Set-RIDataSourceReference -Path '/ConfigMgr_XXX/SRSDashboards' -ReportServerUri 'http://SQL-RS-01/ReportServer' -DataSourceName 'CMSQLDatabase' -DataSourcePath '/ConfigMgr_XXX/{5C8358F2-4BB6-4a1b-A16E-5D96795D8602}'
.EXAMPLE
    Set-RIDataSourceReference -Path '/ConfigMgr_XXX/SRSDashboards' -ReportServerUri 'http://SQL-RS-01/ReportServer' -DataSourceName 'CMSQLDatabase' -DataSourceRoot '/ConfigMgr_XXX' -FilterConnection 'Catalog=CM_XXX;'
.INPUTS
    None.
.OUTPUTS
    System.String
    System.Exception
.NOTES
    This is an public function and can be called directly.
.LINK
    https://MEM.Zone/
.LINK
    https://MEM.Zone/Install-SRSReport-GIT
.LINK
    https://MEM.Zone/Install-SRSReport-ISSUES
.COMPONENT
    RS
.FUNCTIONALITY
    RS Catalog Item Installer
#>
    [CmdletBinding(DefaultParameterSetName='DataSource')]
    Param (
        [Parameter(Mandatory=$true,ParameterSetName='DataSource',HelpMessage='Report file or folder on a report server',Position=0)]
        [Parameter(Mandatory=$true,ParameterSetName='GetDataSource',HelpMessage='Report file or folder on a report server',Position=0)]
        [ValidateNotNullorEmpty()]
        [Alias('RSFolderPath','RSReportPath','RSItemPath')]
        [string]$Path,
        [Parameter(Mandatory=$true,ParameterSetName='DataSource',HelpMessage='URL to your SSRS instance',Position=1)]
        [Parameter(Mandatory=$true,ParameterSetName='GetDataSource',HelpMessage='URL to your SSRS instance',Position=1)]
        [ValidateNotNullorEmpty()]
        [Alias('RS','RSUri','Uri')]
        [string]$ReportServerUri,
        [Parameter(Mandatory=$true,ParameterSetName='DataSource',HelpMessage='Report DataSource name',Position=2)]
        [Parameter(Mandatory=$true,ParameterSetName='GetDataSource',HelpMessage='Report DataSource name',Position=2)]
        [ValidateNotNullorEmpty()]
        [Alias('DSName')]
        [string]$DataSourceName,
        [Parameter(Mandatory=$true,ParameterSetName='DataSource',HelpMessage='RS shared DataSource path (/RSFolder)',Position=3)]
        [ValidateNotNullorEmpty()]
        [Alias('DSPath')]
        [string]$DataSourcePath,
        [Parameter(Mandatory=$true,ParameterSetName='GetDataSource',HelpMessage='RS DataSource root folder (/RSFolder)',Position=3)]
        [ValidateNotNullorEmpty()]
        [Alias('DSRoot')]
        [psobject]$DataSourceRoot,
        [Parameter(Mandatory=$true,ParameterSetName='GetDataSource',HelpMessage='RS DataSource connection string filter pattern',Position=4)]
        [ValidateNotNullorEmpty()]
        [Alias('Filter')]
        [string]$FilterConnection
    )
    Begin {

        ## Set variables
        [psobject]$DataSourcesInfo = @()

        ## Check if path is a folder
        [bool]$IsContainer = If (Get-RsFolderContent -ReportServerUri $ReportServerUri -Path $DataSourceRoot -ErrorAction 'SilentlyContinue') { $true } Else { $false }
    }
    Process {
        Try {

            If ($($PSCmdlet.ParameterSetName) -eq 'DataSource') {
                If ($IsContainer) { Throw 'Path is a folder!' }

                ## Set DataSource
                Write-Verbose -Message 'Updating datasource [$DataSourceName]...'
                $SetDataSource = Set-RsDataSourceReference -Path $ReportPath -ReportServerUri $ReportServerUri -DataSourcePath $DataSourcePath -DataSourceName $DataSourceName
            }
            If ($($PSCmdlet.ParameterSetName) -eq 'GetDataSource') {
                If (-not $IsContainer) { Throw 'Path is not a folder!' }

                ## Get report server DataSources
                Write-Verbose -Message 'Retrieving report server datasources...'
                $RSDataSources = Get-RsFolderContent -ReportServerUri $ReportServerUri -Path $DataSourceRoot | Where-Object -Property 'TypeName' -eq 'DataSource'

                ## Get report server DataSource info
                ForEach ($RSDataSource in $RSDataSources) {
                    #  Set variables
                    [string]$RsDataSourcePath = $($RSDataSource.Path)
                    #  Show progress
                    Show-Progress -Status "Getting Report Server DataSource [$RsDataSourcePath] --> [$($RSDataSource.Name)]" -Loop
                    #  Get DataSource info
                    Write-Verbose -Message 'Getting datasource info...'
                    If ($FilterConnection) {
                        Write-Verbose -Message "Filtering dataSource connection string on [$FilterConnection]..."
                        $GetDataSource = Get-RsDataSource -ReportServerUri $ReportServerUri -Path $RsDataSourcePath | Where-Object -Property 'ConnectString' -Match $FilterConnection
                    }
                    Else {
                        $GetDataSource = Get-RsDataSource -ReportServerUri $ReportServerUri -Path $RsDataSourcePath
                    }

                    If ($GetDataSource) {
                        $DataSourceInfoProps = @{ Path = $RsDataSourcePath }
                        #  Add to DataSourcesInfo object
                        $DataSourcesInfo += New-Object 'PSObject' -Property $DataSourceInfoProps
                    }
                }
                #  Check if we have any DataSources
                If (-not $DataSourcesInfo) { Throw "No datasources found or match filter criteria!" }

                ## Update uploaded report(s) DataSource(s)
                Write-Verbose -Message 'Getting reports to update...'
                [string[]]$ReportPaths = Get-RsFolderContent -ReportServerUri $ReportServerUri -Path $ReportFolder | Where-Object -Property 'TypeName' -eq 'Report' | Select-Object -ExpandProperty 'Path'
                If ($($ReportPaths.Count) -eq 0) { Throw "No reports found at this path [$ReportFolder]!" }
                Write-Verbose -Message "Processing [#$($ReportPaths.Count)] reports..."

                ## Set report DataSources
                ForEach ($ReportPath in $ReportPaths) {
                    ForEach ($DataSource in $DataSourcesInfo) {
                        #  Show progress
                        Show-Progress -Status "Setting Report [$ReportPath] DataSource --> [$($RSDataSource.Name)]" -Loop
                        #  Set variables
                        [string]$DataSourcePath = $($DataSource.Path)
                        #  Set DataSource
                        Set-RsDataSourceReference -Path $ReportPath -ReportServerUri $ReportServerUri -DataSourcePath $DataSourcePath -DataSourceName $DataSourceName
                    }
                }
            }
        }
        Catch {
            Throw (New-Object System.Exception("Error while installing report(s)! $($_.Exception.Message)", $_.Exception))
        }
        Finally {
            Write-Output $SetDataSource
        }
    }
}
#endregion

#region Function Add-RISQLExtension
Function Add-RISQLExtension {
<#
.SYNOPSIS
    Adds an sql extension(s) to specified SQL database.
.DESCRIPTION
    Adds an sql extension(s) from a folder on disk to specified SQL database.
.PARAMETER Path
    Specifies a extension file or folder on disk.
.PARAMETER ServerInstance
    Specifies a character string or SQL Server Management Objects (SMO) object that specifies the name of an instance of the Database Engine. For default instances, only specify the computer name: MyComputer. For named instances, use the format ComputerName\InstanceName.
.PARAMETER Database
    Specifies the name of a database. This cmdlet connects to this database in the instance that is specified in the ServerInstance parameter.
.PARAMETER ConnectionTimeout
    Specifies the number of seconds when this cmdlet times out if it cannot successfully connect to an instance of the Database Engine. The timeout value must be an integer value between 0 and 65534. If 0 is specified, connection attempts does not time out.
    Default is: '0'.
.PARAMETER UseSQLAuthentication
    Specifies to use SQL Server Authentication instead of Windows Authentication. You will be asked for credentials if this switch is used.
.PARAMETER FunctionsOnly
    Specifies to add only function extensions.
.PARAMETER PermissionsOnly
    Specifies to add only permission extensions.
.PARAMETER Overwrite
    Specifies to overwrite the extension if it's already installed.
.EXAMPLE
    Invoke-RISQLExtension -Path 'C:\DAS\Extensions' -ServerInstance 'CM-SQL-RS-01A' -Database 'CM_XXX' -ConnectionTimeout 20 -Overwrite
.EXAMPLE
    Invoke-RISQLExtension -Path 'C:\DAS\Extensions\ufn_CM_GetNextMaintenanceWindow.sql' -ServerInstance 'CM-SQL-RS-01A' -Database 'CM_XXX' -ConnectionTimeout 20 -Overwrite
.EXAMPLE
    Invoke-RISQLExtension -Path 'C:\DAS\Extensions' -ServerInstance 'CM-SQL-RS-01A' -Database 'CM_XXX' -ConnectionTimeout 20 -Overwrite -FunctionsOnly
.EXAMPLE
    Invoke-RISQLExtension -Path 'C:\DAS\Extensions' -ServerInstance 'CM-SQL-RS-01A' -Database 'CM_XXX' -ConnectionTimeout 20 -PermissionsOnly
.INPUTS
    None.
.OUTPUTS
    System.Data.DataRow
    System.String
    System.Exception
.NOTES
    This is an public function and can be called directly.
.LINK
    https://MEM.Zone/
.LINK
    https://MEM.Zone/Install-SRSReport-GIT
.LINK
    https://MEM.Zone/Install-SRSReport-ISSUES
.COMPONENT
    RS
.FUNCTIONALITY
    RS Catalog Item Installer
#>
    [CmdletBinding(DefaultParameterSetName='FunctionsAndPermissions')]
    Param (
        [Parameter(Mandatory=$true,ParameterSetName='FunctionsAndPermissions',HelpMessage='SQL extension file or folder on disk',Position=0)]
        [Parameter(Mandatory=$true,ParameterSetName='Functions',HelpMessage='SQL extension file or folder on disk',Position=0)]
        [Parameter(Mandatory=$true,ParameterSetName='Permissions',HelpMessage='SQL extension file or folder on disk',Position=0)]
        [ValidateNotNullorEmpty()]
        [Alias('FolderPath','FilePath','ItemPath')]
        [string]$Path,
        [Parameter(Mandatory=$true,ParameterSetName='FunctionsAndPermissions',HelpMessage='SQL server and instance name',Position=1)]
        [Parameter(Mandatory=$true,ParameterSetName='Functions',HelpMessage='SQL server and instance name',Position=1)]
        [Parameter(Mandatory=$true,ParameterSetName='Permissions',HelpMessage='SQL server and instance name',Position=1)]
        [ValidateNotNullorEmpty()]
        [Alias('Server')]
        [string]$ServerInstance,
        [Parameter(Mandatory=$true,ParameterSetName='FunctionsAndPermissions',HelpMessage='Database name',Position=2)]
        [Parameter(Mandatory=$true,ParameterSetName='Functions',HelpMessage='Database name',Position=2)]
        [Parameter(Mandatory=$true,ParameterSetName='Permissions',HelpMessage='Database name',Position=2)]
        [ValidateNotNullorEmpty()]
        [Alias('Dbs')]
        [string]$Database,
        [Parameter(Mandatory=$false,ParameterSetName='FunctionsAndPermissions',Position=3)]
        [Parameter(Mandatory=$false,ParameterSetName='Functions',Position=3)]
        [Parameter(Mandatory=$false,ParameterSetName='Permissions',Position=3)]
        [ValidateNotNullorEmpty()]
        [Alias('Tmo')]
        [int]$ConnectionTimeout = 0,
        [Parameter(Mandatory=$false,ParameterSetName='FunctionsAndPermissions',Position=4)]
        [Parameter(Mandatory=$false,ParameterSetName='Functions',Position=4)]
        [Parameter(Mandatory=$false,ParameterSetName='Permissions',Position=4)]
        [Alias('SQLAuth')]
        [switch]$UseSQLAuthentication,
        [Parameter(Mandatory=$false,ParameterSetName='FunctionsAndPermissions',Position=5)]
        [Parameter(Mandatory=$false,ParameterSetName='Functions',Position=5)]
        [ValidateNotNullorEmpty()]
        [Alias('Force')]
        [switch]$Overwrite,
        [Parameter(Mandatory=$false,ParameterSetName='Functions',Position=6)]
        [ValidateNotNullorEmpty()]
        [Alias('Fun')]
        [switch]$FunctionsOnly,
        [Parameter(Mandatory=$false,ParameterSetName='Permissions',Position=5)]
        [ValidateNotNullorEmpty()]
        [Alias('Perm')]
        [switch]$PermissionsOnly
    )
    Process {
        Try {

            ## Get extensions
            $Functions = Get-ChildItem -Path $ExtensionsPath -Filter 'ufn*.sql' | Select-Object -Property 'FullName', 'BaseName'
            $Permissions = Get-ChildItem -Path $ExtensionsPath -Filter 'perm*.sql' | Select-Object -Property 'FullName', 'BaseName'

            ## Process functions
            ForEach ($Function in $Functions) {
                #  Set variables
                [string]$FunctionName = $($Function.BaseName)
                [string]$FunctionPath = $($Function.FullName)
                [string]$InstallFunction = Get-Content -Path $FunctionPath | Out-String
                [string]$CleanupFunction =
@"
                /* Drop function if it exists */
                IF OBJECT_ID('[dbo].[$FunctionName]') IS NOT NULL
                    BEGIN
                        DROP FUNCTION [dbo].[$FunctionName]
                    END
"@

                ## Install functions
                If (($($PSCmdlet.ParameterSetName) -eq 'Functions') -or ($($PSCmdlet.ParameterSetName) -eq 'FunctionsAndPermissions')) {
                    #  Perform function cleanup
                    If ($Overwrite) {
                        #  Show progress
                        Show-Progress -Status "Cleaning up function --> [$FunctionName]" -Loop
                        #  Cleanup function
                        Invoke-SQLCommand -ServerInstance $ServerInstance -Database $Database -Query $CleanupFunction -UseSQLAuthentication:$UseSQLAuthentication
                    }
                    #  Show progress
                    Show-Progress -Status "Installing function --> [$FunctionName]" -Loop
                    #  Install function
                    Invoke-SQLCommand -ServerInstance $ServerInstance -Database $Database -Query $InstallFunction -UseSQLAuthentication:$UseSQLAuthentication
                }

                ## Grant permissions
                If (($($PSCmdlet.ParameterSetName) -eq 'Permissions') -or ($($PSCmdlet.ParameterSetName) -eq 'FunctionsAndPermissions')) {
                    ## Correct Progress
                    $Script:Steps = $Script:Steps + $($Permissions.Count) - 1

                    ## Process permissions
                    ForEach ($Permission in $Permissions) {
                        #  Set variables
                        [string]$PermissionName = $($Permission.BaseName)
                        [string]$PermissionPath = $($Permission.FullName)
                        [string]$GrantPermission = Get-Content -Path $PermissionPath | Out-String
                        #  Show progress
                        Show-Progress -Status "Granting permission --> [$PermissionName]" -Loop
                        #  Grant permissions
                        Invoke-SQLCommand -ServerInstance $ServerInstance -Database $Database -Query $GrantPermission -UseSQLAuthentication:$UseSQLAuthentication
                    }
                }
            }
        }
        Catch {
            Throw
        }
        Finally {
            Write-Output $Table
        }
    }
}
#endregion

#endregion
##*=============================================
##* END FUNCTION LISTINGS
##*=============================================


##*=============================================
##* SCRIPT BODY
##*=============================================
#region ScriptBody

Try {

    ## Clear screen
    Clear-Host

    ## Show installation start
    Write-Verbose -Message 'Installation has started!'

    ## Check if the ReportingServicesTools powerhshell module is installed
    $TestReportingServicesTools = Get-Module -Name 'ReportingServicesTools' -ErrorAction 'SilentlyContinue'
    If (-not $TestReportingServicesTools -and -not $ExtensionsOnly) {
        #  Show progress
        Show-Progress -Status "Importing module --> [ReportingServicesTools]"
        #  Unblock Dependencies
        $Dependencies = Get-ChildItem -Path $DependenciesPath -Recurse -File
        ForEach ($Dependency in $Dependencies) {
            Show-Progress -Status "Unblocking dependency --> [$($Dependency.FullName)]" -Loop -Delay 100
            Unblock-File -Path $Dependency.FullName
        }
        #  Import ReportingServicesTools module
        [string]$ReportingServicesTools = Join-Path -Path $DependenciesPath -ChildPath 'ReportingServicesTools\0.0.6.7\ReportingServicesTools.psm1'
        Import-Module -Name $ReportingServicesTools
    }

    ## Install only sql extensions
    If ($($PSCmdlet.ParameterSetName) -eq 'ExtensionsOnly') {
        #  Show progress
        Show-Progress -Status "Installing only SQL Extensions -->"
        #  Installing extensions
        Add-RISQLExtension -Path $ExtensionsPath -ServerInstance $ServerInstance -Database $Database -UseSQLAuthentication:$UseSQLAuthentication -Overwrite:$OverWrite
    }

    ## Install without sql extensions
    ElseIf ($($PSCmdlet.ParameterSetName) -eq 'ExcludeExtensions') {
        #  Show progress
        Show-Progress -Status "Installing without SQL Extensions -->"
        #  Installing reports
        Install-RIReport -Path $Path -ReportServerUri $ReportServerUri -ReportFolder $ReportFolder -Overwrite:$OverWrite
        #  Set shared DataSources
        Set-RIDataSourceReference -Path $Path -ReportServerUri $ReportServerUri -DataSourceRoot $DataSourceRoot -DataSourceName $DataSourceName -FilterConnection $FilterConnection
        #  Granting CMDB required permissions
        Add-RISQLExtension -Path $ExtensionsPath -ServerInstance $ServerInstance -Database $Database -UseSQLAuthentication:$UseSQLAuthentication -PermissionsOnly
    }

    ## Install with sql extensions
    ElseIf ($($PSCmdlet.ParameterSetName) -eq 'IncludeExtensions') {
        #  Show progress
        Show-Progress -Status "Installing with SQL Extensions -->"
        #  Installing reports
        Install-RIReport -Path $Path -ReportServerUri $ReportServerUri -ReportFolder $ReportFolder -Overwrite:$OverWrite
        #  Set shared DataSources
        Set-RIDataSourceReference -Path $Path -ReportServerUri $ReportServerUri -DataSourceRoot $DataSourceRoot -DataSourceName $DataSourceName -FilterConnection $FilterConnection
        #  Installing helper function and granting CMDB required permissions
        Add-RISQLExtension -Path $ExtensionsPath -ServerInstance $ServerInstance -Database $Database -UseSQLAuthentication:$UseSQLAuthentication -Overwrite:$OverWrite
    }

    ## Show progress
    Show-Progress -Status "Installation Completed!" -Delay 1000 -Step $Steps
}
Catch {
    Throw
}

#endregion
##*=============================================
##* END SCRIPT BODY
##*=============================================