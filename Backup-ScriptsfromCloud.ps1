<#
    .Description
        Backup Scripts from Cloud

    .Notes
        Author: Jeff Buenting
        Date: 28 Jul 2015
#>

$Cred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList 'xxxxxx',(Get-Content -Path 'F:\OneDrive -  , LLC\Scripts\cred.txt' | ConvertTo-SecureString ) 

# ----- Map a network drive to the remote machine.  Required in order to use different credentials
Write-Host "Mapping to cloud drive." -ForegroundColor Cyan
try {
        $RWVATS1Drive = New-Object -ComObject Wscript.Network
        if (( Get-PSDrive -Name J -ErrorAction SilentlyContinue ) -eq $Null ) {
            $RWVATS1Drive.MapNetworkDrive('J:','\\$ServerName\c$\scripts',0,$Cred.UserName,$Cred.GetNetworkCredential().Password)
        }
    }
    Catch {
        Write-Error "Problem mapping to cloud machine"
        $_
        break
}

Write-Host "Get list of script files from cloud drive." -ForegroundColor Cyan
get-childitem -Path 'j:' -recurse | where PSIsContainer -eq $False | foreach {
    write-host "     F:\OneDrive -  , LLC\Scripts$(($_.FullName).substring(2))" -ForegroundColor Cyan

    if ( Test-path -Path "F:\OneDrive -  , LLC\Scripts$(($_.FullName).substring(2))" ) {
            $File =  Get-ChildItem -Path "F:\OneDrive -  , LLC\Scripts$(($_.FullName).substring(2))"
            if ( $File.LastWriteTime -le $_.LastWriteTime ) {
                    Write-Host "          Copying FROM Cloud" -ForegroundColor Cyan
                    Copy-Item -Path $_.FullName -Destination "F:\OneDrive -  , LLC\Scripts$(($_.FullName).substring(2))" -Force
                }
                else {
                    Write-Host "          Copying TO Cloud" -ForegroundColor Magenta
                    Copy-Item -Path "F:\OneDrive -  , LLC\Scripts$(($_.FullName).substring(2))" -Destination $_.FullName -Force
            }
        }
        Else {
           
            if ( -not (Test-Path -Path "F:\OneDrive -  , LLC\scripts$(($_.DirectoryName).substring(2))") ) {
                MD "F:\OneDrive -  , LLC\scripts$(($_.DirectoryName).substring(2))"
            }
            Write-Host "          File does not exist.  Copying FROM Cloud" -ForegroundColor Cyan
            Copy-Item -Path $_.FullName -Destination "F:\OneDrive -  , LLC\Scripts$(($_.FullName).substring(2))" -Force
    }
    
}

Write-Host "Removing mapped drive." -ForegroundColor Cyan
# ----- Remove the network Drive
$RWVATS1Drive.RemoveNetworkDrive('J:')
