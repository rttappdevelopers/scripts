Start-Process msiexec.exe -Wait -ArgumentList '/x {7D7ED176-EA00-4B2B-B421-AA19A451F650} /qn REBOOT=ReallySuppress /l*v "C:\Windows\temp\removeGVC.log"' 

Start-Process msiexec.exe -Wait -ArgumentList '/x {83C9BF15-02E7-4049-9758-EE61175CFB7B} /qn REBOOT=ReallySuppress /l*v "C:\Windows\temp\removeGVC.log"'