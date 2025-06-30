<#
.SYNOPSIS
    Build script for MEM.Zone-Dashboards release package.
.DESCRIPTION
    This build script creates a distribution package for MEM.Zone-Dashboards by copying
    source files, downloading the latest Install-SRSReport.ps1, and creating a zip archive.

    The script supports two parameter sets:
    - Manual:     Specify individual parameters for build configuration
    - ConfigFile: Use a JSON configuration file for build settings
.PARAMETER ProjectName
    [Manual] Specifies the name of the project.
    Default is: 'MEM.Zone-Dashboards'.
.PARAMETER SourcePath
    [Manual] Specifies the path to the source directory.
    Default is: 'src/MEM.Zone-Dashboards'.
.PARAMETER OutputPath
    [Manual] Specifies the output path for the build.
    Default is: 'build/output'.
.PARAMETER OutputFileName
    [Manual] Specifies the output file name.
    Default is: 'MEM.Zone-Dashboards.zip'.
.PARAMETER Version
    [Manual] Specifies the version number for the release.
    Default is: Current timestamp.
.PARAMETER IncludeVersion
    [Manual] Includes version number in the zip file name.
.PARAMETER Clean
    [Manual] Removes the build directory before creating the new build.
.PARAMETER ConfigFile
    [ConfigFile] Specifies the path to a JSON configuration file.
    Default is: 'Build-Config.json' in the script directory.
.EXAMPLE
    .\Build-Script.ps1
    Uses default configuration file (Build-Config.json) in script directory.
.EXAMPLE
    .\Build-Script.ps1 -ConfigFile 'Custom-Build.json'
    Uses a custom configuration file.
.EXAMPLE
    .\Build-Script.ps1 -Version "6.1.0" -IncludeVersion -Clean
    Uses manual parameters with version and clean build.
.INPUTS
    None.
.OUTPUTS
    None. Creates the distribution zip file.
.NOTES
    Created for MEM.Zone-Dashboards project
    Requires PowerShell 5.0 or later
    Automatically downloads latest Install-SRSReport.ps1 from official repository
.LINK
    https://MEMZ.one/Dashboards
.LINK
    https://github.com/MEM-Zone/MEM.Zone-Dashboards
.COMPONENT
    MEM.Zone-Dashboards Build System
.FUNCTIONALITY
    Build and Package MEM.Zone-Dashboards
#>

[CmdletBinding(DefaultParameterSetName = 'ConfigFile')]
param(
    [Parameter(ParameterSetName = 'Manual')]
    [ValidateNotNullOrEmpty()]
    [string]$ProjectName = 'MEM.Zone-Dashboards',

    [Parameter(ParameterSetName = 'Manual')]
    [string]$SourcePath,

    [Parameter(ParameterSetName = 'Manual')]
    [string]$OutputPath,

    [Parameter(ParameterSetName = 'Manual')]
    [string]$OutputFileName,

    [Parameter(ParameterSetName = 'Manual')]
    [string]$Version,

    [Parameter(ParameterSetName = 'Manual')]
    [switch]$IncludeVersion,

    [Parameter(ParameterSetName = 'Manual')]
    [switch]$Clean,

    [Parameter(ParameterSetName = 'ConfigFile')]
    [ValidateNotNullOrEmpty()]
    [string]$ConfigFile
)

## Set script requirements
#Requires -Version 5.0

##*=============================================
##* VARIABLE DECLARATION
##*=============================================
#region VariableDeclaration

## Set script variables
[version]$Script:Version     = [version]::new(1, 0, 0)
[string]$Script:Path         = $PSScriptRoot
[string]$Script:ProjectRoot  = Split-Path -Path $Script:Path -Parent
[datetime]$Script:BuildStart = Get-Date

## Declare build tracking variables
[System.Collections.Generic.List[string]]$Script:BuildErrors = [System.Collections.Generic.List[string]]::new()
[int]$ProcessedFiles    = 0
[int]$FailedFiles       = 0
[bool]$BuildSuccess     = $false
[bool]$ValidationPassed = $false
[hashtable]$BuildStats  = @{}

