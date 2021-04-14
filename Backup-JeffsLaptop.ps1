$Date = Get-Date #-UFormat "%Y-%b-%d"

$Month ='Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'
$Dest = "\\192.168.1.20\Home\Jeffs Backup\$($Date.Year)-$($Month[$($date.Month)-1])-$($Date.Day)"

Write-output $Dest

md $Dest -ErrorAction SilentlyContinue

copy-item -path c:\scripts -Destination $Dest -recurse



Get-ChildItem -path "\\192.168.1.20\Home\Jeffs Backup" | foreach {
       $OldDate = $Date.AddDays( -14 )
       if ( $_.Name -le "$($OldDate.Year)-$($Month[$($Olddate.Month)-1])-$($OldDate.Day)" ) { $_ | remove-item -recurse  }
}

