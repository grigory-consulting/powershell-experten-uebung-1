#Requires -Version 5.1

<#
.SYNOPSIS
    Liest Messwertdateien ein, prüft die Werte und fasst sie je Gerät zusammen.

.DESCRIPTION
    Das bisherige Skript des Teams. Es enthält vier Funktionen und am Ende den
    Aufruf, der sie hintereinander benutzt.

.PARAMETER Path
    Pfad einer oder mehrerer Messwertdateien.

.PARAMETER MaxValue
    Obergrenze für plausible Werte. Ohne Angabe gibt es keine Obergrenze.

.EXAMPLE
    .\start\Get-MeasurementReport.ps1 -Path .\daten\messwerte\Nord_2026-11-23.csv

    Fasst die Messwerte einer Datei je Gerät zusammen.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string[]]$Path,

    [double]$MaxValue = [double]::MaxValue
)

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

function Get-MeasurementSummary {
    <#
    .SYNOPSIS
        Fasst Messwertobjekte je Gerät zusammen.

    .DESCRIPTION
        Liefert je Gerät ein Objekt:

          DeviceId       Gerätenummer
          Count          Zahl aller Messwertobjekte des Geräts
          Sum            Summe der gültigen Werte
          Min            kleinster gültiger Wert, $null ohne gültige Werte
          Max            größter gültiger Wert, $null ohne gültige Werte
          InvalidCount   Zahl der Messwertobjekte mit IsValid = $false
          GapCount       Zahl der fehlenden Intervalle zwischen dem ersten und
                         dem letzten Zeitstempel des Geräts

        Gültig ist ein Messwert, wenn Test-Measurement ihn so markiert hat.
        Objekte ohne die Eigenschaft IsValid schickt die Funktion selbst durch
        Test-Measurement (ohne Obergrenze); sie tragen danach IsValid und Reason.

        Die Summe entsteht in [decimal], damit sich keine Rundungsreste der
        Gleitkommazahlen aufaddieren.

    .PARAMETER Measurement
        Messwertobjekte aus Import-MeasurementFile oder Test-Measurement.

    .PARAMETER IntervalMinutes
        Abstand zweier Messwerte in Minuten. Standard ist 15.

    .EXAMPLE
        $measurements = Import-MeasurementFile -Path .\daten\messwerte\Nord_2026-11-23.csv | Test-Measurement
        Get-MeasurementSummary -Measurement $measurements

        Fasst die Messwerte einer Datei je Gerät zusammen.

    .OUTPUTS
        PSCustomObject mit DeviceId, Count, Sum, Min, Max, InvalidCount und GapCount.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [object[]]$Measurement,

        [ValidateRange(1, 1440)]
        [int]$IntervalMinutes = 15
    )

    # Was noch nicht geprüft ist, läuft jetzt durch Test-Measurement.
    $checked = foreach ($item in $Measurement) {
        if ($null -eq $item.PSObject.Properties['IsValid']) {
            $item | Test-Measurement
        }
        else {
            $item
        }
    }

    foreach ($group in ($checked | Group-Object -Property DeviceId | Sort-Object -Property Name)) {
        $sum = [decimal]0
        $min = $null
        $max = $null
        $invalidCount = 0

        foreach ($item in $group.Group) {
            if (-not $item.IsValid) {
                $invalidCount++
                continue
            }
            $sum += [decimal]$item.Value
            if ($null -eq $min -or $item.Value -lt $min) {
                $min = $item.Value
            }
            if ($null -eq $max -or $item.Value -gt $max) {
                $max = $item.Value
            }
        }

        # Lücken: Zwischen zwei aufeinanderfolgenden Zeitstempeln fehlen
        # so viele Intervalle, wie zusätzlich hineingepasst hätten.
        # Doppelte Zeitstempel zählen dabei nur einmal.
        $gapCount = 0
        $timestamps = @($group.Group | ForEach-Object { $_.Timestamp } | Sort-Object -Unique)
        for ($index = 1; $index -lt $timestamps.Count; $index++) {
            $minutes = ($timestamps[$index] - $timestamps[$index - 1]).TotalMinutes
            $missing = [int][math]::Floor($minutes / $IntervalMinutes) - 1
            if ($missing -gt 0) {
                $gapCount += $missing
            }
        }

        [pscustomobject]@{
            DeviceId     = $group.Name
            Count        = $group.Count
            Sum          = [double]$sum
            Min          = $min
            Max          = $max
            InvalidCount = $invalidCount
            GapCount     = $gapCount
        }
    }
}

$measurements = Import-MeasurementFile -Path $Path | Test-Measurement -MaxValue $MaxValue
Get-MeasurementSummary -Measurement $measurements
