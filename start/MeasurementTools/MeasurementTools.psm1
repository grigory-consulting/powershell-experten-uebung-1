#Requires -Version 5.1

$public  = @(Get-ChildItem "$PSScriptRoot\Public\*.ps1")
$private = @(Get-ChildItem "$PSScriptRoot\Private\*.ps1")

foreach ($file in $public + $private) {
    . $file.FullName
}

Export-ModuleMember -Function $public.BaseName