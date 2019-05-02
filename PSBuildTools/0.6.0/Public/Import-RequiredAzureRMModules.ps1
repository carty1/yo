function Import-RequiredAzureRmModules {
    <#
    .SYNOPSIS
        Imports a specific version of the AzureRm module and its required dependencies.

    .DESCRIPTION
        This script optionally deletes and re-creates the install directory. Then it downloads and imports the required modules and their dependencies.

    .PARAMETER InstallDirectory
        The directory to load and save modules to.

    .PARAMETER RequiredAzureRmVersion
        The AzureRm module version to use.

    .PARAMETER RequiredAzureRmModules
        The AzureRm module's dependencies that are required.

    .PARAMETER KeepDirectory
        If present, does not delete the InstallDirectory before downloading modules.

    .EXAMPLE
        Import-RequiredAzureRmModules -InstallDirectory './modules' -RequiredAzureRmVersion '6.2.1' -RequiredAzureRmModules @('AzureRM.KeyVault') -KeepDirectory
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $InstallDirectory,
        
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $RequiredAzureRmVersion,

        [Parameter(Mandatory=$true)]
        [ValidateCount(1, [int]::MaxValue)]
        [ValidateLength(1, [int]::MaxValue)]
        [string[]]
        $RequiredAzureRmModules,

        [Parameter(Mandatory=$false)]
        [switch]
        $KeepDirectory
    )


    $installDirectoryExists = Test-Path -PathType Container -Path $InstallDirectory
    if ($installDirectoryExists)
    {
        if (!$KeepDirectory)
        {
            # Wipe the directory and import the modules again
            Write-Verbose "Deleting & recreating directory '$InstallDirectory'"
            Remove-Item -Recurse -Force $InstallDirectory
            New-Item -ItemType Directory -Force -Path $InstallDirectory
        }
    }
    else
    {
        New-Item -ItemType Directory -Force -Path $InstallDirectory
    }


    Write-Verbose "Downloading modules"
    $requiredModules = Find-Module -Name AzureRM -RequiredVersion $RequiredAzureRmVersion -IncludeDependencies | Where-Object { $_.Name -in $RequiredAzureRmModules }
    $requiredModulesAndDependencies = foreach ($module in $requiredModules)
    {
        Find-Module -IncludeDependencies -Name $module.Name -RequiredVersion $module.Version
    }
    if ($requiredModulesAndDependencies.Count -eq 0)
    {
        throw "Nothing to import with AzureRm version $RequiredAzureRmVersion and required modules $RequiredAzureRmModules"
    }
    $requiredModulesAndDependencies | Save-ModuleIfNotExists -Path $InstallDirectory


    Write-Verbose "Importing modules"
    # Reverse requiredModulesAndDependencies so dependencies will be imported before the modules that require them
    [array]::Reverse($requiredModulesAndDependencies)
    $importOutput = &{
        foreach ($module in $requiredModulesAndDependencies)
        {
            $psd1Path = Join-Path $InstallDirectory -ChildPath $module.Name | Join-Path -ChildPath $module.Version | Join-Path -ChildPath "$($module.Name).psd1"
            Get-ChildItem -Path $psd1Path | Import-Module -Scope 'Global'
        }
    } 2>&1 # Save error & standard output streams to show later if not all modules have been imported successfully


    Write-Verbose "Verifying required modules are present and accounted for"
    $missingModules = @()
    $modulesWithNoCommands = @()
    foreach ($module in $requiredModules)
    {
        $importedModule = Get-Module -Name $module.Name | Where-Object { $_.Version -eq $module.Version }
        if ($importedModule -eq $null)
        {
            $missingModules += $module
        }
        if ($importedModule.ExportedCommands.Count -eq 0)
        {
            $modulesWithNoCommands += $importedModule
        }
    }

    $errorMessage = ''
    if ($missingModules.Count -gt 0)
    {
        $errorMessage += "The following required modules are missing:`n"
        $errorMessage += $missingModules | Format-Table | Out-String 
    }
    if ($modulesWithNoCommands.Count -gt 0)
    {
        $errorMessage += "The following required modules have zero exported commands:`n"
        $errorMessage += $modulesWithNoCommands | Format-Table | Out-String
    }
    if ($errorMessage.Length -gt 0)
    {
        $errorMessage += "Output from importing modules:`n$importOutput"
        Write-Error $errorMessage
    }
}
