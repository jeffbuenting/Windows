<#
    .SYNOPSIS
        Throws error is speaker and mic are not what I chose.

    .DESCRIPTION
        So my windows machine is having problem maintaining the correct speaker/mic that I pick.  This task will run whenever I log in to check that they are correct.
#>

import-module 'C:\Users\jeff.buenting\OneDrive - nrccua.onmicrosoft.com\Documents\Scripts\Popup'

$DefaultPlayback = "Speakers (Realtek(R) Audio)"
$DefaultRecording = "Microphone Array (Intel*"

try {
    $Playback = Get-AudioDevice -Playback -ErrorAction Stop 
    $Recording = Get-AudioDevice -Recording -ErrorAction Stop 
}
Catch {
    $ExceptionMessage = $_.Exception.Message
    $ExceptionType = $_.Exception.GetType().Fullname
    Throw "Error retrieving audio devices.`n`n     $ExceptionMessage`n`n $ExceptionType"
}

Write-Output "Playback Device:"
$Playback.Name

Write-Output "Recording Device:"
$Recording.Name

if ( $Playback.Name -ne $DefaultPlayback ) {
    $Ans = New-Popup -Message "There is an error with the Playback device ($($Playback.Name)).  Need to manually remediate." -Title "Playback Error" 
}

if ( $Recording.Name -notlike $DefaultRecording ) {
    $Ans = New-Popup -Message "There is an error with the Recording device($($Recording.Name)).  Need to manually remediate." -Title "Recording Error" 
}

$Ans = New-Popup -Message "Done" -Title "done"

