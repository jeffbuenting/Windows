# ----- Script to configure VM and boot it via WINPE to convert from Legacy BIOS to UEFI

# ----- setting verbose to display on screen
$ExistingVerbose = $VerbosePreference
$VerbosePreference = 'Continue'



$LogPath = '\\10.137.8.9\UEFIConvertLogs'
$ISO = "[ISO] Utilitiy/WINPE_UEFI_Mine.iso"
$Key = (3,4,2,3,56,34,254,222,1,1,2,23,42,54,33,233,1,34,2,7,6,5,35,43)
$VCenter = 'CDF2-VCA-01'
$ConfigOU = 'CN=Configuration,DC=CDF2,DC=usae,DC=bah,DC=com'

# ----- Timeout for booting into OS.
$TimeoutOS = 120

# ----- Timeout waiting for WINPE to shutdown
$TimeoutWINPE = 900

#$ServerNames = Get-ADComputer -Filter * -Properties OperatingSystem | where OperatingSystem -like "Windows Server*" | Select-object Name,OperatingSystem | Sort-Object Name | Out-GridView -Title "Select machines to convert to UEFI" -PassThru | Select-Object -ExpandProperty Name
$ServerNames = 'test-jeff'


# ------------------------------------------------------------------------------------

Function Wait-VMState {

    [CmdletBinding()]
    Param ( 
        [VMware.VimAutomation.ViCore.Impl.V1.VM.UniversalVirtualMachineImpl]$VM,

        [Switch]$PoweredOff,

        [Int]$TimeOutSeconds = 1800
    )
    
    $Timer =  [system.diagnostics.stopwatch]::StartNew()

    if ( $PoweredOff ) { $State = 'PoweredOff' }

    Write-Verbose "Waiting for VM status to be $State"

    while ( $VM.PowerState -ne $State ) {
        Start-Sleep -s 5
        Write-Verbose "$($Timer.Elapsed.TotalSeconds) : Powerstate = $($VM.Powerstate)"
        $VM = Get-VM -Name $VM.Name -Verbose:$False

        # ----- Because it is possible $TimeoutOS was not long enough and the VM actually booted into a reall OS we need to check and Fail out of loop if a real OS is detected
        if ( $Timer.Elapsed.TotalSeconds -gt $TimeOutSeconds ) { 
            Write-Output "TimeOut" 
            Return
        }
    }

    Write-Output 'True'
}


# ------------------------------------------------------------------------------------


# ----- Dot source write-log
. $PSScriptRoot\write-log.ps1
#. C:\Scripts\Windows\UEFI\Write-Log.ps1

# ----- Turn on Verbose.
$OldVerbosePref = $VerbosePreference
$VerbosePreference = 'Continue'

# ----- Set IsVerbose
if ( $VerbosePreference -eq 'Continue' ) {
    $IsVerbose = $True
}
Else {
    $IsVerbose = $False
}

$Cred = Get-Credential
$VcenterCred = $Cred # Get-Credential -Message "vCenter User"
$ShareCred = $Cred # Get-Credential -Message "User with access to shared drive for logs"
$ServerAdmin = Get-Credential -Message "Server Admin"

Try {
    # ----- Because we don't know if the VCSA is using self signed certs or not.
    Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$False -ErrorAction Stop

    Connect-VIServer $vCenter -Credential $vcenterCred -ErrorAction Stop
}
Catch {
    $ExceptionMessage = $_.Exception.Message
    $ExceptionType = $_.Exception.GetType().Fullname
    Throw  "Error connecting to vCenter.`n`n     $ExceptionMessage`n`n $ExceptionType"
}

# ----- Find the DHCPServer
$DHCPServer = Get-ADObject -SearchBase $ConfigOU -Filter "objectclass -eq 'dhcpclass' -AND Name -ne 'dhcproot'" | select -expandproperty name

