clear-host

get-vmmserver "vbas0053" | out-null

# Get a list of VM's running


$VM = get-vm | where { $_.state -eq "Running" -and $_.name -eq "vbas9201" } 

#Save state of VM's

foreach ( $I in $VM ) {
    savestate-vm -vm $I | out-null
   # Write-host "Saving state on ",$I.name
}