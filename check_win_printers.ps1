Param(
    [string]$file = "C:\TEMP\check_win_printers.csv",
    [string]$daysOffline = "1"
)

$dateNow = [DateTime]::Now
$dateOffline = $dateNow.AddDays(-$daysOffline)

$returnCode = 0
$returnMsg = ""
$offlinePrinters = @()

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
        $returnCode = 2
        $offlinePrinters += $name
    }

    $printer = New-Object PSObject
    $printer | Add-Member -membertype NoteProperty -name "name" -Value $name
    $printer | Add-Member -membertype NoteProperty -name "date" -Value $date

    $newList += $printer
}

$newList | Export-Csv -Path $file -NoTypeInformation

$returnMsg = "Offline printers: "

# Print
If ($offlinePrinters.Length -eq 0) { $returnMsg += "0" }
Else {
    For ($pos=0; $pos -lt $offlinePrinters.Length; $pos++) {
        $returnMsg += $offlinePrinters[$pos]
        If (($pos + 1) -lt $offlinePrinters.Length) { $returnMsg += ", " }
        Else { $returnMsg += "." }
    }
}

Write-Host $returnMsg
Exit $returnCode
