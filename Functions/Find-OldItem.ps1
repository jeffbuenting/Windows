$SearchRoot = '\\nas1'

# https://www.itprotoday.com/powershell/view-all-shares-remote-machine-powershell
$Shares = net view $SearchRoot /all | select -Skip 7 | ?{$_ -match 'disk*' -and $_ -notmatch 'D\$'} | %{$_ -match '^(.+?)\s+Disk*'|out-null;$matches[1]}

# $AllFiles = @()
foreach ( $S in $Shares ) {
    Write-output "------- $S"

    Measure-Command {
        $Files = Get-childitem -Path $SearchRoot\$S -recurse
    }


    $Files | where { ! $_.PSIsContainer } | Select-object fullname, lastaccesstime,@{N='Year';E={$_.LastAccessTime.Year}}, length,@{N='SizeMB';E={$_.Length/1MB}} | Export-csv "C:\temp\nas1age_$S.csv" -NoTypeInformation
    # $ShareFiles = [PSCustomObject]@{
    #     Share = $S
    #     Files = $Files
    # }

    # $AllFiles += $ShareFiles

}

# $Files | where { ! $_.PSIsContainer } | Select-object fullname, lastaccesstime,@{N='Year';E={$_.LastAccessTime.Year}}, length,@{N='SizeMB';E={$_.Length/1MB}} | Export-csv C:\temp\nas1age.csv -NoTypeInformation