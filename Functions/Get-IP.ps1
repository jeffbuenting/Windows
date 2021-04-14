Function Get-IP( $Computer )
# Returns the TCP/IP Properties of the $Computer

{
     $colItems = get-wmiobject -class "Win32_NetworkAdapterConfiguration" -namespace "root\CIMV2" -computername $Computer -filter "IPEnabled = true"
     Return $colItems
}




get-vmmserver "vbas0053"

foreach ( $VM in get-vm | where { $_.hostname -eq "vbvs0001.vbgov.com" -and $_.state -eq "Running" } ) {

     $length = 0
     $length = ( $vm.name ).indexof( " " ) 
     if ( $length -le 0 ) { $length = ($vm.name).length }
     $strComputer = ( $vm.name ).substring(0,$length)

     write-host $VM.name, $strComputer
    
     
     $TCP-IP = Get-IP $strComputer
     
     foreach ( $objItem in $TCP-IP ) {
          $objitem.DHCPEnabled
     }

}
