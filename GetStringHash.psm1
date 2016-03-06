#requires -Version 1

<#




#>

Function Get-StringHash 
{<#
.SYNOPSIS
    Similar to Get-FileHash, computes the hash value for a string by using a specified hash algorithm.
.DESCRIPTION
    Get-StringHash computes the hash value for a string by using a specified hash algorithm. A hash value is a unique value that
    corresponds to the characters of the string. 

    The purpose of hash values is to provide a cryptographically consistent and reliable way to summarize or abstract a string by
    using a seemingly random token. While some hash algorithms, including MD5 and SHA1, are no longer considered secure, they still
    useful, and somewhat common mechanisms to generate summary hashes/token values for other, more complex data elements.

    By default, the Get-StringHash cmdlet uses the SHA256 algorithm, although all hash algorithms that are also supported by Get-FileHash
    cmdlet can be used.

.PARAMETER String
    String to be encoded through the hash function / algorithm

.PARAMETER Algorithm
    Specifies the cryptographic hash function to use for computing the hash value of the contents of the specified string. A
    cryptographic hash function includes the property that it is not possible to find two distinct inputs that generate the
    same hash values. Hash functions are commonly used with digital signatures and for data integrity. Valid values for this
    parameter are SHA1, SHA256, SHA384, SHA512, MACTripleDES, MD5, and RIPEMD160. If no value is specified, or if the
    parameter is omitted, the default value is SHA256.

    For security reasons, MD5 and SHA1, which are no longer considered secure, should only be used for simple change
    validation, and should not be used to generate hash values for strings that require protection from attack or tampering.

    MACTripleDES creates the shortest hash value string length
    .Example

    PS .\> Get-StringHash http://jongurgul.com/blog/get-stringhash-get-filehash/ | Format-List

    
    Algorithm : SHA256
    Hash      : a91e4392f788b8800b32c6bdc03db6385c373ff5983ba0a5b35f4babe9b4ec99
    String    : http://jongurgul.com/blog/get-stringhash-get-filehash/

    This example uses the Get-StringHash cmdlet to compute the hash value for the URL for this function. The hash algorithm used is
    the default, SHA256. The output is piped to the Format-List cmdlet to format the output as a list.
    
    .Example

    PS .\> Get-StringHash -string "Treat your servers like cattle, not pets" -Algorithm MD5

    Hash                                        Algorithm          String
    ----                                        ---------          ------
    3ef0c0330b5602ad44f78a9ec38e0245            MD5                Treat your servers like cattle, not pets

    This command uses the Get-StringHash cmdlet and the MD5 algorithm to compute the hash value for one of my favorite quotes from Jeffrey Snover (@jsnover)

.NOTES
NAME            :  Get-StringHash
VERSION         :  1.1   
LAST UPDATED    :  12/1/2015
AUTHOR          :  Bryan Dady @bcdady
Version History :
        1.0 - create .psm1 script module from Get-StringHash code on TechNet Gallery.
        1.1 - Update/refactor with ISESteroids and ISEScriptingGeek's 'Add Help' cmdlet
.LINK
    https://gallery.technet.microsoft.com/scriptcenter/Get-StringHash-aa843f71
.LINK
    http://jongurgul.com/blog/get-stringhash-get-filehash/ .LINK
.LINK
    PSLogger 
.INPUTS
None
.OUTPUTS
None
#>
     param
     (
        [Parameter(Mandatory=$true, Position=0, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true,
        HelpMessage='Specify string to be hashed. Accepts from pipeline.')]
        [alias('text','InputObject')]
        [ValidateNotNullOrEmpty()]
        [string]
        $String,

        [Parameter(Mandatory=$false, Position=1, ValueFromPipeline=$false, ValueFromPipelineByPropertyName=$false,
        HelpMessage='Specify string to be hashed. Accepts from pipeline.')]
        [alias('HashName')]
        [ValidateSet('SHA1', 'SHA256', 'SHA384', 'SHA512', 'MACTripleDES', 'MD5', 'RIPEMD160')]
        [string]
        $Algorithm = 'SHA256'
     )
 
    $StringBuilder = New-Object -TypeName System.Text.StringBuilder 
    [System.Security.Cryptography.HashAlgorithm]::Create($Algorithm).ComputeHash([System.Text.Encoding]::UTF8.GetBytes($String)) | ForEach-Object -Process {
        [Void]$StringBuilder.Append($_.ToString('x2'))
    }

    #'Optimize New-Object invocation, based on Don Jones' recommendation: https://technet.microsoft.com/en-us/magazine/hh750381.aspx
    $Private:properties = @{
        'Algorithm' = $Algorithm
        'Hash'      = $StringBuilder.ToString() 
        'String'    = $String
    }

    $Private:RetObject = New-Object –TypeName PSObject –Prop $properties | Sort-Object
    return $RetObject 
    
}