#endregion
##*=============================================
##* END VARIABLE DECLARATION
##*=============================================

##*=============================================
##* FUNCTION LISTINGS
##*=============================================
#region FunctionListings

#region function Test-BuildConfiguration
function Test-BuildConfiguration {
<#
.SYNOPSIS
    Validates build configuration object.
.DESCRIPTION
    Ensures all required configuration properties are present and valid
    in the provided configuration object.
.PARAMETER Config
    The configuration object to validate.
.INPUTS
    System.PSCustomObject
.OUTPUTS
    System.Bool
    True if configuration is valid, False otherwise.
.EXAMPLE
    Test-BuildConfiguration -Config $ConfigObject
.NOTES
    This is an internal script function and should typically not be called directly.
#>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Config
    )

    process {
        [string[]]$RequiredProperties = @('ProjectName')
        [string[]]$MissingProperties  = $RequiredProperties.Where({
            -not ($Config.PSObject.Properties.Name -contains $PSItem) -or [string]::IsNullOrWhiteSpace($Config.$PSItem)
        })

        if ($MissingProperties.Count -gt 0) {
            [string]$ErrorMessage = "Missing required configuration properties: $($MissingProperties -join ', ')"
            Write-Warning -Message $ErrorMessage
            $Script:BuildErrors.Add($ErrorMessage)
            return $false
        }

        Write-Verbose -Message 'Configuration validation completed successfully'
        return $true
    }
}
#endregion

#region function Copy-SourceFiles
function Copy-SourceFiles {
<#
.SYNOPSIS
    Copies source files to the build directory.
.DESCRIPTION
    Recursively copies all files from the source directory to the temporary build directory,
    excluding specified file/folder patterns.
.PARAMETER SourcePath
    The source directory path.
.PARAMETER DestinationPath
    The destination directory path.
.PARAMETER ExcludePatterns
    Array of glob patterns to exclude (from config).
.INPUTS
    System.String, System.String[]
.OUTPUTS
    System.Bool
    True if copy was successful, False otherwise.
.EXAMPLE
    Copy-SourceFiles -SourcePath 'src' -DestinationPath 'build/temp' -ExcludePatterns @('*.DS_Store*')
.NOTES
    This is an internal script function and should typically not be called directly.
#>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$SourcePath,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$DestinationPath,

        [Parameter()]
        [string[]]$ExcludePatterns = @()
    )

    try {
        Write-Verbose -Message "Copying files from [$SourcePath] to [$DestinationPath]"

        # Copy all files recursively
        $CopyParams = @{
            Path        = Join-Path -Path $SourcePath -ChildPath "*"
            Destination = $DestinationPath
            Recurse     = $true
            Force       = $true
        }

        Copy-Item @CopyParams

        # Remove excluded items using ExcludePatterns
        if ($ExcludePatterns.Count -gt 0) {
            Write-Verbose -Message "Cleaning up excluded files (ExcludePatterns)..."
            foreach ($Pattern in $ExcludePatterns) {
                $ItemsToRemove = Get-ChildItem -Path $DestinationPath -Recurse -Force | Where-Object { $_.Name -like $Pattern -or $_.FullName -like (Join-Path $DestinationPath $Pattern) }
                foreach ($Item in $ItemsToRemove) {
                    Write-Verbose -Message "  Removing: $($Item.FullName)"
                    Remove-Item -Path $Item.FullName -Force -Recurse
                }
            }
        }

        return $true
    }
    catch {
        [string]$ErrorMessage = "Failed to copy source files: $($PSItem.Exception.Message)"
        Write-Warning -Message $ErrorMessage
        $Script:BuildErrors.Add($ErrorMessage)
        return $false
    }
}
#endregion

