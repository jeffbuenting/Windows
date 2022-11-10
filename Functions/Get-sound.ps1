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

if ( $Playback.Name -ne $DefaultPlayback ) {
    New-Popup -Message "There is an error with the Playback device ($($Playback.Name)).  Need to manually remediate." -Title "Playback Error" 
}

if ( $Recording.Name -notlike $DefaultRecording ) {
    New-Popup -Message "There is an error with the Recording device($($Recording.Name)).  Need to manually remediate." -Title "Recording Error" 
}

