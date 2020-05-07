# ----- Script to configure VM and boot it via WINPE to convert from Legacy BIOS to UEFI

$VMName = 'KW-Test'
$LogPath = '\\192.168.1.166\Source'
$ISO = "[LocalHDD] ISO/Windows/WINPE_UEFI.iso"
$Key = (3,4,2,3,56,34,254,222,1,1,2,23,42,54,33,233,1,34,2,7,6,5,35,43)


#$VcenterCred = Get-Credential
#$ShareCred = Get-Credential
#$ServerAdmin = Get-Credential

Connect-VIServer 192.168.1.16 -Credential $vcenterCred

$VM = Get-VM -Name $VMName

# ----- Create a snapshot just in case ( grabbing mem also so if we revert this should be a running VM )
Try {
    New-Snapshot -VM $VM -Name "Pre UEFI Conversion - $(Get-Date -Format dd-MM-yyyy:HHmm)" -Memory -ErrorAction Stop
}
Catch {
    $ExceptionMessage = $_.Exception.Message
    $ExceptionType = $_.Exception.GetType().Fullname
    Throw "There was an Eror creating a snapshot.`n`n     $ExceptionMessage`n`n $ExceptionType"
}

# ----- Because we can't pass parameters directly to WINPE we will write a file to the VM's C: drive with data needed for the convertion script in that environment
# ----- Get only IPv4 address.  If there is more than one then we will need to find a way to pick the correct one.
$VMIP = $VM.Guest.IPAddress | Select-String -pattern ':' -NotMatch


Try { 
    New-PSDrive -Name "J" -Root \\$VMIP\c$ -PSProvider FileSystem -Credential $ServerAdmin -ErrorAction Stop
}
Catch {
    $ExceptionMessage = $_.Exception.Message
    $ExceptionType = $_.Exception.GetType().Fullname
    
    Throw "Failed to map to the admin share \\$VMIP\c$ on $VMName.`n`n     $ExceptionMessage`n`n $ExceptionType"

}

[PSCustomObject]@{Name = $VMName; LogPath = $LogPath; UserName = $ShareCred.UserName; PW = ($ShareCred.Password | ConvertFrom-SecureString -Key $Key )} | Export-csv -Path  \\$VMIP\c$\WINPEInput.csv -NoTypeInformation


# ----- Remove the J drive now that we no longer need it
Remove-PSDrive -Name 'J'

Try {   
    Write-Output "Mounting WINPE on CDRom"
    Get-CDDrive -vm $VM -ErrorAction Stop | Set-CDDrive -IsoPath $ISO -StartConnected:$True -Connected:$True -Confirm:$False -ErrorAction Stop
}
Catch {
    $ExceptionMessage = $_.Exception.Message
    $ExceptionType = $_.Exception.GetType().Fullname
    Throw "Problem mounting WINPE ISO.`n`n     $ExceptionMessage`n`n $ExceptionType"
}

# ----- VM must be Powered off to change boot order
Shutdown-VMGuest -VM $VM -Confirm:$False

$VM = Get-VM -Name $VMName

# ----- Wait for VM to be powered off.
Write-Output "Waiting until the VM is in a PoweredOff State prior to changing boot order"
while ( $VM.PowerState -ne 'PoweredOff' ) {
    Start-Sleep -s 5
    Write-Output "Powerstate = $($VM.Powerstate)"
    $VM = Get-VM -Name $VMName
}

# ----- Configure VM to Boot from WINPEUIFIConvertion ISO
Write-output "Setting CDRom as only boot option"

$spec = New-Object VMware.Vim.VirtualMachineConfigSpec 
$Spec.BootOPtions = New-Object VMware.Vim.VirtualMachineBootOptions 
$SPec.BootOptions.BootOrder = New-Object -Type VMware.Vim.VirtualMachineBootOptionsBootableCdromDevice

## reconfig the VM to use the spec with the new BootOrder
$vm.ExtensionData.ReconfigVM_Task($spec)

# ----- so I am having problem imediately starting the VM.  So pausing for x Seconds
Start-Sleep -Seconds 30

Write-Output "Booting to WINPE to performing the magic"
Start-VM -vm $VM 

$VM = Get-vm -name $VMName

# ----- Wait for VM to boot in WINPE and then stop.
Write-Output "Waiting until the VM is in a PoweredOff State"
while ( $VM.PowerState -ne 'PoweredOff' ) {
    Start-Sleep -s 5
    Write-Output "Powerstate = $($VM.Powerstate)"
    $VM = Get-VM -Name $VMName
}

# ----- Check log file for success
if ( -Not ( Get-Content -Path $LogPath\$($VMName).log | Select-String "Success : Conversion Complete" ) ) {
    Throw "MBR2GPT on $VMName did not complete successfully.  Restore the Snapshot"
}

# ----- Set BIOS mode to UEFI
$spec = New-Object VMware.Vim.VirtualMachineConfigSpec
$spec.Firmware = [VMware.Vim.GuestOsDescriptorFirmwareType]::efi
$vm.ExtensionData.ReconfigVM($spec)



# ----- Cleanup

# ----- remove tep boot order
$spec = New-Object VMware.Vim.VirtualMachineConfigSpec 
$Spec.BootOPtions = New-Object VMware.Vim.VirtualMachineBootOptions 
$SPec.BootOptions.BootOrder = $Null

## reconfig the VM to use the spec with the new BootOrder
$vm.ExtensionData.ReconfigVM_Task($spec)

Get-CDDrive -VM $VM | Set-CDDrive -NoMedia -Confirm:$False

Start-VM -VM $VM
#
## ----- Remove the snapshot?
##Get-Snapshot -VM $VM -Name "Pre UEFI Conversion*" | Remove-Snapshot
