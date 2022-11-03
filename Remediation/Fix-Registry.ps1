# $ServerList = "KCDCUTIL01"

# foreach ( $S in $ServerList ) {
#     Write-Verbose "Updating Server: $S"

    $RegPath = "HKLM:\SOFTWARE\Microsoft\Cryptography\Wintrust\Config"
    $RegKey = "EnableCertPaddingCheck"

    if ( ( Get-ItemProperty -Path $RegPath -Name $RegKey -ErrorAction SilentlyContinue ).EnableCertPaddingCheck -ne 1 ) {

        if ( -Not ( Test-Path -Path $RegPath ) ) {
            Write-Verbose "Regkey does not exist.  Creating."

            New-Item -Path $RegPath -Force | New-ItemProperty -Name $RegKey -Value 1 
        }
        else {
            Set-ItemProperty --Path $RegPath -Name $RegKey -Value 1
        }
    }

    $RegPath = "HKLM:\Software\Wow6432Node\Microsoft\Cryptography\Wintrust\Config"
    $RegKey = "EnableCertPaddingCheck"

    if ( ( Get-ItemProperty -Path $RegPath -Name $RegKey -ErrorAction SilentlyContinue ).EnableCertPaddingCheck -ne 1 ) {

        if ( -Not ( Test-Path -Path $RegPath ) ) {
            Write-Verbose "Regkey does not exist.  Creating."

            New-Item -Path $RegPath -Force | New-ItemProperty -Name $RegKey -Value 1 
        }
        else {
            Set-ItemProperty --Path $RegPath -Name $RegKey -Value 1
        }
    }
# }