#Here is a powershell script to check against a list of servers and get their last reboot time and report in excel.

$x = "vbfp0012.vbgov.com"
foreach ($i in $x) {
     $y = get-wmiobject Win32_NetworkAdapterConfiguration -computername $i -Filter "IPenabled = 'True'" 
     foreach ($j in $y) {
	      $Name = $j.DNSHostName
          $IP = $j.IPAddress
          $MAC = $j.MACAddress
     }
     $date = new-object -com WbemScripting.SWbemDateTime
     $z = get-wmiobject Win32_OperatingSystem -computername $i
     foreach ($k in $z) {
          $date.value = $k.lastBootupTime
          If ($k.Version -eq "5.2.3790" )
                    {$LReboot = $Date.GetVarDate($True)}
               Else
                    {$LReboot = $Date.GetVarDate($False)}
     }
     $m = $m + 1
	 "$Name, $IP, $MAC, $LReboot"
}
