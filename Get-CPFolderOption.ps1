Function Get-CPFolderOption {

<#
    .Synopsis
        Retrieves the Control Panel Folder Options

    .Description
        Retrieves the Folder Options from the control panel.  Options such as Hide Known file Extensions.

    .Parameter ComputerName
        Name of the computer to retrieve the info from. 

    .Example
        Gets the folder options from the local computer
        
        Get-CPFolderOption 

    .Link
        http://stackoverflow.com/questions/4491999/configure-windows-explorer-folder-options-through-powershell

    .Note
        I found the solution at the included link to set the options.  I added the function wrapper and a Get function to check for the settings

    .Note
        Author : Jeff Buenting
        Date : 2016 APR 01
#>

    [CmdletBinding()]
    Param (
        [Parameter(ValueFromPipeline=$True)]
        [String[]]$ComputerName = "$($env:COMPUTERNAME).$($env:userdnsdomain)"
    )

    Process {
        foreach ( $C in $ComputerName ) {
            Write-Verbose "Get-CPFolderOption : Getting folder options for computer: $ComputerName"

            if ( -Not (Test-Connection -ComputerName $C -Quiet) ) { 
                Write-Error "Get-CPFolderOption : Computer $Computername does not exits"
                Break
            }
            
            $FolderOptions = Invoke-Command -ComputerName $C -scriptblock {
                Write-Output (Get-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced')
            }

            # ----- Add computername to the object
            $FolderOptions | Add-Member -MemberType NoteProperty -Name Computer -Value $C

            Write-output $FolderOptions
        }
    }    
}

Get-CPFolderOption -verbose