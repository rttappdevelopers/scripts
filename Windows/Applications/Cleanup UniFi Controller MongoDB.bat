REM Ubiquiti UniFi Controller - Prune mongoDB
REM Prunes old data from mongoDB older than 7 days. Compatible with mongodb-win32-x86_64-3.4.15. 
REM Find mongod.exe in \Ubiquiti UniFi\bin and run "mongod.exe --version" to identify architecture and version. 
REM 
REM Reference: https://help.ui.com/hc/en-us/articles/204911424-UniFi-How-to-Remove-Prune-Older-Data-and-Adjust-Mongo-Database-Size
REM May need to review current relevance and test the script; it doesn't target the location of the executable

mongo.exe --port 27117 < mongo_prune_js.js