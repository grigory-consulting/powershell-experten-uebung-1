function Import-MeasurementFile {
    <#
    .SYNOPSIS
        Liest Messwertdateien ein und liefert je Zeile ein Messwertobjekt.

    .DESCRIPTION
        Erwartet CSV-Dateien mit dem Trennzeichen Semikolon und den Spalten
        Zeitstempel, Geraet, Wert, Einheit und Status. Der Zeitstempel hat das
        Format dd.MM.yyyy HH:mm. Die Zahl in der Spalte Wert wird in der Kultur
        gelesen, die -Culture nennt.

    .PARAMETER Path
        Pfad einer oder mehrerer Messwertdateien. Platzhalter sind erlaubt.
        Aus der Pipeline kommen Pfade als Text oder Dateiobjekte (Eigenschaft
        FullName).

    .PARAMETER Culture
        Kultur, in der die Zahlen der Datei geschrieben sind. Standard ist
        de-DE (Dezimalkomma).

    .EXAMPLE
        Import-MeasurementFile -Path .\daten\messwerte\Nord_2026-11-23.csv

        Liest eine Datei ein.

    .EXAMPLE
        Get-ChildItem .\daten\messwerte\Nord_*.csv | Import-MeasurementFile | Test-Measurement

        Liest alle Dateien eines Standorts ein und prüft die Werte.

    .INPUTS
        System.String

    .OUTPUTS
        PSCustomObject mit Timestamp, DeviceId, Value, Unit, Status und SourceFile.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('FullName')]
        [string[]]$Path,

        [cultureinfo]$Culture = 'de-DE'
    )

    process {
        foreach ($item in $Path) {
            foreach ($resolved in (Resolve-Path -Path $item)) {
                $fileName = Split-Path -Path $resolved.ProviderPath -Leaf
                Write-Verbose "Lese $($resolved.ProviderPath)"

                foreach ($row in (Import-Csv -LiteralPath $resolved.ProviderPath -Delimiter ';' -Encoding UTF8)) {
                    [double]$value = ConvertTo-MeasurementValue -Text $row.Wert -Culture $Culture

                    [pscustomobject]@{
                        Timestamp  = Get-Date -Date $row.Zeitstempel
                        DeviceId   = $row.Geraet
                        Value      = $value
                        Unit       = $row.Einheit
                        Status     = $row.Status
                        SourceFile = $fileName
                    }
                }
            }
        }
    }
}