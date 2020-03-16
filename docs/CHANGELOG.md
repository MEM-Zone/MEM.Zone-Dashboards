# Changelog for CM SRS Dashboards

## 2.1.4 - 2020-03-16

* Fixed crash when LastScanPackageLocation is NULL in `SU Scan Status by Collection` (Issue #18)

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
* Fixed issue [#2](https://github.com/SCCM-Zone/CM-SRS-Dashboards/issues/2)
* Fixed issue [#3](https://github.com/SCCM-Zone/CM-SRS-Dashboards/issues/3)
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
