function Get-DriveInfo {  
    
    [CmdletBinding()]
    param (
        [String]$ComputerName = '.'
    )

    Get-CimInstance -ComputerName $ComputerName -ClassName Win32_DiskPartition | ForEach-Object {  
        $partition = $_  
        $logicaldisk = $partition.psbase.GetRelated('Win32_LogicalDisk')  
        if ($logicaldisk -ne $null) {  
            $propertylistObj1 = @($LogicalDisk | Get-Member -ea Stop -memberType *Property | Select-Object -ExpandProperty Name)  
            $propertylistObj2 = @($Partition | Get-Member -memberType *Property | Select-Object -ExpandProperty Name | Where-Object { $_ -notlike '__*'}) 

            $propertylistObj2 | ForEach-Object {  
                if ($propertyListObj1 -contains $_) {  
                    $name = '_{0}' -f $_  
                } else {  
                    $name = $_  
                }  
  
                $LogicalDisk = $LogicalDisk | Add-Member NoteProperty $name ($Partition.$_) -PassThru 
                 
            }  
        } 
        Write-Output $LogicalDisk 
    } 
     
}  

Get-DriveInfo