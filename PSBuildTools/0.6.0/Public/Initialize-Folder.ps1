<#
.SYNOPSIS
    Initialize a folder.
.DESCRIPTION
    Initialize a folder. Optionally, do not delete any pre-existing contents.
.PARAMETER Path
    Path of the folder to initialize. By default, if this path already exists, any contents will be deleted.
.PARAMETER Safe
    If set, any pre-existing contents od the folder will be left on disk.
.EXAMPLE
    Initialize-Folder "C:\MyFolder"
.EXAMPLE
    "C:\MyFolder" | Initialize-Folder -Safe
#>
Function Initialize-Folder
{
    param(
        [Parameter(Mandatory=$true, Position=0)]
        [String] $Path,
        [Parameter()]
        [switch] $Safe
    )

    if ((Test-Path $Path) -and $Safe)
    {
        Return
    }

    if (Test-Path $Path)
    {
        Remove-Item -Recurse -Force $Path -ErrorAction Stop
    }

    $null = New-Item -Type Directory $Path -Force -ErrorAction Stop -Verbose:$VerbosePreference
}
