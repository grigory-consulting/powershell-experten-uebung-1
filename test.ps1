[cultureinfo]::CurrentCulture = 'de-DE'

#.\start\Get-MeasurementReport.ps1 -Path .\daten\messwerte\Nord_2026-11-23.csv | Format-Table

Import-Module .\start\MeasurementTools -Force
Get-Command -Module MeasurementTools