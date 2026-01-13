@echo off

:: This copies common files found in AppData folder under a Windows 11 user profile, to OneDrive in a folder called Backup with the date it ran appended.  
:: It creates another batch file to restore the data along with Backup_PrinterList, Backup_Shared_Drives, Backup_Trusted_IE_Sites.reg, TaskBar-pinned-items.reg, ComputerInfo-Detailed
:: Run as the user, not as admin, on the old computer
:: Created by Aric Galloso 1/2026



:: DO NOT EDIT ANYTHING BELOW THIS LINE


set "MM=%DATE:~4,2%"
set "DD=%DATE:~7,2%"
set "YYYY=%DATE:~10,4%"
set "DATESTAMP=%YYYY%-%MM%-%DD%"
echo %DATESTAMP%



:: Copying files found in AppData folder to OneDrive.
robocopy.exe "%userprofile%\AppData\Roaming\Microsoft\Signatures" *.* /e "%userprofile%\OneDrive\Backup-%DATESTAMP%\AppData\Roaming\Microsoft\Signatures" /R:1 /W:1 
robocopy.exe "%userprofile%\AppData\Roaming\Microsoft\Templates" *.* /e "%userprofile%\OneDrive\Backup-%DATESTAMP%\AppData\Roaming\Microsoft\Templates" /R:1 /W:1
robocopy.exe "%userprofile%\AppData\Roaming\Microsoft\Spelling" *.* /e "%userprofile%\OneDrive\Backup-%DATESTAMP%\AppData\Roaming\Microsoft\Spelling" /R:1 /W:1
robocopy.exe "%userprofile%\AppData\Roaming\Microsoft\Sticky Notes" *.* /e "%userprofile%\OneDrive\Backup-%DATESTAMP%\AppData\Microsoft\Sticky Notes" /R:1 /W:1
robocopy.exe "%userprofile%\%LOCALAPPDATA%\Packages\Microsoft.MicrosoftStickyNotes_8wekyb3d8bbwe\LocalState\plum.sqlite" *.* /e "%userprofile%\OneDrive\Backup-%DATESTAMP%\AppData\Packages\Microsoft.MicrosoftStickyNotes_8wekyb3d8bbwe\LocalState\plum.sqlite" /R:1 /W:1

:: robocopy.exe "%userprofile%\AppData\Local\Google\Chrome\User Data" *.* /e "%userprofile%\OneDrive\Backup-%DATESTAMP%\AppData\Local\Google\Chrome\User Data" /R:1 /W:1 
robocopy.exe "%userprofile%\AppData\Roaming\Microsoft\Internet Explorer\Quick Launch" *.* /e "%userprofile%\OneDrive\Backup-%DATESTAMP%\AppData\Roaming\Microsoft\Internet Explorer\Quick Launch" R:1 /W:1
robocopy.exe "%userprofile%\AppData\Roaming\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar" *.* /e "%userprofile%\OneDrive\Backup-%DATESTAMP%\AppData\Roaming\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar" R:1 /W:1
robocopy.exe "%userprofile%\AppData\Roaming\Microsoft\Windows\Recent\AutomaticDestinations” *.* /e "%userprofile%\OneDrive\Backup-%DATESTAMP%\AppData\Roaming\Microsoft\Windows\Recent\AutomaticDestinations” R:1 /W:1
REG EXPORT "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Taskband" "%userprofile%\OneDrive\Backup-%DATESTAMP%\TaskBar-pinned-items.reg"

:: Copies Adobe Signatures. 
:: robocopy.exe "%userprofile%\AppData\Roaming\Adobe\Acrobat\DC\Security" *.* /e "%userprofile%\OneDrive\Backup-%DATESTAMP%\AppData\Roaming\Adobe\Acrobat\DC\Security" /R:1 /W:1
robocopy.exe "%userprofile%\AppData\Roaming\Adobe\Acrobat" *.* /e "%userprofile%\OneDrive\Backup-%DATESTAMP%\AppData\Roaming\Adobe\Acrobat" /R:1 /W:1


:: Copies Java trusted certificates and exception sites.
robocopy.exe "%userprofile%\Appdata\LocalLow\Sun\Java\Deployment\security\exception.sites" *.* /e "%userprofile%\OneDrive\Backup-%DATESTAMP%\Appdata\LocalLow\Sun\Java\Deployment\security\exception.sites" /R:1 /W:1
robocopy.exe "%userprofile%\Appdata\LocalLow\Sun\Java\Deployment\security\trusted.certs" *.* /e "%userprofile%\OneDrive\Backup-%DATESTAMP%\Appdata\LocalLow\Sun\Java\Deployment\security\trusted.certs" /R:1 /W:1

:: Logs mapped Drives
net use >>"%userprofile%\OneDrive\Backup-%DATESTAMP%\Backup_Shared_Drives.txt"

:: Logs printer info
cscript C:\Windows\System32\Printing_Admin_Scripts\en-US\prnmngr.vbs -l >>"%userprofile%\OneDrive\Backup-%DATESTAMP%\Backup_PrinterList.txt"

