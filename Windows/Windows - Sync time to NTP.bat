@ECHO OFF
time /t
net stop w32time
w32tm /config /syncfromflags:manual /manualpeerlist:"us.pool.ntp.org"
net start w32time
w32tm /config /update
w32tm /resync
time /t