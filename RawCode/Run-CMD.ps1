#------------------------------------------------------------------------

Function Remote-CMD ( $Computer, $CMD, $Cred )
# Function to run a command on a remote computer.  Remote computer is $Computer.  Command is $CMD.  
# You must run this with ADMIN Permissions on the remote computer.


{
     Write-host "Remote-CMD"
     write-host "Running $CMD on $Computer"

     $NewProcess = Get-WmiObject -List -Computer $Computer -credential $Cred | where{$_.Name -eq 'Win32_Process' }
   
     $ReturnCode = $NewProcess.create( $CMD )

     #Waiting for process to end
     $a = 0

     $timespan = New-Object System.TimeSpan(0, 0, 1)  
     $scope = New-Object System.Management.ManagementScope("\\$Computer\root\cimV2")
     $query = New-Object System.Management.WQLEventQuery ("__InstanceDeletionEvent",$timespan, "TargetInstance ISA 'Win32_Process'" )
     $watcher = New-Object System.Management.ManagementEventWatcher($scope,$query)

     "Waiting for $CMD to complete"
     do {
          $b = $watcher.WaitForNextEvent()
          if ( $b.TargetInstance.processid -eq $returncode.processid ) {
	       $a = 1
          }
     } while ($a -ne 1)

     $returncode

     Return $Returncode.returnValue
     
}

#------------------------------------------------------------------------

$file = Read-Host "Name of the CSV file containing the list of computer ( including full path ):"
$uname = Read-Host "Input User Name:"
$cred = get-credential $UName

$CMD = Read-Host "Command to run on remote computer:"

$Computer = Import-Csv $File

foreach ( $C in $Computer ) {
    Remote-CMD $C $CMD $Cred
}