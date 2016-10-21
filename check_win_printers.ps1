<#
.Synopsis
    Get list of printers added to the system and returns 0, 1, 2 depending if it founds offline printers. also returns perfdata for nagios. 
.DESCRIPTION
    Get list of printers added to the system and returns 0, 1, 2 depending if it founds offline printers. also returns perfdata for nagios. 
    It can also saves the last seen online date (or last check date if it was offline at that time, and compares dates using -daysOffline x). 
.EXAMPLE
    ./check_win_printers.ps1 -daysOffline 0 
.EXAMPLE
    ./check_win_printers.ps1 -daysOffline 1
#>
# https://support.microsoft.com/en-us/kb/160129 
# https://support.microsoft.com/en-us/kb/158828
# http://www.powertheshell.com/reference/wmireference/root/cimv2/win32_printer/
# https://assets.nagios.com/downloads/nagioscore/docs/nagioscore/4/en/perfdata.html
# https://assets.nagios.com/downloads/nagioscore/docs/nagioscore/4/en/plugins.html

Param(
    [string]$file = "C:\TEMP\check_win_printers.csv",
    [int]$daysOffline = 0
)

$dateNow = [DateTime]::Now
$dateOffline = $dateNow.AddDays(-$daysOffline)
$stopwatch = [system.diagnostics.stopwatch]::startNew()

$returnCode = 0
$returnMsg = ""
$offlinePrinters = @()
$cofflinePrinters = "0"
$cPrinters = "0"

If (Test-Path $file) { $previousList = Import-Csv $file }
Else { $previousList = @() }

# Get current state of printers
$currentList = Get-WmiObject win32_printer | Select-Object name,status,printerstate

$newList = @()

$currentList | ForEach-Object {
    $name = $_.name
    $status = $_.status
    $state = $_.printerstate
    $date = ""

    # Check for online printers
    If ($status -eq "OK" -or $status -eq "Unknown") { $date = $dateNow }
    Else {
        # Exclude safe error codes
        # 131072 - Toner/Ink Low
        If ($state -ne "131072") {
            # Get last online date from CSV file
            For ($pos=0; $pos -lt $previousList.Length; $pos++) {
                If ($previousList[$pos].name -eq $name) {
                    $date = $previousList[$pos].date
                }
            }
        }
        If (!$date) { $date = $dateNow }
    }

    # Check if outdated conditions are met
    If ((Get-Date $date) -lt (Get-Date $dateOffline)) {
        $offlinePrinters += $name
    }

    $printer = New-Object PSObject
    $printer | Add-Member -membertype NoteProperty -name "name" -Value $name
    $printer | Add-Member -membertype NoteProperty -name "date" -Value $date
    $printer | Add-Member -membertype NoteProperty -name "status" -Value $status
    $printer | Add-Member -membertype NoteProperty -name "state" -Value $state

    $newList += $printer
}

$newList | Export-Csv -Path $file -NoTypeInformation

# int all printers (total printers)
$cPrinters = $newList.Length

# int offlinePrinters (total offline printers)
$cofflinePrinters = $offlinePrinters.Length

$returnMsg = "Offline printers: "

If ($cofflinePrinters -ge 1 ) {
    $returnCode = 1
}

If ($cofflinePrinters -gt 2 ) {
    $returnCode = 2
}

If ($cPrinters -lt 1 ) {
    $returnCode = 2
    $returnMsg = "No printers!: "
}

# Print
If ($cofflinePrinters -eq 0) { $returnMsg += "0" }
Else {	
    For ($pos=0; $pos -lt $cofflinePrinters; $pos++) {
        $returnMsg += $offlinePrinters[$pos]
        If (($pos + 1) -lt $cofflinePrinters) { $returnMsg += ", " }
        Else { $returnMsg += "." }
    }
}

# Manage some information for ran time
$stopwatch.Stop()
$elapsed = $stopwatch.Elapsed.Seconds

If ($elapsed -ge 8 ) {
    $returnCode = 1
    $returnMsg = "Warning script took more than 8s to ran"
}
If ($elapsed -ge 9 ) {
    $returnCode = 2
    $returnMsg = "Critical script took more than 8s to ran"
}

# Add performance data
# https://nagios-plugins.org/doc/guidelines.html#AEN200
# 'label'=value[UOM];[warn];[crit];[min];[max]
# space is required after each label
$returnMsg += "|"  # Separator for perfdata https://assets.nagios.com/downloads/nagioscore/docs/nagioscore/4/en/perfdata.html
$returnMsg += "'offlines'=$cofflinePrinters;1;3;0;; "
$returnMsg += "'printers'=$cPrinters;0;0;1;; "
$returnMsg += "'runtime'=$($elapsed)s;8;9;0;10 "

Write-Host $returnMsg
Exit $returnCode