#region function Get-InstallScript
function Get-InstallScript {
<#
.SYNOPSIS
    Downloads the latest Install-SRSReport.ps1 script.
.DESCRIPTION
    Downloads the latest version of Install-SRSReport.ps1 from the official repository
    and saves it to the specified path.
.PARAMETER Url
    The URL to download the script from.
.PARAMETER OutputPath
    The path where the script should be saved.
.INPUTS
    System.String
.OUTPUTS
    System.Bool
    True if download was successful, False otherwise.
.EXAMPLE
    Get-InstallScript -Url 'https://raw.githubusercontent.com/...' -OutputPath 'Install-SRSReport.ps1'
.NOTES
    This is an internal script function and should typically not be called directly.
#>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Url,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$OutputPath
    )

    try {
        Write-Verbose -Message "Downloading Install-SRSReport.ps1 from: [$Url]"

        # Use system default TLS settings for secure connection
        Invoke-WebRequest -Uri $Url -OutFile $OutputPath -UseBasicParsing
        Write-Verbose -Message "Successfully downloaded Install-SRSReport.ps1"

        return $true
    }
    catch {
        Write-Warning -Message "Failed to download Install-SRSReport.ps1: $($PSItem.Exception.Message)"
        Write-Verbose -Message "Using existing local copy if available..."
        return $false
    }
}
#endregion

#region function Get-Dependencies
function Get-Dependencies {
<##
.SYNOPSIS
    Downloads PowerShell modules listed in the config Dependencies section to the Dependencies folder.
.DESCRIPTION
    Downloads each module (with version if specified) using Save-Module to the specified path.
.PARAMETER OutputPath
    The path where the Dependencies folder should be created.
.PARAMETER Dependencies
    Array of hashtables with Name and optional Version for each module.
.INPUTS
    System.String, System.Object[]
.OUTPUTS
    System.Bool
    True if download was successful, False otherwise.
.EXAMPLE
    Get-Dependencies -OutputPath 'C:\Build\Dependencies' -Dependencies $Dependencies
.NOTES
    This is an internal script function and should typically not be called directly.
#>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$OutputPath,
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [object[]]$Dependencies
    )
    try {
        foreach ($dep in $Dependencies) {
            $name = $dep.Name
            $ver = $dep.Version
            if ($ver -and $ver -ne "") {
                Write-Verbose -Message "Downloading $name ($ver) to Dependencies..."
                Save-Module -Name $name -Path $OutputPath -RequiredVersion $ver -Force
            } else {
                Write-Verbose -Message "Downloading $name (latest) to Dependencies..."
                Save-Module -Name $name -Path $OutputPath -Force
            }
        }
        Write-Verbose -Message "Successfully downloaded all dependencies"
        return $true
    }
    catch {
        Write-Warning -Message "Failed to download dependencies: $($PSItem.Exception.Message)"
        Write-Verbose -Message "Using existing local copy if available..."
        return $false
    }
}
#endregion

#region function Clear-SensitiveData
function Clear-SensitiveData {
<#
.SYNOPSIS
    Removes sensitive information from report and SQL files.
.DESCRIPTION
    Cleans up report files by removing sensitive DataSourceReference and ReportServerUrl entries,
    and replaces specific CollectionID values with generic ones. Also sanitizes SQL files.
.PARAMETER Path
    The path to the directory containing .rdl and .sql files to sanitize.
.INPUTS
    System.String
.OUTPUTS
    System.Bool
    True if cleanup was successful, False otherwise.
.EXAMPLE
    Clear-SensitiveData -Path 'C:\Build\Reports'
.NOTES
    This is an internal script function and should typically not be called directly.
#>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Path
    )

    try {
        Write-Verbose -Message "Cleaning sensitive data from files..."

        # Get all .rdl and .sql files
        $FilesToClean = Get-ChildItem -Path $Path -Include "*.rdl", "*.sql" -Recurse
        $CleanedCount = 0

        foreach ($File in $FilesToClean) {
            Write-Verbose -Message "Processing file: $($File.Name)"

            # Read the file content
            $Content = Get-Content -Path $File.FullName -Raw -Encoding UTF8
            $OriginalContent = $Content

            # Clean .rdl files
            if ($File.Extension -eq ".rdl") {
                # Remove sensitive DataSourceReference entries
                $Content = $Content -replace '(<DataSourceReference>).*?(</DataSourceReference>)', '$1$2'

                # Remove ReportServerUrl entries
                $Content = $Content -replace '(<rd:ReportServerUrl>).*?(</rd:ReportServerUrl>)', '$1$2'

            }

            # Clean both .rdl and .sql files
            # Replace CollectionID values with generic SMS0001 (case-insensitive)
            $Content = $Content -replace "(?i)(@collectionid\s+AS\s+NVARCHAR\(\d+\)\s*=\s*')([^']*)(')", "`$1SMS0001`$3"

            # Write the cleaned content back to the file if changes were made
            if ($Content -ne $OriginalContent) {
                Set-Content -Path $File.FullName -Value $Content -Encoding UTF8 -NoNewline
                $CleanedCount++
            }
        }

        Write-Verbose -Message "Successfully cleaned sensitive data from $CleanedCount of $($FilesToClean.Count) files"
        return $true
    }
    catch {
        Write-Warning -Message "Failed to clean sensitive data: $($PSItem.Exception.Message)"
        return $false
    }
}
#endregion

