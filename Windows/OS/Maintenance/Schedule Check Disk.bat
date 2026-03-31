REM Check Disk At Reboot
REM Run chkdsk /r, which will execute the check disk and repair at the next reboot. Enter the drive letter, or leave blank to default to C. Do not include the colon. Use the reboot component in your job after this component.

echo y | chkdsk /r %drive%:
exit 0