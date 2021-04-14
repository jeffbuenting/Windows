#------------------------------------------------------------------------------------------
# Config-Server
#
# Automates the post server install
#------------------------------------------------------------------------------------------

param ( [String]$ComputerName = 'Empty',		# ----- Contains a name if running remotely
		[Bool]$Debug = $False )					# ----- Debug Var Set to true if debuggins script
		
#-------------------------------------------------------------------------------------
# Main
#-------------------------------------------------------------------------------------

if ( $Debug -eq $true ) {
	Write-Host "Beginning Script Config-VM.ps1"
	Write-Host "  ComputerName = $ComputerName"
	Write-Host "  Debug = $Debug"
}
	
if ( $ComputerName -eq 'Empty' ) {
	Import-Module \\vbgov.com\deploy\Disaster_Recovery\Powershell\Modules\Input\Input.psm1
	
	$ComputerName = Get-InputWindow -question "Please input the name of the server to configure..."
	
	# ----- Get name of computer the Script is running on
	$ScriptComputerName = GC env:computername
	
	If ( ( $ScriptComputerName -eq $ComputerName ) -or ( $ComputerName -eq '' ) ) { 	# ----- Script is running on local Computer
		$LocalScript = $true
		$ComputerName = $ScriptComputerName
	}
}

Clear-host

# ----- Configurations for all Servers

# ----- Set IP

Write-Host "Add AD groups to local groups..." -ForegroundColor Green
import-module '\\vbgov.com\deploy\Disaster_Recovery\ActiveDirectory\Scripts\LocalUsersAndComputersModule\LocalUsersAndComputersModule'

# ----- Add Server Local Admin-U group to the Local Administrators Group
$LocalAdmins = Get-LocalGroupMember 'Administrators' -server $ComputerName

$LocalAdmins

if ( $LocalAdmins  -notcontains "Server Local Admins-U" ) {   	# ----- Add the group 
	Add-LocalGroupMember -ADGroup 'Server Local Admins-U' -localgroup 'Administrators' -Server $ComputeName
}

# ----- Add COMIT Operations DataCenter Group to the Local Remote Desktop Group
$LocalRemoteDesktop = Get-LocalGroupMember 'Remote Desktop Users' -Server $Computername
if ( $LocalRemoteDesktop  -notcontains "COMIT Operations Support data Center-U" ) {   	# ----- Add the group 
	Add-LocalGroupMember -ADGroup 'COMIT Operations Support data Center-U' -localgroup 'Remote Desktop Users' -Server $ComputerName
}

# ----- Add COMIT Operations Server Shutdown-U Group to the Local Power Users Group
$LocalPowerUsers = Get-LocalGroupMember 'Power Users' -Server $Computername
if ( $LocalRemoteDesktop  -cnotcontains "COMIT Operations Support data Center-U" ) {   	# ----- Add the group 
	Add-LocalGroupMember -ADGroup 'Comit Operations Server Shutdown-U' -localgroup 'Power Users' -Server $ComputerName
}

# ----- Create Temp Directory
Write-Host "Creating Temp Directory..." -ForegroundColor Green
if ( $LocalScript ) {                # ----- Create dir local
		if ( (Test-Path "C:\Temp") -eq $False ) {
			Set-Location c:\ 
			New-Item -name temp -ItemType directory -ErrorAction SilentlyContinue
		}
	}
	else {
		Invoke-Command -ComputerName $ComputerName -ScriptBlock {
			if ( (Test-Path "C:\Temp") -eq $False ) {
				Set-Location c:\ 
				New-Item -name temp -ItemType directory -ErrorAction SilentlyContinue
			}
		}
}

# ----- Install SCCM Client Agent ---------------------------------------------------
Write-Host "Installing SCCM Client Agent....." -ForegroundColor Green
if ( $LocalScript ) {
		$job = Start-Job {  & "\\vbas0076\SMS_CVB\Client\ccmsetup.exe" } 
		Wait-Job $job
	}
	else {
		Invoke-Command -ComputerName $ComputerName -ScriptBlock {
			$job = Start-Job {  & "\\vbas0076\SMS_CVB\Client\ccmsetup.exe" } 
			Wait-Job $job
		}
}

# ----- Add required windows Roles / Features --------------------------------------

Write-Host "Adding standard Roles / Features..." -ForegroundColor Green

