# Breaking Changes for MEM.Zone Dashboards (4.0.0)

* Changed `GetHealth/ScanStatus()` vb functions merged into a single `GetStatus()` function
* Changed naming schema for all reports and removed abbreviations to make them more understandable
* Changed `KB2267602 - Microsoft Intelligence Updates` are now excluded by default.
* Changed `Uptime` and `Last Update Scan` to Days instead of Date

# Breaking Changes for MEM.Zone Dashboards (3.0.0)

* Changed `Last Boot Time` to `Uptime (Days)`
* Changed `Last Update Scan Time` to `Last Update Scan (Days)`
* Changed `Health Checks` to display Health Check Values instead of `Yes` / `No`
* Changed `Pending Restart` to display `Restart Reason` instead of `Yes` / `No`
* Changed `ufn_CM_GetNextMaintenanceWindow` also returns `StartTime`
* Added `Free Space (GB)` column
* Added `Health Thresholds` csv report parameter