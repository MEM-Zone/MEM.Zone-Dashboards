# Known Issues for CM SRS Dashboards

## Issue [#1](https://github.com/SCCM-Zone/CM-SRS-Dashboards/issues/5)

* SU DAS Overall Compliance, SU Compliance by Collection, SU Compliance by Device will fail if the CMDM and SSRS databases are not on the same server.

### Workaround

* Create a different Data Source for the
ReportInfo dataset that points to the current Reporting Server database.

### Resolution

* Issue will be fixed after I create a dedicated installer for the dashboards.
