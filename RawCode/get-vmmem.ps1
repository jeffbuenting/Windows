function Get-RAM ( $Computer )

{
    $ram=get-WmiObject -ComputerName $Computer -Class Win32_ComputerSystem 
    return ( $ram.TotalPhysicalMemory )
}


$computer = "VMTS8002"

get-vm -vmmserver vbas0053 | where { ( $_.hostname -eq "vbvs0001.vbgov.com" -or $_.hostname -eq "vbvs0002.vbgov.com" ) -and $_.status -eq "Running" } | foreach {
    $Mem = [math]::Round([math]::Round( ((Get-RAM $_.name)/1MB), 1 ),0)
    $Name = $_.name
	$Owner = $_.owner
	"$name, $Mem, $Owner"
}