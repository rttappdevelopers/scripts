REM Change local username [WIN]
REM Prompts for current username and new username. Does not affect or break the user's profile folder name.
REM Variables: %currentuser%, %newuser%

wmic useraccount where name="%currentuser%" rename "%newuser%"
net user %newuser%