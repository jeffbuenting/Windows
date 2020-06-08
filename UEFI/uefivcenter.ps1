# ----- Script to configure VM and boot it via WINPE to convert from Legacy BIOS to UEFI




$LogPath = 'c:\temp'       #'\\10.137.8.9\UEFIConvertLogs'
$LogPath = '\\192.168.1.166\source'
$ISO = '[LocalHDD] ISO/Windows/WINPE_UEFI.iso'      #"[ISO] Utilitiy/WINPE_UEFI.iso"
$Key = (3,4,2,3,56,34,254,222,1,1,2,23,42,54,33,233,1,34,2,7,6,5,35,43)
$VCenter = '192.168.1.16'            #    'CDF2-VCA-01'



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
    while ( $VM.PowerState -ne 'PoweredOff' ) {
        Start-Sleep -s 5
        Write-Output "Powerstate = $($VM.Powerstate)"
        $VM = Get-VM -Name $VMName
    }

    Start-Sleep -s 30

    Write-Log -Path "$LogPath\$($VMName).log"  -Message "Starting VM." -Verbose:$IsVerbose
    Start-VM -VM $VM

    # ----- restart VM to poweron.
    Write-Log -Path "$LogPath\$($VMName).log"  -Message "Waiting to VM to poweron" -Verbose:$IsVerbose

    $VM = Get-vm -name $VMName

    $VM.Guest | FL *

    while ( $VM.PowerState -ne 'PoweredOn' ) {
        Start-Sleep -s 5
        Write-Output "Powerstate = $($VM.Powerstate)"
        $VM = Get-VM -Name $VMName
    }

    # ----- Check if VMTools installed.
    Write-Log -Path "$LogPath\$($VMName).log"  -Message "Checking if VM Tools are installed." -Verbose:$IsVerbose

    if ( $VM.Guest.ToolsVersion -ne "" ) {
        Write-Log -Path "$LogPath\$($VMName).log" -Warning -Message "VMTools are installed.  VM did not boot into WINPE_UEFI ISO.`nSkipping." -Verbose:$IsVerbose
    }
    Else {
        Write-Log -Path "$LogPath\$($VMName).log" -Warning -Message "VMTools are NOT installed.  Assuming VM has booted to UEFI Conversion ISO.`nContinuing UEFI Conversion." -Verbose:$IsVerbose

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