# https://support.microsoft.com/en-us/kb/160129 
# https://support.microsoft.com/en-us/kb/158828
# http://www.powertheshell.com/reference/wmireference/root/cimv2/win32_printer/

Param(
    [string]$file = "C:\TEMP\check_win_printers.csv",
    [string]$daysOffline = "1"
)

$dateNow = [DateTime]::Now
$dateOffline = $dateNow.AddDays(-$daysOffline)

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
    If ((Get-Date $date) -le (Get-Date $dateOffline)) {
        $offlinePrinters += $name
    }

    $printer = New-Object PSObject
    $printer | Add-Member -membertype NoteProperty -name "name" -Value $name
    $printer | Add-Member -membertype NoteProperty -name "date" -Value $date
	$printer | Add-Member -membertype NoteProperty -name "status" -Value $status

    $newList += $printer
}

$newList | Export-Csv -Path $file -NoTypeInformation

# int all printers (total printers)
$cPrinters = $newList.Length
# int offlinePrinters (total offline printers)
$cofflinePrinters = $offlinePrinters.Length

$returnMsg = "Offline printers: "

if ($cofflinePrinters -gt 1 ) {
    $returnCode = 1
}

if ($cofflinePrinters -gt 2 ) {
    $returnCode = 2
}

if ($cPrinters -lt 1 ) {
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

# Add performance data
$returnMsg += "`n"
$returnMsg += "offlines=$cofflinePrinters;1;2;0;;"
$returnMsg += "printers=$cPrinters;0;0;1;;"

Write-Host $returnMsg
Exit $returnCode
