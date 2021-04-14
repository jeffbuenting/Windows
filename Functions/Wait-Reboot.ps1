Function Wait-ForReboot {

<#
    .Synopsis
        Waits until a remote computer has rebooted before continuing the script.

    .Description
        Using pings, check for the system to be offline and then online again.   And then waits once the ping comes back to let the services complete startup.

        This script was necessary when a system reboots outside of a Restart-Computer cmdlet.  if using the Restart-Computer cmdlet to reboot then you can use the -Wait parameter.

    .Parameter ComputerName
        Name of the remote computer that is rebooting.

    .Parameter Timeout
        Timeout period (in Seconds) if the computer never looses connectivity or never comes back. 

    .Parameter Delay
        Time in seconds to wait after the first successful ping for the services to start.

    .Example
        Wait-ForReboot -ComputerName ServerA 

    .Notes
        Author : Jeff Buenting
        Date : 2016 MAY 18

#>

    [CmdletBinding()]
    Param (
        [Parameter (Mandatory = $True)]
        [String]$ComputerName,

        [Int]$Timeout = 300,

        [Int]$Delay = 300
    )

    # ----- Wait for Server to stop answering pings
    Write-Verbose "Waiting for Ping to stop responding during reboot of $ComputerName"
    $StartTime = Get-Date
    $PingStop = $False
    While ( (Get-Date) -le $StartTime.AddSeconds( $TimeOut ) ) {
        if ( -Not ( Test-Connection -ComputerName $CRMServer -Quiet -Count 1 ) ) { $PingStop = $True; break }
    }

    if ( -Not $PingStop ) { 
        Write-Verbose " $((Get-Date) - $StartTime | Out-String)"
        Throw "Wait-ForReboot : Timeout waiting for pings to stop responding during reboot of $ComputerName" 
    }

    # ----- Wait for Server to Start answering pings
    Write-Verbose "Waiting for Ping to start responding during reboot of $ComputerName"
    $StartTime = Get-Date
    $PingStart = $False
    While ( (Get-Date) -le $StartTime.AddSeconds( $TimeOut ) ) {
        if ( ( Test-Connection -ComputerName $CRMServer -Quiet ) ) { $PingStart = $True; break }
    }

    if ( -Not $PingStart ) { 
        Write-Output " $((Get-Date) - $StartTime | Out-String)"
        Throw "Install-CRM2016 : Timeout waiting for pings to Start responding during reboot" 
    }

    # ----- Wait 5 minutes after ping response to make sure all services are started before continuing
    Write-Verbose "Waiting 5 minutes after ping responds to allow the services to start"
    Start-Sleep -Seconds $Delay

    Write-Verbose "$ComputerName has finished rebooting"
}


   
    $CRMServer = "jeffb-crm01.stratuslivedemo.com"

Restart-Computer -ComputerName $CRMServer -Force