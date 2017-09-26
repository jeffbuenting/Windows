Function Get-Uptime {

<#
    .Synopsis
        Gets a computer's uptime information.

    .Description
        Gets a computers uptime information including:
            Uptime in Days
            Starttime
            Status
            if it may need to be patched

    .Parameter ComputerName
        Name of the computer from which to get the uptime.

    .Example
        Get-Uptime -ComputerName ServerA

    .Link
        http://powershell.org/wp/2016/01/02/january-2016-scripting-games-puzzle/

    .Notes
        Author: Jeff Buenting

#>

    [CmdletBinding()]
    param (
        [Parameter(ValuefromPipeline=$True)]
        [String[]]$ComputerName = $env:COMPUTERNAME
    )

    Process {
        foreach ( $C in $ComputerName ) {
            Write-Verbose "Checking uptime for $C"

            $Uptime = New-Object -TypeName psobject -Property @{
                ComputerName = $C
                StartTime = $Null
                'Uptime (Days)' = $Null
                Status = 'OK'
                MightNeedPatched = $Null
            }


            if ( Test-Connection -ComputerName $C -Quiet ) {
                    # ----- Computer is reachable
                    $OS = Get-CimInstance -ComputerName $C -ClassName Win32_OperatingSystem
                    Try {
                            $U = $OS.LocalDateTime – $OS.LastBootUpTime
                            
                            # ----- Check if $U has a value.  If not then cannot find uptime
                            if ( $U -eq $Null ) {
                                    Write-Verbose "Cannot Find Uptime"
                                    $Uptime.Status = 'ERROR'
                                }
                                Else {
                                    $Uptime.StartTime = $OS.LastBootUpTime
                                    $Uptime.'Uptime (Days)' = "{0:N1}" -f $U.TotalDays
                                    $Uptime.MightNeedPatched = ( [Int]$Uptime.'Uptime (Days)' -gt 30 )

                            }
                        }
                        Catch {
                            # ----- Any error generated from the uptime calculation will end up here
                            Write-Verbose "Cannot Find Uptime"
                            $Uptime.Status = 'ERROR'
                    }
                    
                }
                Else {
                    Write-Warning "$C is OFFLINE"
                    $Uptime.Status = 'OFFLINE'
            }
            Write-Output $Uptime
        }
    }
}

 # 'sl-jeffb','jeffb-crm03','unknonwn','jeffb-crm01' | Get-uptime | FT

 #'sl-jeffb','jeffb-crm03','unknonwn','jeffb-crm01'