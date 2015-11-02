#requires -version 2.0
<#
.SYNOPSIS
  PSLogger is a PowerShell module to enhance and simplify interacting with log files on the file system.
.DESCRIPTION
  PSLogger provides functions to Write logs, find / enumerate recently written log files, and Read the latest lines of recent .log files.
.NOTES
  NAME        :  PSLogger
  VERSION     :  2.1.1   
  LAST UPDATED:  5/12/2015
  AUTHOR      :  Bryan Dady
  Original Write-Log Author: Jeffery Hicks
    http://jdhitsolutions.com/blog
    http://twitter.com/JeffHicks
    Date: 3/3/2011
.LINK
  https://github.com/bcdady/
.LINK
  http://bryan.dady.us
.LINK
  http://twittter.com/bcdady
#>

# Setup necessary configs for PSLogger's Write-Log cmdlet
[string]$loggingPreference='Continue'; # set $loggingPreference to anything other than continue, to leverage write-debug or write-verbose, without writing to a log on the filesystem
[string]$loggingPath = "$env:userprofile\Documents\WindowsPowerShell\log"
[string]$logFileDateString = get-date -UFormat '%Y%m%d'; # Need to keep an eye on this one, in case PowerShell sessions run for multiple days, I doubt this variable value will be refreshed / updated
# [string]$LastFunction;
New-Variable -Name LastFunction -Description "Retain 'state' of the last function name called, to streamline logging statements from the same function" -Force -Scope Global -Visibility Public
[bool]$writeIntro=$true
[string]$global:LastFunction;

Function Write-Log {
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
    .Parameter Path
        The filename and path for the log file. The default is $env:temp\PowerShellLog.txt, 
        unless the $logFilePref variable is found. If so, then this value will be used.
   .Example
        PS C:\> . c:\scripts\write-log.ps1
    
    Here is a sample function that uses the Write-Log function after it has been dot sourced. Within the sample 
    function, the logging variables are defined.
    
Function TryMe {
    [cmdletbinding()]
    Param([string]$computername=$env:computername,
    [string]$Log
    )
    if ($log) 
    {
     $loggingPreference="Continue"
     $logFilePref=$log
    }
    Write-log "Starting Command"
    Write-log "Connecting to $computername"
    $b=gwmi win32_bios -ComputerName $computername
    $b
    Write-log $b.version
    Write-Log "finished" $log
}

TryMe -log e:\logs\sample.txt -verbose
  
   .Notes
    NAME: Write-Log
    AUTHOR: Jeffery Hicks
    VERSION: 1.0
    LASTEDIT: 03/02/2011
    
    Learn more with a copy of Windows PowerShell 2.0: TFM (SAPIEN Press 2010)
    
   .Link
       http://jdhitsolutions.com/blog/2011/03/powershell-automatic-logging/
    
    .Link
        Write-Verbose
#>
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true, Position=0, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true, HelpMessage='The message string to write to the log file. It will be prepended with a date time stamp.')]
        [ValidateNotNullOrEmpty()]
        [string]$Message,

        [Parameter(Mandatory=$false, 
                   ValueFromPipeline=$true,
                   ValueFromPipelineByPropertyName=$true, 
                   ValueFromRemainingArguments=$false, 
                   Position=1,
                   HelpMessage='The Function Parameter passes the name of the Function or CmdLet that invoked this Write-Log function')]
        [ValidateNotNullOrEmpty()]
        [Alias('Action', 'Source')]
        [String[]]
        $Function,

        [Parameter(Position=2,
                   ValueFromPipeline=$true,
                   ValueFromPipelineByPropertyName=$true, 
                   ValueFromRemainingArguments=$false, 
                   HelpMessage='The optional Path parameter specifies the path of the log file to write the message to.')]
        [string[]]
	    $Path="$env:userprofile\Documents\WindowsPowerShell\log\PowerShell.log"

    )

    # Detect -debug mode:
    # http://blogs.msdn.com/b/powershell/archive/2009/04/06/checking-for-bound-parameters.aspx
    # https://kevsor1.wordpress.com/2011/11/03/powershell-v2-detecting-verbose-debug-and-other-bound-parameters/
    if ($PSBoundParameters['Debug'].IsPresent) {
	    [bool]$testMode = $true; 
        $logFilePref = Join-Path -Path "$loggingPath\test" -ChildPath "$("$Function", "$logFileDateString" -join '_').log"
    } else {
	    [bool]$testMode = $false; 
        $logFilePref = Join-Path -Path "$loggingPath" -ChildPath "$("$Function", "$logFileDateString" -join '_').log";
    }

    # Assign Function variable to 'PowerShell' if blank or null
    if (($Function -eq $null) -or ($Function -eq '')) { $Function = 'PowerShell' }

    # Detect if this Function is the same as the $LastFunction. If not, verbosely log which new Function is active
    if ($Function -eq $LastFunction) {
        # Retain 'state' of the last function name called, to streamline logging statements from the same function
#        Write-Debug -Message "Function is $Function";
#        Write-Debug -Message "LastFunction is $LastFunction";
        $writeIntro=$false;
    } else {
#        Write-Debug -Message "Shifting from LastFunction $LastFunction to $Function, so `$writeIntro=`$true";
        Set-Variable -Name LastFunction -Value $Function -Force -Scope Global
        $writeIntro=$true;
#        Write-Output -Message "LastFunction is now $LastFunction";
    }

    #Pass on the message to Write-Debug cmdlet if -Debug parameter was used
    if ($testMode) {
        Write-Debug -Message $Message;
        if ($writeIntro -and ( $Message -notlike 'Exit*')) {Write-Host -Object "Logging [Debug] to $logFilePref`n" };
    } elseif ($PSBoundParameters['Verbose'].IsPresent) {
        #Pass on the message to Write-Verbose cmdlet if -Verbose parameter was used
        Write-Verbose -Message $Message;
        if ($writeIntro -and ( $Message -notlike 'Exit*')) { Write-Host -Object "Logging to $logFilePref`n" };
    }

    #only write to the log file if the $LoggingPreference variable is set to Continue
    if ($LoggingPreference -eq 'Continue') {
    
        #if a $logFilePref variable is found in the scope hierarchy then use that value for the file, otherwise use the default $path
        if ($logFilePref) {
		    $LogFile=$logFilePref
        } else {
		    $LogFile=$Path
        }
        if ($testMode) {
            Write-Output "$(Get-Date) [Debug] $Message" -NoEnumerate | Out-File -FilePath $LogFile -Append
        } elseif ($PSBoundParameters['Verbose'].IsPresent) {
            Write-Output "$(Get-Date) [Verbose] $Message" -NoEnumerate | Out-File -FilePath $LogFile -Append
        } else {
            Write-Output "$(Get-Date) $Message" -NoEnumerate | Out-File -FilePath $LogFile -Append
        }
    }

} #end function

