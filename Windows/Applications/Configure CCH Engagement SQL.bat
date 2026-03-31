REM CCH Engagement SQL Service Settings [WIN]
REM Sets the "SQL Server (PROFXENGAGEMENT)" service to Automatic Start (Delayed)
Sets all recovery options to "Restart the service" after 1 minute

@echo off
sc config "MSSQL$PROFXENGAGEMENT" start= delayed-auto
SC failure "MSSQL$PROFXENGAGEMENT" reset=0 actions=restart/60000/restart/60000/restart/60000