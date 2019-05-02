<#
.SYNOPSIS
    Retrieves date based version and applies to assembly info
.DESCRIPTION
    Retrieves major and minor version from local text file, increments and retrieves version from SQL database, and updates assembly metadata with new version
.PARAMETER ProductName
    Name of the product being versioned
.PARAMETER ServerInstance
    Address to SQL server to retrive version from
.PARAMETER Database
    Name of the database that stores the version information
.EXAMPLE
    Set-LegacyDateBasedBuildVersion -ProductName 'Relativity'
.OUTPUT
    It outputs the version applied as a string
#>


Function Set-LegacyDateBasedBuildVersion {
    [CmdletBinding()]
    param(
        [parameter(Mandatory=$true)] 
        [string] $ProductName,

        [parameter()] 
        [string] $ServerInstance = "BLD-MSTR-01.kcura.corp",

        [parameter()] 
        [string] $Database = "BuildVersion"
    )

    $versionObject = (Get-VersionFromFile)

    $Major = $versionObject.Major
    $Minor = $versionObject.Minor

    Write-Verbose "Using major version: $Major`n Using minor version: $Minor`n"

    $version = Get-IncrementedVersionFromSQLServer -MajorVersion $Major -MinorVersion $Minor -ProductName $ProductName -ServerInstance $ServerInstance -Database $Database
    $assemblyVersion = $version.AssemblyVersion

    Write-Verbose "Version retrieved from server: $assemblyVersion`n"

    Set-VersionsInAssemblyInfo -Version $assemblyVersion

    return $assemblyVersion
}

Function Get-VersionFromFile {
    $root = (git rev-parse --show-toplevel).Replace("/", "\")
    $versionFile = [System.IO.Path]::Combine($root, 'Version\version.txt')

    Write-Verbose "Retrieving version from file: $versionFile`n"

    $file_content = Get-Content $versionFile

    $version_object = [Version]$file_content

    return $version_object
}

Function Get-IncrementedVersionFromSQLServer {
    param(
        [Parameter(Mandatory=$true)]
        [string] $MajorVersion,

        [Parameter(Mandatory=$true)]
        [string] $MinorVersion,

        [Parameter(Mandatory=$true)]
        [string] $ProductName,

        [Parameter(Mandatory=$true)]
        [string] $ServerInstance,

        [Parameter(Mandatory=$true)]
        [string] $Database
    )

    $query = @"
        DECLARE @AssemblyVersion varchar(50), @InstallerVersion varchar(50)
           EXEC getAndIncrementVersionNumbers @ProductName = '{0}', @Major = {1}, @Minor = {2}, @AssemblyVersion = @AssemblyVersion OUTPUT, @InstallerVersion = @InstallerVersion OUTPUT
        SELECT @AssemblyVersion as 'AssemblyVersion', @InstallerVersion as 'InstallerVersion' 
"@	-f $ProductName, $Major, $Minor

    $connectionString = ('Server={0};Database={1};User=Version;Password=Test1234!') -f $ServerInstance,$Database

    Write-Verbose "Querying server using connection string: $connectionString`n"

    $version = Read-Query -ConnectionString $connectionString -Query $query -Action {return $args}

    return $version
}

Function Set-VersionsInAssemblyInfo {
    param(
        [Parameter(Mandatory=$true)]
        [string] $Version
    )

    $root = (git rev-parse --show-toplevel).Replace("/", "\")
    $VersionDirectory = [System.IO.Path]::Combine($root, 'Version')

    $NewVersion = 'AssemblyVersionAttribute("' + $version + '")'
    $NewFileVersion = 'AssemblyFileVersionAttribute("' + $version + '")'
    $NewInfoVersion = 'AssemblyInformationalVersionAttribute("' + $version + '")'

    foreach($o in Get-ChildItem $VersionDirectory){

       if($o.BaseName -ne 'AssemblyInfo') {continue}
       
       Write-Host "Updating" $o.FullName "to version" $version "..."
       
       $tmp = Get-Content $o.FullName | 
       %{$_ -replace 'AssemblyVersionAttribute\(".*"\)', $NewVersion} |
       %{$_ -replace 'AssemblyFileVersionAttribute\(".*"\)', $NewFileVersion} |
       %{$_ -replace 'AssemblyInformationalVersionAttribute\(".*"\)', $NewInfoVersion}

       [System.IO.File]::WriteAllLines($o.FullName, $tmp)
    }   
}

#Read-Query function taken from http://www.22bugs.co/post/simple-alternative-to-invoke-sqlcmd/
Function Read-Query {
    param (
        [Parameter(Mandatory=$true)]
        [string] $ConnectionString,

        [Parameter(Mandatory=$true)]
        [string] $Query,

        [Parameter(Mandatory=$true)]
        [scriptblock] $Action
    )

    $SqlConnection = New-Object System.Data.SqlClient.SqlConnection
    $SqlConnection.ConnectionString = $ConnectionString
    $SqlConnection.Open()

    try {
        $SqlCmd = New-Object System.Data.SqlClient.SqlCommand
        $SqlCmd.CommandText = $Query
        $SqlCmd.Connection = $SqlConnection
        $reader = $SqlCmd.ExecuteReader()

        while ($reader.Read())
        {
            $x = $null
            $x = @{}

            for ($i = 0; $i -lt $reader.FieldCount; ++$i)
            {
                $x.add($reader.GetName($i), $reader[$i])
            }

            Invoke-Command -ScriptBlock $action -ArgumentList $x
        }
    } finally {
        $SqlConnection.Close()
    }
}