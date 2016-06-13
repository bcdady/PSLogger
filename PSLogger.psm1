#requires -version 3
<#
    .SYNOPSIS
        PSLogger is a PowerShell module to enhance and simplify interacting with log files on the file system.
    .DESCRIPTION
        PSLogger provides functions to Write logs, find / enumerate recently written log files, and Read the latest lines of recent .log files.
    .NOTES
        NAME        :  PSLogger
        VERSION     :  1.3.5
        LAST UPDATED:  11/16/2015
        AUTHOR      :  Bryan Dady | https://github.com/bcdady/
        Original Write-Log Author: Jeffery Hicks
        http://jdhitsolutions.com/blog
        http://twitter.com/JeffHicks
        Date: 3/3/2011
#>

# Setup necessary configs for PSLogger's Write-Log cmdlet
[string]$global:loggingPreference = 'Continue'
# set $loggingPreference to anything other than continue, to leverage write-debug or write-verbose, without writing to a log on the filesystem

# Define $loggingPath as .\WindowsPowerShell\log directory, under the user's profile Documents folder.
# To assure portability and compatability across client and server, and various OS versions, we use special Environment paths, instead of $HOME or $env:userprofile
# http://windowsitpro.com/powershell/easily-finding-special-paths-powershell-scripts
# If this path doesn't already exist, it will be created later, in Write-Log function
[string]$global:loggingPath = Join-Path -Path "$([Environment]::GetFolderPath('MyDocuments'))" -ChildPath 'WindowsPowerShell\log'
# Handle when special Environment variable MyDocuments is a mapped drive, it returns as the full UNC path.
if (([Environment]::GetFolderPath('MyDocuments')).Substring(0,2) -match '\\')
{
    $global:loggingPath = $loggingPath.Replace("$(Split-Path -Path "$([Environment]::GetFolderPath('MyDocuments'))" -Parent)"+'\',$(Get-PSDrive -PSProvider FileSystem | Where-Object -FilterScript {
                $PSItem.DisplayRoot -eq $(Split-Path -Path "$([Environment]::GetFolderPath('MyDocuments'))" -Parent)
    }).Root)

}

[string]$global:logFileDateString = Get-Date -UFormat '%Y%m%d'
# Need to keep an eye on this one, in case PowerShell sessions run for multiple days, I doubt this variable value will be refreshed / updated

New-Variable -Name LastFunction -Description "Retain 'state' of the last function name called, to streamline logging statements from the same function" -Force -Scope Global -Visibility Public
[bool]$writeIntro = $true
[string]$global:LastFunction

