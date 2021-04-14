# lists the running VM's on the specified server

Clear-host

Get-VMMServer "vbas0053" | out-null

$VServer = read-host "List VM's on which server?"

if ( $vserver -eq 'all' ) {
		write-host "Showing running VM's for all Servers"

		$vs = Get-VM | where {$_.State -eq 'Running'} | where {$_.HostName -eq 'vbvs0001.vbgov.com' } | format-table Name, HostName, State | out-host
		$vs = Get-VM | where {$_.State -eq 'Running'} | where {$_.HostName -eq 'vbvs0002.vbgov.com' } | format-table Name, HostName, State | out-host
		$vs = Get-VM | where {$_.State -eq 'Running'} | where {$_.HostName -eq 'vbvs0003.vbgov.com' } | format-table Name, HostName, State | out-host
		$vs = Get-VM | where {$_.State -eq 'Running'} | where {$_.HostName -eq 'vbvs9001.vbgov.com' } | format-table Name, HostName, State | out-host
	}
	Else {
		$vserver = $vserver+".vbgov.com"
		write-host "Showing running VM's for Server" $vserver
		$vs = Get-VM | where {$_.State -eq 'Running'} | where {$_.HostName -eq $vserver } | format-table Name, HostName, State | out-host
}
