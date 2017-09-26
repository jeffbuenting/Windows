#---------------------------------------------------------------------------------
# Windows Powershell Cmdlets
#---------------------------------------------------------------------------------

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

#---------------------------------------------------------------------------------

Function Get-PendingReboot
{
<#
.SYNOPSIS
    Gets the pending reboot status on a local or remote computer.

.DESCRIPTION
    This function will query the registry on a local or remote computer and determine if the
    system is pending a reboot, from either Microsoft Patching or a Software Installation.
    For Windows 2008+ the function will query the CBS registry key as another factor in determining
    pending reboot state.  "PendingFileRenameOperations" and "Auto Update\RebootRequired" are observed
    as being consistant across Windows Server 2003 & 2008.
	
    CBServicing = Component Based Servicing (Windows 2008)
    WindowsUpdate = Windows Update / Auto Update (Windows 2003 / 2008)
    CCMClientSDK = SCCM 2012 Clients only (DetermineIfRebootPending method) otherwise $null value
    PendFileRename = PendingFileRenameOperations (Windows 2003 / 2008)

.PARAMETER ComputerName
    A single Computer or an array of computer names.  The default is localhost ($env:COMPUTERNAME).

.PARAMETER ErrorLog
    A single path to send error data to a log file.

.EXAMPLE
    PS C:\> Get-PendingReboot -ComputerName (Get-Content C:\ServerList.txt) | Format-Table -AutoSize
	
    Computer CBServicing WindowsUpdate CCMClientSDK PendFileRename PendFileRenVal RebootPending
    -------- ----------- ------------- ------------ -------------- -------------- -------------
    DC01           False         False                       False                        False
    DC02           False         False                       False                        False
    FS01           False         False                       False                        False

    This example will capture the contents of C:\ServerList.txt and query the pending reboot
    information from the systems contained in the file and display the output in a table. The
    null values are by design, since these systems do not have the SCCM 2012 client installed,
    nor was the PendingFileRenameOperations value populated.

.EXAMPLE
    PS C:\> Get-PendingReboot
	
    Computer       : WKS01
    CBServicing    : False
    WindowsUpdate  : True
    CCMClient      : False
    PendFileRename : False
    PendFileRenVal : 
    RebootPending  : True
	
    This example will query the local machine for pending reboot information.
	
.EXAMPLE
    PS C:\> $Servers = Get-Content C:\Servers.txt
    PS C:\> Get-PendingReboot -Computer $Servers | Export-Csv C:\PendingRebootReport.csv -NoTypeInformation
	
    This example will create a report that contains pending reboot information.

.LINK
    Component-Based Servicing:
    http://technet.microsoft.com/en-us/library/cc756291(v=WS.10).aspx
	
    PendingFileRename/Auto Update:
    http://support.microsoft.com/kb/2723674
    http://technet.microsoft.com/en-us/library/cc960241.aspx
    http://blogs.msdn.com/b/hansr/archive/2006/02/17/patchreboot.aspx

    SCCM 2012/CCM_ClientSDK:
    http://msdn.microsoft.com/en-us/library/jj902723.aspx

.NOTES
    Author:  Brian Wilhite
    Email:   bwilhite1@carolina.rr.com
    Date:    08/29/2012
    PSVer:   2.0/3.0
    Updated: 05/30/2013
    UpdNote: Added CCMClient property - Used with SCCM 2012 Clients only
             Added ValueFromPipelineByPropertyName=$true to the ComputerName Parameter
             Removed $Data variable from the PSObject - it is not needed
             Bug with the way CCMClientSDK returned null value if it was false
             Removed unneeded variables
             Added PendFileRenVal - Contents of the PendingFileRenameOperations Reg Entry
#>

[CmdletBinding()]
param(
	[Parameter(Position=0,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
	[Alias("CN","Computer")]
	[String[]]$ComputerName="$env:COMPUTERNAME",
	[String]$ErrorLog
	)

Begin
	{
		# Adjusting ErrorActionPreference to stop on all errors, since using [Microsoft.Win32.RegistryKey]
        # does not have a native ErrorAction Parameter, this may need to be changed if used within another
        # function.
		$TempErrAct = $ErrorActionPreference
		$ErrorActionPreference = "Stop"
	}#End Begin Script Block
Process
	{
		Foreach ($Computer in $ComputerName)
			{
				Try
					{
						# Setting pending values to false to cut down on the number of else statements
						$PendFileRename,$Pending,$SCCM = $false,$false,$false
                        
                        # Setting CBSRebootPend to null since not all versions of Windows has this value
                        $CBSRebootPend = $null
						
						# Querying WMI for build version
						$WMI_OS = Get-WmiObject -Class Win32_OperatingSystem -Property BuildNumber, CSName -ComputerName $Computer

						# Making registry connection to the local/remote computer
						$RegCon = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey([Microsoft.Win32.RegistryHive]"LocalMachine",$Computer)
						
						# If Vista/2008 & Above query the CBS Reg Key
						If ($WMI_OS.BuildNumber -ge 6001)
							{
								$RegSubKeysCBS = $RegCon.OpenSubKey("SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\").GetSubKeyNames()
								$CBSRebootPend = $RegSubKeysCBS -contains "RebootPending"
									
							}#End If ($WMI_OS.BuildNumber -ge 6001)
							
						# Query WUAU from the registry
						$RegWUAU = $RegCon.OpenSubKey("SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\")
						$RegWUAURebootReq = $RegWUAU.GetSubKeyNames()
						$WUAURebootReq = $RegWUAURebootReq -contains "RebootRequired"
						
						# Query PendingFileRenameOperations from the registry
						$RegSubKeySM = $RegCon.OpenSubKey("SYSTEM\CurrentControlSet\Control\Session Manager\")
						$RegValuePFRO = $RegSubKeySM.GetValue("PendingFileRenameOperations",$null)
						
						# Closing registry connection
						$RegCon.Close()
						
						# If PendingFileRenameOperations has a value set $RegValuePFRO variable to $true
						If ($RegValuePFRO)
							{
								$PendFileRename = $true

							}#End If ($RegValuePFRO)

						# Determine SCCM 2012 Client Reboot Pending Status
						# To avoid nested 'if' statements and unneeded WMI calls to determine if the CCM_ClientUtilities class exist, setting EA = 0
						$CCMClientSDK = $null
                        $CCMSplat = @{
                            NameSpace='ROOT\ccm\ClientSDK'
                            Class='CCM_ClientUtilities'
                            Name='DetermineIfRebootPending'
                            ComputerName=$Computer
                            ErrorAction='SilentlyContinue'
                            }
                        $CCMClientSDK = Invoke-WmiMethod @CCMSplat
						If ($CCMClientSDK)
                            {
                                If ($CCMClientSDK.ReturnValue -ne 0)
							        {
								        Write-Warning "Error: DetermineIfRebootPending returned error code $($CCMClientSDK.ReturnValue)"
                            
							        }#End If ($CCMClientSDK -and $CCMClientSDK.ReturnValue -ne 0)

						        If ($CCMClientSDK.IsHardRebootPending -or $CCMClientSDK.RebootPending)
							        {
								        $SCCM = $true

							        }#End If ($CCMClientSDK.IsHardRebootPending -or $CCMClientSDK.RebootPending)

                            }#End If ($CCMClientSDK)
                        Else
                            {
                                $SCCM = $null

                            }                        
                        
                        # If any of the variables are true, set $Pending variable to $true
						If ($CBSRebootPend -or $WUAURebootReq -or $SCCM -or $PendFileRename)
							{
								$Pending = $true

							}#End If ($CBS -or $WUAU -or $PendFileRename)
							
						# Creating Custom PSObject and Select-Object Splat
                        $SelectSplat = @{
                            Property=('Computer','CBServicing','WindowsUpdate','CCMClientSDK','PendFileRename','PendFileRenVal','RebootPending')
                            }
						New-Object -TypeName PSObject -Property @{
								Computer=$WMI_OS.CSName
								CBServicing=$CBSRebootPend
								WindowsUpdate=$WUAURebootReq
								CCMClientSDK=$SCCM
								PendFileRename=$PendFileRename
                                PendFileRenVal=$RegValuePFRO
								RebootPending=$Pending
								} | Select-Object @SelectSplat

					}#End Try

				Catch
					{
						Write-Warning "$Computer`: $_"
						
						# If $ErrorLog, log the file to a user specified location/path
						If ($ErrorLog)
							{
								Out-File -InputObject "$Computer`,$_" -FilePath $ErrorLog -Append

							}#End If ($ErrorLog)
							
					}#End Catch
					
			}#End Foreach ($Computer in $ComputerName)
			
	}#End Process
	
End
	{
		# Resetting ErrorActionPref
		$ErrorActionPreference = $TempErrAct
	}#End End
	
}#End Function


#--------------------------------------------------------------------------------
# User Cmdlets
#--------------------------------------------------------------------------------

Function Get-LoggedOnUser {

<#
    .Synopsis
        Retrieves a list of users with logged in sessions

    .Description
        Uses Query Session to retrieve users who currently have a session logged onto a computer.  Returns only the sessiosn with a user name.

    .Parameter ComputerName
        Name of the computer from which to retrieve Sessions

    .Parameter Exclude
        Retrieves all user log on sessions except these.

    .Parameter Include
        Retrieve only these Sessions

    .Example
        Retrieves all logged on User Sessions from a computer

        Get-LoggedOnUser -ComuterName $Server

    .Example
        Gets a list of logged on Users sessions excluding the administrator 

        Get-LoggedOnUser -ComputerName $Server -Exclude Administrator

    .Example
        Returns a list of Logged on User Sessions from a list of user names.

        $Servers | Get-LoggedOnUser -UserName Administrator,Bob.Smith

    .Link
        https://www.petri.com/powershell-problem-solver-text-objects-regex

        This link shows how to turn text data into an object.  Note  &lt; and &gt; should be < > respectively

    .Note
        Author : Jeff Buenting
        Date : 2016 JUN 23
#>

    [CmdletBinding(DefaultParameterSetName="default")]
    Param (
        [Parameter ( ValueFromPipeline = $True, ValueFromPipelinebyPropertyName = $True )]
        [String[]]$ComputerName = $env:COMPUTERNAME,

        [Parameter (ParameterSetName = 'Exclude' )]
        [String[]]$Exclude,

        [Parameter (ParameterSetName = 'UserName' )]
        [String[]]$UserName
    )

    Begin {
        [regex]$Pattern = "^?\s(?<SessionName>\s+|\S+)?\s+(?<UserName>(?:[a-z,A-Z,\.]+)|\s+)?\s+(?<ID>\w+|\d+)?\s+(?<State>\w+)"

        $names = $pattern.GetGroupNames() | select -skip 1
    }

    Process {
        Foreach ( $C in $ComputerName ) {
            Write-Verbose "Getting User Log on Sessions on $C"

            $Users = query session /server:$c | Select-String -Pattern $Pattern
                
            $UserSessions = $Users.Matches | Select-Object -Skip 1 | foreach {
                $hash=[ordered]@{}
                foreach ($name in $names) {
                    $hash.add($name,$_.groups[$name].value)
                }
                $hash.add('ComputerName',$C)
                [pscustomobject]$hash
            }


            Switch ( $PSCmdlet.ParameterSetName ) {
                'Exclude' {
                    Write-Verbose "Excluding $Exclude"
                    Write-Output ( $UserSessions | where { $_.UserName -And $_.UserName.tolower() -notin $Exclude.tolower() } )
                    break
                }

                'UserName' {
                    Write-Verbose "Filtered on User: $UserName"
                    Write-Output ( $UserSessions | where { $_.UserName -And $_.UserName.ToLower() -in $Username.ToLower() } )
                    break
                }
                
                default {
                    Write-verbose "Output"
                    Write-Output ( $UserSessions | where UserName )
                }
            }
        }
    }
}

#--------------------------------------------------------------------------------
# Sessions
#--------------------------------------------------------------------------------

Function Get-Session {

<#
    .Synopsis
        Returns the sessions on a computer

    .Description
        Returns a list of sessions on a computer.

    .Parameter ComputerName
        Name of the computer that we want to get a list of sessions.

    .Example
        Get a list of sessions from the remote server ServerA

        Get-Session -ComputerName ServerA

    .Link
        https://social.technet.microsoft.com/Forums/scriptcenter/en-US/62230523-b3ff-49b1-a59e-6a3325f2339c/qwinsta-other-ways-to-enumerate-rdp-sessions-powershell-and-custom-objects?forum=ITCG

    .Notes
        Author : Jeff BUenting
        Date : 2017 SEP 26

#>

    [CmdletBinding()]
    Param (
        [Parameter( ValueFromPipeline= $True ) ]
        [String[]]$ComputerName = $env:COMPUTERNAME
    )
        
    Process {
        Foreach ( $C in $ComputerName ) {
            Write-Verbose "Getting Sessions on $C"

            $Results = qwinsta /server:$Computer

            # ----- Separate headers from results
            $Headers = ($Results[0].trim(" ") -replace ("\b *\B")).split(" ")
            $Results = $Results[1..$($Results.Count - 1)]

            $RDPArray = @()
		    foreach ($Result in $Results) {
			    $RDPMember = New-Object Object
			    Add-Member -InputObject $RDPMember -MemberType NoteProperty -Name $Headers[0] -Value $Result.Substring(1,18).Trim()
                Add-Member -InputObject $RDPMember -MemberType NoteProperty -Name $Headers[1] -Value $Result.Substring(19,22).Trim()
			    Add-Member -InputObject $RDPMember -MemberType NoteProperty -Name $Headers[2] -Value $Result.Substring(41,7).Trim()
			    Add-Member -InputObject $RDPMember -MemberType NoteProperty -Name $Headers[3] -Value $Result.Substring(48,8).Trim()
			    Add-Member -InputObject $RDPMember -MemberType NoteProperty -Name $Headers[4] -Value $Result.Substring(56,12).Trim()
				Add-Member -InputObject $RDPMember -MemberType NoteProperty -Name $Headers[5] -Value $Result.Substring(68,8).Trim()
			    
			    $RDPArray += $RDPMember
		    }


            Write-Output $RDPArray
        }
    }

}

#--------------------------------------------------------------------------------
#--------------------------------------------------------------------------------
#--------------------------------------------------------------------------------
#--------------------------------------------------------------------------------