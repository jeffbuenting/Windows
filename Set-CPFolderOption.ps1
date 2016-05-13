Function Set-CPFolderOption {

<#
    .Synopsis
        Sets the Folder Options.

    .Descriptions
        Sets the Folder Options in the Control Panel.

        including one of the switches toggles the setting.  If it is already 0 then it flips it to 1.  If already 1 then it flips to 0.

    .Note
        Must close and reopen Folder options to see the results.  
        Results show up on registry immediately.
#>

 [CmdletBinding()]
    Param (
        [Parameter(ValueFromPipeline=$True)]
        [String[]]$ComputerName = "$($env:COMPUTERNAME).$($env:userdnsdomain)",

        [Switch]$ShowSuperHidden,

        [Switch]$HideEmptyDrives,

        [Switch]$hideFileExt
    )

    Process {
        Foreach ( $C in $ComputerName ) {
            Write-Verbose "Set-CPFolderOption : Setting folder options for computer: $ComputerName"
            
            if ( -Not (Test-Connection -ComputerName $C -Quiet) ) { 
                Write-Error "Set-CPFolderOption : Computer $Computername does not exits"
                Break
            } 
            
            $FolderOptions = Get-CPFolderOption 
            
            # ----- Show Hidden Files, folders and drives
            if ( $ShowSuperHidden ) {
                Write-Verbose "Set-CPFolderOption : Setting Show Hidden Files, Folders and Drives"
                invoke-command -ComputerName $C -ArgumentList ([int](-Not $FolderOptions.ShowSuperHidden)) -scriptblock {
                    Param (
                        [Int]$Value
                    )
                    Set-ItemProperty -path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name ShowSuperHidden -value $Value
                }
            }

            # ----- HideEmptyDrives
            if ( $HideEmptyDrives ) {
                Write-Verbose "Set-CPFolderOption : Setting Hide Empty Drives"
                invoke-command -ComputerName $C -ArgumentList ([int](-Not $FolderOptions.HideDrivesWithNoMedia)) -scriptblock {
                    Param (
                        [Int]$Value
                    )
                    Set-ItemProperty -path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name HideDrivesWithNoMedia -value $Value
                }
            }

            # ----- HideFileExt
            if ( $HideFileExt ) {
                Write-Verbose "Set-CPFolderOption : Setting Hide File Extensions"
                invoke-command -ComputerName $C -ArgumentList ([int](-Not $FolderOptions.HideFileExt)) -scriptblock {
                    Param (
                        [Int]$Value
                    )
                    Set-ItemProperty -path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name HideFileExt -value $Value
                }
            }

        }
    }
}

Set-CPFolderOption -HideEmptyDrives -Verbose