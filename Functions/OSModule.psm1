#------------------------------------------------------------------------------
# OSModule.psm1
#
# Powershell Module for Operating System 
#-----------------------------------------------------------------------------

#-----------------------------------------------------------------------------
# Function Get-OSVersion
#
# Returns the Version of the OS
#-----------------------------------------------------------------------------

Function Get-OSVersion

{
	param ( $computer ) 
 
	 $os = Get-WmiObject -class Win32_OperatingSystem -computerName $computer
	 
	 $OS
	 
	 $osv = New-Object system.object
	 
	 Switch ($os.Version) 
	  { 
	    "5.1.2600" { $OSV | Add-Member -type NoteProperty -Name Version -Value "xp" } 
	    "5.1.3790" { $OSV | Add-Member -type NoteProperty -Name Version -Value "2003" } 
	    "6.0.6001"  
	               { 
	                 If($os.ProductType -eq 1) 
	                   { 
	                    $OSV | Add-Member -type NoteProperty -Name Version -Value "Vista" 
	                   } #end if 
	                 Else 
	                   { 
	                    $OSV | Add-Member -type NoteProperty -Name Version -Value "2008" 
	                   } #end else 
	               } #end 6001 
	    "6.1.7600" 
	                { 
	                 If($os.ProductType -eq 1) 
	                   { 
	                    $OSV | Add-Member -type NoteProperty -Name Version -Value "Win7" 
	                   } #end if 
	                 Else 
	                   { 
	                    $OSV | Add-Member -type NoteProperty -Name Version -Value "2008R2" 
	                   } #end else 
	               } #end 7600 
		"6.1.7601" {
			If($os.ProductType -eq 1) 
               { 
                $OSV | Add-Member -type NoteProperty -Name Version -Value "Win7" 
               } #end if 
             Else 
               { 
                $OSV | Add-Member -type NoteProperty -Name Version -Value "2008R2" 
               } #end else 
        }
	    DEFAULT {
		 	write-host $OS.Version -ForegroundColor Magenta
			Write-Host "Please update the Module with the new version information" -ForegroundColor Magenta
		} 
	  } #end switch 
	  
	  Return $OSV
	  
} 
 
#--------------------------------------------------------------------------

Export-ModuleMember -Function Get-OSVersion