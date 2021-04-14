clear-host

get-vmmserver "vbas0053" | out-null

# Get a list of VM's running

$VM = get-vm | where { $_.state -eq "Saved" -and $_.vmhost -eq "vbvs0002.vbgov.com" } 

#Save state of VM's

foreach ( $I in $VM ) {
    start-vm -vm $I | out-null
    Write-host "starting ",$I.name
}