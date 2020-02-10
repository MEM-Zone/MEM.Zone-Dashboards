# Changelog for CM SRS Dashboards

## 2.0.0 - 2020-02-10

* Created a dashboard powershell installer [Issue #6](#6)
* Fixed Dashboard and SU Compliance reports not working [Issue #5](#5). RS path is now computed from variables instead from the RS DB.
* Moved the permission block to a separate file [Issue #9](#9)
* Comented database references from prerequisite files
* Removed 'GO' statements from prerequisite files
* Report files have been moved to the 'Reports' folder to match the installer defautls
* Prerequisites have been moved to the 'Extensions' folder to match the installer defaults

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
