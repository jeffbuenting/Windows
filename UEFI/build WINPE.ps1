#REmove boot from cd
#https://serverfault.com/questions/353826/windows-boot-iso-file-without-press-any-key

Dism /Mount-Image /ImageFile:"C:\WinPE_amd64_ps\media\sources\boot.wim" /index:1 /MountDir:"C:\WinPE_amd64_ps\mount"

Dism /Add-Package /Image:"C:\WinPE_amd64_PS\mount" /PackagePath:"C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Windows Preinstallation Environment\amd64\WinPE_OCs\WinPE-WMI.cab"
Dism /Add-Package /Image:"C:\WinPE_amd64_PS\mount" /PackagePath:"C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Windows Preinstallation Environment\amd64\WinPE_OCs\en-us\WinPE-WMI_en-us.cab"
Dism /Add-Package /Image:"C:\WinPE_amd64_PS\mount" /PackagePath:"C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Windows Preinstallation Environment\amd64\WinPE_OCs\WinPE-NetFX.cab"
Dism /Add-Package /Image:"C:\WinPE_amd64_PS\mount" /PackagePath:"C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Windows Preinstallation Environment\amd64\WinPE_OCs\en-us\WinPE-NetFX_en-us.cab"
Dism /Add-Package /Image:"C:\WinPE_amd64_PS\mount" /PackagePath:"C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Windows Preinstallation Environment\amd64\WinPE_OCs\WinPE-Scripting.cab"
Dism /Add-Package /Image:"C:\WinPE_amd64_PS\mount" /PackagePath:"C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Windows Preinstallation Environment\amd64\WinPE_OCs\en-us\WinPE-Scripting_en-us.cab"
Dism /Add-Package /Image:"C:\WinPE_amd64_PS\mount" /PackagePath:"C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Windows Preinstallation Environment\amd64\WinPE_OCs\WinPE-PowerShell.cab"
Dism /Add-Package /Image:"C:\WinPE_amd64_PS\mount" /PackagePath:"C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Windows Preinstallation Environment\amd64\WinPE_OCs\en-us\WinPE-PowerShell_en-us.cab"
Dism /Add-Package /Image:"C:\WinPE_amd64_PS\mount" /PackagePath:"C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Windows Preinstallation Environment\amd64\WinPE_OCs\WinPE-StorageWMI.cab"
Dism /Add-Package /Image:"C:\WinPE_amd64_PS\mount" /PackagePath:"C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Windows Preinstallation Environment\amd64\WinPE_OCs\en-us\WinPE-StorageWMI_en-us.cab"
Dism /Add-Package /Image:"C:\WinPE_amd64_PS\mount" /PackagePath:"C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Windows Preinstallation Environment\amd64\WinPE_OCs\WinPE-DismCmdlets.cab"
Dism /Add-Package /Image:"C:\WinPE_amd64_PS\mount" /PackagePath:"C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Windows Preinstallation Environment\amd64\WinPE_OCs\en-us\WinPE-DismCmdlets_en-us.cab"

# ----- Add VMWare Drivers
Dism /image:c:\winpe_amd64_ps\mount /add-driver /driver:c:\temp\drivers /recurse

# ----- Copy the scripts to WINPE
if ( -not (Test-Path C:\winpe_amd64_ps\mount\scripts ) ) { New-Item -Path C:\winpe_amd64_ps\mount\Scripts -ItemType Directory }

copy -Path C:\Source\Convertto-UEFI.ps1 -Destination C:\winpe_amd64_ps\mount\Scripts\Convertto-UEFI.ps1 -Force
copy -path C:\Scripts\Logging\Write-Log.ps1 -Destination C:\winpe_amd64_ps\mount\Scripts\Write-Log.ps1 -Force

# ----- the built in MBR2GPT for the 1909 WINPE didn't work.  Copied from my 1803 desktop
copy -Path C:\Windows\System32\mbr2gpt.exe -Destination C:\winpe_amd64_ps\mount\Scripts\MBR2GPT.EXE -Force

# ----- Modify the start up to auto run the powershell script
$Start = Get-Content C:\winpe_amd64_ps\mount\Windows\System32\startnet.cmd
$Start += "`nPowershell -executionpolicy bypass -file x:\scripts\ConvertTo-UEFI.ps1"
$Start | Set-Content C:\winpe_amd64_ps\mount\Windows\System32\startnet.cmd

Dism /Unmount-Image /MountDir:C:\WinPE_amd64_PS\mount /Commit

# ----- remove old WINPE ISO
remove-item C:\temp\WINPE_UEFI.iso

# ----- Create ISO
# ----- https://docs.microsoft.com/en-us/windows-hardware/manufacture/desktop/oscdimg-command-line-options
#& "C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\makewinpemedia" /iso c:\winpe_amd64_ps c:\Temp\WINPE_UEFI.iso 
& 'C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg\oscdimg.exe' -bC:\winpe_amd64_ps\fwfiles\etfsboot.com -p00 -u1 -udfver102 C:\winpe_amd64_ps\media C:\Temp\WINPE_UEFI.iso


# ----- Upload to vCenter Datastore
Copy-DatastoreItem c:\temp\winpe_uefi.iso vmstores:\192.168.1.16@443\KW-HQ\LocalHDD\ISO\Windows\WINPE_UEFI.iso -Force -Confirm:$False


# ----------------------------------------------------------------------------------------------






https://kb.vmware.com/s/article/2032184
https://kb.vmware.com/s/article/1011710
dism /image:c:\winpe_amd64_ps\mount /add-driver /driver:c:\temp\drivers /recurse


REmove boot from cd
 https://serverfault.com/questions/353826/windows-boot-iso-file-without-press-any-key