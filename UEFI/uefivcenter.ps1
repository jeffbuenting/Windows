# ----- Script to configure VM and boot it via WINPE to convert from Legacy BIOS to UEFI






$LogPath = '\\192.168.1.166\source'       #'\\10.137.8.9\UEFIConvertLogs'

$ISO = '[LocalHDD] ISO/Windows/WINPE_UEFI.iso'      #"[ISO] Utilitiy/WINPE_UEFI.iso"
$Key = (3,4,2,3,56,34,254,222,1,1,2,23,42,54,33,233,1,34,2,7,6,5,35,43)
$VCenter = '192.168.1.16'            #    'CDF2-VCA-01'

$TimeoutOS = 120
$TimeoutWINPE = 900


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

#$Cred = Get-Credential
#$VcenterCred = Get-Credential -Message "vCenter User"
#$ShareCred = Get-Credential -Message "User with access to shared drive for logs"
#$ServerAdmin = Get-Credential -Message "Server Admin"


    $VM = Get-VM -Name $VMName


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


#$ServerNames = Get-ADComputer -Filter * -Properties OperatingSystem | where OperatingSystem -like "Windows Server*" | Select-object Name,OperatingSystem | Sort-Object Name | Out-GridView -Title "Select machines to convert to UEFI" -PassThru | Select-Object -ExpandProperty Name
$ServerNames = 'kw-test'
 #'CDF2-Test-WS16'


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
  #  [PSCustomObject]@{Name = $VMName; LogPath = $LogPath; UserName = $ShareCred.UserName; PW = ($ShareCred.Password | ConvertFrom-SecureString -Key $Key )} | Export-csv -Path  J:\WINPEInput.csv -NoTypeInformation


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


    # ----- VM must be Powered off to change boot order
    Write-Log -Path "$LogPath\$($VMName).log"  -Message "Shutting down the VM" -Verbose:$IsVerbose

    Shutdown-VMGuest -VM $VM -Confirm:$False

    $VM = Get-VM -Name $VMName

    # ----- Wait for VM to be powered off.

    Write-Log -Path "$LogPath\$($VMName).log"  -Message "Waiting until the VM is in a PoweredOff State prior to changing boot order" -Verbose:$IsVerbose

    while ( $VM.PowerState -ne 'PoweredOff' ) {
        Start-Sleep -s 5
        Write-Output "Powerstate = $($VM.Powerstate)"
        $VM = Get-VM -Name $VMName
    }

    # ----- Configure VM to Boot from WINPEUIFIConvertion ISO

        Write-Log -Path "$LogPath\$($VMName).log"  -Message "Setting CDRom as only boot option" -Verbose:$IsVerbose

        # ----- Capture info needed to register vm
        $VMXPath = $VM.ExtensionData.Config.Files.VmPathName
        $Folder = $VM.Folder
        if ( $($VM.ResourcePool) ) {
            $ResourcePool = $VM.ResourcePool
        }
        Else {
            $ResourcePool = (Get-Cluster -VM $VM).Name
        }


        # ----- Set CDROM as first boot
        $spec = New-Object VMware.Vim.VirtualMachineConfigSpec

        $BootOptions = New-Object VMware.Vim.VirtualMachineBootOptions

        $BootableCDRom = New-Object -Type VMware.Vim.VirtualMachineBootOptionsBootableCdromDevice

        #$HDiskDeviceName = "Hard disk 1"
        #$HDiskDeviceKey = ($vm.ExtensionData.Config.Hardware.Device | ?{$_.DeviceInfo.Label -eq $HDiskDeviceName}).Key
        #$BootableHDisk = New-Object -TypeName VMware.Vim.VirtualMachineBootOptionsBootableDiskDevice -Property @{"DeviceKey" = $HDiskDeviceKey}

        $BootOrder = $BootableCDRom

        $BootOptions.BootOrder = $BootOrder

        $Spec.BootOptions = $BootOptions

        $VM.ExtensionData.reconfigvm( $Spec )

        # ----- Remove and Reregister so VMX changes happen
        Remove-Inventory -Item $VM -Confirm:$False

        # ----- Register VM (use clustername as the default resourcepool)
        $VM = New-VM -VMFilePath $VMXPath -Location $Folder -ResourcePool $ResourcePool


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

    Start-Sleep -Seconds $TimeoutOS

    # ----- Check if VMTools installed.
    Write-Log -Path "$LogPath\$($VMName).log"  -Message "Checking if VM Tools are installed." -Verbose:$IsVerbose

    $VM = Get-VM -Name $VMName

    if ( $VM.Guest.OSFullName -ne $Null ) {
        Write-Log -Path "$LogPath\$($VMName).log" -Warning -Message "OS is $($VM.Guest.OSFUllName).  VM did not boot into WINPE_UEFI ISO.`nSkipping." -Verbose:$IsVerbose
    }
    Else {
        Write-Log -Path "$LogPath\$($VMName).log" -Message "OS fullname is blank. Assuming VM has booted to UEFI Conversion ISO.`nContinuing UEFI Conversion." -Verbose:$IsVerbose

        $VM = Get-vm -name $VMName

        # ----- Wait for VM to boot in WINPE and then stop.
        if ( (Wait-VMState -VM $VM -TimeOutSeconds $TimeoutWINPE -PoweredOff) -eq 'TimeOut' ) { Continue }

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
}

Disconnect-VIServer -Confirm:$False


#
## ----- Remove the snapshot?
##Get-Snapshot -VM $VM -Name "Pre UEFI Conversion*" | Remove-Snapshot


$VerbosePreference = $OldVerbosePref