function Save-ModuleIfNotExists
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true,ValueFromPipeline=$true)]
        [ValidateNotNull()]
        [PSCustomObject[]]
        $PSObject,

        [Parameter(Mandatory=$true)]
        [string]
        $Path
    )

    process
    {
        foreach ($module in $PSObject)
        {
            $name = $module.Name
            $desiredVersion = $module.Version
            $item = Get-ChildItem -Path $Path -File -Recurse -Include "$($name).psd1" | Where-Object { $_.Directory -match "$($name)" -and $_.Directory -match "$($desiredVersion)" }

            if ($item -eq $null)
            {
                Write-Verbose "Module '$name' - '$desiredVersion' not found -- downloading"
                Save-Module -InputObject $module -Path $Path
            }
            else
            {
                Write-Verbose "Module '$name' already downloaded: '$item'"
                $existingVersion = [System.IO.Path]::GetFileName($item.Directory)
                if ($existingVersion -ne $desiredVersion)
                {
                    Write-Warning "Warning - version '$existingVersion' of module '$name' already downloaded; was looking for version '$desiredVersion'"
                }
            }
        }
    }
}
