Function Get-LoggedOnUser {

<#
    .Synopsis
        Retrieves a list of users with logged in sessions

    .Description
        Uses Query Session to retrieve users who currently have a session logged onto a computer.  Returns only the sessiosn with a user name.

    .Parameter ComputerName
        Name of the computer from which to retrieve Sessions

    .Parameter Exclude
        Retrieves all user log on sessions except these.

    .Parameter Include
        Retrieve only these Sessions

    .Example
        Retrieves all logged on User Sessions from a computer

        Get-LoggedOnUser -ComuterName $Server

    .Example
        Gets a list of logged on Users sessions excluding the administrator 

        Get-LoggedOnUser -ComputerName $Server -Exclude Administrator

    .Example
        Returns a list of Logged on User Sessions from a list of user names.

        $Servers | Get-LoggedOnUser -UserName Administrator,Bob.Smith

    .Link
        https://www.petri.com/powershell-problem-solver-text-objects-regex

        This link shows how to turn text data into an object.  Note  &lt; and &gt; should be < > respectively

    .Note
        Author : Jeff Buenting
        Date : 2016 JUN 23
#>

    [CmdletBinding(DefaultParameterSetName="default")]
    Param (
        [Parameter ( ValueFromPipeline = $True, ValueFromPipelinebyPropertyName = $True )]
        [String[]]$ComputerName = $env:COMPUTERNAME,

        [Parameter (ParameterSetName = 'Exclude' )]
        [String[]]$Exclude,

        [Parameter (ParameterSetName = 'UserName' )]
        [String[]]$UserName
    )

    Begin {
        [regex]$Pattern = "^?\s(?<SessionName>\s+|\S+)?\s+(?<UserName>(?:[a-z,A-Z,\.]+)|\s+)?\s+(?<ID>\w+|\d+)?\s+(?<State>\w+)"

        $names = $pattern.GetGroupNames() | select -skip 1
    }

    Process {
        Foreach ( $C in $ComputerName ) {
            Write-Verbose "Getting User Log on Sessions on $C"

            $Users = query session /server:$c | Select-String -Pattern $Pattern
                
            $UserSessions = $Users.Matches | Select-Object -Skip 1 | foreach {
                $hash=[ordered]@{}
                foreach ($name in $names) {
                    $hash.add($name,$_.groups[$name].value)
                }
                $hash.add('ComputerName',$C)
                [pscustomobject]$hash
            }


            Switch ( $PSCmdlet.ParameterSetName ) {
                'Exclude' {
                    Write-Verbose "Excluding $Exclude"
                    Write-Output ( $UserSessions | where { $_.UserName -And $_.UserName.tolower() -notin $Exclude.tolower() } )
                    break
                }

                'UserName' {
                    Write-Verbose "Filtered on User: $UserName"
                    Write-Output ( $UserSessions | where { $_.UserName -And $_.UserName.ToLower() -in $Username.ToLower() } )
                    break
                }
                
                default {
                    Write-verbose "Output"
                    Write-Output ( $UserSessions | where UserName )
                }
            }
        }
    }
}

Get-LoggedOnUser -ComputerName jeffb-crm03.stratuslivedemo.com   -Verbose | foreach {
    $_
    Logoff /Server:$($_.ComputerName) $_.ID
}