#region function Update-ReportVersion
function Update-ReportVersion {
<#
.SYNOPSIS
    Updates version information in report files.
.DESCRIPTION
    Updates the version and date in ReportParameter sections of .rdl files
    with the current build version and date.
.PARAMETER Path
    The path to the directory containing .rdl files to update.
.PARAMETER Version
    The version string to use in the reports.
.INPUTS
    System.String
.OUTPUTS
    System.Bool
    True if update was successful, False otherwise.
.EXAMPLE
    Update-ReportVersion -Path 'C:\Build\Reports' -Version '6.1.0'
.NOTES
    This is an internal script function and should typically not be called directly.
#>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Path,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Version
    )

    try {
        Write-Verbose -Message "Updating version information in reports..."

        # Get all .rdl files
        $ReportFiles = Get-ChildItem -Path $Path -Filter "*.rdl" -Recurse
        $UpdatedCount = 0

        foreach ($ReportFile in $ReportFiles) {
            Write-Verbose -Message "Processing report: $($ReportFile.Name)"

            # Read the report content
            $Content = Get-Content -Path $ReportFile.FullName -Raw -Encoding UTF8
            $OriginalContent = $Content

            # Get current date in the format used in reports
            $CurrentDate = Get-Date -Format "yyyy-MM-dd"

            # Update version parameter with current version and date
            $NewVersionString = "v$Version - $CurrentDate"
            $Content = $Content -replace '<Value>v\d+\.\d+\.\d+\s*-\s*\d{4}-\d{2}-\d{2}</Value>', "<Value>$NewVersionString</Value>"

            # Write the updated content back to the file if changes were made
            if ($Content -ne $OriginalContent) {
                Set-Content -Path $ReportFile.FullName -Value $Content -Encoding UTF8 -NoNewline
                $UpdatedCount++
            }
        }

        Write-Verbose -Message "Successfully updated version in $UpdatedCount of $($ReportFiles.Count) reports"
        return $true
    }
    catch {
        Write-Warning -Message "Failed to update report versions: $($PSItem.Exception.Message)"
        return $false
    }
}
#endregion

#region function New-ZipArchive
function New-ZipArchive {
<#
.SYNOPSIS
    Creates a zip archive from the specified directory.
.DESCRIPTION
    Uses .NET compression to create a zip file from all contents of the source directory.
.PARAMETER SourcePath
    The source directory to compress.
.PARAMETER ZipPath
    The output zip file path.
.INPUTS
    System.String
.OUTPUTS
    System.Bool
    True if zip creation was successful, False otherwise.
.EXAMPLE
    New-ZipArchive -SourcePath 'build/temp' -ZipPath 'build/output/Package.zip'
.NOTES
    This is an internal script function and should typically not be called directly.
#>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$SourcePath,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ZipPath
    )

    try {
        Write-Verbose -Message "Creating zip archive: [$ZipPath]"

        # Remove existing zip file if it exists
        if (Test-Path $ZipPath) {
            Remove-Item -Path $ZipPath -Force
        }

        # Use .NET compression for better compatibility
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        [System.IO.Compression.ZipFile]::CreateFromDirectory($SourcePath, $ZipPath, [System.IO.Compression.CompressionLevel]::Optimal, $false)

        return $true
    }
    catch {
        [string]$ErrorMessage = "Failed to create zip archive: $($PSItem.Exception.Message)"
        Write-Warning -Message $ErrorMessage
        $Script:BuildErrors.Add($ErrorMessage)
        return $false
    }
}
#endregion

