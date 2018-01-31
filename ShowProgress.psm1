﻿#Requires -Version 3.0

function Show-Progress  {
  <#
    .SYNOPSIS
        Extension of Sperry module, to simplify logging of function calls, with matching messages to the console, when specified
    .DESCRIPTION
        Built on to the Write-Log function / script originally provided by Jeff Hicks, this script makes the Show-Progress function portable, as part of the PSLogger Module
    .PARAMETER msgAction
        The stampType parameter specifies to the Show-Progress function whether the update written to the log and/or shown on the console is a Start, Stop, or continue action.
        When passed to the Write-Log function, the Show-Progress message inherits the time-stamp and other features of that function.

    .PARAMETER msgSource
        The msgSource parameter specifies to the Show-Progress function the module or function name to associate the Show-Progress message with.
        This can be passed in via the $MyInvocation.MyCommand.Name variable, so that the output log file the message is written to dynamically matches the script/module/function it was called by.

    .EXAMPLE
        PS .\> Show-Progress 'Start'
        
        Log start time-stamp by passing a standard message through the Write-Log function

    .EXAMPLE
        PS .\> Show-Progress 'Stop'
        
        Log end time-stamp by passing a standard message through the Write-Log function

    .NOTES
        NAME        :  Show-Progress
        VERSION     :  1.0.2
        LAST UPDATED:  11/16/2015
        AUTHOR      :  Bryan Dady
    #>
    [cmdletbinding()]
    param (
        [Parameter(Mandatory,Position=0)]
        [alias('mode','scope')]
        [ValidateSet('Start', 'Stop',$null)]
        [String]
        $msgAction,
        [Parameter(Position=1)]
        [alias('action','source')]
        [string]$msgSource = 'PowerShell'
    )

	Switch ($msgAction) {
        'Start' {
			Write-Log -Message "Starting $msgSource`n" -Function "$msgSource"
		}
        'Stop' {
			Write-Log -Message "Exiting $msgSource`n`n" -Function "$msgSource"
		}
        default {
            Write-Log -Message "continuing $msgSource`n" -Function $msgSource
        }
    }
}
