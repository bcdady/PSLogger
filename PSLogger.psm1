#requires -version 3
<#
    .SYNOPSIS
        PSLogger is a PowerShell module to enhance and simplify interacting with log files on the file system.
    .DESCRIPTION
        PSLogger provides functions to Write logs, find / enumerate recently written log files, and Read the latest lines of recent .log files.
    .NOTES
        NAME        :  PSLogger
        LAST UPDATED:  01/18/2018 - Removed superfluous -Date parameter from Write-Log function. Various PSScriptAnalyzer compliance improvements
        AUTHOR      :  Bryan Dady | https://github.com/bcdady/
        Original Write-Log Author: Jeffery Hicks
        http://jdhitsolutions.com/blog
        http://twitter.com/JeffHicks
        Date: 3/3/2011
#>
[cmdletbinding()]
Param()

#Region MyScriptInfo
    Write-Verbose -Message '[PSLogger] Populating $MyScriptInfo'
    $Private:MyCommandName        = $MyInvocation.MyCommand.Name
    $Private:MyCommandPath        = $MyInvocation.MyCommand.Path
    $Private:MyCommandType        = $MyInvocation.MyCommand.CommandType
    $Private:MyCommandModule      = $MyInvocation.MyCommand.Module
    $Private:MyModuleName         = $MyInvocation.MyCommand.ModuleName
    $Private:MyCommandParameters  = $MyInvocation.MyCommand.Parameters
    $Private:MyParameterSets      = $MyInvocation.MyCommand.ParameterSets
    $Private:MyRemotingCapability = $MyInvocation.MyCommand.RemotingCapability
    $Private:MyVisibility         = $MyInvocation.MyCommand.Visibility

    if (($null -eq $Private:MyCommandName) -or ($null -eq $Private:MyCommandPath)) {
        # We didn't get a successful command / script name or path from $MyInvocation, so check with CallStack
        Write-Verbose -Message 'Getting PSCallStack [$CallStack = Get-PSCallStack]'
        $Private:CallStack      = Get-PSCallStack | Select-Object -First 1
        # $CallStack | Select Position, ScriptName, Command | format-list # FunctionName, ScriptLineNumber, Arguments, Location
        $Private:myScriptName   = $Private:CallStack.ScriptName
        $Private:myCommand      = $Private:CallStack.Command
        Write-Verbose -Message "`$ScriptName: $Private:myScriptName"
        Write-Verbose -Message "`$Command: $Private:myCommand"
        Write-Verbose -Message 'Assigning previously null MyCommand variables with CallStack values'
        $Private:MyCommandPath  = $Private:myScriptName
        $Private:MyCommandName  = $Private:myCommand
    }

    #'Optimize New-Object invocation, based on Don Jones' recommendation: https://technet.microsoft.com/en-us/magazine/hh750381.aspx
    $Private:properties = [ordered]@{
        'CommandName'        = $Private:MyCommandName
        'CommandPath'        = $Private:MyCommandPath
        'CommandType'        = $Private:MyCommandType
        'CommandModule'      = $Private:MyCommandModule
        'ModuleName'         = $Private:MyModuleName
        'CommandParameters'  = $Private:MyCommandParameters.Keys
        'ParameterSets'      = $Private:MyParameterSets
        'RemotingCapability' = $Private:MyRemotingCapability
        'Visibility'         = $Private:MyVisibility
    }
    $MyScriptInfo = New-Object -TypeName PSObject -Property $Private:properties
    Write-Verbose -Message '[PSLogger] $MyScriptInfo populated'

    # Cleanup
    foreach ($var in $Private:properties.Keys) {
        Remove-Variable -Name ('My{0}' -f $var) -Scope Private -Force
    }

    $IsVerbose = $false
    if ('Verbose' -in $PSBoundParameters.Keys) {
        Write-Verbose -Message 'Output Level is [Verbose]. $MyScriptInfo is:'
        $IsVerbose = $true
        $MyScriptInfo
    }
#End Region

# Declare Variables Shared across module functions
New-Variable -Name LogFile           -Value $false -Option AllScope
New-Variable -Name LogFileDateString -Value $false -Option AllScope
New-Variable -Name LoggingPath       -Value $false -Option AllScope -Force
New-Variable -Name LoggingPreference -Value $false -Option AllScope
New-Variable -Name WriteIntro        -Value $true  -Option AllScope -Force
New-Variable -Name LastFunction      -Value 'Console' -Option AllScope -Force -Description 'Retain the name of the last function logged, to streamline log output from the same function'

