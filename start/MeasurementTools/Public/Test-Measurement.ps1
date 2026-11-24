function Test-Measurement {
    <#
    .SYNOPSIS
        Prüft Messwertobjekte und ergänzt IsValid und Reason.

    .DESCRIPTION
        Gibt jedes Objekt wieder aus, ergänzt um zwei Eigenschaften:

          IsValid   $true, wenn nichts gegen den Messwert spricht
          Reason    die Gründe als Text, getrennt durch Semikolon; leer bei
                    gültigen Messwerten

        Mögliche Gründe:

          Wert fehlt        Value ist $null
          Wert negativ      Value ist kleiner als 0
          Wert zu hoch      Value ist größer als -MaxValue
          Status nicht OK   Status ist nicht OK

        Ergänzt werden die Objekte selbst, es entstehen keine Kopien. Ein
        zweiter Lauf mit anderem -MaxValue überschreibt das Ergebnis des ersten.

    .PARAMETER InputObject
        Messwertobjekte aus Import-MeasurementFile.

    .PARAMETER MaxValue
        Obergrenze für plausible Werte. Ohne Angabe gibt es keine Obergrenze.

    .EXAMPLE
        Import-MeasurementFile -Path .\daten\messwerte\Nord_2026-11-23.csv | Test-Measurement

        Prüft alle Messwerte einer Datei.

    .INPUTS
        PSCustomObject mit Value und Status.

    .OUTPUTS
        Dieselben Objekte mit IsValid und Reason.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [psobject[]]$InputObject,

        [double]$MaxValue = [double]::MaxValue
    )

    process {
        foreach ($item in $InputObject) {
            $reasons = @()

            if ($null -eq $item.Value) {
                $reasons += 'Wert fehlt'
            }
            if ($item.Value -lt 0) {
                $reasons += 'Wert negativ'
            }
            if ($item.Value -gt $MaxValue) {
                $reasons += 'Wert zu hoch'
            }
            if ($item.Status -ne 'OK') {
                $reasons += 'Status nicht OK'
            }

            $result = [ordered]@{
                IsValid = ($reasons.Count -eq 0)
                Reason  = ($reasons -join '; ')
            }
            Add-Member -InputObject $item -NotePropertyMembers $result -Force
            $item
        }
    }
}