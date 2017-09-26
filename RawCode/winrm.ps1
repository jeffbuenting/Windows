$Computer = "."

$wa = New-Object -ComObject Wsman.Automation 
$session = $wa.CreateSession( )
$res = $session.Identify()
$xr = [xml]$res
$xr.IdentifyResponse.ProductVersion