function Initialize-Logging {
    <#
        .Synopsis
            Sets up shared constants and variables for PSLogger module
        .Description

        .Parameter logPref
            Optional override for using the Write-Log function without writing to a log file
        .Parameter Path
            Optional override for the directory path to write log files to
        .Parameter Date
            The filename and path for the log file. The default is defined as $LoggingPath (above)
            If $LogFilePref variable is (bound) and passed into the Write-Log function, then that override path value will be used.

        .EXAMPLE
            PS .\> Initialize-Logging

            Initializes all default constants for PSLogger functions

        .EXAMPLE
            PS .\>Initialize-Logging -Path C:\PSlogs -Verbose

            Initializes logging path to C:\PSlogs for PSLogger Write-Log function, with verbose output

        .Link
            Write-Log
    #>
    [cmdletbinding(SupportsShouldProcess)]
    Param(
        [Parameter(Position = 0)]
        [ValidateSet('','Continue','SilentlyContinue','Ignore')]
        [string]
        $logPref = 'Continue',
        [Parameter(Position = 1,
            ValueFromRemainingArguments = $true
        )]
        [ValidateScript({Test-Path -Path $PSItem -PathType Container -IsValid})]
        [Alias('Root', 'Directory')]
        [String]
        $Path = $myPSLogPath
    )

    # set $LoggingPreference to anything other than continue, to leverage write-debug or write-verbose, without writing to a log on the filesystem
    Set-Variable -Name LogFileDateString -Value (Get-Date -Format FileDate)
    Set-Variable -Name LoggingPath       -Value $Path
    Set-Variable -Name LoggingPreference -Value 'Continue'

    # If $LoggingPath looks like a UNC path, replace it with a mapped drive letter path
    $UserProfilePath = Split-Path -Path ([Environment]::GetFolderPath('MyDocuments')) -Parent
    if ( -not $UserProfilePath -eq $Env:USERPROFILE) {
        $LoggingPath = $LoggingPath.Replace($UserProfilePath+'\',(Get-PSDrive -PSProvider FileSystem | Where-Object -FilterScript { $PSItem.DisplayRoot -eq $UserProfilePath}).Root)
    }

    # $LogFileDateString = $Date -as [string]
    Write-Debug -Message ('Initialize PSLogging : logPref = {0}, Path = {1}, Date = {2}' -f $LoggingPreference, $LoggingPath, $LogFileDateString)

    #New-Variable -Name LastFunction -Description "Retain 'state' of the last function name called, to streamline Logging statements from the same function" -Force -Visibility Public
    $WriteIntro = $true
} #end function Initialize-Logging

Function Write-Log {
    <#
        .Synopsis
        Write a message to a log file.
        .Description
        Write-Log can be used to write text messages to a log file. It can be used like Write-Verbose,
        and looks for two variables that you can define in your scripts and functions. If the function
        finds $LoggingPreference with a value of "Continue", the message text will be written to the file.
        The default file is PowerShellLog.txt in your %TEMP% directory. You can specify a different file
        path by parameter or set the $LogFilePref variable. See the help examples.

        This function also supports Write-Verbose which means if -Verbose is detected, the message text
        will be written to the Verbose pipeline. Thus if you call Write-Log with -Verbose and a the
        $LoggingPreference variable is set to continue, you will get verbose messages AND a log file.
        .Parameter Message
        The message string to write to the log file. It will be prepended with a date time stamp.
        .Parameter Function
        The Function Parameter passes the name of the Function or CmdLet that invoked the Write-Log function.
        This is used to write related log messages into a topical log file, instead of writing all log messages into a common file
        If not specified, this defaults to 'PowerShell'
        .Parameter Path
        The filename and path for the log file. The default is defined as $LoggingPath (above)
        If $LogFilePref variable is (bound) and passed into the Write-Log function, then that override path value will be used.

        .EXAMPLE
        PS .\>Write-Log -Message "Test Message ... this is a test of the Write-Log function" -Function TEST

        .EXAMPLE
        PS .\>Write-Log -Message "Test Message ... this is another test of the Write-Log function, to a custom specified path" -Function TEST -Path $env:TEMP\testing.log

        .Notes
        NAME: Write-Log
        AUTHOR: Bryan Dady, adapted from original work by Jeffery Hicks
        VERSION: 1.3.5
        UPDATED: 11/16/2015

        .Link
        http://jdhitsolutions.com/blog/2011/03/powershell-automatic-logging/

        .Link
        Write-Verbose
    #>
    [cmdletbinding(SupportsShouldProcess)]
    Param(
        [Parameter(
			Mandatory,
            Position = 0,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            HelpMessage = 'The message string to write to the log file. It will be prepended with a date time stamp.'
        )]
        [ValidateNotNullOrEmpty()]
        [string]
        $Message,
        [Parameter(Position = 1,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true
        )]
        [ValidateNotNullOrEmpty()]
        [Alias('Action', 'Source')]
        [String]
        $Function = 'PowerShell',
        [Parameter(Position = 2,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true
        )]
        [ValidateScript({Test-Path -Path $PSItem -PathType Any})]
        [Alias('Folder', 'Directory')]
        [string]
        $Path,
        [Parameter(Position = 3)]
        [switch]$PassThru
    )

    # Gracefully handle condition where $Function is null
    if (-not (Get-Variable -Name Function -ErrorAction SilentlyContinue)) {
        Write-Verbose -Message 'Resetting $Function to PowerShell'
        $Function = 'PowerShell'
    }

    # Jun 2017 -- add some sanity checking / validation
    if ($Function.Contains('.')) {
        Write-Debug -Message ('$Function = {0}' -f (Split-Path -Path $Function -Leaf))
        $Function = $(Split-Path -Path $Function -Leaf).Split('.')[0]
    }

    # Gracefully handle condition when  $LastFunction is null
    if (-not (Get-Variable -Name LastFunction -ErrorAction SilentlyContinue)) {
        Write-Verbose -Message 'Matching $LastFunction to $Function'
        $LastFunction = $Function
    }
    Write-Debug -Message ('$LastFunction is {0}' -f $LastFunction)

    # Check if logging is initialized, and if not, call Initialize-Logging to initialize defaults
    if ($LoggingPath) {
        Write-Verbose -Message ('$LoggingPath is: {0}' -f $LoggingPath)
        if (Test-Path -Path $LoggingPath -PathType Container -ErrorAction SilentlyContinue) {
            Write-Debug -Message ('PSLogger is initialized to these variables: logPref = {0}, Path = {1}, Date = {2}' -f $LoggingPreference, $LoggingPath, $LogFileDateString)
        } else {
            Write-Debug -Message '$LoggingPath unavailable; Re- Initialize-Logging'
    	    Initialize-Logging
        }
    } else {
        Write-Verbose -Message 'Initialize-Logging'
        Initialize-Logging
    }

    # Detect if this Function is the same as the $LastFunction. If not, verbosely log which new Function is active
    if ($Function -eq $LastFunction) {
        # Retain 'state' of the last function name called, to streamline logging statements from the same function
        $WriteIntro = $false
    } else {
        $LastFunction = $Function
        $WriteIntro = $true
    }

    Write-Debug -Message ('$LoggingPath is {0}' -f [bool]$LoggingPath)
    # Gracefully handle condition where local scope $LoggingPath is null
    if ($LoggingPath) {
        $Private:LogFileName = ('{0}_{1}.log' -f $Function, $LogFileDateString)
        $LogFilePref = Join-Path -Path $LoggingPath -ChildPath $Private:LogFileName

        # Detect -debug mode:
        # http://blogs.msdn.com/b/powershell/archive/2009/04/06/checking-for-bound-parameters.aspx
        # https://kevsor1.wordpress.com/2011/11/03/powershell-v2-detecting-verbose-debug-and-other-bound-parameters/
        $testMode = $false
        if ('Debug' -in $PSBoundParameters.Keys) {
            [bool]$testMode = $true
            $LoggingPath = Join-Path -Path $LoggingPath -ChildPath 'Debug'

            if (-not (Test-Path -Path $LoggingPath -PathType Container)) {
                Write-Verbose -Message ('Updating $LoggingPath to {0}' -f $LoggingPath)
                New-Item -Path $LoggingPath -ItemType Directory -Force
            }
        }

        Write-Debug -Message ('$LogFilePref is {0}' -f $LogFilePref)
    } else {
        Write-Debug -Message '$LoggingPath is Undefined. Proceeding with host output only'
        $LogFilePref = $NULL
        $LoggingPreference = 'Ignore'
        if ($WriteIntro) {
            Write-Warning -Message 'Log File Undefined. Proceeding with host output only.'
        }
    }

    # Pass on the message to Write-Debug cmdlet if -Debug parameter was used
    if ($testMode) {
        Write-Debug -Message $Message
        if ($WriteIntro -and ( $Message -NotLike 'Exit*')) {
            Write-Output -InputObject ('Logging [Debug] to {0}' -f $LogFilePref)
        }
    }
    if ('Verbose' -in $PSBoundParameters.Keys) {
        #Pass on the message to Write-Verbose cmdlet if -Verbose parameter was used
        Write-Verbose -Message $Message
    } else {
        Write-Debug -Message ('WriteIntro: {0}. ($Message -NotLike Exit*): {1}' -f $WriteIntro, [bool]($Message -NotLike 'Exit*'))
        Write-Debug -Message ('LogFilePref: {0}' -f [bool]$LogFilePref)
        if ($WriteIntro -and ($Message -NotLike 'Exit*')) {
            if ($LogFilePref) {
                Write-Verbose -Message ('Logging to {0}' -f $LogFilePref)
            }
        }
    }

    # Only write to the log file if the $LoggingPreference variable is set to Continue
    if ($LoggingPreference -eq 'Continue') {
        # Before writing a copy of $Message to an output file, strip line breaks and/or other formatting that could interfere with clear/standardized logging
        $Message = $Message -replace "`n", ' '
        $Message = $Message -replace '\s{2,}', ' '

        #if $Path parameter was specified, then use it, otherwise use the derived $LogFilePref
        Set-Variable -Name LogFile -Value $LogFilePref -Force
        Write-Debug -Message (' # $LogFile is: {0}' -f $LogFile)
        if ($Path) {
            Write-Verbose -Message ('Set-Variable -Name LogFile -Value {0} -Force -PassThru' -f (Join-Path -Path $Path -ChildPath $Private:LogFileName))
            Set-Variable -Name LogFile -Value (Join-Path -Path $Path -ChildPath $Private:LogFileName) -Force
        }

        # Confirm or create LogFile path, otherwise Out-File throws DirectoryNotFoundException;
        # Only need to do this once per unique $LogFile path, so use $WriteIntro as that flag
        Write-Debug -Message ('(Test-Path -Path $(Split-Path -Path $LogFile -Parent) -PathType Container) = {0}' -f (Test-Path -Path $(Split-Path -Path $LogFile -Parent) -PathType Container))

        if (-not (Test-Path -Path $(Split-Path -Path $LogFile -Parent) -PathType Container)) {
            New-Item -Path $(Split-Path -Path $LogFile) -Force -ItemType Directory
        }

        Write-Debug -Message (' # # $LogFile is: {0}' -f $LogFile)

        if ($WriteIntro) {
            Write-Verbose -Message ('{0} [Write-Log] {1}' -f (Get-Date), $LogFile)
            if ($PassThru) {
                Write-Output -InputObject ('{0} [Write-Log] {1}' -f (Get-Date), $LogFile) #  | Out-Host
            }
        }

        if ($testMode) {
            Write-Output -InputObject ('{0} [Debug] {1}' -f (Get-Date), $Message) | Out-File -FilePath $LogFile -Append
        }

        if ('Verbose' -in $PSBoundParameters.Keys) {
            Write-Output -InputObject ('{0} [Verbose] {1}' -f (Get-Date), $Message) | Out-File -FilePath $LogFile -Append
        }

        if ($PassThru) {
            Write-Output -InputObject ('{0} {1}' -f (Get-Date), $Message) | Tee-Object -FilePath $LogFile -Append
        } else {
            Write-Output -InputObject ('{0} {1}' -f (Get-Date), $Message) | Out-File -FilePath $LogFile -Append
        }
    } else {
        if ($PassThru) {
            Write-Output -InputObject ('{0} {1}' -f (Get-Date), $Message)
        }
    }
} #end function Write-Log

Function Read-Log {
    <#
        .Synopsis
            Reads the latest log file, optionally displaying only the latest number of specified lines
        .Description
            Intended as a complement to the Write-Log function provided within the PSLogger module, Read-Log will find the latest log file in the
            defined $LoggingPath directory, and return some basic stats of that file, as well as get it's contents for review
        .Parameter MessageSource
            The message source is an optional parameter that specifies which module, function, or script wrote the log file to be retrieved.
            If this parameter is not specified, function returns the latest available log file, regardless of message source.
            The value of this parameter becomes a filter to the search of .log files within the $LoggingPath directory.
            .Parameter lineCount
            The most recent number of lines from the log file in question.
            unless the $LogFilePref variable is found. If so, then this value will be used.
        .Example
            PS .\> Read-Log

            Returns basic file properties, and last 10 lines, of the latest / newest log file found in $LoggingPath directory

        .Example
            PS .\> Read-Log -MessageSource Get-Profile -lineCount 30

            Returns latest log file, reading the latest 30 lines, specific to function Get-Profile

        .Notes
            NAME: Read-Log
            AUTHOR: Bryan Dady
            VERSION: 1.0
            UPDATED: 04/15/2015

        .Output
            Matches default properties return the same as Get-Item:
            * Name
            * LastWriteTime
            * Length
            * Path
    #>
    [cmdletbinding(SupportsShouldProcess)]
    Param(
        [Parameter(Position = 0)]
        [Alias('function','source','f','m')]
        [string]
        $MessageSource,
        [Parameter(Position = 1)]
        [ValidateNotNullOrEmpty()]
        [Alias('lines', 'l')]
        [int]$lineCount = 10
    )

    Write-Output -InputObject ('Selecting latest log file to read last {0} lines' -f $lineCount)
    Write-Verbose -Message ('Looking for log files in {0}' -f $LoggingPath)
    Write-Verbose -Message ('Looking for log files with $MessageSource matching "{0}"' -f $MessageSource)

    $latestLogFile = $null
    # Select the newest (1) file (most recent LastWriteTime), with an optional filter, based on MessageSource parameter
    $latestLogFile = Get-ChildItem -Path $LoggingPath -Filter "*$MessageSource*" -File | Sort-Object -Property LastWriteTime -Descending | Select-Object -First 1

    Write-Verbose -Message ('$latestLogFile is "{0}"' -f $latestLogFile)

    if (Test-Path -Path $latestLogFile.FullName -ErrorAction SilentlyContinue) {
        Write-Verbose -Message ('Reading log file {0}' -f $latestLogFile.FullName)
        $latestLogFile | Select-Object -Property Name, LastWriteTime | Format-List
        if ($lineCount -gt 0) {
            Write-Output -InputObject "`n ... "
            $latestLogFile | Get-Content -Tail $lineCount
            Write-Output -InputObject "`n[EOF]`n"
        }
    } else {
        Write-Warning -Message ('No matching log file(s) found, or could not open "{0}" for reading' -f $latestLogFile)
    }
} #end function Read-Log

Function Get-LatestLog {
    <#
        .SYNOPSIS
        Enumerates most recently written-to log files
        .DESCRIPTION
        Enumerates most recently written-to log files.
        By default, this function looks in the folder specified by the Globally defined $LoggingPath variable, for the 10 files with the most recent LastWriteTime property.

        .EXAMPLE
        PS .\> Get-LatestLog
        Enumerates most recent 10 files in the default \log\ folder
        .PARAMETER Path
        Specifies which folder to enumerate files from
        Default is $LoggingPath
        .PARAMETER Count
        Specifies how many recent / latest log files to return
        Default is 10
        .NOTES
        Last Updated June 30, 2017 -- Get-LatestLogs function: Corrected handling of Count parameter. Added Comment-based help. Made function name singular.
    #>
    [cmdletbinding()]
    Param(
        [Parameter(Position = 0,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true
        )]
        [ValidateScript({Test-Path -Path $PSItem -PathType Any})]
        [string]
        $Path = $myPSLogPath
        ,
        [Parameter(Position = 1)]
        [ValidateRange(1,99)]
        [Alias('c')]
        [int]$Count = 10
    )

    Write-Verbose -Message ('Checking for most recent {0} log files at path {1}' -f $Count, $Path)
    Write-Debug -Message "Get-ChildItem -Path $Path | Sort-Object -Descending -Property LastWriteTime |  Select-Object -First $Count"

    return (Get-ChildItem -Path $Path -Exclude 'archive' | Sort-Object -Descending -Property LastWriteTime | Select-Object -First $Count)
} #end function Get-LatestLog
