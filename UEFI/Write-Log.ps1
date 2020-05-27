Function Write-Log {

<#
    .SYNOPSIS
        Writes output to a log file

    .DESCRIPTION 
        Writes output to log file and if needed to the verbose stream.  This facilitates using one function to both write to the different streams and to a file.

    .PARAMETER PATH
        Full path including name to the log file.

    .PARAMETER MESSAGE
        Info message to write to log.

    .PARAMETER Warning
        changes the message type to warning.

    .PARAMETER Throw
        Changes the message type to Error.

    .EXAMPLE
        write a info message to the log and to the verbose stream.

        Write-Log -Path c:\temp\log.log -Message 'This is info.' -Verbose

    .LINKS
        Used this as inspiration and added the verbose part.

        https://gallery.technet.microsoft.com/scriptcenter/Write-Log-PowerShell-999c32d0

    .NOTES
        Author : Jeff Buenting
        DATE : 2019 NOV 7
#>
    
    [CmdletBinding(DefaultParameterSetName = 'Info')]
    param (
        [Parameter (Mandatory = $True,Position = 0)]
        [Parameter(ParameterSetName = 'Info')]
        [Parameter(ParameterSetName = 'Warning')]
        [Parameter(ParameterSetName = 'Error')]
        [String]$Path,

        [Parameter (Mandatory = $True,Position = 1)]
        [Parameter(ParameterSetName = 'Info')]
        [Parameter(ParameterSetName = 'Warning')]
        [Parameter(ParameterSetName = 'Error')]
        [String]$Message,

        [Parameter(ParameterSetName = 'Warning')]
        [Switch]$Warning,

        # ----- Have to use throw here as error is built in variable
        [Parameter(ParameterSetName = 'Error')]
        [Switch]$Throw
    )

    if ( -Not ( Test-path -Path $Path ) ) { New-Item -ItemType File -Path $Path | Out-Null }

    $Date = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

    $MsgType = 'Info   '
        
    $Txt = "$Date  -  $MsgType -  $Message"

    if ( $VerbosePreference -eq 'Continue' -and -not $Warning -and -not $Throw ) {
        Write-Verbose $TXT
    }

    if ( $Warning ) {
        $MsgType = 'Warning'
        
        $TXT = "$Date  -  $MsgType -  $Message"

        Write-Warning $TXT
    }

     if ( $Throw ) {
        $MsgType = 'Error  '
        
        $Txt = "$Date  -  $MsgType -  $Message"
    }

    Out-File -FilePath $Path -InputObject $TXT -Append

    if ( $Throw ) { Throw $Txt }
}
