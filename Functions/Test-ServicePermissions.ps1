Function Test-ServicePermissions {

<#
    .SYNOPSIS
        Check services for insecure Service Permissions.

    .DESCRIPTION
        All Users / Regular users should not have access to the service folders.  See Tenable Plugin link for more info.
        https://www.tenable.com/plugins/nessus/65057

    .PARAMETER Service
        Service to check permissions.

    .EXAMPLE
        Get-CIMInstance -ClassName WIN32_Service | Test-ServicePermissions

    .NOTES
        Author : Jeff Buenting
        Date : 2022 DEC 19

#>

    [CmdletBinding()]
    param (
        [Parameter( Mandatory = $True,ValueFromPipeline = $True)]
        [PSObject]$Service
    )

    Process {
        Foreach ($S in $Service) {
            Write-Verbose "Checking Service $($S.Name)"
            
            Try {
                # Need to account for blank path ()
                if ( $S.PathName ) {

                    $ServicePath = $S.PathName

                    # remove parameters beginning with space-
                    $ServicePath = ($ServicePath -split " -")[0]
                    # slit off parameters beginning with /
                    $ServicePath = ($ServicePath -split " /")[0]
                    # remove parameters after just a "Space
                    $ServicePath = ($ServicePath -split '" ')[0]
                    # don't forget to remove quotes if they exist
                    $ServicePath = ($ServicePath).trim('"')

                    Write-Verbose "Service Path = $ServicePath"

                    Get-ACL $ServicePath -ErrorAction Stop | Select-object -ExpandProperty Access | foreach {
                        $ACL = $_

                        if ( $ACL.IdentityReference -in "Everyone","Users","Domain Users","Authenticated Users") {
                            Write-Verbose "Insecure Permissions = $($ACL.IdentityReference)"

                            Write-Output $S
                        }
                    }
                }
            }
            Catch {
                $ExceptionMessage = $_.Exception.Message
                $ExceptionType = $_.Exception.GetType().Fullname
                Throw "Test-ServicePermissions : Error retrieving permissions.`n`n     $ExceptionMessage`n`n $ExceptionType"  
            }
        }
    }
}