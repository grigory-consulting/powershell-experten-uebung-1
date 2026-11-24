function ConvertTo-MeasurementValue {
    <#
    .SYNOPSIS
        Wandelt den Text eines Messwerts in eine Zahl um.

    .DESCRIPTION
        Liest den Text in der genannten Kultur, unabhängig von der Kultur der
        Sitzung. Ein leerer Text ergibt $null.

    .PARAMETER Text
        Der Wert als Text, zum Beispiel 1234,56.

    .PARAMETER Culture
        Kultur, in der der Text geschrieben ist.

    .OUTPUTS
        System.Double oder $null.
    #>
    [CmdletBinding()]
    [OutputType([double])]
    param(
        [string]$Text,

        [Parameter(Mandatory)]
        [cultureinfo]$Culture
    )

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return $null
    }

    [double]::Parse($Text, $Culture)
}