#region function Write-BuildSummary
function Write-BuildSummary {
<#
.SYNOPSIS
    Displays a comprehensive build summary report.
.DESCRIPTION
    Shows detailed statistics about the build process including timing,
    file counts, errors, and output information.
.PARAMETER BuildStats
    Hashtable containing build statistics and results.
.INPUTS
    System.Hashtable
.OUTPUTS
    None.
.EXAMPLE
    Write-BuildSummary -BuildStats $BuildStatsHashtable
.NOTES
    This is an internal script function and should typically not be called directly.
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$BuildStats
    )

    [string]$StatusIcon = if ($BuildStats.Success) { '✓' } else { '✗' }
    [ConsoleColor]$StatusColor = if ($BuildStats.Success) { 'Green' } else { 'Red' }
    [string]$Separator = '=' * 60

    Write-Host -Message "`n$Separator" -ForegroundColor Cyan
    Write-Host -Message "BUILD SUMMARY $StatusIcon" -ForegroundColor $StatusColor
    Write-Host -Message $Separator -ForegroundColor Cyan

    Write-Host -Message "Project Name     : $($BuildStats.ProjectName)"      -ForegroundColor White
    Write-Host -Message "Author           : $($BuildStats.Author)"             -ForegroundColor White
    Write-Host -Message "Version          : $($BuildStats.Version)"          -ForegroundColor White
    Write-Host -Message "Build Time       : $($BuildStats.BuildTime)"        -ForegroundColor White
    Write-Host -Message "Processed Files  : $($BuildStats.ProcessedFiles)"   -ForegroundColor White
    Write-Host -Message "Failed Files     : $($BuildStats.FailedFiles)"      -ForegroundColor $(if ($BuildStats.FailedFiles -gt 0) { 'Yellow' } else { 'Green' })
    Write-Host -Message "Uncompressed Size: $($BuildStats.UncompressedSize) MB" -ForegroundColor White
    Write-Host -Message "Compressed Size  : $($BuildStats.CompressedSize) MB"   -ForegroundColor White
    Write-Host -Message "Compression Ratio: $($BuildStats.CompressionRatio)%"   -ForegroundColor White
    Write-Host -Message "Output Path      : $($BuildStats.OutputPath)"       -ForegroundColor Cyan

    if ($BuildStats.Errors.Count -gt 0) {
        Write-Host -Message "`nBUILD ERRORS:" -ForegroundColor Red
        $BuildStats.Errors | ForEach-Object { Write-Host -Message "  • $PSItem" -ForegroundColor Red }
    }

    Write-Host -Message $Separator -ForegroundColor Cyan
    Write-Host -Message $(if ($BuildStats.Success) { 'Build completed successfully!' } else { 'Build failed with errors!' }) -ForegroundColor $StatusColor
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

