# ----- Script to configure VM and boot it via WINPE to convert from Legacy BIOS to UEFI





$LogPath = '\\192.168.1.166\source'       #'\\10.137.8.9\UEFIConvertLogs'
$ISO = '[LocalHDD] ISO/Windows/WINPE_UEFI.iso'      #"[ISO] Utilitiy/WINPE_UEFI.iso"
$Key = (3,4,2,3,56,34,254,222,1,1,2,23,42,54,33,233,1,34,2,7,6,5,35,43)
$VCenter = '192.168.1.16'            #    'CDF2-VCA-01'

# ----- Dot source write-log
. $PSScriptRoot\write-log.ps1
. C:\Scripts\Windows\UEFI\Write-Log.ps1

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



# ----- Because we don't know if the VCSA is using self signed certs or not.
Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$False

Connect-VIServer $vCenter -Credential $vcenterCred 


#$ServerNames = Get-ADComputer -Filter * -Properties OperatingSystem | where OperatingSystem -like "Windows Server*" | Select-object Name,OperatingSystem | Sort-Object Name | Out-GridView -Title "Select machines to convert to UEFI" -PassThru | Select-Object -ExpandProperty Name
$ServerNames = 'kw-test'
 #'CDF2-Test-WS16'


foreach ($VMName in $ServerNames ) {
    Write-Log -Path "$LogPath\$($VMName).log" -Message "Converting $VMName ------------------------------------" -Verbose:$IsVerbose
    

    $VM = Get-VM -Name $VMName

    # ----- Create a snapshot just in case ( grabbing mem also so if we revert this should be a running VM )
    Try {
        Write-Log -Path "$LogPath\$($VMName).log" -Message "Creating Snapshot" -Verbose:$IsVerbose
        New-Snapshot -VM $VM -Name "Pre UEFI Conversion - $(Get-Date -Format MM-dd-yyyy:HHmm)" -Memory -ErrorAction Stop 
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
        New-PSDrive -Name "J" -Root \\$VMIP\c$ -PSProvider FileSystem -Credential $ServerAdmin -ErrorAction Stop 
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

        Get-CDDrive -vm $VM -ErrorAction Stop | Set-CDDrive -IsoPath $ISO -StartConnected:$True -Connected:$True -Confirm:$False -ErrorAction Stop
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






        #    $spec = New-Object VMware.Vim.VirtualMachineConfigSpec 
        #    $Spec.BootOPtions = New-Object VMware.Vim.VirtualMachineBootOptions 
        #    $SPec.BootOptions.BootOrder = New-Object -Type VMware.Vim.VirtualMachineBootOptionsBootableCdromDevice
        #
        #    ## reconfig the VM to use the spec with the new BootOrder
        #    $vm.ExtensionData.ReconfigVM_Task($spec)

    # ----- so I am having problem imediately starting the VM.  So pausing for x Seconds
    Start-Sleep -Seconds 30

    Write-Log -Path "$LogPath\$($VMName).log"  -Message "Booting to WINPE to performing the magic" -Verbose:$IsVerbose
    Start-VM -vm $VM 

    $VM = Get-vm -name $VMName

    # ----- Wait for VM to boot in WINPE and then stop.
    Write-Log -Path "$LogPath\$($VMName).log"  -Message "Waiting until the VM is in a PoweredOff State" -Verbose:$IsVerbose
    while ( $VM.PowerState -ne 'PoweredOff' ) {
        Start-Sleep -s 5
        Write-Output "Powerstate = $($VM.Powerstate)"
        $VM = Get-VM -Name $VMName
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



    # ----- Cleanup

    # ----- remove temp boot order
        # ----- Gather VM info we will need
        $VM = Get-VM -Name $VMName

        $VMXPath = $VM.ExtensionData.Config.Files.VmPathName
        $VMXDS = Get-Datastore $VMXPath.split(' ')[0].trim('[',']')
        $VMXName = $VMXPath.split(' ')[1].Replace( '/','\')
        $Folder = $VM.Folder

        # ----- If VM is in resouce pool use that otherwise just use the cluster as the resource
        if ( $($VM.ResourcePool) ) {
            $ResourcePool = $VM.ResourcePool
        }
        Else {
            $ResourcePool = (Get-Cluster -VM $VM).Name
        }

        # ----- It seems that when you change the Bootoptions via PowerCLI, it also changes the BIOS order.  And removing the BootOrder from the VMX does not set the order back.  SO setting it with Powerclie and then clearing

        $spec = New-Object VMware.Vim.VirtualMachineConfigSpec

        $BootOptions = New-Object VMware.Vim.VirtualMachineBootOptions

        $BootableCDRom = New-Object -Type VMware.Vim.VirtualMachineBootOptionsBootableCdromDevice

        $HDiskDeviceName = "Hard disk 1"
        $HDiskDeviceKey = ($vm.ExtensionData.Config.Hardware.Device | ?{$_.DeviceInfo.Label -eq $HDiskDeviceName}).Key
        $BootableHDisk = New-Object -TypeName VMware.Vim.VirtualMachineBootOptionsBootableDiskDevice -Property @{"DeviceKey" = $HDiskDeviceKey}

        $BootOrder = $BootableCDRom

        $BootOptions.BootOrder = $BootableHDisk,$BootOrder

        $Spec.BootOptions = $BootOptions

        $VM.ExtensionData.reconfigvm( $Spec )

        # ----- Remove and Reregister so VMX changes happen
        Remove-Inventory -Item $VM -Confirm:$False

        # ----- Register VM (use clustername as the default resourcepool)
        $VM = New-VM -VMFilePath $VMXPath -Location $Folder -ResourcePool $ResourcePool

        # ----- Apparently the settings don't change unless the VM boots.  Booting and shuting down
        Start-VM -VM $VM 
        Wait-Tools -vm $VM

        Shutdown-VMGuest -vm $VM -Confirm:$False 

        $VM = Get-VM -Name $VMName

        # ----- Wait for VM to be powered off.
        Write-Output "Waiting until the VM is in a PoweredOff State prior to changing boot order"
        while ( $VM.PowerState -ne 'PoweredOff' ) {
            Start-Sleep -s 5
            Write-Output "Powerstate = $($VM.Powerstate)"
            $VM = Get-VM -Name $VMName
        }




        # ----- Clearing Bios.bootORder from VMX

        # ----- Editing the VMX to be safe unregister VM
        Remove-Inventory -Item $VM -Confirm:$False

        # ----- Copy locally to edit and rename as backup
        Copy-DatastoreItem  -Item "$($VMXDS.DatastoreBrowserPath)\$VMXName" -Destination c:\temp\$($VMName).vmx.old

        # ----- Renaming to .old as backup
        #Rename-Item c:\temp\$($VMName).vmx -NewName c:\temp\$($VMName).vmx.old

        Get-Content -Path c:\temp\$($VMName).vmx.old | Select-String -Pattern bios.bootOrder -NotMatch | Set-Content -Path c:\temp\$($VMName).vmx


        # ----- back to datastore and register VM
        Copy-DatastoreItem -Item c:\temp\$($VMName).vmx -Destination "$($VMXDS.DatastoreBrowserPath)\$VMXName"

        # ----- Register VM (use clustername as the default resourcepool)
        $VM = New-VM -VMFilePath $VMXPath -Location $Folder -ResourcePool $ResourcePool 

   #     $spec = New-Object VMware.Vim.VirtualMachineConfigSpec 
   #     $Spec.BootOPtions = New-Object VMware.Vim.VirtualMachineBootOptions 
   #     $SPec.BootOptions.BootOrder = $Null
   #
   #     ## reconfig the VM to use the spec with the new BootOrder
   #     $vm.ExtensionData.ReconfigVM_Task($spec)

    # ----- Running into connection closed errors when piping.  so split this into two lines.
    $CD = Get-CDDrive -VM $VM 
    Set-CDDrive -CD $CD -NoMedia -Confirm:$False

    Start-VM -VM $VM

}


Disconnect-VIServer -Confirm:$False


#
## ----- Remove the snapshot?
##Get-Snapshot -VM $VM -Name "Pre UEFI Conversion*" | Remove-Snapshot
