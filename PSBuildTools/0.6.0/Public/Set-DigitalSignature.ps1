<#
.SYNOPSIS
    Signs an array of files
.DESCRIPTION
    Signs a set of files using a trusted timestamp server
.PARAMETER Files
    Array of paths to files to sign.
.PARAMETER Certificate
    The certificate to use to sign the files. If one is not passed in, 
    a CodeSigningCert will be grabbed from cert:\CurrentUser\my
.EXAMPLE
    Get-ChildItem "C:\Example" -recurse | select -expand FullName | Set-DigitalSignature
.EXAMPLE
    $Cert = Get-ChildItem -Path cert:\LocalMachine\Trust\B2E92EA3B4FA88521C14A070C82DFA86911E7328
    Get-ChildItem "C:\Example" -recurse | select -expand FullName | Set-DigitalSignature -Certificate $Cert
#>

Function Set-DigitalSignature {
    [CmdletBinding()]
    param(
        [parameter(ValueFromPipeline=$true, Mandatory=$true)]
        [string[]] $File,

        [parameter()]
        [System.Security.Cryptography.X509Certificates.X509Certificate2] $Certificate,

        [parameter()]
        [string[]] $TimestampServer = @(#"http://tsa.kcura.corp/get.aspx",
                                        "http://timestamp.verisign.com/scripts/timstamp.dll",
                                        "http://timestamp.comodoca.com/authenticode",
                                        "http://tsa.starfieldtech.com")
    )

    BEGIN
    {
        if ($Certificate)
        {
            Write-Verbose "The following certificate was passed in:`n$Certificate"
        }
        else
        {
            $Certificate = (Get-ChildItem -Path cert:\CurrentUser\my -CodeSigningCert | Where-Object { $_.NotAfter -gt (Get-Date) })[0]
            Write-Verbose "Using the following certificate:`n$Certificate"
        }

        Write-Verbose "`nUsing the following timestamp servers to sign files:`n$TimestampServer `n"
        
        Function Get-IsSigned ([String]$FileToSign) {
            (Get-AuthenticodeSignature $FileToSign -Verbose:$VerbosePreference).Status -eq "Valid"
        }
    }

    PROCESS
    {
        foreach ($fileToSign in $File)
        {
            Write-Verbose "Checking file $File"
            $isSigned = Get-IsSigned $fileToSign
            Write-Verbose "File is signed? $isSigned"
            if (!$isSigned)
            {
                foreach ($Server in $TimestampServer)
                {
                    Write-Verbose "Signing with $Server"
                    Set-AuthenticodeSignature -FilePath $fileToSign -Certificate $Certificate -TimestampServer $Server -Verbose:$VerbosePreference
                    # This makes sure that the file was signed with a valid certificate.
                    # It is possible to have files signed with garbage certificates, in which case
                    # we'd want to check the exit code of Set-AuthenticodeSignature instead.
                    $isSigned = Get-IsSigned $fileToSign
                    if ($isSigned)
                    {
                        Write-Verbose "Signing was successful."
                        break
                    }
                }

                if (!$isSigned)
                {
                    Throw "Failed to sign $FileToSign"
                }
            }
        }
    }

    END
    {
        Write-Verbose "Finished signing files."
    }
}