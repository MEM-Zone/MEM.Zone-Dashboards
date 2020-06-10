[![Release version][release-version-badge]][release-version]
[![Release date][release-date-badge]][release-date]
[![Issues count][issues-badge]][issues]
[![Commits since release][commits-since-badge]][commits-since]
[![Chat on discord][discord-badge]][discord]
[![Follow on twitter][twitter-badge]][twitter]

# SU SRS Dashboards

## Welcome to our awesome MEMCM Dashboards :)

This repository is a solution of dashboards and reports, for Microsoft Endpoint Configuration Manager.

A software update dashboard with five subreports is currently available. Installation can be done manually or via the included PowerShell installer. You can find the standalone repository for the installer [here](https://SCCM.Zone/Install-SRSReport-RELEASES).

The `SU DAS Overall Compliance` dashboard is navigable, independent of `Software Update Groups` and comes with an array of filtering options.

All subreports can be run standalone.

## Latest release

See [releases](https://SCCM.Zone/CM-SRS-Dashboards-RELEASES).

## Changelog

See [changelog](https://SCCM.Zone/CM-SRS-Dashboards-CHANGELOG).

## Credit

* Adam Weigert [`ufn_CM_GetNextMaintenanceWindow`](https://social.technet.microsoft.com/wiki/contents/articles/7870.sccm-2007-create-report-of-upcoming-maintenance-windows-by-client.aspx)

## Dashboards and Reports

* SU DAS Overall Compliance
* AL Alerts
* SU Compliance by Collection
* SU Compliance by Device
* SU Scan Status
* SU SUP Sync Status

## Build Tree

```bash
.
+-- src
    +-- CM Dashboards
        +-- Extensions
        |   +-- perm_CMDatabase.sql
        |   +-- ufn_CM_GetNextMainanceWindow
        +-- help
        |   +-- README.md
        +-- Reports
            +-- AL Alerts.rdl
            +-- SU Compliance by Collection.rdl
            +-- SU Compliance by Device.rdl
            +-- SU DAS Overall Compliance.rdl
            +-- SU Scan Status by Collection.rdl
            +-- SU SUP Sync Status.rdl
```

## Navigation Tree

```bash
.
+-- (D) SU DAS Overall Compliance
    +-- (C) Update Compliance
    |   +-- (R) SU Compliance by Collection
    |       +-- (R) SU Compliance by Device
    |
    +-- (C) Missing updates by Category
    |   +-- (R) SU Compliance by Collection
    |       +-- (R) SU Compliance by Device
    |
    +-- (C) Update Agent Scan States
    |   +-- (R) SU Scan Status
    |
    +-- (C) Overall Update Group Compliance
    |
    +-- (C) Devices Missing a Specific Update
    |   +-- (R) SU Compliance by Collection
    |       +-- (R) SU Compliance by Device
    |
    +-- (T) Critical Alerts
    |   +-- (R) AL Alerts
    |
    +-- (T) Last Successful Synchronization Time
        +-- (R) SU SUP Sync Status

## Legend
'()'  - 'to' or 'from' navigation element
'(D)' - Dashboard
'(R)' - Report
'(C)' - Chart
'(T)' - Text
```

## Preview

[![](https://s3.ioan.in/Screen-Shot-2020-01-16-at-18.01.39/Screen-Shot-2020-01-16-at-18.01.39.png)](http://www.youtube.com/watch?v=MOHxb8me4IM "CM SRS Dashboards")

[release-version-badge]: https://img.shields.io/github/v/release/SCCM-ZONE/CM-SRS-Dashboards
[release-version]: https://github.com/SCCM-Zone/CM-SRS-Dashboards/releases
[release-date-badge]: https://img.shields.io/github/release-date-pre/SCCM-ZONE/CM-SRS-Dashboards
[release-date]: https://github.com/SCCM-Zone/CM-SRS-Dashboards/releases
[issues-badge]: https://img.shields.io/github/issues/SCCM-Zone/CM-SRS-Dashboards
[issues]: https://github.com/SCCM-Zone/CM-SRS-Dashboards/issues?q=is%3Aopen+is%3Aissue
[commits-since-badge]: https://img.shields.io/github/commits-since/SCCM-Zone/CM-SRS-Dashboards/v2.3.0
[commits-since]: https://github.com/SCCM-Zone/CM-SRS-Dashboards/commits/master
[discord-badge]: https://img.shields.io/discord/666618982844989460?logo=discord
[discord]: https://discord.gg/ZCkVcmP
[twitter-badge]: https://img.shields.io/twitter/follow/ioanpopovici?style=social&logo=twitter
[twitter]: https://twitter.com/intent/follow?screen_name=ioanpopovici
