# PSLogger

PSLogger is a PowerShell module crafted to make logging of PowerShell cmdlets and functions easy and consistent to use.

## Functions

### Backup-Logs

#### Alias

Archive-Logs

### Get-LatestLog

SYNOPSIS
    Enumerates most recently written-to log files

SYNTAX
    Get-LatestLog [[-Path] <String>] [[-Count] <Int32>] [<CommonParameters>]

DESCRIPTION
    Enumerates most recently written-to log files.
    By default, this function looks in the folder specified by the Globally defined $LoggingPath variable, for the 10 files with the most recent LastWriteTime property.

### Get-StringHash

SYNOPSIS
    Similar to Get-FileHash, computes the hash value for a string by using a specified hash algorithm.

SYNTAX
    Get-StringHash [-String] <String> [[-Algorithm] <String>] [<CommonParameters>]

DESCRIPTION
    Get-StringHash computes the hash value for a string by using a specified hash algorithm. A hash value is a unique value that corresponds to the characters of the string.

    The purpose of hash values is to provide a cryptographically consistent and reliable way to summarize or abstract a string by using a seemingly random token. While some hash algorithms, including MD5 and SHA1, are no longer considered secure, they still useful, and somewhat common mechanisms to generate summary hashes/token values for other, more complex data elements.

    By default, the Get-StringHash cmdlet uses the SHA256 algorithm, although all hash algorithms that are also supported by Get-FileHash cmdlet can be used.

### Initialize-Logging

SYNOPSIS
    Sets up shared constants and variables for PSLogger module

SYNTAX
    Initialize-Logging [[-logPref] <String>] [[-Path] <String>] [-WhatIf] [-Confirm] [<CommonParameters>]

### Read-Log

SYNTAX
    Read-Log [[-MessageSource] <string>] [[-lineCount] <int>] [-WhatIf] [-Confirm]  [<CommonParameters>]

DESCRIPTION
    Read-Log is the complement to Write-Log, providing more convenient access to Get-Content of the log files written to by Write-Log.

### Show-Progress

SYNOPSIS
    Extension of Sperry module, to simplify logging of function calls, with matching messages to the console, when specified

SYNTAX
    Show-Progress [-msgAction] <String> [[-msgSource] <String>] [<CommonParameters>]

DESCRIPTION
    Built on to the Write-Log function / script originally provided by Jeff Hicks, this script makes the Show-Progress function portable, as part of the PSLogger Module.

### Write-Log

SYNOPSIS
    Write a message to a log file.
*This is the one that does the heavy lifting*

SYNTAX
    Write-Log [-Message] <String> [[-Function] <String>] [[-Path] <String>] [[-PassThru]] [-WhatIf] [-Confirm] [<CommonParameters>]

DESCRIPTION
    Write-Log can be used to write text messages to a log file. It can be used like Write-Verbose, and looks for two variables that you can define in your scripts and functions. If the function finds $LoggingPreference with a value of "Continue", the message text will be written to the file.

    The default file is PowerShellLog.txt in your %TEMP% directory. You can specify a different file path by parameter or set the $LogFilePref variable. See the help examples.

    This function also supports Write-Verbose which means if -Verbose is detected, the message text will be written to the Verbose pipeline. Thus if you call Write-Log with -Verbose and a the $LoggingPreference variable is set to continue, you will get verbose messages AND a log file.

RELATED LINKS
    http://jdhitsolutions.com/blog/2011/03/powershell-automatic-logging/
