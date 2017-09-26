#------------------------------------------------------------------------------
# Server-PSModule.psm
#
# Contains functions to manipulate servers and retrieve information
#------------------------------------------------------------------------------

#------------------------------------------------------------------------------
# Function Get-HDDUsedSpaceHardDrive
#
#	Returns what Windows sees as used space on all of its hard drives as one number.
#-----------------------------------------------------------------------------

Function Get-HDDUsedSpace

{
	param ( [String]$ServerName = ".",
			[Switch]$Debug )
	
#	if ( $Debug ) { Write-Host "ServerName = $ServerName" -ForegroundColor Cyan }
	try {
			$Disks = gwmi -Class Win32_LogicalDisk -ComputerName $ServerName | where { ($_.drivetype -eq '3') -and ($_.volumename -eq '') } -ErrorAction SilentlyContinue
			
		}
		catch {
#			if ( $Debug ) { Write-Host "Cannot connect to WMI on VM " $VM.name -ForegroundColor Red }
#				throw $error[0].Exception

	}
	if ( -not $? ) { 
		if ( $Debug ) {
			Write-Host "ERROR - Check the Server as this name is not valid $ServerName`n`n" -ForegroundColor Red
			write-host $_ -ForegroundColor red
		}
	}
	
	$Disks
	
	$WindowsTotalSize = 0
	foreach ( $Disk in $Disks ) {
		if ( $Debug ) { Write-Host "Disk = $Disk" -ForegroundColor Cyan }
		$WindowsTotalSize += $Disk.size - $Disk.Freespace
		
	}
	$HDDInfo = New-Object system.Object
	$HDDInfo | Add-Member -type NoteProperty -Name ServerName -Value $Servername
	$HDDInfo | Add-Member -type NoteProperty -Name Disks -Value $Disks
	$HDDInfo | Add-Member -type NoteProperty -Name TotalDiskSpaceUsedbyWIndows -Value ($WindowsTotalSize/1GB)
	
	if ( $Debug ) { Write-Host "Windows Total Size = $WindowsTotalSize" -ForegroundColor Cyan }
	
	$HDInfo
	
	Return $HDDInfo
}

#-----------------------------------------------------------------------------------------
# Function Get-ServerInfo
#
#
#-----------------------------------------------------------------------------------------

Function Get-ServerInfo

{
	param ( $ServerName = '.',			# ----- Name of server
			$Debug = $False )				

	$ServerInfo = New-Object system.object
		
	if ( $ServerName -eq '.' ) {
			# ----- Get name of computer the Script is running on
			$ServerInfo | Add-Member -type NoteProperty -Name ServerName -Value ( GC env:computername )
			
			# ----- Physical or Virtual?
			if ( Test-Path "HKLM:\SOFTWARE\Microsoft\Virtual Machine\Guest\Parameters" ) {
 					$regPath= "HKLM:\SOFTWARE\Microsoft\Virtual Machine\Guest\Parameters" 
					$regValue = get-itemproperty -path $regPath
				
					$ServerInfo | Add-Member -type NoteProperty -Name Virtual -Value True
					$ServerInfo | Add-Member -type NoteProperty -Name VirtualHost -Value $regValue.PhysicalHostNameFullyQualified
				}
				else {
					$ServerInfo | Add-Member -type NoteProperty -Name Virtual -Value False
			}
		}
		else {
			# ----- Get name of computer the Script is running on
			$ServerInfo | Add-Member -type NoteProperty -Name ServerName -Value $ServerName
			
			# ----- Physical or Virtual?
			$reg = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey( 'LocalMachine', $ServerName )         
 			$regKey= $reg.OpenSubKey("SOFTWARE\Microsoft\Virtual Machine\Guest\Parameters")      
 			if ($regKey -ne $null){
					$regValue = $regKey.GetValueNames()
					$Regkey.getValueNames()
					$ServerInfo | Add-Member -type NoteProperty -Name Virtual -Value True
					$ServerInfo | Add-Member -type NoteProperty -Name VirtualHost -Value ( $regKey.getvalue( 'PhysicalHostNameFullyQualified' ) )
				}
				else { 
					$ServerInfo | Add-Member -type NoteProperty -Name Virtual -Value False
			} 
	}

	Return $ServerInfo
}

#-----------------------------------------------------------------------------------------
#-----------------------------------------------------------------------------------------

Export-ModuleMember -Function Get-HDDUsedSPace, Get-ServerInfo
