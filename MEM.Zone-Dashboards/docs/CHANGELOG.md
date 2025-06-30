# Changelog for MEM.Zone-Dashboards

## 7.0.0 - 2025-06-30

* Fixed `ufn_CM_GetNextMaintenanceWindowForDevice` function `has too many parameters` error [#36](https://github.com/MEM-Zone/MEM.Zone-Dashboards/issues/36). @Zombierbone
* Added `Build-Script.ps1` and `Build-Config.json` to automate the process of preparing the dashboards and reports for distribution.
* Added automatic Dependencies download in the build script.
* Added automatic sanitization in the build script to clean sensitive data from reports and SQL files.
* Added automatic `Version` management.
* Bumped `ReportingServicesTools` module version to `0.0.9.3` in the dependencies for offline installation.
* Restructured and simplified folder structure to match the new build script requirements.
* Updated `README.md` with build instructions and prerequisites.

## 6.1.0 - 2025-06-24

* Updated `Software Update - Compliance by Collection` with optimized query and performance improvements.
* Updated `Software Update - Compliance by Device` with optimized query and performance improvements.
* Added `ufn_CM_DeviceIPAddress` extension function to retrieve device IP addresses.
* Added `ufn_CM_DeviceOSInfo` extension function to retrieve device OS information.
* Added `ufn_CM_GetNextMaintenanceWindowForCollection` function to retrieve the next maintenance window for a collection.
* Added `ufn_CM_GetNextMaintenanceWindowForDevice` function to retrieve the next maintenance window for a device.

## 6.0.0 - 2025-06-18

* Updated `Software Update - Compliance by Collection` with optimized query and performance improvements.
* Updated `Software Update - Compliance by Device` with optimized query and performance improvements.
* Added `Software Update Groups` to `Software Update - Compliance by Collection` report.
* Added `Software Update Groups` to `Software Update - Compliance by Device` report.

## 5.1.4 - 2025-06-08

* Fixed `<>` typos in `Software Update - Compliance by Collection` (#45) @Zombierbone.

## 5.1.3 - 2025-06-03

* Fixed `<` `>` typos in `Software Update - Compliance by Collection` (#45) @Zombierbone.
* Added some performance optimizations to `Software Update - Compliance by Collection`.
* Removed out of support windows version normalization in `Software Update - Compliance by Collection` to improve performance.
* Fixed some typos in the `ufn_CM_GetNextMaintenanceWindow` function.

## 5.1.2 - 2024-07-14

* Fixed `IsGMTTime` error in `Software Update - Compliance by Collection` @Steve Mckee.

## 5.1.1 - 2024-05-30

* Updated buitin help.

## 5.1.0 - 2024-05-30

* Added `IsServiceWindowOpen` to `ufn_CM_GetNextMaintenanceWindow`.
* Renamed `IsGMTTime` to `IsUTC` in `ufn_CM_GetNextMaintenanceWindow`.
* Added `ufn_CM_GetNextMaintenanceWindowForCollection` function.
* Added `ufn_CM_GetNextMaintenanceWindowForDevice` function.

## 5.0.5 - 2024-02-02

* Fixed variable bug `Next Maintenance Window` if using `Offset Days` maintenance windows (issue #31).

## 5.0.4 - 2024-01-30

* Fixed `Next Maintenance Window` if using `Offset Days` maintenance windows #31.

## 5.0.3 - 2023-10-02

* Updated shorlink domain from `MEM.Zone` to `MEMZ.one`

## 5.0.2 - 2021-10-15

* Fix duplicate entries in the `Operating System - Windows 11 Readiness` report.

## 5.0.1 - 2021-10-14

* Included `ReportingServicesTools` dependency in the package for the `Install-SRSReport` script.
* Minor Documentation additions.
* Changed `Operating System - Windows 11 Readiness` to `Operating System - Windows 11 Readiness by Collection`.

## 5.0.0 - 2021-10-13

* Added `Operating System - Version Compliance by Collection` report.
* Added `Bitlocker - Compliance by Collection (MBAM)` report.
* Added `Operating System - Windows 11 Readiness` report.
* Added Version in all reports
* Fixed all known issues in the `Bitlocker - Compliance by Collection` report.
* Fixed `Scan Unknown` display gauge in `Software Update - Scan Status by Collection` report.
* Fixed all known visual overlap issues in all reports.
* Reverted Dashboard pie label to `Internal` for better visibility.
* Improved `GetStatus()` function by externalizing `States` as variables in the affected reports.
* Improved `Scan State` handling in `Software Update - Scan Status by Collection` report.

## 4.1.1 - 2020-11-18

* Added null fields descriptors for the `Bitlocker - Compliance by Collection` report.
* Fixed `Compliant` user sorting

## 4.1.0 - 2020-11-18

* Changed `Bitlocker - Compliance by Collection` layout
* Changed 12 hour to 24 hours in all reports
* Added `Pending Policy Status` to `Bitlocker - Compliance by Collection`
* Added `Bitlocker Policy` to `Bitlocker - Compliance by Collection`
* Fixed `Bitlocker - Compliance by Collection` can now be run on any collection. Only devices that have the policy assigned will be displayed.
* Fixed `Compliant` now shows `Unknown` if NULL in `Bitlocker - Compliance by Collection`
* Fixed `Unknown` count on the `OS Drive Decrypted` gauge in `Bitlocker - Compliance by Collection`
* Fixed various summarization errors in `Bitlocker - Compliance by Collection`

## 4.0.0 - 2020-10-09

* Changed branding and links to `MEM.Zone Dashboards`
* Changed dashboard gauges to make their function clearer
* Changed naming schema for all reports and removed abbreviations to make them more understandable
* Changed dashboard graph titles to make them more understandable
* Changed `GetHealth/ScanStatus()` vb functions merged into a single `GetStatus()` function
* Changed dashboard graphs show now percentage when it doesn't make sense to display numbers.
* Changed `KB2267602 - Microsoft Intelligence Updates` are now excluded by default.
* Changed `Sup Sync Time` to ISO 8601 like the rest of time formats
* Changed `Uptime` and `Last Update Scan` to Days instead of Date. You can still see the Date in the tooltip
* Fixed a crazy number counting errors in totals, graphs and gauges
* Fixed `Missing Unique Updates By Category` numbers and percentages. They were way off from the beginning
* Fixed `Scan is waiting for catalog location` graph color
* Fixed `Header Rows` should now be displayed on all report pages. I don't know why this doesn't stick!!!
* Added `Bitlocker - Compliance by Collection` report
* Added `Rendering Time` on all reports
* Added `Help` on all reports
* Added `GetValueBetweenStrings()` vb function to clean up MP/CMG name
* Added `Summarization` option to most reports for displaying less info when needed. `Summatization On` is the default.
* Added `Deployment Enabled` filtering in all reports
* Added `Deployment Enabled` column in `Software Update Compliance by Device Changes`
* Added `Update Dashboard` percentage in tooltips in addition to numbers
* Added tooltips to gauges in order to be able to see the numbers even if they are low. Previously you had to find the sweet spot if the percentage was at the end of the scale
* Added conversion from or to `UTC` in where possible
* Added `UTC` in tooltips when time is UTC
* Added some code optimizations to improve performance
* Added or fixed some stuff that I can't remember now. (Yes, I know I suck at change management)

## 3.0.1 - 2020-07-21

* Changed `README.md` location is now located in `docs`
* Updated requirements and some of the docs
* Removed some SQL nonsense from the `ufn_CM_GetNextMaintenanceWindow`

## 3.0.0 - 2020-07-17

### SU Compliance by Collection Changes (3.0.0)

* Fixed `Total` value on gauges percentage tooltips and tablix now display the correct value
* Fixed squashed page number
* Fixed maintenance window not displaying on some systems
* Fixed expired maintenance window is now displaying correctly
* Fixed header rows are now properly displayed on all report pages #19 (For real now!)
* Changed `ufn_CM_GetNextMaintenanceWindow` also returns `StartTime`
* Changed `Last Boot Time` to `Uptime (Days)`
* Changed `Last Update Scan Time` to `Last Update Scan (Days)`
* Changed `Health Status` to display Health Check Values instead of `Yes` / `No`
* Changed `Pending Restart` to display `Restart Reason` instead of `Yes` / `No`
* Changed some column widths to improve readability
* Added `Free Space (GB)` column
* Added `Last Boot Time` to `Uptime` value as tooltip
* Added `Last Update Scan Time` to `Last Update Scan (Days)` value as tooltip
* Added `Total Devices` on the top of the report
* Added maintenance window state support
* Added `Disabled Maintenance Window`, `Short Maintenance Window`, `Uptime Threshold Exeeded`, `Required VS Uptime`, `Free Space Threshold Exeeded` health checks
* Added `Health Thresholds` for `Distant Maintenance Window`, `Short Maintenance Window`, `Last Scan Time`, `Uptime`, `Free Space`
* Added `Health Thresholds` csv report parameter so the values are not hardcoded
* Added `Health States` descriptions as a `Health State` value tooltip
* Added Query optimizations
* Removed `Total` tool tip from all gauge name descriptions

### SU Compliance by Device Changes (3.0.0)

* Fixed `Total` value on gauges percentage tooltips and tablix now display the correct value
* Fixed header rows are now properly displayed on all report pages #19 (For real now!)
* Fixed squashed page number
* Added `Total Updates` on the top of the report
* Removed `Total` tool tip from all gauge name descriptions

## SU Scan Status by Collection Changes (3.0.0)

* Fixed report crash when devices use a CMG
* Fixed `Total` value on gauges percentage tooltips and tablix now display the correct value
* Fixed header rows are now properly displayed on all report pages #19 (For real now!)
* Fixed squashed page number
* Changed `Last Update Scan Time` to `Last Update Scan (Days)`
* Changed `Health Status` to display Health Check Values instead of `Yes` / `No`
* Added `Total Updates` on the top of the report
* Added `Last Update Scan Time` to `Last Update Scan (Days)` value as tooltip
* Added Query optimizations
* Removed `Total` tool tip from all gauge name descriptions

## AL Alerts Changes (3.0.0)

* Fixed `Total` value on gauges percentage tooltips and tablix now display the correct value
* Fixed squashed page number
* Fixed `Name` null value if update group is deleted
* Added `Total Alerts` on the top of the report
* Removed `Total` tool tip from all gauge name descriptions

## 2.3.0 - 2020-06-10

* Added `Update Vendor` support for `3rd party` update filtering #21
* Fixed `SU Scan Status by Collection` is not devices without client #24
* Fixed `Unknown scan state` actionable chart action error #23
* Fixed the number of updates showing up in `Devices Missing a Specific Update` by limiting them to `TOP 30` #22
* Fixed some others small bug or inconsistencies, replaced some functions with the `RBAC` versions
* Improved performance by not letting SQL convert to `NVARCHAR` where not needed #25

## 2.2.1 - 2020-05-18

* Added `Expired Maintenance Window` status #20
* Header rows are now properly displayed on all report pages #19

## 2.2.0 - 2020-03-23

### SU DAS Overall Compliance v2.2.0

* Removed page number
* Changed the `Update Scan States` chart from pie to bar, #14
* Switched the Update Scan Stated with the `Overall Group Compliance` chart
* Ordered the `Update Scan States` char by number of devices per state

### SU Compliance by Collection v2.2.0

* Moved helper function to standalone field improving render performance
* Added indicator and link to help for SQL helper function in `SU Compliance by Collection`

### All Reports v2.2.0

* Removed space in header for all reports, maximizing viewing area

### Install-SRSReport 1.1.3 - 2020-03-26

* Fixed default parameters #16, all required parameters will be requested if running the script without parameters
* Fixed report upload when non report files are present in the upload folder
* Fixed incorrect `Add-RISQLExtension` parameter set names
* Added `Show-Progress` function
* Added progress indicators
* Install module will always show verbose info
* Removed warning messages
* Removed default `ReportFolder` parameter value
* Updated description links
* Added clear screen before script start
* Added new gif preview

## 2.1.5 - 2020-03-16

* Moved to standalone installer
* Deleted old installer references

## 2.1.4 - 2020-03-16

* Fixed crash when `LastScanPackageLocation` is NULL in `SU Scan Status by Collection` (Issue #18)

## 2.1.3 - 2020-03-12

* Fixed navigation path for the `Update Scan States` piechart

## 2.1.2 - 2020-03-02

* Fixed FQDN not displaying when System Discovery is not enabled
* Fixed dashboard chart axis numbering

## 2.1.1 - 2020-02-11

* Updated README.md with navigation and build tree

## 2.1.0 - 2020-02-11

* Added run as administrator requirement
* Fixed `Invoke-SQL` not connecting to the SQL server due to bad connection string
* Fixed `Add-RISQLExtension` not getting the right parameter set and skipping permissions extensions
* Don't check for `ReportingServicesTools` module if `-ExtensionsOnly` switch is used
* Fix script name in `README.md`
* Fix install parameters in `README.md`

## 2.0.1 - 2020-02-10

* Added check and installation for `ReportingServicesTools` module.

## 2.0.0 - 2020-02-10

* Created a dashboard PowerShell installer issue [#6](#6)
* Fixed Dashboard and SU Compliance reports not working issue [#5](#5). RS path is now computed from variables instead of the RS DB.
* Moved the permission block to a separate file issue [#9](#9)
* Commented database references from prerequisite files
* Removed `GO` statements from prerequisite files
* Report files have been moved to the `Reports` folder to match the installer defaults
* Prerequisites have been moved to the `Extensions` folder to match the installer defaults

## 1.1.1-beta - 2020-01-22

* Fixed issue [#4](#4)

## 1.1.0-beta - 2020-01-16

* SU Scan Status by Collection is now final
* Added StateID to SU DAS Overall Compliance in order to make the Scan State graph actionable
* Added issues and git links
* Fixed issue [#2](https://github.com/SCCM-Zone/Dashboards/issues/2)
* Fixed issue [#3](https://github.com/SCCM-Zone/Dashboards/issues/3)
* Minor layout changes in SU Compliance by Collection
* Minor code layout changes

## 1.0.0-beta - 2020-01-13

### Released in this version

* Software update Dashboard
* Software update compliance by collection
* Software update compliance by device
* System wide alerts
* SUP sync status

## 1.0.1-beta - 2020-01-13

* Added more documentation and reorganized folder structure
* Readme is now added to src folder
* Implemented releases in git

## 1.0.2-beta - 2020-01-13

* Git badges to README.MD
* Added discord channel

## 1.0.3-beta - 2020-01-16

### README.md

* Added software prerequisites
* Fixed some typos
* Added some clarifications
