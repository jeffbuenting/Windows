param($program)
$sa=new-object -com shell.application
$sa.ShellExecute($program,"$args","","runas")