Function Write-Log
{
<#
    .Synopsis
        Write a message to a log file.
    .Description
        Write-Log can be used to write text messages to a log file. It can be used like Write-Verbose,
        and looks for two variables that you can define in your scripts and functions. If the function
        finds $LoggingPreference with a value of "Continue", the message text will be written to the file.
        The default file is PowerShellLog.txt in your %TEMP% directory. You can specify a different file
        path by parameter or set the $logFilePref variable. See the help examples.

        This function also supports Write-Verbose which means if -Verbose is detected, the message text
        will be written to the Verbose pipeline. Thus if you call Write-Log with -Verbose and a the
        $loggingPreference variable is set to continue, you will get verbose messages AND a log file.
    .Parameter Message
        The message string to write to the log file. It will be prepended with a date time stamp.
    .Parameter Function
        The Function Parameter passes the name of the Function or CmdLet that invoked the Write-Log function.
        This is used to write related log messages into a topical log file, instead of writing all log messages into a common file
        If not specified, this defaults to 'PowerShell'
    .Parameter Path
        The filename and path for the log file. The default is defined as $loggingPath (above)
        If $logFilePref variable is (bound) and passed into the Write-Log function, then that override path value will be used.

    .EXAMPLE
        PS .\>Write-Log -Message "Test Message ... this is a test of the Write-Log function" -Function TEST

    .EXAMPLE
        PS .\>Write-Log -Message "Test Message ... this is another test of the Write-Log function, to a custom specified path" -Function TEST -Path $env:TEMP\testing.log

    .Notes
        NAME: Write-Log
        AUTHOR: Bryan Dady, adapted from original work by Jeffery Hicks
        VERSION: 1.3.5
        LASTEDIT: 11/16/2015

    .Link
        http://jdhitsolutions.com/blog/2011/03/powershell-automatic-logging/

    .Link
        Write-Verbose
#>
    [cmdletbinding()]
    Param(
        [Parameter(
            Mandatory = $true,
            Position = 0,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            HelpMessage = 'The message string to write to the log file. It will be prepended with a date time stamp.'
        )]
        [ValidateNotNullOrEmpty()]
        [string]$Message,

        [Parameter(
            Mandatory = $false,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            ValueFromRemainingArguments = $false,
            Position = 1,
            HelpMessage = 'The Function Parameter passes the name of the Function or CmdLet that invoked this Write-Log function'
        )]
        [ValidateNotNullOrEmpty()]
        [Alias('Action', 'Source')]
        [String]$Function,

        [Parameter(
            Position = 2,
                ValueFromPipeline = $true,
                ValueFromPipelineByPropertyName = $true,
                ValueFromRemainingArguments = $false,
            HelpMessage = 'The optional Path parameter specifies the path of the log file to write the message to.'
        )]
        [ValidateScript({Test-Path -Path $PSItem -PathType Any})]
        [string]$Path
    )

    # Assign Function variable to 'PowerShell' if blank or null
    if (($Function -eq $null) -or ($Function -eq ''))
    {
        $Function = 'PowerShell'
    }

    # Detect if this Function is the same as the $LastFunction. If not, verbosely log which new Function is active
    if ($Function -eq $LastFunction)
    {
        # Retain 'state' of the last function name called, to streamline logging statements from the same function
        $writeIntro = $false
    }
    else
    {
        Set-Variable -Name LastFunction -Value $Function -Force -Scope Global
        $writeIntro = $true
    }

    # Detect -debug mode:
    # http://blogs.msdn.com/b/powershell/archive/2009/04/06/checking-for-bound-parameters.aspx
    # https://kevsor1.wordpress.com/2011/11/03/powershell-v2-detecting-verbose-debug-and-other-bound-parameters/
    if ($PSBoundParameters['Debug'].IsPresent)
    {
        [bool]$script:testMode = $true
        $logFilePref = Join-Path -Path "$loggingPath\test" -ChildPath "$("$Function", "$logFileDateString" -join '_').log"
    }
    else
    {
        [bool]$testMode = $false
        $logFilePref = Join-Path -Path "$loggingPath" -ChildPath "$("$Function", "$logFileDateString" -join '_').log"
    }

    # Pass on the message to Write-Debug cmdlet if -Debug parameter was used
    if ($testMode)
    {
        Write-Debug -Message $Message
        if ($writeIntro -and ( $Message -notlike 'Exit*'))
        {
            Write-Output -InputObject "Logging [Debug] to $logFilePref`n"
        }
    }
    elseif ($PSBoundParameters['Verbose'].IsPresent)
    {
        #Pass on the message to Write-Verbose cmdlet if -Verbose parameter was used
        Write-Verbose -Message $Message
        if ($writeIntro -and ( $Message -notlike 'Exit*'))
        {
            Write-Output -InputObject "Logging to $logFilePref`n"
        }
    }

    # Only write to the log file if the $LoggingPreference variable is set to Continue
    if ($loggingPreference -eq 'Continue')
    {

        # Before writing a copy of $Message to an output file, strip line breaks and/or other formatting that could interfere with clear/standardized logging
        $Message = $Message -replace "`n", ' '
        $Message = $Message -replace '\s{2,}', ' '

        #if $Path parameter was specified, then use it, otherwise use the derived $logFilePref
        if ($Path) {
		    $LogFile=$Path
        } else {
		    $LogFile=$logFilePref
        }

        # Confirm or create LogFile path, otherwise Out-File throws DirectoryNotFoundException;
        # Only need to do this once per unique $LogFile path, so use $writeIntro as that flag
        if ($writeIntro -and (-not (Test-Path -Path $(Split-Path -Path $LogFile -Parent) -PathType Container) ) )
        {
            Write-Output -InputObject "$(Get-Date) Creating logging path: $(Split-Path -Path $LogFile)" -NoEnumerate | Out-Host
            New-Item -Path $(Split-Path -Path $LogFile) -Force -ItemType Directory -ErrorAction Ignore
        }

        if ($testMode)
        {
            Write-Output -InputObject "$(Get-Date) [Debug] $Message" -NoEnumerate | Out-File -FilePath $LogFile -Append
        }
        elseif ($PSBoundParameters['Verbose'].IsPresent)
        {
            Write-Output -InputObject "$(Get-Date) [Verbose] $Message" -NoEnumerate | Out-File -FilePath $LogFile -Append
        }
        else
        {
            Write-Output -InputObject "$(Get-Date) $Message" -NoEnumerate | Out-File -FilePath $LogFile -Append
        }
    }
} #end function

