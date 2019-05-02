<#
.SYNOPSIS
    Copies folders or a single file to our package fileshare.
.DESCRIPTION
    Recursively copies the contents of the given sources or a single file to our packages fileshare.
.PARAMETER Source
    Array of paths or a single file path to save.
.PARAMETER Product
    The name of the product we're saving build artifacts for.
.PARAMETER Branch
    The name of the branch we're saving build artifacts for.
.PARAMETER Version
    The version that we're saving build artifacts for.
.EXAMPLE
    Save-BuildArtifacts -Source '.\Environment', '.\Passwords' -Product Relativity -Branch Develop -Version 1.2.3.4
#>

function Save-BuildArtifacts {
    [CmdletBinding()]
    param(
        [parameter(ValueFromPipeline=$True, Mandatory=$True)]
        [string[]] $Source,

        [parameter()]
        [string] $Product,

        [parameter()]
        [string] $Branch,

        [parameter()]
        [string] $Version
    )

    BEGIN
    {
        Write-Verbose "Begin saving build aftifacts."
    }

    PROCESS
    {
        $Destination = ([IO.Path]::Combine("\\bld-pkgs\Packages", $Product, $Branch, $Version))
        if ($VerbosePreference) { $Verbose = "/V" }	
        
        foreach ($SourceItem in $Source)
        {
            $IsContainer = Test-Path -Path $SourceItem -PathType Container
            if($IsContainer)
            {
                robocopy.exe $SourceItem $Destination /S /R:6 /W:10 /FP /MT $Verbose
            } 
            else
            {
                $ItemAsFile = Get-Item $SourceItem
                $SourceFolder = $ItemAsFile.Directory.FullName
                $DestinationItem = $ItemAsFile.Name
            
                robocopy.exe $SourceFolder $Destination $DestinationItem /S /R:6 /W:10 /FP /MT $Verbose
            }
        }
        
        # https://ss64.com/nt/robocopy-exit.html
        if ($LASTEXITCODE -ge 8)
        {
            throw "Failures occurred while copying $Path to $Destination"
        }
    }

    END
    {
        Write-Verbose "Done saving build aftifacts."
    }
}