:: Exports users Internet Explorer Trusted Sites
reg export "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings\ZoneMap\Domains" "%userprofile%\OneDrive\Backup-%DATESTAMP%\Backup_Trusted_IE_Sites.reg"

:: Export Custom Dictionaries
reg export "HKCU\Software\Microsoft\Shared Tools\Proofing tools\Custom Dictionaries" "%userprofile%\OneDrive\Backup-%DATESTAMP%\Custom_Dictionaries.reg"


:: Creating a list of programs below, adds significant time.  Pressing keys CNTRL + C will give you an option to skip it.
:: Echo Creating a list of programs:
:: powershell -NoProfile -Command "Get-CimInstance Win32_Product | Select-Object Name,Version | Export-Csv -NoTypeInformation -Encoding UTF8 -Path '%userprofile%\OneDrive\Backup-%DATESTAMP%\Programs_Installed.csv'"


::  Gathering misc info, Operating System, Serial Number, Computer Name, and list of services running.
Powershell -Command "SystemInfo" >>"%userprofile%\OneDrive\Backup-%DATESTAMP%\ComputerInfo.txt"
Powershell Get-CimInstance Win32_BIOS >>"%userprofile%\OneDrive\Backup-%DATESTAMP%\ComputerInfo.txt"
Powershell $env:COMPUTERNAME >>"%userprofile%\OneDrive\Backup-%DATESTAMP%\ComputerInfo.txt"

Echo ========================== >> "%userprofile%\OneDrive\Backup-%DATESTAMP%\ComputerInfo.txt"
Echo Services Below >> "%userprofile%\OneDrive\Backup-%DATESTAMP%\ComputerInfo.txt"
Echo ========================== >> "%userprofile%\OneDrive\Backup-%DATESTAMP%\ComputerInfo.txt"

Powershell -NoProfile -Command "Get-CimInstance Win32_Service" | Sort >>"%userprofile%\OneDrive\Backup-%DATESTAMP%\ComputerInfo.txt"


@echo off
Echo -
Echo ========================================
Echo -
Echo Manual Steps Below

Echo DONT FORGET to Backup Bookmarks for Chrome, FireFox, and Edge manually.
Echo -

:: Create Restore-Script Batch File in OneDrive

echo. @echo on > "%userprofile%\OneDrive\Backup-%DATESTAMP%\Restore_Script.bat"
echo :: Restore Backup from CommonPathsLight Script- >> "%userprofile%\OneDrive\Backup-%DATESTAMP%\Restore_Script.bat"
echo :: Make sure the backup folder is fully synced or this will fail- >> "%userprofile%\OneDrive\Backup-%DATESTAMP%\Restore_Script.bat"
echo :: Created by Aric Galloso 1/2026 >> "%userprofile%\OneDrive\Backup-%DATESTAMP%\Restore_Script.bat"
echo :: Always Keep on This Device >> "%userprofile%\OneDrive\Backup-%DATESTAMP%\Restore_Script.bat"
echo attrib +P -U "%USERPROFILE%\OneDrive\Backup-%DATESTAMP%" /S /D >> "%userprofile%\OneDrive\Backup-%DATESTAMP%\Restore_Script.bat"
echo Timeout /t 5 >> "%userprofile%\OneDrive\Backup-%DATESTAMP%\Restore_Script.bat"
echo robocopy.exe "AppData" *.* /e "%USERPROFILE%\AppData" /R:1 /W:1 /LOG:"robocopy-appdata-restore.log" >> "%userprofile%\OneDrive\Backup-%DATESTAMP%\Restore_Script.bat"
echo Powershell.exe Stop-Process -Name explorer -Force; Start-Process explorer.exe >> "%userprofile%\OneDrive\Backup-%DATESTAMP%\Restore_Script.bat"
echo :: Import Reg Keys >> "%userprofile%\OneDrive\Backup-%DATESTAMP%\Restore_Script.bat"
echo reg import "TaskBar-pinned-items.reg" >> "%userprofile%\OneDrive\Backup-%DATESTAMP%\Restore_Script.bat"
echo reg import "Backup_Trusted_IE_Sites.reg" >> "%userprofile%\OneDrive\Backup-%DATESTAMP%\Restore_Script.bat"
echo reg import "Custom_Dictionaries.reg" >> "%userprofile%\OneDrive\Backup-%DATESTAMP%\Restore_Script.bat"

echo Timeout /t 15 >> "%userprofile%\OneDrive\Backup-%DATESTAMP%\Restore_Script.bat"
:: The next 2 lines are a repeat.  Without this, the taskbar icons dont load properly.  Probably due to all AppData files not synced fully.

echo robocopy.exe "AppData" *.* /e "%USERPROFILE%\AppData" /R:1 /W:1 /LOG:"robocopy-appdata-restore.log" >> "%userprofile%\OneDrive\Backup-%DATESTAMP%\Restore_Script.bat"
echo Powershell.exe Stop-Process -Name explorer -Force; Start-Process explorer.exe >> "%userprofile%\OneDrive\Backup-%DATESTAMP%\Restore_Script.bat"

echo robocopy-appdata-restore.log >> "%userprofile%\OneDrive\Backup-%DATESTAMP%\Restore_Script.bat"


Pause