Function Read-Log
{
<#
    .Synopsis
        Reads the latest log file, optionally displaying only the latest number of specified lines
    .Description
        Intended as a complement to the Write-Log function provided within the PSLogger module, Read-Log will find the latest log file in the
        defined $loggingPath directory, and return some basic stats of that file, as well as get it's contents for review
    .Parameter MessageSource
        The message source is an optional parameter that specifies which module, function, or script wrote the log file to be retrieved.
        If this parameter is not specified, function returns the latest available log file, regardless of message source.
        The value of this parameter becomes a filter to the search of .log files within the $loggingPath directory.
        .Parameter lineCount
        The most recent number of lines from the log file in question.
        unless the $logFilePref variable is found. If so, then this value will be used.
    .Example
        PS .\> Read-Log

        Returns basic file properties, and last 10 lines, of the latest / newest log file found in $loggingPath directory

    .Example
        PS .\> Read-Log -MessageSource Get-Profile -lineCount 30

        Returns latest log file, reading the latest 30 lines, specific to function Get-Profile

    .Notes
        NAME: Read-Log
        AUTHOR: Bryan Dady
        VERSION: 1.0
        LASTEDIT: 04/15/2015

    .Output
        Matches default properties return the same as Get-Item:
        * Name
        * LastWriteTime
        * Length
        * Path
#>
    [cmdletbinding()]
    Param(
        [Parameter(
            Mandatory = $false,
            Position = 0,
            HelpMessage = 'The message source typically matches a log filename string, which represents the name of the function or module which wrote the log file.'
        )]
        [Alias('function','source','f','m')]
        [string]$MessageSource,

        [Parameter(
            Mandatory = $false,
            Position = 1,
            HelpMessage = 'Provide an integer of line numbers to read from the bottom of the log file.'
        )]
        [ValidateNotNullOrEmpty()]
        [Alias('lines', 'l')]
        [int16]$lineCount = 10
    )
    # Use write-output instead of write-log, so that the function of reading log files does not write new log files to be read
    Write-Output -InputObject "Selecting latest log file to read last $lineCount lines"

Write-Output -InputObject "[Debug] Looking for log files with `$MessageSource is $MessageSource" -Debug
    # Select the newest (1) file (most recent LastWriteTime), with an optional filter, based on MessageSource parameter
    $latestLogFile = Get-ChildItem -Path $loggingPath -Filter *$MessageSource* -File |
    Sort-Object -Property LastWriteTime -Descending |
    Select-Object -First 1

Write-Output -InputObject "[Debug] `$latestLogFile is $latestLogFile" -Debug

    if (Test-Path -Path $latestLogFile -PathType Leaf -IsValid -ErrorAction Ignore)
    {
        Write-Output -InputObject "Selected $latestLogFile"
        $latestLogFile |
        Select-Object -Property Name, LastWriteTime |
        Format-List
        if ($lineCount -gt 0)
        {
            Write-Output -InputObject "`n ... "
            $latestLogFile | Get-Content -Tail $lineCount
            Write-Output -InputObject "`n[EOF]`n"
        }
    } else
    {
        Write-Warning -Message "Could not open $latestLogFile for reading"
    }
} #end function

Function Get-LatestLogs
{
    Get-ChildItem -Path $loggingPath |
    Sort-Object -Descending -Property LastWriteTime |
    Select-Object -First 10
}

# Export-ModuleMember -Function Backup-Logs, Get-StringHash, Write-Log, Read-Log, Get-LatestLogs, Show-Progress -Alias Archive-Logs