foreach ($VMName in $ServerNames ) {
    Write-Log -Path "$LogPath\$($VMName).log" -Message "Converting $VMName ------------------------------------" -Verbose:$IsVerbose 

    $VM = Get-VM -Name $VMName

    # ----- Create a snapshot just in case ( grabbing mem also so if we revert this should be a running VM )
    Try {
        Write-Log -Path "$LogPath\$($VMName).log" -Message "Creating Snapshot" -Verbose:$IsVerbose
        New-Snapshot -VM $VM -Name "Pre UEFI Conversion - $(Get-Date -Format MM-dd-yyyy:HHmm)" -Memory -ErrorAction Stop | Write-Log -Path "$LogPath\$($VMName).log" -Verbose:$IsVerbose
    }
    Catch {
        $ExceptionMessage = $_.Exception.Message
        $ExceptionType = $_.Exception.GetType().Fullname
        Write-Log -Path "$LogPath\$($VMName).log" -Throw -Message "There was an Eror creating a snapshot.`n`n     $ExceptionMessage`n`n $ExceptionType"  -Verbose:$IsVerbose 
    }

    # ----- Because we can't pass parameters directly to WINPE we will write a file to the VM's C: drive with data needed for the convertion script in that environment
    # ----- Get only IPv4 address.  If there is more than one then we will need to find a way to pick the correct one.
    $VMIP = $VM.Guest.IPAddress | Select-String -pattern ':' -NotMatch


    Try { 
        Write-Log -Path "$LogPath\$($VMName).log" -Message "Mapping J to VM c$" -Verbose:$IsVerbose
        New-PSDrive -Name "J" -Root \\$VMIP\c$ -PSProvider FileSystem -Credential $ServerAdmin -ErrorAction Stop | Write-Log -Path "$LogPath\$($VMName).log" -Verbose:$IsVerbose
    }
    Catch {
        $ExceptionMessage = $_.Exception.Message
        $ExceptionType = $_.Exception.GetType().Fullname
    
        Write-Log -Path "$LogPath\$($VMName).log" -Throw -Message "Failed to map to the admin share \\$VMIP\c$ on $VMName.`n`n     $ExceptionMessage`n`n $ExceptionType" -Verbose:$IsVerbose

    }

     Write-Log -Path "$LogPath\$($VMName).log" -Message "Copy WINPE Script config to J:" -Verbose:$IsVerbose
    [PSCustomObject]@{Name = $VMName; LogPath = $LogPath; UserName = $ShareCred.UserName; PW = ($ShareCred.Password | ConvertFrom-SecureString -Key $Key )} | Export-csv -Path  J:\WINPEInput.csv -NoTypeInformation


    # ----- Remove the J drive now that we no longer need it
    Remove-PSDrive -Name 'J'

    Try {   
        Write-Log -Path "$LogPath\$($VMName).log" -Message "Mounting WINPE" -Verbose:$IsVerbose

        Get-CDDrive -vm $VM -ErrorAction Stop | Set-CDDrive -IsoPath $ISO -StartConnected:$True -Connected:$True -Confirm:$False -ErrorAction Stop | Write-Log -Path "$LogPath\$($VMName).log" -Verbose:$IsVerbose
    }
    Catch {
        $ExceptionMessage = $_.Exception.Message
        $ExceptionType = $_.Exception.GetType().Fullname
        Write-Log -Path "$LogPath\$($VMName).log" -Throw -Message "Problem mounting WINPE ISO.`n`n     $ExceptionMessage`n`n $ExceptionType" -Verbose:$IsVerbose
    }



    # ----- Restart and boot to ISO
    Write-Log -Path "$LogPath\$($VMName).log"  -Message "Restarting VM." -Verbose:$IsVerbose

    # ----- Restarting VM OS.  I can't figure out how to monitor when a reboot is complete (without vmtools) so I separated this into two operations
    Shutdown-VMGuest -VM $VM -Confirm:$False 

    $VM = Get-vm -name $VMName

    # ----- Wait for VM to powerdown and...
    Write-Log -Path "$LogPath\$($VMName).log"  -Message "Waiting until the VM is in a PoweredOff State" -Verbose:$IsVerbose
    $Result = Wait-VMState -VM $VM -PoweredOff -Verbose:$IsVerbose

    Start-Sleep -s 30

    Write-Log -Path "$LogPath\$($VMName).log"  -Message "Starting VM." -Verbose:$IsVerbose
    
    # ----- So the question is how do you know when a VM booting into WINPE has finished booting.  No vm tools installed, no psremoting.  Only thing I can think of at this point,
    # ----- is to wait a specific amount of time and then check the VM object for an OS.  If no OS listed then it has not booted to WINPE.  
    
    Start-VM -VM $VM

    Write-Log -Path "$LogPath\$($VMName).log"  -Message "Waiting for VM to poweron" -Verbose:$IsVerbose

    # ----- Wait for VM to finish booting
#    Start-Sleep -Seconds $TimeoutOS
    
    # ----- Get VM's MAC
    Write-Log -Path "$LogPath\$($VMName).log"  -Message "Getting VM's MAC address." -Verbose:$IsVerbose
    
    $MAC = $VM | Get-NetworkAdapter | Select-Object -ExpandProperty MACAddress

    # ----- Loop until VM is pingable
    $PingWINPE = $False
    $PingOS = $False
    Try {
        Do {
            # ----- Checking to see if DHCP has assigned IP to VM's mac
            Write-Log -Path "$LogPath\$($VMName).log"  -Message "Checking DHCP for IP mapped to MAC: $MAC" -Verbose:$IsVerbose

            $IPAddress = ( Get-DhcpServerv4Scope -ComputerName $DHCPServer -ErrorAction Stop | foreach {Get-DhcpServerv4Lease -computername $DHCPServer -allleases -ScopeId ($_.ScopeId) -ErrorAction Stop  } | where clientid -match $MAC.Replace(':','-') ).IPAddress.IPAddressToString

            Write-Log -Path "$LogPath\$($VMName).log"  -Message "IPAddress = $IPAddress" -Verbose:$IsVerbose
        
            $PingWINPE = Test-Connection -ComputerName $IPAddress -Count 1 -Quiet -ErrorAction SilentlyContinue
            $PingOS = Test-Connection -ComputerName $VMIP -Count 1 -Quiet -ErrorAction SilentlyContinue


        } Until ( $PingWINPE -Or $PingOS ) 
    }
    Catch {
        $ExceptionMessage = $_.Exception.Message
        $ExceptionType = $_.Exception.GetType().Fullname
        Write-Log -Path "$LogPath\$($VMName).log" -Throw -Message "Error getting the DHCP info.  Possibly need to run as Admin.`n`n     $ExceptionMessage`n`n $ExceptionType" -Verbose:$IsVerbose
    }



    # ----- Check if regular OS installed.
    Write-Log -Path "$LogPath\$($VMName).log"  -Message "Checking if regular OS is installed." -Verbose:$IsVerbose

    $VM = Get-VM -Name $VMName

    if ( $VM.Guest.OSFullName -ne $Null ) {
 #   if ( $PingOS ) {
        Write-Log -Path "$LogPath\$($VMName).log" -Warning -Message "OS is $($VM.Guest.OSFUllName).  VM did not boot into WINPE_UEFI ISO.`nSkipping." -Verbose:$IsVerbose
 #       Write-Log -Path "$LogPath\$($VMName).log" -Warning -Message "Pinged OS IP.  VM did not boot into WINPE_UEFI ISO.`nSkipping." -Verbose:$IsVerbose
    }
    Else {
        Write-Log -Path "$LogPath\$($VMName).log" -Message "OS fullname is blank. Assuming VM has booted to UEFI Conversion ISO.`nContinuing UEFI Conversion." -Verbose:$IsVerbose
 #       Write-Log -Path "$LogPath\$($VMName).log" -Message "Pinged DHCP IP. Assuming VM has booted to UEFI Conversion ISO.`nContinuing UEFI Conversion." -Verbose:$IsVerbose

        $VM = Get-vm -name $VMName

        # ----- Wait for VM to boot in WINPE and then stop.
        if ( (Wait-VMState -VM $VM -TimeOutSeconds $TimeoutWINPE -PoweredOff) -eq 'TimeOut' ) { 
            Write-Log -Path "$LogPath\$($VMName).log" -Message "There was a problem with the WINPE boot or the Convertion Script.  Check the log." -Verbose:$IsVerbose
            Continue 
        }

        # ----- Check log file for success
        if ( -Not ( Get-Content -Path "$LogPath\$($VMName).log" | Select-String "Success : Conversion Complete" ) ) {
            Write-Log -Path "$LogPath\$($VMName).log" -Throw  -Message "MBR2GPT on $VMName did not complete successfully.  Restore the Snapshot" -Verbose:$IsVerbose
        }

        # ----- Set BIOS mode to UEFI
        Write-Log -Path "$LogPath\$($VMName).log"  -Message "Setting VM Options to EFI" -Verbose:$IsVerbose

        $spec = New-Object VMware.Vim.VirtualMachineConfigSpec
        $spec.Firmware = [VMware.Vim.GuestOsDescriptorFirmwareType]::efi
        $vm.ExtensionData.ReconfigVM($spec)
    }

    # ----- Cleanup
    Write-Log -Path "$LogPath\$($VMName).log"  -Message "Cleanup" -Verbose:$IsVerbose
    
    Write-Log -Path "$LogPath\$($VMName).log"  -Message "Removing ISO from VM." -Verbose:$IsVerbose

    # ----- Running into connection closed errors when piping.  so split this into two lines.
    $CD = Get-CDDrive -VM $VM 
    Set-CDDrive -CD $CD -NoMedia -Confirm:$False

    Start-VM -VM $VM

    # ----- Remove config file from VM
#    Write-Log -Path "$LogPath\$($VMName).log" -Message "Mapping J to VM c$ so we can remove the config file" -Verbose:$IsVerbose
#    Try { 
#        Write-Log -Path "$LogPath\$($VMName).log" -Message "Mapping J to VM c$" -Verbose:$IsVerbose
#        New-PSDrive -Name "J" -Root \\$VMIP\c$ -PSProvider FileSystem -Credential $ServerAdmin -ErrorAction Stop | Write-Log -Path "$LogPath\$($VMName).log" -Verbose:$IsVerbose
#    }
#    Catch {
#        $ExceptionMessage = $_.Exception.Message
#        $ExceptionType = $_.Exception.GetType().Fullname
#    
#        Write-Log -Path "$LogPath\$($VMName).log" -Throw -Message "Failed to map to the admin share \\$VMIP\c$ on $VMName.`n`n     $ExceptionMessage`n`n $ExceptionType" -Verbose:$IsVerbose
#
#    }
#
#    Write-Log -Path "$LogPath\$($VMName).log" -Message "removing J:\WINPEInput.csv" -Verbose:$IsVerbose
#    Remove-Item J:\WINPEInput.csv -Force
#
#    # ----- Remove the J drive now that we no longer need it
#    Remove-PSDrive -Name 'J'
}

Disconnect-VIServer -Confirm:$False

#
## ----- Remove the snapshot?
##Get-Snapshot -VM $VM -Name "Pre UEFI Conversion*" | Remove-Snapshot


$VerbosePreference = $OldVerbosePref