# lists when the VM's where last modified

Clear-host

Get-VMMServer "vbas0053" | out-null

$vs = Get-VM | where {$_.State -eq 'Running'} | format-table Name, State, ModifiedTime | out-host
