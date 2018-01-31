#Requires -Version 3.0

New-Variable -Name LastLogBackup -Description 'TimeStamp of the last time the Backup-Logs function was processed' -Scope Global -Force

[bool]$backupNow = $true
function Backup-Logs {
    <#
        .SYNOPSIS
            Extension of Sperry module, to simplify cleanup of log files (commonly referred to as log rotation in UNIX / Linux context)
        .DESCRIPTION
            As part of the PSLogger module, this script (function) is a complement to the Write-Log function, and simplifies WindowsPowerShell log maintenance
            By default, Backup-Logs will look for any/all files in $env:USERPROFILE\Documents\WindowsPowerShell\log, and if they're older than 7 days, move them into a archive\ sub-folder
            If necessary (and if sufficient permissions are available), the archive\ sub-folder will be created automatically
            If the archive\ sub-folder already exists, Backup-Logs will search for any files older than 90 days, and delete them.
            Note: For both the log age and the archive purge age, each file's LastWriteTime property is what is evaluated
            All of these conditions are customizable through parameters.
            Invoke get-help Backup-Logs -examples for additional information
        .PARAMETER Path
            Optionally specifies the 'root' path of where to look for and maintain log files, to be moved to \archive\.
        .PARAMETER Age
            Optionally specifies age of log files to be moved to \archive\.
        .PARAMETER Purge
            Optionally specifies a date, by age from today(), for which all older log files will be deleted.
        .EXAMPLE
            PS .\> Backup-Logs

            Moves all .log files older than 7 days, from $env:USERPROFILE\Documents\WindowsPowerShell\log\ to $env:USERPROFILE\Documents\WindowsPowerShell\log\archive\
        .EXAMPLE
            PS .\> Backup-Logs -age 14 -purge 90

            Moves all .log files older than 14 days, to $env:USERPROFILE\Documents\WindowsPowerShell\log\archive\, and deletes all files from the archive folder which are older than 90 days
        .NOTES
            NAME        :  BackupLogs.ps1
            VERSION     :  1.0.2
            LAST UPDATED:  11/16/2015
            AUTHOR      :  Bryan Dady
    #>
    [cmdletbinding()]
    param (
        [Parameter(Position=0)]
        [ValidateScript({Test-Path -Path $PSItem -PathType Any -IsValid})]
        [string]
        $Path = $Global:myPSLogPath,

        [Parameter(Position=1)]
        [ValidateRange(0,1825)]
        [int]
        $age=7,

        [Parameter(Position=2)]
        [ValidateRange(0,1825)]
        [int]
        $purge = 90,

        [Parameter(Position=3)]
        [switch]
        $force,

        [Parameter(Position=4)]
        [ValidateRange(0,1825)]
        [int]
        $BackupCadence = 10
    )

    Show-Progress -msgAction Start -msgSource $MyInvocation.MyCommand.Name
    $ValidPath = $false

    if (Test-Path -Path $Path -PathType Any -IsValid -ErrorAction SilentlyContinue) {
        Write-Verbose -Message ('$Path parameter is: {0}' -f $Path)
        $ValidPath = $true
    } else {
        # Derive default path
        Write-Verbose -Message ('$Path parameter not validated; setting to ($myPSLogPath): {0}' -f $myPSLogPath)
        $Path = $global:myPSLogPath
    }
    Write-Log -Message ('Checking $Path: {0}' -f $Path) -Function $MyInvocation.MyCommand.Name

    if ($ValidPath) {
        # confirmed $Path exists; see if \archive sub-folder exists
        if (Test-Path -Path "$Path\archive") {
            Write-Log -Message 'Confirmed archive folder exists' -Function $MyInvocation.MyCommand.Name
            # set variable LastLogBackup based on the latest log file in $Path\archive
            $LastLogFile = Get-ChildItem -Path $Path\archive -Filter *.log -File | Sort-Object -Property LastWriteTime -Descending | Select-Object -First 1
            # Handle case where no last log file exists
            if ($LastLogFile) {
                $LastLogBackup = (Get-Date -Date $LastLogFile.LastWriteTime)
            } else {
                $LastLogBackup = (Get-Date).AddDays(-30)
            }
            Write-Log -Message ('LastLogBackup was {0}' -f ($LastLogBackup.GetDateTimeFormats('d') | Select-Object -First 1)) -Function $MyInvocation.MyCommand.Name
            $NextBackupDate = $LastLogBackup.AddDays($BackupCadence)
            Write-Log -Message ('NextBackupDate is {0}' -f ($NextBackupDate.GetDateTimeFormats('d') | Select-Object -First 1)) -Function $MyInvocation.MyCommand.Name

            # Is today on or after $NextBackupDate ?
            if ($NextBackupDate -ge (Get-Date)) {
                # we DON'T need to backup right now
                $backupNow = $false
            }
        } else {
            # log archive path doesn't yet exist, so create it
            Write-Log -Message 'Creating archive folder' -Function $MyInvocation.MyCommand.Name
            New-Item -ItemType Directory -Path $Path\archive
            Set-Variable -Name LastLogBackup -Value (Get-Date -DisplayHint Date -Format d)
            # Since we've never backed up to this path before, leave $backupNow = $true
        }

        if ($backupNow -or $force) {
            # we can now proceed with backing up logs
            $logFileDateString = Get-Date -UFormat '%Y%m%d'
            Write-Log -Message ('Archiving files older than {0} days.' -f $age) -Function $MyInvocation.MyCommand.Name
            Write-Log -Message " # # # BEGIN ROBOCOPY # # # # #`n" -Function $MyInvocation.MyCommand.Name

            Write-Log -Message ('About to run robocopy, logging to ""{0}\Backup-Logs_{1}.log""' -f $Path, $logFileDateString) -Function $MyInvocation.MyCommand.Name

            & "$env:windir\system32\robocopy.exe" """$Path"" ""$Path\archive"" /MINAGE:$age /MOV /R:1 /W:1 /NS /NC /NP /NDL /TEE" | Out-File -FilePath "$Path\Backup-Logs_$logFileDateString.log" -Append -NoClobber

            Write-Log -Message " # # # END ROBOCOPY # # # # #`n" -Function $MyInvocation.MyCommand.Name

            # Now we attempt to cleanup (purge) any old files
            [datetime]$purgeDate = (Get-Date).AddDays(-$purge)
            Write-Log -Message ('Purge date is {0}' -f $purgeDate) -Function $MyInvocation.MyCommand.Name

            # Enumerate files, and purge those that haven't been updated wince $purge.
            Write-Log -Message ('Deleting archive\ files older than {0}' -f $purgeDate) -Function $MyInvocation.MyCommand.Name

            Get-ChildItem -Path (Join-Path -Path $Path -ChildPath 'archive') -File | Where-Object -FilterScript {$_.LastWriteTime -lt $purgeDate} | Remove-Item -ErrorAction SilentlyContinue

        } else {
            Write-Log -Message 'No need to archive log files right now.' -Function $MyInvocation.MyCommand.Name
        }
    } else {
        Write-Log -Message ('Unable to confirm existence of logs folder: {0}' -f $Path) -Verbose -Function $MyInvocation.MyCommand.Name
    }
    
    Show-Progress -msgAction Stop -msgSource $MyInvocation.MyCommand.Name
}

New-Alias -Name Archive-Logs -Value Backup-Logs -Description 'PSLogger Module' -ErrorAction SilentlyContinue
