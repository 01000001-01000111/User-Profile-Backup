<# This copies common files found in AppData folder under a Windows 11 user profile, to the users OneDrive in a folder called Backup with the date it ran appended.  
It creates another batch file to restore the data along with Backup_PrinterList, Backup_Shared_Drives, Backup_Trusted_IE_Sites.reg, TaskBar-pinned-items.reg, ComputerInfo-Detailed
Run as the user, not as admin.
Created by Aric Galloso 1/2026
#>

function Invoke-ProfileBackupToOneDrive {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param(
        # Optional override if OneDrive env var is missing or nonstandard
        [string]$DestinationRoot,

        # Defaults to yyyy-MM-dd
        [string]$DateStamp = (Get-Date -Format 'yyyy-MM-dd'),

        # Optional features
        [switch]$IncludeChrome,

        # Create transcript/run log
        [switch]$EnableTranscript = $true
    )

    begin {
        Set-StrictMode -Version Latest
        $ErrorActionPreference = 'Stop'

        function Ensure-Directory([string]$Path) {
            if (-not (Test-Path -LiteralPath $Path)) {
                New-Item -ItemType Directory -Path $Path -Force | Out-Null
            }
        }

        function Get-OneDriveRoot {
            if ($DestinationRoot) { return $DestinationRoot }

            if ($env:OneDrive -and (Test-Path -LiteralPath $env:OneDrive)) {
                return $env:OneDrive
            }

            $fallback = Join-Path $env:USERPROFILE 'OneDrive'
            return $fallback
        }

        function Invoke-RobocopyDir([string]$SourceDir, [string]$DestDir) {
            if (-not (Test-Path -LiteralPath $SourceDir)) {
                Write-Verbose "Skip missing: $SourceDir"
                return
            }
            Ensure-Directory $DestDir

            $args = @(
                $SourceDir
                $DestDir
                '/E'
                '/R:1'
                '/W:1'
                '/COPY:DAT'
                '/DCOPY:DAT'
            )

            Write-Verbose "Robocopy: $SourceDir -> $DestDir"
            $null = & robocopy.exe @args

            if ($LASTEXITCODE -ge 8) {
                throw "Robocopy failed (exit code $LASTEXITCODE): $SourceDir -> $DestDir"
            }
        }

        function Copy-FileIfExists([string]$SourceFile, [string]$DestFile) {
            if (-not (Test-Path -LiteralPath $SourceFile)) {
                Write-Verbose "Skip missing: $SourceFile"
                return
            }
            Ensure-Directory (Split-Path -Path $DestFile -Parent)
            Copy-Item -LiteralPath $SourceFile -Destination $DestFile -Force
        }

        function Export-RegKey([string]$KeyPath, [string]$OutFile) {
            Ensure-Directory (Split-Path -Path $OutFile -Parent)
            & reg.exe export $KeyPath $OutFile /y | Out-Null
        }
    }

    process {
        $oneDrive = Get-OneDriveRoot
        if (-not (Test-Path -LiteralPath $oneDrive)) {
            throw "OneDrive root not found: $oneDrive"
        }

        $backupRoot = Join-Path $oneDrive "Backup-$DateStamp"
        Ensure-Directory $backupRoot

        $runLog = Join-Path $backupRoot "Backup-RunLog-$DateStamp.txt"
        $computerInfo = Join-Path $backupRoot "ComputerInfo.txt"
        $restoreBat = Join-Path $backupRoot "Restore_Script.bat"

        if ($EnableTranscript) {
            Start-Transcript -Path $runLog -Append | Out-Null
        }

        try {
            if ($PSCmdlet.ShouldProcess($backupRoot, "Backup profile artifacts to OneDrive")) {

                # ---- Copy AppData folders ----
                Invoke-RobocopyDir (Join-Path $env:APPDATA 'Microsoft\Signatures') (Join-Path $backupRoot 'AppData\Roaming\Microsoft\Signatures')
                Invoke-RobocopyDir (Join-Path $env:APPDATA 'Microsoft\Templates')  (Join-Path $backupRoot 'AppData\Roaming\Microsoft\Templates')
                Invoke-RobocopyDir (Join-Path $env:APPDATA 'Microsoft\Spelling')   (Join-Path $backupRoot 'AppData\Roaming\Microsoft\Spelling')

                Invoke-RobocopyDir (Join-Path $env:APPDATA 'Microsoft\Sticky Notes') (Join-Path $backupRoot 'AppData\Roaming\Microsoft\Sticky Notes')

                # Sticky Notes UWP DB
                $stickyPkg = 'Microsoft.MicrosoftStickyNotes_8wekyb3d8bbwe'
                $stickyDb  = Join-Path $env:LOCALAPPDATA "Packages\$stickyPkg\LocalState\plum.sqlite"
                $stickyOut = Join-Path $backupRoot       "AppData\Local\Packages\$stickyPkg\LocalState\plum.sqlite"
                Copy-FileIfExists $stickyDb $stickyOut

                # Quick Launch / Taskbar pinned folder
                Invoke-RobocopyDir (Join-Path $env:APPDATA 'Microsoft\Internet Explorer\Quick Launch') `
                                   (Join-Path $backupRoot 'AppData\Roaming\Microsoft\Internet Explorer\Quick Launch')

                Invoke-RobocopyDir (Join-Path $env:APPDATA 'Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar') `
                                   (Join-Path $backupRoot 'AppData\Roaming\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar')

                # Jump lists
                Invoke-RobocopyDir (Join-Path $env:APPDATA 'Microsoft\Windows\Recent\AutomaticDestinations') `
                                   (Join-Path $backupRoot 'AppData\Roaming\Microsoft\Windows\Recent\AutomaticDestinations')

                # Adobe
                Invoke-RobocopyDir (Join-Path $env:APPDATA 'Adobe\Acrobat') (Join-Path $backupRoot 'AppData\Roaming\Adobe\Acrobat')

                # Java security files
                $javaSecDir = Join-Path $env:USERPROFILE 'AppData\LocalLow\Sun\Java\Deployment\security'
                Copy-FileIfExists (Join-Path $javaSecDir 'exception.sites') (Join-Path $backupRoot 'AppData\LocalLow\Sun\Java\Deployment\security\exception.sites')
                Copy-FileIfExists (Join-Path $javaSecDir 'trusted.certs')   (Join-Path $backupRoot 'AppData\LocalLow\Sun\Java\Deployment\security\trusted.certs')

             

                # ---- Exports ----
                Export-RegKey 'HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Taskband' `
                             (Join-Path $backupRoot 'TaskBar-pinned-items.reg')

                Export-RegKey 'HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings\ZoneMap\Domains' `
                             (Join-Path $backupRoot 'Backup_Trusted_IE_Sites.reg')

                Export-RegKey 'HKCU\Software\Microsoft\Shared Tools\Proofing tools\Custom Dictionaries' `
                             (Join-Path $backupRoot 'Custom_Dictionaries.reg')

                # ---- Logs ----
                (net use) | Out-File -FilePath (Join-Path $backupRoot 'Backup_Shared_Drives.txt') -Append -Encoding utf8

                $prnScript = 'C:\Windows\System32\Printing_Admin_Scripts\en-US\prnmngr.vbs'
                if (Test-Path -LiteralPath $prnScript) {
                    (cscript.exe //nologo $prnScript -l) | Out-File -FilePath (Join-Path $backupRoot 'Backup_PrinterList.txt') -Append -Encoding utf8
                }

                # ---- Computer info ----
                "SystemInfo:" | Out-File -FilePath $computerInfo -Append -Encoding utf8
                (systeminfo)  | Out-File -FilePath $computerInfo -Append -Encoding utf8

                "" | Out-File -FilePath $computerInfo -Append -Encoding utf8
                "BIOS:" | Out-File -FilePath $computerInfo -Append -Encoding utf8
                (Get-CimInstance Win32_BIOS | Format-List * | Out-String) | Out-File -FilePath $computerInfo -Append -Encoding utf8
                "ComputerName: $($env:COMPUTERNAME)" | Out-File -FilePath $computerInfo -Append -Encoding utf8

                "" | Out-File -FilePath $computerInfo -Append -Encoding utf8
                "==========================" | Out-File -FilePath $computerInfo -Append -Encoding utf8
                "Services Below"             | Out-File -FilePath $computerInfo -Append -Encoding utf8
                "==========================" | Out-File -FilePath $computerInfo -Append -Encoding utf8
                (Get-CimInstance Win32_Service | Sort-Object Name | Format-Table -AutoSize | Out-String) |
                    Out-File -FilePath $computerInfo -Append -Encoding utf8

                # ---- Generate Restore BAT ----
                $restoreLines = @(
                    '@echo on'
                    ':: Restore Backup from CommonPathsLight Script'
                    ':: Make sure the backup folder is fully synced or this will fail'
                    ':: Always Keep on This Device'
                    ('attrib +P -U "{0}" /S /D' -f $backupRoot)
                    'Timeout /t 5'
                    'robocopy.exe "AppData" "%USERPROFILE%\AppData" /E /R:1 /W:1 /LOG:"robocopy-appdata-restore.log"'
                    'Powershell.exe -NoProfile -Command "Stop-Process -Name explorer -Force; Start-Process explorer.exe"'
                    ':: Import Reg Keys'
                    'reg import "TaskBar-pinned-items.reg"'
                    'reg import "Backup_Trusted_IE_Sites.reg"'
                    'reg import "Custom_Dictionaries.reg"'
                   
                    ':: Repeat to help ensure everything is synced for taskbar icons to load'
                    'robocopy.exe "AppData" "%USERPROFILE%\AppData" /E /R:1 /W:1 /LOG:"robocopy-appdata-restore.log"'
                    'Powershell.exe -NoProfile -Command "Stop-Process -Name explorer -Force; Start-Process explorer.exe"'
                    'echo robocopy-appdata-restore.log'
                )
                Set-Content -Path $restoreBat -Value $restoreLines -Encoding ascii

                # Return a structured object (useful for automation)
                [pscustomobject]@{
                    DateStamp      = $DateStamp
                    BackupRoot     = $backupRoot
                    RunLog         = $runLog
                    RestoreScript  = $restoreBat
                    ComputerInfo   = $computerInfo
                    OneDriveRoot   = $oneDrive
                    IncludedChrome = [bool]$IncludeChrome
                }
            }
        }
        finally {
            if ($EnableTranscript) {
                Stop-Transcript | Out-Null
            }
        }
    }
}
Invoke-ProfileBackupToOneDrive -Verbose
# Invoke-ProfileBackupToOneDrive -IncludeChrome -Verbose
# Invoke-ProfileBackupToOneDrive -WhatIf -Verbose
