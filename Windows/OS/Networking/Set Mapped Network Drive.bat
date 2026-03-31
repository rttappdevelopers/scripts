REM Assign Mapped Network Drive [WIN]
REM Map a path to a network drive letter. Not recommended for domain environments that leverage group policy (fix the policy instead). Run as user, not system.

NET USE %driveletter% %sharepath%