#REmove boot from cd
#https://serverfault.com/questions/353826/windows-boot-iso-file-without-press-any-key

$WINPEPath = 'E:\WinPE_amd64_ps'
$Source = 'e:\Winpe_amd64_ps\UEFI'

Dism /Mount-Image /ImageFile:"$WINPEPath\media\sources\boot.wim" /index:1 /MountDir:"$WINPEPath\mount" #/logpath:"$WINPath\dism.log"

Dism /Add-Package /Image:"$WINPEPath\mount" /PackagePath:"C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Windows Preinstallation Environment\amd64\WinPE_OCs\WinPE-WMI.cab"
Dism /Add-Package /Image:"$WINPEPath\mount" /PackagePath:"C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Windows Preinstallation Environment\amd64\WinPE_OCs\en-us\WinPE-WMI_en-us.cab"
Dism /Add-Package /Image:"$WINPEPath\mount" /PackagePath:"C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Windows Preinstallation Environment\amd64\WinPE_OCs\WinPE-NetFX.cab"
Dism /Add-Package /Image:"$WINPEPath\mount" /PackagePath:"C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Windows Preinstallation Environment\amd64\WinPE_OCs\en-us\WinPE-NetFX_en-us.cab"
Dism /Add-Package /Image:"$WINPEPath\mount" /PackagePath:"C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Windows Preinstallation Environment\amd64\WinPE_OCs\WinPE-Scripting.cab"
Dism /Add-Package /Image:"$WINPEPath\mount" /PackagePath:"C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Windows Preinstallation Environment\amd64\WinPE_OCs\en-us\WinPE-Scripting_en-us.cab"
Dism /Add-Package /Image:"$WINPEPath\mount" /PackagePath:"C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Windows Preinstallation Environment\amd64\WinPE_OCs\WinPE-PowerShell.cab"
Dism /Add-Package /Image:"$WINPEPath\mount" /PackagePath:"C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Windows Preinstallation Environment\amd64\WinPE_OCs\en-us\WinPE-PowerShell_en-us.cab"
Dism /Add-Package /Image:"$WINPEPath\mount" /PackagePath:"C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Windows Preinstallation Environment\amd64\WinPE_OCs\WinPE-StorageWMI.cab"
Dism /Add-Package /Image:"$WINPEPath\mount" /PackagePath:"C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Windows Preinstallation Environment\amd64\WinPE_OCs\en-us\WinPE-StorageWMI_en-us.cab"
Dism /Add-Package /Image:"$WINPEPath\mount" /PackagePath:"C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Windows Preinstallation Environment\amd64\WinPE_OCs\WinPE-DismCmdlets.cab"
Dism /Add-Package /Image:"$WINPEPath\mount" /PackagePath:"C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Windows Preinstallation Environment\amd64\WinPE_OCs\en-us\WinPE-DismCmdlets_en-us.cab"

# ----- Add VMWare Drivers
Dism /image:$WINPEPath\mount /add-driver /driver:$Source\drivers /recurse

# ----- Copy the scripts to WINPE
if ( -not (Test-Path $WINPEPath\mount\scripts ) ) { New-Item -Path $WINPEPath\mount\Scripts -ItemType Directory }

copy -Path $Source\Convertto-UEFI.ps1 -Destination $WINPEPath\mount\Scripts\Convertto-UEFI.ps1 -Force
copy -path $Source\Write-Log.ps1 -Destination $WINPEPath\mount\Scripts\Write-Log.ps1 -Force

# ----- the built in MBR2GPT for the 1909 WINPE didn't work.  Copied from my 1803 desktop
copy -Path $Source\mbr2gpt.exe -Destination $WINPEPath\mount\Scripts\MBR2GPT.EXE -Force

# ----- Modify the start up to auto run the powershell script
$Start = Get-Content $WINPEPath\mount\Windows\System32\startnet.cmd
$Start += "`nPowershell -executionpolicy bypass -file x:\scripts\ConvertTo-UEFI.ps1"
$Start | Set-Content $WINPEPath\mount\Windows\System32\startnet.cmd

Dism /Unmount-Image /MountDir:$WINPEPath\mount /Commit

# ----- remove old WINPE ISO
remove-item $WinPEPath\WINPE_UEFI.iso

# ----- Create ISO
# ----- https://docs.microsoft.com/en-us/windows-hardware/manufacture/desktop/oscdimg-command-line-options
#& "C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\makewinpemedia" /iso $WINPEPath c:\Temp\WINPE_UEFI.iso 
& 'C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg\oscdimg.exe' -b $WINPEPath\fwfiles\etfsboot.com -p00 -u1 -udfver102 $WINPEPath\media $WINPEPath\WINPE_UEFI.iso


# ----- Upload to vCenter Datastore
#Copy-DatastoreItem $WINPEPath\winpe_uefi.iso vmstores:\192.168.1.16@443\KW-HQ\LocalHDD\ISO\Windows\WINPE_UEFI.iso -Force -Confirm:$False


# ----------------------------------------------------------------------------------------------






https://kb.vmware.com/s/article/2032184
https://kb.vmware.com/s/article/1011710
dism /image:$WINPEPath\mount /add-driver /driver:c:\temp\drivers /recurse


REmove boot from cd
 https://serverfault.com/questions/353826/windows-boot-iso-file-without-press-any-key