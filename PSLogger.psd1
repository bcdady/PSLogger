#
# Module manifest for module 'PSLogger'
#
# Generated by: Bryan Dady
#
# Generated on: 4/9/2015
# Last Updated: 11/16/2015

@{

# Script module or binary module file associated with this manifest.
RootModule = 'PSLogger.psm1'

# Version number of this module.
ModuleVersion = '1.4.3'

# ID used to uniquely identify this module
GUID = '5665bc78-c5ff-423b-86ba-71b65c15048e'

# Author of this module
Author = 'Bryan Dady'

# Company or vendor of this module
#CompanyName = ''

# Copyright statement for this module
Copyright = '(c) 2015 Bryan Dady. All rights reserved.'

# Description of the functionality provided by this module
Description = 'Modularized edition of write-log.ps1 (originally provided by Jeff Hicks) along with some added log management functions'

# Minimum version of the Windows PowerShell engine required by this module
PowerShellVersion = '3.0'

# Name of the Windows PowerShell host required by this module
# This is really more of a preference; this module is also fully functional in ISE, but intended for at least the author's purposes mostly in Console
# PowerShellHostName = ''

# Minimum version of the Windows PowerShell host required by this module
PowerShellHostVersion = '3.0'

# Minimum version of Microsoft .NET Framework required by this module
# DotNetFrameworkVersion = ''

# Minimum version of the common language runtime (CLR) required by this module
# CLRVersion = ''

# Processor architecture (None, X86, Amd64) required by this module
ProcessorArchitecture = 'None'

# Modules that must be imported into the global environment prior to importing this module
# RequiredModules = @()

# Assemblies that must be loaded prior to importing this module
# RequiredAssemblies = @()

# Script files (.ps1) that are run in the caller's environment prior to importing this module.
# ScriptsToProcess = @()

# Type files (.ps1xml) to be loaded when importing this module
# TypesToProcess = @()

# Format files (.ps1xml) to be loaded when importing this module
# FormatsToProcess = @()

# Modules to import as nested modules of the module specified in RootModule/ModuleToProcess
NestedModules = @('ShowProgress.psm1','BackupLogs.psm1','GetStringHash.psm1')

# Functions to export from this module
FunctionsToExport = 'Backup-Logs', 'Get-LatestLogs', 'Get-StringHash', 'Initialize-Logging', 'Read-Log', 'Show-Progress', 'Write-Log'

# Cmdlets to export from this module
# CmdletsToExport = @()

# Variables to export from this module
VariablesToExport = 'loggingPath'

# Aliases to export from this module
AliasesToExport = 'Archive-Logs'

# List of all modules packaged with this module
ModuleList = @('ShowProgress.psm1','BackupLogs.psm1','GetStringHash.psm1')

# List of all files packaged with this module
FileList = @('PSLogger.psm1','ShowProgress.psm1','BackupLogs.psm1','GetStringHash.psm1')

# Private data to pass to the module specified in RootModule/ModuleToProcess
# PrivateData = ''

# HelpInfo URI of this module
# HelpInfoURI = ''

# Default prefix for commands exported from this module. Override the default prefix using Import-Module -Prefix.
# DefaultCommandPrefix = ''

}