try {
    [string]$Separator = '=' * 60
    Write-Host -Message "`n$Separator" -ForegroundColor Cyan
    Write-Host -Message "MEM.Zone-Dashboards BUILD SCRIPT $Script:Version 🚀" -ForegroundColor Green
    Write-Host -Message "$Separator`n" -ForegroundColor Cyan

    ## Load Configuration and merge with parameters using splatting
    [string]$DefaultConfigFile = Join-Path -Path $PSScriptRoot -ChildPath 'Build-Config.json'
    [string]$ConfigFileToUse = if ($PSCmdlet.ParameterSetName -eq 'ConfigFile' -and $ConfigFile) { $ConfigFile } else { $DefaultConfigFile }

    # Initialize build parameters hashtable with defaults
    [hashtable]$BuildParams = @{
        ProjectName       = 'MEM.Zone-Dashboards'
        SourcePath        = 'src/MEM.Zone-Dashboards'
        OutputPath        = 'build/output'
        OutputFileName    = 'MEM.Zone-Dashboards.zip'
        Version           = Get-Date -Format "yyyy.MM.dd.HHmm"
        IncludeVersion    = $false
        Clean             = $false
        ExcludePatterns   = @()
        InstallScriptUrl  = 'https://raw.githubusercontent.com/MEM-Zone/MEM.Zone-Install-SRSReport/main/Install-SRSReport/Install-SRSReport.ps1'
    }

    # Load config file if it exists and merge with defaults
    if (Test-Path -Path $ConfigFileToUse -PathType Leaf) {
        Write-Verbose -Message "Loading configuration from: [$ConfigFileToUse]"
        [PSCustomObject]$Config = Get-Content -Path $ConfigFileToUse -Raw | ConvertFrom-Json

        if ($PSCmdlet.ParameterSetName -eq 'ConfigFile') {
            if (-not (Test-BuildConfiguration -Config $Config)) {
                throw 'Configuration validation failed'
            }
        }

        # Merge config file values into build parameters
        $Config.PSObject.Properties | ForEach-Object {
            if ($BuildParams.ContainsKey($_.Name)) {
                $BuildParams[$_.Name] = $_.Value
            }
        }

        Write-Verbose -Message 'Configuration loaded and merged successfully'
    } elseif ($PSCmdlet.ParameterSetName -eq 'ConfigFile') {
        throw "Configuration file not found: [$ConfigFileToUse]"
    } else {
        Write-Verbose -Message "Config file not found: [$ConfigFileToUse] - using defaults"
    }

    # Override with explicitly provided parameters
    $PSBoundParameters.GetEnumerator() | ForEach-Object {
        if ($BuildParams.ContainsKey($_.Key)) {
            $BuildParams[$_.Key] = $_.Value
        }
    }

    # Extract final parameter values using splatting
    $ProjectName      = $BuildParams.ProjectName
    $Author           = $Config.Author
    $SourcePath       = $BuildParams.SourcePath
    $OutputPath       = $BuildParams.OutputPath
    $OutputFileName   = $BuildParams.OutputFileName
    $Version          = $BuildParams.Version
    $IncludeVersion   = $BuildParams.IncludeVersion
    $Clean            = $BuildParams.Clean
    $ExcludePatterns  = $Config.ExcludePatterns
    $InstallScriptUrl = $BuildParams.InstallScriptUrl

    ## Resolve paths relative to project root
    [string]$SourcePathResolved = if ([System.IO.Path]::IsPathRooted($SourcePath)) { $SourcePath } else { Join-Path -Path $Script:ProjectRoot -ChildPath $SourcePath }
    [string]$OutputPathResolved = if ([System.IO.Path]::IsPathRooted($OutputPath)) { $OutputPath } else { Join-Path -Path $Script:ProjectRoot -ChildPath $OutputPath }
    [string]$TempBuildPath = Join-Path -Path $OutputPathResolved -ChildPath 'temp'
    [string]$ZipOutputPath = Join-Path -Path $Script:ProjectRoot -ChildPath 'output'

    ## For direct copy mode (no zip), we don't need filename manipulation
    [string]$ZipFilePath = $null

    ## Display Build Information
    Write-Host -Message "Project Name  : $ProjectName" -ForegroundColor Gray
    Write-Host -Message "Author        : $Author" -ForegroundColor Gray
    Write-Host -Message "Source Path   : $SourcePathResolved" -ForegroundColor Gray
    Write-Host -Message "Output Path   : $OutputPathResolved" -ForegroundColor Gray
    Write-Host -Message "Version       : $Version" -ForegroundColor Gray
    Write-Host -Message ""

    ## Validate source directory exists
    if (-not (Test-Path -Path $SourcePathResolved -PathType Container)) {
        throw "Source directory not found: [$SourcePathResolved]"
    }

    ## Clean build directory if requested
    if ($Clean -and (Test-Path $OutputPathResolved)) {
        Write-Host -Message '--> Cleaning build directory...' -ForegroundColor Yellow
        Remove-Item -Path $OutputPathResolved -Recurse -Force
    }

    ## Clean output directory if requested
    if ($Clean -and (Test-Path $ZipOutputPath)) {
        Write-Host -Message '--> Cleaning output directory...' -ForegroundColor Yellow
        Remove-Item -Path $ZipOutputPath -Recurse -Force
    }

    ## Create output directories
    if (-not (Test-Path $OutputPathResolved)) {
        Write-Host -Message '--> Creating output directory...' -ForegroundColor Yellow
        New-Item -Path $OutputPathResolved -ItemType Directory -Force | Out-Null
    }

    ## Create temporary build directory
    if (Test-Path $TempBuildPath) {
        Remove-Item -Path $TempBuildPath -Recurse -Force
    }
    New-Item -Path $TempBuildPath -ItemType Directory -Force | Out-Null

    ## Update version information in source reports first
    Write-Host -Message '--> Updating version information in source reports...' -ForegroundColor Yellow
    [string]$SourceReportsPath = Join-Path -Path $SourcePathResolved -ChildPath 'Reports'
    if (Test-Path $SourceReportsPath) {
        $null = Update-ReportVersion -Path $SourceReportsPath -Version $Version
        Write-Verbose -Message "Successfully updated version information in source reports"
    } else {
        Write-Warning -Message "Source reports folder not found: [$SourceReportsPath]"
    }

    ## Clean sensitive data from source files
    Write-Host -Message '--> Cleaning sensitive data from source files...' -ForegroundColor Yellow
    if (Test-Path $SourcePathResolved) {
        $null = Clear-SensitiveData -Path $SourcePathResolved
        Write-Verbose -Message "Successfully cleaned sensitive data from source files"
    } else {
        Write-Warning -Message "Source path not found: [$SourcePathResolved]"
    }

    ## Copy source files directly to output directory
    Write-Host -Message '--> Copying source files to output directory...' -ForegroundColor Yellow
    if (-not (Copy-SourceFiles -SourcePath $SourcePathResolved -DestinationPath $OutputPathResolved -ExcludePatterns $ExcludePatterns)) {
        throw 'Failed to copy source files'
    }

    ## Download latest Install-SRSReport.ps1
    Write-Host -Message '--> Downloading latest Install-SRSReport.ps1...' -ForegroundColor Yellow
    [string]$InstallScriptPath = Join-Path -Path $OutputPathResolved -ChildPath 'Install-SRSReport.ps1'
    $null = Get-InstallScript -Url $InstallScriptUrl -OutputPath $InstallScriptPath

    ## Download latest Dependencies
    Write-Host -Message '--> Downloading latest Dependencies...' -ForegroundColor Yellow
    [string]$DependenciesPath = Join-Path -Path $OutputPathResolved -ChildPath 'Dependencies'
    if (-not (Get-Dependencies -OutputPath $DependenciesPath -Dependencies $Config.Dependencies)) {
        throw 'Failed to download Dependencies'
    }

    ## Copy docs folder from root
    Write-Host -Message '--> Copying docs folder from root...' -ForegroundColor Yellow
    [string]$RootDocsPath = Join-Path -Path $Script:ProjectRoot -ChildPath 'docs'
    [string]$OutputDocsPath = Join-Path -Path $OutputPathResolved -ChildPath 'docs'
    if (Test-Path $RootDocsPath) {
        Copy-Item -Path $RootDocsPath -Destination $OutputDocsPath -Recurse -Force
        Write-Verbose -Message "Successfully copied docs folder from root"
    } else {
        Write-Warning -Message "Root docs folder not found: [$RootDocsPath]"
    }

    ## Copy README.md from root
    Write-Host -Message '--> Copying README.md from root...' -ForegroundColor Yellow
    [string]$RootReadmePath = Join-Path -Path $Script:ProjectRoot -ChildPath 'README.md'
    [string]$OutputReadmePath = Join-Path -Path $OutputPathResolved -ChildPath 'README.md'
    if (Test-Path $RootReadmePath) {
        Copy-Item -Path $RootReadmePath -Destination $OutputReadmePath -Force
        Write-Verbose -Message "Successfully copied README.md from root"
    } else {
        Write-Warning -Message "Root README.md file not found: [$RootReadmePath]"
    }

    ## Create output directory for zip file
    if (-not (Test-Path $ZipOutputPath)) {
        Write-Host -Message '--> Creating output directory...' -ForegroundColor Yellow
        New-Item -Path $ZipOutputPath -ItemType Directory -Force | Out-Null
    }

    ## Create zip file with version in filename
    Write-Host -Message '--> Creating zip archive...' -ForegroundColor Yellow
    [string]$ZipFileName = "MEM.Zone-Dashboards_v$Version.zip"
    [string]$ZipFilePath = Join-Path -Path $ZipOutputPath -ChildPath $ZipFileName

    if (-not (New-ZipArchive -SourcePath $OutputPathResolved -ZipPath $ZipFilePath)) {
        throw 'Failed to create zip archive'
    }

    ## Get file statistics
    $AllFiles = Get-ChildItem -Path $OutputPathResolved -Recurse -File
    $ProcessedFiles = $AllFiles.Count
    $TotalSize = [math]::Round(($AllFiles | Measure-Object -Property Length -Sum).Sum / 1MB, 2)

    # Get zip file size
    $ZipSize = if (Test-Path $ZipFilePath) { [math]::Round((Get-Item $ZipFilePath).Length / 1MB, 2) } else { 0 }
    $CompressionRatio = if ($TotalSize -gt 0) { [math]::Round((($TotalSize - $ZipSize) / $TotalSize) * 100, 1) } else { 0 }

    Write-Host -Message "Copied $ProcessedFiles files ($TotalSize MB)" -ForegroundColor Green
    Write-Host -Message "Build output: $OutputPathResolved" -ForegroundColor Green
    Write-Host -Message "Zip file created: $ZipFilePath ($ZipSize MB)" -ForegroundColor Green
    $BuildSuccess = $true
    $ValidationPassed = $true
}
catch {
    [string]$ErrorMessage = "Build process failed: $($PSItem.Exception.Message)"
    Write-Warning -Message $ErrorMessage
    $Script:BuildErrors.Add($ErrorMessage)
    $BuildSuccess = $false
    throw
}
finally {
    ## Clean up temporary directory
    if (Test-Path $TempBuildPath) {
        Write-Host -Message '--> Cleaning up temporary files...' -ForegroundColor Yellow
        Remove-Item -Path $TempBuildPath -Recurse -Force
    }

    ## Calculate Build Statistics
    [timespan]$BuildDuration = (Get-Date) - $Script:BuildStart
    [string]$FormattedBuildTime = $BuildDuration.ToString('mm\:ss\.fff')

    ## Populate build statistics
    $BuildStats = @{
        ProjectName        = $ProjectName
        Author             = $Author
        Version            = $Version
        BuildTime          = $FormattedBuildTime
        ProcessedFiles     = $ProcessedFiles
        FailedFiles        = $FailedFiles
        UncompressedSize   = if ($TotalSize) { $TotalSize } else { 0 }
        CompressedSize     = if ($ZipSize) { $ZipSize } else { 0 }
        CompressionRatio   = if ($CompressionRatio) { $CompressionRatio } else { 0 }
        OutputPath         = if ($ZipFilePath) { $ZipFilePath } else { $OutputPathResolved }
        Success            = $BuildSuccess -and ($FailedFiles -eq 0)
        Errors             = $Script:BuildErrors.ToArray()
    }

    ## Write build summary
    Write-BuildSummary -BuildStats $BuildStats
}

#endregion
##*=============================================
##* END SCRIPT BODY
##*=============================================
