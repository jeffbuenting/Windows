# ----- Dot source 
. x:\scripts\write-log.ps1

$Key = (3,4,2,3,56,34,254,222,1,1,2,23,42,54,33,233,1,34,2,7,6,5,35,43)

# ----- Retrieve parameters
Try {

    $Data = Import-Csv -Path D:\WINPEInput.csv -ErrorAction Stop
}
Catch {
    $ExceptionMessage = $_.Exception.Message
    $ExceptionType = $_.Exception.GetType().Fullname
    
    #Write-log -Path "$($Data.Logpath)\$($Data.Name).log" -Throw -Message "There was a problem retrieving the WINPEInput CSV from the local drive.`n`n     $ExceptionMessage`n`n $ExceptionType"
    Write-log -Path "D:\UEFIConversionFailed.log" -Throw -Message "There was a problem retrieving the WINPEInput CSV from the local drive.`n`n     $ExceptionMessage`n`n $ExceptionType" -Verbose


    # ----- Shut Down VM
    Stop-Computer -Force
}

$Cred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $Data.UserName, ($Data.PW | ConvertTo-SecureString -Key $Key)

# ----- Map to log location
Try { 
    New-PSDrive -Name "J" -Root $Data.LogPath -PSProvider FileSystem -Credential $Cred -ErrorAction Stop
}
Catch {
    $ExceptionMessage = $_.Exception.Message
    $ExceptionType = $_.Exception.GetType().Fullname
    
    #Write-log -Path "$($Data.Logpath)\$($Data.Name).log" -Throw -Message "There was a problem retrieving the WINPEInput CSV from the local drive.`n`n     $ExceptionMessage`n`n $ExceptionType"
    Write-log -Path "D:\UEFIConversionFailed.log" -Throw -Message "Failed to map to the network share: $($Data.LogPath).`n`n     $ExceptionMessage`n`n $ExceptionType" -Verbose


    # ----- Shut Down VM
    Stop-Computer -Force
}


Write-log -Path "J:\$($Data.Name).log" -Message "WINPEInput VMName = $($Data.Name); Logpath = $($Data.LogPath)" -Verbose

# ----- Find the system disk
$SystemDisk = Get-Disk | where BootFromDisk

Write-Log -Path "J:\$($Data.Name).log" -Message "System disk is disk: $($SystemDisk.Number)" -Verbose

# ----- Validate system disk for MBR2GBT
$ValidationResult = & x:\scripts\MBR2GPT.EXE /validate /disk:$($SystemDisk.Number) 2>&1

if ($LastExitCode -ne 0) {
    Write-Log -Path "J:\$($Data.Name).log" -Throw -Message "Error validating disk $($SystemDisk.Number).`n`n$ValidationResult" -Verbose

    Write-Error "Error validating disk $($SystemDisk.Number).`n`n$ValidationResult"

    # ----- Shut Down VM
    Stop-Computer -Force
}

Write-Log -Path "J:\$($Data.Name).log" -Message "Validation successful`n$ValidationResult" -Verbose

# ----- Convert
$Result = & X:\Scripts\MBR2GPT.EXE /Convert /disk:0 2>&1

if ($LastExitCode -ne 0) {
    Write-Log -Path "J:\$($Data.Name).log" -Throw -Message "Error Converting Disk $($SystemDisk.Number) from MBR to GPT.`n`n$Result" -Verbose

    Write-Error "Error converting Disk $($SystemDisk.Number) from MBR to GPT"
    
    # ----- Shut Down VM
    Stop-Computer -Force
}

Write-Log -Path "J:\$($Data.Name).log" -Message "Success : Conversion Complete.`n`n$Result" -Verbose

Write-output "Shutting down"

# ----- Shut Down VM
Stop-Computer -Force -Verbose