Function Read-Log {
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
            Mandatory=$false,
            Position=0,
            HelpMessage='The message source typically matches a log filename prefix, which represents the name of the function or module which wrote the log file.'
        )]
        [Alias('function','source','f','m')]
        [string]
        $MessageSource,

        [Parameter(
            Mandatory=$false, 
            Position=1,
            HelpMessage='Provide an integer of line numbers to read from the bottom of the log file.'
        )]
        [ValidateNotNullOrEmpty()]
        [Alias('lines', 'l')]
        [int16]
        $lineCount=10
    )
    # Use write-output instead of write-log, so that the function of reading log files does not write new log files to be read
    Write-Output -InputObject "Selecting latest log file to read last $lineCount lines";

    # Select the newest (1) file (most recent LastWriteTime), with an optional filter, based on MessageSource parameter
    $latestLogFile = Get-ChildItem -Path $loggingPath -Filter *$MessageSource* -File | Sort-Object -Property LastWriteTime -Descending | Select-Object -First 1;

    if (Test-Path -Path $latestLogFile -PathType Leaf -IsValid) {
        Write-Output -InputObject "Selected $latestLogFile";
        $latestLogFile | Select-Object -Property Name,LastWriteTime | Format-List
        if ($lineCount -gt 0) {
            Write-Output -InputObject "`n ... ";
            $latestLogFile | Get-Content -Tail $lineCount;
            Write-Output -InputObject "`n[EOF]`n";
        }
    } else {
        Write-Warning -Message "Could not open $latestLogFile for reading";
    }

} #end function

Function Get-LatestLogs {
    Get-ChildItem $env:userprofile\Documents\WindowsPowerShell\log | Sort-Object -Descending -Property LastWriteTime | Select-Object -First 10
}

Export-ModuleMember -function *