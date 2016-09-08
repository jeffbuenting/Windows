$Catalog = GC "C:\temp\comp.txt"
$DisabledMonth = 'vbgov.com/managed/computers/disabled/OCT'
ForEach($Machine in $Catalog) {
     $Machine = 'CVB-'+$Machine
     move-QADObject $Machine -NewParentContainer $DisabledMonth
}