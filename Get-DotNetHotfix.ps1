function Get-DotNetHotfix {

<#
    .Synopsis
        Retrieves a list of .Net Hotfixes

    .Description
        Lists .Net Hotfixes that are installed on a computer.

    .Parameter ComputerName
        Name of the computer from which to retrieve a list of .Net Hotfixes.

    .Example
        List of all .Net hotfixes installed on ServerA

        Get-DotNetHotfix -ComputerName ServerA

    .Link
        https://msdn.microsoft.com/en-us/library/hh925567(v=vs.110).aspx?cs-save-lang=1&cs-lang=vb#code-snippet-1

    .Notes
        Author : Jeff Buenting
        Date : 2017 MAR 02


#>

    [CmdletBinding()]
    Param (
        [Parameter ( ValueFromPipeLine = $True ) ]
        [String[]]$ComputerName = $env:COMPUTERNAME
    )

    Process {
        Foreach ( $C in $ComputerName ) {
            Write-Verbose "Getting .Net Hotfixes for $C"
            $H = Invoke-Command -ComputerName $C -ScriptBlock {
                $NET = Get-ChildItem 'HKLM:\SOFTWARE\Wow6432Node\Microsoft\Updates' | where { $_.Name -Like '*.NET Framework*' -or $_.Name -like 'KB*' -or $_.Name -Like "*.NETFramework" } 
                foreach ($N in $NET ) {
                    Get-ChildITem "HKLM:\Software\Wow6432Node\Microsoft\Updates\$($N.PSChildName)"  | Foreach {
                        $Hotfix = New-Object -TypeName psobject -Property @{
                            ComputerName = $Using:C
                            Name = $N.PSChildName
                            HotfixID = $_.PSChildName
                        }
                        Write-Output $HOtfix
                    }
                }
            }
            Write-Output $H
        }
    }
}

$H = Get-DotNetHotfix  -verbose 4>&1