if ($LocalScript) { 
		set-wsmanquickconfig -force
	}
	else {
		



#if ( $ServerInfo.Virtual -eq $True ) {			# ----- Server is virtual
#		# ----- Configure Time Sync Integrated Components
#		set-service -Name VMICTIMESYNC -StartupType Disabled -Status Stopped
#		Set-Service -Name W32Time -Status Stopped
#		Set-Service -Name W32Time -Status Running
#	}
#	else {										# ----- Server is physical
#		# ----- Enable SNMP
#		Write-Host "Phisical Server..." -ForegroundColor green
#		Write-Host "     Installing SNMP..." -ForegroundColor green
#		Import-Module servermanager
#		add-windowsfeature SNMP-Service
#	
#		# ----- Install PSP
#		$PSP = Get-InstalledApplications
#
#
#		$PSPInstalled = $False
#		foreach ( $App in $PSP ) {
#			if ( $App.DisplayName -eq 'HP Insight Management Agents' ) { $PSPInstalled = $true } 
#		}
#
#		if ( $PSPInstalled ) {
#				Write-Host "     PSP already installed..." -ForegroundColor green
#			}
#			else {
#				Write-Host "     Installing PSP..." -ForegroundColor green
#				
#				Copy-Item '\\vbgov.com\deploy\OS Servers\apps\HP\PSP\8.7-x64' 'c:\temp' -recurse -force
#				'c:\Temp\8.7-x64\hpsum.exe /express_install'
#				Write-Host "Press any key to continue after PSP installation has completed..."
#
#				$x = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
#		}
#}
#
#if ( $ComputerName -match 'VBVS\d{4}' ) {		# ----- Server is a virtual host
#		Write-Host "Hyper-V Server..."
#	}
#	else {										# ----- Server is not a virtual host
#		# ----- Installing McCrappy EPO Agent
#		Write-Host "Installing McCrappy EPO Agent....."
#		& "\\vbgov.com\deploy\Disaster_Recovery\McAfee_AntiVirus\EPOAgent\FramePkg.exe"
#		Write-Host "Email Shawn so he can config EPO correctly on server.  Go ahead, I'll Wait ...." -ForegroundColor green
#		Write-Host "Press any key when the Email has been sent" 
#		$x = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
#}
#
#
## ----- Get OS Version
#Write-Host "Loading OS Specific hotfixes and featurs ..." -ForegroundColor Green
#$OS = Gwmi Win32_OperatingSystem 
#$OS
#$OS.Caption
#
#switch -regex ( $OS.Caption ) {
#	'Microsoft Windows Server 2008 R2 Enterprise' { 
#		Write-Host "$OS.Caption" -foregroundcolor yellow
#
#		
#		# ----- Install Required Hotfixes
#		Write-Host "Installing HotFixes..." -ForegroundColor green
#		$Command = '\\vbgov.com\deploy\OS Servers\Patches\W2k8R2 Hotfixes\KB2470949 - Avg Disk sec per transfer very high and incorrect\Windows6.1-KB2470949-v2-x64.msu'
#		Copy-Item $Command c:\temp
#		$HFCMD = "c:\temp\Windows6.1-KB2470949-v2-x64 /quiet /norestart"
#		$CMD = Start-Process -FilePath 'c:\Windows\System32\wusa.exe' -ArgumentList $HFCMD -passthru
#		do{}until ($CMD.HasExited -eq $true)
#		$ExitCode = $CMD.GetType().GetField("exitCode", "NonPublic,Instance").GetValue($CMD)
#		
#		Switch ( $ExitCode ) {
#			0			{ 
#					Write-Host "Done"
#					$Reboot = $True
#				}
#			2			{ $CMD }
#			3			{ Write-Host "This update applies to a ROLE or Feature that is not installed on this computer" -ForegroundColor Yellow }
#			3010		{ Write-Host "Hotfix for Windows is already installed on this computer." -ForegroundColor Yellow }
#			-2145124329 { Write-Host "The Update is not applicable to your computer" -ForegroundColor Yellow }
#			-2145124330 { Write-Host "Another Install is underway.  Please wait for that one to complete and restart this one." -ForegroundColor Yellow } 
#			default 	{ Write-Host "Unknown Exit Code --> $ExitCode" -ForegroundColor Magenta }
#		}
#
#	}
#	'Microsoft Windows Server 2008 R2 Standard' { 
#		Write-Host "$OS.Caption"
#		
#		# ----- Install Required Hotfixes
#		Write-Host "Installing HotFixes..." -ForegroundColor green
#		$Command = '\\vbgov.com\deploy\OS Servers\Patches\W2k8R2 Hotfixes\KB2470949 - Avg Disk sec per transfer very high and incorrect\Windows6.1-KB2470949-v2-x64.msu'
#		Copy-Item $Command c:\temp
#		$HFCMD = "c:\temp\Windows6.1-KB2470949-v2-x64 /quiet /norestart"
#		$CMD = Start-Process -FilePath 'c:\Windows\System32\wusa.exe' -ArgumentList $HFCMD -passthru
#		do{}until ($CMD.HasExited -eq $true)
#		$ExitCode = $CMD.GetType().GetField("exitCode", "NonPublic,Instance").GetValue($CMD)
#		
#		Switch ( $ExitCode ) {
#			0			{ 
#					Write-Host "Done"
#					$Reboot = $True
#				}
#			3			{ Write-Host "This update applies to a ROLE or Feature that is not installed on this computer" -ForegroundColor Yellow }
#			3010		{ Write-Host "Hotfix for Windows is already installed on this computer." -ForegroundColor Yellow }
#			-2145124329 { Write-Host "The Update is not applicable to your computer" -ForegroundColor Yellow }
#			-2145124330 { Write-Host "Another Install is underway.  Please wait for that one to complete and restart this one." -ForegroundColor Yellow } 
#			default 	{ Write-Host "Unknown Exit Code --> $ExitCode" -ForegroundColor Magenta }
#		}
#
#	}
#	'Microsoft Windows Server 2008 Enterprise' {
#		Write-Host "$OS.Caption"
#	}
#	'Microsoft Windows Server 2008 R2 Datacenter' {
#		Write-Host "$OS.Caption"
#	}
#	Default { Write-Host "OS unknown:" $OS.Version  $OS.caption $OS.name-ForegroundColor Magenta }
#}
#
##-------------------------------------------------------------------------------
## Configure the server depending on its purpose
##-------------------------------------------------------------------------------
#
#Write-Host 'Configuring Server Depending on type...' -ForegroundColor Green
#
#switch -regex ( $ComputerName ) {
#	'vbvs\d{4}' {	# ----- Virtual Host
#		Write-Host "Configuring Hyper-V Server..." -ForegroundColor green
#	
#		# ----- Enable Fail Over clustering Feature
#		Write-Host "     Adding Fail Over Clustering..." -ForegroundColor green
#		add-windowsfeature Failover-clustering
#		
#		# ----- Install HP Application Aware Snapshot
#		
#		Write-Host "     Installing HP P4000 Application Aware Snapshot Manager..." -ForegroundColor green
#		if ( test-RegPath $ComputerName 'LocalMachine' "SOFTWARE\Wow6432Node\HP\HP P4000 Application Aware Snapshot Manager\9.5.0.1004" ) {		# ----- Software Already Installed
#				Write-Host "     HP Application Aware Snapshot already installed..." -ForegroundColor Yellow
#			}
#			else {
#				Copy-Item '\\vbgov.com\deploy\Disaster_Recovery\HP LeftHand SAN\Software\SANiQ9.5\HP_Application_Aware_Snapshot_Installer_9.5.0.1004_P25020.exe' 'c:\temp'
#				& 'c:\Temp\HP_Application_Aware_Snapshot_Installer_9.5.0.1004_P25020.exe'
#				Write-Host "Press any key to continue after HP Application Aware Snapshot installation has completed..."
#
#				$x = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
#		}
#		
#		# ----- Install HP DSM
#		
#		Write-Host "     Installing HP DSM..." -ForegroundColor green
#		if ( test-RegPath $ComputerName 'LocalMachine' "SOFTWARE\Wow6432Node\HP\HP P4000 DSM for MPIO\9.5.0.981.1" ) {
#				Write-Host "     HP DSM already installed..." -ForegroundColor Yellow
#			}
#			else {
#				
#				
#				Copy-Item '\\vbgov.com\deploy\Disaster_Recovery\HP LeftHand SAN\Software\SANiQ9.5\HP_DSM_Installer_9.5.0.981.exe' 'c:\temp'
#				& 'c:\Temp\HP_DSM_Installer_9.5.0.981.exe'
#				Write-Host "Press any key to continue after HP DSM installation has completed..."
#
#				$x = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
#		}
#		
#		# ----- Add Hyper-V feature
#		Write-Host "     Adding Hyper-V Role..." -ForegroundColor green
#		add-windowsfeature Hyper-V
#		
#		# ----- Install Patches
#		Write-Host "Installing Hotfixes..." -ForegroundColor green
#		& '\\vbgov.com\deploy\Disaster_Recovery\Hyper-V Windows 2008\Patches\Host\Install-Hotfixes.ps1'
#		
#		
#	}
#		
#	'vbdb\d{4}' {
#			Write-Host "Configuring Server as Database Server" -ForegroundColor DarkCyan
#			
#			Import-Module activedirectory
#			
#			# ----- Creating group in ad for DB local Admin
#			$Servers = Get-ADComputer -Filter { dnshostname -eq $ComputerName }
#			
#			
#		}
#	'cvb' {
#			Write-Host "$ComputerName -- Server is a workstation.  Double Check name..." -ForegroundColor Red
#			# ----- Creating group in ad for DB local Admin
#			$Servers = Get-ADComputer -Filter { Name -eq $ComputerName }
#			$ObjectPath = ($Servers.DistinguishedName).Substring($ComputerName.length+4)
#			$GroupName = "$ComputerName Local Admins-U"
#			Try {
#					$Group = New-ADGroup -Path $ObjectPath -Name $GroupName -GroupScope Universal -Credential $Cred
#				}
#				Catch {
#					Write-Host "Username or Password is incorrect...." -ForegroundColor Red
#					Break
#			}
#		}
#	default {
#			Write-Host "Unknown Server Name... $ComputerName"	-ForegroundColor Red
#			break
#		}
#}
#
#
#		Write-Host "Press any key to Reboot..."
#
#		$x = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
#
## ----- Reboot
#
## Restart-Computer
#




	